%option no_sysinit
%import textio
%import conv
%import diskio
%import strings
%import sprites
%import floats
%import verafx
%encoding iso
%zeropage basicsafe
%zpreserved $22, $60





main  {
      &ubyte[32] vHeader = $500
 &ubyte[3] vHdrNUMFRAMES = $50D
           &ubyte Volume = $520

       &ubyte[8] zHeader = $522
      &ubyte[44] wHeader = $522
   &ubyte[44] AUD_Header = $522

&ubyte AUDIO_CTRL = $9F3B
const uword joystick_get = $FF56





ubyte[85] butterfly = [$8F,$93,$9C,$12,$DF,$92,$20,$20,$20,$20,$20,$12,$A9,$0D,$9A,$12,$A5,$DF,$92,$20,$20,$20,$12,$A9,$A7,
                       $92,$0D,$9F,$12,$B5,$20,$DF,$92,$20,$12,$A9,$20,$B6,$0D,$1E,$20,$B7,$12,$BB,$92,$20,$12,$AC,$92,$B7,
                       $0D,$9E,$20,$AF,$12,$BE,$92,$20,$12,$BC,$92,$AF,$0D,$81,$AA,$12,$20,$92,$A9,$20,$DF,$12,$20,$92,$B4,
                       $0D,$1C,$B6,$A9,$20,$20,$20,$DF,$B5,0]



ubyte i=0
ubyte j=0
uword tmpw
uword tmpw2







sub MyPlot(ubyte y, ubyte x) {
    txt.row(y)
    txt.column(x)
}


sub ProgramBanner() {
    i=0
    repeat 85 { cbm.CHROUT(butterfly[i]) i +=1 }
    MyPlot(1,10)
    txt.print ("\x9C*\x9A*\x9F*\x99* \x05COMMANDER X16 MOVIE MAKER ")  txt.print(" \x1E*\x9E*\x81*\x1C*\x05")
    MyPlot(3,10)
    txt.print ("\x05VERSION:  BETA")
    MyPlot(9,0)
    txt.print("READY.")
    MyPlot(28,0)
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

bool tmpB
bool tmpB2

ubyte printchar
ubyte printlen;
ubyte ppos


sub spc(ubyte L @ R11 ) { repeat L { cbm.CHROUT(32) } }

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
        13 -> { if not (StoredChar==89 or StoredChar==78) { goto skipprint }  }
      else -> { goto skipprint }
    }
    return (StoredChar==89)
}


float ScrTimer
ubyte SAVE_DC_VIDEO




ubyte choice

sub start() {
  ProgramBanner()
}
}
