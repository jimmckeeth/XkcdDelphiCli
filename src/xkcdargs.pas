// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit xkcdargs;

interface

uses xkcdmodel;

function ParseArgs(const AArgs: TArray<string>): TXkcdOptions;

implementation

uses System.SysUtils;

function ParseArgs(const AArgs: TArray<string>): TXkcdOptions;
var
  I: Integer;
  LArg: string;
begin
  Result.SubCommand         := '';
  Result.ShowLatest         := False;
  Result.ComicID            := -1;
  Result.NoTerminalGraphics := False;
  Result.Width              := -1;
  Result.CacheFilename      := '';
  Result.DbFilename         := '';
  Result.SearchQuery        := '';
  Result.IncludeExplanation := False;
  Result.IncludeTranscript  := False;
  Result.NoCache            := False;
  Result.Invert             := True;

  if Length(AArgs) = 0 then
  begin
    Result.SubCommand := 'show';
    Result.ShowLatest := True;
    Exit;
  end;

  Result.SubCommand := LowerCase(AArgs[0]);
  if (Result.SubCommand <> 'show') and (Result.SubCommand <> 'update-cache') and
     (Result.SubCommand <> 'random') and (Result.SubCommand <> 'search') then
    raise EXkcdArgError.CreateFmt('Unknown command: %s', [AArgs[0]]);

  I := 1;
  while I <= High(AArgs) do
  begin
    LArg := AArgs[I];
    if LArg = '--latest' then
      Result.ShowLatest := True
    else if LArg = '--no-terminal-graphics' then
      Result.NoTerminalGraphics := True
    else if LArg = '--no-cache' then
      Result.NoCache := True
    else if LArg = '--no-invert' then
      Result.Invert := False
    else if LArg = '--explained' then
      Result.IncludeExplanation := True
    else if LArg = '--transcript' then
      Result.IncludeTranscript := True
    else if LArg = '--comic-id' then
    begin
      Inc(I);
      if I > High(AArgs) then
        raise EXkcdArgError.Create('--comic-id requires a value');
      Result.ComicID := StrToIntDef(AArgs[I], -2);
      if Result.ComicID = -2 then
        raise EXkcdArgError.CreateFmt('Invalid comic ID: %s', [AArgs[I]]);
    end
    else if LArg = '--width' then
    begin
      Inc(I);
      if I > High(AArgs) then
        raise EXkcdArgError.Create('--width requires a value');
      Result.Width := StrToIntDef(AArgs[I], -2);
      if Result.Width = -2 then
        raise EXkcdArgError.CreateFmt('Invalid width: %s', [AArgs[I]]);
    end
    else if LArg = '--cache-filename' then
    begin
      Inc(I);
      if I > High(AArgs) then
        raise EXkcdArgError.Create('--cache-filename requires a value');
      Result.CacheFilename := AArgs[I];
    end
    else if LArg = '--db-filename' then
    begin
      Inc(I);
      if I > High(AArgs) then
        raise EXkcdArgError.Create('--db-filename requires a value');
      Result.DbFilename := AArgs[I];
    end
    else if Result.SubCommand = 'search' then
    begin
      if Result.SearchQuery <> '' then
        Result.SearchQuery := Result.SearchQuery + ' ';
      Result.SearchQuery := Result.SearchQuery + LArg;
    end
    else if Result.SubCommand = 'show' then
    begin
      if LArg.StartsWith('-') then
        raise EXkcdArgError.CreateFmt('Unknown option: %s', [LArg]);
      if Result.ComicID > 0 then
        raise EXkcdArgError.CreateFmt('Unexpected argument: %s', [LArg]);
      Result.ComicID := StrToIntDef(LArg, -2);
      if Result.ComicID = -2 then
        raise EXkcdArgError.CreateFmt('Invalid comic ID: %s', [LArg]);
    end
    else
      raise EXkcdArgError.CreateFmt('Unknown option: %s', [LArg]);
    Inc(I);
  end;

  if (Result.SubCommand = 'search') and (Result.SearchQuery = '') then
    raise EXkcdArgError.Create('search requires text');
end;

end.
