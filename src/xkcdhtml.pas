unit xkcdhtml;

interface

uses xkcdmodel;

function ParseArchive(const AHtml: string): TArray<TXkcdComicMeta>;
procedure ParseComicPage(const AHtml: string; out AImgSrc, ASubText: string);
function HtmlDecode(const S: string): string;

implementation

uses
  System.RegularExpressions,
  System.SysUtils,
  System.Generics.Collections;

function DecodeNumericEntities(const S: string): string;
var
  LPos, LEnd, LCode: Integer;
  LNum: string;
begin
  Result := '';
  LPos := 1;
  while LPos <= Length(S) do
  begin
    if (S[LPos] = '&') and (LPos + 1 <= Length(S)) and (S[LPos + 1] = '#') then
    begin
      LEnd := LPos + 2;
      while (LEnd <= Length(S)) and CharInSet(S[LEnd], ['0'..'9']) do
        Inc(LEnd);
      if (LEnd <= Length(S)) and (S[LEnd] = ';') and (LEnd > LPos + 2) then
      begin
        LNum := Copy(S, LPos + 2, LEnd - LPos - 2);
        LCode := StrToIntDef(LNum, 63);
        Result := Result + string(WideChar(LCode));
        LPos := LEnd + 1;
        Continue;
      end;
    end;
    Result := Result + S[LPos];
    Inc(LPos);
  end;
end;

function HtmlDecode(const S: string): string;
begin
  Result := StringReplace(S,       '&amp;',  '&',  [rfReplaceAll]);
  Result := StringReplace(Result,  '&lt;',   '<',  [rfReplaceAll]);
  Result := StringReplace(Result,  '&gt;',   '>',  [rfReplaceAll]);
  Result := StringReplace(Result,  '&quot;', '"',  [rfReplaceAll]);
  Result := StringReplace(Result,  '&apos;', '''', [rfReplaceAll]);
  Result := StringReplace(Result,  '&#39;',  '''', [rfReplaceAll]);
  Result := DecodeNumericEntities(Result);
end;

function ParseArchive(const AHtml: string): TArray<TXkcdComicMeta>;
var
  LMatches: TMatchCollection;
  LMeta: TXkcdComicMeta;
  LList: TList<TXkcdComicMeta>;
begin
  LList := TList<TXkcdComicMeta>.Create;
  try
    LMatches := TRegEx.Matches(AHtml, '<a href="(/(\d+)/)">([^<]+)</a>');
    for var LMatch in LMatches do
    begin
      LMeta.ID    := StrToIntDef(LMatch.Groups[2].Value, 0);
      LMeta.HRef  := LMatch.Groups[1].Value;
      LMeta.Title := HtmlDecode(LMatch.Groups[3].Value);
      LList.Add(LMeta);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure ParseComicPage(const AHtml: string; out AImgSrc, ASubText: string);
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(AHtml,
    '<div id="comic">.*?<img src="//([^"]+)"[^>]+title="([^"]+)"',
    [roSingleLine]);
  if not LMatch.Success then
    raise EXkcdParseError.Create('Comic image not found in page HTML');
  AImgSrc  := 'https://' + LMatch.Groups[1].Value;
  ASubText := HtmlDecode(LMatch.Groups[2].Value);
end;

end.
