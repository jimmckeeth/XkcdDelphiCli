program kittydemo;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF }
  {$IFDEF LINUX}
  LinuxLibStdCxx in 'LinuxLibStdCxx.pas',
  {$ENDIF }
  System.SysUtils,
  kittieapi in 'kittieapi.pas';

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

var
  LImagePath: string;

begin
  try
{$IFDEF MSWINDOWS}
    EnableVTProcessing;
{$ENDIF}

    if ParamCount > 0 then
      LImagePath := ParamStr(1)
    else
      LImagePath := ExtractFilePath(ParamStr(0)) + 'XkcdDelphiCli.webp';

    if not FileExists(LImagePath) then
      raise Exception.CreateFmt('Image not found: %s', [LImagePath]);

    DisplayImageAsKitty(LImagePath);
  except
    on E: Exception do
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
  end;
end.
