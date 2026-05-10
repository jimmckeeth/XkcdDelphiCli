// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
program sixeldemo;

{$APPTYPE CONSOLE}

{$R XkcdDelphiCli.res 'XkcdDelphiCli.rc'}

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
  sixelapi in 'sixelapi.pas',
  termimageapi in 'termimageapi.pas';

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
  Writeln('Delphi Sixel Terminal Image Sample');
  Writeln('Copyright (c) 2026 James McKeeth - Licensed GPL 3.0');
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
      DisplayImageAsSixel(LImagePath);
    end
    else
    begin
      LImagePath := ExtractFilePath(ParamStr(0)) + 'XkcdDelphiCli.webp';
      if FileExists(LImagePath) then
        DisplayImageAsSixel(LImagePath)
      else
        DisplaySvgResource('XkcdDelphiCli', tpSixel);
    end;
  except
    on E: Exception do
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
  end;
  end.

