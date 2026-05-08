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
    NoCache: Boolean;
  end;

  EXkcdError = class(Exception);
  EXkcdArgError = class(EXkcdError);
  EXkcdHttpError = class(EXkcdError);
  EXkcdParseError = class(EXkcdError);
  EXkcdCacheError = class(EXkcdError);

implementation

end.
