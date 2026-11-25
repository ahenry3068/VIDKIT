# VIDKIT

**A streaming media library for the Commander X16.**
Version 2.0 · MIT-0 licensed · by Anthony W. Henry

VIDKIT is a banked-RAM library, loaded at `$A000`, that plays video and audio
from the SD card while your program waits. It plays the SPV videos made by the
**X16 Movie Maker**, plus PCM audio, and it can be called from BASIC, assembly
or [Prog8](https://prog8.readthedocs.io/).

- **Video:** standard sprite and bitmap SPV videos, and high-bandwidth bitmap
  SPV videos (SD card only, no HostFS).
- **Audio:** 16-bit signed PCM WAV (mono or stereo) and 8- or 16-bit ZCM
  (mono or stereo).
- **Display shape:** videos can carry a true display aspect (SPV hint `A`),
  so wide and narrow pictures play in their real shape.
- **Extras:** screen transitions and palette fades, hide/show of the layers,
  time and frame ranges, seeking, and key handling you can hook or extend.

> Playback runs in the foreground. Your program pauses while media plays, and
> other interrupt-driven work should be suspended during playback. For
> background music see [ZSMKit](https://github.com/mooinglemur/zsmkit), which
> VIDKIT can pause and resume around a video (see the API document).

## Quick start

1. Load `VIDKIT-A000.BIN` at `$A000` in RAM bank 1 or higher. VIDKIT needs three
   consecutive banks (A = load bank, B = A+1, C = A+2).
2. `JSR $A000` once (`INIT`). It sets up its variables and the trampoline at
   `$0400`, and saves the current screen and charset.
3. Put the file name, with no extension and ending in a zero byte, at RAM bank 0,
   `$BF00`, then `JSR $A003` (`LOAD_AND_PLAY`). VIDKIT finds the `.SPV`, `.WAV`
   or `.ZCM` file and plays it.

```
JSR $A000        ; INIT
; write "INTRO",0 to bank 0, $BF00
JSR $A003        ; LOAD_AND_PLAY
```

For finer control use `LOAD_PREPPLAY` (`$A006`) and `PLAY_PREPPED_FILE`
(`$A009`), or the frame, time and jiffy range calls. During playback `ESC`
stops, `SPACE` pauses, Up/Down change the volume and `F5` sets the loop flag.
Read `DOCUMENTS/QUICKSTART.MD` next.

`VIDKIT_VERSION` (`$A03C`) returns the version in `.A` (major) and `.X`
(minor). Carry clear means a release build; carry set means a development
build. This release returns **2.0, carry clear**.

## What is in the binary

`VIDKIT-A000.BIN` is 23,583 bytes. It fills three 8 KB banks, and each part is
padded with zero bytes to its slot:

| Bank | Contents | Slot (bytes) | Written in |
|---|---|---|---|
| A | `VIDKIT-B1` (public API, jump table at `$A000`) | 8192 | Prog8 |
| B | `VIDKIT.ENGINE` (standard playback engine) | 2560 | ca65 |
| B | `VIDKIT-B2` (more library code) | 5632 | Prog8 |
| C | `SPIVID.ENGINE` (high-bandwidth SD-card engine) | 5120 | ca65 |
| C | `VIDKIT-B3` (not padded) | rest | Prog8 |

`VIDKIT-B3` must leave at least 512 free bytes at the end of the bank: the fade
routines use them as a scratch palette. The public jump table never changes
between releases.

## Repository layout

| Path | What it is |
|---|---|
| `VIDKIT SOURCE CODE/` | The Prog8 library source (`VIDKIT-B1.p8`, `VIDKIT-B2.p8`, `VIDKIT-B3.p8`, `VIDKIT_COMMON.p8`), the engines, the build tools and the built library (the rows below are inside it) |
| `VIDKIT-B1.p8`, `VIDKIT-B2.p8`, `VIDKIT-B3.p8`, `VIDKIT_COMMON.p8` | The Prog8 library source |
| `VIDKIT-ENGINE/`, `SPIVID-ENGINE/` | The two ca65 engines, each with a `Makefile` |
| `tramp.s`, `vidvars.inc` | Cross-bank trampoline and shared variable definitions |
| `BUILDVIDKIT.BAS` | Build tool, written in [QB64-PE](https://www.qb64phoenix.com/) |
| `Makefile`, `BUILDVIDKIT.ps1` | The same build for Linux/macOS and Windows PowerShell |
| `VIDKIT-A000.BIN`, `VIDKIT.Z` | The built library, and its LZSA-compressed copy (see "Build") |
| `DOCUMENTS/` | Quick start, API and memory map, jump table, the SPV specification and its addenda (Markdown and PDF) |
| `EXAMPLE VIDKIT CODE/` | Example players and a BASIC loader (see "Examples") |

## Documentation

- `DOCUMENTS/QUICKSTART.MD`: the shortest path to playing something.
- `DOCUMENTS/VIDKIT-API-MEMMAP.MD`: the full API, variables and memory map.
- `DOCUMENTS/JUMPTABLE.MD`: the public jump tables in memory order.
- `DOCUMENTS/ERRATA-MEMMAP-API.MD`: corrections and additions since the API
  document was written (moved zero-page variables, `KEY_EXTRA`, the aspect
  hint).

The PDFs in `DOCUMENTS/` are older copies of the same material, and the
Markdown is the one kept up to date.

## Build

You can use the QB64 tool, the Makefile or the PowerShell script. All three do
the same steps and produce the same `VIDKIT-A000.BIN`:

1. Assemble `tramp.s` with 64tass and strip its 2-byte load address to make `tramp.o`.
2. Compile `VIDKIT-B1.p8`, `VIDKIT-B2.p8` and `VIDKIT-B3.p8` with Prog8 (`-target cx16`).
3. Build the two engines with `make` and cl65, and copy up `VIDKIT.ENGINE` and `SPIVID.ENGINE`.
4. Join the five parts, padded to their slots, into `VIDKIT-A000.BIN`.
5. Compress it with `lzsa -r -f2 VIDKIT-A000.BIN VIDKIT.Z`.
6. Copy the results into the example folders.

```
make PROG8JAR=/path/to/prog8c-x.y.z-all.jar     # Linux, macOS, MSYS2
.\BUILDVIDKIT.ps1 -Jar C:\path\to\prog8c-x.y.z-all.jar   # Windows
```

The jar path is remembered in `P8JARPATH` after the first run. `make clean` or
`.\BUILDVIDKIT.ps1 -Clean` removes the generated files. The build stops with a
message if any part is larger than its slot.

**Tools needed:** Java and a Prog8 compiler jar, 64tass, cc65 (`cl65`), GNU
`make`, and `lzsa`. The shipped binaries were built with Prog8 12.x; a different
Prog8 version can change the generated code.

## Sample media

The sample media are attached to the
[v2.0 release](https://github.com/ahenry3068/VIDKIT/releases/tag/v2.0), not kept in
the repository (they are too large): a Chopin nocturne as a WAV. Their origins and
licenses are in `ASSETS-CREDITS.md`.

## Examples

`EXAMPLE VIDKIT CODE/` holds working programs that use VIDKIT:

- `X16 MOVIE PLAYER ( prog8 )/`: the all-purpose `PLAYMOVIES` player.
- `MOVIE MAKER PLAYER TEMPLATES ( prog8 )/`: the small player programs
  (`PLAYPARTS`, `VIDPLAY-TEMPLATE`, `PLAYLIST`) that the Movie Maker patches to
  build a stand-alone player for one video. See `VIDPLAY.README` there.
- `BASLOAD CODE/`: BASIC examples, including a VIDKIT plus ZSMKit demo.

## Related projects

- **X16 Movie Maker**, which converts ordinary video into SPV files:
  <https://cx16forum.com/forum/viewtopic.php?t=8226>
- The desktop applications (Movie Maker and the SPV player) live in their own
  repositories.

## License

VIDKIT is released under the **MIT No Attribution** license (MIT-0). See
[`LICENSE`](LICENSE). You may use it in any project, commercial or not, without
crediting the author.

### Third-party material

- **ZSMKit** (`ZSMKIT-A000.BIN`, used only by the BASIC example) is by
  MooingLemur and has its own license. VIDKIT calls its entry points to pause
  and resume it. VIDKIT's volume up/down routines were optimized by MooingLemur.
- Example artwork: the cassette-tape animation is adapted from a CC BY 3.0 image by
  Matthias Wunderlich (Wikimedia Commons) and the audio artwork from Pixabay. See `ASSETS-CREDITS.md`.
- Sample media, converted from Wikimedia Commons, is not MIT-0: the pelican video (Thierry Dugnolle) is CC BY-SA 4.0 and the Chopin nocturne recording (Olga Gurevich, via Musopen) is CC0. See `ASSETS-CREDITS.md`.
- Build tools: [Prog8](https://prog8.readthedocs.io/) (Irmen de Jong), 64tass,
  cc65 and LZSA. They are not part of this repository.
- The SPI engine's SD-card and FAT32 code is based on the Commander X16 system
  ROM sources and the X16 community's work.
