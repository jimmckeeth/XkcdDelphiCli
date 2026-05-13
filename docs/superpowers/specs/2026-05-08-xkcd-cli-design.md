# xkcd Delphi CLI — Implementation Spec

**Date:** 2026-05-08  
**Scope:** kitty API + iTerm API + terminal detection demo + xkcd CLI Phases 1 & 2  
**Out of scope:** fzf integration, `--invert`/`--random` flags, macOS, built-in TUI (Phase 3–5)

---

## 1. Guiding Principle

No logic lives in `.dpr` files. Each `.dpr` is entry-point glue only (`begin/end`). All
testable behaviour lives in dedicated units that DUnitX can exercise directly.

---

## 2. Source Files

### 2.1 New API units

| File | Responsibility |
|---|---|
| `src/termdetectapi.pas` | Raw-mode I/O, `TerminalRequest`, all capability probes, `DetectProtocol`, `QueryTerminalSize`, `QueryBackgroundColor`, `IsDarkBackground` |
| `src/kittieapi.pas` | Kitty APC encoding — load+resize via Skia, chunk+base64, emit `ESC_G…ESC\` |
| `src/itermapi.pas` | iTerm OSC 1337 encoding — load+resize via Skia, base64, emit `ESC]1337;File=…BEL` |
| `src/termimageapi.pas` | Thin wrapper: `DisplayImage(path, protocol)` + `AutoDisplayImage(path)` |

### 2.2 New demo entry points

| File | Responsibility |
|---|---|
| `src/termdetectdemo.dpr` | Standalone terminal detection proof-of-concept |
| `src/kittydemo.dpr` | Already exists as shell — needs `kittieapi.pas` created |
| `src/itermdemo.dpr` | Already exists as shell — needs `itermapi.pas` created |

### 2.3 New xkcd CLI units

| File | Responsibility |
|---|---|
| `src/xkcdmodel.pas` | `TXkcdComicMeta`, `TXkcdComic`, `TXkcdCache` record types |
| `src/xkcdhtml.pas` | `ParseArchive`, `ParseComicPage`, `HtmlDecode` |
| `src/xkcdcache.pas` | JSON cache read/write, staleness check, `CachePath`, image caching |
| `src/xkcdhttp.pas` | `FetchArchive`, `FetchComic`, `FetchImageBytes` |
| `src/xkcdargs.pas` | Parses `argv` into `TXkcdOptions` record |
| `src/xkcdapp.pas` | Orchestration: load cache → select comic → fetch → display |
| `src/xkcdconsole.pas` | Windows UTF-8 console text setup and VT processing |
| `src/xkcd.dpr` | Entry point only — parse args, call `Run(options)` |

### 2.4 Test units

| File | Type | What it covers |
|---|---|---|
| `tests/testSixelApi.pas` | Unit | `MakeQuantKey`, RLE encoding, palette building |
| `tests/testKittieApi.pas` | Unit | Base64 chunking, APC escape format |
| `tests/testItermApi.pas` | Unit | OSC 1337 escape format |
| `tests/testTermDetect.pas` | Unit | Response string parsing (not raw I/O) |
| `tests/testXkcdHtml.pas` | Unit | `ParseArchive`, `ParseComicPage`, Unicode-aware `HtmlDecode` with fixture HTML |
| `tests/testXkcdCache.pas` | Unit | Cache write/read roundtrip, UTF-8 text preservation, staleness, path construction |
| `tests/testXkcdArgs.pas` | Unit | Argument parsing for all flag combinations |
| `tests/testXkcdHttp.pas` | Integration | `FetchArchive`, `FetchComic` against live xkcd.com |

---

## 3. Key Types (`xkcdmodel.pas`)

```pascal
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
    SubCommand: string;       // 'show' | 'update-cache'
    ShowLatest: Boolean;
    ComicID: Integer;         // -1 = not set
    NoTerminalGraphics: Boolean;
    Width: Integer;           // -1 = fit terminal
    CacheFilename: string;    // '' = default
    NoCache: Boolean;
  end;
```

---

## 4. `termdetectapi.pas`

### Exported types

```pascal
type
  TTerminalProtocol = (tpNone, tpSixel, tpKitty, tpKittyPlus, tpITerm);
  TTerminalSize = record WidthPx, HeightPx: Integer end;
  TRGBColor = record R, G, B: Byte end;
```

### Exported functions

```pascal
function  TerminalRequest(const ACmd: string; ATimeoutMs: Integer;
            const AEndChars: string): string;
function  DetectProtocol: TTerminalProtocol;
function  QueryTerminalSize: TTerminalSize;
function  QueryBackgroundColor: TRGBColor;
function  IsDarkBackground: Boolean;
```

### Platform strategy

- Raw mode: `{$IFDEF MSWINDOWS}` Console API / `{$ELSE}` termios
- Timeout read: Windows uses `GetTickCount64` + `_kbhit` poll; Linux uses `fpSelect`
- Both paths restore the original console/termios state in a finally block

### Protocol detection sequence

1. Kitty+ probe (1×1 query image with `f=100` JPEG) → look for `OK`
2. iTerm probe (`ESC]1337;ReportCellSize BEL`) → look for `ReportCellSize=`
3. Kitty probe (1×1 query with `f=24` RGB) → look for `OK`
4. DA1 probe (`ESC[c`) → parse response; `;4;` or `;4` in list → sixel
5. Otherwise → `tpNone`

### Testable pieces

The response-string parsers are extracted as standalone functions:
```pascal
function ParseDA1Response(const AResponse: string): Boolean;   // has sixel?
function ParseOSC11Response(const AResponse: string): TRGBColor;
function ParseTerminalSizeResponse(const AResponse: string): TTerminalSize;
```
These take a plain string and return a result — no terminal I/O, fully unit-testable.

---

## 5. `kittieapi.pas`

### Protocol

APC-based chunked base64. Each chunk ≤ 4096 bytes of base64 (`m=1` = more chunks, `m=0` = last):

```
ESC_G a=T,f=100,q=2,m=1;<base64-chunk>ESC\
ESC_G m=0;<base64-chunk>ESC\
```

### Implementation

1. `TSkImage.MakeFromEncodedFile` → load
2. Scale to fit `AMaxWidth` preserving aspect ratio
3. `TSkSurface.MakeRaster` + `DrawImageRect` → composite on white
4. `Surface.MakeImageSnapshot.EncodeToStream` → PNG bytes
5. `TNetEncoding.Base64.EncodeBytesToString` → base64
6. Chunk into 4096-char blocks, emit APC frames

### Exported functions

```pascal
// Testable encoding layer — takes raw PNG bytes, returns the full escape sequence string
function EncodeImageAsKitty(const APngBytes: TBytes): string;

// Public display entry point — loads file via Skia, calls EncodeImageAsKitty, writes to stdout
procedure DisplayImageAsKitty(const AFileName: string; AMaxWidth: Integer = 800);
```

---

## 6. `itermapi.pas`

### Protocol

Single OSC 1337 frame with full base64 payload:

```
ESC]1337;File=inline=1;width=auto:<base64>BEL
```

### Implementation

Same Skia load+resize as kitty; no chunking needed.

### Exported functions

```pascal
// Testable encoding layer — takes raw PNG bytes, returns the full escape sequence string
function EncodeImageAsITerm(const APngBytes: TBytes): string;

// Public display entry point — loads file via Skia, calls EncodeImageAsITerm, writes to stdout
procedure DisplayImageAsITerm(const AFileName: string; AMaxWidth: Integer = 800);
```

---

## 7. `termimageapi.pas`

```pascal
procedure DisplayImage(const AFileName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer = 800);
// Routes to sixelapi / kittieapi / itermapi / OS viewer based on AProtocol

procedure AutoDisplayImage(const AFileName: string; AMaxWidth: Integer = 800);
// Calls DetectProtocol then DisplayImage
```

OS viewer fallback (tpNone):
- Windows: `ShellExecute(0, 'open', PChar(AFileName), nil, nil, SW_SHOWNORMAL)`
- Linux: `TProcess` with `xdg-open`

---

## 8. `xkcdhtml.pas`

### `ParseArchive(const AHtml: string): TArray<TXkcdComicMeta>`

Regex: `<a href="(/(\d+)/)">([^<]+)</a>`  
Applied to the full archive HTML (no need to extract the div first — the pattern is specific enough).

### `ParseComicPage(const AHtml: string; out AImgSrc, ASubText: string)`

Regex: `<div id="comic">.*?<img src="//([^"]+)"[^>]+title="([^"]+)"` with `roSingleLine`.  
Prefix `https:` to `//` URL.

### `HtmlDecode(const S: string): string`

Handles the basic XML/HTML entities, common Unicode punctuation entities used in captions (`&rsquo;`, `&ldquo;`, `&mdash;`, `&hellip;`, etc.), decimal numeric entities, and hex numeric entities. Numeric entity decoding is Unicode-code-point aware: values above `$FFFF` are emitted as valid UTF-16 surrogate pairs instead of being truncated to a single `WideChar`.

Numeric entities are decoded before named entities so escaped numeric text like `&amp;#65;` remains literal text after decoding.

---

## 9. `xkcdcache.pas`

### Cache path

```pascal
function CachePath(const AOverride: string = ''): string;
// TPath.GetHomePath + '.cache/xkcd-cli/cache.json' unless overridden
```

### Image cache path

```pascal
function ComicImageCachePath(AComicID: Integer): string;
// ~/.cache/xkcd-cli/images/<id>.png
```

Each comic image is saved to this path on first display; subsequent shows load from disk.

### Detail cache path

```pascal
function ComicDetailCachePath(AComicID: Integer): string;
// ~/.cache/xkcd-cli/detail/<id>.json
```

Each comic detail cache file stores the image URL and decoded subtext/caption. Detail JSON is read and written as UTF-8.

### Staleness

```pascal
function IsStale(const ALastUpdated: TDateTime): Boolean;
// True if (Now - ALastUpdated) > 1.0 (24 hours)
```

### JSON format

Matches Python version exactly for cross-tool compatibility:
```json
{ "last_updated": "2024-01-15T12:00:00+00:00", "comics": [...] }
```

Metadata and detail JSON must preserve Unicode text exactly across write/read roundtrips.

---

## 10. `xkcdhttp.pas`

```pascal
function FetchArchiveHtml: string;           // GET https://xkcd.com/archive/
function FetchComicHtml(AID: Integer): string; // GET https://xkcd.com/N/
procedure FetchImageToFile(const AURL, ADestPath: string); // stream to file
```

Uses `THTTPClient` from `System.Net.HttpClient`. Sets a User-Agent header.
On HTTP error, raises `EXkcdHttpError` with status code in message.

---

## 11. `xkcdapp.pas`

### `Run(const AOptions: TXkcdOptions)`

```
1. ForceDirectories(cache dir)
2. If AOptions.SubCommand = 'update-cache': fetch archive, save cache, exit
3. Load cache; if missing or stale, fetch + save
4. Select comic:
   - ShowLatest → Comics[0]
   - ComicID set → find by ID (raise if not found)
   - default → Comics[0] (fzf deferred to Phase 4)
5. FetchComicHtml → ParseComicPage → get ImgSrc, decoded Unicode SubText, and detail cache it
6. Check image cache; if miss, FetchImageToFile to cache path
7. Writeln(Title); Writeln(SubText)
8. If NoTerminalGraphics: OS viewer open; else AutoDisplayImage(cached path)
```

---

## 12. `xkcdargs.pas`

### Parses

```
xkcd show [--latest] [--comic-id N] [--no-terminal-graphics] [--width N]
          [--no-cache] [--cache-filename PATH]
xkcd update-cache [--cache-filename PATH]
```

Returns `TXkcdOptions`. Prints usage and raises `EXkcdArgError` on invalid input.

`--no-cache` bypasses metadata and detail cache reads so stale captions can be refetched and rewritten.

---

## 13. `termdetectdemo.dpr`

Standalone demo (no graphics output) that:
1. Enables VT processing (Windows)
2. Calls `DetectProtocol` → prints which protocol was detected
3. Calls `QueryTerminalSize` → prints pixel dimensions
4. Calls `QueryBackgroundColor` → prints RGB values
5. Calls `IsDarkBackground` → prints True/False

---

## 14. Project Files

Each new `.dpr` gets a matching `.dproj` copied from `sixeldemo.dproj` with:
- `<MainSource>` updated
- `<ProjectGuid>` regenerated
- Appropriate `<DCCReference>` entries

`tests/XkcdTests.dproj` gains `<DCCReference>` for each new test unit.

---

## 15. Test Coverage Summary

| Test unit | Key cases |
|---|---|
| `testSixelApi` | `MakeQuantKey` bit layout, RLE `!3~` for 3 identical pixels, palette ≤ 256 entries |
| `testKittieApi` | Base64 chunk split at 4096, first frame has `m=1`, last has `m=0`, APC delimiters correct |
| `testItermApi` | OSC frame starts with `ESC]1337;File=inline=1;`, ends with BEL, valid base64 |
| `testTermDetect` | `ParseDA1Response` detects `;4;` and `4` edge cases; `ParseOSC11Response` handles 2- and 4-digit hex; `ParseTerminalSizeResponse` extracts px W×H |
| `testXkcdHtml` | Archive parse returns correct IDs/titles from fixture; comic parse extracts img+subtext; `HtmlDecode` handles named entities, decimal/hex numeric entities, and non-BMP Unicode code points |
| `testXkcdCache` | Write+read roundtrip preserves all fields and Unicode text; detail cache preserves Unicode captions; stale at 25h, fresh at 23h; `CachePath` uses home dir |
| `testXkcdArgs` | `show --latest`, `show --comic-id 42`, `update-cache`, unknown flag raises error |
| `testXkcdHttp` | (Integration) Archive returns >100 comics; comic 1 has known title "Barrel - Part 1" |
