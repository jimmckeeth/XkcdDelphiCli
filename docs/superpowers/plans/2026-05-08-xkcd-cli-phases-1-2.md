# xkcd CLI + Terminal Image APIs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build kitty/iTerm image encoding APIs, a terminal detection demo, and the xkcd CLI (HTTP + cache + HTML parse + image display) with full DUnitX test coverage.

**Status note (updated 2026-05-13):** This is a historical implementation plan. The current codebase includes later fixes beyond the original checklist, including Unicode-aware caption handling. Current behavior is: HTTP responses are read as UTF-8, metadata/detail JSON caches are read and written as UTF-8, `HtmlDecode` supports common Unicode named entities plus decimal/hex numeric entities including non-BMP code points, and the Windows CLI configures UTF-8 console text output in `xkcdconsole`.

**Architecture:** All logic lives in focused units (`xkcdmodel`, `xkcdhtml`, `xkcdcache`, `xkcdargs`, `xkcdhttp`, `xkcdapp`, `termdetectapi`, `kittieapi`, `itermapi`, `termimageapi`). Every `.dpr` is a glue-only entry point with no business logic. One DUnitX test unit per feature unit. Terminal raw-mode I/O is isolated in `termdetectapi` behind parser helpers that are unit-testable without a real terminal.

**Tech Stack:** Delphi 12 / BDS 37.0, System.Skia (image load/resize), System.Net.HttpClient (HTTP), System.JSON (UTF-8 cache), System.RegularExpressions (HTML parse), Unicode-aware HTML entity decoding, System.NetEncoding (base64), DUnitX (tests), Winapi.Windows + Posix.Termios (terminal I/O)

---

## File Map

**New source units:**
- `src/xkcdmodel.pas` — shared record types and exception classes
- `src/xkcdhtml.pas` — `ParseArchive`, `ParseComicPage`, `HtmlDecode`
- `src/xkcdcache.pas` — cache path helpers, JSON read/write, staleness check
- `src/xkcdargs.pas` — `ParseArgs(TArray<string>): TXkcdOptions`
- `src/xkcdhttp.pas` — `FetchArchiveHtml`, `FetchComicHtml`, `FetchImageToFile`
- `src/xkcdapp.pas` — `Run(TXkcdOptions)` orchestration
- `src/termdetectapi.pas` — parser helpers + raw-mode I/O + `DetectProtocol`
- `src/kittieapi.pas` — `EncodeImageAsKitty(TBytes)` + `DisplayImageAsKitty`
- `src/itermapi.pas` — `EncodeImageAsITerm(TBytes)` + `DisplayImageAsITerm`
- `src/termimageapi.pas` — `DisplayImage` routing wrapper

**New demo entry points:**
- `src/termdetectdemo.dpr` + `.dproj` — terminal detection proof-of-concept

**Modified source files:**
- `src/sixelapi.pas` — expose `MakeQuantKey` and `ColorDist` in interface section
- `src/kittydemo.dpr` — call `DisplayImageAsKitty` instead of `DisplayImageAsSixel`
- `src/kittydemo.dproj` — update `DCCReference` list
- `src/itermdemo.dpr` — call `DisplayImageAsITerm` instead of `DisplayImageAsSixel`
- `src/itermdemo.dproj` — update `DCCReference` list
- `src/xkcd.dpr` — full rewrite as entry-point-only glue
- `src/xkcd.dproj` — update `DCCReference` list

**New test units:**
- `tests/testXkcdHtml.pas`
- `tests/testXkcdCache.pas`
- `tests/testXkcdArgs.pas`
- `tests/testXkcdHttp.pas`
- `tests/testTermDetect.pas`
- `tests/testKittieApi.pas`
- `tests/testItermApi.pas`

**Modified test files:**
- `tests/testSixelApi.pas` — fill in actual test methods
- `tests/XkcdTests.dpr` — add all new test units to `uses`
- `tests/XkcdTests.dproj` — add Win64 unit search path; add all new `DCCReference` entries

---

## Build commands (use throughout the plan)

```powershell
# Build test project (Win64):
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64

# Run tests:
.\bin\Win64\Debug\XkcdTests.exe

# Build a source project (replace xkcd with the target name):
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "src\xkcd.dproj" -Platform Win64
```

> **Note:** `XkcdTests.exe` requires `sk4d.dll` at runtime (pulled in via `sixelapi.pas`).
> After the first successful test build, copy `sk4d.dll` from `bin\Win64\Debug\sixeldemo\` to
> `bin\Win64\Debug\` (or wherever the test exe lives). Check the output directory in the build log.

---

## Task 1: Fix XkcdTests.dproj — add Win64 unit search path

The existing dproj has a Win32 search path to `../src` but is missing the equivalent for Win64. Without this, none of the `src/` units will compile when targeting Win64.

**Files:**
- Modify: `tests/XkcdTests.dproj`

- [ ] **Step 1: Add missing Win64 property groups**

In `tests/XkcdTests.dproj`, after the closing `</PropertyGroup>` of the `Cfg_1_Win32` block (currently around line 96), add:

```xml
    <PropertyGroup Condition="('$(Platform)'=='Win64' and '$(Base)'=='true') or '$(Base_Win64)'!=''">
        <Base_Win64>true</Base_Win64>
        <CfgParent>Base</CfgParent>
        <Base>true</Base>
        <DCC_Namespace>Winapi;System.Win;Data.Win;Datasnap.Win;Web.Win;Soap.Win;Xml.Win;$(DCC_Namespace)</DCC_Namespace>
    </PropertyGroup>
    <PropertyGroup Condition="('$(Platform)'=='Win64' and '$(Cfg_1)'=='true') or '$(Cfg_1_Win64)'!=''">
        <Cfg_1_Win64>true</Cfg_1_Win64>
        <CfgParent>Cfg_1</CfgParent>
        <Cfg_1>true</Cfg_1>
        <Base>true</Base>
        <AppDPIAwarenessMode>none</AppDPIAwarenessMode>
        <Manifest_File>(None)</Manifest_File>
        <DCC_UnitSearchPath>..\lib\Win64\Debug;..\src;$(DUnitX);$(DCC_UnitSearchPath)</DCC_UnitSearchPath>
    </PropertyGroup>
```

- [ ] **Step 2: Build the existing (empty) test project for Win64 to confirm it compiles**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
```

Expected: build succeeds with no errors.

- [ ] **Step 3: Commit**

```
git add tests/XkcdTests.dproj
git commit -m "fix: add Win64 unit search path to XkcdTests.dproj"
```

---

## Task 2: xkcdmodel.pas — shared types

Pure record types and exception classes. No logic, no tests needed.

**Files:**
- Create: `src/xkcdmodel.pas`

- [ ] **Step 1: Create `src/xkcdmodel.pas`**

```pascal
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
```

- [ ] **Step 2: Commit**

```
git add src/xkcdmodel.pas
git commit -m "feat: add xkcdmodel shared types and exception classes"
```

---

## Task 3: xkcdhtml.pas (TDD)

HTML parsing for the xkcd archive page and individual comic pages. Fully testable with fixture strings — no network needed.

**Files:**
- Create: `src/xkcdhtml.pas`
- Create: `tests/testXkcdHtml.pas`
- Modify: `tests/XkcdTests.dpr` (add unit to uses)
- Modify: `tests/XkcdTests.dproj` (add DCCReference)

- [ ] **Step 1: Create `tests/testXkcdHtml.pas`**

```pascal
unit testXkcdHtml;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdHtml = class
  public
    [Test]
    procedure ParseArchiveExtractsComics;
    [Test]
    procedure ParseArchiveReturnsEmptyWhenNoMatches;
    [Test]
    procedure ParseComicPageExtractsImgAndSubtext;
    [Test]
    procedure ParseComicPageRaisesOnMissingImg;
    [Test]
    procedure HtmlDecodeHandlesNamedEntities;
    [Test]
    procedure HtmlDecodeHandlesNumericEntities;
  end;

implementation

uses xkcdhtml, xkcdmodel, System.SysUtils;

const
  CSampleArchiveHtml =
    '<div id="middleContainer">' +
    '<a href="/3/">Forgot to Hit Send</a>' +
    '<a href="/2/">Game &amp; AIs</a>' +
    '<a href="/1/">Barrel - Part 1</a>' +
    '</div>';

  CSampleComicHtml =
    '<div id="comic">' +
    '<img src="//imgs.xkcd.com/comics/barrel.jpg" ' +
    'title="Don&apos;t we all." /></div>';

procedure TTestXkcdHtml.ParseArchiveExtractsComics;
var
  LResult: TArray<TXkcdComicMeta>;
begin
  LResult := ParseArchive(CSampleArchiveHtml);
  Assert.AreEqual(3, Length(LResult));
  Assert.AreEqual(3, LResult[0].ID);
  Assert.AreEqual('/3/', LResult[0].HRef);
  Assert.AreEqual('Forgot to Hit Send', LResult[0].Title);
  Assert.AreEqual(2, LResult[1].ID);
  Assert.AreEqual('Game & AIs', LResult[1].Title, 'Should decode &amp;');
  Assert.AreEqual(1, LResult[2].ID);
end;

procedure TTestXkcdHtml.ParseArchiveReturnsEmptyWhenNoMatches;
var
  LResult: TArray<TXkcdComicMeta>;
begin
  LResult := ParseArchive('<html><body>no comics here</body></html>');
  Assert.AreEqual(0, Length(LResult));
end;

procedure TTestXkcdHtml.ParseComicPageExtractsImgAndSubtext;
var
  LImgSrc, LSubText: string;
begin
  ParseComicPage(CSampleComicHtml, LImgSrc, LSubText);
  Assert.AreEqual('https://imgs.xkcd.com/comics/barrel.jpg', LImgSrc);
  Assert.AreEqual('Don''t we all.', LSubText, 'Should decode &apos; (&#39;)');
end;

procedure TTestXkcdHtml.ParseComicPageRaisesOnMissingImg;
begin
  Assert.WillRaise(
    procedure
    begin
      var LImg, LSub: string;
      ParseComicPage('<html>no comic div</html>', LImg, LSub);
    end,
    EXkcdParseError);
end;

procedure TTestXkcdHtml.HtmlDecodeHandlesNamedEntities;
begin
  Assert.AreEqual('a & b < c > d "e"', HtmlDecode('a &amp; b &lt; c &gt; d &quot;e&quot;'));
  Assert.AreEqual('it''s', HtmlDecode('it&#39;s'));
end;

procedure TTestXkcdHtml.HtmlDecodeHandlesNumericEntities;
begin
  Assert.AreEqual('A', HtmlDecode('&#65;'));
  Assert.AreEqual('©', HtmlDecode('&#169;'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdHtml);

end.
```

- [ ] **Step 2: Add to XkcdTests.dpr and XkcdTests.dproj**

In `tests/XkcdTests.dpr`, add `testXkcdHtml in 'testXkcdHtml.pas'` to the `uses` clause.

In `tests/XkcdTests.dproj`, add inside the `<ItemGroup>` block:
```xml
<DCCReference Include="testXkcdHtml.pas"/>
```

- [ ] **Step 3: Build — expect compile error (xkcdhtml.pas doesn't exist yet)**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
```

Expected: `Fatal: F2613 Unit 'xkcdhtml' not found`

- [ ] **Step 4: Create `src/xkcdhtml.pas`**

```pascal
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

function HtmlDecode(const S: string): string;
begin
  Result := S
    .Replace('&amp;',  '&')
    .Replace('&lt;',   '<')
    .Replace('&gt;',   '>')
    .Replace('&quot;', '"')
    .Replace('&apos;', '''')
    .Replace('&#39;',  '''');
  Result := TRegEx.Replace(Result, '&#(\d+);',
    function(const AMatch: TMatch): string
    begin
      Result := Chr(StrToIntDef(AMatch.Groups[1].Value, 63));
    end);
end;

function ParseArchive(const AHtml: string): TArray<TXkcdComicMeta>;
var
  LMatches: TMatchCollection;
  LMeta: TXkcdComicMeta;
  LList: TList<TXkcdComicMeta>;
begin
  LList := TList<TXkcdComicMeta>.Create;
  try
    LMatches := TRegEx.Matches(AHtml, '<a href="(/(\d+)/)">([^<]+)</a>');
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
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(AHtml,
    '<div id="comic">.*?<img src="//([^"]+)"[^>]+title="([^"]+)"',
    [roSingleLine]);
  if not LMatch.Success then
    raise EXkcdParseError.Create('Comic image not found in page HTML');
  AImgSrc  := 'https://' + LMatch.Groups[1].Value;
  ASubText := HtmlDecode(LMatch.Groups[2].Value);
end;

end.
```

- [ ] **Step 5: Build and run tests — expect all pass**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
.\bin\Win64\Debug\XkcdTests.exe
```

Expected: `TTestXkcdHtml` — 6 tests passed.

- [ ] **Step 6: Commit**

```
git add src/xkcdhtml.pas tests/testXkcdHtml.pas tests/XkcdTests.dpr tests/XkcdTests.dproj
git commit -m "feat: add xkcdhtml parsing with tests"
```

---

## Task 4: xkcdcache.pas (TDD)

Cache path helpers, JSON read/write, and staleness check. Tests write to a temp directory — no network, no filesystem side effects in the source directory.

**Files:**
- Create: `src/xkcdcache.pas`
- Create: `tests/testXkcdCache.pas`
- Modify: `tests/XkcdTests.dpr`, `tests/XkcdTests.dproj`

- [ ] **Step 1: Create `tests/testXkcdCache.pas`**

```pascal
unit testXkcdCache;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdCache = class
  private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure CachePathUsesHomeDir;
    [Test]
    procedure CachePathReturnsOverrideWhenProvided;
    [Test]
    procedure ComicImageCachePathIncludesComicId;
    [Test]
    procedure IsStaleReturnsTrueAfter25Hours;
    [Test]
    procedure IsStaleReturnsFalseAt23Hours;
    [Test]
    procedure SaveAndLoadRoundtrip;
    [Test]
    procedure CacheExistsReturnsFalseForMissingFile;
  end;

implementation

uses
  xkcdcache, xkcdmodel,
  System.SysUtils, System.IOUtils, System.DateUtils;

procedure TTestXkcdCache.Setup;
begin
  FTempFile := TPath.Combine(TPath.GetTempPath, 'xkcd_test_cache_' + IntToStr(GetTickCount) + '.json');
end;

procedure TTestXkcdCache.TearDown;
begin
  if TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
end;

procedure TTestXkcdCache.CachePathUsesHomeDir;
var
  LPath: string;
begin
  LPath := CachePath;
  Assert.IsTrue(LPath.Contains('.cache'), 'Cache path should contain .cache');
  Assert.IsTrue(LPath.Contains('xkcd-cli'), 'Cache path should contain xkcd-cli');
  Assert.IsTrue(LPath.EndsWith('cache.json'), 'Cache path should end with cache.json');
end;

procedure TTestXkcdCache.CachePathReturnsOverrideWhenProvided;
begin
  Assert.AreEqual('C:\custom\path.json', CachePath('C:\custom\path.json'));
end;

procedure TTestXkcdCache.ComicImageCachePathIncludesComicId;
var
  LPath: string;
begin
  LPath := ComicImageCachePath(42);
  Assert.IsTrue(LPath.Contains('42.png'), 'Image path should include comic id + .png');
  Assert.IsTrue(LPath.Contains('xkcd-cli'), 'Image path should be in xkcd-cli dir');
end;

procedure TTestXkcdCache.IsStaleReturnsTrueAfter25Hours;
begin
  Assert.IsTrue(IsStale(Now - 1.1), '25+ hours old should be stale');
end;

procedure TTestXkcdCache.IsStaleReturnsFalseAt23Hours;
begin
  Assert.IsFalse(IsStale(Now - 0.9), '23 hours old should not be stale');
end;

procedure TTestXkcdCache.SaveAndLoadRoundtrip;
var
  LOriginal, LLoaded: TXkcdCache;
begin
  LOriginal.LastUpdated := EncodeDateTime(2024, 1, 15, 12, 0, 0, 0);
  SetLength(LOriginal.Comics, 2);
  LOriginal.Comics[0].ID    := 3;
  LOriginal.Comics[0].HRef  := '/3/';
  LOriginal.Comics[0].Title := 'Forgot to Hit Send';
  LOriginal.Comics[1].ID    := 1;
  LOriginal.Comics[1].HRef  := '/1/';
  LOriginal.Comics[1].Title := 'Barrel - Part 1';

  SaveCache(LOriginal, FTempFile);
  Assert.IsTrue(TFile.Exists(FTempFile), 'Cache file should exist after save');

  LLoaded := LoadCache(FTempFile);
  Assert.AreEqual(2, Length(LLoaded.Comics));
  Assert.AreEqual(3, LLoaded.Comics[0].ID);
  Assert.AreEqual('/3/', LLoaded.Comics[0].HRef);
  Assert.AreEqual('Forgot to Hit Send', LLoaded.Comics[0].Title);
  Assert.AreEqual(1, LLoaded.Comics[1].ID);
end;

procedure TTestXkcdCache.CacheExistsReturnsFalseForMissingFile;
begin
  Assert.IsFalse(CacheExists(FTempFile), 'File should not exist yet');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdCache);

end.
```

- [ ] **Step 2: Add to XkcdTests.dpr and XkcdTests.dproj**

In `tests/XkcdTests.dpr`, add `testXkcdCache in 'testXkcdCache.pas'` to uses.

In `tests/XkcdTests.dproj` ItemGroup:
```xml
<DCCReference Include="testXkcdCache.pas"/>
```

- [ ] **Step 3: Build — expect compile error (xkcdcache.pas missing)**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
```

Expected: `Fatal: F2613 Unit 'xkcdcache' not found`

- [ ] **Step 4: Create `src/xkcdcache.pas`**

```pascal
unit xkcdcache;

interface

uses xkcdmodel;

function CachePath(const AOverride: string = ''): string;
function ComicImageCachePath(AComicID: Integer): string;
function IsStale(const ALastUpdated: TDateTime): Boolean;
function CacheExists(const APath: string): Boolean;
function LoadCache(const APath: string): TXkcdCache;
procedure SaveCache(const ACache: TXkcdCache; const APath: string);

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  System.DateUtils;

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
        LObj       := LArr.Items[I] as TJSONObject;
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
    ForceDirectories(ExtractFileDir(APath));
    TFile.WriteAllText(APath, LRoot.ToJSON, TEncoding.UTF8);
  finally
    LRoot.Free;
  end;
end;

end.
```

- [ ] **Step 5: Build and run — expect all pass**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
.\bin\Win64\Debug\XkcdTests.exe
```

Expected: `TTestXkcdCache` — 7 tests passed.

- [ ] **Step 6: Commit**

```
git add src/xkcdcache.pas tests/testXkcdCache.pas tests/XkcdTests.dpr tests/XkcdTests.dproj
git commit -m "feat: add xkcdcache JSON read/write with tests"
```

---

## Task 5: xkcdargs.pas (TDD)

Argument parsing. Takes `TArray<string>` (not `ParamStr`) so it is fully unit-testable.

**Files:**
- Create: `src/xkcdargs.pas`
- Create: `tests/testXkcdArgs.pas`
- Modify: `tests/XkcdTests.dpr`, `tests/XkcdTests.dproj`

- [ ] **Step 1: Create `tests/testXkcdArgs.pas`**

```pascal
unit testXkcdArgs;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdArgs = class
  public
    [Test]
    procedure ShowLatestParsesCorrectly;
    [Test]
    procedure ShowComicIdParsesCorrectly;
    [Test]
    procedure UpdateCacheParsesCorrectly;
    [Test]
    procedure NoTerminalGraphicsFlagParsed;
    [Test]
    procedure CacheFilenameParsed;
    [Test]
    procedure NoCacheFlagParsed;
    [Test]
    procedure UnknownCommandRaisesArgError;
    [Test]
    procedure UnknownFlagRaisesArgError;
    [Test]
    procedure MissingComicIdValueRaisesArgError;
    [Test]
    procedure NoArgsRaisesArgError;
  end;

implementation

uses xkcdargs, xkcdmodel, System.SysUtils;

procedure TTestXkcdArgs.ShowLatestParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--latest']);
  Assert.AreEqual('show', LOptions.SubCommand);
  Assert.IsTrue(LOptions.ShowLatest);
  Assert.AreEqual(-1, LOptions.ComicID);
  Assert.IsFalse(LOptions.NoTerminalGraphics);
end;

procedure TTestXkcdArgs.ShowComicIdParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--comic-id', '42']);
  Assert.AreEqual('show', LOptions.SubCommand);
  Assert.AreEqual(42, LOptions.ComicID);
  Assert.IsFalse(LOptions.ShowLatest);
end;

procedure TTestXkcdArgs.UpdateCacheParsesCorrectly;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['update-cache']);
  Assert.AreEqual('update-cache', LOptions.SubCommand);
end;

procedure TTestXkcdArgs.NoTerminalGraphicsFlagParsed;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--latest', '--no-terminal-graphics']);
  Assert.IsTrue(LOptions.NoTerminalGraphics);
end;

procedure TTestXkcdArgs.CacheFilenameParsed;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--latest', '--cache-filename', 'C:\my\cache.json']);
  Assert.AreEqual('C:\my\cache.json', LOptions.CacheFilename);
end;

procedure TTestXkcdArgs.NoCacheFlagParsed;
var
  LOptions: TXkcdOptions;
begin
  LOptions := ParseArgs(['show', '--latest', '--no-cache']);
  Assert.IsTrue(LOptions.NoCache);
end;

procedure TTestXkcdArgs.UnknownCommandRaisesArgError;
begin
  Assert.WillRaise(
    procedure begin ParseArgs(['fly']); end,
    EXkcdArgError);
end;

procedure TTestXkcdArgs.UnknownFlagRaisesArgError;
begin
  Assert.WillRaise(
    procedure begin ParseArgs(['show', '--explode']); end,
    EXkcdArgError);
end;

procedure TTestXkcdArgs.MissingComicIdValueRaisesArgError;
begin
  Assert.WillRaise(
    procedure begin ParseArgs(['show', '--comic-id']); end,
    EXkcdArgError);
end;

procedure TTestXkcdArgs.NoArgsRaisesArgError;
begin
  Assert.WillRaise(
    procedure begin ParseArgs([]); end,
    EXkcdArgError);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdArgs);

end.
```

- [ ] **Step 2: Add to XkcdTests.dpr and XkcdTests.dproj**

Add `testXkcdArgs in 'testXkcdArgs.pas'` to `tests/XkcdTests.dpr` uses.

Add to `tests/XkcdTests.dproj` ItemGroup:
```xml
<DCCReference Include="testXkcdArgs.pas"/>
```

- [ ] **Step 3: Build — expect compile error (xkcdargs.pas missing)**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
```

Expected: `Fatal: F2613 Unit 'xkcdargs' not found`

- [ ] **Step 4: Create `src/xkcdargs.pas`**

```pascal
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
  Result.SubCommand          := '';
  Result.ShowLatest          := False;
  Result.ComicID             := -1;
  Result.NoTerminalGraphics  := False;
  Result.Width               := -1;
  Result.CacheFilename       := '';
  Result.NoCache             := False;

  if Length(AArgs) = 0 then
    raise EXkcdArgError.Create('Usage: xkcd <show|update-cache> [options]');

  Result.SubCommand := LowerCase(AArgs[0]);
  if (Result.SubCommand <> 'show') and (Result.SubCommand <> 'update-cache') then
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
    else
      raise EXkcdArgError.CreateFmt('Unknown option: %s', [LArg]);
    Inc(I);
  end;
end;

end.
```

- [ ] **Step 5: Build and run — expect all pass**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
.\bin\Win64\Debug\XkcdTests.exe
```

Expected: `TTestXkcdArgs` — 10 tests passed.

- [ ] **Step 6: Commit**

```
git add src/xkcdargs.pas tests/testXkcdArgs.pas tests/XkcdTests.dpr tests/XkcdTests.dproj
git commit -m "feat: add xkcdargs parser with tests"
```

---

## Task 6: xkcdhttp.pas (integration tests)

HTTP fetching. Integration tests hit live xkcd.com — they need a network connection and are tagged `[Category('Integration')]` so they can be excluded from offline CI.

**Files:**
- Create: `src/xkcdhttp.pas`
- Create: `tests/testXkcdHttp.pas`
- Modify: `tests/XkcdTests.dpr`, `tests/XkcdTests.dproj`

- [ ] **Step 1: Create `tests/testXkcdHttp.pas`**

```pascal
unit testXkcdHttp;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestXkcdHttp = class
  public
    [Test]
    [Category('Integration')]
    procedure FetchArchiveReturnsHtml;
    [Test]
    [Category('Integration')]
    procedure FetchComicOneHasKnownTitle;
    [Test]
    [Category('Integration')]
    procedure FetchImageToFileCreatesFile;
  end;

implementation

uses
  xkcdhttp, xkcdhtml, xkcdmodel,
  System.SysUtils, System.IOUtils;

procedure TTestXkcdHttp.FetchArchiveReturnsHtml;
var
  LHtml: string;
  LComics: TArray<TXkcdComicMeta>;
begin
  LHtml   := FetchArchiveHtml;
  LComics := ParseArchive(LHtml);
  Assert.IsTrue(Length(LComics) > 100, 'Archive should have >100 comics');
  Assert.IsTrue(LHtml.Contains('xkcd'), 'Response should contain xkcd');
end;

procedure TTestXkcdHttp.FetchComicOneHasKnownTitle;
var
  LHtml: string;
  LImgSrc, LSubText: string;
begin
  LHtml := FetchComicHtml(1);
  ParseComicPage(LHtml, LImgSrc, LSubText);
  Assert.IsTrue(LImgSrc.Contains('barrel'), 'Comic 1 image should be barrel');
end;

procedure TTestXkcdHttp.FetchImageToFileCreatesFile;
var
  LPath: string;
begin
  LPath := TPath.Combine(TPath.GetTempPath, 'xkcd_http_test.png');
  try
    FetchImageToFile('https://imgs.xkcd.com/comics/barrel.jpg', LPath);
    Assert.IsTrue(TFile.Exists(LPath), 'Image file should exist after download');
    Assert.IsTrue(TFile.GetSize(LPath) > 1000, 'Image should be non-trivially large');
  finally
    if TFile.Exists(LPath) then TFile.Delete(LPath);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXkcdHttp);

end.
```

- [ ] **Step 2: Add to XkcdTests.dpr and XkcdTests.dproj**

Add `testXkcdHttp in 'testXkcdHttp.pas'` to `tests/XkcdTests.dpr` uses.

Add to `tests/XkcdTests.dproj` ItemGroup:
```xml
<DCCReference Include="testXkcdHttp.pas"/>
```

- [ ] **Step 3: Create `src/xkcdhttp.pas`**

```pascal
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
  System.IOUtils;

const
  CUserAgent = 'xkcd-delphi-cli/1.0';
  CBaseUrl   = 'https://xkcd.com';

function MakeClient: THTTPClient;
begin
  Result            := THTTPClient.Create;
  Result.UserAgent  := CUserAgent;
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
```

- [ ] **Step 4: Build and run — expect integration tests pass (requires network)**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
.\bin\Win64\Debug\XkcdTests.exe
```

Expected: `TTestXkcdHttp` — 3 tests passed.

- [ ] **Step 5: Commit**

```
git add src/xkcdhttp.pas tests/testXkcdHttp.pas tests/XkcdTests.dpr tests/XkcdTests.dproj
git commit -m "feat: add xkcdhttp fetchers with integration tests"
```

---

## Task 7: termdetectapi.pas — parser helpers (TDD)

The response-string parsers are pure functions with no terminal I/O — fully unit-testable. Implement and test these before tackling the raw-mode I/O in Task 8.

**Files:**
- Create: `src/termdetectapi.pas` (parsers + type declarations; I/O stubs for now)
- Create: `tests/testTermDetect.pas`
- Modify: `tests/XkcdTests.dpr`, `tests/XkcdTests.dproj`

- [ ] **Step 1: Create `tests/testTermDetect.pas`**

```pascal
unit testTermDetect;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestTermDetect = class
  public
    [Test]
    procedure ParseDA1ReturnsTrueWhenSixelPresent;
    [Test]
    procedure ParseDA1ReturnsTrueWhenSixelAtEnd;
    [Test]
    procedure ParseDA1ReturnsFalseWhenNoSixel;
    [Test]
    procedure ParseDA1ReturnsFalseForEmptyString;
    [Test]
    procedure ParseOSC11ParsesFourDigitHex;
    [Test]
    procedure ParseOSC11ParsesTwoDigitHex;
    [Test]
    procedure ParseOSC11DarkBackground;
    [Test]
    procedure ParseTermSizeExtractsWidthAndHeight;
  end;

implementation

uses termdetectapi, System.SysUtils;

// DA1 response looks like: ESC[?62;4;22c  (semicolon-separated attributes)
// We receive it as a plain string after stripping the ESC[ prefix.

procedure TTestTermDetect.ParseDA1ReturnsTrueWhenSixelPresent;
begin
  // Typical response with sixel attribute 4 in middle
  Assert.IsTrue(ParseDA1Response(#$1B + '[?62;4;22c'));
end;

procedure TTestTermDetect.ParseDA1ReturnsTrueWhenSixelAtEnd;
begin
  Assert.IsTrue(ParseDA1Response(#$1B + '[?62;22;4c'));
end;

procedure TTestTermDetect.ParseDA1ReturnsFalseWhenNoSixel;
begin
  Assert.IsFalse(ParseDA1Response(#$1B + '[?62;22c'));
end;

procedure TTestTermDetect.ParseDA1ReturnsFalseForEmptyString;
begin
  Assert.IsFalse(ParseDA1Response(''));
end;

// OSC 11 response: ESC]11;rgb:HHHH/HHHH/HHHH BEL  (4-digit hex components)
// or             : ESC]11;rgb:HH/HH/HH BEL         (2-digit hex components)

procedure TTestTermDetect.ParseOSC11ParsesFourDigitHex;
var
  LColor: TTerminalRGB;
begin
  // 4-digit hex — divide each component by 256 to get 0-255
  // 2020 hex = 8224 dec; 8224 div 256 = 32
  LColor := ParseOSC11Response(#$1B + ']11;rgb:2020/2020/2020' + #7);
  Assert.AreEqual(32, Integer(LColor.R));
  Assert.AreEqual(32, Integer(LColor.G));
  Assert.AreEqual(32, Integer(LColor.B));
end;

procedure TTestTermDetect.ParseOSC11ParsesTwoDigitHex;
var
  LColor: TTerminalRGB;
begin
  // 2-digit hex: 1a hex = 26 dec
  LColor := ParseOSC11Response(#$1B + ']11;rgb:1a/1a/ff' + #7);
  Assert.AreEqual(26, Integer(LColor.R));
  Assert.AreEqual(26, Integer(LColor.G));
  Assert.AreEqual(255, Integer(LColor.B));
end;

procedure TTestTermDetect.ParseOSC11DarkBackground;
var
  LColor: TTerminalRGB;
begin
  // Dark gray — luminance should be < 128
  // rgb:2020/2020/2020 → R=G=B=32  → L = 0.299*32+0.587*32+0.114*32 ≈ 32
  LColor := ParseOSC11Response(#$1B + ']11;rgb:2020/2020/2020' + #7);
  Assert.IsTrue(IsDarkColor(LColor));
end;

procedure TTestTermDetect.ParseTermSizeExtractsWidthAndHeight;
var
  LSize: TTerminalSize;
begin
  // ESC[4;768;1024t → height=768, width=1024
  LSize := ParseTermSizeResponse(#$1B + '[4;768;1024t');
  Assert.AreEqual(1024, LSize.WidthPx);
  Assert.AreEqual(768,  LSize.HeightPx);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestTermDetect);

end.
```

- [ ] **Step 2: Add to XkcdTests.dpr and XkcdTests.dproj**

Add `testTermDetect in 'testTermDetect.pas'` to `tests/XkcdTests.dpr` uses.

Add to `tests/XkcdTests.dproj` ItemGroup:
```xml
<DCCReference Include="testTermDetect.pas"/>
```

- [ ] **Step 3: Create `src/termdetectapi.pas`** (types + parsers; I/O deferred to Task 8)

```pascal
unit termdetectapi;

interface

type
  TTerminalProtocol = (tpNone, tpSixel, tpKitty, tpKittyPlus, tpITerm);

  TTerminalSize = record
    WidthPx, HeightPx: Integer;
  end;

  TTerminalRGB = record
    R, G, B: Byte;
  end;

// Response-string parsers — no terminal I/O, fully unit-testable
function ParseDA1Response(const AResponse: string): Boolean;
function ParseOSC11Response(const AResponse: string): TTerminalRGB;
function ParseTermSizeResponse(const AResponse: string): TTerminalSize;
function IsDarkColor(const AColor: TTerminalRGB): Boolean;

// Terminal I/O (implemented in Task 8 — stubs compile here)
function TerminalRequest(const ACmd: string; ATimeoutMs: Integer;
  const AEndChars: string): string;
function DetectProtocol: TTerminalProtocol;
function QueryTerminalSize: TTerminalSize;
function QueryBackgroundColor: TTerminalRGB;
function IsDarkBackground: Boolean;

implementation

uses System.SysUtils, System.RegularExpressions;

function ParseDA1Response(const AResponse: string): Boolean;
var
  LParts: TArray<string>;
  LClean: string;
  LPart: string;
begin
  Result := False;
  if AResponse = '' then Exit;
  // Strip ESC[? prefix and trailing 'c'
  LClean := AResponse;
  var LStart := LClean.IndexOf('?');
  if LStart >= 0 then
    LClean := LClean.Substring(LStart + 1);
  if LClean.EndsWith('c') then
    LClean := LClean.Substring(0, LClean.Length - 1);
  LParts := LClean.Split([';']);
  for LPart in LParts do
    if Trim(LPart) = '4' then
      Exit(True);
end;

function ParseOSC11Response(const AResponse: string): TTerminalRGB;
var
  LMatch: TMatch;
  LHex: string;
  LVal: Integer;

  function HexToByteNorm(const AHex: string): Byte;
  begin
    LVal := StrToIntDef('$' + AHex, 0);
    if Length(AHex) > 2 then
      LVal := LVal shr 8;  // 4-digit hex: normalise to 0-255
    Result := Byte(LVal);
  end;

begin
  Result.R := 0; Result.G := 0; Result.B := 0;
  LMatch := TRegEx.Match(AResponse,
    'rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+)');
  if not LMatch.Success then Exit;
  Result.R := HexToByteNorm(LMatch.Groups[1].Value);
  Result.G := HexToByteNorm(LMatch.Groups[2].Value);
  Result.B := HexToByteNorm(LMatch.Groups[3].Value);
end;

function ParseTermSizeResponse(const AResponse: string): TTerminalSize;
var
  LParts: TArray<string>;
  LClean: string;
begin
  Result.WidthPx := 0; Result.HeightPx := 0;
  // Response: ESC[4;<height>;<width>t
  LClean := AResponse;
  var LStart := LClean.IndexOf('[');
  if LStart >= 0 then
    LClean := LClean.Substring(LStart + 1);
  if LClean.EndsWith('t') then
    LClean := LClean.Substring(0, LClean.Length - 1);
  LParts := LClean.Split([';']);
  if Length(LParts) >= 3 then
  begin
    Result.HeightPx := StrToIntDef(LParts[1], 0);
    Result.WidthPx  := StrToIntDef(LParts[2], 0);
  end;
end;

function IsDarkColor(const AColor: TTerminalRGB): Boolean;
var
  LLum: Double;
begin
  LLum := 0.299 * AColor.R + 0.587 * AColor.G + 0.114 * AColor.B;
  Result := LLum < 128;
end;

// Stub implementations for I/O functions — replaced in Task 8

function TerminalRequest(const ACmd: string; ATimeoutMs: Integer;
  const AEndChars: string): string;
begin
  Result := '';
end;

function DetectProtocol: TTerminalProtocol;
begin
  Result := tpNone;
end;

function QueryTerminalSize: TTerminalSize;
begin
  Result.WidthPx := 0; Result.HeightPx := 0;
end;

function QueryBackgroundColor: TTerminalRGB;
begin
  Result.R := 0; Result.G := 0; Result.B := 0;
end;

function IsDarkBackground: Boolean;
begin
  Result := False;
end;

end.
```

- [ ] **Step 4: Build and run — expect all pass**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
.\bin\Win64\Debug\XkcdTests.exe
```

Expected: `TTestTermDetect` — 8 tests passed.

- [ ] **Step 5: Commit**

```
git add src/termdetectapi.pas tests/testTermDetect.pas tests/XkcdTests.dpr tests/XkcdTests.dproj
git commit -m "feat: add termdetectapi parser functions with tests"
```

---

## Task 8: termdetectapi.pas — full raw-mode I/O + termdetectdemo

Replace the stub I/O functions with real platform implementations. No unit tests for the I/O layer — the `termdetectdemo` serves as the proof-of-concept.

**Files:**
- Modify: `src/termdetectapi.pas` — replace stubs with real implementations
- Create: `src/termdetectdemo.dpr`
- Create: `src/termdetectdemo.dproj`

- [ ] **Step 1: Replace stubs in `src/termdetectapi.pas`**

Replace the stub implementation section with the full platform implementation below. Keep all the parser functions and type declarations unchanged.

```pascal
// Replace the stub I/O implementations with these full ones.
// Replace the implementation uses clause with:

uses
  System.SysUtils,
  System.RegularExpressions,
  System.DateUtils
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ELSE}
  , Posix.Termios
  , Posix.Unistd
  , BaseUnix
  {$ENDIF}
  ;

// ── Raw mode helpers ─────────────────────────────────────────────────────────

{$IFDEF MSWINDOWS}

var
  GhStdIn:  THandle;
  GhStdOut: THandle;
  GSavedIn, GSavedOut: DWORD;

procedure SetRawMode;
const
  ENABLE_VIRTUAL_TERMINAL_INPUT = $0200;
begin
  GhStdIn  := GetStdHandle(STD_INPUT_HANDLE);
  GhStdOut := GetStdHandle(STD_OUTPUT_HANDLE);
  GetConsoleMode(GhStdIn,  GSavedIn);
  GetConsoleMode(GhStdOut, GSavedOut);
  SetConsoleMode(GhStdIn,
    (GSavedIn and not ENABLE_LINE_INPUT and not ENABLE_ECHO_INPUT)
    or ENABLE_VIRTUAL_TERMINAL_INPUT);
  SetConsoleMode(GhStdOut,
    GSavedOut or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
end;

procedure RestoreMode;
begin
  SetConsoleMode(GhStdIn,  GSavedIn);
  SetConsoleMode(GhStdOut, GSavedOut);
end;

function ReadChar(ADeadline: Int64): Char;
var
  LRec: TInputRecord;
  LCount: DWORD;
begin
  Result := #0;
  while GetTickCount64 < UInt64(ADeadline) do
  begin
    if WaitForSingleObject(GhStdIn, 10) = WAIT_OBJECT_0 then
    begin
      if ReadConsoleInput(GhStdIn, LRec, 1, LCount) and (LCount > 0) then
      begin
        if (LRec.EventType = KEY_EVENT) and LRec.Event.KeyEvent.bKeyDown then
        begin
          Result := LRec.Event.KeyEvent.UnicodeChar;
          if Result <> #0 then Exit;
        end;
      end;
    end;
  end;
end;

{$ELSE}

var
  GSavedTermios: termios;

procedure SetRawMode;
var
  LNew: termios;
begin
  tcgetattr(STDIN_FILENO, GSavedTermios);
  LNew := GSavedTermios;
  LNew.c_lflag := LNew.c_lflag and not (ICANON or ECHO);
  LNew.c_cc[VMIN]  := 0;
  LNew.c_cc[VTIME] := 0;
  tcsetattr(STDIN_FILENO, TCSAFLUSH, LNew);
end;

procedure RestoreMode;
begin
  tcsetattr(STDIN_FILENO, TCSAFLUSH, GSavedTermios);
end;

function ReadChar(ADeadline: Int64): Char;
var
  LFds: TFDSet;
  LTV:  TimeVal;
  LC:   Byte;
  LNow: Int64;
begin
  Result := #0;
  LNow := DateTimeToUnix(Now) * 1000;
  while LNow < ADeadline do
  begin
    fpFD_ZERO(LFds);
    fpFD_SET(STDIN_FILENO, LFds);
    LTV.tv_sec  := 0;
    LTV.tv_usec := 10000; // 10 ms poll
    if fpSelect(STDIN_FILENO + 1, @LFds, nil, nil, @LTV) > 0 then
    begin
      if fpRead(STDIN_FILENO, LC, 1) = 1 then
      begin
        Result := Char(LC);
        Exit;
      end;
    end;
    LNow := DateTimeToUnix(Now) * 1000;
  end;
end;

{$ENDIF}

// ── TerminalRequest ───────────────────────────────────────────────────────────

function TerminalRequest(const ACmd: string; ATimeoutMs: Integer;
  const AEndChars: string): string;
var
  LDeadline: Int64;
  LC: Char;
begin
  Result := '';
  SetRawMode;
  try
    Write(ACmd);
    Flush(Output);
    LDeadline := {$IFDEF MSWINDOWS}GetTickCount64{$ELSE}DateTimeToUnix(Now) * 1000{$ENDIF} + ATimeoutMs;
    repeat
      LC := ReadChar(LDeadline);
      if LC <> #0 then
      begin
        Result := Result + LC;
        if (AEndChars <> '') and (Pos(LC, AEndChars) > 0) then Break;
      end;
    until {$IFDEF MSWINDOWS}GetTickCount64{$ELSE}DateTimeToUnix(Now) * 1000{$ENDIF} >= LDeadline;
  finally
    RestoreMode;
  end;
end;

// ── Protocol detection ────────────────────────────────────────────────────────

// Minimal 1x1 transparent PNG for kitty probe (67 bytes, base64-encoded)
const
  CKittyProbePNG =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJggg==';

function DetectProtocol: TTerminalProtocol;
var
  LResp: string;
begin
  Result := tpNone;

  // 1. Kitty+ probe (PNG format f=100)
  LResp := TerminalRequest(
    #$1B + '_G i=31,s=1,v=1,a=q,t=d,f=100;' + CKittyProbePNG + #$1B + '\',
    300, #$1B);
  if LResp.Contains('OK') then Exit(tpKittyPlus);

  // 2. iTerm probe
  LResp := TerminalRequest(#$1B + ']1337;ReportCellSize' + #7, 300, #7);
  if LResp.Contains('ReportCellSize=') then Exit(tpITerm);

  // 3. Kitty probe (raw RGB format f=24)
  LResp := TerminalRequest(
    #$1B + '_G i=31,s=1,v=1,a=q,t=d,f=24;AAAA' + #$1B + '\',
    300, #$1B);
  if LResp.Contains('OK') then Exit(tpKitty);

  // 4. Sixel via DA1
  LResp := TerminalRequest(#$1B + '[c', 300, 'c');
  if ParseDA1Response(LResp) then Exit(tpSixel);
end;

function QueryTerminalSize: TTerminalSize;
var
  LResp: string;
begin
  LResp  := TerminalRequest(#$1B + '[14t', 300, 't');
  Result := ParseTermSizeResponse(LResp);
end;

function QueryBackgroundColor: TTerminalRGB;
var
  LResp: string;
begin
  LResp  := TerminalRequest(#$1B + ']11;?' + #7, 300, #7);
  Result := ParseOSC11Response(LResp);
end;

function IsDarkBackground: Boolean;
begin
  Result := IsDarkColor(QueryBackgroundColor);
end;
```

> **Note on Linux timing:** `DateTimeToUnix(Now) * 1000` gives milliseconds from Unix epoch. The deadline math is correct but may drift slightly; 300 ms is more than enough tolerance.

- [ ] **Step 2: Create `src/termdetectdemo.dpr`**

```pascal
program termdetectdemo;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IFDEF LINUX}
  LinuxLibStdCxx in 'LinuxLibStdCxx.pas',
  {$ENDIF}
  System.SysUtils,
  termdetectapi in 'termdetectapi.pas';

{$IFDEF MSWINDOWS}
procedure EnableVTProcessing;
var
  LHandle: THandle;
  LMode: DWORD;
begin
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if GetConsoleMode(LHandle, LMode) then
    SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
end;
{$ENDIF}

const
  CProtocolName: array[TTerminalProtocol] of string = (
    'None', 'Sixel', 'Kitty', 'Kitty+', 'iTerm');

begin
  try
    {$IFDEF MSWINDOWS}
    EnableVTProcessing;
    {$ENDIF}

    Writeln('Detecting terminal capabilities...');
    Writeln('Protocol : ', CProtocolName[DetectProtocol]);

    var LSize := QueryTerminalSize;
    Writeln('Term size: ', LSize.WidthPx, ' x ', LSize.HeightPx, ' px');

    var LColor := QueryBackgroundColor;
    Writeln(Format('Bg color : rgb(%d, %d, %d)', [LColor.R, LColor.G, LColor.B]));
    Writeln('Dark bg  : ', BoolToStr(IsDarkBackground, True));
  except
    on E: Exception do
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
  end;
end.
```

- [ ] **Step 3: Create `src/termdetectdemo.dproj`**

Copy `src/sixeldemo.dproj` to `src/termdetectdemo.dproj`, then make these changes:
- Change `<MainSource>sixeldemo.dpr</MainSource>` → `<MainSource>termdetectdemo.dpr</MainSource>`
- Change `<ProjectGuid>{8BFE4B00-...}</ProjectGuid>` → `<ProjectGuid>{C7D3A1B2-F4E5-6789-0ABC-DEF123456780}</ProjectGuid>`
- Change `<ProjectName ...>sixeldemo</ProjectName>` → `<ProjectName ...>termdetectdemo</ProjectName>`
- Change `<SanitizedProjectName>sixeldemo</SanitizedProjectName>` → `<SanitizedProjectName>termdetectdemo</SanitizedProjectName>`
- In `<ItemGroup>`, replace the `<DCCReference Include="sixelapi.pas"/>` line with `<DCCReference Include="termdetectapi.pas"/>`
- In `<Source Name="MainSource">sixeldemo.dpr</Source>` → `termdetectdemo.dpr`

- [ ] **Step 4: Build the demo (Win64)**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "src\termdetectdemo.dproj" -Platform Win64
```

Expected: build succeeds.

- [ ] **Step 5: Run the demo in Windows Terminal**

```powershell
.\bin\Win64\Debug\termdetectdemo.exe
```

Expected output (example):
```
Detecting terminal capabilities...
Protocol : Sixel
Term size: 1920 x 1080 px
Bg color : rgb(12, 12, 12)
Dark bg  : True
```

If protocol shows `None`, the terminal doesn't support any graphics protocol — that's fine for testing, it just means the timeout path works correctly.

- [ ] **Step 6: Run the existing test suite to confirm parsers still pass**

```powershell
.\bin\Win64\Debug\XkcdTests.exe
```

Expected: all previous tests still pass.

- [ ] **Step 7: Commit**

```
git add src/termdetectapi.pas src/termdetectdemo.dpr src/termdetectdemo.dproj
git commit -m "feat: add full termdetectapi raw-mode I/O and termdetectdemo"
```

---

## Task 9: kittieapi.pas (TDD)

Kitty APC chunked base64 encoding. The testable function `EncodeImageAsKitty` works purely on bytes — no Skia, no terminal I/O.

**Files:**
- Create: `src/kittieapi.pas`
- Create: `tests/testKittieApi.pas`
- Modify: `tests/XkcdTests.dpr`, `tests/XkcdTests.dproj`

- [ ] **Step 1: Create `tests/testKittieApi.pas`**

```pascal
unit testKittieApi;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestKittieApi = class
  public
    [Test]
    procedure EncodeSmallImageSingleChunk;
    [Test]
    procedure EncodeSmallImageHasCorrectDelimiters;
    [Test]
    procedure EncodeSmallImageHasTransmitAction;
    [Test]
    procedure EncodeLargeImageProducesMultipleChunks;
    [Test]
    procedure EncodeLargeImageLastChunkHasM0;
    [Test]
    procedure EncodeRoundtripVerifiesBase64Content;
  end;

implementation

uses kittieapi, System.NetEncoding, System.SysUtils, System.Math;

// Minimal 1×1 white PNG (67 bytes)
const
  CSamplePngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJggg==';

function MakeSamplePng: TBytes;
begin
  Result := TNetEncoding.Base64.DecodeStringToBytes(CSamplePngB64);
end;

function CountOccurrences(const AStr, ASub: string): Integer;
var
  LPos: Integer;
begin
  Result := 0;
  LPos := 1;
  while True do
  begin
    LPos := PosEx(ASub, AStr, LPos);
    if LPos = 0 then Break;
    Inc(Result);
    Inc(LPos, Length(ASub));
  end;
end;

procedure TTestKittieApi.EncodeSmallImageSingleChunk;
var
  LResult: string;
begin
  LResult := EncodeImageAsKitty(MakeSamplePng);
  // Small image fits in one chunk: exactly one APC frame
  Assert.AreEqual(1, CountOccurrences(LResult, #$1B + '_G'));
end;

procedure TTestKittieApi.EncodeSmallImageHasCorrectDelimiters;
var
  LResult: string;
begin
  LResult := EncodeImageAsKitty(MakeSamplePng);
  Assert.IsTrue(LResult.StartsWith(#$1B + '_G'), 'Must start with APC');
  Assert.IsTrue(LResult.EndsWith(#$1B + '\'), 'Must end with ST');
end;

procedure TTestKittieApi.EncodeSmallImageHasTransmitAction;
var
  LResult: string;
begin
  LResult := EncodeImageAsKitty(MakeSamplePng);
  Assert.IsTrue(LResult.Contains('a=T'), 'Must have transmit action');
  Assert.IsTrue(LResult.Contains('f=100'), 'Must specify PNG format (100)');
  Assert.IsTrue(LResult.Contains('m=0'), 'Single chunk must have m=0');
end;

procedure TTestKittieApi.EncodeLargeImageProducesMultipleChunks;
var
  LData: TBytes;
  LResult: string;
begin
  // 3500 bytes → ~4668 base64 chars → 2 chunks (4096 + 572)
  SetLength(LData, 3500);
  FillChar(LData[0], 3500, $AA);
  LResult := EncodeImageAsKitty(LData);
  Assert.IsTrue(CountOccurrences(LResult, #$1B + '_G') >= 2,
    'Large image should produce multiple APC frames');
end;

procedure TTestKittieApi.EncodeLargeImageLastChunkHasM0;
var
  LData: TBytes;
  LResult: string;
  LLastFrame: string;
begin
  SetLength(LData, 3500);
  FillChar(LData[0], 3500, $AA);
  LResult := EncodeImageAsKitty(LData);
  var LLastPos := LastDelimiter(#$1B, LResult);
  // Find the last ESC_G
  LLastPos := LResult.LastIndexOf(#$1B + '_G');
  Assert.IsTrue(LLastPos >= 0, 'Should have at least one APC frame');
  LLastFrame := LResult.Substring(LLastPos);
  Assert.IsTrue(LLastFrame.Contains('m=0'), 'Last frame must have m=0');
  // Non-last frames have m=1
  Assert.IsTrue(LResult.Contains('m=1'), 'Multi-chunk should have m=1 frames');
end;

procedure TTestKittieApi.EncodeRoundtripVerifiesBase64Content;
var
  LData: TBytes;
  LResult, LBase64Part: string;
  LDecoded: TBytes;
  LFrameContent: string;
begin
  LData := MakeSamplePng;
  LResult := EncodeImageAsKitty(LData);
  // Extract base64 between first ';' and ESC\
  var LSemiPos := Pos(';', LResult);
  var LEndPos  := Pos(#$1B + '\', LResult);
  Assert.IsTrue((LSemiPos > 0) and (LEndPos > LSemiPos), 'Frame structure invalid');
  LBase64Part := LResult.Substring(LSemiPos, LEndPos - LSemiPos - 1);
  LDecoded := TNetEncoding.Base64.DecodeStringToBytes(LBase64Part);
  Assert.AreEqual(Length(LData), Length(LDecoded), 'Decoded byte count must match');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestKittieApi);

end.
```

- [ ] **Step 2: Add to XkcdTests.dpr and XkcdTests.dproj**

Add `testKittieApi in 'testKittieApi.pas'` to uses in `tests/XkcdTests.dpr`.

Add to `tests/XkcdTests.dproj` ItemGroup:
```xml
<DCCReference Include="testKittieApi.pas"/>
```

- [ ] **Step 3: Create `src/kittieapi.pas`**

```pascal
unit kittieapi;

interface

// Encoding only — takes raw PNG bytes, returns the full APC escape string.
// Unit-testable without Skia or a real terminal.
function EncodeImageAsKitty(const APngBytes: TBytes): string;

// Display — loads and resizes the file via Skia, then calls EncodeImageAsKitty.
procedure DisplayImageAsKitty(const AFileName: string; AMaxWidth: Integer = 800);

implementation

uses
  System.SysUtils,
  System.NetEncoding,
  System.Math,
  System.UITypes,
  System.Skia,
  System.Types;

function Base64NoBr(const AData: TBytes): string;
var
  LEnc: TBase64Encoding;
begin
  LEnc := TBase64Encoding.Create(0);  // 0 = no line breaks
  try
    Result := LEnc.EncodeBytesToString(AData);
  finally
    LEnc.Free;
  end;
end;

function EncodeImageAsKitty(const APngBytes: TBytes): string;
const
  CChunkSize = 4096;
var
  LBase64: string;
  LPos, LLen: Integer;
  LSb: TStringBuilder;
  LIsFirst, LIsLast: Boolean;
begin
  if Length(APngBytes) = 0 then
    Exit('');

  LBase64 := Base64NoBr(APngBytes);
  LSb     := TStringBuilder.Create;
  try
    LPos    := 1;
    LIsFirst := True;
    while LPos <= Length(LBase64) do
    begin
      LLen    := Min(CChunkSize, Length(LBase64) - LPos + 1);
      LIsLast := (LPos + LLen - 1) >= Length(LBase64);

      if LIsFirst then
        LSb.Append(#$1B + '_G a=T,f=100,q=2,m=' + IntToStr(Ord(not LIsLast)) + ';')
      else
        LSb.Append(#$1B + '_G m=' + IntToStr(Ord(not LIsLast)) + ';');

      LSb.Append(LBase64.Substring(LPos - 1, LLen));
      LSb.Append(#$1B + '\');

      Inc(LPos, LLen);
      LIsFirst := False;
    end;
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

procedure DisplayImageAsKitty(const AFileName: string; AMaxWidth: Integer = 800);
var
  LSrc: ISkImage;
  LSurface: ISkSurface;
  LCanvas: ISkCanvas;
  LSrcW, LSrcH, LW, LH: Integer;
  LStream: TBytesStream;
  LPngBytes: TBytes;
  LSnapshot: ISkImage;
begin
  LSrc := TSkImage.MakeFromEncodedFile(AFileName);
  if not Assigned(LSrc) then
    raise Exception.CreateFmt('Cannot load image: %s', [AFileName]);

  LSrcW := LSrc.Width;
  LSrcH := LSrc.Height;
  if LSrcW > AMaxWidth then
  begin
    LW := AMaxWidth;
    LH := Round(LSrcH * AMaxWidth / LSrcW);
  end
  else
  begin
    LW := LSrcW;
    LH := LSrcH;
  end;

  LSurface := TSkSurface.MakeRaster(TSkImageInfo.Create(LW, LH,
    TSkColorType.BGRA8888, TSkAlphaType.Premul));
  LCanvas := LSurface.Canvas;
  LCanvas.Clear(TAlphaColors.White);
  LCanvas.DrawImageRect(LSrc, TRectF.Create(0, 0, LW, LH),
    TSkSamplingOptions.Create(TSkCubicResampler.Mitchell));

  LSnapshot := LSurface.MakeImageSnapshot;
  LStream   := TBytesStream.Create;
  try
    LSnapshot.EncodeToStream(LStream, TSkEncodedImageFormat.PNG, 100);
    LPngBytes := Copy(LStream.Bytes, 0, LStream.Size);
  finally
    LStream.Free;
  end;

  Write(EncodeImageAsKitty(LPngBytes));
  Flush(Output);
  Writeln;
end;

end.
```

- [ ] **Step 4: Build and run — expect all pass**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
.\bin\Win64\Debug\XkcdTests.exe
```

Expected: `TTestKittieApi` — 6 tests passed.

- [ ] **Step 5: Commit**

```
git add src/kittieapi.pas tests/testKittieApi.pas tests/XkcdTests.dpr tests/XkcdTests.dproj
git commit -m "feat: add kittieapi APC encoding with tests"
```

---

## Task 10: itermapi.pas (TDD)

iTerm OSC 1337 single-frame base64 encoding.

**Files:**
- Create: `src/itermapi.pas`
- Create: `tests/testItermApi.pas`
- Modify: `tests/XkcdTests.dpr`, `tests/XkcdTests.dproj`

- [ ] **Step 1: Create `tests/testItermApi.pas`**

```pascal
unit testItermApi;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestItermApi = class
  public
    [Test]
    procedure EncodeHasCorrectOSCPrefix;
    [Test]
    procedure EncodeEndsWithBEL;
    [Test]
    procedure EncodeBase64RoundTrip;
    [Test]
    procedure EncodeContainsInlineFlag;
  end;

implementation

uses itermapi, System.NetEncoding, System.SysUtils;

const
  CSamplePngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJggg==';

function MakeSamplePng: TBytes;
begin
  Result := TNetEncoding.Base64.DecodeStringToBytes(CSamplePngB64);
end;

const
  CExpectedPrefix = #$1B + ']1337;File=inline=1;width=auto:';

procedure TTestItermApi.EncodeHasCorrectOSCPrefix;
var
  LResult: string;
begin
  LResult := EncodeImageAsITerm(MakeSamplePng);
  Assert.IsTrue(LResult.StartsWith(CExpectedPrefix),
    'Must start with OSC 1337 File prefix');
end;

procedure TTestItermApi.EncodeEndsWithBEL;
var
  LResult: string;
begin
  LResult := EncodeImageAsITerm(MakeSamplePng);
  Assert.IsTrue(LResult.EndsWith(#7), 'Must end with BEL (#7)');
end;

procedure TTestItermApi.EncodeBase64RoundTrip;
var
  LData, LDecoded: TBytes;
  LResult, LB64: string;
begin
  LData   := MakeSamplePng;
  LResult := EncodeImageAsITerm(LData);
  // Extract base64 between prefix and BEL
  LB64     := LResult.Substring(Length(CExpectedPrefix),
                LResult.Length - Length(CExpectedPrefix) - 1);
  LDecoded := TNetEncoding.Base64.DecodeStringToBytes(LB64);
  Assert.AreEqual(Length(LData), Length(LDecoded), 'Decoded length must match');
  for var I := 0 to High(LData) do
    Assert.AreEqual(LData[I], LDecoded[I], Format('Byte %d must match', [I]));
end;

procedure TTestItermApi.EncodeContainsInlineFlag;
var
  LResult: string;
begin
  LResult := EncodeImageAsITerm(MakeSamplePng);
  Assert.IsTrue(LResult.Contains('inline=1'), 'Must specify inline=1');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestItermApi);

end.
```

- [ ] **Step 2: Add to XkcdTests.dpr and XkcdTests.dproj**

Add `testItermApi in 'testItermApi.pas'` to uses in `tests/XkcdTests.dpr`.

Add to `tests/XkcdTests.dproj` ItemGroup:
```xml
<DCCReference Include="testItermApi.pas"/>
```

- [ ] **Step 3: Create `src/itermapi.pas`**

```pascal
unit itermapi;

interface

function EncodeImageAsITerm(const APngBytes: TBytes): string;
procedure DisplayImageAsITerm(const AFileName: string; AMaxWidth: Integer = 800);

implementation

uses
  System.SysUtils,
  System.NetEncoding,
  System.UITypes,
  System.Skia,
  System.Types;

function Base64NoBr(const AData: TBytes): string;
var
  LEnc: TBase64Encoding;
begin
  LEnc := TBase64Encoding.Create(0);
  try
    Result := LEnc.EncodeBytesToString(AData);
  finally
    LEnc.Free;
  end;
end;

function EncodeImageAsITerm(const APngBytes: TBytes): string;
begin
  if Length(APngBytes) = 0 then
    Exit('');
  Result := #$1B + ']1337;File=inline=1;width=auto:' +
            Base64NoBr(APngBytes) + #7;
end;

procedure DisplayImageAsITerm(const AFileName: string; AMaxWidth: Integer = 800);
var
  LSrc: ISkImage;
  LSurface: ISkSurface;
  LCanvas: ISkCanvas;
  LSrcW, LSrcH, LW, LH: Integer;
  LStream: TBytesStream;
  LPngBytes: TBytes;
  LSnapshot: ISkImage;
begin
  LSrc := TSkImage.MakeFromEncodedFile(AFileName);
  if not Assigned(LSrc) then
    raise Exception.CreateFmt('Cannot load image: %s', [AFileName]);

  LSrcW := LSrc.Width;
  LSrcH := LSrc.Height;
  if LSrcW > AMaxWidth then
  begin
    LW := AMaxWidth;
    LH := Round(LSrcH * AMaxWidth / LSrcW);
  end
  else
  begin
    LW := LSrcW;
    LH := LSrcH;
  end;

  LSurface := TSkSurface.MakeRaster(TSkImageInfo.Create(LW, LH,
    TSkColorType.BGRA8888, TSkAlphaType.Premul));
  LCanvas := LSurface.Canvas;
  LCanvas.Clear(TAlphaColors.White);
  LCanvas.DrawImageRect(LSrc, TRectF.Create(0, 0, LW, LH),
    TSkSamplingOptions.Create(TSkCubicResampler.Mitchell));

  LSnapshot := LSurface.MakeImageSnapshot;
  LStream   := TBytesStream.Create;
  try
    LSnapshot.EncodeToStream(LStream, TSkEncodedImageFormat.PNG, 100);
    LPngBytes := Copy(LStream.Bytes, 0, LStream.Size);
  finally
    LStream.Free;
  end;

  Write(EncodeImageAsITerm(LPngBytes));
  Flush(Output);
  Writeln;
end;

end.
```

- [ ] **Step 4: Build and run — expect all pass**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
.\bin\Win64\Debug\XkcdTests.exe
```

Expected: `TTestItermApi` — 4 tests passed.

- [ ] **Step 5: Commit**

```
git add src/itermapi.pas tests/testItermApi.pas tests/XkcdTests.dpr tests/XkcdTests.dproj
git commit -m "feat: add itermapi OSC 1337 encoding with tests"
```

---

## Task 11: termimageapi.pas — display router

Thin wrapper that routes to the right protocol. No separate test needed — the individual encoders are already tested.

**Files:**
- Create: `src/termimageapi.pas`

- [ ] **Step 1: Create `src/termimageapi.pas`**

```pascal
unit termimageapi;

interface

uses termdetectapi;

procedure DisplayImage(const AFileName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer = 800);

procedure AutoDisplayImage(const AFileName: string; AMaxWidth: Integer = 800);

implementation

uses
  System.SysUtils,
  sixelapi,
  kittieapi,
  itermapi
  {$IFDEF MSWINDOWS}
  , Winapi.ShellAPI, Winapi.Windows
  {$ELSE}
  , Posix.Stdlib
  {$ENDIF}
  ;

procedure OpenWithOsViewer(const AFileName: string);
begin
  {$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(AFileName), nil, nil, SW_SHOWNORMAL);
  {$ELSE}
  Posix.Stdlib.system(PAnsiChar(AnsiString('xdg-open "' + AFileName + '"')));
  {$ENDIF}
end;

procedure DisplayImage(const AFileName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer = 800);
begin
  case AProtocol of
    tpKittyPlus, tpKitty: DisplayImageAsKitty(AFileName, AMaxWidth);
    tpITerm:              DisplayImageAsITerm(AFileName, AMaxWidth);
    tpSixel:              DisplayImageAsSixel(AFileName, AMaxWidth);
    tpNone:               OpenWithOsViewer(AFileName);
  end;
end;

procedure AutoDisplayImage(const AFileName: string; AMaxWidth: Integer = 800);
begin
  DisplayImage(AFileName, DetectProtocol, AMaxWidth);
end;

end.
```

> **Linux note:** `TProcess` is in `System.Classes` (not `System.Diagnostics`). The `xdg-open` call is fire-and-forget — the process continues running after the call returns, which is correct for async viewer opening.

- [ ] **Step 2: Commit**

```
git add src/termimageapi.pas
git commit -m "feat: add termimageapi display router"
```

---

## Task 12: Wire up kittydemo and itermdemo

Update the existing demo shells to call their respective protocol APIs.

**Files:**
- Modify: `src/kittydemo.dpr`
- Modify: `src/kittydemo.dproj`
- Modify: `src/itermdemo.dpr`
- Modify: `src/itermdemo.dproj`

- [ ] **Step 1: Rewrite `src/kittydemo.dpr`**

```pascal
program kittydemo;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IFDEF LINUX}
  LinuxLibStdCxx in 'LinuxLibStdCxx.pas',
  {$ENDIF}
  System.SysUtils,
  kittieapi in 'kittieapi.pas';

{$IFDEF MSWINDOWS}
procedure EnableVTProcessing;
var
  LHandle: THandle;
  LMode: DWORD;
begin
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if GetConsoleMode(LHandle, LMode) then
    SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
end;
{$ENDIF}

var
  LImagePath: string;

begin
  try
    {$IFDEF MSWINDOWS}
    EnableVTProcessing;
    {$ENDIF}

    if ParamCount > 0 then
      LImagePath := ParamStr(1)
    else
      LImagePath := ExtractFilePath(ParamStr(0)) + 'bottle_2x.png';

    if not FileExists(LImagePath) then
      raise Exception.CreateFmt('Image not found: %s', [LImagePath]);

    DisplayImageAsKitty(LImagePath);
  except
    on E: Exception do
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
  end;
end.
```

- [ ] **Step 2: Update `src/kittydemo.dproj` DCCReference list**

In the `<ItemGroup>` block, ensure the DCCReference list is:
```xml
<DelphiCompile Include="$(MainSource)">
    <MainSource>MainSource</MainSource>
</DelphiCompile>
<DCCReference Include="LinuxLibStdCxx.pas"/>
<DCCReference Include="kittieapi.pas"/>
```

- [ ] **Step 3: Rewrite `src/itermdemo.dpr`**

```pascal
program itermdemo;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IFDEF LINUX}
  LinuxLibStdCxx in 'LinuxLibStdCxx.pas',
  {$ENDIF}
  System.SysUtils,
  itermapi in 'itermapi.pas';

{$IFDEF MSWINDOWS}
procedure EnableVTProcessing;
var
  LHandle: THandle;
  LMode: DWORD;
begin
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if GetConsoleMode(LHandle, LMode) then
    SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
end;
{$ENDIF}

var
  LImagePath: string;

begin
  try
    {$IFDEF MSWINDOWS}
    EnableVTProcessing;
    {$ENDIF}

    if ParamCount > 0 then
      LImagePath := ParamStr(1)
    else
      LImagePath := ExtractFilePath(ParamStr(0)) + 'bottle_2x.png';

    if not FileExists(LImagePath) then
      raise Exception.CreateFmt('Image not found: %s', [LImagePath]);

    DisplayImageAsITerm(LImagePath);
  except
    on E: Exception do
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
  end;
end.
```

- [ ] **Step 4: Update `src/itermdemo.dproj` DCCReference list**

```xml
<DCCReference Include="LinuxLibStdCxx.pas"/>
<DCCReference Include="itermapi.pas"/>
```

- [ ] **Step 5: Build both demos (Win64)**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "src\kittydemo.dproj" -Platform Win64

pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "src\itermdemo.dproj" -Platform Win64
```

Expected: both build successfully.

- [ ] **Step 6: Run the demos in a kitty/iTerm-capable terminal**

```powershell
.\bin\Win64\Debug\kittydemo.exe src\bottle_2x.png
.\bin\Win64\Debug\itermdemo.exe src\bottle_2x.png
```

Expected: image renders inline in the terminal (if the terminal supports the protocol).

- [ ] **Step 7: Commit**

```
git add src/kittydemo.dpr src/kittydemo.dproj src/itermdemo.dpr src/itermdemo.dproj
git commit -m "feat: wire up kittydemo and itermdemo to their API units"
```

---

## Task 13: Fill in testSixelApi.pas + expose sixelapi internals

`testSixelApi.pas` currently exists as an empty fixture. `MakeQuantKey` and `ColorDist` are private in `sixelapi.pas` — move them to the interface section so tests can call them directly.

**Files:**
- Modify: `src/sixelapi.pas` (expose two helper functions)
- Modify: `tests/testSixelApi.pas` (add real test methods)

- [ ] **Step 1: Expose helpers in `src/sixelapi.pas`**

Move the two helper function declarations from the `implementation` section to the `interface` section. Change the interface from:

```pascal
interface

procedure DisplayImageAsSixel(const AFileName: string; AMaxWidth: Integer = 800);
```

to:

```pascal
interface

procedure DisplayImageAsSixel(const AFileName: string; AMaxWidth: Integer = 800);

// Exposed for unit testing
function MakeQuantKey(const AR, AG, AB: Byte): Word;
function ColorDist(const AA, AB: TRGBColor): Int64;

type
  TRGBColor = record
    R, G, B: Byte;
  end;
```

> **Order matters in Delphi:** `TRGBColor` must be declared before `ColorDist` uses it in the interface section. Move the `TRGBColor` type declaration from the implementation to the interface, and keep the existing implementation bodies for `MakeQuantKey` and `ColorDist` unchanged.

- [ ] **Step 2: Rewrite `tests/testSixelApi.pas`**

```pascal
unit testSixelApi;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestSixelApi = class
  public
    [Test]
    procedure MakeQuantKeyBitLayout;
    [Test]
    procedure MakeQuantKeyBlackIsZero;
    [Test]
    procedure MakeQuantKeyWhiteIsMax;
    [Test]
    procedure ColorDistSameColorIsZero;
    [Test]
    procedure ColorDistBlackToWhiteIsMax;
    [Test]
    procedure ColorDistIsSymmetric;
  end;

implementation

uses sixelapi, System.SysUtils;

procedure TTestSixelApi.MakeQuantKeyBitLayout;
var
  LKey: Word;
begin
  // R=248 (11111000), G=0, B=0 → R shr 3 = 31 = %11111
  // Key = 31 shl 10 = %0111110000000000 = $7C00
  LKey := MakeQuantKey(248, 0, 0);
  Assert.AreEqual(Word($7C00), LKey, 'Full red should map to top 5 bits');
end;

procedure TTestSixelApi.MakeQuantKeyBlackIsZero;
begin
  Assert.AreEqual(Word(0), MakeQuantKey(0, 0, 0));
end;

procedure TTestSixelApi.MakeQuantKeyWhiteIsMax;
begin
  // 255 shr 3 = 31; key = 31<<10 | 31<<5 | 31 = $7FFF
  Assert.AreEqual(Word($7FFF), MakeQuantKey(255, 255, 255));
end;

procedure TTestSixelApi.ColorDistSameColorIsZero;
var
  LC: TRGBColor;
begin
  LC.R := 100; LC.G := 150; LC.B := 200;
  Assert.AreEqual(Int64(0), ColorDist(LC, LC));
end;

procedure TTestSixelApi.ColorDistBlackToWhiteIsMax;
var
  LBlack, LWhite: TRGBColor;
begin
  LBlack.R := 0;   LBlack.G := 0;   LBlack.B := 0;
  LWhite.R := 255; LWhite.G := 255; LWhite.B := 255;
  // dist = 255^2 + 255^2 + 255^2 = 195075
  Assert.AreEqual(Int64(195075), ColorDist(LBlack, LWhite));
end;

procedure TTestSixelApi.ColorDistIsSymmetric;
var
  LA, LB: TRGBColor;
begin
  LA.R := 10; LA.G := 20; LA.B := 30;
  LB.R := 50; LB.G := 60; LB.B := 70;
  Assert.AreEqual(ColorDist(LA, LB), ColorDist(LB, LA));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSixelApi);

end.
```

- [ ] **Step 3: Build and run — expect all pass**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
.\bin\Win64\Debug\XkcdTests.exe
```

Expected: `TTestSixelApi` — 6 tests passed.

- [ ] **Step 4: Confirm sixeldemo still builds**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "src\sixeldemo.dproj" -Platform Win64
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```
git add src/sixelapi.pas tests/testSixelApi.pas
git commit -m "feat: expose sixelapi helpers and fill in sixel unit tests"
```

---

## Task 14: xkcdapp.pas — orchestration

The `Run` function ties all the pieces together. No isolated unit test — its behaviour is verified by the CLI integration in Task 15.

**Files:**
- Create: `src/xkcdapp.pas`

- [ ] **Step 1: Create `src/xkcdapp.pas`**

```pascal
unit xkcdapp;

interface

uses xkcdmodel;

procedure Run(const AOptions: TXkcdOptions);

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Math,
  xkcdcache,
  xkcdhttp,
  xkcdhtml,
  termimageapi,
  termdetectapi
  {$IFDEF MSWINDOWS}
  , Winapi.ShellAPI, Winapi.Windows
  {$ELSE}
  , Posix.Stdlib
  {$ENDIF}
  ;

procedure OpenWithOsViewer(const AFileName: string);
begin
  {$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(AFileName), nil, nil, SW_SHOWNORMAL);
  {$ELSE}
  Posix.Stdlib.system(PAnsiChar(AnsiString('xdg-open "' + AFileName + '"')));
  {$ENDIF}
end;

function FindComicByID(const AComics: TArray<TXkcdComicMeta>;
  AID: Integer): TXkcdComicMeta;
begin
  for var LMeta in AComics do
    if LMeta.ID = AID then
      Exit(LMeta);
  raise EXkcdError.CreateFmt('Comic #%d not found in cache', [AID]);
end;

procedure Run(const AOptions: TXkcdOptions);
var
  LCachePath: string;
  LCache: TXkcdCache;
  LMeta: TXkcdComicMeta;
  LImgSrc, LSubText: string;
  LImgCachePath: string;
  LWidth: Integer;
begin
  LCachePath := CachePath(AOptions.CacheFilename);
  ForceDirectories(ExtractFileDir(LCachePath));
  ForceDirectories(ExtractFileDir(ComicImageCachePath(0))); // ensure images/ exists

  // update-cache subcommand
  if AOptions.SubCommand = 'update-cache' then
  begin
    Writeln('Fetching archive...');
    LCache.LastUpdated := Now;
    LCache.Comics      := ParseArchive(FetchArchiveHtml);
    SaveCache(LCache, LCachePath);
    Writeln(Format('Cache updated: %d comics', [Length(LCache.Comics)]));
    Exit;
  end;

  // Load (or refresh) cache
  if AOptions.NoCache or not CacheExists(LCachePath) or
     IsStale(LoadCache(LCachePath).LastUpdated) then
  begin
    Writeln('Refreshing cache...');
    LCache.LastUpdated := Now;
    LCache.Comics      := ParseArchive(FetchArchiveHtml);
    SaveCache(LCache, LCachePath);
  end
  else
    LCache := LoadCache(LCachePath);

  if Length(LCache.Comics) = 0 then
    raise EXkcdError.Create('No comics in cache');

  // Select comic
  if AOptions.ComicID > 0 then
    LMeta := FindComicByID(LCache.Comics, AOptions.ComicID)
  else
    LMeta := LCache.Comics[0]; // newest first

  // Fetch comic page
  ParseComicPage(FetchComicHtml(LMeta.ID), LImgSrc, LSubText);

  Writeln(Format('#%d: %s', [LMeta.ID, LMeta.Title]));
  Writeln(LSubText);
  Writeln;

  // Resolve image (cache on first fetch)
  LImgCachePath := ComicImageCachePath(LMeta.ID);
  if not TFile.Exists(LImgCachePath) then
    FetchImageToFile(LImgSrc, LImgCachePath);

  // Display
  if AOptions.NoTerminalGraphics then
    OpenWithOsViewer(LImgCachePath)
  else
  begin
    LWidth := AOptions.Width;
    if LWidth <= 0 then LWidth := 800;
    AutoDisplayImage(LImgCachePath, LWidth);
  end;
end;

end.
```

- [ ] **Step 2: Commit**

```
git add src/xkcdapp.pas
git commit -m "feat: add xkcdapp orchestration unit"
```

---

## Task 15: Rewrite xkcd.dpr

The current `xkcd.dpr` is a clone of `sixeldemo.dpr`. Replace it with a minimal entry point that parses args and calls `Run`.

**Files:**
- Modify: `src/xkcd.dpr`
- Modify: `src/xkcd.dproj`

- [ ] **Step 1: Rewrite `src/xkcd.dpr`**

```pascal
program xkcd;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IFDEF LINUX}
  LinuxLibStdCxx in 'LinuxLibStdCxx.pas',
  {$ENDIF}
  System.SysUtils,
  xkcdmodel  in 'xkcdmodel.pas',
  xkcdargs   in 'xkcdargs.pas',
  xkcdapp    in 'xkcdapp.pas';

{$IFDEF MSWINDOWS}
procedure EnableVTProcessing;
var
  LHandle: THandle;
  LMode: DWORD;
begin
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if GetConsoleMode(LHandle, LMode) then
    SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
end;
{$ENDIF}

var
  LArgs: TArray<string>;
  LOptions: TXkcdOptions;

begin
  try
    {$IFDEF MSWINDOWS}
    EnableVTProcessing;
    {$ENDIF}

    SetLength(LArgs, ParamCount);
    for var I := 1 to ParamCount do
      LArgs[I - 1] := ParamStr(I);

    LOptions := ParseArgs(LArgs);
    Run(LOptions);
  except
    on E: EXkcdArgError do
    begin
      Writeln(ErrOutput, 'Error: ', E.Message);
      Writeln(ErrOutput, 'Usage: xkcd <show|update-cache> [options]');
      ExitCode := 1;
    end;
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
```

- [ ] **Step 2: Update `src/xkcd.dproj` DCCReference list**

In the `<ItemGroup>` block, replace the existing `<DCCReference>` entries with:

```xml
<DelphiCompile Include="$(MainSource)">
    <MainSource>MainSource</MainSource>
</DelphiCompile>
<DCCReference Include="LinuxLibStdCxx.pas"/>
<DCCReference Include="xkcdmodel.pas"/>
<DCCReference Include="xkcdargs.pas"/>
<DCCReference Include="xkcdhtml.pas"/>
<DCCReference Include="xkcdcache.pas"/>
<DCCReference Include="xkcdhttp.pas"/>
<DCCReference Include="xkcdapp.pas"/>
<DCCReference Include="termdetectapi.pas"/>
<DCCReference Include="kittieapi.pas"/>
<DCCReference Include="itermapi.pas"/>
<DCCReference Include="termimageapi.pas"/>
<DCCReference Include="sixelapi.pas"/>
```

- [ ] **Step 3: Build the xkcd CLI (Win64)**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "src\xkcd.dproj" -Platform Win64
```

Expected: build succeeds.

- [ ] **Step 4: Smoke-test the CLI**

```powershell
# Show latest comic
.\bin\Win64\Debug\xkcd.exe show --latest

# Show a specific comic
.\bin\Win64\Debug\xkcd.exe show --comic-id 1

# Update the cache
.\bin\Win64\Debug\xkcd.exe update-cache
```

Expected for each: title and subtext printed, image displayed (or OS viewer opened if terminal doesn't support graphics).

- [ ] **Step 5: Commit**

```
git add src/xkcd.dpr src/xkcd.dproj
git commit -m "feat: rewrite xkcd.dpr as entry-point-only CLI glue"
```

---

## Task 16: Final — sync XkcdTests.dpr + dproj, build all, verify clean run

Ensure the test project knows about all the new units and every test passes.

**Files:**
- Modify: `tests/XkcdTests.dpr`
- Modify: `tests/XkcdTests.dproj`

- [ ] **Step 1: Verify `tests/XkcdTests.dpr` uses clause includes all test units**

The uses clause must contain exactly these entries (add any that are missing):

```pascal
uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF}
  {$IFNDEF TESTINSIGHT}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF}
  DUnitX.TestFramework,
  testSixelApi   in 'testSixelApi.pas',
  testKittieApi  in 'testKittieApi.pas',
  testItermApi   in 'testItermApi.pas',
  testTermDetect in 'testTermDetect.pas',
  testXkcdHtml   in 'testXkcdHtml.pas',
  testXkcdCache  in 'testXkcdCache.pas',
  testXkcdArgs   in 'testXkcdArgs.pas',
  testXkcdHttp   in 'testXkcdHttp.pas';
```

- [ ] **Step 2: Verify `tests/XkcdTests.dproj` ItemGroup includes all test units**

The `<ItemGroup>` block must include:

```xml
<DCCReference Include="testSixelApi.pas"/>
<DCCReference Include="testKittieApi.pas"/>
<DCCReference Include="testItermApi.pas"/>
<DCCReference Include="testTermDetect.pas"/>
<DCCReference Include="testXkcdHtml.pas"/>
<DCCReference Include="testXkcdCache.pas"/>
<DCCReference Include="testXkcdArgs.pas"/>
<DCCReference Include="testXkcdHttp.pas"/>
```

- [ ] **Step 3: Build and run full test suite**

```powershell
pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
     -ProjectFile "tests\XkcdTests.dproj" -Platform Win64
.\bin\Win64\Debug\XkcdTests.exe
```

Expected: all unit tests pass. Integration tests (`TTestXkcdHttp`) also pass if network is available.

- [ ] **Step 4: Build all source projects for Win64**

```powershell
foreach ($proj in @('sixeldemo','kittydemo','itermdemo','termdetectdemo','xkcd')) {
    pwsh -File "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1" `
         -ProjectFile "src\$proj.dproj" -Platform Win64
}
```

Expected: all 5 projects build successfully.

- [ ] **Step 5: Final commit**

```
git add tests/XkcdTests.dpr tests/XkcdTests.dproj
git commit -m "chore: sync test runner with all new test units; all tests passing"
```

---

## Appendix: sk4d.dll placement

The test exe (`bin\Win64\Debug\XkcdTests.exe`) needs `sk4d.dll` at runtime because `sixelapi.pas` pulls in `System.Skia`. Copy it from the sixeldemo build output:

```powershell
Copy-Item "bin\Win64\Debug\sk4d.dll" "bin\Win64\Debug\" -ErrorAction SilentlyContinue
```

If the DLL isn't there yet, build `sixeldemo` first — the Delphi build process copies it automatically.
