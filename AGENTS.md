## OVERVIEW
This repository is a Delphi console application suite for viewing XKCD comics in terminals, with a strong focus on reusable rendering components and proof-of-concept protocol support.

Primary product:
- `xkcd` CLI app: fetches XKCD metadata/content over HTTP, caches it locally, and renders images in terminal environments.

Companion/demo tools:
- `iterm2demo`, `kittydemo`, `sixeldemo`, `termdetectdemo`: small console demos that exercise protocol-specific units and terminal detection behavior.

Who this serves:
- Developers and power users who want fast terminal-based XKCD viewing, including graphical terminal protocols (Kitty, iTerm2 inline images, Sixel).

Backend/system boundary:
- Network boundary is HTTP to XKCD endpoints.
- Persistence boundary is local filesystem cache under user cache path, including JSON/image files and a local SQLite search database.

## PROJECT VARIANTS
Projects in the group:
- `src/xkcd.dproj` — main CLI.
- `src/iterm2demo.dproj` — iTerm2 rendering demo.
- `src/kittydemo.dproj` — Kitty rendering demo.
- `src/sixeldemo.dproj` — Sixel rendering demo.
- `src/termdetectdemo.dproj` — terminal detection demo.
- `tests/XkcdTests.dproj` — DUnitX test runner.

Common build traits:
- Console projects.
- Debug/Release configs.
- Win32/Win64/Linux64 platform metadata present.

## NAMING CONVENTIONS
Observed conventions (follow these, even if not textbook Delphi naming):
- Core app units use lowercase domain names: `xkcdapp`, `xkcdargs`, `xkcdcache`, `xkcdhtml`, `xkcdhttp`, `xkcdmodel`.
- Protocol/support units generally end with `api`: `termdetectapi`, `termimageapi`, `iterm2api`, `kittieapi`, `sixelapi`.
- Tests mirror production responsibilities: `testXkcdArgs`, `testXkcdCache`, `testTermDetect`, etc.
- Types still use Delphi-style `T*` and `E*` names (`TXkcdOptions`, `EXkcdArgError`, etc.).

Note: `kittieapi`/`testKittieApi` spelling is intentionally present in repo. Do not “correct” naming unless requested.

## ARCHITECTURE
High-level flow (main app):
1. `xkcd.dpr` remains thin: parse args, call `Run(LOptions)` in `xkcdapp`.
2. `xkcdapp` orchestrates behavior only.
3. Specialized units do focused work:
   - `xkcdargs`: parse/validate CLI.
   - `xkcdhttp`: HTTP fetch/download boundary.
   - `xkcdhtml`: parse archive/comic HTML and decode HTML entities into Unicode strings.
   - `xkcdcache`: UTF-8 JSON + file cache read/write/path/staleness.
   - `xkcddb`: FireDAC SQLite connection/schema/upsert/search boundary.
   - `xkcdexplained`: parse Explain XKCD transcript/explanation HTML.
   - `xkcdconsole`: console text encoding and VT setup.
   - `xkcdmodel`: shared records/options/exceptions.

Terminal rendering architecture:
- `termdetectapi`: capability and environment detection.
- Protocol adapters: `sixelapi`, `kittieapi`, `iterm2api`.
- `termimageapi`: dispatcher/facade over detection + adapters + fallback viewer behavior.
- `termimagecolor`: shared selective inversion logic for neutral/grayscale pixels.

Design intent confirmed by developer:
- Demo projects are part of architecture strategy for reusability and proof-of-concept validation.
- Units should stay small, focused, and reusable.

## CODING STYLE
Project style currently favors:
- Thin `.dpr` entry points.
- Small units with single responsibility.
- Clear boundaries between orchestration, parsing, networking, rendering, and persistence.
- Practical modern Delphi usage (inline vars, generics, records where appropriate).

For new code:
- Keep logic out of `.dpr` and out of demo programs; put behavior in reusable units.
- Add features by extending existing focused units before creating new cross-cutting abstractions.
- Keep protocol-specific logic inside protocol units; keep dispatch in `termimageapi`.

## THIRD-PARTY DEPENDENCIES
Runtime/feature dependencies observed:
- Skia (`System.Skia`) is actively used in terminal image pipeline and SVG rendering paths.
- FireDAC SQLite is used for the local search database; keep SQL parameterized and Unicode-aware.
- Terminal protocol implementations are custom code (Kitty/iTerm2/Sixel escape/protocol handling), not large external component suites.

Testing/tooling dependencies:
- DUnitX (`DUnitX.TestFramework`) is the primary test framework.
- Optional TestInsight integration appears in test runner path.

Not observed:
- No BDE/ORM database framework usage.
- No DevExpress/TMS/JVCL/FastReport-style UI component suites.

## RULES FOR AI AGENTS
1. Treat this as a console + terminal-graphics codebase, not VCL/FMX form architecture.
2. Keep `.dpr` files minimal; place behavior in units.
3. Preserve small, focused unit boundaries; avoid “god units”.
4. Keep protocol adapters isolated (`sixelapi`, `kittieapi`, `iterm2api`); do not blend protocol internals into orchestration.
5. Route cross-protocol display decisions through `termimageapi` (or equivalent dispatcher), not ad hoc call sites.
6. Keep backend assumptions limited to HTTP + local cache files/SQLite.
7. Mirror test naming and structure: one test unit per production concern where possible.
8. Prefer deterministic unit tests for parsers/encoders; isolate live-network integration tests.
9. Do not rename existing quirky identifiers (e.g., `kittieapi`) without explicit request.
10. Maintain reusability/proof-of-concept orientation for demo projects.
11. Keep text Unicode-aware end to end: HTTP content and cache files use UTF-8; parsed captions/titles are Delphi strings; Windows console text output is configured in `xkcdconsole`.

## HOW TO WORK IN THIS CODEBASE
When adding a feature:
- Start from domain model/options (`xkcdmodel`, `xkcdargs`) if CLI behavior changes.
- Extend orchestration in `xkcdapp` only after adding reusable lower-level capability.
- For fetch/parse/cache changes, modify `xkcdhttp`/`xkcdhtml`/`xkcdcache` respectively, not all-in-one.
- For local search/database changes, keep schema, connection, upserts, and search helpers in `xkcddb`.
- For Explain XKCD ingestion, keep network fetches in `xkcdhttp`, parsing in `xkcdexplained`, and storage/search updates in `xkcddb`. The `--explained` flag means explanation text; `--transcript` means transcript text.
- For terminal output changes, implement/adjust protocol unit and keep dispatch in `termimageapi`.
- For image color/inversion changes, keep shared pixel classification in `termimagecolor` and avoid writing derived inverted cache files.
- For user-visible text encoding changes, keep the boundary logic in `xkcdhtml`, `xkcdcache`, `xkcdhttp`, or `xkcdconsole` as appropriate.
- Add or update tests in matching `tests/test*` unit.

Testing guidance:
- Framework: DUnitX.
- Existing coverage is good for args/cache/html and protocol parsing/encoding helpers.
- Unicode regressions should be covered at both parser and cache boundaries: named entities, decimal/hex numeric entities, non-BMP code points, and UTF-8 JSON roundtrips.
- SQLite/search regressions should cover schema idempotency, Unicode roundtrips, and literal search over title/caption/transcript/explanation fields.
- Gaps worth prioritizing when touching behavior:
  - `xkcdapp` orchestration flow tests.
  - HTTP failure-path tests (timeouts/non-200/malformed content).
  - Cache corruption/permission edge cases.
  - More malformed terminal response edge cases.

## UNCERTAINTIES
- Tooling read mismatch occurred for some files (`tests/XkcdTests.dpr`, some .dpr/.dproj reads returned `xkcd` content). Runner/config conclusions are supported by search results and other files but should be re-checked directly if exact runner flags matter.
- `TXkcdOptions.ShowLatest` appears parsed but may be underused in current orchestration; verify intent before relying on it.
- `tpKittyPlus` vs `tpKitty` behavioral distinction is inferred from detection/dispatch flow but not deeply documented in comments.
