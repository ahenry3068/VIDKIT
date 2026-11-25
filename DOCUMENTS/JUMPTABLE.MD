# VIDKIT Public API Jump Table

Public API jump table in module/memory order. Omitted table entries are for internal library use. This is a summary only; details are in the main API document.

## VIDKIT-B1.BIN (prog8) - Bank A, jump table at `$A000`

| Bank | Address | Name | Parameters |
|---|---|---|---|
| A | `$A000` | INIT | none |
| A | `$A003` | LOAD_AND_PLAY | media filename at 0:`$BF00` |
| A | `$A006` | LOAD_PREPPLAY | media filename at 0:`$BF00` |
| A | `$A009` | PLAY_PREPPED_FILE | none |
| A | `$A00F` | SET_TARGET_FRAME | 32-bit int frame number at R3 |
| A | `$A012` | SET_FRAME_RANGE | 32-bit start frame at R0, end frame at R3 |
| A | `$A015` | SET_STARTTIME | unsigned 16-bit seconds into media at R5 |
| A | `$A018` | SET_TARGETTIME | unsigned 16-bit seconds end target at R6 |
| A | `$A01B` | SET_TIMERANGE | unsigned 16-bit start seconds at R5, end seconds at R6 |
| A | `$A01E` | CLOSE_MEDIA | none |
| A | `$A021` | HideBothLayers | none |
| A | `$A024` | HideTextLayer | none |
| A | `$A027` | HideGraphicsLayer | none |
| A | `$A02A` | ShowBothLayers | none |
| A | `$A02D` | ShowTextLayer | none |
| A | `$A030` | ShowGraphicsLayer | none |
| A | `$A033` | PLAY_TO_TIMER | number of jiffies playtime, 32-bit int at R4_R5 |
| A | `$A036` | SET_STARTTIME_JIFFIES | number of jiffies into media file, 32-bit int at R4_R5 |
| A | `$A039` | SET_VIDEOMODE | none |
| A | `$A03C` | VIDKIT_VERSION | returns version in `.A` (major), `.X` (minor); carry clear = release version, carry set = dev |

(See also the errata: `$A03F` SET_KEYEXTRA, `$A042` CLEAR_KEYEXTRA.)

## VIDKIT.ENGINE (ca65) - Bank B, jump table at `$A000`

| Bank | Address | Name | Parameters |
|---|---|---|---|
| B | `$A003` | CLEARALLBUFFERS | none |
| B | `$A012` | SET_FRAMEDRIVER | address of frame driver sub in `.X`,`.Y` |
| B | `$A015` | CLEARGRAPHBUFFER | none |
| B | `$A018` | CLEARTEXTBUFFER | none |
| B | `$A01B` | CLEARSPRITEBUFFER | none |
| B | `$A024` | HIDEALLSPRITES (1 to 127) | none |
| B | `$A02A` | SetDefaultPalette (fast) | none |
| B | `$A036` | SetDiskFastMode | none |
| B | `$A039` | Fade2Black / BLACKFADE | none |
| B | `$A03C` | Pal2black (fast) | none |
| B | `$A03F` | SetControls | KeyController1 address at R7, KeyController2 address at R8 |
| B | `$A042` | SetControl1 | KeyController1 address at R7 |
| B | `$A045` | SetControl2 | KeyController2 address at R8 |
| B | `$A048` | SETDEFAULT_CONTROLS (key controllers) | none |

## VIDKIT-B2.BIN (prog8) - Bank B, jump table at `$AA00`

| Bank | Address | Name | Parameters |
|---|---|---|---|
| B | `$AA06` | RESTORE_LINES | none. Sets HSTART / VSTART and all VERA borders to full 640 x 480 scanlines |
| B | `$AA0C` | SETUP_SPRITEGRID | X,Y origin at R7, R8. Sets sprite sizes, position and bit depth for a currently open sprite video; call manually only if `MANAGE_SCREEN` is false |
| B | `$AA15` | RESTORE_SCREEN | no parameters, but does have modifying control variables |
| B | `$AA1B` | HOOK CONTROLS | Control1 address at R7, Control2 address at R8 |
| B | `$AA1E` | HookControl1 | Control1 address at R7 |
| B | `$AA21` | HookControl2 | Control2 address at R8 |
| B | `$AA24` | ResetControls | none |

## SPIVID.ENGINE (ca65) - Bank C, jump table at `$A000`

Most of this jump table is private to VIDKIT. A few public APIs are here.

| Bank | Address | Name | Parameters |
|---|---|---|---|
| C | `$A024` | FIX_ISOCURSOR | none |
| C | `$A027` | setControls (SPI vids only) | Control1 ptr at R7, Control2 ptr at R8 |
| C | `$A02A` | SetControl1 (SPI vids only) | Control1 ptr at R7 |
| C | `$A02D` | SetControl2 (SPI vids only) | Control2 ptr at R8 |
| C | `$A030` | SETDEFAULT_CONTROLS | none |
| C | `$A033` | SETBANK_ZSMKIT (tell VIDKIT where ZSMKIT is loaded) | bank number of ZSMKIT load in R0L |
| C | `$A036` | ZSMKIT_PAUSEALL | pauses (and stores) all playing ZSMKIT priorities |
| C | `$A039` | ZSMKIT_UNPAUSE | restarts ZSMKIT priorities paused by PAUSEALL |

## VIDKIT-B3.BIN (prog8) - Bank C, jump table at `$B400`

| Bank | Address | Name | Parameters |
|---|---|---|---|
| C | `$B412` | FadeToPal | cross fade from current palette to palette data pointed at by ptr at R11 |
| C | `$B415` | FadeToDefPal | none |
| C | `$B418` | FadeToColor | `$0RGB` uword at R0; fades the entire palette to that entry |

Keep the following calls 1 to 1 during program execution. `Swap_ORGISR` may be used before program exit. They are ISR manager helpers for apps that also redirect the system ISR. VIDKIT uses the system timer and is designed to operate with the standard system ISR in service.

| Bank | Address | Name | Parameters |
|---|---|---|---|
| C | `$B41B` | Swap_ORGISR | none. If the ISR vector has been changed since VIDKIT INIT, the ISR in service at INIT is swapped in. The current ISR is also saved for the `Swap_NEWISR` call |
| C | `$B41E` | Swap_NEWISR | none. Restores the ISR set before the call to `Swap_ORGISR`. Should always be called before another call to `Swap_ORGISR` if doing ISR manipulation |
