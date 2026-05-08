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

// Terminal I/O (stub implementations — replaced in Task 8)
function TerminalRequest(const ACmd: string; ATimeoutMs: Integer;
  const AEndChars: string): string;
function DetectProtocol: TTerminalProtocol;
function QueryTerminalSize: TTerminalSize;
function QueryBackgroundColor: TTerminalRGB;
function IsDarkBackground: Boolean;

implementation

uses System.SysUtils, System.RegularExpressions;

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

function TerminalRequest(const ACmd: string; ATimeoutMs: Integer;
  const AEndChars: string): string;
begin
  Result := '';
end;

function DetectProtocol: TTerminalProtocol;
begin
  Result := tpNone;
end;

function QueryTerminalSize: TTerminalSize;
begin
  Result.WidthPx := 0; Result.HeightPx := 0;
end;

function QueryBackgroundColor: TTerminalRGB;
begin
  Result.R := 0; Result.G := 0; Result.B := 0;
end;

function IsDarkBackground: Boolean;
begin
  Result := False;
end;

end.
