unit kittieapi;

interface

uses System.SysUtils;

function EncodeImageAsKitty(const APngBytes: TBytes): string;
procedure DisplayImageAsKitty(const AFileName: string; AMaxWidth: Integer = 800;
  AInvert: Boolean = False);

implementation

uses
  System.NetEncoding,
  System.Math,
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

function EncodeImageAsKitty(const APngBytes: TBytes): string;
const
  CChunkSize = 4096;
var
  LBase64: string;
  LPos, LLen: Integer;
  LSb: TStringBuilder;
  LIsFirst, LIsLast: Boolean;
  LM: string;
begin
  if APngBytes = nil then
    Exit('');

  LBase64  := Base64NoBr(APngBytes);
  LSb      := TStringBuilder.Create;
  LIsFirst := True;
  try
    LPos := 1;
    while LPos <= Length(LBase64) do
    begin
      LLen    := Min(CChunkSize, Length(LBase64) - LPos + 1);
      LIsLast := (LPos + LLen - 1) >= Length(LBase64);
      if LIsLast then LM := '0' else LM := '1';

      if LIsFirst then
        LSb.Append(#$1B + '_G a=T,f=100,q=2,m=' + LM + ';')
      else
        LSb.Append(#$1B + '_G m=' + LM + ';');

      LSb.Append(LBase64.Substring(LPos - 1, LLen));
      LSb.Append(#$1B + '\');

      Inc(LPos, LLen);
      LIsFirst := False;
    end;
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

procedure DisplayImageAsKitty(const AFileName: string; AMaxWidth: Integer;
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
  LSurface.Canvas.DrawImageRect(LSrc, TRectF.Create(0, 0, LW, LH),
    TSkSamplingOptions.High, LPaint);

  LPngBytes := LSurface.MakeImageSnapshot.Encode(TSkEncodedImageFormat.PNG, 100);

  Write(EncodeImageAsKitty(LPngBytes));
  Flush(Output);
  Writeln;
end;

end.
