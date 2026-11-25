VIDKIT-A000.BIN is a loadable library running entirely from Banked RAM that supports streaming media playback.

***SUPPORTED FORMATS***

Standard format Sprite & Bitmap SPV videos created by the X16 Movie Maker

High Bandwidth Bitmap SPV videos created by the X16 Movie Maker

(on SD-Card filesystem ONLY !, No HOSTFS)

16 bit PCM signed Microsoft WAV files, mono or stereo.

8 or 16 bit X16 ZCM Audio, mono or stereo.

This is not background interrupt driven play like MooingLemur's ZSMKIT. This happens in the foreground and other process's won't be running ! If a user has ISR's in service other than the system ISR it is recommended they be suspended during streaming play !

X16 Movie Maker Home

https://cx16forum.com/forum/viewtopic.php?t=8226

**VIDKIT** should be loaded at \$A000 in Bank 1 (or higher). It must have

3 consecutive banks available.

After loading Reset to the load bank and do a JSR to \$A000 to save the

Current Screen Mode & Charset and also to load the Trampoline code !

BANK A. Bank where load starts

BANK B. Bank A + 1

BANK C. Bank A + 2

Always **VIDKIT_INIT** at least once first.

And also if user code tromps on \$0400-\$0600 or ZP from \$22-60

Some of these routines take call parameters passed at various ZP addresses. By X16 programming convention the Zero Page from \$02 to \$21 are designated as Psuedo registers for this purpose. Layout is 2 byte word designators starting with **R0 at \$02, R1 at \$04, R3 at \$06…….. R15 at \$20.** Where this document references 24 or 32 bit parameters the **R# **is the starting address of a multi-byte little endian int that extends into the **next R value** ! **RxL** & **RxH** reference the High and Low bytes of each **R** word.

***COLOR LEGENDS ****ON THE VARIABLE MAP ****.***** **

Plain white background, INTERNAL VIDKIT USE ONLY !

Green Background, Safe for developer to write for intended use.

Yellow Background, Should be safe for developer to utilize, but with additional caution.

RED - Might be useful for end developer, but utilize extreme caution when changing !!!!

**

**

**

| MAIN MEDIA API |  |  |  |
|---|---|---|---|
| API NAME | What it does | LIB<br>BANK | Call<br>(jmp table) address |
| VIDKIT_INIT | Initializes library variables & installs a Custom Trampoline at $0400 | A | $A000 |
| VIDKIT_LOAD_AND_PLAY | Loads and then plays a Media File. Filename WITHOUT File extension passed at Ram Bank 0:$BF00 , Null terminated string.  Search order SPV, WAV , ZCM | A | $A003 |
| LOAD_MEDIA_FILE | Loads but does not play a Media File.  Filename WITHOUT File extension passed at Ram Bank 0:$BF00, Null terminated string.  Search order SPV, WAV , ZCM | A | $A006 |
| A Media File must be first LOADED to call the following ! |  |  |  |
| PLAY_MEDIA_FILE | Plays the File loaded by LOAD_MEDIA_FILE | A | $A009 |
| SET_START_FRAME<br>(No effect on PCM Audio) | Sets the Video Frame Number to Start play on. Frame Number passed as a 24 bit int at R0 (24 significant bits ) (SPV Video only, Not for PCM audio files) | A | $A00C |
| SET_END_FRAME<br>(No effect on PCM Audio) | Sets the Video Frame Number to END PLAY On  Pass Frame Number to this routine as a 24 bit Integer at R3 (SPV Video only, Not for PCM audio files) | A | $A00F |
| SET_FRAME_RANGE<br>(No effect on PCM Audio) | Essentially calls SET_END_FRAME and SET_START_FRAME as 1 call<br>Start Frame at R0, End Frame at R3<br>(SPV Video only, Not for PCM audio files) | A | $A012 |
| SET_STARTTIME<br>(For PCM Files this call SET_STARTTIME_JIFFIES, for SPV Videos is resolves to a Frame seek) | Time to Start play at in whole seconds at r5 (16 bit unsigned int, start of file is time 0)<br>(For SPV and PCM audio files, but SET_STARTTIME_JIFFIES is recommended for PCM only files) | A | $A015 |
| SET_ENDTIME<br>(No effect on PCM Audio) | Time to end play at in Seconds at r6 (16 bit unsigned int, start of file is time 0) (SPV Video only, Not for PCM audio files) | A | $A018 |
| SET_TIMERANGE<br>(No effect on PCM Audio) | Calls STARTTIME & ENDTIME<br>Start time at r5, endtime at r6<br>(SPV Video only, Not for PCM audio files) | A | $A01B |
| CLOSE_MEDIA | Closes out the Media opened by<br>LOAD_MEDIA .  Use if KEEP_OPEN is also used before loading another Media file | A | $A01E |
| PLAY_TO_TIMER<br>(For PCM Audio Streaming this is<br>the only API to end play prior to EOF of the Audio File !) | Sets an End Timer and then Plays the currently loaded Media from the Current Position for number of jiffies passed as a 32 bit int in r4-r5.<br>On an SPV Video the END FRAME will take precedence if encountered before the Timer expires (including if set by SET_END_TIMER or SET_END_FRAME).<br>For PCM Audio EOF will take precedence over Timer. | A | $A033 |
| SET_STARTTIME_JIFFIES<br>(DO NOT USE ON SPV VIDEO, PCM AUDIO ONLY !) | Sets Play start time of Loaded PCM AUDIO ONLY (not for SPV) at Jiffie precision. Jiffie position passed as a 32 bit Integer at r4-r5.  Start of file is 0 time. | A | $A036 |

| SET_KEYEXTRA | Adds one addition exit Key code. This will be returned as the value of MANEXIT | A | $A03F |
|---|---|---|---|
| CLEAR_KEYEXTRA | Clears a KEY_EXTRA code set by SET_KEYEXTRA . | A | $A042 |

**IMPORTANT NOTE ON SEEK AND TIME PLAY API’s:** All of the api’s that seek and do time ranges have MINIMAL error checking. The developer should do his utmost to ensure that values passed to these routines are valid for the loaded Media file. If out of range values are passed the behavior may be unpredictable.

CONTROL VARIABLES MODIFY BEHAVIOR ACCORDING TO VARIABLE VALUE

DISABLE Automatic Screen restore after Video play. By storing a value of \$01 at \$043A

If the developer does this he assumes ALL responsibility for VERA state when Video play returns (including

Hiding of Sprites !)

RESTORE Automatic Screen restore after Video play by storing a \$00 value at \$043A. The behaviour of **RESTORE_SCREEN** is further modified by **PAL_RESET** ***(\$0464) **(**PAL_RESET** is **True** at INIT)*

DISABLE Video Key Controls by storing a value of \$01 at ZP \$33 before Video Play

(Volume remains enabled)

RESTORE Video Key Controls by storing a value of \$00 at ZP \$33 before Video Play

\$043A is set to 0 on INIT

\$33 is set to 0 on INIT

| GENERAL UTILITY ROUTINES |  |  |  |
|---|---|---|---|
| ROUTINE NAME | RAM BANK<br>FOR CALL | CALL ADDRESS |  |
| HideBothLayers<br>(Turns off Visibility of Layer 0 & Layer 1) | A | $A021 |  |
| HideTextLayer (Turns off Visibility of Layer 1) | A | $A024 |  |
| HideGraphicsLayer (Turns off Visibility of Layer 0) | A | $A027 |  |
| ShowBothLayers<br>(Turns ON Visibility of Layer 0 & Layer 1) | A | $A02A |  |
| ShowTextLayer (Turns ON Visibility of Layer 1) | A | $A02D |  |
| ShowGraphicsLayer (Turns ON Visibility of Layer 0) | A | $A030 |  |
| SET_VERA_VIDEOMODE<br>(Sets Full Screen Mode for the current Video Load, see Screen<br>Management topic) | A | $A039 |  |
| SETUP_SPRITEGRID<br>(Sets up Sprite positions in a grid for Sprite Based Videos,<br>does not set full screen, Xorg, Yorg passed at R7, R8 -<br>see Screen Management topic) | B | $AA0C |  |
| ClearALL 3 of the Below BUFFERs with one<br>API Call. | B | $A003 |  |
|  | ClearGraphicsBuffer<br>Clears (0 fills)<br>VRAM<br>0:0000 – 1:2BFF | B | $A015 |
|  | ClearTextBuffer<br>Clears (0 fills)<br>VRAM<br>1:B000 – 1:EBFF | B | $A018 |
|  | ClearSpriteData<br>Clears (0 fills)<br>VRAM<br>1:3000 – 1:AFFF | B | $A01B |
| HideSprites (Hides sprites 1-127 via Z-order, does not<br>effect Sprite Layer bit) | B | $A024 |  |
| SetDefaultPalette<br>(sets the VERA default Palette instantly, not a<br>fade.)<br>(Adjusts for differences between ROM versions r48 and<br>r49 or greater !) | B | $A02A |  |
| Fade2Black<br>(smooth fade to black. Slightly longer than ¼ second) | B | $A039 |  |
| Pal2Black<br>(VERA Palette to all black, instant, not a fade !) | B | $A03C |  |
| FadeToPal<br>Fades the current VERA Palette to another,<br>using a memory pointer passed at R11 as the<br>source of the palette data. | C | $B412 |  |
| FadeInDefPal<br>Fades in from current Palette to the VERA<br>default palette. | C | $B415 |  |
| DISK_FASTMODE<br>Sets fast read/write mode on SD-Card file<br>system. No effect on Emulator HOSTFS . | B | $A036 |  |
| Fade2Color<br>Fades the current palette all to one Word Value<br>passed at R1 in the Following form $0RGB with<br>a 12 bit color value, each color component is 4<br>bits. The high nibble is not significant. | C | $B418 |  |
| RestoreScreen<br>(Restores CX16 screen mode and charset that is stored at<br>VIDKIT_INIT. ) If RESET_PAL is TRUE then the default palette<br>is also restored. If RESET_PAL is false the palette will not be affected.<br>This is called automatically when play finishes<br>unless DISABLE_RESTORE is TRUE .<br>NOT SAFE TO CALL BEFORE VIDKIT_INIT | B | $AA15 |  |
| ADDITIONAL NOTES: If DISABLE_RESTORE is not set to true then RestoreScreen is called every time a Video ends play.  If the developer use’s DISABLE_RESTORE then you may call RestoreScreen yourself to restore what was set at VIDKIT_INIT , or you may fully manage what the VERA is doing in your own code. RestoreScreen is not required to be called.  If you have the palette blacked when calling RestoreScreen and RESET_PAL is false then you must call SetDefaultPalette yourself or else load your own palette !  Restore screen does restore screen scaling and charset.<br>Charset is especially important for HIGH Res Videos as they may overwrite the resident font for their frame buffer ! |  |  |  |
| FixupISOCursor<br>(turns the character used by ISO font mode as the cursor to a thick (2 pix) underscore. )<br>This is done directly and does not use the ROM EXTAPI set cursor ! | C | $A024 |  |

Following is a detailed Memory Map of VIDKIT’s variable usage in Zero Page and Golden Ram.

A lot of this is technical stuff that’s not strictly needed to use the Library. It is necessary that

you calling code does not use **ZP from \$22 to \$4F. Golden Ram** from **\$0400 to \$054D** is also reserved for **VIDKIT** !

**ALSO**, **Logical File \#6, Secondary address \#6** is used for Standard **Video streaming**, **Logical File \#4**, **Secondary Address \#4** is used for **PCM only playback**. **BOTH** of these are used for a Standard Video with Audio in a separate SVA file. If and only if ***loading a Palette*** for a sprite video from a separate file ***Logical File*** ***\#7, Secondary Address \#7*** is used. This is only open once for the whole Video playback.

| ZERO PAGE RAM ALLOCATION<br>( bool Values are 1 if True, 0 if False ) |  |  |
|---|---|---|
| ADDRESS | CODE NAME | PURPOSE |
| Old - $22 (VIDKIT 1.0)<br>Current - $55 | VERA_RATEBYTE | Playback Sample Rate VERA<br>value. Used to reload after pause |
| Old - $23 (VIDKIT 1.0)<br>Current - $55 | VERA_CFG_BYTE | VERA Config for PCM format<br>(see VERA docs) |
| $24 - $26 | VERA Address for Palette Cache | Used during Play ! |
| $27 | DO_BUFFER_AUDIO | Is there an “extra” audio frame to read ?<br>(Set to 1 only at beginning of Video play if Audio Frame Size < 2049 bytes) |
| $28 | G_WIDTH | Width (byte) for bitmap mode |
| $29 - $2B | Various | Values to manage Palette target<br>location for 1, 2 & 4bpp videos (they are alternated between palette rows 14 & 15 every other frame during play !) |
| $2C | LOOPS_255 | For STD Videos how many bytes to<br>read for a frame in a multiple of<br>255. |
| $2D | BYTES_REM | How many bytes left to read after<br>calling MACPTR the number of<br>times at $2C |
| $2E | page_flag | Tracks the current Visible “page”<br>(alternates every other frame) |
| $2F - $31 | Loop counters | GP loop counters used during<br>Streaming playback ! |
| $32 | PlayDone | This is the control value to end<br>play. Set to $FF to end, 0<br>otherwise. Frame checker will set it when CURRENT_FRAME = TARGET_FRAME and it is also set by the standard Key Controller when ESC is pressed. |
| $33 | LOCK_KEYS | Set to 1 to disable the standard Key<br>Controller (except Volume) before<br>playback.   0 is default |
| $34 - $36 | FRAME_CURRENT | Current Video Frame Number<br>24 bit unsigned int (Updated each frame during play) |
| $37 - $39 | FRAME_TARGET | Frame Number to End Play On<br>24 bit unsigned int |
| Above this line is used across the library.  Below is only used for Direct SPI High Bandwidth videos. |  |  |
| $3A - $3B | FREE FOR USE | NOT USED |
| $3C | AUD_SECTOR_ADDER | Number to add to current Audio<br>frame sector to reach the next Audio Frame<br>sector |
| $3D | VID_SECTOR_ADDER | Number to add to current Video frame<br>sector to reach the next video frame sector. |
| $3E - $41 | VID_SECTOR_CURRENT | Current Video sector address 32 bit unsigned int |
| $42 - $45 | AUD_SECTOR_START | Audio data start sector Address<br>32 bit unsigned Int |
| $46 - $49 | AUD_SECTOR_CURRENT | Current Audio Frame Sector Address |
| $4A - $4D | VID_SECTOR_START | Starting Sector Address of Video<br>Frame Data (Frame 0) |
| $4E | AUD_FRAME_NUMSECTORS | Size of Audio Frame in Sectors (Each Sector is 512 bytes) . True audio frame size |
| $4F | VID_FRAME_NUMSECTORS | Size of Video Frame in Sectors (Each Sector is 512 bytes) . May include byte padding for alignment ! |

***MEDIA HEADER STORAGE VARIABLES ***

SPV File Header is always loaded at \$500. See SPV file format documentation for full description.

Prog8 variable definition for SPV Header

VideoHeader {

&ubyte\[4\] ID = \$500

&ubyte VTYPE = \$504

&ubyte BPP = \$505

&ubyte FPS = \$506

&ubyte SpriteWidth = \$507

&ubyte SpriteHeight = \$508

&uword FrameWidth = \$509

&uword FrameHeight = \$50B

&uword NumFramesLO = \$50D

&uword NumFramesHI = \$50F

&ubyte SHint = \$511

&ubyte VERARate = \$512

&uword AudioFrameSize = \$513

&ubyte XAUD_FLAG = \$515

&ubyte XCFG_BYTE = \$516

&uword X_F_FPS = \$517

&ubyte\[7\] Extra = \$519

&float AspectF = \$51A ; overlays Extra\[1..5\], valid for SHint “A”

}

** Last** Header byte is **\$51F**.

The Current setting of **PCM Volume** level (low nibble of VERA_CFG) is stored at **\$520 **

** **This value is checked at INIT and if it outside 1 to 15 then it is set to 10. It is not

updated during play. When a play sequence end it is updated from the VERA value

If the default Key controller is not replaced then Volume Control with up/down arrow keys

always remains active even when other key controls are deactivated.

Between Media streaming plays ! If this value is \< 1 or \>15 then the play routine automatically set it to 12 ! ( 0 is valid during play but not as a saved value ! \>15 is not valid at all !)

If an Audio PCM file is loaded for streaming it’s Header is loaded at \$522 Variables will vary depending on PCM format. WAVHeader is fully defined

by the Microsoft WAV/RIFF format and is 44 bytes in size.

Prog8 variable definition for Microsoft WAV Header

WAVHeader {

&ubyte\[4\] RIFFID = \$522

&uword WAVDATASIZExL = \$526

&uword WAVDATASIZExH = \$528

&ubyte\[4\] WAVID = \$52A

&ubyte\[4\] SUBCHKID1 = \$52E

&uword SUBCHK1SIZExL = \$532

&uword SUBCHK1SIZExH = \$534

&uword AUDIO_FORMAT = \$536

&uword AUDIO_CHANNELS = \$538

&uword SAMPLE_RATExL = \$53A

&uword SAMPLE_RATExH = \$53C

&uword BYTE_RATExL = \$53E

&uword BYTE_RATExH = \$540

&uword BLOCK_ALIGN = \$542

&uword SAMPLE_BITS = \$544

&ubyte\[4\] SUBCHKID2 = \$546

&uword SUBCHK2SIZExL = \$54A

&uword SUBCHK2SIZExH = \$54C

}

If the Audio File is an X16 ZCM file then it will have the following header format. Standard ZCM originally defined by Zerobyte and is identical to the ZCM format supported in ZSOUND & ZSMKIT. This format has a 24 bit unsigned file size and an X16 load header as well as a suggested memory bank value.

A HUGE ZCM was defined by me for streaming only. The X16 load header is replaced by the static value \$FFFF and The banknum & 24 bit filesize are combined into a 32 bit file size. Both formats have a VERA Config byte indicating PCM format & VERA Rate Byte indicating PCM sample rate. These are at identical offsets in both Header formats !

***Mixed ****Prog8 variable definition for ****both standard & Huge ZCM Header***

ZCMHeader {

&uword lptr = \$522 ; \$FFFF identify's HUGE ZCM

&ubyte banknum = \$524 ; for standard ZCM

&uword SizeLow32 = \$524 ; for HUGE ZCM

&ubyte SizeLow24 = \$525 ; for standard ZCM

&uword SizeHigh = \$526 ; Multiply by 256 for Standard ZCM, Multiply by 65536 for HUGE ZCM

&ubyte ZCFG_BYTE = \$528 ; LOW Nibble of ZCFG_BYTE is requested VOLUME and is masked out/ignored by this code

&ubyte ZRATE_BYTE = \$529 ; This and ZCFG are copied directly to the VERA PCM control registers (sans the Volume nibble)

| Golden Ram Memory Map ( bool Values are 1 if True, 0 if False ) |  |  |
|---|---|---|
| VARIABLE ADDRESS | SOURCE CODE NAME | PURPOSE |
| $0400 - $041C<br>($040F – uword Tramp<br>Target)<br>($041B – Bank to switch to) | Trampoline | JSRFAR substitute for Ram Bank<br>cross calls |
| $041E-$041F (unsigned word) | ORG_ISR | Saved State of CINV at INIT. |
| $0421 (prog8 bool) | LOOP_ON | Not implemented, True for looped video play. LOOP_FLAG is used in the provided play apps for loop play. |
| $0422 (prog8 bool) | IS_VIDEO | True if the opened Media is a Video file. |
| $0423 (prog8 bool) | IS_BITMAP_VIDEO | True if the opened Media has Bitmap based frames. |
| $0424 (prog8 bool) | IS_SPRITE_VIDEO | True if the opened Media has Sprite<br>based frames. |
| $0425 (prog8 bool) | IS_SUPPORTED_VIDEO | True if the opened Media is<br>supported by VIDKIT |
| $0426 (prog8 bool) | IS_STD_VIDEO | True if opened Video is a low<br>bandwidth vid, read in via CBM file<br>system calls (MACPTR) |
| $0427 (prog8 bool) | IS_SPI_VIDEO | True if opened Video is a high<br>bandwidth vid, read in via direct SPI<br>access of the SD-Card** |
| $0428 (prog8 bool) | AUDIO_TRACK_IN_SEPERATEFILE | True if the sound track for this Video<br>is stored in a seperate SVA file. |
| $0429 (prog8 bool) | MAKE_WIDE_SCREEN | True for 16:9 aspect Video |
| $042A (prog8 bool) | IS_TALL_VIDEO | True for 9:16 SPRITE Videos |
| $042B (prog8 bool) | K_TYPE | True for a bitmap based Video with a 270 pixel wide visual centered in a 320 wide frame with 25 pixel wide vertical black borders. Source is 9:16 aspect. |
| $042C (prog8 bool) | VID_HAS_PALETTE | True if Video has embedded dynamic palette data per frame. Usually true but Movie maker also allows an external fixed palette for sprite based videos. |
| $042D (prog8 bool) | IS_PCM_ONLY | True if the opened media is a ZCM<br>file or a WAV file |
| $042E (prog8 bool) | IS_Z_FILE | True if the opened media is an X16<br>ZCM file. |
| $042F (prog8 bool) | IS_WAV_FILE | True if the opened media is a WAV<br>file.<br>(only 16 bit signed  PCM format is<br>supported for WAV’s) |
| $0430 (prog8 bool) | PCM_IS_STEREO | Used for Video sound tracks & PCM<br>files.<br>True if the PCM track is stereo |
| $0431 (prog8 bool) | PCM_IS_16BIT | Used for Video sound tracks & PCM files. True if the PCM track is 16 bit. ALWAYS TRUE for supported WAV files. |
| $0432 - $0434 (3 x  bool) | VID_FILE_FOUND<br>PCM_FILE_FOUND<br>PAL_FILE_FOUND | Booleans used internally while locating supported media. |
| $0435 (prog8 bool) | READY_TO_PLAY | True when loaded Media file is ready to start play. |
| $0436 (prog8 bool) | LOOP_FLAG | True when F5 has been pressed in the built in Key controller.  This has no other effect but is used by the Movie Maker player programs to enable looped playback. |
| $0437 (prog8 bool) | success | Used internally to indicate true<br>when certain steps succeed ! |
| $0438 (unsigned byte value) | SCR_SAVEMODE | When VIDKIT INIT is called the<br>current X16 Screen mode is saved<br>here. |
| $0439 (unsigned byte value) | CHARSET_SAVE | Saves the current loaded X16<br>charset number and mode. (PETSCII/ISO/cp437…) when VIDKIT INIT is called. |
| $043A (prog8 bool)<br>DEFAULT: FALSE ULT: TRUE | DISABLE_RESTORE | Default set to false on VIDKIT INIT. If the developer sets this to true then the VERA screen is not restored when a Video ends play. When false the screen mode/charset at $438-$439 are set after a video ends play ! |
| $043B (unsigned byte value) | VERAcfgvar | Stores the VERA Config value (PCM<br>format) for the current Audio stream. |
| $043C (unsigned byte value) | drivenumber/devicenumber | The CBM I/O device used<br>internally, set to 8 by VIDKIT<br>INIT.  VIDKIT has not been tested with other devices than the VERA SD-Card reader 1 |
| $043D - $0441 (cbm Float) | F_FPS | Video encoded Frames Per Second |
| $0442 - $0446 (cbm Float) | TRUE_FPS | What playback FPS actually is<br>accounts for 380hz step precision |
| $0447 - $044B (cbm Float) | Frame | Set to same value as FRAME_CURRENT when Video play ends. NOT updated during play. The 24 bit INT at ZP $34 FRAME_CURRENT is updated during play !  Frame is used for internal calculations ! |
| $044C - $0450 (cbm Float) | BFrame | Used in internal calculations. Also used for Bookmarked Frame Value in the players that do bookmarking ! |
| $0451 - $0455 (cbm Float) | VFRAME_MUL | Factor used to Multiply Frame Number by to get File byte position when seeking. |
| $0456 - $045A (cbm Float) | AUDIOFRAME_MUL | Factor used for seeking on SVA files when a Video has a separate Audio track file. |
| $045B - $045F (cbm Float) | VIDEOFILE_LEAD | Added to the MUL Value when file seeking to skip Header and Audio pre-buffer (if present) |
| $0460 - $0463 (32 bit uint) | RESET_FRAME | Stored Frame Number (Number of Frames – 5).  Used to reset Video back to Frame 0 if passed when a Video Exits and KEEP_OPEN is true ! |
| $0464 (prog8 bool) | PAL_RESET | If TRUE then RESTORE_SCREEN will reset the VERA Default Palette !, If FALSE . Then the Palette is not reset ! (must be done in user code) |
| $0465 (unsigned byte) | MANEXIT<br>(manual exit) | Is set to $FF by the built in Key Controller when Video is exited with ESC. Returns KEY_EXTRA value if exiting with KEY_EXTRA or 0 when terminating at media end. |
| $0466 (prog8 bool)<br>DEFAULT: FALSE | KEEP_OPEN | False by default. When set to True the current loaded Video is kept open after play terminates. Default behavior is to close Media after each play. |
| $0467, $0468 (prog8 bools) | NO_SCREENCHANGE<br>SCREEN_IS_SET<br>(These work together !)<br>These are Overridden by the<br>MANAGE_SCREEN boolean<br>value.  If MANAGE_SCREEN is false then the library NEVER automatically changes mode. It must be commanded explicitly by user code. | Default is False . If developer sets NO_SCREENCHANGE to True then Video Playback will set screen mode on FIRST call to play only. (SCREEN_IS_SET now True) . After that subsequent calls to Play WILL NOT set screen mode.  Program should only play Videos using the same screen mode and NOT reset VERA itself during this condition !. |
| $0469 (uint 32 bit) | AUD_LEAD_START | SPV Videos with an Audio Frame Size smaller than 2049 bytes have one extra Audio Frame to buffer when starting from the beginning. If this is true for an Open SPI Video then this location holds the Sector Address of that extra Audio Frame ! Otherwise this is unused ! |
| $046D - $0471 (cbm Float) | tmpf | Used by VIDKIT Internally |
| $0472 - $0476 (cbm Float) | tmpf2 | Used by VIDKIT Internally |
| $0477 - $047B (cbm Float) | vk_FAC | Used by VIDKIT Internally |
| $047C - $0480 (cbm Float) | PCM_BYTEsPerSecond | Bytes Per Second of a PCM Stream. This is identical to the PCM Sample rate for 8 bit Mono but twice that for Stereo & twice that again for 16 bit. (Byte Rate for 16 bit stereo is 4x Sample Rate) |
| $0481 - $0485 (cbm Float) | Video_START_Sector | For SPI Videos, Sector address on the SD-Card where the Video data begins. |
| $0486 - $048A (cbm Float) | Audio_START_Sector | For SPI Videos, Sector address on the SD-Card where the Audio data begins.  (after the initial audio lead !) |
| $048B - $048F (cbm Float) | AudFilePosition | Used internally when seeking on<br>PCM audio stream. |
| $0490 (unsigned byte) | SAVE_DC_VIDEO | Saves the VERA_DC_VIDEO Value that is set prior to VIDKIT_INIT |
| $0491 (prog8 bool) | PCM_EOF | For PCM Audio Files set at End of file to indicate necessary reset. |
| $0492-$0493 (unsigned word) | DefPAL_PTR | ROM Address of the Default VERA<br>Palette Data (filled in at INIT) |
| $0494 (unsigned byte) | PalBank | The ROM bank number where the<br>default Palette Data is located. |
| $0495 (unsigned byte) | HighRAMBank | Bank Number of the Highest Bank<br>Available, Used for Scratch Data !. |
| $0496 (prog8 bool)<br>DEFAULT: TRUE | MANAGE_SCREEN | If MANAGE_SCREEN is True then<br>The Proper VERA Mode, Graphics<br>layer and sprites if necessary are set<br>for Video playback. If False ,<br>Developer has to do it themselves 1 |
| $0497 - $049C | HB sprite layout | Used by the high bandwidth sprite engine (see source). |
| $049D (prog8 bool) | HAS_ASPECT | VIDKIT 2.0. True when the open video has SHint “A”: the display aspect (width / height) is a 5 byte CBM float at $051A (VideoHeader.AspectF, overlaying Extra[1..5]). The screen is then set up as an aspect window; see Addendum #3 of the SPV format specification. Set when the video is opened, cleared by CLOSE_MEDIA. Bitmap videos only, ignored for sprite videos. |
| $049E - $04FF | FREE | UNUSED. |
| $0500 - $051F | SPV (video) file Header | See prog8 code def and SPV<br>format document with X16 Movie<br>Maker |
| $0520 (unsigned byte) | Volume<br>Saved PCM Volume | Can be set before Play !<br>Valid values are 0 to 15 only ! |
| $0522 - $054D | Microsoft WAV file Header.<br>Also shared area for ZCM<br>file Header. | See prog8 code def, Also Microsoft<br>WAV/RIFF format is well<br>documented elsewhere ! |

***COLOR LEGENDS.***** **

Plain white background, INTERNAL VIDKIT USE ONLY !

Green Background, Safe for developer to write for intended use.

Yellow Background, Should be safe for developer to utilize, but with additional caution.

RED - Might be useful for end developer, but utilize extreme caution when changing !!!!

VIDKIT is open source, and these are recommendations only ! If a developer wish’s to accomplish something

that isn’t included in the library they are of course free to go over the source and change any of the above values that makes sense to them. This is at a developers own risk, and while I will help if I can, I’m not responsible for

*unintended side effects !*

ADVANCED API ADDENDUM

IT IS EXPECTED THAT THE ABOVE API CALLS WILL COVER \> 90% OF THE USE CASE’s for VIDKIT. HOWEVER IN THE INTEREST’S OF FLEXIBILITY SOME MORE ADVANCED API’s ALSO EXIST !

THIS ADDENDUM COVERS HOOKING THE LIBRARY WITH CALLBACKS TO YOUR OWN CODE.

AS WELL AS A MORE TECHNICAL EXPLANATION OF THE SET TIME AND FRAME RANGE API’s

**

** *****TOPIC ****A***

**

***Screen transitions and Screen Management***

Screen to screen transitions in a program are one of the finishing touch’s that can really give an application a

professional look, but they can be a bit jarring & distracting if not done correctly. Two common approach’s are

to set the palette to a solid color ***(typically black) ***so that what is drawn on the screen is not visible. When drawing

is complete then the palette is either faded in gradually or changed immediately to reveal the drawn screen. The

other approach is to Hide an entire layer when drawing, Then showing the layer to reveal the screen.

**VIDKIT** has a number of support/utility routines that are there mainly to help with both of these processes.

There are also a number of control variables which modify **VIDKIT** behavior when set to certain values.

The library stores the current ROM screen mode and character set when **INIT** is called. *(**INIT** may be called more*

than once.)

* *The **default behavior** when playing a video is for the Video full screen mode to be set for playback

and when the video is done playing **RESTORE_SCREEN** is called which returns the ROM screen mode and

charset. If your are using a custom tile set or VERA mode then that part needs to be restored in your own code.

This default behavior can be modified with several control variables and combinations of control variables.

The routines in the library that do the mode setting can be called explicitly by the developer to manage exactly

how their application behaves during Video transitions.

**DISABLE_RESTORE*****(\$043A)*** = **False on INIT.** If set to **True** then **VIDKIT** will still set full screen mode

for video playback, but **RESTORE_SCREEN will not** be called on exit.

**NO_SCREENCHANGE*****(\$0467)*** = **False on INIT.** If set to **True** then **VIDKIT** will only set the Screen mode

for the ***...First...***video played back. Also disables **SCREEN_RESTORE**.

This is for use when ALL your videos are the same format ! May cause

odd or corrupted screen format otherwise. **NO_SCREENCHANGE** works

together with **SCREEN_IS_SET*****(\$0468). ***After the first video playback

**SCREEN_IS_SET** will be **True**. *(Set to **False** to enable Screen mode*

 * setting on the next playback call !)*

** MANAGE_SCREEN*****(\$04****96****)*** = **True on INIT.**  * *Use ***...Caution !...*** with changing this. When set to **False**

**NO** automatic setting of screen modes will occur on Video entry or exit.

**Developer assumes FULL RESPONSIBILITY** for setting necessary VERA

state !. ***(routines are exposed in the library to help with this)***

**

**

**

*If the developer chooses to disable automatic mode setting, they may use** *****SET_VERA_SCREENMODE, SETUP_SPRITEGRID***** & *****RESTORE SCREEN***** with manual calls ! (see API chart). **Once a full understanding of the SPV format is achieved it is possible to bypass these and also set necessary VERA parameters manually. By combining these routines with the palette manipulation/fade routines and Layer On/Off routines it should be possible to achieve a smooth professional looking screen transition in all cases !** ***

**

**

**

**

**

**

**

***TOPIC ****B***

***Play Engine Flow when any Play Media call ***

Check **LOCK_KEYS**.

If 1 then **gate** Pause and Exit functions in **KeyController2**

If 0 then **Ungate** them (happens every call !)

***(Volume Control Always remains enabled in KeyController2)***

Reset the PCM_FIFO (VERA Rate 0 here !)

Check **DO_BUFFER_AUDIO**

If 1 then read an Audio Frame into the FIFO

If 0 skip this.

Read in an Audio Frame to the FIFO

instantiate **page_flag** and **PlayDone** to 0

Read in a Video Frame

Start Playing the AUDIO (sta VERA_RATE)

**LOOP POINT IS HERE**

Check **PlayDone** if not 0 branch to END

Wait for AFLOW bit

**Read in an Audio Frame**

**Read in a Video Frame and Flip page** and **pageflag**

***(pageflag is a flip flop for odd/even frames)***

Increment **CURRENT_FRAME** & Check equality against **FRAME_TARGET**

***(When Streaming PCM Audio only. This code is modified to check EOF (READST))***

instead. **CURRENT_FRAME** not applicable !

**PlayDone** set to true if equal ***(MANEXIT remains 0)***

Call **KeyController1** ***(default is kbdbuf_peek)***

if Not 0 (bne) then Call **KeyController2**

The Default **KeyController2** ***(processKeys in the source)***

is where Volume Control, Pause, Exit and **LOOP_FLAG** is

implemented.

**KEY_EXTRA **– Sets **PlayDone** to \$FF and **MANEXIT** to **KEY_EXTRA**

ESC sets **PlayDone** to \$FF, and also **MANEXIT** to \$FF

UP/DOWN Arrow – Volume Up/Down

SPACE BAR.  - Enters a Pause Loop ***(VERA PCM is also paused !)***

***Pause loop***

infinite GETIN until SpaceBar is pressed again.

***(sta VERA_RATE to restart PCM on exit)***

F5 – Sets **LOOP_FLAG** to true but that’s for exit code to read

it doesn’t otherwise effect ENGINE Code.

**LOOP**

END

There are two entirely separate library sections for SPI and STD Video file play. PCM Only play is always done in the STD ENGINE code. There are enough specific differences to justify putting them in separate Code Banks.

In the **STD Engine Bank** ***ALL the above*** Color Highlighted Code points are exposed to change the Call target !

In the **SPI Engine Bank **only changing the **KeyController1 & KeyController2** hook points is supported.

In most cases it will probably suffice to just hook **KeyController1**. **KeyController2** is only called by the main loop is the **Zero flag is clear** when **KeyController1** returns. The normal **KeyController1** is **kbdbuf_peek** from the Kernal and the Zero flag is clear if there is a Key stroke waiting in the Keyboard buffer.

The Default Key Controllers are reset each time a **LOAD_MEDIA_FILE** or a **LOAD_AND_PLAY** are called.

You need to do your Hook after each **LOAD_MEDIA_FILE** call ***(if you are using more than one Streaming Media file in your application)***

***TOPIC ****C***

**

THIS SECTION IS AN IN DEPTH EXPLANATION FOR WRITING AND INSTALLING YOUR OWN KEY CONTROLLERS ! KEY CONTROLLERS DO NOT NECESSARILY NEED TO RELY ON KEYBOARD INPUT !

**BY DEFAULT:**

**KeyController1** is a call to ROM **kbdbuf_peek** (\$FEBD)

**KeyController2** is a call to internal library routine **ProcessKeys. ** This routine implements the following

functionality. Keys are read from the Keyboard Buffer with ROM GETIN !

** SpaceBar**, pause / unpauses play. ***(ProcessKeys ****does**** not return during Pause, ****it returns AFTER****)***

**ESC** – Sets the ZP Variable **Playdone** to \$FF & Golden Variable **MANEXIT** to \$FF

(**Playdone** is the signal to stop playing, it will also be set at EOF (PCM or LastFrame)

**Up/Down** arrows - PCM Volume increase/decrease.

In addition if a **KEY_EXTRA** is set. **KEY_EXTRA** will exit and set **MANEXIT** to **KEY_EXTRA** !

TO HOOK THESE ROUTINES AFTER CALLING LOAD_MEDIA_FILE

To Install your routine for both SPI & STD Videos if you don’t know the SRC type.

In VIDKIT ***Bank B*** - **HookControls** → **jsr \$AA1B **

An address for KeyController1 at R7, address for KeyController2 at R8

In VIDKIT ***Bank B*** - **HookControl1** → **jsr \$AA1E **

An address for KeyController1 at R7

In VIDKIT ***Bank B*** - **HookControl2** → **jsr \$AA21 **

An address for KeyController2 at R8

To Install your routine for STD Videos and PCM Only **(will not effect SPI vids)**.

Parameters also passed at R7 for KeyControl1 address, R8 for KeyControl2

In VIDKIT ***Bank B*** - **HookControls** → **jsr \$A03F **

An address for KeyController1 at R7, address for KeyController2 at R8

In VIDKIT ***Bank B*** - **HookControl1** → **jsr \$A042 **

An address for KeyController1 at R7

In VIDKIT ***Bank B*** - **HookControl2** → **jsr \$A045 **

An address for KeyController2 at R8

To Install your routine for SPI Videos Only **(will not effect STD vids and PCM Audio)**.

Parameters also passed at R7 for KeyControl1 address, R8 for KeyControl2

In VIDKIT ***Bank ****C*** - **HookControls** → **jsr \$A027 **

An address for KeyController1 at R7, address for KeyController2 at R8

In VIDKIT ***Bank ****C*** - **HookControl1** → **jsr \$A02A **

An address for KeyController1 at R7

In VIDKIT ***Bank ****C*** - **HookControl2** → **jsr \$A02D **

An address for KeyController2 at R8

TO RESET KEY CONTROLLERS TO DEFAULT

They are always RESET to Default on **LOAD_MEDIA_FILE** & **LOAD_AND_PLAY_MEDIA**

** *****To RESET to Default without a new LOAD ****(No parameters) ***** **

** BOTH SPI, STD & PCM – **VIDKIT ***Bank B*** – **jsr \$AA24**

** STD Vids & PCM Only -- **VIDKIT** *****Bank B***** – jsr \$A048**

** SPI Vids Only -- **VIDKIT** *****Bank ****C***** – jsr \$A030**

GUIDELINES FOR WRITING A KEY CONTROLLER

If you hook these routines your routine entry point must be somewhere in Low Ram from \$0200 - \$BFFC. Write your routine to return as quickly as possible. **KeyController1** is called EVERY FRAME of a Video and is expected to return quickly, **KeyController2** is only called if **KeyController1** returns with the Z flag clear. If your **KeyControllers **depend on key press’s then the easiest way to implement this is for your **KeyController1 **to just end with a **jmp** to **kbdbuf_peek**.

***NOTE FOR ZCM & WAV Audio only streaming:**** Your KeyController1 should first call READST (\$FFB7). It should then sta PCM_EOF ****(****\$491*****)***** if .A is non zero your routine should also set PlayDone (\$3****2****) to value ****\$FF****. This IS NOT NECESSARY for SPV Video streaming. There end play is determined by counting frames ! ****You may also always set PlayDone to 1 based on your own requirements.***

**

Do stuff as quickly as possible and **rts** if not pausing play !

If changing any Bank registers, ensure they are restored before **rts**.

If changing any VERA registers it is recommended and/or required to

restore values before **rts**.

To end Media Play – Store a 1 to **PlayDone** before rts (zp \$32)

To pause play - Store a Zero to VERA_RATE (\$9F3C), you now have room to breath. There will

be a pause in Audio in your app, Before you **rts **retrieve the Value of VERA RATE from

VERA_RATEBYTE (at ZP \$22) and store it to VERA_RATE (\$9F3C) immediately before rts.

***(You may want to change this value, It will speed up or slow down playback (within reason))***

**

Hooking the Key Controllers is NOT 100% compatible with **PLAY_TO_TIMER** as that does its own Hook to KeyController1 !

** (***If you’ve hooked both routines then during **PLAY_TO_TIMER** your KeyController2 *

will be called if the user press’s a Key but your KeyController1 will be taken out of

* the loop and will need to be restored after **PLAY_TO_TIMER**.* **)**

***TOPIC ****D***

***INSTALLABLE ****USER ****FRAME DRIVER FOR STD ENGINE***

Both the Standard and the SPI Video engine’s operate on something of a Frame Driver Model. A different Frame Reader address is inserted into the video core call depending on what parameters are set in the loaded Media File. Each frame reader in each respective Engine is optimized to particular video parameters ***(Frame, Type, Color depth, etc !)*** Normally these should not be tampered with. The routine and address’s for doing this for SPI videos is not even exposed to the API layer of the library. Each time a media file is OPENED then the proper frame driver code call address’s are installed by the library.

There is a use for installing a ***“User Frame Driver” ***for **PCM audio files**. When the loaded media is an Audio only file ***(WAV or ZCM) *** the default installed Frame driver is just an **RTS** instruction. When playing Audio **VIDKIT** doesn’t do any updates to VERA at all.

You can install your own routine as a User Frame Driver for PCM Audio by calling **\$A012 in VIDKIT Bank B** with the register pair XY holding a pointer to your routine. ***(lsb in X, msb in Y). ***Since VIDKIT sets up the appropriate Internal frame driver each time it loads a new media then your Frame Driver needs to be installed each time you open a new PCM only file ! This only applies to the STD Engine. This is not exposed for the SPI Engine.

Unlike installing a **KeyController** routine. A Frame Driver for a PCM only file is allowed to update the VERA display.

**PLAYMOVIES.PRG** use’s this for it’s Audio only playback screen to update the ***playing bar*** on the screen !

As with installed **KeyController **this routine is called ***...during… ***playback and should be as efficient as possible. It is called immedietly after the PCM buffer is filled with 5 calls to MACPTR with .A (count) set to 0. Normally about 2.5k of Audio data at the current Sample rate should be in the PCM FIFO buffer at that time. (less with HOSTFS, but that is also faster at reads !) How much processing can be done in the Frame Driver depends highly on the fidelity of the PCM sound. Much more processing is possible with lower sample rate PCM files. ! This is why **PLAYMOVIES.PRG** displays a simple animation for low sample rate PCM’s and a static graphic with just a moving bar for higher sample rates !

***TOPIC ****E***

**VIDKIT** has included a few utility routines to help it coexist with **MooingLemur’s ZSMKIT Version 2.8** *(or higher)*

[***https://github.com/mooinglemur/zsmkit***](https://github.com/mooinglemur/zsmkit)

**

**ZSMKIT **predates **VIDKIT** and is used for support for background play of **ZSM *****&***** ZCM** files in a user program. I did use Mr. Lemur’s naming scheme as inspiration, ***(with his permission)*** but the libraries were developed independently for different but complementary purposes. Usage of **ZSMKIT** is beyond the scope of this document, **ZSMKIT** itself includes extensive documentation on it’s usage.

**

ALL ZSMKIT SUPPORT ROUTINES ARE IN BANK C of VIDKIT

If ZSMKIT will not be used in your application it is not necessary to worry about these routines. None of them are called automatically by anything else in VIDKIT. Nor is it completely necessary to use them. They are provided for the convenience of the developer who wish’s to use both Libraries ***(and myself, My scripting project use’s both libraries) ***

For best integration it is recommended to load and init VIDKIT before any other libraries are initialized. In support of these functions **VIDKIT** stores the current value of **CINV *****(the system isr vector)*** on **INIT**. This should be the default **system ISR** and for this reason **VIDKIT** has to **INIT first**.

**

In some case’s it is not necessary to do anything for coexistence. I have tested streaming standard Videos with ZSM background music playing with ZSMKIT and for lower res videos there appear to be no ill effects. This may even be useful if the Video has a silent sound track.

I believe in many case’s it won’t be desired for background Music to play in conjunction with a Video with sound. Also I am **CERTAIN** that ***ZSM’s with PCM tracks will cause problems*** in conjunction with streaming play ! It ***may*** work well enough if **zsm_pcm_suspend** ***(in ZSMKIT)*** is called first !

I am also concerned that ZSMKIT’s background processing may take to much CPU time when playing High Bandwidth SPI videos.

***HELPER Routines for VIDKIT/ZSMKIT coexistence !***

(FOR THESE TO WORK RELIABLY VIDKIT MUST BE LOADED AND INIT CALLED BEFORE CALLING ZSMKIT INIT !)

After **VIDKIT** is loaded and **INIT** has been called. Load and INIT ZSMKIT normally.

Put the **bank number** where **ZSMKIT was loaded** at **R0** and do a **jsr to \$A033** in **VIDKIT Bank C**.

**\*\*\*** VIDKIT ***….Must !….*** know what bank *ZSMKIT lives in*. **\*\*\***

**

Since ZSMKIT has 8 (0 to 7) priority slots for background music VIDKIT contains a routine to scan all 8 slots if they are playing. Save’s the play state & suspends play for the priority if playing. ** ZSMKIT_PAUSEALL**

This routine is called in **VIDKIT Bank C at \$A036**, it does not change ISR vectors.

If about to stream a normal resolution Video or Media file then this is probably sufficient.

If about to stream High Bandwidth media. ***(SPI Vids or CD Quality Audio !) ***

May also be necessary for use of **PLAY_TO_TIMER**

To temporarily redirect ISR processing to the original system ISR:

call **Swap_ORGISR** in **VIDKIT Bank C at \$B41B **

*** (This assumes you have set ZSMKITS init_isr and have also called ZSMKIT_PAUSEALL ****in VIDKIT****)***

**After Streaming Play returns:**

To restore the ZSMKIT ISR call **Swap_NEWISR** in **VIDKIT Bank C at \$B41E**

** **To restore ZSMKIT Playback** **call **ZSMKIT_UNPAUSE **in** VIDKIT Bank C at \$A039**

This technique is illustrated in the included BASLOAD sample code FLIPFLOP.BAS
