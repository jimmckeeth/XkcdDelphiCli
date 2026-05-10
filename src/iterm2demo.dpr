// Copyright © 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
program iterm2demo;

// iTerm2 Inline Images Protocol
// https://iterm2.com/documentation-images.html

{$APPTYPE CONSOLE}

{$R *.res}
{$R *.dres}

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF }
  {$IFDEF LINUX}
  LinuxLibStdCxx in 'LinuxLibStdCxx.pas',
  {$ENDIF }
  System.SysUtils,
  System.IOUtils,
  termdetectapi in 'termdetectapi.pas',
  iterm2api in 'iterm2api.pas',
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

  var
  LImagePath: string;

  begin
  Writeln('Delphi iTerm2 Terminal Image Sample');
  Writeln('Copyright 2026 © James McKeeth - Licensed GPL 3.0');
  Writeln('https://github.com/jimmckeeth/XkcdDelphiCli');

  try
  {$IFDEF MSWINDOWS}
    EnableVTProcessing;
  {$ENDIF}

    if ParamCount > 0 then
    begin
      LImagePath := ParamStr(1);
      if not FileExists(LImagePath) then
        raise Exception.CreateFmt('Image not found: %s', [LImagePath]);
      DisplayImageAsITerm(LImagePath);
    end
    else
    begin
      LImagePath := ExtractFilePath(ParamStr(0))  + 'XkcdDelphiCli.webp';
      if FileExists(LImagePath) then
        DisplayImageAsITerm(LImagePath)
      else
        DisplaySvgResource('XkcdDelphiCli', tpITerm);
    end;
  except
    on E: Exception do
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
  end;
  end.

