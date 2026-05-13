# xkcd Delphi CLI Architecture

A Delphi native cross-platform console application (Windows + Linux, eventually macOS) for displaying XKCD. Demonstrates displaying graphics in the terminal via Sixel, ITerm2, Kitty, etc. Inspired by `dcs-xkcd-cli`.

## 1. Goals & Motivation

The primary motivation is to provide a high-performance, low-latency native binary for viewing XKCD comics directly in modern terminals. A compiled Delphi binary starts in under 50 ms, significantly faster than interpreted alternatives.

**Key Goals:**
- Cross-platform support (Windows + Linux parity).
- Native terminal graphics support (Sixel, Kitty, ITerm2).
- Zero external library dependencies at runtime (except for optional graphics encoders).
- Full unit test coverage for core logic.

**Non-goals for v1:**
- GUI / windowed interface.
- Built-in TUI (planned for v2).

---

## 2. Cross-Platform Strategy (No VCL/FMX)

This is a pure console application using the Delphi Run-Time Library (RTL) and Skia4Delphi for image processing.

| Layer                        | Choice                                 | Why                                     |
| ---------------------------- | -------------------------------------- | --------------------------------------- |
| Application frame            | Console app (no framework)             | No UI needed                            |
| Image load / resize / invert | Skia4Delphi                            | Cross-platform, GPU-optional, no VCL    |
| HTTP                         | `TNetHTTPClient` (RTL)                 | Built-in, cross-platform                |
| JSON                         | `System.JSON` (RTL)                    | Built-in                                |
| HTML parse                   | Custom Regex-based                     | Minimal structures, no library needed   |
| Terminal I/O                 | Direct RTL + Platform API              | Low-level control needed for probes     |
| Text encoding                | UTF-8 at HTTP/cache/console boundaries | Prevents mojibake in comic captions     |

### Skia4Delphi
- Used for LANCZOS-quality resizing and pixel-level color inversion.
- Operates in a console-safe manner without requiring a window handle.

---

## 3. Terminal I/O

### 3.1 Protocol Detection
The application probes the terminal using escape sequences to detect supported graphics protocols:
1. **Kitty+**: PNG format support via APC.
2. **ITerm2**: Proprietary `ReportCellSize` probe.
3. **Kitty**: Raw RGB format support.
4. **Sixel**: Primary Device Attributes (DA1) probe (attribute `4`).

### 3.2 Raw Mode I/O
To read terminal responses (like pixel size or protocol probes) without waiting for a newline, the application switches the terminal to "raw mode":
- **Windows**: Uses `GetConsoleMode` / `SetConsoleMode` with `ENABLE_VIRTUAL_TERMINAL_INPUT`.
- **Linux**: Uses `termios` API to disable `ICANON` and `ECHO`.

### 3.3 Unicode Console Output

Caption text is stored internally as Delphi `string`/UTF-16. On Windows, `xkcdconsole.ConfigureUnicodeConsole` sets console input/output code pages and Delphi `Text` code pages to UTF-8 before user-visible text is printed. This setup is separate from terminal graphics protocol detection so caption text output remains independent from image rendering.

---

## 4. Sixel Protocol Implementation

Sixel is a legacy DEC format supported by modern terminals like Windows Terminal 1.22+, xterm, and WezTerm.

- **Quantization**: Sixel supports max 256 colors. The app ideally uses `libsixel` if available, or falls back to an internal median-cut quantizer or ImageMagick.
- **Encoding**: Generates sixel bands (6-pixel vertical strips) represented by ASCII characters 63-126.

---

## 5. HTML Parsing

The application uses `System.RegularExpressions` to parse the two required structures:
- **Archive Page**: Extracts comic IDs, HRefs, and titles.
- **Comic Page**: Extracts the image source URL and the subtext (alt-text).

HTML responses are read as UTF-8. `HtmlDecode` decodes common named entities used in captions and titles, numeric decimal/hex entities, and full Unicode code points. Code points outside the Basic Multilingual Plane are emitted as valid UTF-16 surrogate pairs.

---

## 6. Cache System

- **Metadata Cache**: A JSON file stored at `~/.cache/xkcd-cli/cache.json` containing the list of known comics.
- **Detail Cache**: JSON files under `~/.cache/xkcd-cli/detail/` containing per-comic image URL and decoded subtext/caption.
- **Image Cache**: Downloaded comic images are cached under `~/.cache/xkcd-cli/images/`.
- **Encoding**: Metadata and detail JSON are read and written as UTF-8.
- **Staleness**: Cache is considered stale after 24 hours.
- **Bypass**: `--no-cache` bypasses metadata and detail cache reads, refetches from xkcd.com, and rewrites the cache with decoded Unicode text.

---

## 7. CLI Command Structure

The application follows a subcommand-based interface.

### Subcommands:
- `show`: Displays a comic.
- `random`: Displays a random comic.
- `update-cache`: Forces a refresh of the metadata cache.

### Options:
- `--latest`: Show the newest comic (default).
- `--comic-id N`: Show a specific comic by number.
- `--width N`: Target pixel width (-1 = fit terminal).
- `--no-terminal-graphics`: Skip in-terminal rendering; opens in the default OS image viewer.
- `--no-invert`: Suppress automatic color inversion on dark backgrounds.
- `--cache-filename PATH`: Override the default cache location.
- `--no-cache`: Skip metadata/detail cache reads and fetch fresh data from xkcd.com.

### Future Options:
- `--no-terminal-scale-up`: Prevent upscaling smaller comics.
- `--fzf-cmd PATH`: Custom path for the `fzf` binary for interactive selection.

---

## 8. Implementation Roadmap

### Phase 1: Core Plumbing
- Console app scaffolding for Windows/Linux.
- HTTP fetching and Regex parsing.
- JSON cache management.

### Phase 2: Terminal Graphics
- Raw mode I/O implementation.
- Protocol detection (Sixel, Kitty, ITerm2).
- Escape sequence handling.

### Phase 3: Image Processing
- Skia4Delphi integration.
- Aspect-ratio aware resizing.
- Alpha-preserving color inversion.

### Phase 4: Polish & Interaction
- `random` command.
- Interactive selection via `fzf`.
- More cache hardening for corrupted JSON and permission failures.

---

## 9. Key Escape Sequences

| Sequence                                    | Purpose                                                  |
| ----------------------------                | -------------------------------------------------------- |
| `ESC[c`                                     | Sixel detection (DA1)                                    |
| `ESC[14t`                                   | Query terminal pixel size                                |
| `ESC]11;?BEL`                               | Query background color (OSC 11)                          |
| `ESC_G ... ESC\`                            | Kitty graphics protocol (APC)                            |
| `ESC]1337;File=inline=1:...BEL`             | ITerm2 inline image (OSC)                                |
| `ESC P ... q ... ESC\`                      | Sixel graphics stream (DCS)                              |
