// Copyright © 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit termdetectapi;

interface

type
  TTerminalProtocol = (tpNone, tpSixel, tpKitty, tpKittyPlus, tpITerm);

  TTerminalSize = record
    WidthPx, HeightPx: Integer;
  end;

  TTerminalRGB = record
    R, G, B: Byte;
  end;

// Response-string parsers — no terminal I/O, fully unit-testable
function ParseDA1Response(const AResponse: string): Boolean;
function ParseOSC11Response(const AResponse: string): TTerminalRGB;
function ParseTermSizeResponse(const AResponse: string): TTerminalSize;
function IsDarkColor(const AColor: TTerminalRGB): Boolean;

// Terminal I/O
function TerminalRequest(const ACmd: string; ATimeoutMs: Integer;
  const AEndChars: string): string;
function DetectProtocol: TTerminalProtocol;
function QueryTerminalSize: TTerminalSize;
function QueryBackgroundColor: TTerminalRGB;
function IsDarkBackground: Boolean;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  System.DateUtils
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ELSE}
  , Posix.Termios
  , Posix.Unistd
  , Posix.SysSelect
  , Posix.SysTime
  {$ENDIF}
  ;

// ── Parser helpers ────────────────────────────────────────────────────────────

function ParseDA1Response(const AResponse: string): Boolean;
var
  LParts: TArray<string>;
  LClean: string;
  LPart: string;
begin
  Result := False;
  if AResponse = '' then Exit;
  LClean := AResponse;
  var LStart := LClean.IndexOf('?');
  if LStart >= 0 then
    LClean := LClean.Substring(LStart + 1);
  if LClean.EndsWith('c') then
    LClean := LClean.Substring(0, LClean.Length - 1);
  LParts := LClean.Split([';']);
  for LPart in LParts do
    if Trim(LPart) = '4' then
      Exit(True);
end;

function ParseOSC11Response(const AResponse: string): TTerminalRGB;
var
  LMatch: TMatch;
  LVal: Integer;

  function HexToByteNorm(const AHex: string): Byte;
  begin
    LVal := StrToIntDef('$' + AHex, 0);
    if Length(AHex) > 2 then
      LVal := LVal shr 8;
    Result := Byte(LVal);
  end;

begin
  Result.R := 0; Result.G := 0; Result.B := 0;
  LMatch := TRegEx.Match(AResponse,
    'rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+)');
  if not LMatch.Success then Exit;
  Result.R := HexToByteNorm(LMatch.Groups[1].Value);
  Result.G := HexToByteNorm(LMatch.Groups[2].Value);
  Result.B := HexToByteNorm(LMatch.Groups[3].Value);
end;

function ParseTermSizeResponse(const AResponse: string): TTerminalSize;
var
  LParts: TArray<string>;
  LClean: string;
begin
  Result.WidthPx := 0; Result.HeightPx := 0;
  LClean := AResponse;
  var LStart := LClean.IndexOf('[');
  if LStart >= 0 then
    LClean := LClean.Substring(LStart + 1);
  if LClean.EndsWith('t') then
    LClean := LClean.Substring(0, LClean.Length - 1);
  LParts := LClean.Split([';']);
  if Length(LParts) >= 3 then
  begin
    Result.HeightPx := StrToIntDef(LParts[1], 0);
    Result.WidthPx  := StrToIntDef(LParts[2], 0);
  end;
end;

function IsDarkColor(const AColor: TTerminalRGB): Boolean;
var
  LLum: Double;
begin
  LLum := 0.299 * AColor.R + 0.587 * AColor.G + 0.114 * AColor.B;
  Result := LLum < 128;
end;

// ── Raw mode helpers ──────────────────────────────────────────────────────────

{$IFDEF MSWINDOWS}

var
  GhStdIn:  THandle;
  GhStdOut: THandle;
  GSavedIn, GSavedOut: DWORD;

procedure SetRawMode;
const
  ENABLE_VIRTUAL_TERMINAL_INPUT = $0200;
begin
  GhStdIn  := GetStdHandle(STD_INPUT_HANDLE);
  GhStdOut := GetStdHandle(STD_OUTPUT_HANDLE);
  GetConsoleMode(GhStdIn,  GSavedIn);
  GetConsoleMode(GhStdOut, GSavedOut);
  SetConsoleMode(GhStdIn,
    (GSavedIn and not ENABLE_LINE_INPUT and not ENABLE_ECHO_INPUT)
    or ENABLE_VIRTUAL_TERMINAL_INPUT);
  SetConsoleMode(GhStdOut,
    GSavedOut or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
end;

procedure RestoreMode;
begin
  SetConsoleMode(GhStdIn,  GSavedIn);
  SetConsoleMode(GhStdOut, GSavedOut);
end;

function ReadChar(ADeadline: UInt64): Char;
var
  LRec: TInputRecord;
  LCount: DWORD;
begin
  Result := #0;
  while GetTickCount64 < ADeadline do
  begin
    if WaitForSingleObject(GhStdIn, 10) = WAIT_OBJECT_0 then
    begin
      if ReadConsoleInput(GhStdIn, LRec, 1, LCount) and (LCount > 0) then
      begin
        if (LRec.EventType = KEY_EVENT) and LRec.Event.KeyEvent.bKeyDown then
        begin
          Result := LRec.Event.KeyEvent.UnicodeChar;
          if Result <> #0 then Exit;
        end;
      end;
    end;
  end;
end;

{$ELSE}

var
  GSavedTermios: termios;

procedure SetRawMode;
var
  LNew: termios;
begin
  tcgetattr(STDIN_FILENO, GSavedTermios);
  LNew := GSavedTermios;
  LNew.c_lflag := LNew.c_lflag and not (ICANON or ECHO);
  LNew.c_cc[VMIN]  := 0;
  LNew.c_cc[VTIME] := 0;
  tcsetattr(STDIN_FILENO, TCSAFLUSH, LNew);
end;

procedure RestoreMode;
begin
  tcsetattr(STDIN_FILENO, TCSAFLUSH, GSavedTermios);
end;

function ReadChar(ADeadline: Int64): Char;
var
  LFds: fd_set;
  LTV:  timeval;
  LC:   Byte;
  LNow: Int64;
begin
  Result := #0;
  LNow := DateTimeToUnix(Now) * 1000;
  while LNow < ADeadline do
  begin
    FD_ZERO(LFds);
    _FD_SET(STDIN_FILENO, LFds);
    LTV.tv_sec  := 0;
    LTV.tv_usec := 10000;
    if select(STDIN_FILENO + 1, @LFds, nil, nil, @LTV) > 0 then
    begin
      if __read(STDIN_FILENO, @LC, SizeOf(LC)) = 1 then
      begin
        Result := Char(LC);
        Exit;
      end;
    end;
    LNow := DateTimeToUnix(Now) * 1000;
  end;
end;

{$ENDIF}

// ── TerminalRequest ───────────────────────────────────────────────────────────

function TerminalRequest(const ACmd: string; ATimeoutMs: Integer;
  const AEndChars: string): string;
var
{$IFDEF MSWINDOWS}
  LDeadline: UInt64;
{$ELSE}
  LDeadline: Int64;
{$ENDIF}
  LC: Char;
begin
  Result := '';
  SetRawMode;
  try
    Write(ACmd);
    Flush(Output);
    LDeadline := {$IFDEF MSWINDOWS}GetTickCount64 + UInt64(ATimeoutMs){$ELSE}DateTimeToUnix(Now) * 1000 + ATimeoutMs{$ENDIF};
    repeat
      LC := ReadChar(LDeadline);
      if LC <> #0 then
      begin
        Result := Result + LC;
        if (AEndChars <> '') and (Pos(LC, AEndChars) > 0) then Break;
      end;
    until {$IFDEF MSWINDOWS}GetTickCount64{$ELSE}DateTimeToUnix(Now) * 1000{$ENDIF} >= LDeadline;
  finally
    RestoreMode;
  end;
end;

// ── Protocol detection ────────────────────────────────────────────────────────

const
  CKittyProbePNG =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJggg==';

function DetectProtocol: TTerminalProtocol;
var
  LResp: string;
begin
  Result := tpNone;

  LResp := TerminalRequest(
    #$1B + '_G i=31,s=1,v=1,a=q,t=d,f=100;' + CKittyProbePNG + #$1B + '\',
    100, #$1B);
  if LResp.Contains('OK') then Exit(tpKittyPlus);

  LResp := TerminalRequest(#$1B + ']1337;ReportCellSize' + #7, 100, #7);
  if LResp.Contains('ReportCellSize=') then Exit(tpITerm);

  LResp := TerminalRequest(
    #$1B + '_G i=31,s=1,v=1,a=q,t=d,f=24;AAAA' + #$1B + '\',
    100, #$1B);
  if LResp.Contains('OK') then Exit(tpKitty);

  LResp := TerminalRequest(#$1B + '[c', 100, 'c');
  if ParseDA1Response(LResp) then Exit(tpSixel);
end;

function QueryTerminalSize: TTerminalSize;
var
  LResp: string;
begin
  LResp  := TerminalRequest(#$1B + '[14t', 100, 't');
  Result := ParseTermSizeResponse(LResp);
end;

function QueryBackgroundColor: TTerminalRGB;
var
  LResp: string;
begin
  LResp  := TerminalRequest(#$1B + ']11;?' + #7, 100, #7);
  Result := ParseOSC11Response(LResp);
end;

function IsDarkBackground: Boolean;
begin
  Result := IsDarkColor(QueryBackgroundColor);
end;

end.
