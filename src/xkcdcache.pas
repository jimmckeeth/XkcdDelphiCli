unit xkcdcache;

interface

uses xkcdmodel;

function CachePath(const AOverride: string = ''): string;
function ComicImageCachePath(AComicID: Integer): string;
function ComicImageInvertedCachePath(AComicID: Integer): string;
function ComicDetailCachePath(AComicID: Integer): string;
function IsStale(const ALastUpdated: TDateTime): Boolean;
function CacheExists(const APath: string): Boolean;
function LoadCache(const APath: string): TXkcdCache;
procedure SaveCache(const ACache: TXkcdCache; const APath: string);
function LoadComicDetail(AComicID: Integer; out AImgSrc, ASubText: string): Boolean;
procedure SaveComicDetail(AComicID: Integer; const AImgSrc, ASubText: string);

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  System.DateUtils,
  System.Generics.Collections;

function CachePath(const AOverride: string = ''): string;
begin
  if AOverride <> '' then
    Exit(AOverride);
  Result := TPath.Combine(TPath.GetHomePath, '.cache');
  Result := TPath.Combine(Result, 'xkcd-cli');
  Result := TPath.Combine(Result, 'cache.json');
end;

function ComicImageCachePath(AComicID: Integer): string;
begin
  Result := TPath.Combine(TPath.GetHomePath, '.cache');
  Result := TPath.Combine(Result, 'xkcd-cli');
  Result := TPath.Combine(Result, 'images');
  Result := TPath.Combine(Result, AComicID.ToString + '.png');
end;

function ComicImageInvertedCachePath(AComicID: Integer): string;
begin
  Result := TPath.Combine(TPath.GetHomePath, '.cache');
  Result := TPath.Combine(Result, 'xkcd-cli');
  Result := TPath.Combine(Result, 'images');
  Result := TPath.Combine(Result, AComicID.ToString + '_inv.png');
end;

function ComicDetailCachePath(AComicID: Integer): string;
begin
  Result := TPath.Combine(TPath.GetHomePath, '.cache');
  Result := TPath.Combine(Result, 'xkcd-cli');
  Result := TPath.Combine(Result, 'detail');
  Result := TPath.Combine(Result, AComicID.ToString + '.json');
end;

function IsStale(const ALastUpdated: TDateTime): Boolean;
begin
  Result := (Now - ALastUpdated) > 1.0;
end;

function CacheExists(const APath: string): Boolean;
begin
  Result := TFile.Exists(APath);
end;

function LoadCache(const APath: string): TXkcdCache;
var
  LJson: string;
  LRoot: TJSONObject;
  LArr: TJSONArray;
  LObj: TJSONObject;
  LMeta: TXkcdComicMeta;
  LList: TList<TXkcdComicMeta>;
begin
  LJson := TFile.ReadAllText(APath, TEncoding.UTF8);
  LRoot := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
  if LRoot = nil then
    raise EXkcdCacheError.Create('Cache file is not valid JSON');
  try
    Result.LastUpdated := ISO8601ToDate(LRoot.GetValue<string>('last_updated'), False);
    LArr  := LRoot.GetValue<TJSONArray>('comics');
    LList := TList<TXkcdComicMeta>.Create;
    try
      for var I := 0 to LArr.Count - 1 do
      begin
        LObj        := LArr.Items[I] as TJSONObject;
        LMeta.ID    := LObj.GetValue<Integer>('id');
        LMeta.HRef  := LObj.GetValue<string>('href');
        LMeta.Title := LObj.GetValue<string>('title');
        LList.Add(LMeta);
      end;
      Result.Comics := LList.ToArray;
    finally
      LList.Free;
    end;
  finally
    LRoot.Free;
  end;
end;

procedure SaveCache(const ACache: TXkcdCache; const APath: string);
var
  LRoot: TJSONObject;
  LArr: TJSONArray;
  LObj: TJSONObject;
  LDir: string;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('last_updated',
      FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"+00:00"', ACache.LastUpdated));
    LArr := TJSONArray.Create;
    for var LMeta in ACache.Comics do
    begin
      LObj := TJSONObject.Create;
      LObj.AddPair('id',    TJSONNumber.Create(LMeta.ID));
      LObj.AddPair('href',  LMeta.HRef);
      LObj.AddPair('title', LMeta.Title);
      LArr.Add(LObj);
    end;
    LRoot.AddPair('comics', LArr);
    LDir := ExtractFileDir(APath);
    if LDir <> '' then
      ForceDirectories(LDir);
    TFile.WriteAllText(APath, LRoot.ToJSON, TEncoding.UTF8);
  finally
    LRoot.Free;
  end;
end;

function LoadComicDetail(AComicID: Integer; out AImgSrc, ASubText: string): Boolean;
var
  LPath: string;
  LRoot: TJSONObject;
begin
  AImgSrc  := '';
  ASubText := '';
  LPath := ComicDetailCachePath(AComicID);
  if not TFile.Exists(LPath) then
    Exit(False);
  LRoot := TJSONObject.ParseJSONValue(TFile.ReadAllText(LPath, TEncoding.UTF8)) as TJSONObject;
  if LRoot = nil then
    Exit(False);
  try
    AImgSrc  := LRoot.GetValue<string>('img_src');
    ASubText := LRoot.GetValue<string>('sub_text');
    Result := True;
  finally
    LRoot.Free;
  end;
end;

procedure SaveComicDetail(AComicID: Integer; const AImgSrc, ASubText: string);
var
  LPath: string;
  LRoot: TJSONObject;
begin
  LPath := ComicDetailCachePath(AComicID);
  ForceDirectories(ExtractFileDir(LPath));
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('img_src',  AImgSrc);
    LRoot.AddPair('sub_text', ASubText);
    TFile.WriteAllText(LPath, LRoot.ToJSON, TEncoding.UTF8);
  finally
    LRoot.Free;
  end;
end;

end.
