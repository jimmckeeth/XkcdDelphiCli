# xkcd Delphi CLI

A high-performance, cross-platform native command-line tool for viewing [xkcd](https://xkcd.com/) comics directly in your terminal.

![XkcdDelphiCli](XkcdDelphiCli.webp)

## Features

- **Blazing Fast**: Starts in under 50ms.
- **Terminal Graphics**: Native support for Sixel, Kitty, and ITerm2 image protocols.
- **Smart Inversion**: Automatically inverts comic colors on dark terminal backgrounds (optional).
- **Cross-Platform**: Built for Windows and Linux.
- **Local Cache**: Caches comic metadata to reduce network overhead.

## Usage

```powershell
# Show the latest comic
xkcd show

# Show a specific comic
xkcd show --comic-id 149

# Show a random comic
xkcd random

# Disable terminal graphics (opens in OS image viewer)
xkcd show --no-terminal-graphics

# Disable automatic color inversion
xkcd show --no-invert

# Force update the local metadata cache
xkcd update-cache
```

### Options

| Option | Description |
| --- | --- |
| `--latest` | Show the newest comic (default). |
| `--comic-id N` | Show a specific comic by number. |
| `--width N` | Target pixel width (-1 = fit terminal). |
| `--no-terminal-graphics` | Skip in-terminal rendering; opens in OS viewer. |
| `--no-invert` | Suppress automatic color inversion on dark backgrounds. |
| `--cache-filename PATH` | Override default cache location. |
| `--no-cache` | Skip local cache and fetch directly from xkcd.com. |

## Architecture

For detailed information on the project's internal structure, terminal protocol detection, and cross-platform strategy, please refer to [Architecture.md](./Architecture.md).

## Requirements

- **Windows**: [Windows Terminal 1.22+](https://github.com/microsoft/terminal/releases) (from Aug 1, 2025) recommended for Sixel support.
- **Linux**: A terminal supporting Sixel (xterm, mlterm), Kitty, or ITerm2 protocols.
- **Skia**: Uses [Skia4Delphi](https://skia4delphi.org/) for image processing (`sk4d.dll` or `libsk4d.so` must be present).

## License

Distributed under the GNU General Public License v3.0. See `LICENSE` for more information.
