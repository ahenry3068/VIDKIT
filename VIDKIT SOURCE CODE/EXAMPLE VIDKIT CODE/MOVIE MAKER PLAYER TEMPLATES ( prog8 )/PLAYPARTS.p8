%encoding iso
%option no_sysinit
%import textio
%import conv
%import diskio
%import strings
%import sprites
%import floats
%import verafx
%import VIDKIT_COMMON
%zeropage basicsafe
%zpreserved $22, $60


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
     }
}


main  {
      &ubyte[32] vHeader = $500
 &ubyte[3] vHdrNUMFRAMES = $50D
           &ubyte Volume = $520

       &ubyte[8] zHeader = $522
      &ubyte[44] wHeader = $522
   &ubyte[44] AUD_Header = $522

&bool DO_LOOP_VIDEO = $550

&ubyte AUDIO_CTRL = $9F3B
const uword joystick_get = $FF56

VKIT:
%asmbinary "VIDKIT.Z"
VKIT_END:

uword CURRENT_PART
uword NUMBER_OF_PARTS
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
extsub @bank VID_BANK1 $A03F = SET_KEYEXTRA(ubyte tKey @A)

extsub @bank VID_BANK2 $A024 = HIDE_SPRITES()
extsub @bank VID_BANK2 $A02A = SetDefaultPalette()
extsub @bank VID_BANK2 $A039 = Fade2Black()
extsub @bank VID_BANK2 $A03C = pal2black()
extsub @bank VID_BANK2 $AA15 = RESTORE_SCREEN()
extsub @bank VID_BANK3 $B412 = FadePal(uword ThePal @R11)
extsub @bank VID_BANK3 $B415 = FadeToDEFPAL()
extsub @bank VID_BANK3 $B418 = Fade2Color(uword PalEntry @R1)
; FadeInPal $B412

bool SPI_HOST_FLAG = false

&ubyte STASHVEC = $03B2
&ubyte AUDIO_FIFO = $9F3D
&byte AUDIO_FIFOs = $9F3D
&ubyte VERA_AUDIORATE = $9F3C


str BASENAME = "**CHANGEMEHERE**\x00"+"?"*96
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

bool UseBookMark = false
bool ShowBanners = true
ubyte OB

ubyte VID_BANK1
ubyte VID_BANK2
ubyte VID_BANK3

alias NumFramesHI = cx16.r1
alias NumFramesLO = cx16.r2

uword PMRK

sub MakeStandAlonePlayer() {
    float Seeker = $A4 as float
    strings.copy("PLAYPARTS.PRG",TMPFILE)
    strings.copy(BASENAME,AUDFILE)
    strings.append(AUDFILE,".PRG")
    if FExists(AUDFILE,strings.length(AUDFILE)) { return }

    if FExists(TMPFILE,strings.length(TMPFILE)) {
       txt.clear_screen()
       MyPlot(2,1)
       txt.print("\x05 CREATING \x99DEDICATED\x1E, \x05PARTS PLAYER \x1C--\x96> \x9E") txt.print(AUDFILE )
       strings.copy("@:", AUDFILE)
       strings.append(AUDFILE,BASENAME)
       strings.append(AUDFILE,".PRG,S,W")
       strings.append(TMPFILE,",S,R")
       fopen(7,drivenumber,7,TMPFILE)
       fopen(6,drivenumber,6,AUDFILE)
       cx16.rambank(1)
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
       while BASENAME[i] != 0 { cbm.CHROUT(BASENAME[i])  i+=1 }
       cbm.CHROUT(0)
       cbm.CLRCHN()
       cbm.CLOSE(6)
       txt.print("\x0D..\x99 Done \x05!")
       sys.wait(30)
     } else { %asm {{ nop }} }
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

bool tmpB2
sub check_A_Ext(str extension, str TARGET) -> bool {
    strings.copy(BASENAME,TARGET)
    strings.append(TARGET,extension)
    tmpB2 = FExists(TARGET, strings.length(TARGET))
    if tmpB2 { strings.copy(extension, FOUND_EXT) } else { FOUND_EXT[0] = 0 }
    return tmpB2
}


sub directory() -> bool {
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
            bool IsPART
            if i>12 { strings.slice(AUDFILE,i-12,6,PRGFILE) } else { IsPART=false goto skipPartCMP }
            IsPART = (strings.compare(PRGFILE,"-PART-")==0)
skipPartCMP:
            if strings.compare(&AUDFILE + (i-3) as uword,"SPV") == 0 or IsPART {
               txt.print(" \x9B") txt.print_uw(mkword(high, low)) txt.column(10)
               if IsPART {
                  txt.print("\x99")
               } else { txt.print("\x81") }
               txt.print(AUDFILE) LineCount++ txt.nl()
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
        if status!=0 and status & $40 == 0 {            ; bit 6=end of file
            txt.print("\ni/o error, status: ")
            txt.print_ub(status)
            txt.nl()
            return false
        }
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
    if (WarnCount > 1) or VIDKIT.LOOP_FLAG { return }
    WarnCount++
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
    txt.print ("\x9C*\x9A*\x99* \x05X16 VIDKIT MULTI-PART VIDEO PLAYER ") txt.print(PENV.PETSCII_VERSTR) txt.print(" \x9E*\x81*\x1C*\x05")
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


sub CheckBookMark() -> bool {
    if c != 27 { c = cbm.GETIN2() }
    strings.copy(BASENAME, TMPFILE)
    strings.append(TMPFILE,".PMARK")

    txt.print("\x0D\x0D CHECKING FOR: ") txt.print(TMPFILE) txt.nl()

    if FExists(TMPFILE,strings.length(TMPFILE)) {

       txt.print("\x0D \x05BOOKMARK FILE\x1E: \x96") txt.print(TMPFILE) txt.print("\x05 FOUND \x99!\x05\x0D")

       fopen(7,drivenumber,7,TMPFILE)
       %asm {{
               ldx #7
               jsr cbm.CHKIN
               clc
               ldx #<p8v_BFrame
               ldy #>p8v_BFrame
               lda #5
               jsr cx16.MACPTR
               ldx #<p8v_PMRK
               ldy #>p8v_PMRK
               lda #2
               clc
               jsr cx16.MACPTR
            }}
       cbm.CLOSE(7)
       cbm.CLRCHN()

       if BFrame < 8.0 { BFrame = 8.0 }

      if (PMRK>0) and (PMRK <= NUMBER_OF_PARTS) {
              txt.print("\x0D\x05  PART#\x1E:\x9E ") txt.print_uw(PMRK)
          txt.print("\x0D\x05 FRAME#\x1E:\x9E ") floats.print(BFrame) txt.print("\x0D\x05")
          if c != 27 { c = cbm.GETIN2() }
          if c != 27 { sys.wait(45) }
          c = 0
          return true
         }
       else { c=0 return false }
   }
  else
   { txt.print(" \x0D\x0D\x05NO BOOKMARK !\x0D\x0D") sys.wait(90) c=0 return false }
}


bool CAN_PLAY

sub CleanUpMarkFile() {
    strings.copy(BASENAME,AUDFILE)
    strings.append(AUDFILE,".PMARK")
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


sub MakePartName(uword PNum)  {
    strings.copy("-PART-",PartName)
    if PNum < 10 { strings.append(PartName,"0") }
    strings.append(PartName,conv.str_uw(PNum))
}

sub PokeBASENAME() {
    OB = peek(0)
    cx16.rambank(0)
    strings.copy(BASENAME, $BF00)
    MakePartName(CURRENT_PART)
    strings.append($BF00,PartName)
    cx16.rambank(OB)
}

bool VID_FILE_FOUND
sub DO_FILENAME_PROCESSING(uword PARTN, bool PrintFound) {
    strings.copy(BASENAME, VIDFILE)
    MakePartName(PARTN)
    strings.append(VIDFILE,PartName)
    strings.append(VIDFILE,VEXT)
    ; strings.copy(BASENAME, PRGFILE)
    ; strings.append(PRGFILE,PEXT)
    VID_FILE_FOUND = FExists(VIDFILE,strings.length(VIDFILE))
    if VID_FILE_FOUND and PrintFound {
       if c !=27 { c = cbm.GETIN2() }
       txt.print("FOUND: ") txt.print(VIDFILE) txt.nl()
    }
}

ubyte c
ubyte i
sub COUNT_PARTS() {
 uword tmpP
   tmpP = 1
   NUMBER_OF_PARTS = 0
   DO_FILENAME_PROCESSING(tmpP, true)
   if VID_FILE_FOUND {
      NUMBER_OF_PARTS = 1
      while VID_FILE_FOUND {
        if c != 27 {
           c = cbm.GETIN2()
           sys.wait(15)
        }
        DO_FILENAME_PROCESSING(NUMBER_OF_PARTS+1,true)
        if VID_FILE_FOUND { NUMBER_OF_PARTS++ }
      }
   }
}


sub NoBannerDelay() -> bool {
    return FExists("NOBANNERS",9)
}

sub LoadBASENAME(str FNAME) {
    OB = @(0)
    cx16.rambank(0)
    strings.copy(FNAME, $BF00)
    cx16.rambank(OB)
}

sub GetBASENAME_FromUser() {
GOGET:
    Fade2Color($000F)
    txt.cp437()
    txt.color2(1,6)
    txt.clear_screen()
    MyPlot(2,2)
    txt.print ("\x9C*\x9A*\x99* \x05X16 Vidkit Multi-Part Movie Player \x9E*\x81*\x1C*")
    MyPlot(3,2)
    txt.print(PENV.ISOASC_VERSTR)

    MyPlot(9,1)
    txt.print("\x05 (\x99Without: \x9A\x80\x22\x96-PART-nn\x9A\x80\x22\x05)")
    txt.print("\x0D\x0D  \x99[\x05LIST\x99] \x9Bfor a Media Listing \x1E(\x9E-PART-xx.SPV\x1E)\x0D")
    MyPlot(7,1)
    txt.print(" \x05Enter Movie Name\x1E:\x9E ")
    FadeToDEFPAL()
    BASENAME[0]=0
    txt.input_chars(&BASENAME)
    ISOUpper(BASENAME)
    if strings.compare(BASENAME,"LIST")==0 {
       ShowDirectory_LIST()
       goto GOGET
    }
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
    SET_KEYEXTRA(9)
}


sub PrintOutControls() {
      txt.print("  \x05 [\x99F5\x05] \x9E- \x9B ACTIVATES LOOPED PLAYBACK\x05.\x0D")
      txt.print("  \x05[\x99SPC\x05] \x9E- \x9B PAUSE/UNPAUSE VIDEO PLAYBACK\x05.\x0D")
      txt.print("  \x05[\x99TAB\x05] \x9E- \x9B NEXT VIDEO PART\x05.\x0D")
      txt.print("  \x05[\x99ESC\x05] \x9E- \x9B EXITS PLAYBACK\x05.\x0D")
}

sub start() {
    cx16.set_screen_mode(1)
    PENV.GetRunEnvironment()
    ShowBanners = not NoBannerDelay()
    SET_BANKS(2)
    UNCOMPRESS_VIDKIT()
    Fade2Black()
    NUMBER_OF_PARTS = 0
    if Volume==0 or Volume>15 { Volume = 12 }
    if ShowBanners { ProgramBanner() repeat 3 { txt.nl() } PrintOutControls() }
    void diskio.fastmode(3)
    if strings.compare(BASENAME,"**CHANGEMEHERE**")==0 {
       FadeToDEFPAL()
       txt.print(" \x0D\x05 NO EMBEDDED MOVIE NAME \x99!")
       sys.wait(90)
       GetBASENAME_FromUser()
       txt.clear_screen()
       txt.nl()
       COUNT_PARTS()
       if NUMBER_OF_PARTS > 0 { MakeStandAlonePlayer() txt.nl() txt.nl() }
    }

    if ShowBanners {
       txt.print("\x0D\x05MOVIE\x99: \x05") txt.print(BASENAME)
       txt.nl() txt.nl()
       FadeToDEFPAL()
    }

getfilename:
    void diskio.fastmode(3)
    if (NUMBER_OF_PARTS==0) {
       if not ShowBanners { FadeToDEFPAL() }
       COUNT_PARTS()
    }
    CURRENT_PART = 1
    if NUMBER_OF_PARTS < 1 {
       txt.nl()
       txt.print(BASENAME) txt.print("\x96\x07 MOVIE FILES NOT FOUND \x05!")
       txt.nl()
       SetDefaultPalette()
       goto theend
    }
    UseBookMark = CheckBookMark()
    if UseBookMark { CURRENT_PART = PMRK}

    txt.print("\x0D\x05")
    void diskio.fastmode(3)
    Fade2Color($000F)
    txt.clear_screen()
    txt.cp437()
    txt.nl() PrintOutControls()
    txt.print("  \x05 [\x99\x80\x18\x80\x19\x05] \x9E- \x9B AUDIO VOLUME\x05.\x0D")
    FadeToDEFPAL()
    sys.wait(250)
    Fade2Color($000F)
getPARTName:
    PokeBASENAME()
LoadTheVideo:
    LOAD_MEDIA()
    if UseBookMark {
       FLOAT_TO_INT32(BFrame, &cx16.r0)
       SET_START_FRAME()
    }
    VIDKIT.KEEP_OPEN = true
    VIDKIT.DISABLE_RESTORE = true
getchoice:
      if VIDKIT.IS_SUPPORTED_VIDEO {
            Fade2Black()
            if VIDKIT.IS_SPI_VIDEO and (ROM.VERSION==49) and ROM.IsPreRelease and CURRENT_PART==1 { SPI_WARN() }
            if (CURRENT_PART==1) or UseBookMark {
               if VIDKIT.IS_SPI_VIDEO and PENV.IS_HOST {
                  txt.print("\x0D\x99\x07  SPI DIRECT VIDEOS DETECTED\x0D")
                  txt.print("\x05  HOSTFS \x9BDETECTED.\x0D")
                  txt.print("\x05  SPI DIRECT\x9B VIDS ARE \x05NOT PLAYABLE\x9B ON \x05EMULATOR HOSTFS\x0D")
                  FadeToDEFPAL()
                  goto theend
               }
            }
          }

PlayTheVideo:
    if VideoHeader.BPP < 8
     { @($9F2C)=$10 }
    else
    { @($9F2C)=0 }
    PLAY_MEDIA()
    UseBookMark=false
      if MANEXIT==$FF
        { Fade2Color($000F) }
      else {
             if CURRENT_PART==NUMBER_OF_PARTS {
                Fade2Black()
                if VIDKIT.LOOP_FLAG { CURRENT_PART=0 }
             }
             if CURRENT_PART < NUMBER_OF_PARTS {
                if MANEXIT==9 { Fade2Black() } else { %asm {{ wai }} pal2black() }
                CURRENT_PART++
                if VIDKIT.IS_STD_VIDEO { CLOSE_MEDIA() }
                goto getPARTName
             }
           }
      HIDE_SPRITES()
      CLOSE_MEDIA()
      verafx.clear(0,0,0,27648)
      VIDKIT.DISABLE_RESTORE = false
      VIDKIT.PAL_RESET = false

    bool Saved_A_BOOKMARK = false
    if MANEXIT==$FF {
       Saved_A_BOOKMARK = true
       RESTORE_SCREEN()
       txt.cp437()
       txt.color2(1,6)
       cx16.set_screen_mode(0)
       cx16.VERA_DC_HSCALE = 88
       cx16.VERA_DC_VSCALE = 88
       PMRK = CURRENT_PART
       Frame = VIDKIT.Frame
       MyPlot(2,2)
       txt.print(" \x05SAVING BOOKMARK \x96!")
       unroll 2 { txt.nl() }
       txt.print(" \x05MOVIE PART\x99#\x1E: \x9E") txt.print_uw(CURRENT_PART) txt.nl()
       txt.print("      \x05FRAME\x99#\x1E: \x9E") floats.print(Frame) txt.print("\x0D\x05")
       FadeToDEFPAL()
       strings.copy("@:", TMPFILE)
       strings.append(TMPFILE,BASENAME)
       strings.append(TMPFILE,".PMARK,S,W")
       fopen(9,drivenumber,9,TMPFILE)
       cbm.CHKOUT(9)
       uword NPtr = &Frame
       repeat 5 { cbm.CHROUT(@(NPtr)) NPtr++ }
       NPtr = &CURRENT_PART
       repeat 2 { cbm.CHROUT(@(NPtr)) NPtr++ }
       cbm.CLOSE(9)
       cbm.CLRCHN()
       ; The following is just to shake up the file system and make sure the fat32
       ; write buffer from directly above is flushed to disk !  It was failing to before
       ; and I was getting a 0 length .PMARK file !
       strings.copy(BASENAME, TMPFILE)
       strings.append(TMPFILE,".PMARK")
       fopen(7,drivenumber,7,TMPFILE)
       cbm.CHKIN(7)
       repeat 2 { c = cbm.GETIN2() }
       cbm.CLOSE(7)
       cbm.CLRCHN()
       Fade2Color($000F)
    } else { Fade2Black() RESTORE_SCREEN() CleanUpMarkFile()  }

   CLOSE_MEDIA()

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
   txt.print("\x0D ")  txt.print(BASENAME) txt.color(7)
skipoutputstuff2:
   txt.print(" DONE \x05!\x0D")
   if Saved_A_BOOKMARK {
      txt.print("\x0D\x05 BOOKMARK SAVED\x9B\x0D FILENAME\x1E: \x99") txt.print(BASENAME) txt.print(".PMARK\x0D\x0D")

      txt.print(" \x05MOVIE PART\x99#\x1E: \x9E") txt.print_uw(CURRENT_PART) txt.nl()
      txt.print("      \x05FRAME\x99#\x1E: \x9E") floats.print(Frame) txt.print("\x0D\x05")
      txt.nl()
   }
skiplast:

theend:
 }
}
