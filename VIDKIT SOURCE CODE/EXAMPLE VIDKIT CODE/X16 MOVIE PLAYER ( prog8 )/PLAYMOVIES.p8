%option no_sysinit
%import textio
%import conv
%import diskio
%import strings
%import sprites
%import floats
%import verafx
%import VIDKIT_COMMON
%import MEDIAPICK
%encoding iso
%zeropage basicsafe
%zpreserved $22, $60


ROM {
      ubyte VERSION
      bool  IsPreRelease
}


PENV {
           str HOST = "?"*5
           str PETSCII_VERSTR="\x99 2\x1E.\x990"
           str  ISOASC_VERSTR="\x99 2\x1E.\x990"
           str    CPU="\x9B65\x99C\x9B02"
           uword   cpu=6502
           bool IS_HOST
           bool ON_HARDWARE
           bool ON_EMU

           sub FIND_CPU() { if sys.cpu_is_65816() { strings.copy("\x9B65\x99816",CPU) cpu=816} }
           sub IS_HOST_FS()-> bool {
               ON_EMU = (EMUIndicator==$3631)
               if ON_EMU {
                 cbm.SETNAM(11, "$")
                 cbm.SETLFS(11, 8, 0)
                 cbm.OPEN()
                 cbm.CHKIN(11)
                 ubyte ctr = 0
                 while ctr<2 { if cbm.GETIN2()==34 {ctr++} }
                 void cbm.GETIN2()
                 for ctr in 0 to 3 {HOST[ctr] = cbm.GETIN2()}
                 HOST[4] = 0
                 cbm.CLRCHN()
                 cbm.CLOSE(11)
               }
               return (ON_EMU and (HOST=="HOST"))
             }

&uword EMUIndicator = $9FBE

sub GetRunEnvironment() {
         FIND_CPU()
         ROM.VERSION, ROM.IsPreRelease = cx16.rom_version()
         IS_HOST=IS_HOST_FS()
         ON_HARDWARE = not ON_EMU
     }
}



main  {

      str MY_TITLE = " \x05X16 VIDKIT Movie & Audio Player \x991\x1E.\x990 \x0D\x9B For the \x05Commander \x99X16\x1E. "
      const ubyte _KEY_UP = 145
      const ubyte _KEY_DOWN = 17
      const ubyte _KEY_ESC = 27
      const ubyte _KEY_ENTER = 13
      const ubyte _KEY_F1 = 133
      const ubyte _KEY_F2 = 137
      const ubyte _KEY_F3 = 134
      const ubyte _KEY_F4 = 138
      const ubyte _KEY_F5 = 135
      const ubyte _KEY_F6 = 139
      const ubyte _KEY_F7 = 136
      const ubyte _KEY_F8 = 140
      const ubyte _KEY_F9 = 16
      const ubyte _KEY_F10 = 21
      const ubyte _KEY_F11 = 22
      const ubyte _KEY_F12 = 23
      const ubyte _CTRL_F  = 6
      const ubyte _CTRL_L = 12

      &ubyte[32] vHeader = $500
 &ubyte[3] vHdrNUMFRAMES = $50D
           &ubyte Volume = $520

       &ubyte[8] zHeader = $522
      &ubyte[44] wHeader = $522
   &ubyte[44] AUD_Header = $522

&ubyte AUDIO_CTRL = $9F3B
const uword joystick_get = $FF56


;VKIT:
; %asmbinary "VIDKIT.Z"
;VKIT_END:

titlescreen:
%asmbinary "x16vid.Z"

boingsnd:
%asmbinary "dull.raw"
endboing:

spritelogo1:
%asmbinary "XHD.Z"

spritelogo2:
%asmbinary "X16-64.Z"

spritelogo3:
%asmbinary "AUD64.Z"

spritelogo4:
%asmbinary "NOCAM.Z"

reelsprites:
%asmbinary "REEL.SPRS.Z"
reelend:

; will be set to $FF if Video is exited by the user
 ; in the Bank where the Video Engine code is located
 alias MANEXIT = VIDKIT.MANEXIT

ubyte Pix_Spread
ubyte xSpreads
ubyte ySpreads

alias f_size_low = cx16.r2
alias f_size_high = cx16.r3

ubyte[85] butterfly = [$8F,$93,$9C,$12,$DF,$92,$20,$20,$20,$20,$20,$12,$A9,$0D,$9A,$12,$A5,$DF,$92,$20,$20,$20,$12,$A9,$A7,
                       $92,$0D,$9F,$12,$B5,$20,$DF,$92,$20,$12,$A9,$20,$B6,$0D,$1E,$20,$B7,$12,$BB,$92,$20,$12,$AC,$92,$B7,
                       $0D,$9E,$20,$AF,$12,$BE,$92,$20,$12,$BC,$92,$AF,$0D,$81,$AA,$12,$20,$92,$A9,$20,$DF,$12,$20,$92,$B4,
                       $0D,$1C,$B6,$A9,$20,$20,$20,$DF,$B5,0]

ubyte VID_BANK1
ubyte VID_BANK2
ubyte VID_BANK3

; This section of code is not ALL THE VIDKIT API
; just what I needed for this player of it !
; There is more to the API available.
extsub @bank VID_BANK1 $A000 = VIDKIT_INIT()
extsub @bank VID_BANK1 $A003 = LOAD_PLAY()
extsub @bank VID_BANK1 $A006 = LOAD_MEDIA()
extsub @bank VID_BANK1 $A009 = PLAY_MEDIA()
extsub @bank VID_BANK1 $A00C = SET_START_FRAME()
extsub @bank VID_BANK1 $A01E = CLOSE_MEDIA()
extsub @bank VID_BANK1 $A036 = SET_STARTTIME_JIFFIES()
extsub @bank VID_BANK2 $A012 = SET_FRAME_DRIVER(uword DrivePtr @XY)
extsub @bank VID_BANK2 $A024 = HIDE_SPRITES()
extsub @bank VID_BANK2 $A02A = SetDefaultPalette()
extsub @bank VID_BANK2 $A039 = Fade2Black()
extsub @bank VID_BANK2 $A03C = pal2black()
extsub @bank VID_BANK2 $AA15 = RESTORE_SCREEN()
extsub @bank VID_BANK3 $B412 = FadePal(uword ThePal @R11)
extsub @bank VID_BANK3 $B415 = FadeToDEFPAL()
extsub @bank VID_BANK3 $B418 = Fade2Color(uword PalEntry @R1)
extsub @bank VID_BANK1 $A024 = hideTextLayer()
extsub @bank VID_BANK1 $A02D = showTextLayer()
extsub @bank VID_BANK1 $A02A = ShowBothLayers()
extsub @bank VID_BANK1 $A021 = HideBothLayers()
extsub @bank VID_BANK1 $A03C = VidKitVersion() -> ubyte @A, ubyte @X, bool @Pc
; FadeInPal $B412


&ubyte STASHVEC = $03B2
&ubyte AUDIO_FIFO = $9F3D
&byte AUDIO_FIFOs = $9F3D
&ubyte VERA_AUDIORATE = $9F3C

alias IS_VIDEO = VIDKIT.IS_VIDEO
alias IS_BITMAP_VIDEO = VIDKIT.IS_BITMAP_VIDEO
alias IS_SPRITE_VIDEO = VIDKIT.IS_SPRITE_VIDEO
alias IS_SUPPORTED_VIDEO = VIDKIT.IS_SUPPORTED_VIDEO
alias VID_HAS_PALETTE = VIDKIT.VID_HAS_PALETTE
alias IS_STD_VIDEO = VIDKIT.IS_STD_VIDEO
alias IS_SPI_VIDEO = VIDKIT.IS_SPI_VIDEO
alias AUDIO_TRACK_IN_SEPERATEFILE = VIDKIT.AUDIO_TRACK_IN_SEPERATEFILE
bool VID_FILE_FOUND
alias IS_Z_FILE = VIDKIT.IS_Z_FILE
alias IS_WAV_FILE = VIDKIT.IS_WAV_FILE
alias PCM_FILE_FOUND = VIDKIT.PCM_FILE_FOUND
alias IS_PCM_ONLY = VIDKIT.IS_PCM_ONLY
alias LOOP_PLAY_ON = VIDKIT.LOOP_FLAG
alias MAKE_WIDE_SCREEN = VIDKIT.MAKE_WIDE_SCREEN
alias K_TYPE = VIDKIT.K_TYPE
alias IS_TALL_VIDEO = VIDKIT.IS_TALL_VIDEO
alias HAS_ASPECT = VIDKIT.HAS_ASPECT
alias F_FPS = VIDKIT.F_FPS
alias TRUE_FPS = VIDKIT.TRUE_FPS

bool ShowLoadMessages

alias PCM_IS_STEREO = VIDKIT.PCM_IS_STEREO
alias PCM_IS_16BIT = VIDKIT.PCM_IS_16BIT

alias VERAcfgvar = VIDKIT.VERAcfgvar
ubyte drivenumber
ubyte OB
bool tmpB
bool tmpB2
ubyte printchar
ubyte printlen;
ubyte ppos

ubyte i=0
ubyte j=0
uword tmpw
uword tmpw2

ubyte VideoLFN = 4
ubyte AudioLFN = 6

str FILEID = iso:"SPRV"
str BASENAME = "?"*96
str PAD = " "*4
str VIDFILE = "MOVIE"+"?"*96
str PAD3 = " "*4
str AUDFILE = "?"*96
str TMPFILE = "?"*96
str VEXT = iso:".SPV"
str AEXT = iso:".SVA"
str PEXT = iso:".PRG"
str ZEXT = iso:".ZCM"
str WEXT = iso:".WAV"
str FOUND_EXT = ".XXX" + "?"*6
str AnyMessage = iso:"\x9BAny \x05KEY\x9B to continue\x99."

bool success = false
bool UseBookMark = false


word XOrg = 0
word YOrg = 0

alias NumFramesHI = cx16.r1
alias NumFramesLO = cx16.r2

ubyte VMajor
ubyte VMinor
bool VDevelopment


float Frame = 0.0
float tmpf
float tmpf2
float audFilePosition = 0.0
float AudFileSize = 0.0
float NewAudioPosition = 0.0
float play_total
float play_left
float NumFrames
ubyte HighRAMBank

uword NumSprites
uword SpriteAttr_EndAddress
uword SpriteBlock2_DataAddress
uword FrameBufferSize

float AudioByteRate
uword AudioHeaderSize
 long AudioTimePos
ubyte[4] fsector

sub SET_BANKS() {
    HighRAMBank = (cx16.numbanks() - 1) as ubyte
    VID_BANK1 = HighRAMBank - 4
    VID_BANK2 = VID_BANK1 + 1
    VID_BANK3 = VID_BANK2 + 1
}

sub LOAD_VIDKIT_LIBRARY() {
ubyte EOF
uword Destination
uword BytesWritten
uword ByteCount
uword BytesToGet
ubyte CurBank
bool Error
bool GO

  OB = @(0)
  strings.copy("VIDKIT-A000.BIN", TMPFILE)
  GO = diskio.exists(TMPFILE)
  if not GO {
     strings.copy("ASSETS/VIDKIT-A000.BIN",TMPFILE)
     GO = diskio.exists(TMPFILE)
  }
  if not GO {
     strings.copy("//ASSETS/:VIDKIT-A000.BIN",TMPFILE)     ; ASSETS folder in the root
     GO = diskio.exists(TMPFILE)
  }
  void diskio.status()
  if GO {
     txt.nl()
     txt.print("  LOADING: ") txt.print(TMPFILE)
     SET_BANKS()
     EOF = 0
     CurBank = VID_BANK1
     fopen(7,8,7,TMPFILE)
     cbm.CHKIN(7)
     while EOF==0 {
         cx16.rambank(CurBank)
         Destination = $A000
         ByteCount = 0
         while (ByteCount<8192) and (EOF==0) {
           BytesToGet = (8192 - ByteCount)
           if BytesToGet > 512 { BytesToGet = 0 } else { if BytesToGet > 128 { BytesToGet = 128 } }
           Error, BytesWritten = cx16.MACPTR(lsb(BytesToGet), Destination, false)
           EOF = cbm.READST()
           if Error { cbm.CLOSE(7) cx16.enter_basic(true) }
           ByteCount += BytesWritten
           Destination += BytesWritten
         }
         CurBank++
     }
     cbm.CLRCHN()
     cbm.CLOSE(7)
     cx16.rambank(OB)
     VIDKIT_INIT()
     VMajor, VMinor, VDevelopment = VidKitVersion()
     drivenumber = VIDKIT.drivenumber
     return
  } else { txt.print(TMPFILE) txt.print(" \x07NOT FOUND \x99!\x05\x0D") }
  cx16.enter_basic(false)
}

sub PrintINT32(ubyte[] i32) {
   for i in 3 to 0 step -1 { txt.print(conv.str_ubhex(i32[i])) }
  }

sub Boing() {
    VERA_AUDIORATE = 0
    if Volume < 8 { AUDIO_CTRL = 8 } else { AUDIO_CTRL = Volume }
    cx16.memory_copy(&boingsnd,&AUDIO_FIFO, &endboing - &boingsnd)
    VERA_AUDIORATE = 26
    sys.wait(22)
    VERA_AUDIORATE = 0
    %asm {{
kflush: jsr cbm.GETIN
        bne kflush
        }}
}

sub LoadHD_Logo(word lX, word lY,uword ZsprPtr,ubyte sbank, uword BuffPtr, ubyte sprn,bool ShowIt) {
    cx16.VERA_ADDR_H = %00010000 | sbank
    cx16.VERA_ADDR_M = msb(BuffPtr)
    cx16.VERA_ADDR_L = lsb(BuffPtr)
    cx16.memory_decompress(ZsprPtr,&cx16.VERA_DATA0)
    sprites.init(sprn, sbank, BuffPtr, sprites.SIZE_64, sprites.SIZE_64, 128, 0)
    sprites.pos(sprn, lX,lY)
    if ShowIt { sprites.show(sprn) }
}

 ;sub init(ubyte spritenum,
 ;            ubyte databank, uword dataaddr,
 ;            ubyte width_flag, ubyte height_flag,
 ;            ubyte colors_flag, ubyte palette_offset)

uword Next_SPRITE_BUFF
sub Load_FilmReel_Image(uword BUFF, ubyte vBank, word xStart, word yStart) {
    ; for i in 0 to 127 { sprites.hide(i) }
    HIDE_SPRITES()
    word x
    word y
    cx16.VERA_ADDR_H = %00010000 | vBank
    cx16.VERA_ADDR_M = msb(BUFF)
    cx16.VERA_ADDR_L = lsb(BUFF)
    cx16.memory_decompress(&reelsprites,&cx16.VERA_DATA0)
    i = 5
    tmpw = BUFF
    for y in yStart to (yStart+64) step 32 {
     for x in xStart to (xStart+192) step 64 {
        sprites.init(i,vBank,tmpw,sprites.SIZE_64, sprites.SIZE_32, 128, 0)
        sprites.pos(i,x,y)
        i++
        tmpw += 2048
       }
     }
    ubyte z = i-1
    for i in 5 to z { sprites.show(i) }
}

sub bload(str filename,ubyte bank, uword addr @ R0)  {
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

ubyte[26] banks
uword[26] sImages
ubyte curImageIdx
sub NextSpriteFrame() {
    OB = peek(0)
    if curImageIdx == 24 { curImageIdx=0 } else { curImageIdx = curImageIdx + 2 }
    cx16.rambank(banks[curImageIdx])
    cx16.VERA_ADDR_L = 0
    cx16.VERA_ADDR_M = $32
    cx16.VERA_ADDR_H = %00010001
    cx16.memory_copy(sImages[curImageIdx], &cx16.VERA_DATA0, 2048)
    cx16.rambank(OB)
}

sub InitTapeAnimSprites() {
   sprites.init(10, 1, $3200, sprites.SIZE_32, sprites.SIZE_32, 128, 0)
   sprites.init(11, 1, $3600, sprites.SIZE_32, sprites.SIZE_32, 128, 0)
   sprites.pos(10,92,74)
   sprites.pos(11,196,74)
   sprites.show(10)
   sprites.show(11)
   NextSpriteFrame()
}

sub LoadTapeImage() {
    LoadVERAImage(Asset("CASSETTE.IMG"))
}

sub LoadAudioCDImage() {
    LoadVERAImage(Asset("CDROM.IMG"))
}

str ASSETPATH = "?"*48
sub Asset(str name) -> str {
    ; ASSETS/<name> in the current folder, else //ASSETS/:<name> in the root
    strings.copy("ASSETS/", ASSETPATH)
    strings.append(ASSETPATH, name)
    if not FExists(ASSETPATH, strings.length(ASSETPATH)) {
       strings.copy("//ASSETS/:", ASSETPATH)
       strings.append(ASSETPATH, name)
    }
    return ASSETPATH
}

sub AssetExists(str name) -> bool {
    void Asset(name)
    return FExists(ASSETPATH, strings.length(ASSETPATH))
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

sub PrintInfo() {
    MyPlot(28,1)
    txt.print(PENV.CPU)
    spc(2) txt.print ("\x9BOn\x1E: \x05")
    if PENV.ON_EMU { txt.print("X16 Emulator") }
    if PENV.ON_HARDWARE { txt.print("X16 Hardware") }
    spc(2)
    txt.print("\x9BROM\x1E: \x9Cr\x99") txt.print(conv.str_ub(ROM.VERSION))
    if ROM.IsPreRelease { txt.print("\x1E(\x9BPre-Release\x1E)") }
    MyPlot(27,1)
    txt.print("\x05VIDKIT Version\x1E: \x9E") txt.print_ub(VMajor) txt.print("\x1E.\x9E") txt.print_ub(VMinor)
}

sub SPLASH_SCREEN() {
    Fade2Black()
    cx16.set_screen_mode($80)
    txt.cp437()
    txt.color2(15,0)
    txt.clear_screen()
    verafx.clear(0,0,0,19200)
    cx16.VERA_ADDR_L = $00
    cx16.VERA_ADDR_M = $05
    cx16.VERA_ADDR_H = %00010000
    cx16.memory_decompress(&titlescreen, &cx16.VERA_DATA0)
    Load_FilmReel_Image($2C00, 1,52,92)
    PrintInfo()
    FadeToDEFPAL()
    sys.wait(360)
    Fade2Color($0006)
    verafx.clear(0,0,0,19200)
}

sub LoadVERAImage(str IMAGEFILE) {
    DO_VOPEN(IMAGEFILE)
    cx16.VERA_ADDR_L = 0
    cx16.VERA_ADDR_M = 0
    cx16.VERA_ADDR_H = %00010000
    DO_VLOAD()
    cx16.memory_fill($9F23,15040,0)
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

sub PrintPlayerControls(ubyte StartRow,bool PrintTitle) {
    MyPlot(StartRow,24)
    txt.print(" \x1E[\x05\x80\x18\x80\x19\x1E]\x99-\x9BVolume")
    MyPlot(StartRow+1, 24)
    txt.print("\x1E[\x05SPC\x1E]\x99-\x9BPause")
    MyPlot(StartRow+2,24)
    txt.print("\x1E[\x05ESC\x1E]\x99-\x9BExit Play")
    if PrintTitle { MyPlot(1,3) txt.print(BASENAME) txt.print(FOUND_EXT) }
}

sub SetSpritePointers(ubyte startbank) {
  ubyte imgctr
  OB = startbank
  curImageIdx = 0
  tmpw = $A000
  imgctr = 0
  while curImageIdx < 26 {
        banks[curImageIdx] = OB
        banks[curImageIdx+1] = OB
        sImages[curImageIdx] = tmpw
        sImages[curImageIdx+1] = tmpw + 1024
        imgctr = imgctr + 2
        curImageIdx = curImageIdx + 2
        tmpw = tmpw + 2048
        if imgctr == 8 { imgctr=0 tmpw=$A000 OB++ }
     }
   curImageIdx = 24
}

sub PrintByteRate() { txt.print("\x0D\x05 Audio Byte Rate: \x9E") floats.print(floats.round(AudioByteRate/1024.0)) txt.print("\x96kb") }

sub TapeAnimation_INIT() {
    bload(Asset("TAPESPRITES.BIN"), 14, $A000)
    SetSpritePointers(14)
    cx16.screen_mode($80,false)
    LoadTapeImage()
    InitTapeAnimSprites()
    txt.color2(1,0)
    MyPlot(26,0)
    PrintPCMFormat()
    PrintByteRate()
    txt.color2(11,0)
    PrintPlayerControls(27,false)
    cx16.GRAPH_set_colors($10,4,6)
    strings.copy(BASENAME,TMPFILE)
    strings.append(TMPFILE, FOUND_EXT)
    Graph_CHAR(TMPFILE,57,45)
}

sub TapeAnimationAvailable() -> bool {
    if not AssetExists("CASSETTE.IMG") { return false }
    return AssetExists("TAPESPRITES.BIN")
}

sub PrintTime(float seconds) {
    float PHours = floats.floor(seconds/3600.0)
    tmpf = seconds - (PHours * 3600.0)
    float PMins = floats.floor(tmpf/60.0)
    float PSecs = floats.round(tmpf - (PMins*60))

      txt.print("\x05")
      if PHours < 10 {cbm.CHROUT('0')}
      floats.print(PHours)

      txt.print("\x99:\x05")
      if PMins < 10 {cbm.CHROUT('0')}
      floats.print(PMins)

      txt.print("\x99:\x05")
      if PSecs < 10 {cbm.CHROUT('0')}
      floats.print(PSecs)
}

inline asmsub NOP() { %asm {{ nop }} }

sub CLOSE_ALL() {
    for i in 1 to 15 { cbm.CLOSE(i) }
    while diskio.status_code() !=0 { NOP() }
}

asmsub Flush15() clobbers(A,X,Y) {
  %asm {{
          ldx #15
          jsr cbm.CHKIN
          jmp p8s_FExists.flushchars
       }}
}


sub Woop() {
    VERA_AUDIORATE = 0
    ubyte freint = 100
    byte Amplitude = 30

  repeat 20 {
   repeat 2 {
    repeat freint  {
       AUDIO_FIFOs = Amplitude
     }
    repeat freint {
       AUDIO_FIFOs = (0 - Amplitude)
     }
   }
   freint = freint - 5
   Amplitude = Amplitude + 4
  }
    AUDIO_CTRL = Volume
    VERA_AUDIORATE = 35
    sys.wait(10)
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

sub ClearUpperRows() {
   txt.color2(1,0)
   MyPlot(0,0)
   repeat 5 {
       repeat 80 {cbm.CHROUT(32)}
     }
   MyPlot(4,0)
   repeat 80  {cbm.CHROUT(95)}
   MyPlot(0,0)
}

sub Graph_CHAR(str s,uword X,uword Y) {
  j = strings.length(s)
  if j>0 {
     j--
     cx16.GRAPH_put_char(X,Y, $06)
     for i in 0 to j {
       cx16.GRAPH_put_next_char(s[i])
      }
   }
}

sub VERA2Hz() -> float {
    return (VideoHeader.VERARate as float / 128.0) * 48828.15
}

ubyte WarnCount = 0
sub SPI_WARN() {
    if (WarnCount > 0) or LOOP_PLAY_ON { return }
    WarnCount++
    ClearUpperRows()
    MyPlot(1,1)
    txt.print(" \x9BYou are running a \x96prerelease \x99r49 \x05ROM.")
    MyPlot(2,1)
    txt.print(" \x96This \x99MAY\x96 work \x1E!\x1F....\x9B[\x05Recommend \x99UPGRADE\x9B]\x05")
    MyPlot(3,2)
    WaitForKey_RestoreColor()
}

float Seeker
sub MakeStandAlonePlayer() {
    Seeker = $2D as float
    strings.copy(Asset("VIDPLAY-TEMPLATE.PRG"), TMPFILE)
    ClearUpperRows()
    MyPlot(1,1)
    if FExists(TMPFILE,strings.length(TMPFILE)) {
       txt.print("\x99 ") txt.print(TMPFILE) txt.print(" \x05FOUND \x9B!")
       sys.wait(90)
       ClearUpperRows() MyPlot(1,1)
       txt.print("\x96 CREATING\x1C: \x9E") txt.print(BASENAME) txt.print(".PRG")
       strings.copy("@:", AUDFILE)
       strings.append(AUDFILE,BASENAME)
       strings.append(AUDFILE,".PRG,S,W")
       strings.append(TMPFILE,",S,R")
       fopen(7,drivenumber,7,TMPFILE)
       fopen(6,drivenumber,6,AUDFILE)
       cx16.rambank(HighRAMBank)
       txt.print(" \x99")
       %asm {{
              stz $BFFE
cloop:        ldx #7
              jsr cbm.CHKIN
              ldx #0
              ldy #$A0
              lda #240
              clc
              jsr cx16.MACPTR
              phx             ; Put bytes read on the stack for the write
              jsr cbm.READST
              sta $BFFF
              ldx #6
              jsr cbm.CHKOUT
              pla             ; write out as many bytes as we read in
              ldx #0
              ldy #$A0
              jsr cx16.MCIOUT
              inc $BFFE
              lda $BFFE
              cmp #4          ; print a "." every 4 chunks
              bne checkEOF
              jsr cbm.CLRCHN
              lda #"."
              jsr cbm.CHROUT
              stz $BFFE
checkEOF:     lda $BFFF
              beq cloop
       }}
       cbm.CLRCHN()
       cbm.CLOSE(7)
       f_seek(6, Seeker)
       cbm.CHKOUT(6)
       i = 0
       while BASENAME[i] != 0 { cbm.CIOUT(BASENAME[i])  i+=1 }
       cbm.CHROUT(0)
       cbm.CLRCHN()
       cbm.CLOSE(6)
       txt.print("\x99 Done \x05!")
     } else { txt.print("TEMPLATE PROGRAM NOT FOUND\x0D\x0D") }
}

sub MyPlot(ubyte y, ubyte x) {
    txt.row(y)
    txt.column(x)
}

sub ProgramBanner() {
    for i in 0 to 84 { cbm.CHROUT(butterfly[i]) }
    MyPlot(1,10)
    txt.print ("\x9C*\x9A*\x99* \x05X16 VIDKIT STREAMING MEDIA PLAYER ") txt.print(PENV.PETSCII_VERSTR) txt.print(" \x9E*\x81*\x1C*\x05")
    MyPlot(2,14)
    if PENV.ON_EMU { txt.print("EMULATOR") } else { txt.print("HARDWARE") }
    MyPlot(3,10)
    txt.print ("\x9BAUTHOR\x1E: \x05ANTHONY W. HENRY")
    MyPlot(5,10)
    txt.print("\x9ETHIS SOFTWARE IS UNDER THE MIT LICENSE")
    MyPlot(6,14)
    txt.print("\x05(\x9BPERMISSIVE\x05)")
}

sub ISOUpper(str s) {
  i=0
  while s[i] != 0 {
      if s[i] > 96 and s[i]<123 { s[i] -= 32 }
      i+=1
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

sub PrintPlayBar() {
    cbm.CLRCHN()
    cbm.CHROUT(printchar)
    ppos++
    if ppos>printlen {
       ppos = 0
       cbm.CHROUT(1)
       txt.column(2)
     }
  }

sub PrintAudioPlayScreen() {
    txt.color2(7,0)
    MenuBox()
    MyPlot(8,48)
    txt.print("\x05Playing Audio File")
    txt.color2(7,0)
    MyPlot(15,48)
    txt.print("\x1E[\x05\x80\x18\x80\x19\x1E]\x99 - \x9BVolume")
    MyPlot(17,47)
    txt.print("\x1E[\x05SPC\x1E]\x99 - \x9BPause Play")
    MyPlot(19,47)
    txt.print("\x1E[\x05ESC\x1E]\x99 - \x9BExit Play")
 }

sub SetUpPlayBar(ubyte Row, ubyte character, ubyte length) {
    txt.color2(2,11)
    printchar = character
    printlen = length
    MyPlot(Row,2)
    ppos = 0
  }

float NewPCMTime
sub CheckBookMark() -> bool {
    strings.copy(BASENAME, TMPFILE)
    strings.append(TMPFILE,".MARK")
    if FExists(TMPFILE,strings.length(TMPFILE)) {
       fopen(7,drivenumber,7,TMPFILE)
       %asm {{
               ldx #7
               jsr cbm.CHKIN
               ldx #<p8v_Frame
               ldy #>p8v_Frame
               lda #5
               jsr cx16.MACPTR
            }}
       cbm.CLRCHN()
       cbm.CLOSE(7)
          if IS_PCM_ONLY {
          audFilePosition = Frame
          AdjustAudioPosition()
          NewPCMTime = floats.round((NewAudioPosition/AudioByteRate) * 60.0)
          return true
        }
       tmpf = NumFrames - 10.0
       if ( Frame > 5.0 ) and ( Frame < tmpf )
          { return true }
       else { Frame = 0.0 }
     }
      return false
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

 sub File_FL(ubyte channel) {
        ; gets the (32 bits) position + file size of the opened read file channel
        ubyte[3] command = ['F','L',0]
        command[2] = channel       ; f_open uses this secondary address
        cbm.SETNAM(sizeof(command), &command)
        cbm.SETLFS(15, drivenumber, 15)
        void cbm.OPEN()
        void cbm.CHKIN(15)        ; use #15 as input channel
        success=false
        ; valid response starts with "07," followed by hex notations of the position and filesize
        if cbm.CHRIN()=='0' and cbm.CHRIN()=='7' and cbm.CHRIN()==',' {
            cx16.r1 = read4hex()
            cx16.r0 = read4hex()        ; LBA Sector
            void cbm.CHRIN()            ; separator space
            cx16.r3 = read4hex()
            cx16.r2 = read4hex()        ; Cluster in R3:R2
            success = true
        }
        %asm {{ jmp p8s_Flush15 }}
}

bool IS_FRAGMENTED
float CALCULATED_SECTOR
float FILE_STARTSECTOR
float CURRENT_SECTOR
float FILE_NUMBER_OF_SECTORS
float F_FILESIZE
float[8] CHECK_SECTORS
ubyte FChkLFN = 9

sub PrintHexF(float F)  {
    FLOAT_TO_INT32(F, fsector)
    PrintINT32(fsector)
}

sub VERIFY_CONTIGUOUS_SECTOR(float SECTOR) -> bool {
    Seeker = 512.0 * SECTOR
    CALCULATED_SECTOR = SECTOR + FILE_STARTSECTOR
    MyPlot(3,0)
    txt.print("\x1E Seeking \x9C-\x1E> \x99") PrintHexF(CALCULATED_SECTOR) spc(3)
    f_seek(FChkLFN,Seeker)
    getSector(FChkLFN)
    CURRENT_SECTOR = INT32_TO_FLOAT(fsector)
    MyPlot(1,0)
    return (CALCULATED_SECTOR == CURRENT_SECTOR)
}

sub CALC_CHECKSECTORS() {
  if FILE_NUMBER_OF_SECTORS < 8.0 {
     j = (FILE_NUMBER_OF_SECTORS - 1.0) as ubyte
     for i in 0 to ((FILE_NUMBER_OF_SECTORS-1.0) as ubyte) {
         CHECK_SECTORS[i] = j as float
         j--
         if j==0 { break }
     }
   return
  }

  ; LAST_SECTOR
  CHECK_SECTORS[0] = FILE_NUMBER_OF_SECTORS - 1

  ; FILE MIDPOINT
  CHECK_SECTORS[1] = floats.floor(FILE_NUMBER_OF_SECTORS / 2)

  ; FILE 1/4 POINT
  CHECK_SECTORS[2] = floats.floor(CHECK_SECTORS[1]/2)

  ; FILE 3/4 POINT
  CHECK_SECTORS[3] = CHECK_SECTORS[1] + CHECK_SECTORS[2]

  ; FILE 1/8 POINT
  CHECK_SECTORS[4] = floats.floor(CHECK_SECTORS[2]/2)

  ; FILE 5/8 POINT
  CHECK_SECTORS[5] = CHECK_SECTORS[1] + CHECK_SECTORS[4]

  ; FILE 3/8 POINT
  CHECK_SECTORS[6] = CHECK_SECTORS[2] + CHECK_SECTORS[4]

  ; FILE 7/8 POINT
  CHECK_SECTORS[7] = CHECK_SECTORS[3] + CHECK_SECTORS[4]
}

str CALC_HDR = "\x05 CALCULATED LBA ADDR\x1E: \x99"
str ACT_HDR = "\x05   ACTUAL\x1E: \x99"

sub CHECK_FRAGMENTATION(str filename) {
    IS_FRAGMENTED = false
    Fade2Black()
    txt.clear_screen()
    MyPlot(8,2)
    txt.color2(15,2)
    txt.print("\x05Running Frag Check \x9E-\x9C> \x9E") txt.print(filename)
    spc(4)
    ClearUpperRows()
    SetDefaultPalette()
    MyPlot(3,1)
    txt.print("Opening...")
    fopen(FChkLFN,drivenumber,FChkLFN,filename)
    MyPlot(3,1)
    txt.print("Calculating...")
    getSector(FChkLFN)
    FILE_STARTSECTOR = INT32_TO_FLOAT(fsector)
    my_f_tell(FChkLFN)
    F_FILESIZE = (65536.0 * f_size_high as float) + f_size_low as float
    FILE_NUMBER_OF_SECTORS = floats.round(F_FILESIZE / 512.0)
    CALC_CHECKSECTORS()
    for j in 0 to 7 {
        txt.color2(15,6)
        MyPlot(6,1)
        txt.print("\x05Check Sector\x1E: \x9B#\x9E") floats.print(CHECK_SECTORS[j]) spc(3)
        txt.color2(15,0)
        if VERIFY_CONTIGUOUS_SECTOR(CHECK_SECTORS[j]) {
           txt.print(CALC_HDR)  PrintHexF(CALCULATED_SECTOR)
           txt.print(ACT_HDR)  PrintHexF(CURRENT_SECTOR)
        } else {
            txt.print("\x96FRAGMENTED \x1E-\x1C>")
            txt.print(CALC_HDR) PrintHexF(CALCULATED_SECTOR)
            txt.print(ACT_HDR) PrintHexF(CURRENT_SECTOR)
           IS_FRAGMENTED = true
           break;
        }
      if CHECK_SECTORS[j]==0.0 { break }
    }
    cbm.CLOSE(FChkLFN)

    txt.color2(15,6)
    MyPlot(11,1)
    Woop()
    if IS_FRAGMENTED {
       repeat 2 { sys.wait(15) Woop() }
       txt.print("\x96FRAGMENTED: \x05Do Not Play.")
    } else {
       txt.print("\x99CONTIGUOUS\x05")
       if FRAG_AUTO { sys.wait(75) return }     ; picked from the list: go straight to playback
    }
    txt.nl() txt.nl()
    WaitForKey_RestoreColor()
}

bool FRAG_AUTO      ; true = no Y/N for the .SVA and no key wait when contiguous

sub FragCheckSPI(bool auto) {
    ; checks the SPI video and, if separate, its .SVA audio track.
    ; Menu (Ctrl+F): asks before the audio check. Autoplay: checks both.
    FRAG_AUTO = auto
    CHECK_FRAGMENTATION(VIDFILE)
    if AUDIO_TRACK_IN_SEPERATEFILE and not IS_FRAGMENTED {
       if not auto {
          MyPlot(15,0)
          txt.print(" \x9BCheck \x05Audio\x9B for Fragmentation \x9B(\x9EY\x1E/\x9EN\x9B) \x81?")
          txt.color2(5,0)
          if not Yes(15,42) { return }
          txt.color2(15,6)
       }
       strings.copy(BASENAME,AUDFILE)
       strings.append(AUDFILE,".SVA")
       CHECK_FRAGMENTATION(AUDFILE)
    }
    FRAG_AUTO = false
}

str FBUFF = "?????"

sub SPI_PROMPT(bool hostfs) -> ubyte {
    ; shown after an SPI video is picked from the list. Returns the key pressed.
    txt.color2(1,6)
    txt.clear_screen()
    MyPlot(9,4)
    if hostfs {
       txt.print("\x05SPI videos \x96do not Play \x05on HOSTFS\x96!")
       MyPlot(11,4)
       txt.print(AnyMessage)
       LoadHD_Logo(500,154,&spritelogo4,0,0,2,true)   ; same NOCAM logo as the info screen
    } else {
       txt.color(1)
       txt.print(BASENAME) txt.print(".SPV") txt.nl() txt.nl()
       txt.color(7)
       txt.column(4)
       txt.print_uw(VideoHeader.FrameWidth) txt.print(" \x05x\x9E ") txt.print_uw(VideoHeader.FrameHeight) txt.print(" \x05SPI Direct Video\x0D\x9E")
       txt.column(4)
       txt.print_ub(VideoHeader.BPP) txt.print("\x05 Bits Per Pixel\x0D\x9E")
       txt.column(4)
       floats.print(TRUE_FPS)
       txt.column(9) spc(10)
       txt.column(9)
       txt.print(" \x05FPS\x0D\x0D")
       txt.column(4)
       txt.print("\x1E[\x05Ctrl\x99/\x05F\x1E] \x9BFrag Check & Play\x0D")
       txt.column(7)
       txt.print("\x1E[\x05ESC\x1E] \x9BBack\x0D\x0D")
       txt.column(4)
       txt.print("Any Other Key to Play  \x9B(\x05auto in ")
    }
    showTextLayer()
    FadeToDEFPAL()
    KEYFLUSH()
    if hostfs { return txt.waitkey() }

    ; 30 second countdown, redrawn in place each second.
    ; No key before it reaches 0 = play (returns ENTER).
    ubyte secs
    ubyte k
    uword t0
    secs = 30
    repeat {
        picker.print_right(secs, 2)
        txt.print("\x9Bs\x05)\x9D\x9D\x9D\x9D")      ; 4 x cursor-left back onto the number
        t0 = cbm.RDTIM16()
        while cbm.RDTIM16() - t0 < 60 {             ; one second of jiffies
            k = cbm.GETIN2()
            if k != 0 { return k }
        }
        secs--
        if secs == 0 { return _KEY_ENTER }
    }
}

sub ShowVolume() {
    txt.color2(7,0)
    MyPlot(17,47)
    txt.print(" \x1E[\x05\x80\x18\x80\x19\x1E]\x99 - \x9BVolume\x05: \x96")

    ; 0-15 -> 0-100%, rounded (was a 16-entry table)
    tmpw = ((Volume as uword) * 100 + 7) / 15
    if tmpw < 10 { cbm.CHROUT('0') }
    txt.print_uw(tmpw)
    txt.print("\x05% ")
    txt.color2(1,6)
}

sub MenuBox() {
    i=6
    MyPlot(i,45) cbm.CHROUT(201) repeat 28 { cbm.CHROUT(205) } cbm.CHROUT(187)
    repeat 13 { i++ MyPlot(i,45) cbm.CHROUT(186) repeat 28 { cbm.CHROUT(32) } cbm.CHROUT(186) }
    i++
    MyPlot(i,45) cbm.CHROUT(200) repeat 28 { cbm.CHROUT(205) } cbm.CHROUT(188)
}

bool CAN_PLAY
bool AUTOPLAY       ; set when a file was just picked: play it straight away

sub CalcCanPlay() {
    CAN_PLAY = IS_SUPPORTED_VIDEO or IS_PCM_ONLY
    if CAN_PLAY { CAN_PLAY = ((not PENV.IS_HOST)) or (not IS_SPI_VIDEO) }
}

sub MenuBar() {
  ;  if Load_816_SPICode or Load_816_STDCode {
  ;   MyPlot(0,47) txt.color2(1,0)
  ;   txt.print("\x1E[\x05F12\x1E]\x99 - \x9BDisable 65816 Driver ")
  ;   txt.color2(1,6)
  ;  }
    i=5
    CalcCanPlay()

    txt.color2(1,0)
    repeat 17 {
      MyPlot(i,43)
      repeat 34 { cbm.CHROUT(176)  }
      i++
    }
    txt.color(8)
    MenuBox()
    MyPlot(7,48)
    txt.print("\x1E[")
    if CAN_PLAY { txt.print("\x05") goto SkipBrightP}
    txt.print("\x98")
SkipBrightP:
    txt.print("F1\x1E]\x99 - ")
    if CAN_PLAY { txt.print("\x9B") goto SkipBrightP2 }
    txt.print("\x97")
SkipBrightP2:
    txt.print("Play ")
    if IS_VIDEO { txt.print("Movie") }
    if IS_PCM_ONLY { txt.print("Audio File") }

    if IS_VIDEO {
      MyPlot(9,48)
      txt.print("\x1E[\x05F2\x1E]\x99 - \x9BCreate mini Player")
     }

    MyPlot(11,48)
    txt.print("\x1E[\x05F3\x1E]\x99 - \x9BChoose Another")

    MyPlot(13,48)
    txt.print("\x1E[")
    if UseBookMark { txt.print("\x05") goto SkipBright}
    txt.print("\x98")
SkipBright:
    txt.print("F4\x1E]")
    txt.print("\x99 - ")
    if UseBookMark { txt.print("\x9B") goto SkipBright2 }
    txt.print("\x97")
SkipBright2:
    txt.print("Scratch BookMark")
    MyPlot(19,47)
    txt.print("\x1E[\x05ESC\x1E]\x99 - \x9BExit")
    if IS_SPI_VIDEO and (not PENV.IS_HOST) {
       MyPlot(18,66)
       txt.print("\x05Frag chk")
       MyPlot(19,66)
       txt.print("\x1E[\x05Ctrl\x81/\x05F\x1E]")
    }
    ShowVolume()
    ShowLoop()
    txt.color2(1,6)
}

ubyte[] MENUKEYS = [_KEY_F1, _KEY_F2, _KEY_F3, _KEY_F4, _KEY_F5]   ; the menu lines, rows 7,9,11,13,15

sub MouseChoice() -> ubyte {
    ; info screen: a left click on a menu line returns the key shown on that line
    ; (0 = nothing).  Same mouse setup as the file picker: 8x8 cells, text rows.
    ubyte btn
    byte wheel
    ubyte col
    ubyte row
    ubyte pressed

    btn, wheel = cx16.mouse_get(lsb(&cx16.r0))
    col = lsb(cx16.r0 >> 3)
    row = lsb(cx16.r1 >> 3)
    picker.mouse_moved = cx16.r0 != picker.mx_prev or cx16.r1 != picker.my_prev or btn != 0 or wheel != 0
    picker.mx_prev = cx16.r0
    picker.my_prev = cx16.r1
    if picker.mouse_moved { picker.wake() }       ; mouse activity keeps the screen on

    pressed = btn & ~picker.mbtn_prev
    picker.mbtn_prev = btn
    if (pressed & 1) == 0 { return 0 }
    if row == 17 and col >= 48 and col <= 51 {              ; "[<up><down>]" = cols 48..51: "[" + up arrow = up, down arrow + "]" = down
        if col < 50 { return _KEY_UP }
        return _KEY_DOWN
    }
    if row == 19 and col >= 47 and col < 60 { return _KEY_ESC }    ; "[ESC] - Exit" (not the Ctrl/F text)
    if col < 47 or col > 72 or row < 7 or row > 15 or (row & 1) == 0 { return 0 }
    return MENUKEYS[(row - 7) >> 1]
}

sub ShowLoop() {
    txt.color2(1,0)
    MyPlot(15,48)
    txt.print("\x1E[\x05F5\x1E]\x99 - \x9BLOOP Toggle\x96:")
    if LOOP_PLAY_ON {  txt.print(" \x99ON ") } else { txt.print(" \x1EOff") }
    txt.color2(1,6)
}

sub CleanUpMarkFile() {
    strings.copy(BASENAME,AUDFILE)
    strings.append(AUDFILE,".MARK")
    if FExists(AUDFILE,strings.length(AUDFILE)) { diskio.delete(AUDFILE) }
    void diskio.status()
}

sub PrintFrameRate() {
    txt.print("\x0D \x81") cbm.CHROUT(175) txt.print("\x05Frames Per Second\x81") cbm.CHROUT(174)
    txt.print("\x0D\x9B (\x96byte\x9B)\x99") txt.print(conv.str_ub(VideoHeader.FPS))
    txt.print("  \x9B(\x96encode\x9B)\x99") floats.print(VIDKIT.F_FPS)
    txt.print("  \x9B(\x96play\x9B)\x99") floats.print(VIDKIT.TRUE_FPS) txt.nl()
}

sub PrintFrameInfo_STD() {
    txt.print("\x0D\x05             Color Depth: \x99") txt.print(conv.str_ub(VideoHeader.BPP)) txt.print(" \x9Ebpp\x99")
    txt.print("\x0D\x05      Frame X Resolution: \x9E") txt.print(conv.str_uw(VideoHeader.FrameWidth))
    txt.print("\x0D\x05      Frame Y Resolution: \x9E") txt.print(conv.str_uw(VideoHeader.FrameHeight))
    txt.print("\x0D\x05       Frame Buffer Size: \x9E") txt.print(conv.str_uw(FrameBufferSize))
}

sub PrintAspectRatio() {
    txt.nl() txt.nl()
    if HAS_ASPECT {                                ; VIDKIT 2.1 hint "A": true aspect, stored as a CBM float
        uword a100 = floats.round(VideoHeader.AspectF * 100.0) as uword
        spc(9) txt.print("\x9BCustom Aspect \x81[\x05")
        txt.print_uw(a100 / 100)
        txt.chrout('.')
        if a100 % 100 < 10 { txt.chrout('0') }
        txt.print_uw(a100 % 100)
        txt.print("\x1C:\x051\x81]")
        return
    }
    if MAKE_WIDE_SCREEN { spc(14) txt.print("\x9BWide Screen \x81[\x0516\x1C:\x059\x81]") return}
    if K_TYPE or (IS_SPRITE_VIDEO and IS_TALL_VIDEO)
      { spc(11) txt.print("\x9BTall Video \x81[\x059\x1C:\x0516\x81]") return}
    spc(9) txt.print("\x9BStd Aspect Video \x81[\x054\x1C:\x053\x81]")
}

sub PrintSpriteInfo() {
       txt.print("\x0D\x0D\x05           SPRITE  Width: \x99") txt.print(conv.str_ub(VideoHeader.SpriteWidth))
       txt.print("\x0D\x05           SPRITE Height: \x99") txt.print(conv.str_ub(VideoHeader.SpriteHeight))

       txt.print("\x0D\x05       Sprites per Frame: \x9E") txt.print(conv.str_uw(NumSprites))
}

sub PrintMainVideoInfo() {
    txt.print("\x0D\x05 Movie Name\x1E: \x96")
    txt.print(BASENAME) txt.print("\x0D")
    txt.print("\x9B Type:\x05 ") txt.print(conv.str_ub(VideoHeader.VTYPE))
    txt.print("     \x9E") floats.print(NumFrames) txt.print(" \x9BFrame\x99")
    if IS_SPRITE_VIDEO {
        if VideoHeader.VTYPE > 20 { txt.print(" HIGH BANDWIDTH SPRITE") } else { txt.print(" Sprite") }
    }
    if VideoHeader.VTYPE==3 or VideoHeader.VTYPE==8 { txt.print(" Bitmap") }
    if VideoHeader.VTYPE==23 or VideoHeader.VTYPE==28 { txt.print(" HIGH BANDWIDTH BITMAP") }
    txt.print("\x9B Based \x05VIDEO  ")
    txt.nl()

    if UseBookMark {
       txt.print("\x05 BookMark at FRAME: \x9E") floats.print(Frame) cbm.CHROUT(32)
    }

    txt.print("\x9B Play Length\x1E: ") PrintTime(NumFrames / TRUE_FPS)

     if UseBookMark {
        txt.print("\x9B  Time Left\x1E: ") PrintTime(NumFrames / TRUE_FPS - (Frame/ TRUE_FPS))
     }
     txt.nl()
}

sub PrintMainAudioInfo() {
    txt.print("\x0D\x05 Audio Track Name\x1E: \x96")
    txt.print(BASENAME) txt.print(FOUND_EXT) txt.nl()

    txt.print("\x9B             Type\x1E:\x05 ")
      if IS_Z_FILE { txt.print("ZCM") }
      if IS_WAV_FILE { txt.print("WAV") }
    txt.print(" Audio File")

    play_total = (AudFileSize - (AudioHeaderSize as float)) / AudioByteRate
    txt.print("\x0D\x9B      Play Length\x1E: ") PrintTime(play_total) txt.nl()

    if UseBookMark {
       tmpf2 = (audFilePosition-(AudioHeaderSize as float)) / AudioByteRate
       play_left = play_total - tmpf2
       txt.print("\x0D\x05 BookMark at Time: \x9E") PrintTime(tmpf2) txt.nl()
       txt.print("\x05   Play Time Left: \x9E") PrintTime(play_left) txt.nl()
    }
}

sub VidMediaSpace() { if not IS_PCM_ONLY { repeat 7 { cbm.CHROUT(32) } } }

sub PrintPCMFormat() {
      txt.print("\x05      PCM Format: \x99")

      if PCM_IS_16BIT { txt.print("16") } else { txt.print("8") }

      txt.print("\x1E bit \x9E")

      if PCM_IS_STEREO
         { txt.print("stereo") }
      else
         { txt.print("mono") }
      txt.nl()
    VidMediaSpace()
        txt.print("\x05       VERA Rate: \x99") txt.print(conv.str_ub(VideoHeader.VERARate))
        txt.nl()
        if IS_VIDEO { txt.print("       ") }
        txt.print("       (\x9B") floats.print(VERA2Hz()) txt.print(" \x96hz\x99)\x0D")
}



sub PrintAudioInformation_STD() {
 if IS_PCM_ONLY {    txt.row(10)
                     goto printAudFormat }

  if AUDIO_TRACK_IN_SEPERATEFILE
    { txt.print("\x05      Audio File size is: \x9E") floats.print(AudFileSize) txt.print("\x96 bytes") }
  else
    { txt.print("\x05                Audio is: \x96embedded") }

  txt.print("\x0D\x05        Audio Frame Size: \x9E") txt.print(conv.str_uw(VideoHeader.AudioFrameSize))

  txt.nl()

printAudFormat:
    VidMediaSpace()
    PrintPCMFormat()
    if IS_PCM_ONLY { PrintByteRate() }
    txt.nl()
    VidMediaSpace()
}

sub PrintMediaAttributes() {
word SpY
    txt.color2(15,6)
    txt.clear_screen()

    if IS_VIDEO {
       PrintMainVideoInfo()
       PrintFrameRate()
       PrintFrameInfo_STD()
       PrintAspectRatio()
       if IS_SPRITE_VIDEO { PrintSpriteInfo() }
     }
    if IS_PCM_ONLY {
       txt.nl()
       PrintMainAudioInfo()
     }

    unroll 2 { txt.nl() }

    PrintAudioInformation_STD()

    SpY = 178
    if IS_SPI_VIDEO { if PENV.IS_HOST { tmpw=&spritelogo4 SpY=174 } else { tmpw = &spritelogo1 } }
    if IS_STD_VIDEO { tmpw = &spritelogo2 }
    if IS_PCM_ONLY { tmpw = &spritelogo3 }

    LoadHD_Logo(526, SpY,tmpw,0,0 ,2,true)

    sprites.show(2)

    if IS_PCM_ONLY { goto skipNotSupportedMessage }

    if not IS_SUPPORTED_VIDEO {
       txt.row(23) txt.column(1)
       txt.print("\x0D\x0D\x96  UNSUPPORTED FORMAT ")
     }
skipNotSupportedMessage:
   Print_RUN_Environment()
}

sub spc(ubyte L @ R11 ) { repeat L { cbm.CHROUT(32) } }

sub Print_RUN_Environment() {
  ; shared with the file picker: rows 28/29, same layout on both screens
  picker.draw_env()
}

bool IN_LOOP
sub GetMediaFile_BASENAME() {
    ; Scrolling picker built from the folder listing (kept in banked RAM).
    ; Shows a message and exits when the folder has no media or folders.
    Fade2Color($000F)
    verafx.clear(0,0,0,19200)
    HIDE_SPRITES()
    VID_FILE_FOUND = false
    IS_PCM_ONLY = false
    PCM_FILE_FOUND = false
    picker.draw_frame()
    FadeToDEFPAL()
    if picker.read_folder() and picker.count > 0 {
       if picker.pick() == picker.RESULT_SELECTED { return }
    } else {
       MyPlot(12,16)
       txt.print("\x96No media or folders found\x99.")    ; also covers a failed folder read
       MyPlot(14,16)
       WaitForKey_RestoreColor()
    }
    strings.copy("EXIT", BASENAME)
}

sub Yes(ubyte y @R9, ubyte x @R10) -> bool {
  ubyte InChar=0
  ubyte StoredChar=32

  printit:
     MyPlot(y, x)
     cbm.CHROUT(StoredChar)
  skipprint:
     InChar = cbm.GETIN2()
     if InChar==217 or InChar==121 { InChar=89 }  ; force PETSCII or ISO to UpperCase for Y
     if InChar==110 or InChar==206 { InChar=78 }  ; ditto for N
     when InChar {
         0 -> { goto skipprint }
     89,78 -> { StoredChar=InChar goto printit }
        27 -> { StoredChar = 78 }
        13 -> { if not (StoredChar==89 or StoredChar==78) { Boing() goto skipprint }  }
      else -> { Boing() goto skipprint }
    }
    return (StoredChar==89)
}

float ScrTimer
ubyte SAVE_DC_VIDEO

sub SetScreenTimer() {
    SAVE_DC_VIDEO = cx16.VERA_DC_VIDEO
    ScrTimer = floats.time()
    if ScrTimer > 16773000 {
       ScrTimer = 600.0
      }
     else
      { ScrTimer = ScrTimer + 3600 }
}

sub Print_PCM_FILE_ERROR(str msg) {
    txt.color2(15,0)
    ClearUpperRows()
    MyPlot(1,0) txt.print("\x9E ") txt.print(AUDFILE)
    MyPlot(3,0) txt.print("\x05 ") txt.print(msg)
    Boing()
    txt.color2(15,6)
    sys.wait(180)
}

sub MouseButtons() -> ubyte {
    ubyte b
    byte w
    b, w = cx16.mouse_get(lsb(&cx16.r0))
    return b
}

sub WaitForKey_RestoreColor() {
   txt.print(AnyMessage)
   while MouseButtons() != 0 { %asm {{ nop }} }                    ; let go of the click that got us here
   while cbm.GETIN2() == 0 and MouseButtons() == 0 { %asm {{ nop }} }   ; any key or any mouse button
   txt.color2(1,6)
}

sub BAD_ROM_MESSAGE() {
       txt.print("\x07\x0D\x9B   THIS PROGRAM \x05REQUIRES\x9B ROM VERSION \x99R\x0548 \x9BOR \x05 HIGHER\x96 !")
       txt.print("\x0D\x05   VERSION\x1E: \x99") txt.print(conv.str_ub(ROM.VERSION)) txt.print("\x9B WAS FOUND.\x0D")
       if ROM.IsPreRelease { txt.print("\x0D\x05   PRE-RELEASE ROM\x0D") }
}

sub SEND_BASENAME() {
    OB = @(0)
    cx16.rambank(0)
    strings.copy(BASENAME, $BF00)
    cx16.rambank(OB)
}

sub KEYFLUSH() {
  while cbm.GETIN2() != 0 { %asm {{ nop }} }
}

sub GetAudioProperties() {
    my_f_tell(AudioLFN)
    audFilePosition = (65536.0 * cx16.r1 as float) + cx16.r0 as float
    AudFileSize = (65536.0 * f_size_high as float) + f_size_low as float
}

float Divisor
sub AdjustAudioPosition() {
  Divisor = 1
  if PCM_IS_16BIT { Divisor = Divisor * 2 }
  if PCM_IS_STEREO { Divisor = Divisor * 2 }
  if Divisor > 1 { while (floats.floor(audFilePosition/Divisor) * Divisor) != audFilePosition { audFilePosition = audFilePosition + 1 } }
  NewAudioPosition = audFilePosition
}

sub GetMediaInfo() {
  if IS_VIDEO {
   when VideoHeader.BPP {
    8 -> Divisor = 1
    4 -> Divisor = 2
    2 -> Divisor = 4
    1 -> Divisor = 8
   }
   FrameBufferSize = ((VideoHeader.FrameWidth as float * VideoHeader.FrameHeight as float) / Divisor) as uword
   if IS_SPRITE_VIDEO {
      NumSprites = (VideoHeader.FrameWidth/VideoHeader.SpriteWidth) * (VideoHeader.FrameHeight/VideoHeader.SpriteHeight)
   }
  }
  if IS_PCM_ONLY { GetAudioProperties() }
}

sub SETUP_PLAY_PCMSTREAM() {
     if not IN_LOOP { Fade2Black() }
        if TapeAnimationAvailable() and (AudioByteRate < 120000) {
           if not IN_LOOP { TapeAnimation_INIT() }
           SET_FRAME_DRIVER(&NextSpriteFrame)
       } else {
         if AssetExists("CDROM.IMG") {
            if not IN_LOOP {
               cx16.screen_mode($80,false)
               LoadVERAImage(Asset("CDROM.IMG"))
               PrintPlayerControls(26,true)
                txt.row(24) txt.column(0)
                PrintPCMFormat()
                PrintByteRate()
                i=35
             }
         }
         else {
            if not IN_LOOP { PrintAudioPlayScreen() }
            i=75
         }
         if not IN_LOOP { SetUpPlayBar(29, 178, i) }
         SET_FRAME_DRIVER(&PrintPlayBar)
       }
       if not IN_LOOP { FadeToDEFPAL() }
}

sub LOAD_AND_PREP() {
      CLOSE_MEDIA()
      LOAD_MEDIA()
      NumFrames = (VideoHeader.NumFramesHI as float * 65536.0) as float + (VideoHeader.NumFramesLO as float)
      if IS_PCM_ONLY { AudioByteRate = VIDKIT.PCM_BYTEsPerSecond }
      UseBookMark = CheckBookMark()
      if UseBookMark {
       if IS_VIDEO {
          FLOAT_TO_INT32(Frame, &cx16.r0)
          SET_START_FRAME()
       }
       if IS_PCM_ONLY {
          FLOAT_TO_INT32(NewPCMTime, &cx16.r4)
          SET_STARTTIME_JIFFIES()
       }
      }
      GetMediaInfo()
}


ubyte choice

;extsub @bank VID_BANK1 $A000 = VIDKIT_INIT()
;extsub @bank VID_BANK1 $A003 = LOAD_PLAY()
;extsub @bank VID_BANK1 $A006 = LOAD_MEDIA()
;extsub @bank VID_BANK1 $A009 = PLAY_MEDIA()
;extsub @bank VID_BANK1 $A00C = SET_START_FRAME()
;extsub @bank VID_BANK1 $A01E = CLOSE_MEDIA()
;extsub @bank VID_BANK2 $A024 = HIDE_SPRITES()
;extsub @bank VID_BANK2 $A02A = SetDefaultPalette()
;extsub @bank VID_BANK2 $A039 = Fade2Black()
;extsub @bank VID_BANK2 $A03C = pal2black()
;extsub @bank VID_BANK2 $AA15 = RESTORE_SCREEN()
;extsub @bank VID_BANK3 $B412 = FadePal(uword ThePal @R11)
;extsub @bank VID_BANK3 $B415 = FadeToDEFPAL()
;extsub @bank VID_BANK3 $B418 = Fade2Color(uword PalEntry @R1)
;extsub @bank VID_BANK1 $A024 = hideTextLayer()
;extsub @bank VID_BANK1 $A02D = showTextLayer()
;extsub @bank VID_BANK1 $A02A = ShowBothLayers()
;extsub @bank VID_BANK1 $A021 = HideBothLayers()

sub WRITE_STATUS() {
    fopen(9,8,9,"@:STAT.TXT,S,W")
    strings.copy(diskio.status(), TMPFILE)
    cbm.CHKOUT(9)
    txt.print(TMPFILE) txt.nl()
    cbm.CLRCHN()
    cbm.CLOSE(9)
}

sub start() {
bool IN_PLAY
    PENV.GetRunEnvironment()
    if (ROM.VERSION < 48) or ((ROM.VERSION==48) and ROM.IsPreRelease) { BAD_ROM_MESSAGE() goto skiplast }
    if Volume==0 or Volume>15 { Volume = 12 }
    txt.color2(1,6)
    txt.clear_screen()
    txt.nl()
    ; void diskio.fastmode(1)
    LOAD_VIDKIT_LIBRARY()
    ; UNCOMPRESS_VIDKIT()
    SPLASH_SCREEN()
    cx16.set_screen_mode(1)
    txt.cp437()
    SAVE_DC_VIDEO = cx16.VERA_DC_VIDEO

getfilename:
    GetMediaFile_BASENAME()
    IN_PLAY = false
    if BASENAME=="EXIT" { goto alldone }
    AUTOPLAY = true

LoadTheVideo:
      if AUTOPLAY { Fade2Black() } else { Fade2Color($000F) }   ; picker fades to black before first play
      HIDE_SPRITES()
ReLoadVideo:
      CLOSE_ALL()
      LOAD_AND_PREP()                     ; also picks up the bookmark, if any
      if IS_STD_VIDEO or IS_PCM_ONLY { cx16.i2c_write_byte($42,$05, $00) }  ; Turn OFF the (disc) Activity Light
      ; cx16.i2c_write_byte($42,$05, $00)   ; Turn OFF the (disc) Activity Light
      VIDKIT.KEEP_OPEN = true
      VIDKIT.DISABLE_RESTORE = true
      if IN_PLAY and LOOP_PLAY_ON { goto PlayTheMedia }
      if AUTOPLAY {
         ; picked from the list: play immediately. Unplayable files
         ; fall through to the information screen instead.
         AUTOPLAY = false
         CalcCanPlay()
         if IS_SPI_VIDEO {
            if PENV.IS_HOST {
               ; SPI video can't play on HOSTFS: warn, back to the list
               void SPI_PROMPT(true)
               CLOSE_MEDIA()
               goto getfilename
            }
            choice = SPI_PROMPT(false)
            picker.mouse_off()
            if choice==_KEY_ESC { CLOSE_MEDIA() goto getfilename }
            if choice==_CTRL_F {
               FragCheckSPI(true)
               ; fragmented: the warning was shown, go to the info screen
               if IS_FRAGMENTED { Fade2Color($000F) goto GetUserChoice }
            }
         }
         if CAN_PLAY {
            ; the plain-text audio screen draws its box over whatever is on
            ; screen - give it the info screen underneath, not the file list
            if IS_PCM_ONLY { PrintMediaAttributes() }
            choice = _KEY_F1
            goto GOPLAY
         }
      }
GetUserChoice:
      PrintMediaAttributes()
      MenuBar()
      picker.mouse_on()
      MyPlot(27,40)            ; right of the two-line environment info
      showTextLayer()
      FadeToDEFPAL()
      cbm.CLRCHN()
      ; MyPlot(27,1)
      ; diskio.fastmode(3)
      ; void diskio.status_code()
      sprites.show(2)
      SetScreenTimer()
getchoice:
      choice = cbm.GETIN2()
      picker.check_blank()     ; Blank the Screen after the timeout
      if choice==0 { choice = MouseChoice() }
SkipChoice:
      if choice==0 { goto getchoice }
      ; If a key is pressed reset the Screen blank timer
      cx16.VERA_DC_VIDEO = SAVE_DC_VIDEO
      SetScreenTimer()
GOPLAY:
      if choice==_KEY_F1 {
         if CAN_PLAY {
            IN_PLAY = true
            IN_LOOP = false
            if IS_SPI_VIDEO and (ROM.VERSION==49) and ROM.IsPreRelease { SPI_WARN() }
            HIDE_SPRITES()
            goto PlayTheMedia
          }
       }

      if choice==_KEY_UP {
          if Volume < 15 {Volume++ ShowVolume() Woop()} else { Boing() KEYFLUSH() }
          goto getchoice
      }

      if choice==_KEY_DOWN {
         if Volume > 0 {Volume-- ShowVolume() Woop()}  else { Boing()  KEYFLUSH() }
         goto getchoice
      }

      if choice==_CTRL_F and IS_SPI_VIDEO and (not PENV.IS_HOST){
         FragCheckSPI(false)
         Fade2Color($000F)
         goto GetUserChoice
      }

     if choice==_KEY_F5 { LOOP_PLAY_ON=not LOOP_PLAY_ON ShowLoop() goto getchoice }

     if choice==_KEY_F3 { CLOSE_MEDIA() goto getfilename }

     if choice==_KEY_F4 and UseBookMark {
        ClearUpperRows()
        CleanUpMarkFile()
        CLOSE_MEDIA()
        SEND_BASENAME()
        MyPlot(1,1)
        txt.print("\x99") txt.print(AUDFILE) txt.print("\x96 Removed\x05!")
        MyPlot(3,2)
        WaitForKey_RestoreColor()
        Fade2Color($000F)
        HIDE_SPRITES()
        goto ReLoadVideo
     }

     if choice==_KEY_F2 and IS_VIDEO and IS_SUPPORTED_VIDEO {   ; same test as the menu line: never for a PCM-only file
         ;ResetAllLFNs()
         MakeStandAlonePlayer()
         MyPlot(3,2)
         WaitForKey_RestoreColor()
         goto LoadTheVideo
      }

      if choice==_KEY_ESC {
         ClearUpperRows()
         MyPlot(1,1)
         txt.print(" \x9BAre you \x05SURE\x9B you want to \x05Exit \x9B(\x9EY\x1E/\x9EN\x9B) \x81?")
         txt.color2(5,0)
         if not Yes(1,40) {
            txt.color2(1,6)
            goto GetUserChoice               ; No: redraw the information screen
         }
         if IS_STD_VIDEO or IS_PCM_ONLY { cx16.i2c_write_byte($42,$05, $FF) }  ; Turn on the (disc) Activity Light
         goto alldone
       }
      Boing()
      goto getchoice

PlayTheMedia:
      picker.mouse_off()
      if IS_PCM_ONLY { SETUP_PLAY_PCMSTREAM() } else { Fade2Black() }
      if IS_STD_VIDEO or IS_PCM_ONLY { cx16.i2c_write_byte($42,$05, $FF) }  ; Turn on the (disc) Activity Light
      PLAY_MEDIA()
      VIDKIT.PAL_RESET = false
      if not (MANEXIT==$FF) {
         if LOOP_PLAY_ON {
            if UseBookMark { CleanUpMarkFile() }
            IN_LOOP=true
            if IS_PCM_ONLY { %asm {{ nop }} } else { Fade2Black() }
            VIDKIT.MANAGE_SCREEN = false
            goto ReLoadVideo
         }
         sys.wait(90)
      }
      VIDKIT.MANAGE_SCREEN = true
      if MANEXIT==$FF {Fade2Color($000F)} else { Fade2Black() }
      RESTORE_SCREEN()
      showTextLayer()
      cx16.set_screen_mode(1)
      txt.cp437()

 skiptoend:
    if MANEXIT==$FF {
       IN_PLAY = false
       cx16.vaddr(1,$FA08,0,1)
       cx16.VERA_DATA0 = $EE
       cx16.VERA_DATA0 = $0F
       cx16.VERA_DC_HSCALE=88
       MyPlot(2,2)
       txt.print(" \x05Saving BookMark\x0D\x0D")
       txt.print("        Filename\x1E: \x9E") txt.print(BASENAME) txt.print(".MARK\x0D\x0D\x05")

       if IS_PCM_ONLY {
          GetAudioProperties()
          AdjustAudioPosition()
          Frame=NewAudioPosition
          txt.print("         At Time\x1E: \x99") PrintTime(Frame/AudioByteRate)
       }
        else
          { Frame = VIDKIT.Frame txt.print("        At Frame\x1E: \x99") floats.print(Frame) }

       FadeToDEFPAL()
       strings.copy("@:", TMPFILE)
       strings.append(TMPFILE,BASENAME)
       strings.append(TMPFILE,".MARK,S,W")
       fopen(7,drivenumber,7,TMPFILE)
       %asm {{
               ldx #7
               jsr cbm.CHKOUT
               ldx #<p8v_Frame
               ldy #>p8v_Frame
               lda #5
               jsr cx16.MCIOUT
            }}
       cbm.CLRCHN()
       cbm.CLOSE(7)
       strings.copy("@:", TMPFILE)
       strings.append(TMPFILE,BASENAME)
       strings.append(TMPFILE,".MARK,S,R")
       fopen(7,drivenumber,7,TMPFILE)
       cbm.CLOSE(7)
       if IS_PCM_ONLY { Frame=0 }
    } else
       { CleanUpMarkFile() }
      Volume = AUDIO_CTRL & $0F
      Fade2Black()
      cx16.set_screen_mode(1)
      goto LoadTheVideo
alldone:
   picker.mouse_off()
   Fade2Color($000F)
   showTextLayer()
   HIDE_SPRITES()
   cx16.set_screen_mode(1)
   txt.iso_off()
   txt.uppercase()
   txt.color2(1,6)
   txt.cls()
   ProgramBanner()
   FadeToDEFPAL()

skipoutputstuff1:
   MyPlot(12,1)
   txt.color2(13,6)
   if BASENAME=="EXIT" { goto skipoutputstuff2 }
   ISOUpper(BASENAME)      ; PETSCII mode now: lower case would print as graphics
   txt.print("\x0D ")  txt.print(BASENAME) txt.color(7)
skipoutputstuff2:
   txt.print(" DONE \x05!\x0D\x0D")
skiplast:
   ; void diskio.status()
   ; cx16.i2c_write_byte($42,$05, $00)   ; Turn OFF the (disc) Activity Light
   CLOSE_ALL()
   HIDE_SPRITES()
 }
}
