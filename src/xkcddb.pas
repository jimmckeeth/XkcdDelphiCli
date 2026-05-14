// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit xkcddb;

interface

uses
  FireDAC.Comp.Client,
  xkcdmodel;

const
  CXkcdDbSchemaVersion = 1;

function DatabasePath(const AOverride: string = ''): string;
function CreateConnection(const ADatabasePath: string): TFDConnection;
procedure InitializeDatabase(AConnection: TFDConnection);
function GetSchemaVersion(AConnection: TFDConnection): Integer;
procedure UpsertComicMeta(AConnection: TFDConnection; const AMeta: TXkcdComicMeta);
procedure UpsertComicDetail(AConnection: TFDConnection; const AComic: TXkcdComic);
procedure UpsertExplanation(AConnection: TFDConnection; const AExplanation: TXkcdExplanation);
function ExplanationExists(AConnection: TFDConnection; AComicID: Integer): Boolean;
function TryGetExplanation(AConnection: TFDConnection; AComicID: Integer;
  out AExplanation: TXkcdExplanation): Boolean;
function SearchComics(AConnection: TFDConnection; const AQuery: string;
  AMaxResults: Integer = 20): TArray<TXkcdSearchResult>;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.DateUtils,
  System.Generics.Collections,
  System.Variants,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Stan.Param,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef;

function DatabasePath(const AOverride: string = ''): string;
begin
  if AOverride <> '' then
    Exit(AOverride);

  Result := TPath.Combine(TPath.GetHomePath, '.cache');
  Result := TPath.Combine(Result, 'xkcd-cli');
  Result := TPath.Combine(Result, 'xkcd.sqlite');
end;

function CreateConnection(const ADatabasePath: string): TFDConnection;
var
  LDir: string;
begin
  LDir := ExtractFileDir(ADatabasePath);
  if LDir <> '' then
    ForceDirectories(LDir);

  Result := TFDConnection.Create(nil);
  try
    Result.DriverName := 'SQLite';
    Result.Params.Values['Database'] := ADatabasePath;
    Result.Params.Values['LockingMode'] := 'Normal';
    Result.Params.Values['Synchronous'] := 'Normal';
    Result.Params.Values['StringFormat'] := 'Unicode';
    Result.LoginPrompt := False;
    Result.Connected := True;
  except
    Result.Free;
    raise;
  end;
end;

procedure ExecuteSql(AConnection: TFDConnection; const ASql: string);
begin
  AConnection.ExecSQL(ASql);
end;

procedure InitializeDatabase(AConnection: TFDConnection);
begin
  AConnection.StartTransaction;
  try
    ExecuteSql(AConnection,
      'create table if not exists schema_info (' +
      'key text primary key not null, ' +
      'value text not null)');

    ExecuteSql(AConnection,
      'create table if not exists comics (' +
      'id integer primary key not null, ' +
      'title text not null, ' +
      'href text not null, ' +
      'img_src text, ' +
      'sub_text text, ' +
      'published_date text, ' +
      'updated_at text not null)');

    ExecuteSql(AConnection,
      'create table if not exists explanations (' +
      'comic_id integer primary key not null references comics(id), ' +
      'explain_url text not null, ' +
      'transcript text, ' +
      'explanation text, ' +
      'fetched_at text not null)');

    ExecuteSql(AConnection,
      'create virtual table if not exists comic_search using fts5(' +
      'title, sub_text, transcript, explanation)');

    AConnection.ExecSQL(
      'insert into schema_info(key, value) values(''schema_version'', :version) ' +
      'on conflict(key) do update set value = excluded.value',
      [CXkcdDbSchemaVersion]);

    AConnection.Commit;
  except
    AConnection.Rollback;
    raise;
  end;
end;

function GetSchemaVersion(AConnection: TFDConnection): Integer;
var
  LValue: Variant;
begin
  LValue := AConnection.ExecSQLScalar(
    'select value from schema_info where key = ''schema_version''');
  Result := StrToIntDef(VarToStr(LValue), 0);
end;

function TimestampUtc: string;
begin
  Result := DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), False);
end;

procedure BindWideString(AQuery: TFDQuery; const AName, AValue: string);
begin
  AQuery.ParamByName(AName).AsWideString := AValue;
end;

procedure ExecutePrepared(AConnection: TFDConnection; const ASql: string;
  const ABind: TProc<TFDQuery>);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := AConnection;
    LQuery.SQL.Text := ASql;
    ABind(LQuery);
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure RefreshSearchRow(AConnection: TFDConnection; AComicID: Integer);
var
  LQuery: TFDQuery;
begin
  AConnection.ExecSQL('delete from comic_search where rowid = :id', [AComicID]);

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := AConnection;
    LQuery.SQL.Text :=
      'insert into comic_search(rowid, title, sub_text, transcript, explanation) ' +
      'select c.id, c.title, coalesce(c.sub_text, ''''), ' +
      'coalesce(e.transcript, ''''), coalesce(e.explanation, '''') ' +
      'from comics c left join explanations e on e.comic_id = c.id ' +
      'where c.id = :id';
    LQuery.ParamByName('id').AsInteger := AComicID;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure UpsertComicMeta(AConnection: TFDConnection; const AMeta: TXkcdComicMeta);
begin
  ExecutePrepared(AConnection,
    'insert into comics(id, title, href, updated_at) ' +
    'values(:id, :title, :href, :updated_at) ' +
    'on conflict(id) do update set ' +
    'title = excluded.title, href = excluded.href, updated_at = excluded.updated_at',
    procedure(AQuery: TFDQuery)
    begin
      AQuery.ParamByName('id').AsInteger := AMeta.ID;
      BindWideString(AQuery, 'title', AMeta.Title);
      AQuery.ParamByName('href').AsString := AMeta.HRef;
      AQuery.ParamByName('updated_at').AsString := TimestampUtc;
    end);
  RefreshSearchRow(AConnection, AMeta.ID);
end;

procedure UpsertComicDetail(AConnection: TFDConnection; const AComic: TXkcdComic);
begin
  UpsertComicMeta(AConnection, AComic.Meta);
  ExecutePrepared(AConnection,
    'update comics set img_src = :img_src, sub_text = :sub_text, updated_at = :updated_at ' +
    'where id = :id',
    procedure(AQuery: TFDQuery)
    begin
      AQuery.ParamByName('id').AsInteger := AComic.Meta.ID;
      AQuery.ParamByName('img_src').AsString := AComic.ImgSrc;
      BindWideString(AQuery, 'sub_text', AComic.SubText);
      AQuery.ParamByName('updated_at').AsString := TimestampUtc;
    end);
  RefreshSearchRow(AConnection, AComic.Meta.ID);
end;

procedure UpsertExplanation(AConnection: TFDConnection; const AExplanation: TXkcdExplanation);
begin
  ExecutePrepared(AConnection,
    'insert into explanations(comic_id, explain_url, transcript, explanation, fetched_at) ' +
    'values(:comic_id, :explain_url, :transcript, :explanation, :fetched_at) ' +
    'on conflict(comic_id) do update set ' +
    'explain_url = excluded.explain_url, transcript = excluded.transcript, ' +
    'explanation = excluded.explanation, fetched_at = excluded.fetched_at',
    procedure(AQuery: TFDQuery)
    begin
      AQuery.ParamByName('comic_id').AsInteger := AExplanation.ComicID;
      AQuery.ParamByName('explain_url').AsString := AExplanation.ExplainUrl;
      BindWideString(AQuery, 'transcript', AExplanation.Transcript);
      BindWideString(AQuery, 'explanation', AExplanation.Explanation);
      AQuery.ParamByName('fetched_at').AsString := TimestampUtc;
    end);
  RefreshSearchRow(AConnection, AExplanation.ComicID);
end;

function ExplanationExists(AConnection: TFDConnection; AComicID: Integer): Boolean;
begin
  Result := Integer(AConnection.ExecSQLScalar(
    'select count(*) from explanations where comic_id = :comic_id',
    [AComicID])) > 0;
end;

function TryGetExplanation(AConnection: TFDConnection; AComicID: Integer;
  out AExplanation: TXkcdExplanation): Boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  AExplanation.ComicID := AComicID;
  AExplanation.ExplainUrl := '';
  AExplanation.Transcript := '';
  AExplanation.Explanation := '';

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := AConnection;
    LQuery.SQL.Text :=
      'select explain_url, coalesce(transcript, '''') as transcript, ' +
      'coalesce(explanation, '''') as explanation ' +
      'from explanations where comic_id = :comic_id';
    LQuery.ParamByName('comic_id').AsInteger := AComicID;
    LQuery.Open;
    if LQuery.Eof then
      Exit;

    AExplanation.ExplainUrl := LQuery.FieldByName('explain_url').AsString;
    AExplanation.Transcript := LQuery.FieldByName('transcript').AsString;
    AExplanation.Explanation := LQuery.FieldByName('explanation').AsString;
    Result := True;
  finally
    LQuery.Free;
  end;
end;

function BestSnippet(const ATitle, ASubText, ATranscript, AExplanation, AQuery: string): string;
var
  LQuery: string;
begin
  LQuery := LowerCase(AQuery);
  if LowerCase(ATitle).Contains(LQuery) then
    Exit(ATitle);
  if LowerCase(ASubText).Contains(LQuery) then
    Exit(ASubText);
  if LowerCase(ATranscript).Contains(LQuery) then
    Exit(ATranscript);
  Result := AExplanation;
end;

function SearchComics(AConnection: TFDConnection; const AQuery: string;
  AMaxResults: Integer = 20): TArray<TXkcdSearchResult>;
var
  LQuery: TFDQuery;
  LResult: TXkcdSearchResult;
  LResults: TList<TXkcdSearchResult>;
begin
  LResults := TList<TXkcdSearchResult>.Create;
  try
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := AConnection;
      LQuery.SQL.Text :=
        'select c.id, c.title, coalesce(c.sub_text, '''') as sub_text, ' +
        'coalesce(e.transcript, '''') as transcript, coalesce(e.explanation, '''') as explanation ' +
        'from comics c left join explanations e on e.comic_id = c.id ' +
        'where instr(lower(c.title), lower(:query)) > 0 ' +
        'or instr(lower(coalesce(c.sub_text, '''')), lower(:query)) > 0 ' +
        'or instr(lower(coalesce(e.transcript, '''')), lower(:query)) > 0 ' +
        'or instr(lower(coalesce(e.explanation, '''')), lower(:query)) > 0 ' +
        'order by c.id desc limit :limit';
      BindWideString(LQuery, 'query', AQuery);
      LQuery.ParamByName('limit').AsInteger := AMaxResults;
      LQuery.Open;
      while not LQuery.Eof do
      begin
        LResult.ComicID := LQuery.FieldByName('id').AsInteger;
        LResult.Title := LQuery.FieldByName('title').AsString;
        LResult.Snippet := BestSnippet(
          LQuery.FieldByName('title').AsString,
          LQuery.FieldByName('sub_text').AsString,
          LQuery.FieldByName('transcript').AsString,
          LQuery.FieldByName('explanation').AsString,
          AQuery);
        LResults.Add(LResult);
        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;
    Result := LResults.ToArray;
  finally
    LResults.Free;
  end;
end;

end.
