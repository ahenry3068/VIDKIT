# ADDENDUM #1 (Currently defined Frame Type fields, 256 possible 8 bit values)

TYPE 1: Sprite based video with full palette following each frame, palette is 512 bytes in size for 8 bpp or 32 bytes for 4bpp. Video frame is made up of a Sprite Grid. The sprite size is specified in Sprite Width & Sprite Height. Frame data is immediately followed by palette data for the frame.

TYPE 2: Sprite based video like Type 1 but with NO palette data in the file (separate audio file)

(for either grayscale 4 bpp or VERA default (or user loadable) palette 8 bpp. The player looks for a .PAL file with the same name as the video and uses the VERA default palette if there is none. IMPLEMENTED: Movie Maker writes it with an external palette, VIDKIT and the desktop player play it.)

TYPE 3: Bitmap based video with full palette following each frame. Either 640 or 320 width, the the converter disallows 640 for 4bpp videos (just to big). Bit depths 1, 2 or 4. Sprite size is insignificant for this video type. Frame data is immediately followed by palette data for the frame.

TYPE 4: NOT IMPLEMENTED (bitmap frames no palette)

(for either grayscale 4,2 or 1 bpp or VERA default (or user loadable) palette 8 bpp)

TYPE 5: Currently UNDEFINED.

TYPE 6: Matches Type 1 but doesn’t use a separate audio file. Embedded audio.

TYPE 7: Matches Type 2 (no palette data, .PAL file or VERA default) but with embedded audio

TYPE 8: Matches Type 3 but with embedded audio

TYPE 9: (NOT IMPLEMENTED) Should match Type 4 but with embedded Audio

The X16 Movie Maker can make videos that are padded out so that all DATA Elements are even multiples of 512 bytes. This corresponds to a full sector block on an SD-Card. On X16 Hardware and with an unfragmented SD-Card these are capable of higher resolution with a decent frame rate than videos played using CBM File system access. ( F11 – Is the control key to activate this in the Movie Maker)

IF THESE FILES ARE FRAGMENTED ON AN SD-CARD THEY WILL NOT PLAY PROPERLY !!!. NO ERROR CHECKING FOR THIS CONDITION IS CURRENTLY PERFORMED IN THE PLAYER.

TYPE 23: A Sector Aligned Bitmap Video meant for SPI Play with a separate

file as the audio track.

TYPE 28: A Sector Aligned Bitmap Video meant for SPI Play with embedded audio

data

For type 23 & 28 the palette block is ALWAYS a full 512 bytes. For 8 bpp files the entire palette is significant. For all bit depths \< 8 significant values alternate between row 14 & row 15 of the palette. For Even numbered frames the significant palette will be row 14 with row 15 for odd numbered frames. Current Engine must always start play on an even frame for correct palette alignment on videos with bit depth’s less than 8.

The encoder currently set’s any palette entry not used in the video to the VERA default value for that entry. At some point it will be possible to use a User specified palette for those entry’s but that is not yet implemented in the converter. Audio frame follows the same guidelines as above but for these videos audio sample rate is always chosen by the converter to give an audio frame size that is evenly divisible by 512 bytes, this is not true for the Standard video type.

## ADDITIONAL TYPES (added since the original list)

TYPE 21: High bandwidth sprite video (sector aligned), palette sector after each frame, separate audio file. TYPE 22: High bandwidth sprite video, no palette in the file (a .PAL file or the VERA default is used), separate audio file. TYPE 26 and TYPE 27: the same as 21 and 22 but with embedded audio.

TYPE 86: VGA (MS-DOS) bitmap video, padded frames, embedded audio. TYPE 88: Mode X (MS-DOS) bitmap video, embedded audio. When the header BPP is 4, TYPE 88 is the VGA 16 color format: 4 bit planar frames (EGA mode 0Dh layout) followed after every frame by a 16 entry palette of 6 bit R,G,B (48 bytes).

TYPE 99: MJPG video (JPEG frames) with embedded audio. Desktop only, not playable on the X16. Always marked with Shint “A” by the Movie Maker 2.0 when “Keep original aspect” is checked (see Addendum #3).

TYPE 199: Amiga planar bitmap video, embedded audio. The Paula audio period is stored as a 16 bit little endian value in header EXTRA bytes 0-1. See Addendum #2 for the Amiga audio description.

Types 21, 22, 26 and 27 follow from the build rule below and from the VIDKIT and desktop player (SPV-HANDLES) source.

HOW THE MOVIE MAKER BUILDS THE TYPE NUMBER: it starts with 1 (sprite) or 3 (bitmap), adds 1 when the palette is external (not stored per frame), adds 5 when the audio is embedded and adds 20 for sector aligned (SPI) output. Types 4 and 9 (bitmap with no palette) would result from the same rule but are not produced and are not played by VIDKIT, so they remain NOT IMPLEMENTED.

ALL OTHER TYPE NUMBERS are TBD
