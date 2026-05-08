unit xkcdhttp;

interface

uses xkcdmodel;

function FetchArchiveHtml: string;
function FetchComicHtml(AID: Integer): string;
procedure FetchImageToFile(const AURL, ADestPath: string);

implementation

uses
  System.Net.HttpClient,
  System.SysUtils,
  System.IOUtils,
  System.Classes;

const
  CUserAgent = 'xkcd-delphi-cli/1.0';
  CBaseUrl   = 'https://xkcd.com';

function MakeClient: THTTPClient;
begin
  Result           := THTTPClient.Create;
  Result.UserAgent := CUserAgent;
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
