// Copyright © 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testXkcdHttp;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdHttp = class
  public
    [Test]
    [Category('Integration')]
    procedure FetchArchiveReturnsHtml;
    [Test]
    [Category('Integration')]
    procedure FetchComicOneHasKnownTitle;
    [Test]
    [Category('Integration')]
    procedure FetchImageToFileCreatesFile;
  end;

implementation

uses
  xkcdhttp, xkcdhtml, xkcdmodel,
  System.SysUtils, System.IOUtils;

procedure TTestXkcdHttp.FetchArchiveReturnsHtml;
var
  LHtml: string;
  LComics: TArray<TXkcdComicMeta>;
begin
  LHtml   := FetchArchiveHtml;
  LComics := ParseArchive(LHtml);
  Assert.IsTrue(Integer(Length(LComics)) > 100, 'Archive should have >100 comics');
  Assert.IsTrue(LHtml.Contains('xkcd'), 'Response should contain xkcd');
end;

procedure TTestXkcdHttp.FetchComicOneHasKnownTitle;
var
  LHtml: string;
  LImgSrc, LSubText: string;
begin
  LHtml := FetchComicHtml(1);
  ParseComicPage(LHtml, LImgSrc, LSubText);
  Assert.IsTrue(LImgSrc.Contains('barrel'), 'Comic 1 image should be barrel');
end;

procedure TTestXkcdHttp.FetchImageToFileCreatesFile;
var
  LPath, LHtml, LImgSrc, LSubText: string;
begin
  LHtml := FetchComicHtml(1);
  ParseComicPage(LHtml, LImgSrc, LSubText);
  LPath := TPath.Combine(TPath.GetTempPath, 'xkcd_http_test.jpg');
  try
    FetchImageToFile(LImgSrc, LPath);
    Assert.IsTrue(TFile.Exists(LPath), 'Image file should exist after download');
    Assert.IsTrue(TFile.GetSize(LPath) > 1000, 'Image should be non-trivially large');
  finally
    if TFile.Exists(LPath) then TFile.Delete(LPath);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdHttp);

end.
