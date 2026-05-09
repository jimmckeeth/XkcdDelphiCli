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
  LCache: TXkcdCache;
  LMeta: TXkcdComicMeta;
  LImgSrc, LSubText: string;
  LImgCachePath: string;
  LWidth: Integer;
begin
  LCachePath := CachePath(AOptions.CacheFilename);
  ForceDirectories(ExtractFileDir(LCachePath));
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

  if AOptions.NoCache or not CacheExists(LCachePath) or
     IsStale(LoadCache(LCachePath).LastUpdated) then
  begin
    Writeln('Refreshing cache...');
    LCache.LastUpdated := Now;
    LCache.Comics      := ParseArchive(FetchArchiveHtml);
    SaveCache(LCache, LCachePath);
  end
  else
    LCache := LoadCache(LCachePath);

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
    AutoDisplayImage(LImgCachePath, LWidth, False);

  Writeln;
  Writeln(LSubText);
end;

end.
