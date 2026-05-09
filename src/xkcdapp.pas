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
  Posix.Stdlib.system(PAnsiChar(AnsiString('xdg-open "' + AFileName + '"')));
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
  else
    LMeta := LCache.Comics[0];

  ParseComicPage(FetchComicHtml(LMeta.ID), LImgSrc, LSubText);

  Writeln(Format('#%d: %s', [LMeta.ID, LMeta.Title]));
  Writeln(LSubText);
  Writeln;

  LImgCachePath := ComicImageCachePath(LMeta.ID);
  if not TFile.Exists(LImgCachePath) then
    FetchImageToFile(LImgSrc, LImgCachePath);

  if AOptions.NoTerminalGraphics then
    OpenWithOsViewer(LImgCachePath)
  else
  begin
    LWidth := AOptions.Width;
    if LWidth <= 0 then LWidth := 800;
    AutoDisplayImage(LImgCachePath, LWidth);
  end;
end;

end.
