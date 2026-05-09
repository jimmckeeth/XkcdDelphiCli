unit termimageapi;

interface

uses termdetectapi;

procedure DisplayImage(const AFileName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer = 800; AInvert: Boolean = False);

procedure AutoDisplayImage(const AFileName: string; AMaxWidth: Integer = 800;
  AInvert: Boolean = False);

procedure SaveInvertedImage(const ASrcPath, ADstPath: string);

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Types,
  System.Skia,
  sixelapi,
  kittieapi,
  itermapi
  {$IFDEF MSWINDOWS}
  , Winapi.ShellAPI, Winapi.Windows
  {$ELSE}
  , Posix.Stdlib
  {$ENDIF}
  ;

procedure OpenWithOsViewer(const AFileName: string);
begin
  {$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(AFileName), nil, nil, SW_SHOWNORMAL);
  {$ELSE}
  _system(PAnsiChar(AnsiString('xdg-open "' + AFileName + '"')));
  {$ENDIF}
end;

procedure DisplayImage(const AFileName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer; AInvert: Boolean);
begin
  case AProtocol of
    tpKittyPlus, tpKitty: DisplayImageAsKitty(AFileName, AMaxWidth, AInvert);
    tpITerm:              DisplayImageAsITerm(AFileName, AMaxWidth, AInvert);
    tpSixel:              DisplayImageAsSixel(AFileName, AMaxWidth, AInvert);
    tpNone:               OpenWithOsViewer(AFileName);
  end;
end;

procedure AutoDisplayImage(const AFileName: string; AMaxWidth: Integer;
  AInvert: Boolean);
begin
  DisplayImage(AFileName, DetectProtocol, AMaxWidth, AInvert);
end;

procedure SaveInvertedImage(const ASrcPath, ADstPath: string);
var
  LSrc: ISkImage;
  LSurface: ISkSurface;
  LInfo: TSkImageInfo;
  LPaint: ISkPaint;
  LPngBytes: TBytes;
begin
  LSrc := TSkImage.MakeFromEncodedFile(ASrcPath);
  if not Assigned(LSrc) then
    raise Exception.CreateFmt('Cannot load image: %s', [ASrcPath]);
  LInfo    := TSkImageInfo.Create(LSrc.Width, LSrc.Height, TSkColorType.BGRA8888, TSkAlphaType.Opaque);
  LSurface := TSkSurface.MakeRaster(LInfo);
  LPaint   := TSkPaint.Create;
  LPaint.ColorFilter := TSkColorFilter.MakeMatrix(
    TSkColorMatrix.Create(-1,0,0,0,1, 0,-1,0,0,1, 0,0,-1,0,1, 0,0,0,1,0));
  LSurface.Canvas.Clear($FFFFFFFF);
  LSurface.Canvas.DrawImageRect(LSrc,
    TRectF.Create(0, 0, LSrc.Width, LSrc.Height), TSkSamplingOptions.High, LPaint);
  LPngBytes := LSurface.MakeImageSnapshot.Encode(TSkEncodedImageFormat.PNG, 100);
  TFile.WriteAllBytes(ADstPath, LPngBytes);
end;

end.
