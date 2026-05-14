// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit xkcdexplained;

interface

uses
  xkcdmodel;

function ExplainXkcdUrl(AComicID: Integer): string; overload;
function ExplainXkcdUrl(AComicID: Integer; const ATitle: string): string; overload;
function ParseExplainPage(AComicID: Integer; const AHtml: string): TXkcdExplanation; overload;
function ParseExplainPage(AComicID: Integer; const ATitle, AHtml: string): TXkcdExplanation; overload;
function TryParseExplainPage(AComicID: Integer; const AHtml: string;
  out AExplanation: TXkcdExplanation): Boolean; overload;
function TryParseExplainPage(AComicID: Integer; const ATitle, AHtml: string;
  out AExplanation: TXkcdExplanation): Boolean; overload;

implementation

uses
  System.RegularExpressions,
  System.SysUtils,
  xkcdhtml;

const
  CExplainBaseUrl = 'https://www.explainxkcd.com/wiki/index.php';

function ExplainXkcdUrl(AComicID: Integer): string;
begin
  Result := Format('%s/%d', [CExplainBaseUrl, AComicID]);
end;

function EncodePathSegment(const AValue: string): string;
var
  LBytes: TBytes;
  LByte: Byte;
begin
  Result := '';
  LBytes := TEncoding.UTF8.GetBytes(AValue);
  for LByte in LBytes do
  begin
    if ((LByte >= Ord('A')) and (LByte <= Ord('Z'))) or
       ((LByte >= Ord('a')) and (LByte <= Ord('z'))) or
       ((LByte >= Ord('0')) and (LByte <= Ord('9'))) or
       CharInSet(Chr(LByte), ['-', '.', '_', '~', ':']) then
      Result := Result + Chr(LByte)
    else
      Result := Result + '%' + IntToHex(LByte, 2);
  end;
end;

function ExplainXkcdUrl(AComicID: Integer; const ATitle: string): string;
var
  LTitle: string;
begin
  LTitle := TRegEx.Replace(Trim(ATitle), '\s+', '_');
  if LTitle = '' then
    Exit(ExplainXkcdUrl(AComicID));
  Result := Format('%s/%s', [CExplainBaseUrl,
    EncodePathSegment(Format('%d:_%s', [AComicID, LTitle]))]);
end;

function SectionPattern(const ASectionID: string): string;
begin
  Result :=
    '<h[1-6][^>]*>.*?<span[^>]+id="' + ASectionID + '"[^>]*>.*?</h[1-6]>' +
    '(.*?)' +
    '(?=<h[1-6][^>]*>|<div[^>]+class="printfooter"|<div[^>]+id="catlinks"|$)';
end;

function ExtractSectionHtml(const AHtml, ASectionID: string): string;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(AHtml, SectionPattern(ASectionID),
    [roIgnoreCase, roSingleLine]);
  if LMatch.Success then
    Result := LMatch.Groups[1].Value
  else
    Result := '';
end;

function CollapseLineWhitespace(const ALine: string): string;
begin
  Result := TRegEx.Replace(Trim(ALine), '\s+', ' ');
end;

function NormalizeText(const AText: string): string;
var
  LLines: TArray<string>;
  LLine: string;
  LNormalizedLine: string;
begin
  Result := '';
  LLines := TRegEx.Split(AText.Replace(#13#10, #10).Replace(#13, #10), #10);
  for LLine in LLines do
  begin
    LNormalizedLine := CollapseLineWhitespace(LLine);
    if LNormalizedLine = '' then
      Continue;
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + LNormalizedLine;
  end;
end;

function StripHtmlToText(const AHtml: string): string;
begin
  Result := AHtml;
  Result := TRegEx.Replace(Result, '<script\b[^>]*>.*?</script>', '',
    [roIgnoreCase, roSingleLine]);
  Result := TRegEx.Replace(Result, '<style\b[^>]*>.*?</style>', '',
    [roIgnoreCase, roSingleLine]);
  Result := TRegEx.Replace(Result, '<span[^>]+class="mw-editsection"[^>]*>.*?</span>', '',
    [roIgnoreCase, roSingleLine]);
  Result := TRegEx.Replace(Result, '<sup\b[^>]*>.*?</sup>', '',
    [roIgnoreCase, roSingleLine]);
  Result := TRegEx.Replace(Result, '<br\s*/?>', #10, [roIgnoreCase]);
  Result := TRegEx.Replace(Result, '</(p|div|li|dd|dt|tr|h[1-6])>', #10,
    [roIgnoreCase]);
  Result := TRegEx.Replace(Result, '<li[^>]*>', '- ', [roIgnoreCase]);
  Result := TRegEx.Replace(Result, '<[^>]+>', ' ', [roSingleLine]);
  Result := HtmlDecode(Result);
  Result := NormalizeText(Result);
end;

function TrimFromMarker(const AText, AMarker: string): string;
var
  LIndex: Integer;
begin
  Result := AText;
  LIndex := Pos(AMarker, Result);
  if LIndex > 0 then
    Result := Trim(Copy(Result, 1, LIndex - 1));
end;

function RemoveTranscriptFooter(const AText: string): string;
begin
  Result := TrimFromMarker(AText, 'Add comment');
  Result := TrimFromMarker(Result, 'Create topic (use sparingly)');
end;

function TryParseExplainPage(AComicID: Integer; const AHtml: string;
  out AExplanation: TXkcdExplanation): Boolean;
begin
  Result := TryParseExplainPage(AComicID, '', AHtml, AExplanation);
end;

function TryParseExplainPage(AComicID: Integer; const ATitle, AHtml: string;
  out AExplanation: TXkcdExplanation): Boolean;
begin
  AExplanation.ComicID := AComicID;
  AExplanation.ExplainUrl := ExplainXkcdUrl(AComicID, ATitle);
  AExplanation.Explanation := StripHtmlToText(ExtractSectionHtml(AHtml, 'Explanation'));
  AExplanation.Transcript := RemoveTranscriptFooter(
    StripHtmlToText(ExtractSectionHtml(AHtml, 'Transcript')));
  Result := (AExplanation.Explanation <> '') or (AExplanation.Transcript <> '');
end;

function ParseExplainPage(AComicID: Integer; const AHtml: string): TXkcdExplanation;
begin
  Result := ParseExplainPage(AComicID, '', AHtml);
end;

function ParseExplainPage(AComicID: Integer; const ATitle, AHtml: string): TXkcdExplanation;
begin
  if not TryParseExplainPage(AComicID, ATitle, AHtml, Result) then
    raise EXkcdParseError.CreateFmt('Explain XKCD sections not found for comic %d', [AComicID]);
end;

end.
