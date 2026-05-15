// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit xkcdapp;

interface

uses xkcdmodel;

function Run(const AOptions: TXkcdOptions): Integer;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Math,
  FireDAC.Comp.Client,
  xkcdcache,
  xkcddb,
  xkcdhttp,
  xkcdhtml,
  xkcdexplained,
  xkcdconsole,
  termimageapi,
  termdetectapi
  {$IFDEF MSWINDOWS}
  , Winapi.ShellAPI, Winapi.Windows
  {$ELSE}
  , Posix.Stdlib
  {$ENDIF}
  ;

function ProtocolCacheFile(const ACacheDir: string): string;
begin
  Result := TPath.Combine(ACacheDir, 'protocol.txt');
end;

function LoadCachedProtocol(const ACacheDir: string;
  out AProtocol: TTerminalProtocol): Boolean;
var
  LVal: Integer;
begin
  var LPath := ProtocolCacheFile(ACacheDir);
  if not TFile.Exists(LPath) then
    Exit(False);
  LVal := StrToIntDef(Trim(TFile.ReadAllText(LPath, TEncoding.UTF8)), -1);
  if (LVal < Ord(Low(TTerminalProtocol))) or
     (LVal > Ord(High(TTerminalProtocol))) then
    Exit(False);
  AProtocol := TTerminalProtocol(LVal);
  Result := True;
end;

procedure SaveCachedProtocol(const ACacheDir: string; AProtocol: TTerminalProtocol);
begin
  TFile.WriteAllText(ProtocolCacheFile(ACacheDir),
    IntToStr(Ord(AProtocol)), TEncoding.UTF8);
end;

procedure OpenWithOsViewer(const AFileName: string);
begin
  {$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(AFileName), nil, nil, SW_SHOWNORMAL);
  {$ELSE}
  _system(PAnsiChar(AnsiString('xdg-open "' + AFileName + '"')));
  {$ENDIF}
end;

function FindComicByID(const AComics: TArray<TXkcdComicMeta>;
  AID: Integer): TXkcdComicMeta;
begin
  for var LMeta in AComics do
    if LMeta.ID = AID then
      Exit(LMeta);
  raise EXkcdError.CreateFmt('Comic #%d not found in cache', [AID]);
end;

procedure WriteIndentedWrappedText(const AText, AIndent: string);
var
  LWrapped: string;
  LLines: TArray<string>;
begin
  LWrapped := WrapTextAtWords(AText, ConsoleTextWidth - Length(AIndent));
  LLines := LWrapped.Replace(#13#10, #10).Replace(#13, #10).Split([#10]);
  for var LLine in LLines do
    Writeln(AIndent + LLine);
end;

function UpdateExplainedCache(AConnection: TFDConnection;
  const AComics: TArray<TXkcdComicMeta>; AComicID: Integer;
  AForceFetch: Boolean; AIncludeExplanation, AIncludeTranscript: Boolean): Integer;
var
  LTargets: TArray<TXkcdComicMeta>;
  LFailureCount: Integer;
  LSkippedExistingCount: Integer;
  LExplanation: TXkcdExplanation;
  LNeedsFetch: Boolean;
begin
  Result := 0;
  LFailureCount := 0;
  LSkippedExistingCount := 0;
  if AComicID > 0 then
    LTargets := [FindComicByID(AComics, AComicID)]
  else
    LTargets := AComics;

  Writeln(Format('Checking Explain XKCD pages: %d comics', [Length(LTargets)]));
  for var I := 0 to High(LTargets) do
  begin
    try
      LNeedsFetch := AForceFetch;
      if not LNeedsFetch then
      begin
        if TryGetExplanation(AConnection, LTargets[I].ID, LExplanation) then
        begin
          LNeedsFetch := (AIncludeExplanation and (LExplanation.Explanation = '')) or
                         (AIncludeTranscript and (LExplanation.Transcript = ''));
        end
        else
          LNeedsFetch := True;
      end;

      if not LNeedsFetch then
      begin
        Inc(LSkippedExistingCount);
        Continue;
      end;

      UpsertExplanation(AConnection,
        ParseExplainPage(LTargets[I].ID, LTargets[I].Title,
          FetchExplainHtml(LTargets[I].ID, LTargets[I].Title)));
      Inc(Result);
    except
      on E: Exception do
      begin
        Inc(LFailureCount);
        Writeln(ErrOutput, Format('Explain XKCD #%d skipped: %s',
          [LTargets[I].ID, E.Message]));
      end;
    end;

    if ((I + 1) mod 25 = 0) or (I = High(LTargets)) then
      Writeln(Format('Explain XKCD progress: %d/%d fetched, %d skipped, %d failed',
        [Result, Length(LTargets), LSkippedExistingCount, LFailureCount]));
  end;
end;

function LoadOrFetchExplanation(AConnection: TFDConnection; const AMeta: TXkcdComicMeta;
  AForceFetch: Boolean): TXkcdExplanation;
begin
  if (not AForceFetch) and TryGetExplanation(AConnection, AMeta.ID, Result) then
    Exit;

  Result := ParseExplainPage(AMeta.ID, AMeta.Title,
    FetchExplainHtml(AMeta.ID, AMeta.Title));
  UpsertExplanation(AConnection, Result);
end;

procedure WriteExplanation(const AExplanation: TXkcdExplanation;
  AIncludeExplanation, AIncludeTranscript: Boolean);
begin
  Writeln;
  if AIncludeExplanation and (AExplanation.Explanation <> '') then
  begin
    Writeln('Explanation:');
    WriteIndentedWrappedText(AExplanation.Explanation, '  ');
  end;

  if AIncludeTranscript and (AExplanation.Transcript <> '') then
  begin
    Writeln;
    Writeln('Transcript:');
    WriteIndentedWrappedText(AExplanation.Transcript, '  ');
  end;
end;

function Run(const AOptions: TXkcdOptions): Integer;
var
  LCachePath: string;
  LCacheDir: string;
  LCache: TXkcdCache;
  LMeta: TXkcdComicMeta;
  LImgSrc, LSubText: string;
  LImgCachePath: string;
  LWidth: Integer;
  LConnection: TFDConnection;
begin
  Result := 0;
  LCachePath := CachePath(AOptions.CacheFilename);
  LCacheDir  := ExtractFileDir(LCachePath);
  ForceDirectories(LCacheDir);
  ForceDirectories(ExtractFileDir(ComicImageCachePath(0)));
  ForceDirectories(ExtractFileDir(ComicDetailCachePath(0)));

  LConnection := CreateConnection(DatabasePath(AOptions.DbFilename));
  try
    InitializeDatabase(LConnection);
  except
    LConnection.Free;
    raise;
  end;
  try
  if AOptions.SubCommand = 'update-cache' then
  begin
    Writeln('Fetching archive...');
    LCache.LastUpdated := Now;
    LCache.Comics      := ParseArchive(FetchArchiveHtml);
    SaveCache(LCache, LCachePath);
    for var LComicMeta in LCache.Comics do
      UpsertComicMeta(LConnection, LComicMeta);
    if AOptions.IncludeExplanation or AOptions.IncludeTranscript then
    begin
      var LExplainedCount := UpdateExplainedCache(LConnection, LCache.Comics,
        AOptions.ComicID, AOptions.NoCache, AOptions.IncludeExplanation, AOptions.IncludeTranscript);
      Writeln(Format('Explain XKCD updated: %d pages', [LExplainedCount]));
    end;
    Writeln(Format('Cache updated: %d comics', [Length(LCache.Comics)]));
    Exit;
  end;

  if AOptions.SubCommand = 'search' then
  begin
    var LResults := SearchComics(LConnection, AOptions.SearchQuery);
    if Length(LResults) = 0 then
    begin
      Writeln(Format('No matches for "%s"', [AOptions.SearchQuery]));
      Exit;
    end;

    for var LSearchResult in LResults do
    begin
      Writeln(Format('#%d: %s', [LSearchResult.ComicID, LSearchResult.Title]));
      
      if AOptions.IncludeExplanation and (LSearchResult.Explanation <> '') then
      begin
        Writeln('Explanation:');
        WriteIndentedWrappedText(LSearchResult.Explanation, '  ');
      end;

      if AOptions.IncludeTranscript and (LSearchResult.Transcript <> '') then
      begin
        Writeln('Transcript:');
        WriteIndentedWrappedText(LSearchResult.Transcript, '  ');
      end;
    end;
    Exit;
  end;

  var LNeedsRefresh := AOptions.NoCache or not CacheExists(LCachePath);
  if not LNeedsRefresh then
  begin
    LCache := LoadCache(LCachePath);
    LNeedsRefresh := IsStale(LCache.LastUpdated);
  end;
  if LNeedsRefresh then
  begin
    Writeln('Refreshing cache...');
    LCache.LastUpdated := Now;
    LCache.Comics      := ParseArchive(FetchArchiveHtml);
    SaveCache(LCache, LCachePath);
    for var LComicMeta in LCache.Comics do
      UpsertComicMeta(LConnection, LComicMeta);
  end;

  if Length(LCache.Comics) = 0 then
    raise EXkcdError.Create('No comics in cache');

  if AOptions.ComicID > 0 then
    LMeta := FindComicByID(LCache.Comics, AOptions.ComicID)
  else if AOptions.SubCommand = 'random' then
  begin
    Randomize;
    LMeta := LCache.Comics[Random(Length(LCache.Comics))];
  end
  else
    LMeta := LCache.Comics[0];

  Result := LMeta.ID;

  if AOptions.NoCache or not LoadComicDetail(LMeta.ID, LImgSrc, LSubText) then
  begin
    ParseComicPage(FetchComicHtml(LMeta.ID), LImgSrc, LSubText);
    SaveComicDetail(LMeta.ID, LImgSrc, LSubText);
  end;
  var LComic: TXkcdComic;
  LComic.Meta := LMeta;
  LComic.ImgSrc := LImgSrc;
  LComic.SubText := LSubText;
  UpsertComicDetail(LConnection, LComic);

  Writeln(Format('#%d: %s', [LMeta.ID, LMeta.Title]));
  Writeln;

  LImgCachePath := ComicImageCachePath(LMeta.ID);
  if not TFile.Exists(LImgCachePath) then
    FetchImageToFile(LImgSrc, LImgCachePath);

  if AOptions.NoTerminalGraphics then
    OpenWithOsViewer(LImgCachePath)
  else
  begin
    LWidth := AOptions.Width;
    if LWidth <= 0 then
    begin
      var LTermSize := QueryTerminalSize;
      if LTermSize.WidthPx > 0 then
        LWidth := LTermSize.WidthPx * 9 div 10
      else
        LWidth := 1200;
    end;

    var LProtocol: TTerminalProtocol;
    if not LoadCachedProtocol(LCacheDir, LProtocol) then
    begin
      LProtocol := DetectProtocol;
      SaveCachedProtocol(LCacheDir, LProtocol);
    end;
    DisplayImage(LImgCachePath, LProtocol, LWidth, AOptions.Invert);
  end;

  Writeln;
  WriteWrappedText(LSubText);
  if AOptions.IncludeExplanation or AOptions.IncludeTranscript then
    WriteExplanation(LoadOrFetchExplanation(LConnection, LMeta, AOptions.NoCache),
      AOptions.IncludeExplanation, AOptions.IncludeTranscript);
  finally
    LConnection.Free;
  end;
end;

end.
