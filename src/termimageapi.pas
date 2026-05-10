// Copyright � 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit termimageapi;

interface

uses termdetectapi;

procedure DisplayImage(const AFileName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer = 800; AInvert: Boolean = False);

procedure DisplaySvgResource(const AResourceName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer = 800);

procedure AutoDisplayImage(const AFileName: string; AMaxWidth: Integer = 800;
  AInvert: Boolean = False);

procedure SaveInvertedImage(const ASrcPath, ADstPath: string);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Types,
  System.UITypes,
  System.Skia,
  sixelapi,
  kittieapi,
  iterm2api
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

procedure DisplaySvgResource(const AResourceName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer);
var
  LResStream: TResourceStream;
  LSvg: ISkSVGDOM;
  LSurface: ISkSurface;
  LTempFile: string;
  LData: TBytes;
  LSvgText: string;
  LBytes: TBytes;
  LResName: string;
  LBgColor: TTerminalRGB;
  LSkBgColor: TAlphaColor;
  LSvgFile: string;
begin
  LResName := AResourceName.ToUpper;
  LSvgText := '';
  
  // Try resource first
  try
    LResStream := TResourceStream.Create(HInstance, LResName, RT_RCDATA);
    try
      if LResStream.Size > 0 then
      begin
        SetLength(LBytes, LResStream.Size);
        LResStream.ReadBuffer(LBytes[0], LResStream.Size);
        LSvgText := TEncoding.UTF8.GetString(LBytes);
      end;
    finally
      LResStream.Free;
    end;
  except
    // Fallback to disk file if resource fails
    LSvgFile := TPath.Combine(ExtractFilePath(ParamStr(0)), AResourceName + '.svg');
    if TFile.Exists(LSvgFile) then
      LSvgText := TFile.ReadAllText(LSvgFile);
  end;

  if LSvgText = '' then
    raise Exception.CreateFmt('SVG source not found (resource "%s" or file)', [LResName]);

  LSvg := TSkSVGDOM.Make(LSvgText);
  if not Assigned(LSvg) then
    raise Exception.CreateFmt('Cannot parse SVG source: %s', [LResName]);

  // Match terminal background
  LBgColor := QueryBackgroundColor;
  if (LBgColor.R = 0) and (LBgColor.G = 0) and (LBgColor.B = 0) then
  begin
    if IsDarkBackground then
      LSkBgColor := TAlphaColors.Black
    else
      LSkBgColor := TAlphaColors.White;
  end
  else
    LSkBgColor := (255 shl 24) or (LBgColor.R shl 16) or (LBgColor.G shl 8) or LBgColor.B;

  // Render SVG
  LSurface := TSkSurface.MakeRaster(680, 200);
  LSurface.Canvas.Clear(LSkBgColor);
  LSvg.SetContainerSize(TSizeF.Create(680, 200));
  LSvg.Render(LSurface.Canvas);

  LData := LSurface.MakeImageSnapshot.Encode(TSkEncodedImageFormat.PNG, 100);
  LTempFile := TPath.Combine(TPath.GetTempPath, LResName + '.png');
  TFile.WriteAllBytes(LTempFile, LData);

  DisplayImage(LTempFile, AProtocol, AMaxWidth);
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
