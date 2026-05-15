// Copyright (c) 2026 James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
program xkcd;

{$APPTYPE CONSOLE}

{$R *.dres}

uses
  {$IFDEF LINUX}
  LinuxLibStdCxx in 'LinuxLibStdCxx.pas',
  {$ENDIF }
  System.SysUtils,
  xkcdversion in 'xkcdversion.pas',
  xkcdmodel in 'xkcdmodel.pas',
  xkcdargs in 'xkcdargs.pas',
  xkcdconsole in 'xkcdconsole.pas',
  xkcdapp in 'xkcdapp.pas';

var
  LArgs: TArray<string>;
  LOptions: TXkcdOptions;


begin
  ConfigureUnicodeConsole;

  Writeln('XKCD Delphi CLI - v' + CAppVersion);
  Writeln('Copyright (c) 2026 James McKeeth - Licensed GPL 3.0');
  Writeln('https://github.com/jimmckeeth/XkcdDelphiCli');

  try
    SetLength(LArgs, ParamCount);
    for var I := 1 to ParamCount do
      LArgs[I - 1] := ParamStr(I);

    LOptions := ParseArgs(LArgs);
    var LComicID := Run(LOptions);
    if LComicID > 0 then
      Writeln('https://xkcd.com/' + LComicID.ToString + '/');
  except
    on E: EXkcdArgError do
    begin
      Writeln(ErrOutput, 'Error: ', E.Message);
      Writeln(ErrOutput, 'Usage: xkcd <show|update-cache|random|search> [options]');
      Writeln(ErrOutput, 'Options:');
      Writeln(ErrOutput, '  --comic-id 149           To open a specific comic by ID');
      Writeln(ErrOutput, '  --db-filename PATH       Override the SQLite search database path');
      Writeln(ErrOutput, '  --explained, --explain   Show/cache Explain XKCD explanation text');
      Writeln(ErrOutput, '  --transcript             Show/cache Explain XKCD transcript text');
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
