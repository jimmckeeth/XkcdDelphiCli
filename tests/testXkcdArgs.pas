// Copyright © 2026 by James McKeeth - Licensed GPL 3.0
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
    procedure UpdateCacheParsesCorrectly;
    [Test]
    procedure NoTerminalGraphicsFlagParsed;
    [Test]
    procedure CacheFilenameParsed;
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

procedure TTestXkcdArgs.UpdateCacheParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['update-cache']);
  Assert.AreEqual('update-cache', LOptions.SubCommand);
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

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdArgs);

end.
