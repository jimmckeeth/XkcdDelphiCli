// Copyright (c) 2026 James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit xkcdconsole;

interface

procedure ConfigureUnicodeConsole;
function ConsoleTextWidth(ADefaultWidth: Integer = 80): Integer;
function WrapTextAtWords(const AText: string; AWidth: Integer): string;
procedure WriteWrappedText(const AText: string; AWidth: Integer = 0);

implementation

uses
  System.SysUtils
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ENDIF}
  ;

function ConsoleTextWidth(ADefaultWidth: Integer = 80): Integer;
{$IFDEF MSWINDOWS}
var
  LHandle: THandle;
  LInfo: TConsoleScreenBufferInfo;
{$ENDIF}
begin
  Result := StrToIntDef(GetEnvironmentVariable('COLUMNS'), 0);
  if Result > 0 then
    Exit;

  {$IFDEF MSWINDOWS}
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if GetConsoleScreenBufferInfo(LHandle, LInfo) then
    Exit(LInfo.srWindow.Right - LInfo.srWindow.Left + 1);
  {$ENDIF}

  Result := ADefaultWidth;
end;

function WrapSingleLineAtWords(const AText: string; AWidth: Integer): string;
var
  LWords: TArray<string>;
  LLine: string;
  LWord: string;
begin
  Result := '';
  LLine := '';
  LWords := AText.Split([' '], TStringSplitOptions.ExcludeEmpty);
  for LWord in LWords do
  begin
    if LLine = '' then
      LLine := LWord
    else if Length(LLine) + 1 + Length(LWord) <= AWidth then
      LLine := LLine + ' ' + LWord
    else
    begin
      if Result <> '' then
        Result := Result + sLineBreak;
      Result := Result + LLine;
      LLine := LWord;
    end;
  end;

  if LLine <> '' then
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + LLine;
  end;
end;

function WrapTextAtWords(const AText: string; AWidth: Integer): string;
var
  LLines: TArray<string>;
  LLine: string;
  LWrapped: string;
begin
  if AWidth <= 0 then
    AWidth := ConsoleTextWidth;
  if AWidth <= 1 then
    Exit(AText);

  Result := '';
  LLines := AText.Replace(#13#10, #10).Replace(#13, #10).Split([#10]);
  for LLine in LLines do
  begin
    LWrapped := WrapSingleLineAtWords(LLine, AWidth);
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + LWrapped;
  end;
end;

procedure WriteWrappedText(const AText: string; AWidth: Integer = 0);
begin
  Writeln(WrapTextAtWords(AText, AWidth));
end;

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
