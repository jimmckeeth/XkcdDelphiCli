// Copyright 2026 © James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testSvgRendering;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestSvgRendering = class
  public
    [Test]
    procedure TestSvgResourceLoadAndRender;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Types,
  System.UITypes,
  System.Skia,
  Winapi.Windows,
  termimageapi,
  termdetectapi;

function EnumResNameProc(hModule: HMODULE; lpszType, lpszName: PChar; lParam: IntPtr): BOOL; stdcall;
begin
  if IntPtr(lpszName) < $FFFF then
    Writeln('  #', IntPtr(lpszName))
  else
    Writeln('  ', lpszName);
  Result := True;
end;

procedure TTestSvgRendering.TestSvgResourceLoadAndRender;
var
  LTempPath: string;
  LSvg: ISkSVGDOM;
  LSurface: ISkSurface;
  LData: TBytes;
  LResStream: TResourceStream;
  LBytes: TBytes;
  LSvgText: string;
begin
  LTempPath := TPath.Combine(TPath.GetTempPath, 'test_svg_render.png');
  if TFile.Exists(LTempPath) then
    TFile.Delete(LTempPath);

  // Test loading from resource
  try
    LResStream := TResourceStream.Create(HInstance, 'XKCDDELPHICLI', RT_RCDATA);
    try
      SetLength(LBytes, LResStream.Size);
      LResStream.ReadBuffer(LBytes[0], LResStream.Size);
      LSvgText := TEncoding.UTF8.GetString(LBytes);
    finally
      LResStream.Free;
    end;
  except
    on E: Exception do
    begin
      // Diagnostic: List all RCDATA resources
      Writeln('Available RCDATA resources:');
      EnumResourceNames(HInstance, RT_RCDATA, @EnumResNameProc, 0);
      Assert.Fail('Failed to load SVG resource "XKCDDELPHICLI": ' + E.Message);
    end;
  end;

  Assert.IsTrue(Length(LSvgText) > 0, 'SVG resource text is empty');

  LSvg := TSkSVGDOM.Make(LSvgText);
  Assert.IsNotNull(LSvg, 'Failed to load SVG from resource text');

  LSurface := TSkSurface.MakeRaster(400, 400);
  Assert.IsNotNull(LSurface, 'Failed to create surface');

  // Clear canvas to white for testing
  LSurface.Canvas.Clear(TAlphaColors.White);
  LSvg.SetContainerSize(TSizeF.Create(400, 400));
  LSvg.Render(LSurface.Canvas);

  LData := LSurface.MakeImageSnapshot.Encode(TSkEncodedImageFormat.PNG, 100);
  Assert.IsTrue(Length(LData) > 0, 'Encoded data is empty');
  
  TFile.WriteAllBytes(LTempPath, LData);
  Assert.IsTrue(TFile.Exists(LTempPath), 'Output file was not created');
  
  // Clean up
  if TFile.Exists(LTempPath) then
    TFile.Delete(LTempPath);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSvgRendering);

end.
