// Copyright © 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit sixelapi;

// Sixel (Six Pixel) Terminal graphics API

interface

uses System.SysUtils;

type
  TRGBColor = record
    R, G, B: Byte;
  end;

procedure DisplayImageAsSixel(const AFileName: string; AMaxWidth: Integer = 800;
  AInvert: Boolean = False);
function MakeQuantKey(const AR, AG, AB: Byte): Word;
function ColorDist(const AA, AB: TRGBColor): Int64;

implementation

uses
  System.Skia,
  System.Types,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Math;

type
  TColorBucket = record
    Color: TRGBColor;
    Count: Integer;
  end;

function MakeQuantKey(const AR, AG, AB: Byte): Word; inline;
begin
  Result := ((AR shr 3) shl 10) or ((AG shr 3) shl 5) or (AB shr 3);
end;

function ColorDist(const AA, AB: TRGBColor): Int64; inline;
var
  LDR, LDG, LDB: Integer;
begin
  LDR := AA.R - AB.R;
  LDG := AA.G - AB.G;
  LDB := AA.B - AB.B;
  Result := Int64(LDR) * LDR + Int64(LDG) * LDG + Int64(LDB) * LDB;
end;

procedure DisplayImageAsSixel(const AFileName: string; AMaxWidth: Integer;
  AInvert: Boolean);
const
  CMAX_COLORS = 256;
var
  LSrcImage: ISkImage;
  LSurface: ISkSurface;
  LSrcW, LSrcH, LW, LH: Integer;
  LRowBytes: Integer;
  LPixelBuf: TArray<Byte>;
  LPixelVal: Cardinal;
  LColor: TRGBColor;
  LQKey: Word;
  LBucket: TColorBucket;
  LFreqMap: TDictionary<Word, TColorBucket>;
  LFreqList: TList<TColorBucket>;
  LPalette: array of TRGBColor;
  LPaletteSize: Integer;
  LIndexMap: TDictionary<Word, Integer>;
  LPixels: array of Integer;
  LNumBands, LBand, LBit, LCI: Integer;
  LX, LY: Integer;
  LBandSixel: array of Byte;
  LColorUsed: array of Boolean;
  LOutput: TStringBuilder;
  LPalIdx, LBestIdx: Integer;
  LBestDist, LDist: Int64;
  LPrevChar, LCurChar: Byte;
  LRunLen, i: Integer;
  LFirstColor: Boolean;
  LPair: TPair<Word, TColorBucket>;
  LInfo: TSkImageInfo;
  LPaint: ISkPaint;
begin
  LSrcImage := TSkImage.MakeFromEncodedFile(AFileName);
  if LSrcImage = nil then
    raise Exception.CreateFmt('Cannot load image: %s', [AFileName]);

  LSrcW := LSrcImage.Width;
  LSrcH := LSrcImage.Height;

  if LSrcW > AMaxWidth then
  begin
    LW := AMaxWidth;
    LH := Round(LSrcH * (AMaxWidth / LSrcW));
  end
  else
  begin
    LW := LSrcW;
    LH := LSrcH;
  end;
  LH := (LH + 5) div 6 * 6;

  // Render scaled image onto a white raster surface
  LInfo := TSkImageInfo.Create(LW, LH, TSkColorType.BGRA8888, TSkAlphaType.Opaque);
  LSurface := TSkSurface.MakeRaster(LInfo);
  if LSurface = nil then
    raise Exception.Create('Cannot create raster surface');

  if AInvert then
  begin
    LPaint := TSkPaint.Create;
    LPaint.ColorFilter := TSkColorFilter.MakeMatrix(
      TSkColorMatrix.Create(-1,0,0,0,1, 0,-1,0,0,1, 0,0,-1,0,1, 0,0,0,1,0));
  end;
  LSurface.Canvas.Clear($FFFFFFFF);
  LSurface.Canvas.DrawImageRect(LSrcImage,
    TRectF.Create(0, 0, LW, LH),
    TSkSamplingOptions.High, LPaint);

  // Read BGRA8888 pixels (stored as $AARRGGBB Cardinal in little-endian)
  LRowBytes := NativeUInt(LW) * SizeOf(Cardinal);
  SetLength(LPixelBuf, LH * LRowBytes);
  if not LSurface.ReadPixels(LInfo, @LPixelBuf[0], NativeUInt(LRowBytes)) then
    raise Exception.Create('Cannot read surface pixels');

  // Pass 1: frequency analysis with 5-bit quantization per channel
  LFreqMap := TDictionary<Word, TColorBucket>.Create(32768);
  try
    for LY := 0 to LH - 1 do
    begin
      for LX := 0 to LW - 1 do
      begin
        LPixelVal := PCardinal(@LPixelBuf[LY * LRowBytes + LX * SizeOf(Cardinal)])^;
        LColor.R := (LPixelVal shr 16) and $FF;
        LColor.G := (LPixelVal shr 8) and $FF;
        LColor.B := LPixelVal and $FF;
        LQKey := MakeQuantKey(LColor.R, LColor.G, LColor.B);
        if LFreqMap.TryGetValue(LQKey, LBucket) then
        begin
          Inc(LBucket.Count);
          LFreqMap[LQKey] := LBucket;
        end
        else
        begin
          LBucket.Color := LColor;
          LBucket.Count := 1;
          LFreqMap.Add(LQKey, LBucket);
        end;
      end;
    end;

    // Sort by frequency descending, take top CMAX_COLORS
    LFreqList := TList<TColorBucket>.Create(
      TDelegatedComparer<TColorBucket>.Create(
        function(const A, B: TColorBucket): Integer
        begin
          Result := B.Count - A.Count;
        end));
    try
      for LPair in LFreqMap do
        LFreqList.Add(LPair.Value);
      LFreqList.Sort;

      LPaletteSize := Min(LFreqList.Count, CMAX_COLORS);
      SetLength(LPalette, LPaletteSize);
      for i := 0 to LPaletteSize - 1 do
        LPalette[i] := LFreqList[i].Color;
    finally
      LFreqList.Free;
    end;

    // Map each quantized bucket to its nearest palette index
    LIndexMap := TDictionary<Word, Integer>.Create(LFreqMap.Count);
    try
      for LPair in LFreqMap do
      begin
        LBestDist := High(Int64);
        LBestIdx := 0;
        for i := 0 to LPaletteSize - 1 do
        begin
          LDist := ColorDist(LPair.Value.Color, LPalette[i]);
          if LDist < LBestDist then
          begin
            LBestDist := LDist;
            LBestIdx := i;
          end;
        end;
        LIndexMap.Add(LPair.Key, LBestIdx);
      end;

      // Pass 2: assign every pixel a palette index
      SetLength(LPixels, LW * LH);
      for LY := 0 to LH - 1 do
      begin
        for LX := 0 to LW - 1 do
        begin
          LPixelVal := PCardinal(@LPixelBuf[LY * LRowBytes + LX * SizeOf(Cardinal)])^;
          LColor.R := (LPixelVal shr 16) and $FF;
          LColor.G := (LPixelVal shr 8) and $FF;
          LColor.B := LPixelVal and $FF;
          LQKey := MakeQuantKey(LColor.R, LColor.G, LColor.B);
          LPixels[LY * LW + LX] := LIndexMap[LQKey];
        end;
      end;
    finally
      LIndexMap.Free;
    end;
  finally
    LFreqMap.Free;
  end;

  // Encode as sixel
  LOutput := TStringBuilder.Create;
  try
    LOutput.Append(#27'P0;1;0q');
    LOutput.Append('"1;1;').Append(LW).Append(';').Append(LH);

    for i := 0 to LPaletteSize - 1 do
      LOutput.Append(Format('#%d;2;%d;%d;%d',
        [i,
         Round(LPalette[i].R * 100.0 / 255),
         Round(LPalette[i].G * 100.0 / 255),
         Round(LPalette[i].B * 100.0 / 255)]));

    LNumBands := LH div 6;
    SetLength(LBandSixel, LW * LPaletteSize);
    SetLength(LColorUsed, LPaletteSize);

    for LBand := 0 to LNumBands - 1 do
    begin
      FillChar(LBandSixel[0], Length(LBandSixel), 0);
      FillChar(LColorUsed[0], LPaletteSize, 0);

      for LBit := 0 to 5 do
      begin
        LY := LBand * 6 + LBit;
        if LY < LH then
        begin
          for LX := 0 to LW - 1 do
          begin
            LPalIdx := LPixels[LY * LW + LX];
            LBandSixel[LX * LPaletteSize + LPalIdx] :=
              LBandSixel[LX * LPaletteSize + LPalIdx] or (1 shl LBit);
            LColorUsed[LPalIdx] := True;
          end;
        end;
      end;

      LFirstColor := True;
      for LCI := 0 to LPaletteSize - 1 do
      begin
        if not LColorUsed[LCI] then
          Continue;
        if not LFirstColor then
          LOutput.Append('$');
        LFirstColor := False;

        LOutput.Append('#').Append(LCI);

        LPrevChar := $FF;
        LRunLen := 0;
        for LX := 0 to LW - 1 do
        begin
          LCurChar := LBandSixel[LX * LPaletteSize + LCI] + 63;
          if LPrevChar = $FF then
          begin
            LPrevChar := LCurChar;
            LRunLen := 1;
          end
          else if LCurChar = LPrevChar then
            Inc(LRunLen)
          else
          begin
            if LRunLen > 3 then
              LOutput.Append('!').Append(LRunLen).Append(Chr(LPrevChar))
            else
              for i := 0 to LRunLen - 1 do
                LOutput.Append(Chr(LPrevChar));
            LPrevChar := LCurChar;
            LRunLen := 1;
          end;
        end;
        if LRunLen > 0 then
        begin
          if LRunLen > 3 then
            LOutput.Append('!').Append(LRunLen).Append(Chr(LPrevChar))
          else
            for i := 0 to LRunLen - 1 do
              LOutput.Append(Chr(LPrevChar));
        end;
      end;

      LOutput.Append('-');
    end;

    LOutput.Append(#27'\');

    Write(LOutput.ToString);
    Flush(Output);
  finally
    LOutput.Free;
  end;
end;

end.
