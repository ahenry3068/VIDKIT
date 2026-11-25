%address $A000
%memtop $C000
%output library
%import textio
%import conv
%import diskio
%import strings
%import sprites
%import floats
%import verafx
%import VIDKIT_COMMON
%encoding iso
%zeropage basicsafe
%zpreserved $22, $60


main  {
      %jmptable (
         VIDKIT.GRABPlayMedia,
         VIDKIT.PrepFile,
         VIDKIT.PlayFile,
         VIDKIT.VIDSEEK_USER_STARTFRAME,
         VIDKIT.SET_TARGET_FRAME,
         VIDKIT.SET_FRAME_RANGE,
         VIDKIT.SET_STARTTIME,
         VIDKIT.SET_TARGET_TIME,
         VIDKIT.SET_TIME_RANGE,
         VIDKIT.CLOSE_MEDIA,
         VIDKIT.HideBothLayers,
         VIDKIT.hideTextLayer,
         VIDKIT.hideGraphicsLayer,
         VIDKIT.ShowBothLayers,
         VIDKIT.showTextLayer,
         VIDKIT.showGraphicsLayer,
         VIDKIT.PLAY_TO_TIMER,
         VIDKIT.SET_STARTTIME_JIFFIES,
         VIDKIT.SET_VERA_VIDEOMODE,
         VIDKIT.VERSION,
         VIDKIT.SET_KEYEXTRA,
         VIDKIT.CLEAR_KEYEXTRA
      )

; GrabPlay $A003
; PrepFile $A006
; PlayFile $A009
; START_FRAME $A00C
; TARGET_FRAME $A00F
; START_FRAME_RANGE $A012
; START_TIME $A015
; TARGET_TIME $A018
; TIME_RANGE $A01B
; CLOSE_MEDIA $A01E
; HideBothLayers $A021
; hideTextLayer  $A024
; hideGraphicsLayer $A027
; ShowBothLayers $A02A
; showTextLayer  $A02D
; showGraphicsLayer $A030
; PLAY_TO_TIMER $A033
; SET_STARTTIME_JIFFIES $A036
; SET VIDEOMODE $A039
; RETURN VERSION $A03C
; SET_KEYEXTRA $A03F
; CLEAR_KEYEXTRA $A042

sub start() {
    PENV.GetRunEnvironment()
    if (ROM.VERSION < 48) or ((ROM.VERSION==48) and ROM.IsPreRelease) {
       %asm {{ sec
               rts }}
    }
    VIDKIT.ORG_ISR = VIDKIT.CINV
    VIDKIT.MANAGE_SCREEN = true
    if VIDKIT.Volume==0 or VIDKIT.Volume>15 { VIDKIT.Volume = 10 }
    VIDKIT.SAVE_DC_VIDEO = cx16.VERA_DC_VIDEO
    VIDKIT.COPYDOWN_PAL = false
    VIDKIT.KEY_EXTRA = 0
    VIDKIT.STD_ENGINE_BANK = @(0) + 1
    VIDKIT.SPI_ENGINE_BANK = VIDKIT.STD_ENGINE_BANK + 1
    ; Install the custom Trampoline at $0400
    cx16.memory_copy(&VIDKIT.TRAMPOLINE_CODE, $0400, &VIDKIT.TRAMP_CODE_END - &VIDKIT.TRAMPOLINE_CODE)
    ; Now call VIDKIT-B2 INIT
    VIDKIT.TrampCallSTD($AA00)
    ; and call VIDKIT-B3 INIT
    ; poke($20, ROM.VERSION)
    @($20) = ROM.VERSION
    VIDKIT.TrampCallSPI($B400)
    %asm {{ clc }}
 }
}

ROM {
      ubyte VERSION
      bool  IsPreRelease
}

PENV {
           &ubyte[6] HOST  = $500
           &ubyte ctr = $02
           bool IS_HOST
           bool ON_HARDWARE
           bool ON_EMU
           sub IS_HOST_FS()-> bool {
               cbm.SETNAM(11, "$")
               cbm.SETLFS(11, 8, 0)
               cbm.OPEN()
               cbm.CHKIN(11)
               ctr = 0
               while ctr<2 { if cbm.GETIN2()==34 {ctr++} }
               void cbm.GETIN2()
               for ctr in 0 to 3 {HOST[ctr] = cbm.GETIN2()}
               HOST[4] = 0
               cbm.CLRCHN()
               cbm.CLOSE(11)
               return ((strings.compare(&HOST,"HOST")==1) and ON_EMU)
             }

&uword EMUIndicator = $9FBE

sub GetRunEnvironment() {
         ROM.VERSION, ROM.IsPreRelease = cx16.rom_version()
         ON_EMU = (EMUIndicator==$3631)
         IS_HOST=IS_HOST_FS()
         ON_HARDWARE = not ON_EMU
     }
}


VIDKIT {

TRAMPOLINE_CODE:
%asmbinary "tramp.o"
TRAMP_CODE_END:

; STD ENGINE ROUTINES
extsub $A000 = stB_PlayVideo_STD(uword PCMParms @ R0) clobbers(A,X,Y)

; Clears TextBuffer at 1:$B000, GraphBuffer at 0:$0000 and the Sprite Data Buffer at 1:$3000
; (fills with 0)
extsub $A003 = stB_ClearAllBuffers() clobbers(A,X,Y)

extsub $A006 = stB_Engine_SetAudioCode(uword AudParms1 @R0, uword AudParms2 @R1, ubyte AbuffRem @R2 ) clobbers(A)
extsub $A009 = stB_SetSpriteMovie8bit(uword BuffSizes @R3, ubyte SpriteCount @R4, uword EndSprAttrs @R5, uword EndSprData @R6 ) clobbers(A,X)
extsub $A00C = stB_SetSpriteMovie4bit(uword BuffSizes @R3, ubyte SpriteCount @R4, uword EndSprAttrs @R5, uword EndSprData @R6 ) clobbers(A,X)
extsub $A00F = stB_SetBitMapMovie(uword BuffSizes @R3, ubyte WidthByte @R2, ubyte PaletteSize @R4) clobbers(A,X)
extsub $A012 = stB_SET_FRAME_DRIVER(uword DriverAddr @ XY)

; Clears the Graphics Buffer at 0:0000 for 76800 bytes.  (execution time app. 2.7 jiffies)
extsub $A015 = stB_ClearGraphBuffer() clobbers(A,X,Y)
; basically CLS (but always to color 0).  Not sure there's an advantage here but it is also
; called by the Above ClearAllBuffers.
extsub $A018 = stB_ClearTextBuffer() clobbers(A,X,Y)

; Clears the Sprite Buffer at 1:$3000
extsub $A01B = stB_ClearSpriteBuffer() clobbers(A,X,Y)

extsub $A021 = stB_SET_PCM_ONLY() clobbers(A,X)

; Only valid value to pass at the moment is 4 which aligns with the Video LFN for
; Video type 6 & 8 (with embedded Audio).
; eventually both LFN's will be assignable.   For NOW video LFN is 4
; Audio LFN if a seperate file is 6 (same as Vid LFN if embedded)
extsub $A01E = stB_SetAudioLFN(ubyte AudLFN @R0) clobbers(A)

extsub $A024 = stB_HIDEALLSPRITES() clobbers(A,X)

; Decrements all RGB Values in the VERA Palette towards 0 individually by 1.
; If DOBLUE is true then the B value is instead shifted towards $F by 1
extsub $A027 = stB_PALSHIFT(bool DOBLUE @ X) clobbers(A,X,Y)

extsub $A02A = stB_SET_DEFAULT_PALETTE() clobbers(A,X,Y)
extsub $A02D = stB_SETEXTERNAL_CONTROLS() clobbers(X,Y)
extsub $A030 = stB_TURN_OFF_PALETTE_HANDLING() clobbers(A)        ;SYS $A030
extsub $A033 = stB_TURN_ON_PALETTE_HANDLING() clobbers(A)         ;SYS $A033
extsub $A036 = stb_DISK_FASTMODE() clobbers(A,X,Y)
extsub $A039 = stb_FADE2BLACK()

extsub $AA03 = stB_PrepareSTDVideoPlay()
extsub $AA06 = stB_RESTORELINES()
extsub $AA09 = stB_SetVideoAttributeSTD()
extsub $AA0C = stB_setup_SpriteGrid(word X @R7, word Y @R9) clobbers(A,X,Y)
extsub $AA0F = stB_SETUP_PCMPLAY()
extsub $AA12 = stB_CLONENAMES()
extsub $AA15 = stB_RESTORE_SCREEN()
extsub $AA18 = stB_PLAY_TO_TIMER()
; END STANDARD ENGINE ROUTINES

; SPI ENGINE ROUTINES
extsub $A000 = spB_PlayVideo_SPI() clobbers(A,X,Y)
extsub $A00F = spB_SETVIDREAD_BITMAP() clobbers(A,X,Y)
extsub $A012 = spB_SETVIDREAD_BITMAP_LOW() clobbers(A,X,Y)
extsub $A015 = spB_SETAUDIOREAD_SPI() clobbers(A,X)
extsub $A018 = spB_SET_FRAME_38K() clobbers(A)
extsub $A01B = spB_SET_FRAME_51K() clobbers(A)
extsub $A01E = spB_SET_FRAME_62K() clobbers(A)
; INTERNAL (appended to the SPIVID jump table): HB sprite layout + loader setup (VTYPE 21,22,26,27)
extsub $A03C = spB_SETSPRITEREAD_SPI() clobbers(A,X,Y)
extsub $A021 = spB_RESETPCM() clobbers(A,X)
; END SPI ENGINE ROUTINES

;B3 B400 ROUTINES
extsub $B400 = spB_INIT_B3()
extsub $B403 = spB_SEEK_FRAMESPI()
extsub $B40F = spB_PLAY_TO_TIMER()

&ubyte[4] fsector = $18

alias f_size_low = cx16.r2
alias f_size_high = cx16.r3

str FILEID = iso:"SPRV"
str BASENAME = "?"*96
str PAD = " "*4
str VIDFILE = "MOVIE"+"?"*96
str PAD3 = " "*4
str AUDFILE = "?"*96
str PALFILE = "?"*96
str PAD4 = " "*4
str TMPFILE = "?"*96
str VEXT = iso:".SPV"
str AEXT = iso:".SVA"
str ZEXT = iso:".ZCM"
str WEXT = iso:".WAV"
str FOUND_EXT = ".XXX" + "?"*2

ubyte i=0
ubyte j=0

ubyte STD_ENGINE_BANK
ubyte SPI_ENGINE_BANK
ubyte HIRAMBANK

uword FrameBufferSize
uword PalBufferSize
uword NumSprites
uword SpriteAttr_EndAddress
uword SpriteBlock2_DataAddress
ubyte VBuff_255
ubyte VBuff_Remainder
ubyte ABuff_255
ubyte ABuff_Remainder
uword SpriteOrigAddress
uword SpriteBuffSize

word XOrg = 0
word YOrg = 0

alias NumFramesHI = cx16.r1
alias NumFramesLO = cx16.r2

float play_total
float play_left
float NumFrames = 0.0
float AudFileSize = 0.0
float vidFilePosition

float VidFileStartSector
float AudFileStartSector
float Seeker

const ubyte MAJOR = 2
const ubyte MINOR = 0
asmsub VERSION() {
  %asm {{
     lda #p8c_MAJOR
     ldx #p8c_MINOR
     clc            ; This will be CLC for the release CODE !
     rts
  }}
}

sub Restore_Screen() {
    TrampCallSTD(&stB_RESTORE_SCREEN)
}

sub DiskFastMode() {
    TrampCallSTD(&stb_DISK_FASTMODE)
}

sub TrampCallSPI(uword TARGET_ADDR) {
    Trampoline_JSR_Target = TARGET_ADDR
    Trampoline_BANK_Target = SPI_ENGINE_BANK
    Trampoline()
}

sub TrampCallSTD(uword TARGET_ADDR) {
    Trampoline_JSR_Target = TARGET_ADDR
    Trampoline_BANK_Target = STD_ENGINE_BANK
    Trampoline()
}

sub PlayVideo_STD(uword PCMParms @ R0) {
    TrampCallSTD(&stB_PlayVideo_STD)
}

sub ClearAllBuffers() {
    TrampCallSTD(&stB_ClearAllBuffers)
}

sub Engine_SetAudioCode(uword AudParms1 @R0, uword AudParms2 @R1, ubyte AbuffRem @R2) {
    TrampCallSTD(&stB_Engine_SetAudioCode)
}

sub SetSpriteMovie8bit(uword BuffSizes @R3, ubyte SpriteCount @R4, uword EndSprAttrs @R5, uword EndSprData @R6) {
    TrampCallSTD(&stB_SetSpriteMovie8bit)
}

sub SetSpriteMovie4bit(uword BuffSizes @R3, ubyte SpriteCount @R4, uword EndSprAttrs @R5, uword EndSprData @R6) {
    TrampCallSTD(&stB_SetSpriteMovie4bit)
}

sub SetBitMapMovie(uword BuffSizes @R3, ubyte WidthByte @R2, ubyte PaletteSize @R4) {
    TrampCallSTD(&stB_SetBitMapMovie)
}

sub ClearGraphBuffer() {
    TrampCallSTD(&stB_ClearGraphBuffer)
}

sub ClearTextBuffer() {
    TrampCallSTD(&stB_ClearTextBuffer)
}

sub ClearSpriteBuffer() {
    TrampCallSTD(&stB_ClearSpriteBuffer)
}

sub SET_PCM_ONLY() {
    TrampCallSTD(&stB_SET_PCM_ONLY)
}

sub SetAudioLFN(ubyte AudLFN @R0) {
    TrampCallSTD(&stB_SetAudioLFN)
}

sub HIDEALLSPRITES() {
    TrampCallSTD(&stB_HIDEALLSPRITES)
}

asmsub PALSHIFT() {
%asm {{
          pha
          lda #$27
          sta $040F
          lda #$A0
          sta $0410
          lda p8v_STD_ENGINE_BANK
          sta $041B
          pla
          jmp $0400
    }}
}

sub SET_DEFAULT_PALETTE() {
    TrampCallSTD(&stB_SET_DEFAULT_PALETTE)
}

sub TURN_OFF_PALETTE_HANDLING() {
    TrampCallSTD(&stB_TURN_OFF_PALETTE_HANDLING)
}

sub TURN_ON_PALETTE_HANDLING() {
    TrampCallSTD(&stB_TURN_ON_PALETTE_HANDLING)
}

sub PlayVideo_SPI() {
    TrampCallSPI(&spB_PlayVideo_SPI)
}

sub SETVIDREAD_BITMAP() {
    TrampCallSPI(&spB_SETVIDREAD_BITMAP)
}

sub SETVIDREAD_BITMAP_LOW() {
    TrampCallSPI(&spB_SETVIDREAD_BITMAP_LOW)
}

sub SETAUDIOREAD_SPI() {
    TrampCallSPI(&spB_SETAUDIOREAD_SPI)
}

sub SET_FRAME_38K() {
    TrampCallSPI(&spB_SET_FRAME_38K)
}

sub SET_FRAME_51K() {
    TrampCallSPI(&spB_SET_FRAME_51K)
}

sub SET_FRAME_62K() {
    TrampCallSPI(&spB_SET_FRAME_62K)
}

sub RESETPCM() {
    TrampCallSPI(&spB_RESETPCM)
}

sub PrepareSTDVideoPlay() {
    TrampCallSTD(&stB_PrepareSTDVideoPlay)
}

sub RESTORE_LINES() {
    TrampCallSTD(&stB_RESTORELINES)
}

sub MAKE_ALL_FALSE() {
  success = false
  VIDKIT.COPYDOWN_PAL = false
  IS_VIDEO = false
  K_TYPE = false
  HAS_ASPECT = false
  IS_SPI_VIDEO = false
  IS_STD_VIDEO = false
  IS_PCM_ONLY = false
  IS_Z_FILE = false
  IS_WAV_FILE = false
  PCM_IS_16BIT = false
  PCM_IS_STEREO = false
}

sub VERA2Hz() -> float {
    return (VideoHeader.VERARate as float / 128.0) * 48828.15
}

sub check_A_Ext(str extension, str TARGET) -> bool {
    strings.copy(BASENAME,TARGET)
    strings.append(TARGET,extension)
    tmpB2 = FExists(TARGET, strings.length(TARGET))
    if tmpB2 { strings.copy(extension, FOUND_EXT) } else { FOUND_EXT[0] = 0 }
    return tmpB2
}

sub FIND_AUDIO_FILE()  {
    PCM_FILE_FOUND = check_A_Ext(ZEXT,AUDFILE)
    if PCM_FILE_FOUND { IS_Z_FILE = true goto DoneAudioSearch }
    PCM_FILE_FOUND = check_A_Ext(WEXT,AUDFILE)
    if PCM_FILE_FOUND { IS_WAV_FILE = true }
DoneAudioSearch:
    IS_PCM_ONLY = PCM_FILE_FOUND
    success = IS_PCM_ONLY
    return
}

sub FIND_PAL_FILE() {
    PAL_FILE_FOUND = check_A_Ext(".PAL",PALFILE)
    return
}

sub BlankPAL_LAST32() {
    cx16.VERA_ADDR_L = $C0
    cx16.VERA_ADDR_M = $FB
    cx16.VERA_ADDR_H = %00010001
    repeat 16 { unroll 4 { %asm {{ stz $9F23 }} } }
}

alias SetDefaultPalette = SET_DEFAULT_PALETTE

sub hideGraphicsLayer() {
    cx16.VERA_DC_VIDEO = cx16.VERA_DC_VIDEO & 239
}

sub showGraphicsLayer() {
    cx16.VERA_DC_VIDEO = cx16.VERA_DC_VIDEO | 16
}

sub hideTextLayer() {
    cx16.VERA_DC_VIDEO = cx16.VERA_DC_VIDEO & 223
}

sub showTextLayer() {
    cx16.VERA_DC_VIDEO = cx16.VERA_DC_VIDEO | 32
}

asmsub HideBothLayers() {
  %asm {{
    jsr p8s_hideGraphicsLayer
    jmp p8s_hideTextLayer
  }}
}

asmsub ShowBothLayers() {
  %asm {{
    jsr p8s_showGraphicsLayer
    jmp p8s_showTextLayer
  }}
}

sub setup_SpriteGrid(word X @R7, word Y @R9) {
    TrampCallSTD(&stB_setup_SpriteGrid)
}

sub fopen(ubyte lfn, ubyte device, ubyte sa, str filename) {
    cbm.SETLFS(lfn, device, sa)
    cbm.SETNAM(strings.length(filename), filename)
    void cbm.OPEN()
}

sub numFrameSectors() -> ubyte {
    tmpw = FrameBufferSize / 512
    if FrameBufferSize % 512 > 0 { tmpw = tmpw + 1 }
    return tmpw as ubyte
  }

sub FLOAT_TO_INT32(float src, ubyte[] target) {
    tmpw = src/65536.0 as uword
    target[3] = msb(tmpw)
    target[2] = lsb(tmpw)
    tmpw2 = (src - (tmpw as float * 65536.0)) as uword
    target[1] = msb(tmpw2)
    target[0] = lsb(tmpw2)
}

sub INT32_TO_FLOAT(ubyte[] src) -> float {
    tmpw = src[2] + (src[3] as uword * 256)
    return (src[0] as float) + (src[1] as float * 256.0) + (tmpw as float * 65536)
}

sub SET_VID_STARTSECTOR() {
    for i in 0 to 3 { VID_SECTOR_START[i] = fsector[i] }
}

sub SET_AUD_STARTSECTOR() {
    for i in 0 to 3 { AUD_SECTOR_START[i] = fsector[i] }
}

sub VIDSTART_TOFLOAT() -> float {
    return (VID_SECTOR_STARTw[0] as float) + ((VID_SECTOR_STARTw[1] as float)*65536.0)
}

sub FLOATTO_VIDCURRENT(float FStart) {
    VID_SECTOR_CURRENTw[1] = (FStart/65536.0) as uword
    VID_SECTOR_CURRENTw[0] = ( FStart - (AUD_SECTOR_STARTw[1] as float * 65536.0) ) as uword
}

sub AUDSTART_TOFLOAT() -> float {
    return (AUD_SECTOR_STARTw[0] as float) + ((AUD_SECTOR_STARTw[1] as float)*65536.0)
}

sub FLOATTO_AUDCURRENT(float FStart) {
    AUD_SECTOR_CURRENTw[1] = (FStart/65536.0) as uword
    AUD_SECTOR_CURRENTw[0] = (FStart - (AUD_SECTOR_STARTw[1] as float * 65536.0) ) as uword
}

sub VIDSEEK_USER_STARTFRAME() { TrampCallSPI($B409) }

sub SET_TARGET_FRAME() { TrampCallSPI($B406) }

asmsub SET_FRAME_RANGE() {
  %asm {{ jsr p8s_SET_TARGET_FRAME
          jmp p8s_VIDSEEK_USER_STARTFRAME }}
}

sub SET_STARTTIME() {
    if IS_PCM_ONLY {
       audFilePosition = floats.round(cx16.r5 as float * PCM_BYTEsPerSecond)
       %asm {{ jmp p8s_SET_STARTTIME_JIFFIES.p8l_doJSeek }}
    } else {
       FLOAT_TO_INT32(floats.round(cx16.r5 as float * TRUE_FPS), &cx16.r0 )
       VIDSEEK_USER_STARTFRAME()
    }
}

sub SET_STARTTIME_JIFFIES() {
       audFilePosition = floats.round(((((cx16.r4 as float) + (cx16.r5 as float * 65536.0)) as float) * PCM_BYTEsPerSecond) / 60.0)
doJSeek:
       FLOAT_TO_INT32(audFilePosition, &cx16.r7)
       cx16.r7L = AudioHeaderSize as ubyte
       f_seekL(AudioLFN, &cx16.r7)
}

sub SET_TARGET_TIME() {
    FLOAT_TO_INT32(floats.round(peekw(&cx16.r6) as float * TRUE_FPS), &cx16.r3 )
    SET_TARGET_FRAME()
}

asmsub SET_TIME_RANGE() {
  %asm {{
      jsr p8s_SET_STARTTIME
      jmp p8s_SET_TARGET_TIME
  }}
}

sub CALC_FILE_STARTUP_SECTORS() {
    VID_FRAME_NUMSECTORS = numFrameSectors()
    ubyte palSec = 0
    if VID_HAS_PALETTE { palSec = 1 }       ; 22 & 27 have no 512 byte palette block
    if AUDIO_TRACK_IN_SEPERATEFILE {        ; 23, 21, 22
       VID_SECTOR_ADDER = VID_FRAME_NUMSECTORS + palSec
       AUD_SECTOR_ADDER = AUD_FRAME_NUMSECTORS

       Video_START_SECTOR = VidFileStartSector + 1
       Audio_START_SECTOR = AudFileStartSector

       if AUD_FRAME_NUMSECTORS < 5 {
          Audio_START_SECTOR = Audio_START_SECTOR + (AUD_FRAME_NUMSECTORS as float)
          FLOAT_TO_INT32(AudFileStartSector, AUD_LEAD_START)
        }
     }
    else {                                  ; 28, 26, 27 (audio embedded)
       VID_SECTOR_ADDER = VID_FRAME_NUMSECTORS + AUD_FRAME_NUMSECTORS + palSec
       AUD_SECTOR_ADDER = VID_SECTOR_ADDER

       Video_START_SECTOR = (VidFileStartSector + 1.0) + (AUD_FRAME_NUMSECTORS as float)
       Audio_START_SECTOR = (VidFileStartSector + 1.0)

       if AUD_FRAME_NUMSECTORS < 5 {
          Video_START_SECTOR = Video_START_SECTOR + (AUD_FRAME_NUMSECTORS as float)
          FLOAT_TO_INT32(Audio_START_SECTOR, AUD_LEAD_START)
          Audio_START_SECTOR = Audio_START_SECTOR + (AUD_FRAME_NUMSECTORS as float)
        }
      }
SETSTART:
     FLOAT_TO_INT32(Video_START_SECTOR, VID_SECTOR_CURRENT)
     FLOAT_TO_INT32(Audio_START_SECTOR, AUD_SECTOR_CURRENT)
}

sub SETUP_SPI_ENGINECODE() {
    SETAUDIOREAD_SPI()
    if IS_SPRITE_VIDEO {                          ; HB sprite types: SPIVID works out the VRAM layout and selects its loader
       TrampCallSPI(&spB_SETSPRITEREAD_SPI)
       return
    }
    if FrameBufferSize < 38401.00 {
          SET_FRAME_38K()
    }
    else {
       if FrameBufferSize < 51201.00 {
          SET_FRAME_51K()
       }
       else {
          SET_FRAME_62K()
       }
    }
    if VideoHeader.BPP==8 { SETVIDREAD_BITMAP() } else { SETVIDREAD_BITMAP_LOW() }
  }

sub CalcFrameSize() {
    ubyte adjust
    if VideoHeader.BPP==1 { adjust=8
                PalBufferSize = 4}
    if VideoHeader.BPP==2 { adjust=4
                PalBufferSize = 8}
    if VideoHeader.BPP==4 { adjust=2
                PalBufferSize = 32}
    if VideoHeader.BPP==8 { adjust=1
                PalBufferSize = 512}
    if not VID_HAS_PALETTE { PalBufferSize=0 }
    FrameBufferSize = ((VideoHeader.FrameWidth as float * VideoHeader.FrameHeight as float) / adjust as float) as uword
}

sub calc_asize(float filesize, float numframes) -> uword {
    tmpf = floats.round(filesize / numframes)
    if IS_STD_VIDEO {
        if PCM_IS_16BIT or PCM_IS_STEREO {
           if floats.floor(tmpf/2.0) != (tmpf/2.0) {
              tmpf = tmpf - 1
            }
        }
        if PCM_IS_16BIT and PCM_IS_STEREO {
           while (floats.floor(tmpf/4.0) != (tmpf/4.0)) { tmpf = tmpf + 1 }
        }
     }
  return tmpf as uword
}

sub CalcTrueFPS() {
    tmpf = (VideoHeader.VERARate as float / 128.0) * 48828.15  ; ByteRate == PCM Rate for 8 bit mono PCM
    if PCM_IS_16BIT { tmpf = tmpf * 2.0 }
    if PCM_IS_STEREO { tmpf = tmpf * 2.0 }
    TRUE_FPS = tmpf / VideoHeader.AudioFrameSize as float
}

sub CalculateVERARate() -> ubyte {
        tmpf = VideoHeader.AudioFrameSize as float * F_FPS
        if PCM_IS_16BIT { tmpf = tmpf / 2 }
        if PCM_IS_STEREO { tmpf = tmpf / 2 }
        return floats.floor((tmpf / 48828.15) * 128) as ubyte
}


sub Get_VidFrameNumber_STD(float FilePos) -> float {
   uword HeaderSize = 32
   uword FrameTotalSize = FrameBufferSize + PalBufferSize
   if VideoHeader.VTYPE==6 or VideoHeader.VTYPE==8 or VideoHeader.VTYPE==7 {
      FrameTotalSize += VideoHeader.AudioFrameSize
      if VideoHeader.AudioFrameSize < 2049 { HeaderSize += VideoHeader.AudioFrameSize }
    }
   return floats.floor((FilePos - HeaderSize as float)/FrameTotalSize as float) - 1.0
}


sub GetAudioPosition() {
    my_f_tell(AudioLFN)
    audFilePosition = (65536.0 * cx16.r1 as float) + cx16.r0 as float
}


sub hFullScale(uword HRes) -> ubyte {
  &float hScale = $0522
  hScale = floats.floor((HRes as float/640.0) * 128.0)
  return hScale as ubyte
}

sub vFullScale(uword VRes) -> ubyte {
  &float vScale = $522
  &float FDiv = $527
  if MAKE_WIDE_SCREEN { FDiv = 360.0 } else { FDiv = 480.0 }
  vScale = floats.floor((VRes as float/FDiv) * 128.0)
  return vScale as ubyte
}

; ---------------------------------------------------------------------------
; VIDKIT 2.1  HINT "A": show the picture in its true shape.
; The picture gets a window on the 640 x 480 output:
;     aspect >= 4:3   640 columns wide, floor(640 / aspect) lines high (even)
;     aspect <  4:3   480 lines high,   floor(480 * aspect) columns wide (multiple of 8)
; The frame is scaled to fill the window.  Scale values are whole numbers rounded DOWN
; (128 = 1:1, a frame can never be shown smaller than 1:1), so the picture ends up a
; little bigger than the window: the extra edge lines / columns are clipped, never garbage.
; The Movie Maker (MM_ASPECT.BM) uses exactly the same rules when it checks frame sizes.
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; VIDKIT 2.1  HINT "A": show the picture in its true shape (called from B1 SetFullScreen).
;     aspect >= 4:3   640 columns wide, floor(640 / aspect) lines high (even)
;     aspect <  4:3   480 lines high,   floor(480 * aspect) columns wide (multiple of 8)
; Scales are whole numbers rounded DOWN (128 = 1:1): the picture ends up a little bigger than
; the window, the extra edge lines / columns are clipped.  MM_ASPECT.BM uses the same rules.
; ---------------------------------------------------------------------------
; Compact on purpose (B3 must keep 512 pad bytes): ONE float calculation, the rest is small integer math.
; Window units: lines come in steps of 2 (VSTART/VSTOP), columns in steps of 8 here (HSTART/HSTOP count 4).
;   wide  (aspect >= 4:3): 640 columns, l2 = floor(320 / aspect) = lines / 2
;   narrow(aspect <  4:3): 480 lines,   c8 = floor(60 * aspect)  = columns / 8
sub SetAspectScreen() {
    alias hs = cx16.r0L
    alias he = cx16.r0H
    alias vs = cx16.r3L
    alias ve = cx16.r3H
    alias hsc = cx16.r1
    alias vsc = cx16.r2
    alias l2 = cx16.r4L
    alias c8 = cx16.r4H
    hs = 0                                                    ; default window = full screen
    he = 160
    vs = 0
    ve = 240
    if VideoHeader.AspectF >= 1.3333333 {
        l2 = floats.floor(320.0 / VideoHeader.AspectF + 0.001) as ubyte
        vs = (240 - l2) / 2
        ve = vs + l2
        hsc = VideoHeader.FrameWidth / 5                      ; = frame * 128 / 640
        vsc = (VideoHeader.FrameHeight * 64) / l2             ; = frame * 128 / (2 * l2)
    } else {
        c8 = floats.floor(60.0 * VideoHeader.AspectF + 0.001) as ubyte
        hs = 80 - c8
        he = 80 + c8
        hsc = (VideoHeader.FrameWidth * 16) / c8              ; = frame * 128 / (8 * c8)
        vsc = (VideoHeader.FrameHeight * 4) / 15              ; = frame * 128 / 480
    }
    cx16.VERA_DC_HSCALE = lsb(hsc)
    cx16.VERA_DC_VSCALE = lsb(vsc)
    ; DCSEL = 1 : HSTART, HSTOP, VSTART, VSTOP at $9F29 - $9F2C.  Zero page: $02 = r0L (hs), $03 = r0H (he),
    ; $08 = r3L (vs), $09 = r3H (ve)  (cx16 virtual registers r0..r15 live at $02..$21)
    %asm {{
        lda #2
        sta $9F25
        lda $02
        sta $9F29
        lda $03
        sta $9F2A
        lda $08
        sta $9F2B
        lda $09
        sta $9F2C
        stz $9F25
    }}
    if VideoHeader.BPP < 8 { @($9F2C)=$10 }
}

sub SetFullScreen() {
    if HAS_ASPECT {
        SetAspectScreen()
        return
    }
    ubyte vScale = vFullScale(VideoHeader.FrameHeight)
    ubyte hScale = hFullScale(VideoHeader.FrameWidth)
    if IS_SPRITE_VIDEO {
       if IS_TALL_VIDEO or (VideoHeader.FrameWidth as float <= (VideoHeader.FrameHeight as float/1.5)) { hScale = vScale - 1 }
    }
    if K_TYPE { cx16.VERA_DC_HSCALE = 128 } else { cx16.VERA_DC_HSCALE = hScale }
    cx16.VERA_DC_VSCALE = vScale
    if MAKE_WIDE_SCREEN {
       %asm {{
         lda #2
         sta $9F25
         lda #30
         sta $9F2B
         lda #210
         sta $9F2C
         stz $9F25 }}
       if VideoHeader.BPP < 8 { @($9F2C)=$10 }
    }
    if K_TYPE {
       %asm {{
         lda #2
         sta $9F25
         lda #40
         sta $9F29
         lda #120
         sta $9F2A
         stz $9F25
       }}
       if VideoHeader.BPP < 8 { @($9F2C)=$10 }
    }
}

sub SET_VERA_VIDEOMODE() {
       if IS_PCM_ONLY { return }
       XOrg = 0
       YOrg = 0
       if VideoHeader.BPP<8 and VID_HAS_PALETTE {
          cx16.VERA_ADDR_L = $C0
          cx16.VERA_ADDR_M = $FB
          cx16.VERA_ADDR_H = %00010001
          repeat 32 { unroll 2 { cx16.VERA_DATA0=0 } }
       }
       ubyte smode = $80
       when VideoHeader.VTYPE {
       1,2,6,7,21,22,26,27 -> if VideoHeader.BPP==8 {smode=3}
          3, 8,23,28 -> if VideoHeader.FrameWidth==640 { smode=0 }
       }
       cx16.set_screen_mode(smode)
       ClearAllBuffers()
       if IS_BITMAP_VIDEO and VideoHeader.FrameWidth==640 { showGraphicsLayer() }
       if IS_SPRITE_VIDEO {
          ; HB sprite buffers that start at 0:0000 (tier 2/3) live inside the bitmap layer's VRAM: screen mode $80 would
          ; draw them as a 320x240 bitmap behind the video, so the graphics layer has to go.
          if VideoHeader.VTYPE>20 and HB_BANK1==0 { hideGraphicsLayer() }
          if (VideoHeader.VTYPE<20 and VideoHeader.BPP==4 and FrameBufferSize>16384) { hideTextLayer() }   ; HB sprites hide the text layer themselves (B2 setup_SpriteGrid)
          ; This little bit of code centers TALL videos.
          if VideoHeader.FrameWidth as float <= (VideoHeader.FrameHeight as float/1.5) or IS_TALL_VIDEO {
             tmpw = floats.round(((vFullScale(VideoHeader.FrameHeight) - 1) as float / 128.0) * 640) as uword
             XOrg = ((tmpw - VideoHeader.FrameWidth) / 2) as word
          }
          setup_SpriteGrid(XOrg,YOrg)
        }

       if IS_BITMAP_VIDEO {
          when VideoHeader.BPP {
              1 -> cx16.VERA_L0_CONFIG = %00000100
              2 -> cx16.VERA_L0_CONFIG = %00000101
              4 -> cx16.VERA_L0_CONFIG = %00000110
          }
       }
       SetFullScreen()
}

sub setPlayerScreen() {
    if MANAGE_SCREEN {
       if NO_SCREENCHANGE and SCREEN_IS_SET { return }
       SET_VERA_VIDEOMODE()
    }
}

bool tmpB
bool tmpB2

float AudioHeaderSize

sub DblPCMByteRate() { PCM_BYTEsPerSecond = PCM_BYTEsPerSecond * 2 }

sub GetPCM_ByteRate() {
    PCM_BYTEsPerSecond = floats.round((VideoHeader.VERARate as float / 128.0) as float * 48828.15)
    if PCM_IS_16BIT { DblPCMByteRate() }
    if PCM_IS_STEREO { DblPCMByteRate() }
}

sub PARSE_WAV_HEADER() {
    tmpB = WAVHeader.RIFFID[0]=='R' and WAVHeader.RIFFID[1]=='I' and WAVHeader.RIFFID[2]=='F' and WAVHeader.RIFFID[3]=='F'

    success = WAVHeader.WAVID[0]=='W' and WAVHeader.WAVID[1]=='A' and WAVHeader.WAVID[2]=='V' and WAVHeader.WAVID[3]=='E'

    success = tmpB and success

    if success { success = WAVHeader.AUDIO_FORMAT==1 and (WAVHeader.AUDIO_CHANNELS==1 or WAVHeader.AUDIO_CHANNELS==2) and (WAVHeader.SAMPLE_BITS==16) }

    if success { success = (WAVHeader.SAMPLE_RATExL < 48829) and (WAVHeader.SAMPLE_RATExL > 0) and (WAVHeader.SAMPLE_RATExH==0) }

    if success {
       if VideoHeader.BPP==1
          { VIDKIT.COPYDOWN_PAL = true }
       else
          { VIDKIT.COPYDOWN_PAL = false }
       VideoHeader.XAUD_FLAG = 'X'
       VideoHeader.XCFG_BYTE = %00100000
       PCM_IS_16BIT = true
       PCM_IS_STEREO = (WAVHeader.AUDIO_CHANNELS==2)
       if PCM_IS_STEREO { VideoHeader.XCFG_BYTE = %00110000 }
       VideoHeader.VERARate = ((WAVHeader.SAMPLE_RATExL as float/48828.15) * 128.0 ) as ubyte
       VERAcfgvar = VideoHeader.XCFG_BYTE
       AudioHeaderSize = 44
       IS_WAV_FILE = success
     }
}

sub VERIFY_ZCM_HEADER() -> bool {
     ZCMHeader.ZCFG_BYTE = ZCMHeader.ZCFG_BYTE & $F0  ; mask out the volume value.

     ; Sanity checks to ensure this is actually a proper ZCM file. (No way to be 100% on this)
     tmpB = (ZCMHeader.ZCFG_BYTE == 0) or (ZCMHeader.ZCFG_BYTE == %00100000) or (ZCMHeader.ZCFG_BYTE == %00110000) or (ZCMHeader.ZCFG_BYTE == %00010000)
     tmpB = tmpB and ((ZCMHeader.ZRATE_BYTE < 129) and (ZCMHeader.ZRATE_BYTE > 0))

    if tmpB {
      VideoHeader.VERARate = ZCMHeader.ZRATE_BYTE
      VideoHeader.XCFG_BYTE = ZCMHeader.ZCFG_BYTE
      VERAcfgvar = ZCMHeader.ZCFG_BYTE
      VideoHeader.XAUD_FLAG = 'X'
       PCM_IS_16BIT = (( VERAcfgvar & %00100000 ) == %00100000 )
      PCM_IS_STEREO = (( VERAcfgvar & %00010000 ) == %00010000 )
      AudioHeaderSize = 8
    }
    success = tmpB
    return tmpB
}

sub READ_AUDIO_HEADER(ubyte ALFN, ubyte hcount) {
    cbm.CHKIN(ALFN)
    for i in 0 to hcount { AUD_Header[i]=cbm.GETIN2() }
    cbm.CLRCHN()
    audFilePosition = hcount + 1
    f_seek(ALFN, audFilePosition)
}

sub Read_ZCM_HEADER(ubyte ALFN)  {
    READ_AUDIO_HEADER(ALFN, 7)
  }

sub Read_WAV_HEADER(ubyte ALFN) {
    READ_AUDIO_HEADER(ALFN, 43)
  }

sub OpenAudioFile(str AUDEXT) {
    strings.copy(BASENAME, AUDFILE)
    strings.append(AUDFILE,AUDEXT)
    if FExists(AUDFILE,strings.length(AUDFILE))
     {
       fopen(AudioLFN, drivenumber,AudioLFN, AUDFILE)
       my_f_tell(AudioLFN)
       AudFileSize = (65536.0 * f_size_high as float) + f_size_low as float
       success = true
       return }
         else {
            ; open failed
            success = false
            return }
    }


sub getSector1() {
    cx16.r0 = $B7E1    ; This is valid for r48 only !!!
    for i in 0 to 3 {
        fsector[i] = cx16.fetch(&cx16.r0,0,i)
    }
 }

sub getSector(ubyte channel) {
 if ROM.VERSION==48 { getSector1() return }
        File_FL(channel)
        fsector[0] = cx16.r0L
        fsector[1] = cx16.r0H
        fsector[2] = cx16.r1L
        fsector[3] = cx16.r1H
 }

 sub getStartSector(ubyte device, str filename) {
        fopen(1,device,2,filename)
        getSector(2)
        cbm.CLOSE(1)
}

sub FILE_SECTOR(ubyte sA) -> float {
    getSector(sA)
    return INT32_TO_FLOAT(fsector)
}


float FILE_STARTSECTOR
float CURRENT_SECTOR
float FILE_NUMBER_OF_SECTORS
float F_FILESIZE

sub SetVideoAttributes_SPI() {
    cbm.CLOSE(VideoLFN)
    getStartSector(drivenumber, VIDFILE)
    SET_VID_STARTSECTOR()
    VidFileStartSector = VIDSTART_TOFLOAT()
    if AUDIO_TRACK_IN_SEPERATEFILE {
        OpenAudioFile(AEXT)
        VideoHeader.AudioFrameSize = calc_asize(AudFileSize, NumFrames)
        cbm.CLOSE(AudioLFN)
        getStartSector(drivenumber,AUDFILE)
        for i in 0 to 3 { AUD_SECTOR_START[i] = fsector[i] }
        ;SET_AUD_STARTSECTOR()
        AudFileStartSector = AUDSTART_TOFLOAT()
        AUD_FRAME_NUMSECTORS = ((VideoHeader.AudioFrameSize + 256)/512) as ubyte
        VideoHeader.AudioFrameSize = (AUD_FRAME_NUMSECTORS as uword * 512)
        VideoHeader.VERARate = CalculateVERARate()
      }
    else
      {
        AUD_FRAME_NUMSECTORS = ((VideoHeader.AudioFrameSize/512) as ubyte)
        AudFileStartSector = 0
      }
    CalcTrueFPS()
    G_WIDTH = 0
    if VideoHeader.FrameWidth == 640 { G_WIDTH=1 }
    CalcFrameSize()
    DO_BUFFER_AUDIO = ( AUD_FRAME_NUMSECTORS < 5)
    CALC_FILE_STARTUP_SECTORS()
    SETUP_SPI_ENGINECODE()
}

sub CopyHighFrameNumber() {
  for i in 0 to 2 { FRAME_TARGET[i] = vHdrNUMFRAMES[i] RFRAME[i]=vHdrNUMFRAMES[i] }
  RFRAME[3] = 0
  RESET_FRAME = RESET_FRAME - 10
}

sub SetVideoAttributes() {
  CopyHighFrameNumber()
  if IS_STD_VIDEO { TrampCallSTD(&stB_SetVideoAttributeSTD) }
  if IS_SPI_VIDEO { SetVideoAttributes_SPI() }
  CURFRAME_ZERO()
  MAKE_WIDE_SCREEN = (VideoHeader.SHint=='W')
  K_TYPE = (VideoHeader.SHint=='K')
  IS_TALL_VIDEO = (VideoHeader.SHint=='T')
  ; VIDKIT 2.1: HINT "A" = true display aspect, stored as a CBM float in Extra[1..5] ($051A).
  ; Bitmap videos only (the Movie Maker never writes "A" for sprite videos; if one turns up it is shown as before).
  HAS_ASPECT = (VideoHeader.SHint=='A') and not IS_SPRITE_VIDEO
}


sub DO_RESET_MEDIA() -> bool {
    if IS_PCM_ONLY { return PCM_EOF }
    FLOAT_TO_INT32(Frame, &cx16.r5)
    return (peekl(&cx16.r5) > RESET_FRAME)
}

sub Close_VIDEOLFNS() {
    cbm.CLRCHN()
    cbm.CLOSE(VideoLFN)
    if AudioLFN !=VideoLFN { cbm.CLOSE(AudioLFN) }
}

sub CHECK_IS_DIRECT() -> bool {
   return ((VideoHeader.VTYPE>20 and VideoHeader.VTYPE<24) or (VideoHeader.VTYPE>25 and VideoHeader.VTYPE<29))   ; 21,22,23 / 26,27,28
}

sub CHECK_IS_STANDARD() -> bool {
    return ((VideoHeader.VTYPE==1) or (VideoHeader.VTYPE==3) or (VideoHeader.VTYPE==6) or (VideoHeader.VTYPE==8) or VideoHeader.VTYPE==2 or VideoHeader.VTYPE==7)
}

sub CHECK_SEP_AUDIO() -> bool {
  return ((VideoHeader.VTYPE<4) or (VideoHeader.VTYPE>20 and VideoHeader.VTYPE<24))   ; 1-3, 21-23
}

sub CHECK_SPRITE_VIDEO() -> bool {
   return ((VideoHeader.VTYPE==1) or (VideoHeader.VTYPE==6) or (VideoHeader.VTYPE==2) or (VideoHeader.VTYPE==7) or (VideoHeader.VTYPE==21) or (VideoHeader.VTYPE==26) or (VideoHeader.VTYPE==22) or (VideoHeader.VTYPE==27))
}

sub CHECK_BITMAP_VIDEO() -> bool {
   return ((VideoHeader.VTYPE==3) or (VideoHeader.VTYPE==8) or (VideoHeader.VTYPE==23) or (VideoHeader.VTYPE==28))
}

sub PARSE_VideoHeader() -> bool {
   MAKE_ALL_FALSE()
   if VideoHeader.ID[0]==FILEID[0] and VideoHeader.ID[1]==FILEID[1] and VideoHeader.ID[2]==FILEID[2] and VideoHeader.ID[3]==FILEID[3] {
      IS_VIDEO = true
      F_FPS = VideoHeader.FPS as float
      NumFrames = (65536.0 * VideoHeader.NumFramesHI as float) + VideoHeader.NumFramesLO as float
      if VideoHeader.XAUD_FLAG == 'X' {
         PCM_IS_16BIT = (( VideoHeader.XCFG_BYTE & %00100000 ) == %00100000 )
         PCM_IS_STEREO = (( VideoHeader.XCFG_BYTE & %00010000 ) == %00010000 )
         if VideoHeader.X_F_FPS > 0 { F_FPS = VideoHeader.X_F_FPS as float / 100.0 }
       }
      TRUE_FPS = F_FPS
      VID_HAS_PALETTE = true
      if ((VideoHeader.VTYPE==2) or (VideoHeader.VTYPE==7) or (VideoHeader.VTYPE==22) or (VideoHeader.VTYPE==27)) {
         VID_HAS_PALETTE = false
         FIND_PAL_FILE()
      }
      IS_SPI_VIDEO = CHECK_IS_DIRECT()
      IS_STD_VIDEO = CHECK_IS_STANDARD()
      IS_SPRITE_VIDEO = CHECK_SPRITE_VIDEO()
      IS_BITMAP_VIDEO = CHECK_BITMAP_VIDEO()
      AUDIO_TRACK_IN_SEPERATEFILE = CHECK_SEP_AUDIO()
      IS_SUPPORTED_VIDEO = (IS_SPI_VIDEO or IS_STD_VIDEO)
    }
   success = IS_SUPPORTED_VIDEO
   return IS_VIDEO
}

sub ReadIn_VideoHeader() {
    cbm.CHKIN(VideoLFN)
    for i in 0 to 31 { vHeader[i] = cbm.GETIN2() }
    cbm.CLRCHN()
}

sub OpenVideo() {
    fopen(VideoLFN, drivenumber , VideoLFN, VIDFILE)
    ReadIn_VideoHeader()
    if PARSE_VideoHeader() { SetVideoAttributes() } else { %asm {{ sec }} }
}


sub DO_PLAYVIDEO_SPI() {
    cx16.i2c_write_byte($42,$05, $FF)   ; Turn on the (disc) Activity Light
    PlayVideo_SPI()
    cx16.i2c_write_byte($42,$05, $00)   ; Turn OFF the (disc) Activity Light
}

sub SETUP_PLAY_PCMSTREAM() {
    TrampCallSTD(&stB_SETUP_PCMPLAY)
}

sub CLONE_NAMES() {
    TrampCallSTD(&stB_CLONENAMES)
}

sub PrepareVideoPlay() {
    if IS_STD_VIDEO {
       PrepareSTDVideoPlay()  ; in mid bank
   }

   if IS_SPI_VIDEO {
      if IS_SPRITE_VIDEO {
         PrepareSTDVideoPlay()   ; palette for 22 & 27 (PAL file or default); graphics/text layers stay untouched
      } else {
         ClearGraphBuffer()
         hideTextLayer()
         showGraphicsLayer()
      }
    }
}

sub DO_FILENAME_PROCESSING() {
    GrabBaseName()
    MAKE_ALL_FALSE()
    strings.copy(BASENAME, VIDFILE)
    strings.append(VIDFILE,VEXT)
    VID_FILE_FOUND = FExists(VIDFILE,strings.length(VIDFILE))
    if not VID_FILE_FOUND { FIND_AUDIO_FILE() }
    CLONE_NAMES()
}

sub GrabBaseName() {
    cx16.r2 = $BF00
    for cx16.r12L in 0 to 94 {
        i = cx16.fetch(lsb(&cx16.r2), 0, cx16.r12L)
        if i==0 { break }
        BASENAME[cx16.r12L] = i
      }
    BASENAME[cx16.r12L]=0
}

sub CLOSE_MEDIA() {
    Close_VIDEOLFNS()
    MAKE_ALL_FALSE()
}

sub PrepFile() {
    DO_FILENAME_PROCESSING()
SkipFileName:
    if VID_FILE_FOUND or PCM_FILE_FOUND {
       DiskFastMode()
       SCREEN_IS_SET = false
       if VID_FILE_FOUND { OpenVideo() }

       if IS_PCM_ONLY {
          OpenAudioFile(FOUND_EXT)
          PCM_EOF = false
          if IS_Z_FILE {
             Read_ZCM_HEADER(AudioLFN)
             success = VERIFY_ZCM_HEADER()
          }
          if IS_WAV_FILE {
             Read_WAV_HEADER(AudioLFN)
             PARSE_WAV_HEADER()
          }
         if success { GetPCM_ByteRate() SETUP_PLAY_PCMSTREAM() } else { %asm {{ sec }} goto pf_end }
       }
  }
    READY_TO_PLAY = (VID_FILE_FOUND and IS_SUPPORTED_VIDEO) or (IS_PCM_ONLY and success)
    if PENV.IS_HOST {
       if IS_SPI_VIDEO { READY_TO_PLAY=false }
    }
pf_end:
   if READY_TO_PLAY { %asm {{ clc }} } else { %asm {{ sec }} }
}

sub PlayFilePOST() {
     Volume = AUDIO_CTRL & $0F
     if IS_VIDEO {
        CURFRAMEINT_TOFLOAT()
        CopyHighFrameNumber()
     }
     if DISABLE_RESTORE or IS_PCM_ONLY { %asm {{nop}} } else { Restore_Screen() }
     if KEEP_OPEN {
      if DO_RESET_MEDIA() {
        if IS_SPI_VIDEO
         { %asm {{ jsr p8s_CALC_FILE_STARTUP_SECTORS.p8l_SETSTART }}
           CURFRAME_ZERO()
           CopyHighFrameNumber()
         } else { Close_VIDEOLFNS()  %asm {{ jsr p8s_PrepFile.p8l_SkipFileName }} }
      } else {
         %asm {{ stz p8v_DO_BUFFER_AUDIO }}
         if IS_SPI_VIDEO {
            vk_FAC = Frame
            TrampCallSPI($B40C)
      }
     } } else { Close_VIDEOLFNS() }
     %asm {{ clc }}
}


sub PlayFile() {
   if READY_TO_PLAY {
     if not IS_PCM_ONLY {
        PrepareVideoPlay()
        setPlayerScreen()
        SCREEN_IS_SET = true
     }
     if IS_STD_VIDEO or IS_PCM_ONLY {
        PlayVideo_STD(mkword(VERAcfgvar,VideoHeader.VERARate))
     }
     if IS_SPI_VIDEO { DO_PLAYVIDEO_SPI() }
     PlayFilePOST()
   }
    else { %asm {{ sec }} }
}

sub PLAY_TO_TIMER() {
   if READY_TO_PLAY {
      if not IS_PCM_ONLY {
        PrepareVideoPlay()
        setPlayerScreen()
        SCREEN_IS_SET = true
      }
      if IS_STD_VIDEO or IS_PCM_ONLY {
         TrampCallSTD(&stB_PLAY_TO_TIMER)
      }
      if IS_SPI_VIDEO { TrampCallSPI(&spB_PLAY_TO_TIMER) }
      PlayFilePOST()
   } else { %asm {{ sec }} }
}


sub GRABPlayMedia()     {
    PrepFile()
    PlayFile()
}

asmsub SET_KEYEXTRA(ubyte TheKey @A) {
   %asm {{
      sta p8v_KEY_EXTRA
      rts
   }}
}

asmsub CLEAR_KEYEXTRA() {
  %asm {{
     stz p8v_KEY_EXTRA
     rts
  }}
}

}
