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
  termdetectapi in 'termdetectapi.pas';

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
  except
    on E: Exception do
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
  end;
end.
