unit xkcdapp;

interface

uses xkcdmodel;

procedure Run(const AOptions: TXkcdOptions);

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Math,
  xkcdcache,
  xkcdhttp,
  xkcdhtml,
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

procedure Run(const AOptions: TXkcdOptions);
var
  LCachePath: string;
  LCacheDir: string;
  LCache: TXkcdCache;
  LMeta: TXkcdComicMeta;
  LImgSrc, LSubText: string;
  LImgCachePath: string;
  LWidth: Integer;
begin
  LCachePath := CachePath(AOptions.CacheFilename);
  LCacheDir  := ExtractFileDir(LCachePath);
  ForceDirectories(LCacheDir);
  ForceDirectories(ExtractFileDir(ComicImageCachePath(0)));
  ForceDirectories(ExtractFileDir(ComicDetailCachePath(0)));

  if AOptions.SubCommand = 'update-cache' then
  begin
    Writeln('Fetching archive...');
    LCache.LastUpdated := Now;
    LCache.Comics      := ParseArchive(FetchArchiveHtml);
    SaveCache(LCache, LCachePath);
    Writeln(Format('Cache updated: %d comics', [Length(LCache.Comics)]));
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

  if not LoadComicDetail(LMeta.ID, LImgSrc, LSubText) then
  begin
    ParseComicPage(FetchComicHtml(LMeta.ID), LImgSrc, LSubText);
    SaveComicDetail(LMeta.ID, LImgSrc, LSubText);
  end;

  Writeln(Format('#%d: %s', [LMeta.ID, LMeta.Title]));
  Writeln;

  LImgCachePath := ComicImageCachePath(LMeta.ID);
  if not TFile.Exists(LImgCachePath) then
    FetchImageToFile(LImgSrc, LImgCachePath);

  if AOptions.Invert then
  begin
    var LInvPath := ComicImageInvertedCachePath(LMeta.ID);
    if not TFile.Exists(LInvPath) then
      SaveInvertedImage(LImgCachePath, LInvPath);
    LImgCachePath := LInvPath;
  end;

  LWidth := AOptions.Width;
  if LWidth <= 0 then
  begin
    var LTermSize := QueryTerminalSize;
    if LTermSize.WidthPx > 0 then
      LWidth := LTermSize.WidthPx * 9 div 10
    else
      LWidth := 1200;
  end;

  if AOptions.NoTerminalGraphics then
    OpenWithOsViewer(LImgCachePath)
  else
  begin
    var LProtocol: TTerminalProtocol;
    if not LoadCachedProtocol(LCacheDir, LProtocol) then
    begin
      LProtocol := DetectProtocol;
      SaveCachedProtocol(LCacheDir, LProtocol);
    end;
    DisplayImage(LImgCachePath, LProtocol, LWidth, False);
  end;

  Writeln;
  Writeln(LSubText);
end;

end.
