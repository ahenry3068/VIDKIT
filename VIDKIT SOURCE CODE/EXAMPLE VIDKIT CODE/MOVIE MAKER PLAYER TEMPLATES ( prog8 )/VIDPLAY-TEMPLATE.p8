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

ROM {
      ubyte VERSION
      bool  IsPreRelease
}


PENV {
           str HOST = "?"*5
           str PETSCII_VERSTR="\x05VERSION \x992\x1E.\x990"
           str  ISOASC_VERSTR="\x05 Version\x992\x1E.\x990"
           str    CPU="\x9B65\x99C\x9B02"
           uword   cpu=6502
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

main {

VKIT:
%asmbinary "VIDKIT.Z"
VKIT_END:

titlescreen:
%asmbinary "x16vid.Z"

reelsprites:
%asmbinary "REEL.SPRS.Z"

ubyte VID_BANK1
ubyte VID_BANK2
ubyte VID_BANK3
ubyte OB
uword tmpw
uword tmpw2
ubyte drivenumber = 8
str BASENAME = "**CHANGEME**" + "?"*110
str TMPFILE = "?"*128
str VIDFILE = "?"*120
str VEXT = iso:".SPV"
str AEXT = iso:".SVA"
bool UseBookMark

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

sub SPLASH_SCREEN() {
    Fade2Black()
    cx16.set_screen_mode($80)
    txt.cp437()
    txt.color2(15,0)
    txt.clear_screen()
    verafx.clear(0,0,0,19200)
    cx16.VERA_ADDR_L = $80
    cx16.VERA_ADDR_M = $16
    cx16.VERA_ADDR_H = %00010000
    cx16.memory_decompress(&titlescreen, &cx16.VERA_DATA0)
    Load_FilmReel_Image($2C00, 1,52,100)
    ShowInfo()
    FadeToDEFPAL()
    sys.wait(200)
    Fade2Black()
    HIDE_SPRITES()
    verafx.clear(0,0,0,19200)
}


ubyte i
sub ProgramBanner() {
    i=0
    repeat 85 { cbm.CHROUT(butterfly[i]) i +=1 }
    txt.row(1)
    txt.column(10)
    txt.print ("\x9C*\x9A*\x99* \x05X16 VIDKIT MINI MOVIE PLAYER ") txt.print(PENV.PETSCII_VERSTR) txt.print(" \x9E*\x81*\x1C*\x05")
    txt.row(2)
    txt.column(14)
    if PENV.ON_EMU { txt.print("EMULATOR") } else { txt.print("HARDWARE") }
    txt.row(3)
    txt.column(10)
    txt.print ("\x9BAUTHOR\x1E: \x05ANTHONY W. HENRY")
    txt.row(5)
    txt.column(10)
    txt.print("\x9ETHIS SOFTWARE IS UNDER THE MIT LICENSE")
    txt.row(6)
    txt.column(10)
    txt.print("    \x05(\x9BPERMISSIVE\x05)")
}

sub ISOUpper(str s) {
  i=0
  while s[i] != 0 {
      if s[i] > 96 and s[i]<123 { s[i] -= 32 }
      i+=1
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
             jmp cbm.CLRCHN
dummy        .byte 0
; !notreached!
          }}
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

sub NoBannerDelay() -> bool {
    return FExists("NOBANNERS",9)
}

sub LoadBASENAME(str FNAME) {
    OB = @(0)
    cx16.rambank(0)
    strings.copy(FNAME, $BF00)
    cx16.rambank(OB)
}

sub SET_BANKS(ubyte StartBank) {
    VID_BANK1 = StartBank
    VID_BANK2 = VID_BANK1 + 1
    VID_BANK3 = VID_BANK2 + 1
}

sub UNCOMPRESS_VIDKIT() {
    txt.print("\x0D\x99 DECOMPRESSING VIDKIT\x96... \x0D\x0D")
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
      repeat 8192 { @(Ptr) = cx16.VERA_DATA0 Ptr++ }
      Target++
    }
    VIDKIT_INIT()
}

; alternate code to load VIDKIT from disk file
; rather than embedding !
sub Load_VIDKIT() {
    cx16.rambank(VID_BANK1)
    void diskio.loadlib("VIDKIT-A000.BIN", $A000)
    VIDKIT_INIT()
}

sub CleanUpMarkFile() {
    strings.copy(BASENAME,TMPFILE)
    strings.append(TMPFILE,".MARK")
    if FExists(TMPFILE,strings.length(TMPFILE)) { diskio.delete(TMPFILE) }
 }

float Frame
bool DidBookMark
bool ShowBanners
sub CheckBookMarking() {
    DidBookMark = false

    if VIDKIT.MANEXIT==$FF {
       Frame = VIDKIT.Frame
       if ShowBanners {
         txt.cp437()
         txt.color2(1,6)
         txt.clear_screen()
         txt.nl()
         txt.print(" \x05Saving\x1E: \x9E") txt.print(BASENAME) txt.print("\x1C.\x9EMARK\x0D\x0D")
         txt.print(" \x05Bookmark at Frame \x1E#\x99") floats.print(Frame) txt.print("\x05\x0D")
         FadeToDEFPAL()
       }
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
       DidBookMark = true
       if ShowBanners { Fade2Black() }
    }
     else {
      CleanUpMarkFile()
    }
}


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
       return true
     }
   return false
  }

sub PrintOutControls() {
      txt.print("  \x05 [\x99F5\x05] \x9E- \x9B ACTIVATES LOOPED PLAYBACK\x05.\x0D")
      ; for parts & List Player
      ; txt.print("  \x05[\x99TAB\x05] \x9E- \x9B NEXT VIDEO PART\x05.\x0D")
      txt.print("  \x05[\x99ESC\x05] \x9E- \x9B EXITS PLAYBACK\x05.\x0D")
}

sub ShowInfo() {
      txt.color2(1,0)
      txt.plot (0,1)
      txt.print("\x05 ")
      txt.print(VIDFILE)
      txt.print("\x99 FOUND !\x0D")
      if UseBookMark {
         txt.print(" \x05BOOKMARK AT FRAME \x1E#\x99") floats.print(Frame) txt.print("\x0D\x0D\x05")
      }
      txt.plot(0,27)
      PrintOutControls()
}

sub start() {
    cx16.set_screen_mode(1)
    PENV.GetRunEnvironment()
    ShowBanners = not NoBannerDelay()
    SET_BANKS(2)
    UNCOMPRESS_VIDKIT()
    UseBookMark = CheckBookMark()
    Fade2Black()
    ISOUpper(BASENAME)
    strings.copy(BASENAME, VIDFILE)
    strings.append(VIDFILE,VEXT)
    if FExists(VIDFILE,strings.length(VIDFILE)) {
      if not ShowBanners { goto LoadTheVideo }
    } else {
       txt.print("\x0D\x05MISSING \x1E--\x99> \x05") txt.print(VIDFILE)
       cbm.CHROUT(13)
       goto skipOVER
    }
    if ShowBanners {
       SPLASH_SCREEN()
       cx16.set_screen_mode(1)
       txt.color2(15,0)
       txt.clear_screen()
    }
LoadTheVideo:
    if not ShowBanners { Fade2Black() }
    LoadBASENAME(BASENAME)
    LOAD_MEDIA()
    if VIDKIT.IS_SPI_VIDEO and PENV.IS_HOST {
       txt.print("\x0D\x07")
       txt.print("\x9B  SPI DIRECT VIDEOS CAN NOT BE PLAYED ON \x0D")
       txt.print("\x05  EMULATOR \x99HOSTFS \x9B!!\x0D")
       CLOSE_MEDIA()
       goto skipOVER
    }
    Fade2Black()
    if UseBookMark {
       FLOAT_TO_INT32(Frame, &cx16.r0)
       SET_START_FRAME()
    }
    VIDKIT.KEEP_OPEN = true
    VIDKIT.DISABLE_RESTORE = true
RePlay:
    diskio.fastmode(1)
    PLAY_MEDIA()
    if VIDKIT.LOOP_FLAG and (VIDKIT.MANEXIT==0) { Fade2Black() goto RePlay }
    CLOSE_MEDIA()
    Fade2Black()
    HIDE_SPRITES()
    VIDKIT.DISABLE_RESTORE = false
    RESTORE_SCREEN()
    CheckBookMarking()
    if ShowBanners {
       Fade2Color($000F)
       txt.color2(1,6)
       txt.clear_screen()
       ProgramBanner()
       txt.print("\x0D\x0D\x0D\x05 ") txt.print(BASENAME) txt.print(" \x99DONE \x96!\x0D\x0D")
       if DidBookMark {
          txt.print(" \x05BOOKMARK AT FRAME \x1E#\x99") floats.print(Frame) txt.print("\x05\x0D")
       }
    }
skipOVER:
    txt.color(1)
    FadeToDEFPAL()
}
}
