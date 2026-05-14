unit xkcdhttp;

interface

uses xkcdmodel;

function FetchArchiveHtml: string;
function FetchComicHtml(AID: Integer): string;
function FetchExplainHtml(AID: Integer): string; overload;
function FetchExplainHtml(AID: Integer; const ATitle: string): string; overload;
procedure FetchImageToFile(const AURL, ADestPath: string);

implementation

uses
  System.Net.HttpClient,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  xkcdexplained;

const
  CUserAgent = 'xkcd-delphi-cli/1.0';
  CBaseUrl   = 'https://xkcd.com';

function MakeClient: THTTPClient;
begin
  Result           := THTTPClient.Create;
  Result.UserAgent := CUserAgent;
  Result.HandleRedirects := True;
end;

function FetchArchiveHtml: string;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
begin
  LClient := MakeClient;
  try
    LResp := LClient.Get(CBaseUrl + '/archive/');
    if LResp.StatusCode <> 200 then
      raise EXkcdHttpError.CreateFmt('HTTP %d fetching archive', [LResp.StatusCode]);
    Result := LResp.ContentAsString(TEncoding.UTF8);
  finally
    LClient.Free;
  end;
end;

function FetchComicHtml(AID: Integer): string;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
begin
  LClient := MakeClient;
  try
    LResp := LClient.Get(Format('%s/%d/', [CBaseUrl, AID]));
    if LResp.StatusCode <> 200 then
      raise EXkcdHttpError.CreateFmt('HTTP %d fetching comic %d',
        [LResp.StatusCode, AID]);
    Result := LResp.ContentAsString(TEncoding.UTF8);
  finally
    LClient.Free;
  end;
end;

function FetchExplainHtml(AID: Integer): string;
begin
  Result := FetchExplainHtml(AID, '');
end;

function IsTransientStatus(AStatusCode: Integer): Boolean;
begin
  Result := (AStatusCode = 429) or
    (AStatusCode = 500) or
    (AStatusCode = 502) or
    (AStatusCode = 503) or
    (AStatusCode = 504);
end;

function FetchExplainHtml(AID: Integer; const ATitle: string): string;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
  LUrl: string;
  LAttempt: Integer;
begin
  LUrl := ExplainXkcdUrl(AID, ATitle);
  LClient := MakeClient;
  try
    for LAttempt := 1 to 3 do
    begin
      LResp := LClient.Get(LUrl);
      if LResp.StatusCode = 200 then
        Exit(LResp.ContentAsString(TEncoding.UTF8));
      if (LAttempt < 3) and IsTransientStatus(LResp.StatusCode) then
      begin
        TThread.Sleep(LAttempt * 1000);
        Continue;
      end;
      raise EXkcdHttpError.CreateFmt('HTTP %d fetching Explain XKCD page %d from %s',
        [LResp.StatusCode, AID, LUrl]);
    end;
  finally
    LClient.Free;
  end;
end;

procedure FetchImageToFile(const AURL, ADestPath: string);
var
  LClient: THTTPClient;
  LStream: TFileStream;
  LResp: IHTTPResponse;
begin
  ForceDirectories(ExtractFileDir(ADestPath));
  LClient := MakeClient;
  try
    LStream := TFileStream.Create(ADestPath, fmCreate);
    try
      LResp := LClient.Get(AURL, LStream);
      if LResp.StatusCode <> 200 then
        raise EXkcdHttpError.CreateFmt('HTTP %d fetching image', [LResp.StatusCode]);
    finally
      LStream.Free;
    end;
  finally
    LClient.Free;
  end;
end;

end.
