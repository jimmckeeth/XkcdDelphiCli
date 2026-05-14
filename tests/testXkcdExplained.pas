// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testXkcdExplained;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdExplained = class
  public
    [Test]
    procedure ExplainXkcdUrlUsesComicID;
    [Test]
    procedure ExplainXkcdUrlUsesCanonicalTitleSlug;
    [Test]
    procedure ExplainXkcdUrlEscapesTitleSlug;
    [Test]
    procedure ParseExplainPageUsesCanonicalTitleUrl;
    [Test]
    procedure ParseExplainPageExtractsExplanationAndTranscript;
    [Test]
    procedure ParseExplainPageHandlesH3Sections;
    [Test]
    procedure ParseExplainPagePreservesUnicodeText;
    [Test]
    procedure ParseExplainPageRemovesTranscriptFooterControls;
    [Test]
    procedure TryParseExplainPageAllowsMissingTranscript;
    [Test]
    procedure TryParseExplainPageReturnsFalseWhenSectionsMissing;
    [Test]
    procedure ParseExplainPageRaisesWhenSectionsMissing;
  end;

implementation

uses
  System.SysUtils,
  xkcdexplained,
  xkcdmodel;

const
  CSampleExplainHtml =
    '<html><body>' +
    '<h2><span class="mw-headline" id="Explanation">Explanation</span>' +
    '<span class="mw-editsection">[edit]</span></h2>' +
    '<p>For any engineering task, there are numerous ways a problem can be solved.</p>' +
    '<p>Attempts to unify standards often create another standard.</p>' +
    '<h2><span class="mw-headline" id="Transcript">Transcript</span>' +
    '<span class="mw-editsection">[edit]</span></h2>' +
    '<p>[A chart is labeled &quot;Standards&quot;.]<br />' +
    'Situation: there are 14 competing standards.</p>' +
    '<h2><span class="mw-headline" id="Trivia">Trivia</span></h2>' +
    '<p>Not part of transcript.</p>' +
    '</body></html>';

  CSampleH3ExplainHtml =
    '<h3><span id="Explanation">Explanation</span></h3>' +
    '<ul><li>First point</li><li>Second point</li></ul>' +
    '<h3><span id="Transcript">Transcript</span></h3>' +
    '<dl><dd>Single panel description.</dd></dl>';

procedure TTestXkcdExplained.ExplainXkcdUrlUsesComicID;
begin
  Assert.AreEqual('https://www.explainxkcd.com/wiki/index.php/927', ExplainXkcdUrl(927));
end;

procedure TTestXkcdExplained.ExplainXkcdUrlUsesCanonicalTitleSlug;
begin
  Assert.AreEqual('https://www.explainxkcd.com/wiki/index.php/2869:_Puzzles',
    ExplainXkcdUrl(2869, 'Puzzles'));
end;

procedure TTestXkcdExplained.ExplainXkcdUrlEscapesTitleSlug;
var
  LOmega: string;
begin
  LOmega := string(WideChar($03A9));
  Assert.AreEqual('https://www.explainxkcd.com/wiki/index.php/1:_A%2FB_%26_%CE%A9',
    ExplainXkcdUrl(1, 'A/B & ' + LOmega));
end;

procedure TTestXkcdExplained.ParseExplainPageUsesCanonicalTitleUrl;
var
  LResult: TXkcdExplanation;
begin
  LResult := ParseExplainPage(2869, 'Puzzles',
    '<h2><span id="Explanation">Explanation</span></h2><p>Logic puzzle.</p>');

  Assert.AreEqual('https://www.explainxkcd.com/wiki/index.php/2869:_Puzzles',
    LResult.ExplainUrl);
end;

procedure TTestXkcdExplained.ParseExplainPageExtractsExplanationAndTranscript;
var
  LResult: TXkcdExplanation;
begin
  LResult := ParseExplainPage(927, CSampleExplainHtml);

  Assert.AreEqual(927, LResult.ComicID);
  Assert.AreEqual(ExplainXkcdUrl(927), LResult.ExplainUrl);
  Assert.IsTrue(LResult.Explanation.Contains('numerous ways'));
  Assert.IsTrue(LResult.Explanation.Contains('another standard'));
  Assert.IsFalse(LResult.Explanation.Contains('[edit]'));
  Assert.IsTrue(LResult.Transcript.Contains('[A chart is labeled "Standards".]'));
  Assert.IsTrue(LResult.Transcript.Contains('14 competing standards'));
  Assert.IsFalse(LResult.Transcript.Contains('Not part of transcript'));
end;

procedure TTestXkcdExplained.ParseExplainPageHandlesH3Sections;
var
  LResult: TXkcdExplanation;
begin
  LResult := ParseExplainPage(1, CSampleH3ExplainHtml);

  Assert.IsTrue(LResult.Explanation.Contains('- First point'));
  Assert.IsTrue(LResult.Explanation.Contains('- Second point'));
  Assert.AreEqual('Single panel description.', LResult.Transcript);
end;

procedure TTestXkcdExplained.ParseExplainPagePreservesUnicodeText;
var
  LResult: TXkcdExplanation;
  LSmile: string;
begin
  LSmile := string(WideChar($D83D)) + string(WideChar($DE00));
  LResult := ParseExplainPage(314,
    '<h2><span id="Explanation">Explanation</span></h2>' +
    '<p>Randall&rsquo;s &ldquo;Unicode&rdquo; example &#x1F600;.</p>' +
    '<h2><span id="Transcript">Transcript</span></h2>' +
    '<p>Caption says: &#128512;</p>');

  Assert.IsTrue(LResult.Explanation.Contains('Randall' + #$2019 + 's'));
  Assert.IsTrue(LResult.Explanation.Contains(#$201C + 'Unicode' + #$201D));
  Assert.IsTrue(LResult.Explanation.Contains(LSmile));
  Assert.IsTrue(LResult.Transcript.Contains(LSmile));
end;

procedure TTestXkcdExplained.ParseExplainPageRemovesTranscriptFooterControls;
var
  LResult: TXkcdExplanation;
begin
  LResult := ParseExplainPage(149,
    '<h2><span id="Explanation">Explanation</span></h2><p>Sudo joke.</p>' +
    '<h2><span id="Transcript">Transcript</span></h2>' +
    '<p>Cueball: sudo Make me a sandwich.</p>' +
    '<div>Add comment &nbsp; Create topic (use sparingly) &nbsp; Refresh</div>');

  Assert.IsTrue(LResult.Transcript.Contains('sudo Make me a sandwich'));
  Assert.IsFalse(LResult.Transcript.Contains('Add comment'));
  Assert.IsFalse(LResult.Transcript.Contains('Create topic'));
  Assert.IsFalse(LResult.Transcript.Contains('Refresh'));
end;

procedure TTestXkcdExplained.TryParseExplainPageAllowsMissingTranscript;
var
  LResult: TXkcdExplanation;
begin
  Assert.IsTrue(TryParseExplainPage(42,
    '<h2><span id="Explanation">Explanation</span></h2><p>Only explanation.</p>',
    LResult));
  Assert.AreEqual('Only explanation.', LResult.Explanation);
  Assert.AreEqual('', LResult.Transcript);
end;

procedure TTestXkcdExplained.TryParseExplainPageReturnsFalseWhenSectionsMissing;
var
  LResult: TXkcdExplanation;
begin
  Assert.IsFalse(TryParseExplainPage(42, '<html><body>No useful sections.</body></html>', LResult));
end;

procedure TTestXkcdExplained.ParseExplainPageRaisesWhenSectionsMissing;
begin
  Assert.WillRaise(
    procedure
    begin
      ParseExplainPage(42, '<html><body>No useful sections.</body></html>');
    end,
    EXkcdParseError);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdExplained);

end.
