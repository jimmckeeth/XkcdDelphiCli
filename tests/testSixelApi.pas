// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testSixelApi;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestSixelApi = class
  public
    [Test]
    procedure MakeQuantKeyBitLayout;
    [Test]
    procedure MakeQuantKeyBlackIsZero;
    [Test]
    procedure MakeQuantKeyWhiteIsMax;
    [Test]
    procedure ColorDistSameColorIsZero;
    [Test]
    procedure ColorDistBlackToWhiteIsMax;
    [Test]
    procedure ColorDistIsSymmetric;
  end;

implementation

uses sixelapi, System.SysUtils;

procedure TTestSixelApi.MakeQuantKeyBitLayout;
var
  LKey: Word;
begin
  // R=248 (11111000), G=0, B=0 → R shr 3 = 31 = %11111
  // Key = 31 shl 10 = %0111110000000000 = $7C00
  LKey := MakeQuantKey(248, 0, 0);
  Assert.AreEqual(Word($7C00), LKey, 'Full red should map to top 5 bits');
end;

procedure TTestSixelApi.MakeQuantKeyBlackIsZero;
begin
  Assert.AreEqual(Word(0), MakeQuantKey(0, 0, 0));
end;

procedure TTestSixelApi.MakeQuantKeyWhiteIsMax;
begin
  // 255 shr 3 = 31; key = 31<<10 | 31<<5 | 31 = $7FFF
  Assert.AreEqual(Word($7FFF), MakeQuantKey(255, 255, 255));
end;

procedure TTestSixelApi.ColorDistSameColorIsZero;
var
  LC: TRGBColor;
begin
  LC.R := 100; LC.G := 150; LC.B := 200;
  Assert.AreEqual(Int64(0), ColorDist(LC, LC));
end;

procedure TTestSixelApi.ColorDistBlackToWhiteIsMax;
var
  LBlack, LWhite: TRGBColor;
begin
  LBlack.R := 0;   LBlack.G := 0;   LBlack.B := 0;
  LWhite.R := 255; LWhite.G := 255; LWhite.B := 255;
  // dist = 255^2 + 255^2 + 255^2 = 195075
  Assert.AreEqual(Int64(195075), ColorDist(LBlack, LWhite));
end;

procedure TTestSixelApi.ColorDistIsSymmetric;
var
  LA, LB: TRGBColor;
begin
  LA.R := 10; LA.G := 20; LA.B := 30;
  LB.R := 50; LB.G := 60; LB.B := 70;
  Assert.AreEqual(ColorDist(LA, LB), ColorDist(LB, LA));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSixelApi);

end.
