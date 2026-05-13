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

function CodePointToString(ACodePoint: Integer): string;
var
  LHighSurrogate, LLowSurrogate: Word;
begin
  if (ACodePoint < 0) or (ACodePoint > $10FFFF) or
     ((ACodePoint >= $D800) and (ACodePoint <= $DFFF)) then
    Exit(string(WideChar($FFFD)));

  if ACodePoint <= $FFFF then
    Exit(string(WideChar(ACodePoint)));

  Dec(ACodePoint, $10000);
  LHighSurrogate := $D800 + (ACodePoint shr 10);
  LLowSurrogate  := $DC00 + (ACodePoint and $3FF);
  Result := string(WideChar(LHighSurrogate)) + string(WideChar(LLowSurrogate));
end;

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
          Result := Result + CodePointToString(LCode);
          LPos := LEnd + 1;
          Continue;
        end;
      end;
    end;
    Result := Result + S[LPos];
    Inc(LPos);
  end;
end;

function DecodeNamedEntities(const S: string): string;
const
  CEntities: array[0..16, 0..1] of string = (
    ('&amp;', '&'),
    ('&lt;', '<'),
    ('&gt;', '>'),
    ('&quot;', '"'),
    ('&apos;', ''''),
    ('&nbsp;', #$00A0),
    ('&copy;', #$00A9),
    ('&reg;', #$00AE),
    ('&trade;', #$2122),
    ('&ndash;', #$2013),
    ('&mdash;', #$2014),
    ('&lsquo;', #$2018),
    ('&rsquo;', #$2019),
    ('&ldquo;', #$201C),
    ('&rdquo;', #$201D),
    ('&hellip;', #$2026),
    ('&minus;', #$2212)
  );
begin
  Result := S;
  for var I := Low(CEntities) to High(CEntities) do
    Result := StringReplace(Result, CEntities[I, 0], CEntities[I, 1], [rfReplaceAll]);
end;

function HtmlDecode(const S: string): string;
begin
  // Decode numeric entities from the raw input before expanding named entities.
  // This prevents &amp;#65; from becoming A: the &amp; pass would produce &#65;
  // after the numeric pass has already run, leaving it as the literal text &#65;.
  Result := DecodeNumericEntities(S);
  Result := DecodeNamedEntities(Result);
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
