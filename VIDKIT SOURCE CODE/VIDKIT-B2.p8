%address $AA00
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


; VIDKIT-B2 code is in the same bank as STDVID.ENGINE and
; does not have to change banks or use Trampoline to
; call Code in STDVID.ENGINE !

main {
%jmptable (
         VIDKIT.PrepareSTDVideoPlay,
         VIDKIT.RESTORE_LINES,
         VIDKIT.SetVideoAttributes_STD,
         VIDKIT.setup_SpriteGrid,
         VIDKIT.SETUP_PLAY_PCMSTREAM,
         VIDKIT.DO_FILENAME_CLONING,
         VIDKIT.Restore_Screen,
         VIDKIT.PLAY_TO_TIMER,
         VIDKIT.HookControls,
         VIDKIT.HookControl1,
         VIDKIT.HookControl2,
         VIDKIT.ResetControls
      )

; PrepareSTDVideoPlay ; $AA03
; RESTORE_LINES ; $AA06
; SetVideoAttributes_STD ; $AA09
; setup_SpriteGrid ; $AA0C
; SETUP_PLAY_PCMSTREAM ; $AA0F
; DO_FILENAME_CLONING ; AA12
; Restore_Screen ; $AA15
; PLAY_TO_TIMER ; $AA18
; HookControls $AA1B
; HookControl1 $AA1E
; HookControl2 $AA21
; ResetControls $AA24

 sub start() {
    VIDKIT.ORG_ISR = VIDKIT.CINV
    VIDKIT.MYBANK = @(0)
    VIDKIT.PARENT_BANK = VIDKIT.MYBANK-1
    VIDKIT.SCR_SAVEMODE,void,void = cx16.get_screen_mode()
    VIDKIT.CHARSET_SAVE = @($372) & %00001111
    VIDKIT.DISABLE_RESTORE = false
    VIDKIT.NO_SCREENCHANGE = false
    VIDKIT.LOCK_KEYS = false
    VIDKIT.KEEP_OPEN = false
    VIDKIT.LOOP_ON = false
    VIDKIT.LOOP_FLAG = false
    VIDKIT.PAL_RESET = true
      VIDKIT.Frame = 0.0
     VIDKIT.BFrame = VIDKIT.Frame
    VIDKIT.drivenumber = 8
    VIDKIT.DISK_FASTMODE()
 }
}


VIDKIT  {

; STD ENGINE ROUTINES
extsub $A000 = PlayVideo_STD(uword PCMParms @ R0) clobbers(A,X,Y)

; Clears TextBuffer at 1:$B000, GraphBuffer at 0:$0000 and the Sprite Data Buffer at 1:$3000
; (fills with 0)
extsub $A003 = ClearAllBuffers() clobbers(A,X,Y)
extsub $A006 = Engine_SetAudioCode(uword AudParms1 @R0, uword AudParms2 @R1, ubyte AbuffRem @R2 ) clobbers(A)
extsub $A009 = SetSpriteMovie8bit(uword BuffSizes @R3, ubyte SpriteCount @R4, uword EndSprAttrs @R5, uword EndSprData @R6 ) clobbers(A,X)
extsub $A00C = SetSpriteMovie4bit(uword BuffSizes @R3, ubyte SpriteCount @R4, uword EndSprAttrs @R5, uword EndSprData @R6 ) clobbers(A,X)
extsub $A00F = SetBitMapMovie(uword BuffSizes @R3, ubyte WidthByte @R2, ubyte PaletteSize @R4) clobbers(A,X)
extsub $A012 = SET_FRAME_DRIVER(uword DriverAddr @ XY)

; Clears the Graphics Buffer at 0:0000 for 76800 bytes.  (execution time app. 2.7 jiffies)
extsub $A015 = ClearGraphBuffer() clobbers(A,X,Y)
; basically CLS (but always to color 0).  Not sure there's an advantage here but it is also
; called by the Above ClearAllBuffers.
extsub $A018 = ClearTextBuffer() clobbers(A,X,Y)

; Clears the Sprite Buffer at 1:$3000
extsub $A01B = ClearSpriteBuffer() clobbers(A,X,Y)

extsub $A021 = SET_PCM_ONLY() clobbers(A,X)
; Only valid value to pass at the moment is 4 which aligns with the Video LFN for
; Video type 6 & 8 (with embedded Audio).
; eventually both LFN's will be assignable.   For NOW video LFN is 4
; Audio LFN if a seperate file is 6 (same as Vid LFN if embedded)
extsub $A01E = SetAudioLFN(ubyte AudLFN @R0) clobbers(A)

extsub $A024 = HIDEALLSPRITES() clobbers(A,X)
extsub $A024 = HIDESPRITES() clobbers(A,X)

; Decrements all RGB Values in the VERA Palette towards 0 individually by 1.
; If DOBLUE is true then the B value is instead shifted towards $F by 1
extsub $A027 = PALSHIFT() clobbers(A,X,Y)
extsub $A02A = SET_DEFAULT_PALETTE() clobbers(A,X,Y)
extsub $A02A = SetDefaultPalette() clobbers(A,X,Y)
extsub $A02D = SETEXTERNAL_CONTROLS() clobbers(X,Y)
extsub $A030 = TURN_OFF_PALETTE_HANDLING() clobbers(A)
extsub $A033 = TURN_ON_PALETTE_HANDLING() clobbers(A)
extsub $A036 = DISK_FASTMODE() clobbers(A,X,Y)
extsub $A039 = FADE2BLACK() clobbers(A,X,Y)
extsub $A03C = pal2black() clobbers(A,X)
extsub $A042 = setControl1(uword addr @R7)
extsub $A045 = setControl2(uword addr @R8)
extsub $A048 = SET_Default_CONTROLS_std()

; END STANDARD ENGINE ROUTINES

; &ubyte[4] AUD_LEAD_START = $BFA0

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
str MEDIA_EXT = ".XXXXXX"
str FOUND_EXT = ".XXXXXX"

ubyte i=0
ubyte j=0
ubyte PARENT_BANK
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

float NumFrames = 0.0
float AudFileSize = 0.0
float vidFilePosition

; SPI - Bank addresses
; jmp setControls              ;SYS $A027
; jmp setControl1              ;SYS $A02A
; jmp setControl2              ;SYS $A02D
; jmp SET_DEFAULT_CONTROLS     ;SYS $A030

sub HookControls() {
; Valid low RAM procedure address expected in
; R7 for Control1 & R8 for Control2
    ; First do the Trampoline calls and set the SPI Targets
    Trampoline_BANK_Target = MYBANK + 1
    Trampoline_JSR_Target = $A027
    Trampoline()
    ; Then call the routines in THIS Bank.
    %asm {{
       jsr p8s_setControl1
       jsr p8s_setControl2
    }}
}

sub ResetControls() {
    Trampoline_BANK_Target = MYBANK + 1
    Trampoline_JSR_Target = $A030
    Trampoline()
    SET_Default_CONTROLS_std()
}

sub HookControl1() {
    Trampoline_BANK_Target = MYBANK + 1
    Trampoline_JSR_Target = $A02A
    Trampoline()
    %asm {{ jsr p8s_setControl1 }}
}

sub HookControl2() {
    Trampoline_BANK_Target = MYBANK + 1
    Trampoline_JSR_Target = $A02D
    Trampoline()
    %asm {{ jsr p8s_setControl2 }}
}

long TimerTarget

sub CheckTimer() {
    if cbm.RDTIML() > TimerTarget { PlayDone = $FF }
    ; rom kbdbuf_peek
    %asm {{ jmp $FEBD }}
}


sub PLAY_TO_TIMER() {
&long tpassed = $0A
    TimerTarget = tpassed
    setControl1(&CheckTimer)
    cbm.SETTIML(0)
    PlayVideo_STD(mkword(VERAcfgvar,VideoHeader.VERARate))
    setControl1($FEBD)
}


sub FrameDoNothing() {
    SET_FRAME_DRIVER(&DoNothing)
}

sub Restore_Screen() {
    SCREEN_IS_SET = false
    if MAKE_WIDE_SCREEN or K_TYPE or HAS_ASPECT { RESTORE_LINES() }
    HIDEALLSPRITES()
    HideBothLayers()
    cx16.set_screen_mode(SCR_SAVEMODE)
    if (CHARSET_SAVE > 12) or (CHARSET_SAVE==0) {CHARSET_SAVE=2}
    if (CHARSET_SAVE==1) or (CHARSET_SAVE>5) {cbm.CHROUT(15)} else {cbm.CHROUT($8E)}
    ; reload the appropriate Saved CHARSET
    %asm {{
      lda p8v_CHARSET_SAVE
      jsr $FF62
    }}
    ; FixCursor
    if (CHARSET_SAVE==1) or (CHARSET_SAVE > 5) { Trampoline_JSR_Target=$A024 Trampoline_BANK_Target=@(0)+1 Trampoline() }
    cx16.VERA_DC_VIDEO = SAVE_DC_VIDEO
    showTextLayer()
    if PAL_RESET { SetDefaultPalette() }
}

sub RESTORE_LINES() {
  %asm {{
    lda #2
    sta $9F25
    stz $9F2B
    lda #240
    sta $9F2C
    stz $9F29
    lda #160
    sta $9F2A
    stz $9F25
  }}
    ; poke($9F25,2)
    ; poke($9F2B,0)
    ; poke($9F2C,240)
    ; poke($9F29,0)
    ; poke($9F2A,160)
    ; poke($9F25,0)
    if VideoHeader.BPP < 8 {
       ;poke($9F2C,0)
       %asm {{ stz $9F2C }}
    }
}

sub bload(str filename,ubyte bank, uword addr @ R0)  {
ubyte OB
    %asm {{
           ldx 2
           ldy 3
           phy
           phx
         }}
    cbm.SETNAM(strings.length(filename), filename)
    %asm {{
           lda #0
           ldx p8v_drivenumber
           ldy #2
           jsr cbm.SETLFS
         }}
    OB = peek(0)
    cx16.rambank(bank)
    %asm {{
            plx
            ply
            lda #0
            jsr cbm.LOAD
        }}
     cx16.rambank(OB)
}

sub DO_VLOAD() {
    while cbm.READST() == 0 {
      %asm {{
             sec
             lda #0
             ldx #$23
             ldy #$9F
             jsr cx16.MACPTR
           }}
     }
   cbm.CLRCHN()
   cbm.CLOSE(7)
}

sub DO_VOPEN(str VFILE) {
    fopen(7,drivenumber,7,VFILE)
    cbm.CHKIN(7)
}

sub LoadVERAPalette(str PFILE, ubyte StartIndx) {
   uword VAddr
   VAddr = $FA00 + ((StartIndx as uword) * 2)
   DO_VOPEN(PFILE)
   cx16.VERA_ADDR_L = lsb(VAddr)
   cx16.VERA_ADDR_M = msb(VAddr)
   cx16.VERA_ADDR_H = %00010001
   DO_VLOAD()
}

asmsub DoNothing() {
  %asm {{
          nop
          rts
       }}
}

asmsub Flush15() clobbers(A,X,Y) {
  %asm {{
          ldx #15
          jsr cbm.CHKIN
          jmp p8s_FExists.flushchars
       }}
}

asmsub FExists(uword FName @ XY, ubyte NameLength @ A) clobbers(A,X,Y) -> bool @Pc  {
   %asm  {{
             jsr cbm.SETNAM
             lda #11
             ldx p8v_drivenumber
             ldy #0
             jsr cbm.SETLFS
             jsr cbm.OPEN
             lda #11
             jsr cbm.CLOSE
             lda #0
             ldx #<dummy
             ldy #>dummy
             jsr cbm.SETNAM
             lda #15
             ldx p8v_drivenumber
             ldy #15
             jsr cbm.SETLFS
             jsr cbm.OPEN
             ldx #15
             jsr cbm.CHKIN
             jsr cbm.GETIN
             cmp #"0"
             bne NotFound
             jsr cbm.GETIN
             cmp #"0"
             beq Found
NotFound:    jsr flushchars
             clc
             rts
Found:       jsr flushchars
             sec
             rts
flushchars:  jsr cbm.GETIN
             cmp #13
             bne flushchars
             lda #15
             jsr cbm.CLOSE
             jsr cbm.CLRCHN
             jmp cbm.READST
dummy        .byte 0
; !notreached!
          }}
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

sub FIND_PAL_FILE() {
    PAL_FILE_FOUND = FExists(PALFILE,strings.length(PALFILE))
    return
}

sub ISOUpper(str s) {
  i=0
  while s[i] != 0 {
      if s[i] > 96 and s[i]<123 { s[i] -= 32 }
      i+=1
    }
}

sub BlankPAL_LAST32() {
    cx16.VERA_ADDR_L = $C0
    cx16.VERA_ADDR_M = $FB
    cx16.VERA_ADDR_H = %00010001
    repeat 16 { unroll 4 { %asm {{ stz $9F23 }} } }
}



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

sub HideBothLayers() {
    hideGraphicsLayer()
    hideTextLayer()
}

sub ShowBothLayers() {
    showGraphicsLayer()
    showTextLayer()
}

sub setMovieVideoMode() {
    if IS_SPRITE_VIDEO { return }
    if VideoHeader.FrameWidth==320 {
      cx16.set_screen_mode($80) }
    else {
      cx16.set_screen_mode(0)
    }
 }

sub spr_init(ubyte spritenum,
             ubyte databank, uword dataaddr,
             ubyte width_flag, ubyte height_flag,
             ubyte colors_flag, ubyte palette_offset,bool show) {
        sprites.pos(spritenum, -64, -64)                    ; move sprite off-screen initially
        if not show { cx16.vpoke(1, sprite_reg+6, %00000000) }                     ; z depth %11 = in front of both layers, no flips
        cx16.VERA_DC_VIDEO |= %01000000             ; enable sprites globally
        dataaddr >>= 5
        dataaddr |= (databank as uword)<<11
        uword sprite_reg = sprites.VERA_SPRITEREGS + spritenum*$0008
        cx16.vpoke(1, sprite_reg, lsb(dataaddr))                    ; address 12:5
        cx16.vpoke(1, sprite_reg+1, colors_flag | msb(dataaddr))    ; 4 bpp + address 16:13
        if show { cx16.vpoke(1, sprite_reg+6, %00001100) }          ; z depth %11 = in front of both layers, no flips
        cx16.vpoke(1, sprite_reg+7, height_flag<<6 | width_flag<<4 | palette_offset&15) ; 64x64 pixels, palette offset
    }

sub setup_SpriteGrid(word X @R7, word Y @R9) {
    ubyte sprWidByte
    ubyte sprHeiByte
    ubyte sprBank2
    alias X1 = cx16.r5
    alias Y1 = cx16.r6
    ubyte sprPal1 = 0
    ubyte sprPal2 = 0
    ubyte sprDepth = 128
    ubyte sprNum = 1
    ubyte sprBank = 0
    X1  = X as uword
    Y1  = Y as uword
    word XLimit = (X + VideoHeader.FrameWidth) as word
    uword sprBlock1Addr = SpriteOrigAddress
    uword sprBlock2Addr = SpriteBlock2_DataAddress
    uword BuffAdd = (VideoHeader.SpriteWidth as uword * VideoHeader.SpriteHeight as uword)

    if VideoHeader.BPP==4 {
       sprDepth = 0
       if VID_HAS_PALETTE {
          sprPal1 = 14
          sprPal2 = 15
       } else
         {
          if PAL_FILE_FOUND { sprPal1 = 15 } else { sprPal1 = 1 }
          sprPal2 = sprPal1
         }
       sprBank=1
       BuffAdd=BuffAdd/2
     }

   if VideoHeader.SpriteWidth==64 { sprWidByte=sprites.SIZE_64 }
   if VideoHeader.SpriteWidth==32 { sprWidByte=sprites.SIZE_32 }
   if VideoHeader.SpriteWidth==16 { sprWidByte=sprites.SIZE_16 }
   if VideoHeader.SpriteWidth==8 { sprWidByte= sprites.SIZE_8 }

   if VideoHeader.SpriteHeight==64 { sprHeiByte=sprites.SIZE_64 }
   if VideoHeader.SpriteHeight==32 { sprHeiByte=sprites.SIZE_32 }
   if VideoHeader.SpriteHeight==16 { sprHeiByte=sprites.SIZE_16 }
   if VideoHeader.SpriteHeight==8 { sprHeiByte=sprites.SIZE_8 }

   bool hb = VideoHeader.VTYPE > 20             ; high bandwidth sprite types: layout comes from SPIVID.ENGINE
   if hb {
      NumSprites = HB_NUMSPR
      sprBlock1Addr = mkword(HB_MID1, 0)
      sprBlock2Addr = mkword(HB_MID2, 0)
      sprBank = HB_BANK1
      sprBank2 = HB_BANK2
      if HB_HIDE_TEXT != 0 { hideTextLayer() }
      ; sector (HB) videos: encoder puts frame 0's palette in row 14 and frame 1's in row 15, and frame 0
      ; is loaded into buffer 2 -> buffer 2 uses row 14, buffer 1 uses row 15 (STD sprites are the other way round)
      if VideoHeader.BPP==4 and VID_HAS_PALETTE { sprPal1 = 15 sprPal2 = 14 }
   } else { sprBank2 = sprBank }
   repeat NumSprites {
         sprites.init(sprNum, sprBank, sprBlock1Addr, sprWidByte, sprHeiByte, sprDepth, sprPal1)
         sprites.pos(sprNum, X1 as word,Y1 as word)
         sprites.init((sprNum+NumSprites) as ubyte, sprBank2, sprBlock2Addr, sprWidByte, sprHeiByte, sprDepth, sprPal2)
         sprites.pos((sprNum+NumSprites) as ubyte, X1 as word,Y1 as word)
         sprNum = sprNum+1
         X1 = X1 + VideoHeader.SpriteWidth
         if X1>=XLimit {X1=X as uword
                        Y1=(Y1+VideoHeader.SpriteHeight) as word }
         if hb {
            sprBlock1Addr += BuffAdd
            if sprBlock1Addr < BuffAdd { sprBank += 1 }     ; carry into the next 64K bank
            sprBlock2Addr += BuffAdd
            if sprBlock2Addr < BuffAdd { sprBank2 += 1 }
         } else {
            sprBlock1Addr = sprBlock1Addr + BuffAdd
            if sprBlock2Addr >= (65535 - BuffAdd) and (sprBank2==0) {
                sprBlock2Addr = 512
                sprBank2 = 1
              }  else {
                sprBlock2Addr = sprBlock2Addr + BuffAdd
              }
         }
     }
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

sub CURFRAMEINT_TOFLOAT() {
    Frame = (FRAME_CURRENT[0] as float) + (256.0 * FRAME_CURRENT[1] as float) + (65536.0 * FRAME_CURRENT[2] as float)
}

sub CURFRAMEFLOAT_TOINT() {
    tmpf = floats.floor((Frame / 65536.0))
    FRAME_CURRENT[2] = tmpf as ubyte
    tmpw = ( Frame - (tmpf * 65536.0) ) as uword
    FRAME_CURRENT[1] = msb(tmpw)
    FRAME_CURRENT[0] = lsb(tmpw)
}

sub CURFRAME_ZERO() {
    Frame = 0
    FRAME_CURRENT[0] = 0
    FRAME_CURRENT[1] = 0
    FRAME_CURRENT[2] = 0
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

sub CalculateSprites()  {
    NumSprites = (VideoHeader.FrameWidth/VideoHeader.SpriteWidth) * (VideoHeader.FrameHeight/VideoHeader.SpriteHeight)
    SpriteOrigAddress = 0
    SpriteBuffSize = VideoHeader.SpriteHeight as uword * VideoHeader.SpriteWidth as uword
    if VideoHeader.BPP==4 { SpriteBuffSize = SpriteBuffSize/2
                SpriteOrigAddress = $3000}
    SpriteAttr_EndAddress = $FC06 + (NumSprites*16)
    SpriteBlock2_DataAddress = SpriteOrigAddress + FrameBufferSize
    if VideoHeader.BPP==8 { SpriteBlock2_DataAddress = SpriteBlock2_DataAddress + 512 }
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

sub hFullScale(uword HRes) -> ubyte {
  tmpf = floats.floor((HRes as float/640.0) * 128.0)
  return tmpf as ubyte
}

sub vFullScale(uword VRes) -> ubyte {
  if MAKE_WIDE_SCREEN { tmpf2 = 360.0 } else { tmpf2 = 480.0 }
  tmpf = floats.floor((VRes as float/tmpf2) * 128.0)
  return tmpf as ubyte
}

sub read4hex() -> uword {
    str hex = "0000"
    for cx16.r4L in 0 to 3 {
        hex[cx16.r4L] = cbm.CHRIN()
    }
    return conv.hex2uword(hex)
}

sub my_f_tell(ubyte channel) {
        ; gets the (32 bits) position + file size of the opened read file channel
        ubyte[2] command = ['T',0]
        command[1] = channel       ; f_open uses this secondary address
        cbm.SETNAM(sizeof(command), &command)
        cbm.SETLFS(15, drivenumber, 15)
        void cbm.OPEN()
        void cbm.CHKIN(15)        ; use #15 as input channel
        success=false
        ; valid response starts with "07," followed by hex notations of the position and filesize
        if cbm.CHRIN()=='0' and cbm.CHRIN()=='7' and cbm.CHRIN()==',' {
            cx16.r1 = read4hex()
            cx16.r0 = read4hex()        ; position in R1:R0
            void cbm.CHRIN()            ; separator space
            cx16.r3 = read4hex()
            cx16.r2 = read4hex()        ; filesize in R3:R2
            success = true
        }
        %asm {{ jmp p8s_Flush15 }}
    }

sub f_seek(ubyte channel, float seekpos) {
        ; gets the (32 bits) position + file size of the opened read file channel
        cx16.r2 = floats.floor(seekpos/65536.0) as uword
        cx16.r1 = (seekpos - (cx16.r2 as float * 65536.0)) as uword
        cx16.r0 = mkword(channel,'P')   ; complete building the P command
        cbm.SETNAM(6, &cx16.r0)
        cbm.SETLFS(15, drivenumber, 15)
        void cbm.OPEN()
        void cbm.CHKIN(15)        ; use #15 as input channel
        %asm {{
              jmp p8s_Flush15
            }}
       }

bool tmpB
bool tmpB2

float AudioByteRate
float AudioHeaderSize

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


ubyte APreLoops

sub SetVideoAttributes_STD() {
    if VideoHeader.VTYPE < 4 {
       OpenAudioFile(AEXT)
       VideoHeader.AudioFrameSize=calc_asize(AudFileSize, NumFrames)
       VideoHeader.VERARate = CalculateVERARate()
       SetAudioLFN(AudioLFN)
    }
    ; CalcTrueFPS()
    XOrg = 0
    YOrg = 0

    ABuff_255 = (VideoHeader.AudioFrameSize / 255 ) as ubyte
    ABuff_Remainder = (VideoHeader.AudioFrameSize - (ABuff_255 as uword * 255)) as ubyte

    VIDEOFILE_LEAD = 32.0

    if ABuff_Remainder==0 { ABuff_255 -= 1 ABuff_Remainder=255 }  ; adjust for rare case where AFrame is evenly divisible by 255

    CalcFrameSize()
    VBuff_255 = (FrameBufferSize / 255 ) as ubyte
    VBuff_Remainder = (FrameBufferSize - (VBuff_255 as uword * 255)) as ubyte

    if IS_SPRITE_VIDEO { CalculateSprites() }

    if (VideoHeader.AudioFrameSize<2048) { DO_BUFFER_AUDIO=true } else { DO_BUFFER_AUDIO=false }

    Engine_SetAudioCode(mkword(ABuff_255,0), mkword(ABuff_255, ABuff_Remainder), ABuff_Remainder)

    VFRAME_MUL = FrameBufferSize  + PalBufferSize as float

    if VideoHeader.VTYPE==6 or VideoHeader.VTYPE==7 or VideoHeader.VTYPE==8 {
       SetAudioLFN(VideoLFN)
       VFRAME_MUL=VFRAME_MUL + VideoHeader.AudioFrameSize as float
       if (VideoHeader.AudioFrameSize<2048) { VIDEOFILE_LEAD = VIDEOFILE_LEAD + VideoHeader.AudioFrameSize as float }
    }

    if IS_SPRITE_VIDEO {
         if VideoHeader.BPP==4 { SetSpriteMovie4bit(mkword(VBuff_Remainder,VBuff_255), NumSprites as ubyte, SpriteAttr_EndAddress, SpriteBlock2_DataAddress) }
         if VideoHeader.BPP==8 { SetSpriteMovie8bit(mkword(VBuff_Remainder,VBuff_255), NumSprites as ubyte, SpriteAttr_EndAddress, SpriteBlock2_DataAddress) }
    }

    if IS_BITMAP_VIDEO {
    ubyte WidthVal = 0
          if VideoHeader.FrameWidth==640 { WidthVal=1 }
          SetBitMapMovie(mkword(VBuff_Remainder,VBuff_255), WidthVal, PalBufferSize as ubyte)
    }
  READY_TO_PLAY = true
  %asm {{ clc }}
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

sub SETUP_PLAY_PCMSTREAM() {
    SetAudioLFN(AudioLFN)
    SET_PCM_ONLY()
    SET_FRAME_DRIVER(&DoNothing)
}

sub PrepareSTDVideoPlay() {
    VERAcfgvar = 0
    if VideoHeader.XAUD_FLAG == 'X' { VERAcfgvar = (VideoHeader.XCFG_BYTE & %00110000) }
    if VID_HAS_PALETTE {
        TURN_ON_PALETTE_HANDLING()
    } else {
        TURN_OFF_PALETTE_HANDLING()
         if PAL_FILE_FOUND
          {
            if VideoHeader.BPP==4
               { LoadVERAPalette(PALFILE, $F0) }
            else
               { LoadVERAPalette(PALFILE,0) }
            }
          else { SetDefaultPalette() }
     }
}


bool EXTENSION_FOUND
ubyte DotPOS
sub TEST_EXTENSION(str TEST) -> bool {
ubyte eLength
    DotPOS, void = strings.find(TEST,'.')
    if DotPOS < 255 {
       eLength = strings.length(TEST) - DotPOS
       if eLength < 8 {
          strings.right(TEST,eLength,MEDIA_EXT)
          TEST[DotPOS]=0
          return true
       }
    }
 MEDIA_EXT[0] = 0
 return false
}

sub DO_FILENAME_CLONING() {
    GrabBaseName()
    ISOUpper(BASENAME)
    EXTENSION_FOUND = TEST_EXTENSION(BASENAME)
    strings.copy(BASENAME, VIDFILE)
    strings.copy(BASENAME, AUDFILE)
    strings.copy(BASENAME, PALFILE)
    strings.append(PALFILE,".PAL")
    strings.append(AUDFILE,AEXT)
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



}
