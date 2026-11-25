# X16 Video File Format Draft #16

This is a specification for an Video file format for the Commander X16 platform. It is not meant for general use on other platforms . A conversion applications will be provided on those Platforms (Linux/BSD/Windows/Mac) to convert standard file formats such as .mp4 & .avi to the X16 format.

DESIGN GOALS

- A format optimized for the X16 that is easily programmed for

- Takes full advantage of all capabilities of the VERA video hardware.

- Portability for software developed for X16

DETAILED FILE SPECIFICATION* *

(All numeric values are unsigned int, little endian where multi-byte)

| FILE ELEMENT | SIZE IN BYTES | PURPOSE | Comment |
|---|---|---|---|
| File ID<br>(char) | 4 | To identify this file as an X16 Video File | Always “SPRV”<br>$53,$50,$52,$56 |
| VTYPE | 1 | Type of Video Encoding | See Addendum #1 |
| Bit Depth | 1 | What is the color depth of this video ? | 1, 2, 4 or 8<br>(Only 4 & 8bpp are allowed for Sprite Based frame types) |
| FPS | 1 | Frames per Second | Desired Playback rate, if no extensions. For Video files with Embedded Audio this is informational.  Playback FPS is controlled by the Vera PCM rate byte.<br>See Addendum #2 |
| Sprite Width | 1 |  | Sprite Width for Sprite Based Videos |
| Sprite Height | 1 |  | Sprite Height for Sprite Based Videos |
| Frame Width | 2 |  | Frame Resolution Width |
| Frame Height | 2 |  | Frame Resolution Height |
| Number of Frames | 4 |  | Total number of Frames in this Video. (also used with FPS to calculate the VERA Audio rate) |
| SCREEN HINT (Char) | 1 | N – Normal            4:3<br>W – Wide Screen 16:9<br>T – Tall                    9:16<br>K - Tall centered    9:16<br>A - Aspect float in EXTRA<br>P - Amiga video, PAL clock (VTYPE 199 only)<br>(K only used for bitmapped frames) | Not exactly the aspect Ratio. But a Hint as to how to Display the Video.   Covers the most common Aspect Ratios.<br>See Addendum #3<br>A: bytes 1-5 of EXTRA hold the aspect (width/height) as a CBM float. Players that do not know A should treat it like N. |
| Vera Rate | 1 | Control byte to VERA for PCM playback Rate<br>(only significant for types with Interleaved Audio, end user program should calculate this from the sound track size for Types with external audio track. | 1-128 |
| Audio Frame Size | 2 | How many bytes of PCM embedded for each frame (only for types with embedded Audio) | Roughly 512 bytes up to a maximum of 3072 bytes (¾ capacity of the VERA audio FIFO) |
| SPV Extensions Flag | 1 | Flag to identify SPV “extensions”<br>Using Audio Formats other than 8 bit PCM mono. 8 bit stereo working OK, 16 bit formats are currently a bit shaky!<br>Also “fractional frame rates” | Will be the value ‘X’ if<br>Extensions are present<br>(Dec. 88, Hex $58) |
| VERA CONFIG BYTE | 1 | Contains the Bit Pattern for Extended Audio Formats.  Only Valid if the Extended Flag is SET.    Correct Value for Direct OR’ing with the PCM Volume and sta to AUDIO_CTRL on VERA | %00100000 16 bit Mono %00010000  8 bit Stereo<br>%00110000 16 bit Stereo<br>%00000000   8 bit mono<br>If Extensions aren’t set this field is ignored. 8 bit PCM mono is assumed. |
| ENCODED FRAME<br>RATE | 2 | This is an SPV “extended” parameter.  If encoded frame rate is not a whole number this is the encoded frame rate * 100. (fixed point) | Most Significant byte whole number part of FPS<br>Least Significant byte<br>Encoded Frame rate “100ths”<br>If extensions are not set or this field is zero value it is ignored. |
| EXTRA/RESERVED | 7 | Bytes numbered from 0. Byte 0: "X", "J", "W" or 0 (as before). For Amiga videos (VTYPE 199, never hint A) bytes 0-1 are the 16 bit little endian Paula audio period.<br>Bytes 1-5: aspect ratio (width / height) as a 5 byte Commodore (CBM) float, only valid when SCREEN HINT is "A"<br>Byte 6: palette tag (as before) | Unused bytes are zero. Writers set bytes 1-5 only for hint "A". Readers must ignore them for any other hint. |
| VIDEO DATA &<br>AUDIO DATA<br>FOR EMBEDDED<br>FORMATS. | 4gb total file size limit. |  | The Frames or Audio start here. On **STANDARD** Videos.<br>If the Video is meant for SPI play then the header is followed by 480 Pad Bytes to fill One Sector. |

For formats with external audio the data will be :

frame, palette, frame, palette, frame, palette……….

The external file will have the extension .SVA but there is no header data. Default is 8 bit signed, single channel PCM. 8 bit stereo, 16 bit single channel & 16 bit stereo have been introduced as experimental features. Palette data is only as large as it needs to be for the video bit depth.

** 8 bit - Palette is 512 bytes.**

4 bit – Palette is 32 bytes

2 bit – Palette is 8 bytes

1 bit - Palette is 4 bytes

The player software calculates the Audio frame size & the proper VERA playback rate of the PCM audio based on

1.  The size of the audio file & PCM format.
2.  The header FPS field (*byte or extended fps if present*)
3.  The total number of frames in the video.

See **Addendum \#2** for a full description of this calculation.

For formats with embedded audio the data will be:

Audio Frame, frame, palette, Audio Frame, frame, palette………...

If Audio Frame size \< 2049 bytes the first audio frame after the header is doubled in size to allow prefilling of the VERA audio FIFO. If Audio frame size is 2049 bytes or greater then the 1<sup>st</sup> audio frame is identical to all other audio frames. Palette data is the same as for videos with a separate audio file. The Audio frame size and VERA PCM rate is specified *in the Header *and is actually what controls playback FPS. The header FPS field for this format is purely informational in nature.

On the next two pages are Header definitions for the QB64PE, C and prog8 programming languages

QB64PE Type Definition

```
Type SVIDHeaderType
ID As String * 4
VTYPE As _Unsigned _Byte
BPP As _Unsigned _Byte
FPS As _Unsigned _Byte
SpriteWidth As _Unsigned _Byte
SpriteHeight As _Unsigned _Byte
FrameWidth As _Unsigned Integer
FrameHeight As _Unsigned Integer
NumFrames As _Unsigned Long
SHint As String * 1
VeraRATE As _Unsigned _Byte
AudFrmSize As _Unsigned Integer
XAUD_FLAG As String * 1
XAUD_CFGBYTE As _Unsigned _Byte
X_ENCODED_FPS As _Unsigned Integer
EXTRA As String * 7
End Type
```

C struct definition

```
struct SVIDHeaderType {
char ID[4];
uint8_t VTYPE;
uint8_t BPP;
uint8_t FPS;
uint8_t SpriteWidth;
uint8_t SpriteHeight;
uint16_t FrameWidth;
uint16_t FrameHeight;
uint32_t NumFrames;
char SHint[1];
uint8_t VeraRate;
uint16_t AudFrmSize;
char xAudFlag[1];
uint8_t xAudCFGByte;
uint16_t xEncodedFPS
char EXTRA[7];
};
```

Definition in prog8 from the X16 player source code.

(The player uses fixed addresses for reading in the Video Header)

```
VideoHeader {
    &ubyte[4] ID              = $500
    &ubyte    VTYPE           = $504
    &ubyte    BPP             = $505
    &ubyte    FPS             = $506
    &ubyte    SpriteWidth     = $507
    &ubyte    SpriteHeight    = $508
    &uword    FrameWidth      = $509
    &uword    FrameHeight     = $50B
    &uword    NumFramesLO     = $50D
    &uword    NumFramesHI     = $50F
    &ubyte    SHint           = $511
    &ubyte    VERARate        = $512
    &uword    AudioFrameSize  = $513
    &ubyte    XAUD_FLAG       = $515
    &ubyte    XCFG_BYTE       = $516
    &uword    X_F_FPS         = $517
    &ubyte[7] Extra           = $519
    &float    AspectF         = $51A   ; overlaps Extra[1..5], valid for SHint "A"
}
```
