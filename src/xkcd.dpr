program xkcd;

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
  xkcdmodel  in 'xkcdmodel.pas',
  xkcdargs   in 'xkcdargs.pas',
  xkcdapp    in 'xkcdapp.pas';

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
  LArgs: TArray<string>;
  LOptions: TXkcdOptions;

begin
  try
    {$IFDEF MSWINDOWS}
    EnableVTProcessing;
    {$ENDIF}

    SetLength(LArgs, ParamCount);
    for var I := 1 to ParamCount do
      LArgs[I - 1] := ParamStr(I);

    LOptions := ParseArgs(LArgs);
    Run(LOptions);
  except
    on E: EXkcdArgError do
    begin
      Writeln(ErrOutput, 'Error: ', E.Message);
      Writeln(ErrOutput, 'Usage: xkcd <show|update-cache> [options]');
      ExitCode := 1;
    end;
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
