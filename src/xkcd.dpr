// Copyright 2026 © James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
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
  Writeln('XKCD Delphi CLI');
  Writeln('Copyright 2026 © James McKeeth - Licensed GPL 3.0');
  Writeln('https://github.com/jimmckeeth/XkcdDelphiCli');

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
      Writeln(ErrOutput, 'Usage: xkcd <show|update-cache|random> [options]');
      Writeln(ErrOutput, 'Options:');
      Writeln(ErrOutput, '  --comic-id 149           To open a specific comic by ID');
      Writeln(ErrOutput, '  --no-terminal-graphics   Open the comic in the default image viewer');
      Writeln(ErrOutput, '                             Instead of displaying in the terminal.');
      Writeln(ErrOutput, '  --no-invert              Skip the invert if the background is dark.');

      ExitCode := 1;
    end;
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
