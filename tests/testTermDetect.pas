// Copyright © 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testTermDetect;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestTermDetect = class
  public
    [Test]
    procedure ParseDA1ReturnsTrueWhenSixelPresent;
    [Test]
    procedure ParseDA1ReturnsTrueWhenSixelAtEnd;
    [Test]
    procedure ParseDA1ReturnsFalseWhenNoSixel;
    [Test]
    procedure ParseDA1ReturnsFalseForEmptyString;
    [Test]
    procedure ParseOSC11ParsesFourDigitHex;
    [Test]
    procedure ParseOSC11ParsesTwoDigitHex;
    [Test]
    procedure ParseOSC11DarkBackground;
    [Test]
    procedure ParseTermSizeExtractsWidthAndHeight;
  end;

implementation

uses termdetectapi, System.SysUtils;

procedure TTestTermDetect.ParseDA1ReturnsTrueWhenSixelPresent;
begin
  Assert.IsTrue(ParseDA1Response(#$1B + '[?62;4;22c'));
end;

procedure TTestTermDetect.ParseDA1ReturnsTrueWhenSixelAtEnd;
begin
  Assert.IsTrue(ParseDA1Response(#$1B + '[?62;22;4c'));
end;

procedure TTestTermDetect.ParseDA1ReturnsFalseWhenNoSixel;
begin
  Assert.IsFalse(ParseDA1Response(#$1B + '[?62;22c'));
end;

procedure TTestTermDetect.ParseDA1ReturnsFalseForEmptyString;
begin
  Assert.IsFalse(ParseDA1Response(''));
end;

procedure TTestTermDetect.ParseOSC11ParsesFourDigitHex;
var
  LColor: TTerminalRGB;
begin
  LColor := ParseOSC11Response(#$1B + ']11;rgb:2020/2020/2020' + #7);
  Assert.AreEqual(32, Integer(LColor.R));
  Assert.AreEqual(32, Integer(LColor.G));
  Assert.AreEqual(32, Integer(LColor.B));
end;

procedure TTestTermDetect.ParseOSC11ParsesTwoDigitHex;
var
  LColor: TTerminalRGB;
begin
  LColor := ParseOSC11Response(#$1B + ']11;rgb:1a/1a/ff' + #7);
  Assert.AreEqual(26, Integer(LColor.R));
  Assert.AreEqual(26, Integer(LColor.G));
  Assert.AreEqual(255, Integer(LColor.B));
end;

procedure TTestTermDetect.ParseOSC11DarkBackground;
var
  LColor: TTerminalRGB;
begin
  LColor := ParseOSC11Response(#$1B + ']11;rgb:2020/2020/2020' + #7);
  Assert.IsTrue(IsDarkColor(LColor));
end;

procedure TTestTermDetect.ParseTermSizeExtractsWidthAndHeight;
var
  LSize: TTerminalSize;
begin
  LSize := ParseTermSizeResponse(#$1B + '[4;768;1024t');
  Assert.AreEqual(1024, LSize.WidthPx);
  Assert.AreEqual(768,  LSize.HeightPx);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestTermDetect);

end.
