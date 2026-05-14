// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testXkcdArgs;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdArgs = class
  public
    [Test]
    procedure ShowLatestParsesCorrectly;
    [Test]
    procedure ShowComicIdParsesCorrectly;
    [Test]
    procedure ShowPositionalComicIdParsesCorrectly;
    [Test]
    procedure ShowRejectsInvalidPositionalComicId;
    [Test]
    procedure ShowExplainedParsesCorrectly;
    [Test]
    procedure ShowTranscriptParsesCorrectly;
    [Test]
    procedure UpdateCacheParsesCorrectly;
    [Test]
    procedure UpdateCacheExplainedParsesCorrectly;
    [Test]
    procedure UpdateCacheTranscriptParsesCorrectly;
    [Test]
    procedure NoTerminalGraphicsFlagParsed;
    [Test]
    procedure CacheFilenameParsed;
    [Test]
    procedure DbFilenameParsed;
    [Test]
    procedure NoCacheFlagParsed;
    [Test]
    procedure UnknownCommandRaisesArgError;
    [Test]
    procedure UnknownFlagRaisesArgError;
    [Test]
    procedure MissingComicIdValueRaisesArgError;
    [Test]
    procedure NoArgsDefaultsToShowLatest;
    [Test]
    procedure InvertDefaultsToTrue;
    [Test]
    procedure NoInvertFlagDisablesInvert;
    [Test]
    procedure RandomCommandParsesCorrectly;
    [Test]
    procedure SearchCommandParsesQuery;
    [Test]
    procedure SearchCommandRequiresQuery;
  end;

implementation

uses xkcdargs, xkcdmodel, System.SysUtils;

procedure TTestXkcdArgs.ShowLatestParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--latest']);
  Assert.AreEqual('show', LOptions.SubCommand);
  Assert.IsTrue(LOptions.ShowLatest);
  Assert.AreEqual(-1, LOptions.ComicID);
  Assert.IsFalse(LOptions.NoTerminalGraphics);
end;

procedure TTestXkcdArgs.ShowComicIdParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--comic-id', '42']);
  Assert.AreEqual('show', LOptions.SubCommand);
  Assert.AreEqual(42, LOptions.ComicID);
  Assert.IsFalse(LOptions.ShowLatest);
end;

procedure TTestXkcdArgs.ShowPositionalComicIdParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '747']);
  Assert.AreEqual('show', LOptions.SubCommand);
  Assert.AreEqual(747, LOptions.ComicID);
end;

procedure TTestXkcdArgs.ShowRejectsInvalidPositionalComicId;
begin
  Assert.WillRaise(
    procedure begin ParseArgs(['show', 'sandwich']); end,
    EXkcdArgError);
end;

procedure TTestXkcdArgs.ShowExplainedParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '149', '--explained']);
  Assert.AreEqual('show', LOptions.SubCommand);
  Assert.AreEqual(149, LOptions.ComicID);
  Assert.IsTrue(LOptions.IncludeExplanation);
  Assert.IsFalse(LOptions.IncludeTranscript);
end;

procedure TTestXkcdArgs.ShowTranscriptParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '149', '--transcript']);
  Assert.AreEqual('show', LOptions.SubCommand);
  Assert.AreEqual(149, LOptions.ComicID);
  Assert.IsFalse(LOptions.IncludeExplanation);
  Assert.IsTrue(LOptions.IncludeTranscript);
end;

procedure TTestXkcdArgs.UpdateCacheParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['update-cache']);
  Assert.AreEqual('update-cache', LOptions.SubCommand);
end;

procedure TTestXkcdArgs.UpdateCacheExplainedParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['update-cache', '--explained', '--comic-id', '149']);
  Assert.AreEqual('update-cache', LOptions.SubCommand);
  Assert.IsTrue(LOptions.IncludeExplanation);
  Assert.IsFalse(LOptions.IncludeTranscript);
  Assert.AreEqual(149, LOptions.ComicID);
end;

procedure TTestXkcdArgs.UpdateCacheTranscriptParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['update-cache', '--transcript', '--comic-id', '149']);
  Assert.AreEqual('update-cache', LOptions.SubCommand);
  Assert.IsFalse(LOptions.IncludeExplanation);
  Assert.IsTrue(LOptions.IncludeTranscript);
  Assert.AreEqual(149, LOptions.ComicID);
end;

procedure TTestXkcdArgs.NoTerminalGraphicsFlagParsed;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--latest', '--no-terminal-graphics']);
  Assert.IsTrue(LOptions.NoTerminalGraphics);
end;

procedure TTestXkcdArgs.CacheFilenameParsed;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--latest', '--cache-filename', 'C:\my\cache.json']);
  Assert.AreEqual('C:\my\cache.json', LOptions.CacheFilename);
end;

procedure TTestXkcdArgs.DbFilenameParsed;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['search', 'standards', '--db-filename', 'C:\my\xkcd.sqlite']);
  Assert.AreEqual('C:\my\xkcd.sqlite', LOptions.DbFilename);
end;

procedure TTestXkcdArgs.NoCacheFlagParsed;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--latest', '--no-cache']);
  Assert.IsTrue(LOptions.NoCache);
end;

procedure TTestXkcdArgs.UnknownCommandRaisesArgError;
begin
  Assert.WillRaise(
    procedure begin ParseArgs(['fly']); end,
    EXkcdArgError);
end;

procedure TTestXkcdArgs.UnknownFlagRaisesArgError;
begin
  Assert.WillRaise(
    procedure begin ParseArgs(['show', '--explode']); end,
    EXkcdArgError);
end;

procedure TTestXkcdArgs.MissingComicIdValueRaisesArgError;
begin
  Assert.WillRaise(
    procedure begin ParseArgs(['show', '--comic-id']); end,
    EXkcdArgError);
end;

procedure TTestXkcdArgs.NoArgsDefaultsToShowLatest;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs([]);
  Assert.AreEqual('show', LOptions.SubCommand);
  Assert.IsTrue(LOptions.ShowLatest);
end;

procedure TTestXkcdArgs.InvertDefaultsToTrue;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--latest']);
  Assert.IsTrue(LOptions.Invert);
end;

procedure TTestXkcdArgs.NoInvertFlagDisablesInvert;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--latest', '--no-invert']);
  Assert.IsFalse(LOptions.Invert);
end;

procedure TTestXkcdArgs.RandomCommandParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['random']);
  Assert.AreEqual('random', LOptions.SubCommand);
  Assert.IsTrue(LOptions.Invert);
end;

procedure TTestXkcdArgs.SearchCommandParsesQuery;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['search', 'color', 'perception']);
  Assert.AreEqual('search', LOptions.SubCommand);
  Assert.AreEqual('color perception', LOptions.SearchQuery);
end;

procedure TTestXkcdArgs.SearchCommandRequiresQuery;
begin
  Assert.WillRaise(
    procedure begin ParseArgs(['search']); end,
    EXkcdArgError);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdArgs);

end.
