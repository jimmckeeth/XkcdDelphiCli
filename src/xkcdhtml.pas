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
  LIsHex: Boolean;
begin
  Result := '';
  LPos := 1;
  while LPos <= Length(S) do
  begin
    if (S[LPos] = '&') and (LPos + 1 <= Length(S)) and (S[LPos + 1] = '#') then
    begin
      LEnd := LPos + 2;
      LIsHex := (LEnd <= Length(S)) and CharInSet(S[LEnd], ['x', 'X']);
      if LIsHex then
        Inc(LEnd);
      if LIsHex then
      begin
        while (LEnd <= Length(S)) and CharInSet(S[LEnd], ['0'..'9', 'a'..'f', 'A'..'F']) do
          Inc(LEnd);
      end
      else
      begin
        while (LEnd <= Length(S)) and CharInSet(S[LEnd], ['0'..'9']) do
          Inc(LEnd);
      end;
      if (LEnd <= Length(S)) and (S[LEnd] = ';') then
      begin
        if LIsHex then
          LNum := Copy(S, LPos + 3, LEnd - LPos - 3)
        else
          LNum := Copy(S, LPos + 2, LEnd - LPos - 2);
        if LNum <> '' then
        begin
          if LIsHex then
            LCode := StrToIntDef('$' + LNum, 63)
          else
            LCode := StrToIntDef(LNum, 63);
          Result := Result + string(WideChar(LCode));
          LPos := LEnd + 1;
          Continue;
        end;
      end;
    end;
    Result := Result + S[LPos];
    Inc(LPos);
  end;
end;

function HtmlDecode(const S: string): string;
begin
  // Decode numeric entities from the raw input before expanding named entities.
  // This prevents &amp;#65; from becoming A: the &amp; pass would produce &#65;
  // after the numeric pass has already run, leaving it as the literal text &#65;.
  Result := DecodeNumericEntities(S);
  Result := StringReplace(Result,  '&amp;',  '&',  [rfReplaceAll]);
  Result := StringReplace(Result,  '&lt;',   '<',  [rfReplaceAll]);
  Result := StringReplace(Result,  '&gt;',   '>',  [rfReplaceAll]);
  Result := StringReplace(Result,  '&quot;', '"',  [rfReplaceAll]);
  Result := StringReplace(Result,  '&apos;', '''', [rfReplaceAll]);
  Result := StringReplace(Result,  '&#39;',  '''', [rfReplaceAll]);
end;

function ParseArchive(const AHtml: string): TArray<TXkcdComicMeta>;
var
  LMatches: TMatchCollection;
  LMeta: TXkcdComicMeta;
  LList: TList<TXkcdComicMeta>;
begin
  LList := TList<TXkcdComicMeta>.Create;
  try
    LMatches := TRegEx.Matches(AHtml, '<a href="(/(\d+)/)"[^>]*>([^<]+)</a>');
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
  LDivMatch, LSrcMatch, LTitleMatch: TMatch;
  LComicBlock: string;
begin
  // Extract the comic div block first so that attribute order within the
  // <img> tag does not matter.
  LDivMatch := TRegEx.Match(AHtml,
    '<div id="comic">.*?</div>',
    [roSingleLine]);
  if not LDivMatch.Success then
    raise EXkcdParseError.Create('Comic image not found in page HTML');
  LComicBlock := LDivMatch.Value;

  LSrcMatch := TRegEx.Match(LComicBlock, 'src="//([^"]+)"');
  if not LSrcMatch.Success then
    raise EXkcdParseError.Create('Comic image src not found in page HTML');

  LTitleMatch := TRegEx.Match(LComicBlock, '<img[^>]*title="([^"]+)"');
  if not LTitleMatch.Success then
    raise EXkcdParseError.Create('Comic image title not found in page HTML');

  AImgSrc  := 'https://' + LSrcMatch.Groups[1].Value;
  ASubText := HtmlDecode(LTitleMatch.Groups[1].Value);
end;

end.
