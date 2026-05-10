// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit iterm2api;

interface

uses System.SysUtils;

function EncodeImageAsITerm(const APngBytes: TBytes): string;
procedure DisplayImageAsITerm(const AFileName: string; AMaxWidth: Integer = 800;
  AInvert: Boolean = False);

implementation

uses
  System.NetEncoding,
  System.UITypes,
  System.Skia,
  System.Types;

function Base64NoBr(const AData: TBytes): string;
var
  LEnc: TBase64Encoding;
begin
  LEnc := TBase64Encoding.Create(0);
  try
    Result := LEnc.EncodeBytesToString(AData);
  finally
    LEnc.Free;
  end;
end;

function EncodeImageAsITerm(const APngBytes: TBytes): string;
begin
  if APngBytes = nil then
    Exit('');
  Result := #$1B + ']1337;File=inline=1;width=auto:' +
            Base64NoBr(APngBytes) + #7;
end;

procedure DisplayImageAsITerm(const AFileName: string; AMaxWidth: Integer;
  AInvert: Boolean);
var
  LSrc: ISkImage;
  LSurface: ISkSurface;
  LSrcW, LSrcH, LW, LH: Integer;
  LInfo: TSkImageInfo;
  LPngBytes: TBytes;
  LPaint: ISkPaint;
begin
  LSrc := TSkImage.MakeFromEncodedFile(AFileName);
  if not Assigned(LSrc) then
    raise Exception.CreateFmt('Cannot load image: %s', [AFileName]);
  LSrcW := LSrc.Width;
  LSrcH := LSrc.Height;
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
  if AInvert then
  begin
    LPaint := TSkPaint.Create;
    LPaint.ColorFilter := TSkColorFilter.MakeMatrix(
      TSkColorMatrix.Create(-1,0,0,0,1, 0,-1,0,0,1, 0,0,-1,0,1, 0,0,0,1,0));
  end;
  LInfo    := TSkImageInfo.Create(LW, LH, TSkColorType.BGRA8888, TSkAlphaType.Opaque);
  LSurface := TSkSurface.MakeRaster(LInfo);
  LSurface.Canvas.Clear($FFFFFFFF);
  LSurface.Canvas.DrawImageRect(LSrc, TRectF.Create(0, 0, LW, LH), TSkSamplingOptions.High, LPaint);
  LPngBytes := LSurface.MakeImageSnapshot.Encode(TSkEncodedImageFormat.PNG, 100);
  Write(EncodeImageAsITerm(LPngBytes));
  Flush(Output);
  Writeln;
end;

end.
