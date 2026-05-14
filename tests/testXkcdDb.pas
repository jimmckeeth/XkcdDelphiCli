// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testXkcdDb;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdDb = class
  private
    FDbPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure DatabasePathUsesCacheDir;
    [Test]
    procedure DatabasePathReturnsOverrideWhenProvided;
    [Test]
    procedure InitializeDatabaseCreatesSchema;
    [Test]
    procedure InitializeDatabaseIsIdempotent;
    [Test]
    procedure DatabaseRoundtripPreservesUnicodeText;
    [Test]
    procedure FullTextSearchFindsTranscriptText;
    [Test]
    procedure UpsertComicDetailCanBeSearchedLiterally;
    [Test]
    procedure UpsertExplanationCanBeSearchedLiterally;
    [Test]
    procedure TryGetExplanationReturnsStoredExplanation;
    [Test]
    procedure ExplanationExistsReturnsTrueOnlyForStoredRows;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  xkcddb,
  xkcdmodel;

function QueryString(AConnection: TFDConnection; const ASql: string): string;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := AConnection;
    LQuery.SQL.Text := ASql;
    LQuery.Open;
    Result := LQuery.Fields[0].AsString;
  finally
    LQuery.Free;
  end;
end;

procedure TTestXkcdDb.Setup;
begin
  FDbPath := TPath.Combine(TPath.GetTempPath,
    'xkcd_test_' + TGUID.NewGuid.ToString + '.sqlite');
end;

procedure TTestXkcdDb.TearDown;
begin
  if TFile.Exists(FDbPath) then
    TFile.Delete(FDbPath);
end;

procedure TTestXkcdDb.DatabasePathUsesCacheDir;
var
  LPath: string;
begin
  LPath := DatabasePath;
  Assert.IsTrue(LPath.Contains('.cache'), 'Database path should contain .cache');
  Assert.IsTrue(LPath.Contains('xkcd-cli'), 'Database path should contain xkcd-cli');
  Assert.IsTrue(LPath.EndsWith('xkcd.sqlite'), 'Database path should end with xkcd.sqlite');
end;

procedure TTestXkcdDb.DatabasePathReturnsOverrideWhenProvided;
begin
  Assert.AreEqual('C:\custom\xkcd.sqlite', DatabasePath('C:\custom\xkcd.sqlite'));
end;

procedure TTestXkcdDb.InitializeDatabaseCreatesSchema;
var
  LConnection: TFDConnection;
begin
  LConnection := CreateConnection(FDbPath);
  try
    InitializeDatabase(LConnection);

    Assert.AreEqual(CXkcdDbSchemaVersion, GetSchemaVersion(LConnection));
    Assert.AreEqual(1, Integer(LConnection.ExecSQLScalar(
      'select count(*) from sqlite_master where type = ''table'' and name = ''comics''')));
    Assert.AreEqual(1, Integer(LConnection.ExecSQLScalar(
      'select count(*) from sqlite_master where type = ''table'' and name = ''explanations''')));
    Assert.AreEqual(1, Integer(LConnection.ExecSQLScalar(
      'select count(*) from sqlite_master where type = ''table'' and name = ''comic_search''')));
  finally
    LConnection.Free;
  end;
end;

procedure TTestXkcdDb.InitializeDatabaseIsIdempotent;
var
  LConnection: TFDConnection;
begin
  LConnection := CreateConnection(FDbPath);
  try
    InitializeDatabase(LConnection);
    InitializeDatabase(LConnection);

    Assert.AreEqual(CXkcdDbSchemaVersion, GetSchemaVersion(LConnection));
  finally
    LConnection.Free;
  end;
end;

procedure TTestXkcdDb.DatabaseRoundtripPreservesUnicodeText;
var
  LConnection: TFDConnection;
  LQuery: TFDQuery;
  LSmile, LTitle, LSubText: string;
begin
  LSmile := string(WideChar($D83D)) + string(WideChar($DE00));
  LTitle := 'Unicode ' + #$201C + 'caption' + #$201D + ' ' + LSmile;
  LSubText := 'that' + #$2019 + 's ' + #$201C + 'quoted' + #$201D + ' ' + LSmile;

  LConnection := CreateConnection(FDbPath);
  try
    InitializeDatabase(LConnection);
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := LConnection;
      LQuery.SQL.Text :=
        'insert into comics(id, title, href, img_src, sub_text, updated_at) ' +
        'values(:id, :title, :href, :img_src, :sub_text, :updated_at)';
      LQuery.ParamByName('id').AsInteger := 123456;
      LQuery.ParamByName('title').AsWideString := LTitle;
      LQuery.ParamByName('href').AsString := '/123456/';
      LQuery.ParamByName('img_src').AsString := 'https://imgs.xkcd.com/comics/unicode.png';
      LQuery.ParamByName('sub_text').AsWideString := LSubText;
      LQuery.ParamByName('updated_at').AsString := '2026-05-13T00:00:00Z';
      LQuery.ExecSQL;
    finally
      LQuery.Free;
    end;

    Assert.AreEqual(LTitle, QueryString(LConnection,
      'select title from comics where id = 123456'));
    Assert.AreEqual(LSubText, QueryString(LConnection,
      'select sub_text from comics where id = 123456'));
  finally
    LConnection.Free;
  end;
end;

procedure TTestXkcdDb.FullTextSearchFindsTranscriptText;
var
  LConnection: TFDConnection;
begin
  LConnection := CreateConnection(FDbPath);
  try
    InitializeDatabase(LConnection);
    LConnection.ExecSQL(
      'insert into comic_search(rowid, title, sub_text, transcript, explanation) ' +
      'values(:id, :title, :sub_text, :transcript, :explanation)',
      [927, 'Standards', 'Fortunately, the charging one has been solved now.',
       'Situation: there are 14 competing standards.',
       'This comic explains why attempts to unify standards often create another standard.']);

    Assert.AreEqual(927, Integer(LConnection.ExecSQLScalar(
      'select rowid from comic_search where comic_search match ''competing''')));
  finally
    LConnection.Free;
  end;
end;

procedure TTestXkcdDb.UpsertComicDetailCanBeSearchedLiterally;
var
  LConnection: TFDConnection;
  LComic: TXkcdComic;
  LResults: TArray<TXkcdSearchResult>;
  LSmile: string;
begin
  LSmile := string(WideChar($D83D)) + string(WideChar($DE00));
  LComic.Meta.ID := 149;
  LComic.Meta.HRef := '/149/';
  LComic.Meta.Title := 'Sandwich';
  LComic.ImgSrc := 'https://imgs.xkcd.com/comics/sandwich.png';
  LComic.SubText := 'Make me a sandwich ' + LSmile;

  LConnection := CreateConnection(FDbPath);
  try
    InitializeDatabase(LConnection);
    UpsertComicDetail(LConnection, LComic);

    LResults := SearchComics(LConnection, 'make me');

    Assert.AreEqual(1, Integer(Length(LResults)));
    Assert.AreEqual(149, LResults[0].ComicID);
    Assert.AreEqual('Sandwich', LResults[0].Title);
    Assert.IsTrue(LResults[0].Snippet.Contains(LSmile));
  finally
    LConnection.Free;
  end;
end;

procedure TTestXkcdDb.UpsertExplanationCanBeSearchedLiterally;
var
  LConnection: TFDConnection;
  LMeta: TXkcdComicMeta;
  LExplanation: TXkcdExplanation;
  LResults: TArray<TXkcdSearchResult>;
begin
  LMeta.ID := 927;
  LMeta.HRef := '/927/';
  LMeta.Title := 'Standards';
  LExplanation.ComicID := 927;
  LExplanation.ExplainUrl := 'https://www.explainxkcd.com/wiki/index.php/927';
  LExplanation.Transcript := 'Situation: there are 14 competing standards.';
  LExplanation.Explanation := 'The joke is about making yet another standard.';

  LConnection := CreateConnection(FDbPath);
  try
    InitializeDatabase(LConnection);
    UpsertComicMeta(LConnection, LMeta);
    UpsertExplanation(LConnection, LExplanation);

    LResults := SearchComics(LConnection, 'competing standards');

    Assert.AreEqual(1, Integer(Length(LResults)));
    Assert.AreEqual(927, LResults[0].ComicID);
    Assert.AreEqual(LExplanation.Transcript, LResults[0].Snippet);
  finally
    LConnection.Free;
  end;
end;

procedure TTestXkcdDb.TryGetExplanationReturnsStoredExplanation;
var
  LConnection: TFDConnection;
  LMeta: TXkcdComicMeta;
  LStored: TXkcdExplanation;
  LLoaded: TXkcdExplanation;
begin
  LMeta.ID := 149;
  LMeta.HRef := '/149/';
  LMeta.Title := 'Sandwich';
  LStored.ComicID := 149;
  LStored.ExplainUrl := 'https://www.explainxkcd.com/wiki/index.php/149:_Sandwich';
  LStored.Transcript := 'A person asks for a sandwich.';
  LStored.Explanation := 'The joke is about sudo.';

  LConnection := CreateConnection(FDbPath);
  try
    InitializeDatabase(LConnection);
    UpsertComicMeta(LConnection, LMeta);
    UpsertExplanation(LConnection, LStored);

    Assert.IsTrue(TryGetExplanation(LConnection, 149, LLoaded));
    Assert.AreEqual(LStored.ExplainUrl, LLoaded.ExplainUrl);
    Assert.AreEqual(LStored.Transcript, LLoaded.Transcript);
    Assert.AreEqual(LStored.Explanation, LLoaded.Explanation);
    Assert.IsFalse(TryGetExplanation(LConnection, 150, LLoaded));
  finally
    LConnection.Free;
  end;
end;

procedure TTestXkcdDb.ExplanationExistsReturnsTrueOnlyForStoredRows;
var
  LConnection: TFDConnection;
  LMeta: TXkcdComicMeta;
  LStored: TXkcdExplanation;
begin
  LMeta.ID := 149;
  LMeta.HRef := '/149/';
  LMeta.Title := 'Sandwich';
  LStored.ComicID := 149;
  LStored.ExplainUrl := 'https://www.explainxkcd.com/wiki/index.php/149:_Sandwich';
  LStored.Transcript := '';
  LStored.Explanation := '';

  LConnection := CreateConnection(FDbPath);
  try
    InitializeDatabase(LConnection);
    Assert.IsFalse(ExplanationExists(LConnection, 149));

    UpsertComicMeta(LConnection, LMeta);
    UpsertExplanation(LConnection, LStored);

    Assert.IsTrue(ExplanationExists(LConnection, 149));
    Assert.IsFalse(ExplanationExists(LConnection, 150));
  finally
    LConnection.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdDb);

end.
