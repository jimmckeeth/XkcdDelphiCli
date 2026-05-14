// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testTermImageColor;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestTermImageColor = class
  public
    [Test]
    procedure SelectiveInvertPixelInvertsBlackInk;
    [Test]
    procedure SelectiveInvertPixelInvertsWhiteBackground;
    [Test]
    procedure SelectiveInvertPixelLeavesColorAlone;
    [Test]
    procedure SelectiveInvertPixelPreservesAlpha;
  end;

implementation

uses
  termimagecolor;

procedure TTestTermImageColor.SelectiveInvertPixelInvertsBlackInk;
begin
  Assert.AreEqual(Cardinal($FFFFFFFF), SelectiveInvertPixel($FF000000));
end;

procedure TTestTermImageColor.SelectiveInvertPixelInvertsWhiteBackground;
begin
  Assert.AreEqual(Cardinal($FF000000), SelectiveInvertPixel($FFFFFFFF));
end;

procedure TTestTermImageColor.SelectiveInvertPixelLeavesColorAlone;
begin
  Assert.AreEqual(Cardinal($FFFF3366), SelectiveInvertPixel($FFFF3366));
end;

procedure TTestTermImageColor.SelectiveInvertPixelPreservesAlpha;
begin
  Assert.AreEqual(Cardinal($80DFDFDF), SelectiveInvertPixel($80202020));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestTermImageColor);

end.
