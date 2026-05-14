// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testXkcdConsole;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdConsole = class
  public
    [Test]
    procedure WrapTextAtWordsBreaksOnSpaces;
    [Test]
    procedure WrapTextAtWordsPreservesExistingLines;
    [Test]
    procedure WrapTextAtWordsKeepsLongWordsWhole;
  end;

implementation

uses
  System.SysUtils,
  xkcdconsole;

procedure TTestXkcdConsole.WrapTextAtWordsBreaksOnSpaces;
begin
  Assert.AreEqual(
    'alpha beta' + sLineBreak + 'gamma',
    WrapTextAtWords('alpha beta gamma', 10));
end;

procedure TTestXkcdConsole.WrapTextAtWordsPreservesExistingLines;
begin
  Assert.AreEqual(
    'alpha' + sLineBreak + 'beta gamma',
    WrapTextAtWords('alpha' + sLineBreak + 'beta gamma', 20));
end;

procedure TTestXkcdConsole.WrapTextAtWordsKeepsLongWordsWhole;
begin
  Assert.AreEqual(
    'supercalifragilistic',
    WrapTextAtWords('supercalifragilistic', 8));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdConsole);

end.
