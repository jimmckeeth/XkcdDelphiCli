program termdetectdemo;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IFDEF LINUX}
  LinuxLibStdCxx in 'LinuxLibStdCxx.pas',
  {$ENDIF}
  System.SysUtils,
  System.IOUtils,
  termdetectapi in 'termdetectapi.pas',
  termimageapi in 'termimageapi.pas';

{$R 'XkcdDelphiCli.res' 'XkcdDelphiCli.rc'}

{$IFDEF MSWINDOWS}
procedure EnableVTProcessing;
var
  LHandle: THandle;
  LMode: DWORD;
begin
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if GetConsoleMode(LHandle, LMode) then
    SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
end;
{$ENDIF}

const
  CProtocolName: array[TTerminalProtocol] of string = (
    'None', 'Sixel', 'Kitty', 'Kitty+', 'iTerm');

var
  LImagePath: string;

begin
  try
    {$IFDEF MSWINDOWS}
    EnableVTProcessing;
    {$ENDIF}

    Writeln('Detecting terminal capabilities...');
    Writeln('Protocol : ', CProtocolName[DetectProtocol]);

    var LSize := QueryTerminalSize;
    Writeln('Term size: ', LSize.WidthPx, ' x ', LSize.HeightPx, ' px');

    var LColor := QueryBackgroundColor;
    Writeln(Format('Bg color : rgb(%d, %d, %d)', [LColor.R, LColor.G, LColor.B]));
    Writeln('Dark bg  : ', BoolToStr(IsDarkBackground, True));

    Writeln;
    if ParamCount > 0 then
    begin
      LImagePath := ParamStr(1);
      if FileExists(LImagePath) then
        AutoDisplayImage(LImagePath)
      else
        Writeln('Image not found: ', LImagePath);
    end
    else
    begin
      LImagePath := ExtractFilePath(ParamStr(0)) + 'XkcdDelphiCli.webp';
      if FileExists(LImagePath) then
        AutoDisplayImage(LImagePath)
      else
        DisplaySvgResource('XkcdDelphiCli', DetectProtocol);
    end;

  except
    on E: Exception do
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
  end;
end.
