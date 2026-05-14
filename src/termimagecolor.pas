// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit termimagecolor;

interface

function IsNeutralPixel(AR, AG, AB: Byte): Boolean;
function SelectiveInvertPixel(APixel: Cardinal): Cardinal;
procedure SelectiveInvertPixels(var APixels: TArray<Byte>; AWidth, AHeight,
  ARowBytes: Integer);

implementation

uses
  System.Math;

function IsNeutralPixel(AR, AG, AB: Byte): Boolean;
var
  LMinChannel, LMaxChannel: Byte;
begin
  LMinChannel := Min(AR, Min(AG, AB));
  LMaxChannel := Max(AR, Max(AG, AB));
  Result := LMaxChannel - LMinChannel <= 24;
end;

function SelectiveInvertPixel(APixel: Cardinal): Cardinal;
var
  LA, LR, LG, LB: Byte;
begin
  LA := (APixel shr 24) and $FF;
  LR := (APixel shr 16) and $FF;
  LG := (APixel shr 8) and $FF;
  LB := APixel and $FF;

  if IsNeutralPixel(LR, LG, LB) then
  begin
    LR := 255 - LR;
    LG := 255 - LG;
    LB := 255 - LB;
  end;

  Result := (Cardinal(LA) shl 24) or (Cardinal(LR) shl 16) or
    (Cardinal(LG) shl 8) or Cardinal(LB);
end;

procedure SelectiveInvertPixels(var APixels: TArray<Byte>; AWidth, AHeight,
  ARowBytes: Integer);
var
  LX, LY: Integer;
  LPixel: PCardinal;
begin
  for LY := 0 to AHeight - 1 do
  begin
    for LX := 0 to AWidth - 1 do
    begin
      LPixel := PCardinal(@APixels[LY * ARowBytes + LX * SizeOf(Cardinal)]);
      LPixel^ := SelectiveInvertPixel(LPixel^);
    end;
  end;
end;

end.
