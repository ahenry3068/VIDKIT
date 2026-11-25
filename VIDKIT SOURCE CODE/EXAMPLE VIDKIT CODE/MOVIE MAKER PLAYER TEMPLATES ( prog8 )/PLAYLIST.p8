%encoding iso
%option no_sysinit
%import textio
%import conv
%import diskio
%import strings
%import fnames
%import sprites
%import floats
%import verafx
%import VIDKIT_COMMON
%zeropage basicsafe
%zpreserved $22, $60

Errors {
sub HALT(str msg) {
  cx16.set_screen_mode(1)
  txt.print(msg)
  main.showTextLayer()
  main.SetDefaultPalette()
  cx16.enter_basic(false)
}
}

TEXTLIST {
bool IS_CURRENTFOLDER_LIST
ubyte OB
str LINE = "?"*255
bool IsWindowsFile
bool NOT_TEXT
bool IsLoaded = false
bool THE_END
bool FILE_FOUND
ubyte Terminator
ubyte StartBank
ubyte LastBank
uword END_ADDR
uword NUM_LOOPS
uword NUM_FOUND_FILES
ubyte cBANK
uword cPOS
uword CURRENT_LINE

sub getTerminator(str tFile) {
ubyte Char
ubyte EOF
ubyte Ctr
bool Done
    main.fopen(5,8,5,tFile)
    cbm.CHKIN(5)
    Done = false
    Ctr = 0
    NOT_TEXT = false
    IsWindowsFile = false
    while not Done {
      Char = cbm.GETIN2()
      EOF = cbm.READST()
      Ctr++
      if Char==10 or Char==13 {
         Terminator = Char
         Done = true
         if Terminator==13 {
           Char = cbm.GETIN2()
           EOF = cbm.READST()
           Ctr++
           IsWindowsFile = (Char==10)
         } else { IsWindowsFile = false }
      }
      if EOF>0 or (Ctr==0) {
         NOT_TEXT = true
         Done = true
         Terminator = 0
      }
    }
    cbm.CLOSE(5)
    cbm.CLRCHN()
}

sub REWIND() {
 if IsLoaded {
  THE_END = false
  cPOS = $A000
  cBANK = StartBank
  CURRENT_LINE = 0
 }
}

sub SEEK(uword LineNumber) {
  if IsLoaded {
    REWIND()
    while CURRENT_LINE < LineNumber {
      GetNextLine()
      if THE_END { break }
    }
  }
}

sub GetNextLine()  {
ubyte i
ubyte SB
    SB=peek(0)
    if THE_END { LINE[0]=0 return}
    defer {
      if THE_END {NUM_LOOPS++}
    }
    i = 0
    cx16.rambank(cBANK)
    do {
     LINE[i] = @(cPOS)
     cPOS++ i++
     if cPOS==$C000 { cPOS=$A000 cBANK++ cx16.rambank(cBANK) }
     if i==0 { Errors.HALT("\x0DLINE TO LONG\x0D") }
    } until @(cPOS)==Terminator or (cBANK==LastBank and cPOS==END_ADDR)
    LINE[i] = 0
    THE_END = (cBANK==LastBank and cPOS >= END_ADDR) or (cBANK > LastBank)
    CURRENT_LINE++
    if not THE_END {
       cPOS++
       if cPOS==$C000 { cPOS=$A000 cBANK++ cx16.rambank(cBANK) }
       if IsWindowsFile { cPOS++ }
       if cPOS==$C000 { cPOS=$A000 cBANK++ cx16.rambank(cBANK) }
       THE_END = (cBANK==LastBank and cPOS>=END_ADDR) or (cBANK > LastBank)
    }
    cx16.rambank(SB)
}

sub NextFileName() -> str {
ubyte L
top:
    FILE_FOUND = false
    GetNextLine()
    strings.trim(LINE)
    main.ISOUpper(LINE)
    L = strings.length(LINE)
    if L==0 and not THE_END  { goto top }
    if THE_END {
       if L==0 { return LINE }
    }

    if main.FExists(LINE,L) {
      FILE_FOUND = true
      if NUM_LOOPS==0 { NUM_FOUND_FILES++ }
      return LINE
    }

    if THE_END { return "\x00" }
    goto top
}


sub LoadFile(str mFile, ubyte lBank) -> bool {
    IS_CURRENTFOLDER_LIST = false
    IsLoaded = false
    if main.FExists(mFile, strings.length(mFile)) {
       StartBank = lBank
       cBANK = lBank
       cPOS = $A000
       CURRENT_LINE = 0
       getTerminator(mFile)
       if NOT_TEXT {
          txt.clear_screen() txt.nl()
          txt.print(" \x07\x05Not a valid TEXT FILE \x99!\x96!\x99!\x0D")
          sys.wait(300)
          %asm {{ nop }}
       } else {
         cx16.rambank(lBank)
         END_ADDR = diskio.load_raw(mFile,cPOS)
         LastBank = @(0)
         IsLoaded = true
         THE_END = false
         ; txt.print("LOADED: ") txt.print(mFile) txt.nl()
         ; sys.wait(90)
       }
    }
    return IsLoaded
}

str LST_NAME="TEMPFOLDER.LST"
bool FOLDERLIST_IS_SAVED
sub SaveIt() {
    FOLDERLIST_IS_SAVED = false
    REWIND()
    if diskio.exists(LST_NAME) { diskio.delete(LST_NAME) }
    if diskio.f_open_w(LST_NAME) {
       diskio.reset_write_channel()
       do {
        GetNextLine()
        txt.print(LINE) txt.nl()
       } until THE_END
       diskio.f_close_w()
       cbm.CLRCHN()
       REWIND()
       FOLDERLIST_IS_SAVED = true
    }
}


sub FOLDER_LIST(ubyte StartB) -> bool {
alias AUDFILE = main.AUDFILE
alias drivenumber = main.drivenumber

        ubyte CurB
        uword LPtr
        uword mCount
        ubyte i
        bool started = true
        ubyte @zp lastchar = 1
        bool inquote = false
        OB = @(0)
        ; -- Prints the directory contents to the screen. Returns success.
        txt.clear_screen()
        CurB = StartB
        cx16.rambank(CurB)
        LPtr = $A000
        mCount = 0
        Terminator = 10
        IsWindowsFile = false
        cbm.SETNAM(11, "$:*=P")
internal_dir:
        cbm.SETLFS(11, drivenumber, 0)
        ubyte status = 1
        void cbm.OPEN()          ; open 11,8,0,"$"
        if_cs
            goto io_error

        %asm {{
                ldx #11
                jsr cbm.CHKIN
             }}

        repeat 4 {
            void cbm.CHRIN()     ; skip the 4 prologue bytes
        }

        ; while not stop key pressed / EOF encountered, read data.
        status = cbm.READST()
        if status!=0 {
            status = 1
            goto io_error
        }
        ubyte LineCount = 0
        while status==0 {
            ubyte low = cbm.CHRIN()
            ubyte high = cbm.CHRIN()
            ubyte @zp character
            i = 0
            repeat {
                character = cbm.CHRIN()
                if character==0
                    break
                if character == 34 { inquote = not inquote }
                if inquote and character != 34 { AUDFILE[i] = character i++ }
            }
            AUDFILE[i] = 0
            main.ISOUpper(AUDFILE)

            bool IsAud = (strings.compare(&AUDFILE + (i-3) as uword,"ZCM") == 0) or (strings.compare(&AUDFILE + (i-3) as uword,"WAV")==0)
            if strings.compare(&AUDFILE + (i-3) as uword,"SPV") == 0 or IsAud {
               mCount++
               ubyte j
               for j in 0 to i-1 {
                 @(LPtr) = AUDFILE[j]
                 LPtr++
                 if LPtr > $BFFF { LPtr=$A000 CurB++ cx16.rambank(CurB) }
               }
               @(LPtr) = 10
               LPtr++
               if LPtr > $BFFF { LPtr=$A000 CurB++ cx16.rambank(CurB) }
               main.MyPlot(0,0)
               for j in 0 to 3 { main.spc(80) }
               main.MyPlot(1,1)
               txt.print("\x05Found \x99") txt.print_uw(mCount) txt.print(" \x05 media files \x96!\x05\x0D\x0D ")
               txt.print(AUDFILE)
               sys.wait(3)
            }

            void cbm.CHRIN()     ; skip 2 bytes
            void cbm.CHRIN()
            status = cbm.READST()
            void cbm.STOP()
breaker:
            if_z
                break
        }
        status = cbm.READST()

io_error:
        %asm {{                                 ; restore default i/o devices
               jsr cbm.CLRCHN
               lda #11
               jsr cbm.CLOSE
             }}
        if mCount==0
          { IsLoaded = false }
        else {
          LPtr++
          if LPtr > $BFFF { LPtr=$A000 CurB++ cx16.rambank(CurB) }
          StartBank = StartB
          LastBank = CurB
          END_ADDR = LPtr
          IsLoaded = true
          IS_CURRENTFOLDER_LIST = true
          REWIND()
          if main.Ask(7, 2,"\x05Save this List for Editing\x96:") {
             txt.color2(1,6)
             SaveIt()
          }
          txt.color2(1,6)
        }
        cx16.rambank(OB)
        return IsLoaded
}

}


ROM {
      ubyte VERSION
      bool  IsPreRelease
}

PENV {
           str HOST = "?"*5
           str PETSCII_VERSTR="\x05VERSION \x992\x1E.\x990"
           str ISOASC_VERSTR="\x05 Version \x992\x1E.\x990"
           str CPU="\x9B65\x99C\x9B02\x00" + "?"*2
           uword cpu=6502
           bool IS_HOST
           bool ON_HARDWARE
           bool ON_EMU
           ubyte HIGH_BANK
           sub FIND_CPU() { if sys.cpu_is_65816() { strings.copy("\x9B65\x99816",CPU) cpu=816} }
           sub IS_HOST_FS()-> bool {
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
               return ((HOST=="HOST") and ON_EMU)
             }

&ubyte EMUIndicator1 = $9FBE
&ubyte EMUIndicator2 = $9FBF

sub GetRunEnvironment() {
         FIND_CPU()
         ROM.VERSION, ROM.IsPreRelease = cx16.rom_version()
         ON_EMU = ( (EMUIndicator1==49) and (EMUIndicator2==54) )
         IS_HOST=IS_HOST_FS()
         ON_HARDWARE = not ON_EMU
         %asm {{
            sec
            jsr $FF99  ; memtop
            dea
            sta p8v_HIGH_BANK
            clc
         }}
     }
}

main  {
      &ubyte[32] vHeader = $500
 &ubyte[3] vHdrNUMFRAMES = $50D
           &ubyte Volume = $520

       &ubyte[8] zHeader = $522
      &ubyte[44] wHeader = $522
   &ubyte[44] AUD_Header = $522

&ubyte AUDIO_CTRL = $9F3B
const uword joystick_get = $FF56

VKIT:
%asmbinary "VIDKIT.Z"
VKIT_END:


uword tmpw
uword tmpw2
float Frame
float BFrame

; will be set to $FF if Video is exited by the user
; in the Bank where the Video Engine code is located
alias MANEXIT = VIDKIT.MANEXIT
ubyte drivenumber=8

alias f_size_low = cx16.r2
alias f_size_high = cx16.r3

ubyte[85] butterfly = [$8F,$93,$9C,$12,$DF,$92,$20,$20,$20,$20,$20,$12,$A9,$0D,$9A,$12,$A5,$DF,$92,$20,$20,$20,$12,$A9,$A7,
                       $92,$0D,$9F,$12,$B5,$20,$DF,$92,$20,$12,$A9,$20,$B6,$0D,$1E,$20,$B7,$12,$BB,$92,$20,$12,$AC,$92,$B7,
                       $0D,$9E,$20,$AF,$12,$BE,$92,$20,$12,$BC,$92,$AF,$0D,$81,$AA,$12,$20,$92,$A9,$20,$DF,$12,$20,$92,$B4,
                       $0D,$1C,$B6,$A9,$20,$20,$20,$DF,$B5,0]

; This section of code is not ALL THE VIDKIT API
; just what I needed for this player of it !
; There is more to the API available.
extsub @bank VID_BANK1 $A000 = VIDKIT_INIT()
extsub @bank VID_BANK1 $A003 = LOAD_PLAY()
extsub @bank VID_BANK1 $A006 = LOAD_MEDIA()
extsub @bank VID_BANK1 $A009 = PLAY_MEDIA()
extsub @bank VID_BANK1 $A00C = SET_START_FRAME()
extsub @bank VID_BANK1 $A01E = CLOSE_MEDIA()
extsub @bank VID_BANK1 $A024 = hideTextLayer()
extsub @bank VID_BANK1 $A027 = hideGraphicsLayer()
extsub @bank VID_BANK1 $A02D = showTextLayer()
extsub @bank VID_BANK1 $A02A = ShowBothLayers()
extsub @bank VID_BANK1 $A036 = SET_STARTTIME_JIFFIES()
extsub @bank VID_BANK1 $A03F = SET_KEYEXTRA(ubyte tKey @A)

extsub @bank VID_BANK2 $A012 = SET_FRAME_DRIVER(uword DrivePtr @XY)
extsub @bank VID_BANK2 $A024 = HIDE_SPRITES()
extsub @bank VID_BANK2 $A02A = SetDefaultPalette()
extsub @bank VID_BANK2 $A039 = Fade2Black()
extsub @bank VID_BANK2 $A03C = pal2black()
extsub @bank VID_BANK2 $AA15 = RESTORE_SCREEN()

extsub @bank VID_BANK3 $B412 = FadePal(uword ThePal @R11)
extsub @bank VID_BANK3 $B415 = FadeToDEFPAL()
extsub @bank VID_BANK3 $B418 = Fade2Color(uword PalEntry @R1)
; FadeInPal $B412

alias IS_PCM_ONLY = VIDKIT.IS_PCM_ONLY
alias PCM_IS_STEREO = VIDKIT.PCM_IS_STEREO
alias PCM_IS_16BIT = VIDKIT.PCM_IS_16BIT
alias IS_VIDEO = VIDKIT.IS_VIDEO

bool SPI_HOST_FLAG = false

&ubyte STASHVEC = $03B2
&ubyte AUDIO_FIFO = $9F3D
&byte AUDIO_FIFOs = $9F3D
&ubyte VERA_AUDIORATE = $9F3C


str BASENAME = "**CHANGEMEHERE**\x00"+"?"*96
str BOOKNAME = "**BOOKSTRINGHERE**\x00"+"?"*96

str BASE_EXT = "?"*8
; str BASENAME = "?"*96
str PartName = "?"*16
str TMPST = "?"*32
str PAD = " "*4
str VIDFILE = "MOVIE"+"?"*96
str PAD3 = " "*4
str AUDFILE = "?"*96
str PALFILE = "?"*96
str PAD4 = " "*4
str PRGFILE = "?"*96
str PAD5 = " "*4
str TMPFILE = "?"*96
str VEXT = iso:".SPV"
str AEXT = iso:".SVA"
str PEXT = iso:".PRG"
str FOUND_EXT = ".XXX" + "?"*6
str AnyMessage = iso:"\x9BAny \x05KEY\x9B to continue\x99."


bool ShowBanners = true
ubyte OB
ubyte j

ubyte VID_BANK1
ubyte VID_BANK2
ubyte VID_BANK3

alias NumFramesHI = cx16.r1
alias NumFramesLO = cx16.r2

uword LMRK
sub IS_MEDIA() -> bool {
 return (BASE_EXT==".WAV") or (BASE_EXT==".SPV") or (BASE_EXT==".ZCM")
}

sub SPLITNAME(str sName) {
ubyte i
ubyte L
  i = strings.length(sName)
  L = i
  BASE_EXT[0]=0
  while sName[i] != '.' and i>0 { i-- j++ }
  if i==0 {
     strings.copy(sName, BASENAME)
  } else {
     strings.right(sName,j,BASE_EXT)
     strings.left(sName,L-j,BASENAME)
  }
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


sub directory() -> bool {

        bool started = true
        ubyte @zp lastchar = 1
        bool inquote = false

        ; -- Prints the directory contents to the screen. Returns success.

        cbm.SETNAM(11, "$:*=P")
internal_dir:
        cbm.SETLFS(11, drivenumber, 0)
        ubyte status = 1
        void cbm.OPEN()          ; open 11,8,0,"$"
        if_cs
            goto io_error

        %asm {{
                ldx #11
                jsr cbm.CHKIN
             }}

        repeat 4 {
            void cbm.CHRIN()     ; skip the 4 prologue bytes
        }

        ; while not stop key pressed / EOF encountered, read data.
        status = cbm.READST()
        if status!=0 {
            status = 1
            goto io_error
        }
        ubyte LineCount = 0
        while status==0 {
            ubyte low = cbm.CHRIN()
            ubyte high = cbm.CHRIN()
            if LineCount == 27 { txt.print("\x0D\x99...\x96more  \x99[\x9ELeft\x9F-\x9ECtrl\x99]     [\x9EENTER\x99] \x9F- \x05Done")
                          if started { FadeToDEFPAL() started = false }
                          %asm {{
getnextbut:                      lda #0
                                 jsr p8c_joystick_get
                                 and #%00010000
                                 beq p8l_io_error
                                 txa
                                 and #128
                                 bne getnextbut
donewaitlist:                    nop
                               }}
                             txt.print("\x0D")
                                 LineCount=0}
            ubyte @zp character
            i = 0
            repeat {
                character = cbm.CHRIN()
                if character==0
                    break
                if character == 34 { inquote = not inquote }
                if inquote and character != 34 { AUDFILE[i] = character i++ }
            }
            AUDFILE[i] = 0
            ISOUpper(AUDFILE)

            if strings.compare(&AUDFILE + (i-3) as uword,"LST") == 0  {
               txt.print(" \x9B") txt.print_uw(mkword(high, low)) txt.column(10)
               txt.print("\x05")
               txt.print(AUDFILE) LineCount++ txt.nl() }

            void cbm.CHRIN()     ; skip 2 bytes
            void cbm.CHRIN()
            status = cbm.READST()
            void cbm.STOP()
breaker:
            if_z
                break
        }
        status = cbm.READST()

io_error:
        %asm {{                                 ; restore default i/o devices
               jsr cbm.CLRCHN
               lda #11
               jsr cbm.CLOSE
             }}
        if status!=0 and status & $40 == 0 {            ; bit 6=end of file
            txt.print("\ni/o error, status: ")
            txt.print_ub(status)
            txt.nl()
            return false
        }
        if started { FadeToDEFPAL()  }
        return true
}



sub ShowDirectory_LIST() {
       txt.clear_screen()
       txt.print("\x0D\x05")
       directory();
       %asm {{
gl:            jsr cbm.GETIN
               bne gl
            }}
       txt.print("\x0D\x0D")
       WaitForKey_RestoreColor()
}

ubyte WarnCount = 0
sub SPI_WARN() {
    if WarnCount > 1 or HAS_LOOPED { return }
    WarnCount += 1
    txt.cp437()
    ClearUpperRows()
    MyPlot(1,1)
    txt.print(" \x9BYou are running a \x96prerelease \x99r49 \x05ROM.")
    MyPlot(2,1)
    txt.print(" \x96This \x99MAY\x96 work \x1E!\x1F....\x9B[\x05Recommend \x99UPGRADE\x9B]\x05")
    MyPlot(3,2)
    WaitForKey_RestoreColor()
}

sub MyPlot(ubyte y, ubyte x) {
    txt.row(y)
    txt.column(x)
}

sub ProgramBanner() {
    i=0
    repeat 85 { cbm.CHROUT(butterfly[i]) i +=1 }
    MyPlot(1,10)
    txt.print ("\x9C*\x9A*\x99* \x05X16 VIDKIT VIDEO LIST PLAYER ") txt.print(PENV.PETSCII_VERSTR)
    txt.print(" \x9E*\x81*\x1C*\x05")
    MyPlot(2,14)
    txt.print("\x05CPU\x1E:\x9B") txt.print(PENV.CPU) txt.print("\x05  ")
    if PENV.ON_EMU { txt.print("EMULATOR") } else { txt.print("HARDWARE") }
    MyPlot(3,10)
    txt.print ("\x9BAUTHOR\x1E: \x05ANTHONY W. HENRY")
    MyPlot(5,10)
    txt.print("\x9ETHIS SOFTWARE IS UNDER THE MIT LICENSE")
    MyPlot(6,10)
    txt.print("    \x05(\x9BPERMISSIVE\x05)")
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
    repeat 16 { unroll 4 { cx16.VERA_DATA0 = 0 } }
}


sub fopen(ubyte lfn, ubyte device, ubyte sa, str filename) {
    cbm.SETLFS(lfn, device, sa)
    cbm.SETNAM(strings.length(filename), filename)
    void cbm.OPEN()
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

bool success
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

sub BuildBookMarkName(bool ForWrite) {
    if ForWrite
       { strings.copy("@:", BOOKNAME) }
    else
       { BOOKNAME[0] = 0 }
    fnames.parse(BASENAME)
    if fnames.PLength > 0 {
       strings.append(BOOKNAME,fnames.PATH)
    }
    strings.append(BOOKNAME,fnames.NAME)
    strings.append(BOOKNAME,".LMARK")
    if ForWrite { strings.append(BOOKNAME,",S,W")}
}

sub WriteBookMark() {
       Fade2Black()
       HIDE_SPRITES()
       hideGraphicsLayer()
       cx16.set_screen_mode(3)
       txt.cp437()
       txt.color2(1,6)
       txt.clear_screen()
       MyPlot(2,2)
       txt.print(" \x05SAVING BOOKMARK \x96!")
       unroll 2 { txt.nl() }
       txt.print(" \x05 MEDIA NAME\x1E: ") txt.print(TEXTLIST.LINE) txt.nl()
       if VIDKIT.IS_PCM_ONLY
          { Frame=AudioFilePosition()
            txt.print(" \x05   FILEPOS\x99#\x1E: \x9E") txt.print(conv.str_ulhex(Frame as long)) txt.print("\x0D\x05")
         }
       else {
          Frame=VIDKIT.Frame
          txt.print(" \x05     FRAME\x99#\x1E: \x9E") floats.print(Frame) txt.print("\x0D\x05")
         }
       showTextLayer()
       Fade2Color($000F)
       FadeToDEFPAL()
       BuildBookMarkName(true)
       fopen(9,drivenumber,9,BOOKNAME)
       cbm.CHKOUT(9)
       uword NPtr = &Frame
       repeat 5 { cbm.CHROUT(@(NPtr)) NPtr++ }
       c = strings.length(TEXTLIST.LINE)
       cbm.CHROUT(c)
       for i in 0 to c-1 { cbm.CHROUT(TEXTLIST.LINE[i])}
       cbm.CLOSE(9)
       cbm.CLRCHN()

       ; after the above CBM fat32 doesn't automatically flush a small write cache
       ; reopening the file with a different LFN "flushs" the above write to disc
         BuildBookMarkName(false)
         fopen(7,drivenumber,7,BOOKNAME)
         cbm.CLOSE(7)
         cbm.CLRCHN()

       sys.wait(120)
}


sub ReadBookMark() {
       fopen(9,drivenumber,9,BOOKNAME)
       cbm.CHKIN(9)
       uword NPtr = &BFrame
       repeat 5 { @(NPtr) = cbm.GETIN2()  NPtr++ }
       c = cbm.GETIN2()
       for i in 0 to c-1 { TMPFILE[i] = cbm.GETIN2() }
       TMPFILE[c] = 0
       cbm.CLOSE(9)
       cbm.CLRCHN()
}

sub SeekBookMark() -> bool {
bool Found
    Found = false
    TEXTLIST.REWIND()
    do {
      TEXTLIST.GetNextLine()
      ISOUpper(TEXTLIST.LINE)
      strings.trim(TEXTLIST.LINE)
      strings.trim(TMPFILE)
      if strings.compare(TMPFILE,TEXTLIST.LINE)==0 { Found=true }
    } until Found or TEXTLIST.THE_END
    txt.nl() txt.nl()
    if not Found {
       TEXTLIST.REWIND()
       txt.print("\x96 Missing\x99:\x1E") txt.print(TMPFILE) txt.nl()
       UseBookMark = false
       sys.wait(90)
    } else {
      Found = verifyMedia(TEXTLIST.LINE)
      if Found {
         txt.print("\x05 Media Found\x99:\x1E ") txt.print(TEXTLIST.LINE) txt.nl()
      } else {
         txt.print("\x96 Media\x99:\x1E") txt.print(TMPFILE) txt.print("\x96NOT \x05Verified\x99") txt.nl()
      }
    }
  txt.nl() txt.nl()
  return Found
}


float Divisor
float audFilePosition
float NewPCMTime
sub AdjustAudioPosition() {
  Divisor = 1
  if VIDKIT.PCM_IS_16BIT { Divisor = Divisor * 2 }
  if VIDKIT.PCM_IS_STEREO { Divisor = Divisor * 2 }
  if Divisor > 1 { while (floats.floor(audFilePosition/Divisor) * Divisor) != audFilePosition { audFilePosition = audFilePosition + 1 } }
}

sub AudioFilePosition() -> float {
    my_f_tell(VIDKIT.AudioLFN)
    return (65536.0 * (cx16.r1 as float)) + (cx16.r0 as float)
}

sub SeekMediaPosition() {
       if VIDKIT.IS_VIDEO {
          FLOAT_TO_INT32(BFrame, &cx16.r0)
          SET_START_FRAME()
       }
       if VIDKIT.IS_PCM_ONLY {
          audFilePosition = BFrame
          AdjustAudioPosition()
          FLOAT_TO_INT32(floats.round((audFilePosition/VIDKIT.PCM_BYTEsPerSecond) * 60.0), &cx16.r4)
          SET_STARTTIME_JIFFIES()
       }
}


sub CheckBookMark() -> bool {
    if c != 27 { c = cbm.GETIN2() }
    fnames.parse(BASENAME)
    if fnames.PLength > 0
       { strings.copy(fnames.PATH, BOOKNAME)}
    else
       { BOOKNAME[0] = 0 }
    strings.append(BOOKNAME, fnames.NAME)
    strings.append(BOOKNAME,".LMARK")

    txt.print("\x0D\x0D \x05CHECKING FOR\x1E: \x99") txt.print(BOOKNAME) txt.print("\x0D\x05")

    if FExists(BOOKNAME,strings.length(BOOKNAME)) {
       txt.print("\x0D \x05BOOKMARK FILE FOUND\x1E!")
       ReadBookMark()
       sys.wait(30)
       return true
   }
  else
   { txt.print(" \x0D\x05NO BOOKMARK !\x0D\x0D") sys.wait(90) c=0 return false }
}


sub ScratchBookMark() {
    fnames.parse(BASENAME)
    if fnames.PLength > 0
       { strings.copy(fnames.PATH, BOOKNAME)}
    else
       { BOOKNAME[0] = 0 }
    strings.append(BOOKNAME, fnames.NAME)
    strings.append(BOOKNAME,".LMARK")

   if FExists(BOOKNAME,strings.length(BOOKNAME)) {
      diskio.delete(BOOKNAME)
      void diskio.status()
   }
}


bool CAN_PLAY

sub CleanUpMarkFile() {
    strings.copy(BASENAME,AUDFILE)
    strings.append(AUDFILE,".LMARK")
    if FExists(AUDFILE,strings.length(AUDFILE)) { diskio.delete(AUDFILE) }
}

sub spc(ubyte L @ R11 ) { repeat L { cbm.CHROUT(32) } }

sub Print_RUN_Environment() {
  MyPlot(29,7)
  if PENV.ON_EMU and PENV.IS_HOST { txt.print("\x1C(\x99HOST \x05File System\x1C)") } else { txt.print("\x1C(\x99Fat\x1E32 \x05File System\x1C)") }

  MyPlot(28,1)
  txt.print(PENV.CPU)
  spc(2) txt.print ("\x9BOn\x1E: \x05")
  if PENV.ON_EMU { txt.print("X16 Emulator") }
  if PENV.ON_HARDWARE { txt.print("X16 Hardware") }
  spc(2)
  txt.print("\x9BROM\x1E: \x9Cr\x99") txt.print(conv.str_ub(ROM.VERSION))
  if ROM.IsPreRelease { txt.print("\x1E(\x9BPre-Release\x1E)") }
}

sub WaitForKey_RestoreColor() {
   txt.print(AnyMessage)
   txt.waitkey()
   txt.color2(1,6)
}


sub BAD_ROM_MESSAGE() {
       txt.print("\x07\x0D\x9B   THIS PROGRAM \x05REQUIRES\x9B ROM VERSION \x99R\x0548 \x9BOR \x05 HIGHER\x96 !")
       txt.print("\x0D\x05   VERSION\x1E: \x99") txt.print(conv.str_ub(ROM.VERSION)) txt.print("\x9B WAS FOUND.\x0D")
       if ROM.IsPreRelease { txt.print("\x0D\x05   PRE-RELEASE ROM\x0D") }
}


sub PokeBASENAME() {
    OB = peek(0)
    cx16.rambank(0)
    if fnames.PLength > 0 {
       strings.copy(fnames.PATH, $BF00)
       strings.append($BF00, fnames.NAME)
    } else { strings.copy(fnames.NAME, $BF00) }
    cx16.rambank(OB)
}


sub verifyMedia(str mName) -> bool {
bool GoodFile
     IS_VIDEO = false
     OB = peek(0)
     cx16.rambank(TEXTLIST.LastBank + 1)
     ISOUpper(mName)
     fnames.parse(mName)
     if fnames.ELength > 0 {
        GoodFile = ((fnames.EXT==".SPV") or (fnames.EXT==".WAV") or (fnames.EXT==".ZCM"))
        if GoodFile { GoodFile= GoodFile and FExists(mName, strings.length(mName)) goto goodexit
        }
     } else {
        strings.copy(mName,$A000)
        strings.append($A000,".SPV")
        GoodFile = FExists($A000, strings.length($A000))
        if GoodFile {
           IS_PCM_ONLY = false
           IS_VIDEO = true
        }
        if not GoodFile {
           strings.copy(mName,$A000)
           strings.append($A000,".WAV")
           GoodFile = FExists($A000, strings.length($A000))
           if GoodFile { IS_PCM_ONLY=true }
        }
        if not GoodFile {
           strings.copy(mName,$A000)
           strings.append($A000,".ZCM")
           GoodFile = FExists($A000, strings.length($A000))
           if GoodFile { IS_PCM_ONLY=true }
        }
        if GoodFile { fnames.parse($A000) }
     }
goodexit:

   if GoodFile { PokeBASENAME() }
vDone:
   cx16.rambank(OB)
   ; VID_FILE_FOUND = GoodFile
   return GoodFile
}

ubyte c
ubyte i


boingsnd:
%asmbinary "dull.raw"
endboing:

spritelogo3:
%asmbinary "AUD64.Z"


sub Yes(ubyte y, ubyte x) -> bool {
  ubyte InChar=0
  ubyte StoredChar='N'

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

sub Ask(ubyte Y, ubyte X, str prompt) -> bool {
ubyte L = strings.length(prompt)
   MyPlot(Y,X) txt.print(prompt)
   txt.color2(7, 0)
   return Yes(Y, X + L + 2)
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

sub LoadTapeImage() {
    LoadVERAImage("ASSETS/CASSETTE.IMG")
}

sub LoadAudioCDImage() {
    LoadVERAImage("ASSETS/CDROM.IMG")
}

sub VERA2Hz() -> float {
    return (VideoHeader.VERARate as float / 128.0) * 48828.15
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

sub TapeAnimation_INIT() {
    bload("ASSETS/TAPESPRITES.BIN", 14, $A000)
    SetSpritePointers(14)
    cx16.screen_mode($80,false)
    LoadTapeImage()
    InitTapeAnimSprites()
    txt.color2(1,0)
    txt.clear_screen()
    MyPlot(26,0)
    PrintPCMFormat()
    PrintByteRate()
    txt.color2(11,0)
    PrintPlayerControls(27,false)
    cx16.GRAPH_set_colors($10,4,6)
    strings.copy(fnames.NAME,TMPFILE)
    strings.append(TMPFILE, fnames.EXT)
    Graph_CHAR(TMPFILE,57,45)
    showTextLayer()
}

sub TapeAnimationAvailable() -> bool {
    return FExists("ASSETS/CASSETTE.IMG",19) and FExists("ASSETS/TAPESPRITES.BIN",22)
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

sub LoadVERAImage(str IMAGEFILE) {
    DO_VOPEN(IMAGEFILE)
    cx16.VERA_ADDR_L = 0
    cx16.VERA_ADDR_M = 0
    cx16.VERA_ADDR_H = %00010000
    DO_VLOAD()
    cx16.memory_fill($9F23,15040,0)
}

sub PrintPlayerControls(ubyte StartRow,bool PrintTitle) {
    MyPlot(StartRow,24)
    txt.print(" \x1E[\x05\x80\x18\x80\x19\x1E]\x99-\x9BVolume")
    MyPlot(StartRow+1, 24)
    txt.print("\x1E[\x05SPC\x1E]\x99-\x9BPause")
    MyPlot(StartRow+2,24)
    txt.print("\x1E[\x05ESC\x1E]\x99-\x9BExit Play")
    if PrintTitle { MyPlot(1,3) txt.print(fnames.NAME) txt.print(fnames.EXT) }
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

sub SPI_WARNING() {
    Fade2Color($000F)
    cx16.set_screen_mode(3)
    hideGraphicsLayer()
    showTextLayer()
    txt.color2(7,2)
    txt.clear_screen()
    MyPlot(3,1)
    txt.print(fnames.NAME) txt.print(fnames.EXT) txt.print("\x0D\x05 is an SPI Direct Video.\x0D\x0D")
    txt.print(" it cannot be played on Emulator HOSTFS.\x0D\x0D")
    FadeToDEFPAL()
    WaitForKey_RestoreColor()
    Fade2Black()
}



sub PrintByteRate() { txt.print("\x0D\x05  Byte Rate: \x9E") floats.print(floats.round(VIDKIT.PCM_BYTEsPerSecond/1024.0)) txt.print(" \x96kb\x1E/\x96sec") }

sub MenuBox() {
    i=6
    MyPlot(i,45) cbm.CHROUT(201) repeat 28 { cbm.CHROUT(205) } cbm.CHROUT(187)
    repeat 13 { i++ MyPlot(i,45) cbm.CHROUT(186) repeat 28 { cbm.CHROUT(32) } cbm.CHROUT(186) }
    i++
    MyPlot(i,45) cbm.CHROUT(200) repeat 28 { cbm.CHROUT(205) } cbm.CHROUT(188)
}


sub PrintAudioPlayScreen() {
    OB = @(0)
    cx16.rambank(PENV.HIGH_BANK)
    strings.copy(fnames.NAME,$A000)
    strings.append($A000, fnames.EXT)
    if strings.length($A000) < 21 {
       strings.copy($A000,$A100)
    } else { strings.left($A000,20,$A100) }
    txt.color2(1,6)
    cx16.set_screen_mode(1)
    txt.clear_screen()
    txt.color2(7,0)
    MenuBox()
    MyPlot(8,48)
    txt.print("\x05Playing Audio File")
    MyPlot(10,48)
    txt.color(5)
    txt.print($A100)
    MyPlot(15,47)
    txt.print(" \x1E[\x05\x80\x18\x80\x19\x1E]\x99 - \x9BVolume")
    MyPlot(17,47)
    txt.print("\x1E[\x05SPC\x1E]\x99 - \x9BPause Play")
    MyPlot(19,47)
    txt.print("\x1E[\x05ESC\x1E]\x99 - \x9BExit Play")
    txt.color2(1,6)
    MyPlot(11,0)
    PrintPCMFormat()
    txt.color2(1,6)
    cx16.rambank(OB)
    hideGraphicsLayer()
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

ubyte ppos
ubyte printchar
ubyte printlen
sub SetUpPlayBar(ubyte Row, ubyte character, ubyte length) {
    txt.color2(2,11)
    printchar = character
    printlen = length
    MyPlot(Row,2)
    ppos = 0
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

sub BlackScreen() {
    txt.color2(1,0)
    txt.clear_screen()
}


sub SETUP_PLAY_PCMSTREAM() {
        HIDE_SPRITES()
        Fade2Black()
        txt.cp437()
        showTextLayer()
        if TapeAnimationAvailable() and (VIDKIT.PCM_BYTEsPerSecond < 120000) {
           TapeAnimation_INIT()
           SET_FRAME_DRIVER(&NextSpriteFrame)
       } else {
         if FExists("ASSETS/CDROM.IMG",16) {
                cx16.screen_mode($80,false)
                txt.color2(1,0)
                txt.clear_screen()
                LoadVERAImage("ASSETS/CDROM.IMG")
                PrintPlayerControls(26,true)
                txt.row(24) txt.column(0)
                PrintPCMFormat()
                PrintByteRate()
                i=35
         }
         else {
            PrintAudioPlayScreen()
            LoadHD_Logo(145,25,&spritelogo3,0,$E000,51,false)
            i=75
         }
         SetUpPlayBar(29, 178, i)
         SET_FRAME_DRIVER(&PrintPlayBar)
       }
       showTextLayer()
       FadeToDEFPAL()
}

sub NoBannerDelay() -> bool {
    return FExists("NOBANNERS",9)
}

bool EXITFLAG
sub GetLISTNAME_FromUser() {
GOGET:
    EXITFLAG = false
    Fade2Color($000F)
    txt.cp437()
    txt.color2(1,6)
    txt.clear_screen()
    MyPlot(2,2)
    txt.print ("\x9C*\x9A*\x99* \x05X16 Vidkit Video List Player \x9E*\x81*\x1C*")
    MyPlot(3,2)
    spc(3) txt.print(PENV.ISOASC_VERSTR)

    MyPlot(9,1)
    txt.print("\x0D\x0D    \x99[\x05LIST\x99] \x9Bfor a LST Listing \x1E(\x9E*.LST\x1E)\x0D")
    txt.print("  \x99  [\x05EXIT\x99] \x9Bto end program\x0D")
    txt.print("  \x99[\x05FOLDER\x99] \x9Bload all Media files \x96(\x05.\x99SPV,\x05.\x99WAV \x1E& \x05.\x99ZCM\x96)\x05 as a Play List\x0D")
    txt.print("  \x96 (\x9BMedia in current folder\x96)")


    MyPlot(8,1)
    txt.print(" \x96(\x9BInclude file extension\x96)")
    MyPlot(7,1)
    txt.print(" \x05Enter full Playlist Filename\x1E:\x9E ")
    FadeToDEFPAL()
    BASENAME[0]=0
    txt.input_chars(&BASENAME)
    ISOUpper(BASENAME)
    if strings.compare(BASENAME,"LIST")==0 {
       ShowDirectory_LIST()
       goto GOGET
    }
    if strings.compare(BASENAME,"EXIT")==0 { EXITFLAG=true }
}


sub SET_BANKS(ubyte StartBank) {
    VID_BANK1 = StartBank
    VID_BANK2 = VID_BANK1 + 1
    VID_BANK3 = VID_BANK2 + 1
}

sub UNCOMPRESS_VIDKIT() {
    if ShowBanners { txt.print("\x0D\x99 DECOMPRESSING VIDKIT\x96... \x0D\x0D") }
    cx16.VERA_ADDR_L = 0
    cx16.VERA_ADDR_M = 0
    cx16.VERA_ADDR_H = %00010000
    cx16.memory_decompress(&VKIT, $9F23)
    cx16.VERA_ADDR_L = 0
    cx16.VERA_ADDR_M = 0
    cx16.VERA_ADDR_H = %00010000
    ubyte Target = VID_BANK1
    repeat 3 {
      uword Ptr = $A000
      cx16.rambank(Target)
      repeat 1024 { unroll 8 { @(Ptr) = cx16.VERA_DATA0 Ptr++ } }
      Target++
    }
    VIDKIT_INIT()
}


; This section of code is not ALL THE VIDKIT API
; just what I needed for this player of it !
; There is more to the API available.
; extsub @bank VID_BANK1 $A000 = VIDKIT_INIT()
; extsub @bank VID_BANK1 $A003 = LOAD_PLAY()
; extsub @bank VID_BANK1 $A006 = LOAD_MEDIA()
; extsub @bank VID_BANK1 $A009 = PLAY_MEDIA()
; extsub @bank VID_BANK1 $A00C = SET_START_FRAME()
; extsub @bank VID_BANK1 $A01E = CLOSE_MEDIA()
; extsub @bank VID_BANK2 $A024 = HIDE_SPRITES()
; extsub @bank VID_BANK2 $A02A = SetDefaultPalette()
; extsub @bank VID_BANK2 $A039 = Fade2Black()
; extsub @bank VID_BANK2 $A03C = pal2black()
; extsub @bank VID_BANK2 $AA15 = RESTORE_SCREEN()
; extsub @bank VID_BANK3 $B412 = FadePal(uword ThePal @R11)
; extsub @bank VID_BANK3 $B415 = FadeToDEFPAL()
; extsub @bank VID_BANK3 $B418 = Fade2Color(uword PalEntry @R1)
; FadeInPal $B412

uword PlayCounter
uword Looped_Counter
bool HAS_LOOPED

sub CLR_COUNTERS() {
    PlayCounter = 0
    Looped_Counter = 0
    HAS_LOOPED = false
}

bool UseBookMark
sub GO_PLAY_IT() {
    ; PokeBASENAME()
    LOAD_MEDIA()
    if VIDKIT.IS_SPI_VIDEO and PENV.IS_HOST {
       SPI_WARNING()
       goto endPlayIT
    }

    if UseBookMark { SeekMediaPosition() UseBookMark=false }
    VIDKIT.KEEP_OPEN = true
    VIDKIT.DISABLE_RESTORE = true
getchoice:
    if VIDKIT.IS_SUPPORTED_VIDEO or VIDKIT.IS_PCM_ONLY {
            if VIDKIT.IS_SPI_VIDEO and (ROM.VERSION==49) and ROM.IsPreRelease and TEXTLIST.CURRENT_LINE==1 { SPI_WARN() }
            if IS_VIDEO {
               if (not HAS_LOOPED) and PlayCounter==0 { Fade2Color($000F) Fade2Black() }
            }
             else {
               if IS_PCM_ONLY { SETUP_PLAY_PCMSTREAM() goto PlayMedia }
             }
PlayTheVideo:
       if VideoHeader.BPP < 8
         { @($9F2C)=$10 }
       else
         { @($9F2C)=0 }
PlayMedia:
       PlayCounter++
       PLAY_MEDIA()

       if MANEXIT==$FF {
          WriteBookMark()
          Fade2Color($000F)
          ; Place Holder for call to BookMarking code
       }

endPlayIT:
      Fade2Black()
      HIDE_SPRITES()
      CLOSE_MEDIA()
      verafx.clear(0,0,0,27648)
      VIDKIT.DISABLE_RESTORE = false
      VIDKIT.PAL_RESET = false
}
}

sub PrintOutControls() {
      txt.print("  \x05 [\x99F5\x05] \x9E- \x9B ACTIVATES LOOPED PLAYBACK\x05.\x0D")
      txt.print("  \x05[\x99SPC\x05] \x9E- \x9B PAUSE/UNPAUSE VIDEO PLAYBACK\x05.\x0D")
      txt.print("  \x05[\x99TAB\x05] \x9E- \x9B NEXT VIDEO IN LIST\x05.\x0D")
      txt.print("  \x05[\x99ESC\x05] \x9E- \x9B EXITS PLAYBACK\x05.\x0D")
}

sub NoMediaFiles() {
    Fade2Black()
    hideGraphicsLayer()
    showTextLayer()
    Fade2Color($000F)
    cx16.set_screen_mode(1)
    txt.nl()  txt.print("\x07 \x05No Media Files were found in \x99") txt.print(BASENAME) txt.nl()
    sys.wait(130)
}

sub PlayerStartMessage() {
       Fade2Color($000F)
       txt.clear_screen()
       txt.nl() PrintOutControls()
       txt.print("  \x05 [\x99\x80\x18\x80\x19\x05] \x9E- \x9B AUDIO VOLUME\x05.\x0D")
       FadeToDEFPAL()
       sys.wait(160)
}

sub start() {
bool Saved_A_BOOKMARK
    CLR_COUNTERS()
    cx16.set_screen_mode(1)
    PENV.GetRunEnvironment()
    ShowBanners = not NoBannerDelay()
    SET_BANKS(2)
    UNCOMPRESS_VIDKIT()
    Fade2Black()
    if Volume==0 or Volume>15 { Volume = 12 }
    if ShowBanners {
       ProgramBanner()
       repeat 3 { txt.nl() }
       PrintOutControls()
       Fade2Color($000F)
       FadeToDEFPAL()
       sys.wait(90)
    }
getfilename:
    void diskio.fastmode(3)
    GetLISTNAME_FromUser()
    if EXITFLAG { goto LIST_IS_DONE }

    if strings.compare(BASENAME,"FOLDER")==0 { void TEXTLIST.FOLDER_LIST(VID_BANK3+1) goto startlist }

    TEXTLIST.LoadFile(BASENAME,VID_BANK3+1)
startlist:
    if TEXTLIST.IsLoaded {
       MyPlot(14,0)
       UseBookMark = CheckBookMark()
       VIDKIT.LOOP_FLAG = false
       SET_KEYEXTRA(9)
       if not UseBookMark { PlayerStartMessage() }
bool GotAFile
startPlayList:
       do {
           if UseBookMark
             { GotAFile=SeekBookMark() sys.wait(110) PlayerStartMessage() }
            else
             { GotAFile = verifyMedia(TEXTLIST.NextFileName()) }
           if GotAFile{ GO_PLAY_IT() if MANEXIT==$FF { goto LIST_IS_DONE } }
       } until TEXTLIST.THE_END

       if PlayCounter==0 {
          NoMediaFiles()
          goto LIST_IS_DONE
       }

       if VIDKIT.LOOP_FLAG {
          TEXTLIST.REWIND()
          PlayCounter=0
          HAS_LOOPED = true
          Looped_Counter++
          goto startPlayList
       }
    } else {
       txt.clear_screen()
       txt.nl()
       txt.print("\x07 \x9BError Loading\x99: \x05") txt.print(BASENAME) txt.nl()
       sys.wait(300)
       goto getfilename
      }



LIST_IS_DONE:
   Fade2Black()
   Fade2Color($000F)
   if MANEXIT != $FF { ScratchBookMark() }
   showTextLayer()
   hideGraphicsLayer()
   cx16.set_screen_mode(1)
   txt.iso_off()
   txt.uppercase()
   txt.color2(1,6)
   txt.cls()

   ProgramBanner()

   MyPlot(12,1)
   txt.color2(13,6)
   if not EXITFLAG {
      txt.print("\x0D ")  txt.print(BASENAME)
      txt.color(7)
   }

   txt.print(" DONE \x05!\x0D")
   if Saved_A_BOOKMARK {
      txt.print("\x0D\x05 BOOKMARK SAVED\x9B\x0D FILENAME\x1E: \x99") txt.print(BOOKNAME) txt.print("\x0D\x0D")
      txt.nl()
   }
   Fade2Color($000F)
   FadeToDEFPAL()

   if strings.compare(BASENAME,"FOLDER")==0 and TEXTLIST.FOLDERLIST_IS_SAVED {
      if Ask(15,1,"\x05 OPEN TEMPFOLDER.LST WITH THE EDITOR\x96:") {
         OB = @(1)
         ubyte b = cx16.search_x16edit()
         cx16.rombank(b)
         cx16.x16edit_loadfile(2, PENV.HIGH_BANK, TEXTLIST.LST_NAME, strings.length(TEXTLIST.LST_NAME))
         cx16.rombank(OB)
         Fade2Color($000F)
         txt.color2(1,6)
         txt.clear_screen()
         if ShowBanners { ProgramBanner() }
         txt.nl()
         FadeToDEFPAL()
      }
   }

  txt.color2(1,6)
  showTextLayer()
  SetDefaultPalette()

}
}
