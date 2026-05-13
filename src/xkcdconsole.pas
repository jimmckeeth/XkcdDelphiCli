// Copyright (c) 2026 James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit xkcdconsole;

interface

procedure ConfigureUnicodeConsole;

implementation

uses
  System.SysUtils
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ENDIF}
  ;

procedure ConfigureUnicodeConsole;
{$IFDEF MSWINDOWS}
var
  LHandle: THandle;
  LMode: DWORD;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  SetConsoleCP(CP_UTF8);
  SetConsoleOutputCP(CP_UTF8);
  SetTextCodePage(Input, CP_UTF8);
  SetTextCodePage(Output, CP_UTF8);
  SetTextCodePage(ErrOutput, CP_UTF8);

  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if GetConsoleMode(LHandle, LMode) then
    SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  {$ENDIF}
end;

end.
