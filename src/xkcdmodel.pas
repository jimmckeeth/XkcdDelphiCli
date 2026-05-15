// Copyright (c) 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit xkcdmodel;

interface

uses System.SysUtils;

type
  TXkcdComicMeta = record
    ID: Integer;
    HRef: string;
    Title: string;
  end;

  TXkcdComic = record
    Meta: TXkcdComicMeta;
    ImgSrc: string;
    SubText: string;
  end;

  TXkcdExplanation = record
    ComicID: Integer;
    ExplainUrl: string;
    Transcript: string;
    Explanation: string;
  end;

  TXkcdSearchResult = record
    ComicID: Integer;
    Title: string;
    Snippet: string;
    Transcript: string;
    Explanation: string;
  end;

  TXkcdCache = record
    LastUpdated: TDateTime;
    Comics: TArray<TXkcdComicMeta>;
  end;

  TXkcdOptions = record
    SubCommand: string;          // 'show' | 'update-cache'
    ShowLatest: Boolean;
    ComicID: Integer;            // -1 = not set
    NoTerminalGraphics: Boolean;
    Width: Integer;              // -1 = fit terminal
    CacheFilename: string;       // '' = use default
    DbFilename: string;          // '' = use default
    SearchQuery: string;
    IncludeExplanation: Boolean;
    IncludeTranscript: Boolean;
    NoCache: Boolean;
    Invert: Boolean;
  end;

  EXkcdError = class(Exception);
  EXkcdArgError = class(EXkcdError);
  EXkcdHttpError = class(EXkcdError);
  EXkcdParseError = class(EXkcdError);
  EXkcdCacheError = class(EXkcdError);

implementation

end.
