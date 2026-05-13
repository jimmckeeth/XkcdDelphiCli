// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testXkcdHtml;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdHtml = class
  public
    [Test]
    procedure ParseArchiveExtractsComics;
    [Test]
    procedure ParseArchiveReturnsEmptyWhenNoMatches;
    [Test]
    procedure ParseComicPageExtractsImgAndSubtext;
    [Test]
    procedure ParseComicPageExtractsWhenTitleBeforeSrc;
    [Test]
    procedure ParseComicPageRaisesOnMissingImg;
    [Test]
    procedure ParseComicPageRaisesOnMissingSrc;
    [Test]
    procedure ParseComicPageRaisesOnMissingTitle;
    [Test]
    procedure HtmlDecodeHandlesNamedEntities;
    [Test]
    procedure HtmlDecodeHandlesNumericEntities;
    [Test]
    procedure HtmlDecodeHandlesHexEntities;
    [Test]
    procedure HtmlDecodeHandlesSupplementaryPlaneEntities;
    [Test]
    procedure HtmlDecodeHandlesCommonUnicodeNamedEntities;
  end;

implementation

uses xkcdhtml, xkcdmodel, System.SysUtils;

const
  CSampleArchiveHtml =
    '<div id="middleContainer">' +
    '<a href="/3/" title="2006-1-1">Forgot to Hit Send</a>' +
    '<a href="/2/" title="2006-1-1">Game &amp; AIs</a>' +
    '<a href="/1/" title="2006-1-1">Barrel - Part 1</a>' +
    '</div>';

  CSampleComicHtml =
    '<div id="comic">' +
    '<img src="//imgs.xkcd.com/comics/barrel.jpg" ' +
    'title="Don&apos;t we all." /></div>';

  CSampleComicHtmlTitleFirst =
    '<div id="comic">' +
    '<img title="Don&apos;t we all." ' +
    'src="//imgs.xkcd.com/comics/barrel.jpg" /></div>';

procedure TTestXkcdHtml.ParseArchiveExtractsComics;
var
  LResult: TArray<TXkcdComicMeta>;
begin
  LResult := ParseArchive(CSampleArchiveHtml);
  Assert.AreEqual(3, Integer(Length(LResult)));
  Assert.AreEqual(3, LResult[0].ID);
  Assert.AreEqual('/3/', LResult[0].HRef);
  Assert.AreEqual('Forgot to Hit Send', LResult[0].Title);
  Assert.AreEqual(2, LResult[1].ID);
  Assert.AreEqual('Game & AIs', LResult[1].Title, 'Should decode &amp;');
  Assert.AreEqual(1, LResult[2].ID);
end;

procedure TTestXkcdHtml.ParseArchiveReturnsEmptyWhenNoMatches;
var
  LResult: TArray<TXkcdComicMeta>;
begin
  LResult := ParseArchive('<html><body>no comics here</body></html>');
  Assert.AreEqual(0, Integer(Length(LResult)));
end;

procedure TTestXkcdHtml.ParseComicPageExtractsImgAndSubtext;
var
  LImgSrc, LSubText: string;
begin
  ParseComicPage(CSampleComicHtml, LImgSrc, LSubText);
  Assert.AreEqual('https://imgs.xkcd.com/comics/barrel.jpg', LImgSrc);
  Assert.AreEqual('Don''t we all.', LSubText, 'Should decode &apos; (&#39;)');
end;

procedure TTestXkcdHtml.ParseComicPageExtractsWhenTitleBeforeSrc;
var
  LImgSrc, LSubText: string;
begin
  ParseComicPage(CSampleComicHtmlTitleFirst, LImgSrc, LSubText);
  Assert.AreEqual('https://imgs.xkcd.com/comics/barrel.jpg', LImgSrc);
  Assert.AreEqual('Don''t we all.', LSubText);
end;

procedure TTestXkcdHtml.ParseComicPageRaisesOnMissingImg;
var
  LImg, LSub: string;
begin
  Assert.WillRaise(
    procedure
    begin
      ParseComicPage('<html>no comic div</html>', LImg, LSub);
    end,
    EXkcdParseError);
end;

procedure TTestXkcdHtml.ParseComicPageRaisesOnMissingSrc;
var
  LImg, LSub: string;
begin
  Assert.WillRaise(
    procedure
    begin
      ParseComicPage('<div id="comic"><img title="oops"/></div>', LImg, LSub);
    end,
    EXkcdParseError);
end;

procedure TTestXkcdHtml.ParseComicPageRaisesOnMissingTitle;
var
  LImg, LSub: string;
begin
  Assert.WillRaise(
    procedure
    begin
      ParseComicPage('<div id="comic"><img src="//imgs.xkcd.com/comics/x.jpg"/></div>', LImg, LSub);
    end,
    EXkcdParseError);
end;

procedure TTestXkcdHtml.HtmlDecodeHandlesNamedEntities;
begin
  Assert.AreEqual('a & b < c > d "e"', HtmlDecode('a &amp; b &lt; c &gt; d &quot;e&quot;'));
  Assert.AreEqual('it''s', HtmlDecode('it&#39;s'));
end;

procedure TTestXkcdHtml.HtmlDecodeHandlesNumericEntities;
begin
  Assert.AreEqual('A', HtmlDecode('&#65;'));
  Assert.AreEqual(#169, HtmlDecode('&#169;'));
end;

procedure TTestXkcdHtml.HtmlDecodeHandlesHexEntities;
begin
  Assert.AreEqual('A', HtmlDecode('&#x41;'));
  Assert.AreEqual(#169, HtmlDecode('&#xA9;'));
end;

procedure TTestXkcdHtml.HtmlDecodeHandlesSupplementaryPlaneEntities;
var
  LSmile: string;
begin
  LSmile := string(WideChar($D83D)) + string(WideChar($DE00));
  Assert.AreEqual(LSmile, HtmlDecode('&#x1F600;'));
  Assert.AreEqual(LSmile, HtmlDecode('&#128512;'));
end;

procedure TTestXkcdHtml.HtmlDecodeHandlesCommonUnicodeNamedEntities;
begin
  Assert.AreEqual('that' + #$2019 + 's', HtmlDecode('that&rsquo;s'));
  Assert.AreEqual(#$201C + 'quoted' + #$201D, HtmlDecode('&ldquo;quoted&rdquo;'));
  Assert.AreEqual('wait' + #$2026, HtmlDecode('wait&hellip;'));
  Assert.AreEqual('a' + #$00A0 + 'b', HtmlDecode('a&nbsp;b'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdHtml);

end.
