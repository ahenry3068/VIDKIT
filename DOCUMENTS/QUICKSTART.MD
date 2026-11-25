# VIDKIT Quickstart

## What VIDKIT does

VIDKIT is a banked RAM library that enables:

- Playback of SPV video files (sprite and bitmap based)
- Playback of PCM audio (WAV and ZCM)
- Streaming from the SD card file system
- Various functions to aid in screen transition management

> **Playback runs in the foreground.** Your program pauses while media plays.

## Requirements

Before using VIDKIT:

- Load the library at `$A000` in Bank 1 or higher
- Ensure 3 consecutive RAM banks are available:
  - Bank A = load bank
  - Bank B = A + 1
  - Bank C = A + 2

## Minimal setup (must do first)

After loading VIDKIT:

```
JSR $A000      ; VIDKIT_INIT
```

This:

- Initializes internal variables
- Installs trampoline code
- Saves current screen + charset

You must call this at least once before anything else.

## Fastest way to play something

**Option 1: one-step load + play**

```
; Put filename (no extension) at $BF00 (Bank 0)
JSR $A003   ; VIDKIT_LOAD_AND_PLAY
```

- Automatically searches: `.SPV`, `.WAV`, `.ZCM`
- Plays immediately

**Option 2: manual control (recommended)**

```
JSR $A006      ; LOAD_MEDIA_FILE
JSR $A009      ; PLAY_MEDIA_FILE
```

Use this if you want to:

- Set start/end frames
- Control timing
- Reuse loaded media
- Control screen transitions

## How to pass a filename

- Store a null-terminated string
- At: RAM Bank 0 : `$BF00`
- Do NOT include the file extension

Example: `"INTRO"` will match `INTRO.SPV` / `INTRO.WAV` / `INTRO.ZCM`.

## Basic video controls

**Set frame range**

```
; R0 = start frame (24-bit)
; R3 = end frame (24-bit)
JSR $A012   ; SET_FRAME_RANGE
```

Frame numbers are passed as 32-bit values, but only the low 24 bits are used, so the high byte should be 0. (24 bits covers over 16 million frames, far beyond any practical video.)

**Set start time (seconds)**

```
; R5 = start time
JSR $A015   ; SET_STARTTIME
```

## Audio-specific control

For PCM audio, R4-R5 = start time in jiffies (32-bit). Use this instead of seconds for accurate audio seeking.

```
JSR $A036   ; SET_STARTTIME_JIFFIES
```

## Play for a fixed duration

```
; R4-R5 = duration in jiffies (32-bit)
JSR $A033   ; PLAY_TO_TIMER
```

- Works for both video and audio
- Required for early exit in PCM playback

## Default key controls

During video and audio playback:

| Key | Action |
|---|---|
| ESC | Stop playback |
| SPACE | Pause / resume |
| Up / Down | Volume |
| F5 | Set loop flag. Looping is not implemented in the library; the app using VIDKIT can decide how to respond to this flag. The author's players use it to activate looped playback |

Disable controls:

```
LDA #$01
STA $33       ; LOCK_KEYS
```

## Screen behavior

By default, VIDKIT restores screen mode after playback.

Disable auto-restore:

```
LDA #$01
STA $043A     ; DISABLE_RESTORE
```

> If you disable this, you must manage VERA state yourself. Various functions in VIDKIT itself allow for changing and fades of the palette, showing and hiding layers, and clearing areas in VRAM.

## Clean up / reuse

If keeping media open:

```
JSR $A01E       ; CLOSE_MEDIA
```

Otherwise, VIDKIT closes automatically after playback.

## Minimal working flow

```
JSR $A000        ; INIT
; write "INTRO" to $BF00 (null terminated)
JSR $A003        ; LOAD_AND_PLAY
```

That's it: you're playing video or audio.

## Where to go next

Once basic playback works, explore:

- Custom key handlers (HookControls)
- Frame-accurate seeking
- Audio-only visualizers (user frame driver)
- Palette effects and fades
- Looping playback systems
