// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testXkcdCache;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdCache = class
  private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure CachePathUsesHomeDir;
    [Test]
    procedure CachePathReturnsOverrideWhenProvided;
    [Test]
    procedure ComicImageCachePathIncludesComicId;
    [Test]
    procedure IsStaleReturnsTrueAfter25Hours;
    [Test]
    procedure IsStaleReturnsFalseAt23Hours;
    [Test]
    procedure SaveAndLoadRoundtrip;
    [Test]
    procedure SaveAndLoadRoundtripPreservesUnicodeTitle;
    [Test]
    procedure ComicDetailRoundtripPreservesUnicodeSubText;
    [Test]
    procedure SaveCacheAllowsFilenameWithoutDirectory;
    [Test]
    procedure CacheExistsReturnsFalseForMissingFile;
  end;

implementation

uses
  xkcdcache, xkcdmodel,
  System.SysUtils, System.IOUtils, System.DateUtils,
  {$IFDEF MSWINDOWS}Winapi.Windows{$ELSE}Posix.Unistd{$ENDIF};

procedure TTestXkcdCache.Setup;
begin
  FTempFile := TPath.Combine(TPath.GetTempPath,
    'xkcd_test_cache_' + IntToStr(GetTickCount) + '.json');
end;

procedure TTestXkcdCache.TearDown;
begin
  if TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
end;

procedure TTestXkcdCache.CachePathUsesHomeDir;
var
  LPath: string;
begin
  LPath := CachePath;
  Assert.IsTrue(LPath.Contains('.cache'), 'Cache path should contain .cache');
  Assert.IsTrue(LPath.Contains('xkcd-cli'), 'Cache path should contain xkcd-cli');
  Assert.IsTrue(LPath.EndsWith('cache.json'), 'Cache path should end with cache.json');
end;

procedure TTestXkcdCache.CachePathReturnsOverrideWhenProvided;
begin
  Assert.AreEqual('C:\custom\path.json', CachePath('C:\custom\path.json'));
end;

procedure TTestXkcdCache.ComicImageCachePathIncludesComicId;
var
  LPath: string;
begin
  LPath := ComicImageCachePath(42);
  Assert.IsTrue(LPath.Contains('42.png'), 'Image path should include comic id + .png');
  Assert.IsTrue(LPath.Contains('xkcd-cli'), 'Image path should be in xkcd-cli dir');
end;

procedure TTestXkcdCache.IsStaleReturnsTrueAfter25Hours;
begin
  Assert.IsTrue(IsStale(Now - 1.1), '25+ hours old should be stale');
end;

procedure TTestXkcdCache.IsStaleReturnsFalseAt23Hours;
begin
  Assert.IsFalse(IsStale(Now - 0.9), '23 hours old should not be stale');
end;

procedure TTestXkcdCache.SaveAndLoadRoundtrip;
var
  LOriginal, LLoaded: TXkcdCache;
begin
  LOriginal.LastUpdated := EncodeDateTime(2024, 1, 15, 12, 0, 0, 0);
  SetLength(LOriginal.Comics, 2);
  LOriginal.Comics[0].ID    := 3;
  LOriginal.Comics[0].HRef  := '/3/';
  LOriginal.Comics[0].Title := 'Forgot to Hit Send';
  LOriginal.Comics[1].ID    := 1;
  LOriginal.Comics[1].HRef  := '/1/';
  LOriginal.Comics[1].Title := 'Barrel - Part 1';

  SaveCache(LOriginal, FTempFile);
  Assert.IsTrue(TFile.Exists(FTempFile), 'Cache file should exist after save');

  LLoaded := LoadCache(FTempFile);
  Assert.AreEqual(2, Integer(Length(LLoaded.Comics)));
  Assert.AreEqual(3, LLoaded.Comics[0].ID);
  Assert.AreEqual('/3/', LLoaded.Comics[0].HRef);
  Assert.AreEqual('Forgot to Hit Send', LLoaded.Comics[0].Title);
  Assert.AreEqual(1, LLoaded.Comics[1].ID);
end;

procedure TTestXkcdCache.SaveAndLoadRoundtripPreservesUnicodeTitle;
var
  LOriginal, LLoaded: TXkcdCache;
  LSmile: string;
begin
  LSmile := string(WideChar($D83D)) + string(WideChar($DE00));
  LOriginal.LastUpdated := EncodeDateTime(2024, 1, 15, 12, 0, 0, 0);
  SetLength(LOriginal.Comics, 1);
  LOriginal.Comics[0].ID    := 314;
  LOriginal.Comics[0].HRef  := '/314/';
  LOriginal.Comics[0].Title := 'Unicode ' + #$201C + 'caption' + #$201D + ' ' + LSmile;

  SaveCache(LOriginal, FTempFile);
  LLoaded := LoadCache(FTempFile);

  Assert.AreEqual(LOriginal.Comics[0].Title, LLoaded.Comics[0].Title);
end;

procedure TTestXkcdCache.ComicDetailRoundtripPreservesUnicodeSubText;
var
  LImgSrc, LSubText: string;
  LSmile: string;
begin
  LSmile := string(WideChar($D83D)) + string(WideChar($DE00));
  SaveComicDetail(999001, 'https://imgs.xkcd.com/comics/unicode.png',
    'that' + #$2019 + 's ' + #$201C + 'quoted' + #$201D + ' ' + LSmile);
  try
    Assert.IsTrue(LoadComicDetail(999001, LImgSrc, LSubText));
    Assert.AreEqual('https://imgs.xkcd.com/comics/unicode.png', LImgSrc);
    Assert.AreEqual('that' + #$2019 + 's ' + #$201C + 'quoted' + #$201D + ' ' + LSmile, LSubText);
  finally
    TFile.Delete(ComicDetailCachePath(999001));
  end;
end;

procedure TTestXkcdCache.SaveCacheAllowsFilenameWithoutDirectory;
var
  LOriginal: TXkcdCache;
  LLocalFile: string;
begin
  LLocalFile := 'xkcd_test_cache_bare_filename.json';
  LOriginal.LastUpdated := EncodeDateTime(2024, 1, 15, 12, 0, 0, 0);
  SetLength(LOriginal.Comics, 0);

  SaveCache(LOriginal, LLocalFile);
  try
    Assert.IsTrue(TFile.Exists(LLocalFile));
  finally
    if TFile.Exists(LLocalFile) then
      TFile.Delete(LLocalFile);
  end;
end;

procedure TTestXkcdCache.CacheExistsReturnsFalseForMissingFile;
begin
  Assert.IsFalse(CacheExists(FTempFile), 'File should not exist yet');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdCache);

end.
