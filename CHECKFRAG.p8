%encoding iso
%option no_sysinit
%import textio
%import conv
%import diskio
%import strings
%import sprites
%import floats
%import verafx
%zeropage basicsafe
%zpreserved $22, $60



ROM {
      ubyte VERSION
      bool  IsPreRelease
}


PENV {
           str HOST = "?"*5
           str PETSCII_VERSTR="VER 1.0 \x1E(\x9B1ST REV\x1E)"
           str  ISOASC_VERSTR="\x05 VER \x991.0 \x9B(\x051ST rev\x9B)"
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


main  {

str FILENAME= "?"*200

ubyte[4] fsector
ubyte[4] tmpL

bool success
uword tmpw
uword tmpw2
ubyte drivenumber = 8

alias f_size_low = cx16.r2
alias f_size_high = cx16.r3

ubyte[85] butterfly = [$8F,$93,$9C,$12,$DF,$92,$20,$20,$20,$20,$20,$12,$A9,$0D,$9A,$12,$A5,$DF,$92,$20,$20,$20,$12,$A9,$A7,
                       $92,$0D,$9F,$12,$B5,$20,$DF,$92,$20,$12,$A9,$20,$B6,$0D,$1E,$20,$B7,$12,$BB,$92,$20,$12,$AC,$92,$B7,
                       $0D,$9E,$20,$AF,$12,$BE,$92,$20,$12,$BC,$92,$AF,$0D,$81,$AA,$12,$20,$92,$A9,$20,$DF,$12,$20,$92,$B4,
                       $0D,$1C,$B6,$A9,$20,$20,$20,$DF,$B5,0]

&ubyte STASHVEC = $03B2
&ubyte AUDIO_FIFO = $9F3D
&byte AUDIO_FIFOs = $9F3D
&ubyte VERA_AUDIORATE = $9F3C
&ubyte AUDIO_CTRL = $9F3B

ubyte Volume = 12

ubyte i=0
ubyte j=0
ubyte c=0

alias NumFramesHI = cx16.r1
alias NumFramesLO = cx16.r2

float FILE_STARTSECTOR
float CURRENT_SECTOR
float SECTOR_NUMBER
float CALCULATED_SECTOR
float BYTEPOS
float Seeker
float FILE_SIZE
float FILE_NUMBER_OF_SECTORS
uword FILE_TRAILING_BYTES
float[8] CHECK_SECTORS

asmsub float2long(uword FPtr @ AY, uword lptr @ R1) {
   %asm {{

                MOVFM = $fe63
                QINT  = $fe8d
                FAC   = $c3
                FACHO = FAC + 1

float2long:     ldx $01
                phx
                ldx #$04
                stx $01
                jsr MOVFM
                jsr QINT
                ldx #3
                ldy #0
rl:
                lda FACHO,x
                sta (cx16.r1),y
                iny
                dex
                bpl rl
                pla
                sta $01
                rts
         }}
}

asmsub White() {
%asm {{
  lda #05
  jmp cbm.CHROUT
  }}
}

asmsub Red() {
 %asm {{
  lda #$96
  jmp cbm.CHROUT
  }}
}

asmsub Orange() {
 %asm {{
  lda #$81
  jmp cbm.CHROUT
  }}
}


asmsub Green() {
 %asm {{
  lda #$99
  jmp cbm.CHROUT
  }}
}

asmsub Yellow() {
 %asm {{
  lda #$9E
  jmp cbm.CHROUT
  }}
}

sub PrintINT32(ubyte[] i32) {
   for i in 3 to 0 step -1 { txt.print(conv.str_ubhex(i32[i])) }
  }

sub PrintHexF(float F)  {
    FLOAT_TO_INT32(F, tmpL)
    PrintINT32(tmpL)
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

sub GrabBaseName() {
    cx16.r2 = $BF00
    for cx16.r12L in 0 to 94 {
        i = cx16.fetch(cx16.r2L, 0, cx16.r12L)
        if i==0 { break }
        FILENAME[cx16.r12L] = i
      }
    FILENAME[cx16.r12L+1]=0
}


ubyte WarnCount = 0
sub SPI_WARN() {
    if WarnCount > 2 { return }
    WarnCount++
    MyPlot(1,1)
    txt.print(" \x9BYou are running a \x96prerelease \x99r49 \x05ROM.")
    MyPlot(2,1)
    txt.print(" \x96This \x99MAY\x96 work \x1E!\x1F....\x9B[\x05Recommend \x99UPGRADE\x9B]\x05")
    MyPlot(3,2)
}

sub MyPlot(ubyte y, ubyte x) {
    txt.row(y)
    txt.column(x)
}

sub ProgramBanner() {
    i=0
    repeat 85 { cbm.CHROUT(butterfly[i]) i +=1 }
    MyPlot(1,10)
    txt.print ("\x9C*\x9A*\x99* \x05SD-CARD FILE FRAGMENTATION CHECKER ") txt.print(PENV.PETSCII_VERSTR) txt.print(" \x9E*\x81*\x1C*\x05")
    MyPlot(2,14)
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

asmsub SetDefaultPalette() {
 %asm {{
     lda 1
     pha
     stz 1
     jsr GETROM
     cmp #48
     beq r48
     lda #$10
     clc
     jsr $FEAB   ; X16 Rom extapi
     bra dnp
r48: jsr $D00C
dnp:
     pla
     sta 1
     rts
GETROM:
         clc             ; prepare for released ROM
         lda  $FF80
         bpl  finalR     ; pre-release versions are negative
         eor  #$FF       ; twos complement
         ina
         sec
finalR:
         rts
 }}
}

sub pal2black() {
    cx16.VERA_ADDR_L = 0
    cx16.VERA_ADDR_M = $FA
    cx16.VERA_ADDR_H = %00010001
    repeat 128 {
      unroll 4 { cx16.VERA_DATA0 = 0 }
     }
}

sub pal2blue() {
    cx16.VERA_ADDR_L = 0
    cx16.VERA_ADDR_M = $FA
    cx16.VERA_ADDR_H = %00010001
    repeat 128 {
      unroll 2 { cx16.VERA_DATA0=$0F cx16.VERA_DATA0=0 }
     }
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

sub GETSector48() {
    cx16.r0 = $B7E1    ; This is valid for r48 only !!!
    for i in 0 to 3 {
        fsector[i] = cx16.fetch(&cx16.r0,0,i)
    }
 }

sub getSector(ubyte Channel) {
        if ROM.VERSION==48 { GETSector48() return }
        File_FL(Channel)
        fsector[0] = cx16.r0L
        fsector[1] = cx16.r0H
        fsector[2] = cx16.r1L
        fsector[3] = cx16.r1H
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
            cx16.r0 = read4hex()        ; position in R1:R0
            void cbm.CHRIN()            ; separator space
            cx16.r3 = read4hex()
            cx16.r2 = read4hex()        ; filesize in R3:R2
            success = true
        }
        %asm {{ jmp p8s_Flush15 }}
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


sub BAD_ROM_MESSAGE() {
       txt.print("\x07\x0D\x9B   THIS PROGRAM \x05REQUIRES\x9B ROM VERSION \x99R\x0548 \x9BOR \x05 HIGHER\x96 !")
       txt.print("\x0D\x05   VERSION\x1E: \x99") txt.print(conv.str_ub(ROM.VERSION)) txt.print("\x9B WAS FOUND.\x0D")
       if ROM.IsPreRelease { txt.print("\x0D\x05   PRE-RELEASE ROM\x0D") }
}

sub HOSTFS_MESSAGE() {
       txt.nl()
       txt.print("\x05   RUNNING ON EMULATOR \x9BHOST FILE SYSTEM \x96 !\x0D")
       txt.print("\x07\x0D\x99   FRAGMENTATION CHECKER\x9B IS FOR \x05 SD-CARD \x9BFILE SYSTEM \x96ONLY \x1EROM \x99R\x0548 \x05OR HIGHER\x96 !")
       txt.nl()
}


; float FILE_STARTSECTOR
; float CURRENT_SECTOR

; float CALCULATED_SECTOR
; float Seeker
; float FILE_SIZE
; float FILE_NUMBER_OF_SECTORS
; uword FILE_TRAILING_BYTES
; float[8] CHECK_SECTORS

sub VERIFY_CONTIGUOUS_SECTOR(float SECTOR) -> bool {
    Seeker = 512.0 * SECTOR
    CALCULATED_SECTOR = SECTOR + FILE_STARTSECTOR
    f_seek(6,Seeker)
    getSector(6)
    CURRENT_SECTOR = INT32_TO_FLOAT(fsector)
    return (CALCULATED_SECTOR == CURRENT_SECTOR)
}

sub CALC_CHECKSECTORS() {
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

bool IS_FRAGMENTED

sub CHECK_FRAGMENTATION() {
ubyte cn
    MyPlot(3,0)
    for cn in 0 to 7 {
        if cn > 0 {
           if cn % 2 == 0 { MyPlot(3,0) }
        }
        txt.print("\x96 CHECKING")
        txt.nl()
        if VERIFY_CONTIGUOUS_SECTOR(CHECK_SECTORS[cn]) {
           White()
           txt.print("    CALCULATED SECTOR: ") Green() PrintHexF(CALCULATED_SECTOR) txt.nl()
           White()
           txt.print("        ACTUAL SECTOR: ") Green() PrintHexF(CURRENT_SECTOR) txt.nl()
        } else {
            Red()
            txt.print("FRAGMENTATION FOUND !") txt.nl()
            White()
           txt.print("    CALCULATED SECTOR: ") Yellow() PrintHexF(CALCULATED_SECTOR) txt.nl()
           White()
           txt.print("        ACTUAL SECTOR: ") Red() PrintHexF(CURRENT_SECTOR) txt.nl()
           IS_FRAGMENTED = true
           break;
        }
    }
}

sub LOAD_PARAMETERS() {
    IS_FRAGMENTED = false
    fopen(6,8,6,FILENAME)
    getSector(6)
    FILE_STARTSECTOR = INT32_TO_FLOAT(fsector)
    my_f_tell(6)
    FILE_SIZE = INT32_TO_FLOAT(&cx16.r2)
    FILE_NUMBER_OF_SECTORS = floats.floor(FILE_SIZE/512.0)
    FILE_TRAILING_BYTES = (FILE_SIZE - (FILE_NUMBER_OF_SECTORS * 512.0)) as uword
    if FILE_TRAILING_BYTES > 0 { FILE_NUMBER_OF_SECTORS = FILE_NUMBER_OF_SECTORS + 1}
    CURRENT_SECTOR = FILE_STARTSECTOR
}

sub FlushKeyBoard() {
    while cbm.GETIN2() > 0 { %asm {{ nop }} }
}


sub GOT_FILE_TOCHECK() -> bool {
    txt.nl()
    txt.nl()
    txt.print(" ENTER FILENAME TO CHECK \x96--\x99> \x05")
    txt.input_chars(&FILENAME)
    ISOUpper(FILENAME)
    return FExists(FILENAME, strings.length(FILENAME))
}

sub PRINT_FILESTATS() {
       White()
       txt.nl()
       txt.print ("      LBA START ADDRESS: ") Green() PrintHexF(FILE_STARTSECTOR)
       txt.nl() txt.nl()
       White()
       txt.print ("              FILE SIZE: ") Yellow() floats.print(FILE_SIZE) Red() txt.print(" BYTES.")
       txt.nl() White()
       txt.print ("   FILE SIZE IN SECTORS: ") Yellow() floats.print(FILE_NUMBER_OF_SECTORS) Red() txt.print(" SECTORS.")
       txt.nl()
       White()
       if FILE_TRAILING_BYTES > 0 {
          txt.print (" LAST SECTOR USED BYTES: ") Yellow() txt.print_uw(FILE_TRAILING_BYTES) Red() txt.print(" BYTES.")
          txt.nl()
       }
}

sub start() {
    PENV.GetRunEnvironment()
    if (ROM.VERSION < 48) or ((ROM.VERSION==48) and ROM.IsPreRelease) { BAD_ROM_MESSAGE() goto theend }
    if PENV.IS_HOST { HOSTFS_MESSAGE() goto theend }
    ProgramBanner()
    void diskio.fastmode(3)
    sys.wait(60)
    if GOT_FILE_TOCHECK() {
       txt.nl() txt.nl()
       txt.print(" FOUND: ")
       txt.print(FILENAME)
       txt.nl() txt.nl()
       LOAD_PARAMETERS()
       PRINT_FILESTATS()
       txt.print("\x0D   CALCULATING SECTORS TO CHECK !") txt.nl()
       CALC_CHECKSECTORS()
       txt.print("\x0D\x0D\x05  PRESS ANY KEY TO PERFORM FRAG CHECK \x96 !")
       FlushKeyBoard()
       txt.waitkey()
       txt.clear_screen()
       txt.print(" \x0DCHECKING\x96: ") Yellow() txt.print(FILENAME) txt.nl() txt.nl()
       CHECK_FRAGMENTATION()
       MyPlot(11,1)
       PRINT_FILESTATS()
       txt.nl() txt.nl()
       if IS_FRAGMENTED {
          White() txt.print("   FRAGMENTATION DETECTED \x9B--\x96> ") Yellow() PrintHexF(CURRENT_SECTOR)
        }
       else
        {
         spc(3) Orange() txt.print(FILENAME) txt.print(" \x05IS \x99CONTIGUOUS \x96 !")
        }
    }
theend:
  White()
  txt.nl()
  cbm.CLOSE(6)
 }
}
