# xkcd Delphi CLI

A high-performance, cross-platform native command-line tool for viewing [xkcd](https://xkcd.com/) comics directly in your terminal.

![XkcdDelphiCli](XkcdDelphiCli.webp)

## Features

- **Blazing Fast**: Starts in under 50ms.
- **Terminal Graphics**: Native support for Sixel, Kitty, and ITerm2 image protocols.
- **Smart Inversion**: Automatically adapts neutral comic backgrounds/line art for dark terminals while preserving colored regions.
- **Cross-Platform**: Built for Windows and Linux.
- **Unicode Captions**: Decodes common HTML entities and full Unicode numeric code points, including non-BMP characters.
- **Local Cache**: Caches comic metadata, comic detail captions, and downloaded images to reduce network overhead.
- **Local Search**: Stores comic metadata in SQLite and supports literal search over cached titles, captions, and Explain XKCD transcripts/explanations.

## Usage

```powershell
# Show the latest comic
xkcd show

# Show a specific comic
xkcd show --comic-id 149

# Show a specific comic using positional syntax
xkcd show 747

# Show a comic with Explain XKCD explanation text
xkcd show 149 --explained

# Show a comic with Explain XKCD transcript text
xkcd show 149 --transcript

# Show a random comic
xkcd random

# Disable terminal graphics (opens in OS image viewer)
xkcd show --no-terminal-graphics

# Disable automatic color inversion
xkcd show --no-invert

# Force update the local metadata cache
xkcd update-cache

# Incrementally fetch missing Explain XKCD explanations into the local search DB
xkcd update-cache --explained

# Incrementally fetch missing Explain XKCD transcripts into the local search DB
xkcd update-cache --transcript

# Refresh Explain XKCD data for one comic, even if it is already cached
xkcd update-cache --explained --transcript --comic-id 149 --no-cache

# Search the local SQLite comic index
xkcd search "standards"
```

### Options

| Option | Description |
| --- | --- |
| `--latest` | Show the newest comic (default). |
| `--comic-id N` | Show a specific comic by number. |
| `--width N` | Target pixel width (-1 = fit terminal). |
| `--no-terminal-graphics` | Skip in-terminal rendering; opens in OS viewer. |
| `--no-invert` | Suppress automatic color inversion on dark backgrounds. |
| `--explained` | With `show`, display Explain XKCD explanation text. With `update-cache`, fetch missing Explain XKCD pages into SQLite. |
| `--transcript` | With `show`, display Explain XKCD transcript text. With `update-cache`, fetch missing Explain XKCD pages into SQLite. |
| `--cache-filename PATH` | Override default cache location. |
| `--db-filename PATH` | Override default SQLite database location. |
| `--no-cache` | Skip metadata/detail cache reads and fetch fresh data from xkcd.com. |

## Unicode, Caching, and Search

HTML is fetched and cached as UTF-8. Comic titles and captions are decoded from HTML entities before display, including smart punctuation (`&rsquo;`, `&ldquo;`, `&mdash;`, `&hellip;`) and numeric entities outside the Basic Multilingual Plane. On Windows, the CLI configures console input, output, and error streams for UTF-8 before printing captions.

`update-cache` refreshes the JSON archive cache and seeds the local SQLite database at `~/.cache/xkcd-cli/xkcd.sqlite`. Add `--explained` and/or `--transcript` to incrementally fetch missing Explain XKCD pages and store their parsed explanation/transcript text in SQLite. Existing Explain XKCD rows are skipped by default; add `--no-cache` to force a fresh fetch/re-parse. `show --explained` and `show --transcript` display cached Explain XKCD text when available, otherwise they fetch, parse, store, and display that comic's page. Explain XKCD pages are requested with their canonical comic-title URLs when the archive title is available, with retry/backoff for transient 429/500/502/503/504 responses. The `search` command performs literal, case-insensitive search over local SQLite data. Archive titles are searchable after `update-cache`; captions become searchable after a comic has been viewed or refetched; transcripts and explanations become searchable after `update-cache --explained`, `update-cache --transcript`, `show --explained`, or `show --transcript`.

Downloaded images are cached only in their original form. Terminal inversion is applied at display time, so changing `--no-invert` does not create or depend on a second cached image file.

If an older cached caption was saved before Unicode handling was fixed, run with `--no-cache` to refetch the comic detail and overwrite the stale detail cache:

```powershell
xkcd show --comic-id 1234 --no-cache
```

## Architecture

For detailed information on the project's internal structure, terminal protocol detection, and cross-platform strategy, please refer to [Architecture.md](./Architecture.md).

## Requirements

- **Windows**: [Windows Terminal 1.22+](https://github.com/microsoft/terminal/releases) (from Aug 1, 2025) recommended for Sixel support.
- **Linux**: A terminal supporting Sixel (xterm, mlterm), Kitty, or ITerm2 protocols.
- **Skia**: Uses [Skia4Delphi](https://skia4delphi.org/) for image processing (`sk4d.dll` or `libsk4d.so` must be present).

## License

Distributed under the GNU General Public License v3.0. See `LICENSE` for more information.
