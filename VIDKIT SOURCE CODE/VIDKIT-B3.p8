%address $B400
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
        VIDKIT.VIDSEEK_SPI,
        VIDKIT.SET_TARGETFRAME,
        VIDKIT.SET_USER_STARTFRAME,
        VIDKIT.VIDSEEK_FRAME,
        VIDKIT.PLAY_TO_TIMER,
        VIDKIT.FadeToPal,
        VIDKIT.FadeInDefPal,
        VIDKIT.FadeInColor,
        VIDKIT.Swap_ORGISR,
        VIDKIT.Swap_NEWISR
      )

;VIDSEEK_SPI ; $B403
;SET_TARGETFRAME ; $B406
;SET_USER_STARTFRAME; $B409
;VIDSEEK_FRAME; $B40C
;PLAY_TO_TIMER; $B40F
; FadeInPal $B412
; FadeInDefPal $B415
; FadeInColor $B418
; ORGISR $B41B
; NEWISR $B41E

sub start() {
    VIDKIT.RV = peek($20)  ; Passed from VIDKIT-B1
    VIDKIT.SetPalette_POINTER()
    VIDKIT.ORG_ISR = VIDKIT.CINV
    VIDKIT.SPI_ENGINE_BANK = @(0)
    VIDKIT.MYBANK = VIDKIT.SPI_ENGINE_BANK
    VIDKIT.STD_ENGINE_BANK = VIDKIT.SPI_ENGINE_BANK - 1
    VIDKIT.PARENT_BANK = VIDKIT.STD_ENGINE_BANK - 1
}

}

VIDKIT {
ubyte STD_ENGINE_BANK
ubyte SPI_ENGINE_BANK
ubyte PARENT_BANK
ubyte HIRAMBANK

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

extsub $AA03 = stB_PrepareSTDVideoPlay()
extsub $AA06 = stB_RESTORELINES()
extsub $AA09 = stB_SetVideoAttributeSTD()
extsub $AA0C = stB_setup_SpriteGrid(word X @R7, word Y @R9) clobbers(A,X,Y)
extsub $AA0F = stB_SETUP_PCMPLAY()
extsub $AA12 = stB_CLONENAMES()
extsub $AA15 = stB_RESTORE_SCREEN()
extsub $AA18 = stb_FADE2BLACK()

; END STANDARD ENGINE ROUTINES

; SPI ENGINE ROUTINES
extsub $A000 = spB_PlayVideo_SPI() clobbers(A,X,Y)
extsub $A00F = spB_SETVIDREAD_BITMAP() clobbers(A,X,Y)
extsub $A012 = spB_SETVIDREAD_BITMAP_LOW() clobbers(A,X,Y)
extsub $A015 = spB_SETAUDIOREAD_SPI() clobbers(A,X)
extsub $A018 = spB_SET_FRAME_38K() clobbers(A)
extsub $A01B = spB_SET_FRAME_51K() clobbers(A)
extsub $A01E = spB_SET_FRAME_62K() clobbers(A)
extsub $A021 = spB_RESETPCM() clobbers(A,X)
extsub $A02A = spB_SETCONTROL1(uword addr @R7)
; END SPI ENGINE ROUTINES

extsub $0400 = Trampoline()

alias NumFramesHI = cx16.r1
alias NumFramesLO = cx16.r2

ubyte i
ubyte RV

sub SetPalette_POINTER() {
    if RV==48
     { PalBank=0 DefPAL_PTR=$FC00 }
    else
     { PalBank, DefPAL_PTR = cx16.get_default_palette() }
}

asmsub FadeInDefPal() {
  %asm {{
    sec
    jsr p8s_FadeInPal
    clc
    rts
  }}
}

asmsub FadeToPal() {
%asm {{
    clc
    jmp p8s_FadeInPal
  }}
}

uword SwapISR = $FFFF
sub Swap_ORGISR() {
      if CINV != ORG_ISR {
         %asm {{ sei }}
         if SwapISR != CINV { SwapISR = CINV }
         CINV = ORG_ISR
         %asm {{ cli }}
      }
}

sub Swap_NEWISR() {
    if SwapISR != $FFFF {
     if CINV != SwapISR {
        %asm {{ sei }}
         CINV = SwapISR
        %asm {{ cli }}
      }
    }
}

asmsub FadeInColor(uword PalEntry @R1) {
 %asm {{
  stz cx16.r0
  stz cx16.r11
  lda #$BE
  sta cx16.r0+1
  sta cx16.r11+1
  ldx #0
stowPal_LOOP:
  lda cx16.r1
  sta (cx16.r0)
  inc cx16.r0
  bne NoWordINC
  inc cx16.r0+1
NoWordINC:
  lda cx16.r1+1
  sta (cx16.r0)
  inc cx16.r0
  bne NoWordINC2
  inc cx16.r0+1
NoWordINC2:
  dex
  bne stowPal_LOOP
 clc
 jmp p8s_FadeInPal
 }}}

asmsub GrayPal() {
 %asm {{
  stz cx16.r0
  stz cx16.r11
  lda #$BE
  sta cx16.r0+1
  sta cx16.r11+1
  lda 1
  pha
  lda p8v_PalBank
  sta 1
  lda p8v_DefPAL_PTR + 1
  sta cx16.r4+1
  lda p8v_DefPAL_PTR
  clc
  adc #32
  sta cx16.r4
  bcc noPInc
  inc cx16.r4+1
noPInc:
  ldx #16
stGrayRow:
  lda cx16.r4
  sta cx16.r3
  lda cx16.r4+1
  sta cx16.r3+1

  sta (cx16.r0)
  inc cx16.r0
  bne NoWordINC
  inc cx16.r0+1
NoWordINC:


  sta (cx16.r0)
  inc cx16.r0
  bne NoWordINC2
  inc cx16.r0+1
NoWordINC2:
  dex
  bne stowPal_LOOP
 clc
 jmp p8s_FadeInPal
 }}}



uword SavePtr
uword WorkPtr=$04

sub FadeInPal() {
 &ubyte G_OUT = $08
 &ubyte B_IN  = $09
 &ubyte B_OUT = $0A
 &ubyte R_IN = $0B
 &ubyte R_OUT = $0C
 &ubyte GB_IN = $0D
 &ubyte GB_OUT = $0E
 &ubyte G_IN = $0F

 %asm {{
   lda 1
   pha
   bcc LOAD_PALETTE_POINTER
   lda p8v_PalBank
   sta 1
   lda p8v_DefPAL_PTR
   sta p8v_SavePtr
   lda p8v_DefPAL_PTR+1
   sta p8v_SavePtr+1
   bra DONEPTRS
LOAD_PALETTE_POINTER
   lda cx16.r11
   sta p8v_SavePtr
   lda cx16.r11+1
   sta p8v_SavePtr+1
   nop
DONEPTRS:
   nop
 }}

 repeat 15 {
   WorkPtr = SavePtr
   cx16.VERA_ADDR_L = 0
   cx16.VERA_ADDR_M = $FA
   cx16.VERA_ADDR_H = %00010001
   %asm {{ wai }}
   repeat 256 {
     %asm {{
       lda $9F20
       pha
       lda $9F21
       pha
     }}
      GB_IN = cx16.VERA_DATA0
       R_IN = cx16.VERA_DATA0
      GB_OUT = @(WorkPtr)
      WorkPtr++
       R_OUT = @(WorkPtr)
      WorkPtr++
      B_IN = (GB_IN & $0F)
      G_IN = (GB_IN  & $F0) >> 4
      R_IN = (R_IN & $0F)
      B_OUT = (GB_OUT & $0F)
      G_OUT = (GB_OUT  & $F0) >> 4
      R_OUT = (R_OUT & $0F)
      if B_IN != B_OUT {
         if B_IN > B_OUT {
            B_OUT = B_IN - 1
         } else { B_OUT = B_IN + 1 }
      }
      if G_IN != G_OUT {
         if G_IN > G_OUT {
            G_OUT = G_IN - 1
         } else { G_OUT = G_IN + 1 }
      }
      if R_IN != R_OUT {
         if R_IN > R_OUT {
            R_OUT = R_IN - 1
         } else { R_OUT = R_IN + 1 }
      }
      GB_OUT = (G_OUT << 4) | B_OUT
     %asm {{
       pla
       sta $9F21
       pla
       sta $9F20
     }}
     cx16.VERA_DATA0 = GB_OUT
     cx16.VERA_DATA0 =  R_OUT
   }
 }
 %asm {{
       pla
       sta 1
     }}
}


long TimerTarget

sub CheckTimerS() {
    if cbm.RDTIML() > TimerTarget { PlayDone = $FF }
    ; rom kbdbuf_peek
    %asm {{ jmp $FEBD }}
}


sub PLAY_TO_TIMER() {
&long tpassed = $0A
    TimerTarget = tpassed
    spB_SETCONTROL1(&CheckTimerS)
    cbm.SETTIML(0)
    spB_PlayVideo_SPI()
    spB_SETCONTROL1($FEBD)
}


sub FLOAT_TO_INT32(float src, ubyte[] target) {
    tmpw = src/65536.0 as uword
    target[3] = msb(tmpw)
    target[2] = lsb(tmpw)
    tmpw2 = (src - (tmpw as float * 65536.0)) as uword
    target[1] = msb(tmpw2)
    target[0] = lsb(tmpw2)
}

sub VIDSEEK_SPI() {
     tmpf = Video_START_SECTOR + (vk_FAC * VID_SECTOR_ADDER as float)
     tmpf2 = Audio_START_SECTOR + (vk_FAC * AUD_SECTOR_ADDER as float)
     FLOAT_TO_INT32(tmpf, VID_SECTOR_CURRENT)
     FLOAT_TO_INT32(tmpf2 , AUD_SECTOR_CURRENT)
}

sub SET_TARGETFRAME() {
uword TPtr = &cx16.r3 ; R3 register
    for i in 0 to 2 {
        FRAME_TARGET[i] = @(TPtr)
        TPtr++
     }
}

sub VIDSEEK_FRAME() {
    DO_BUFFER_AUDIO = false
    if IS_SPI_VIDEO {
       if VideoHeader.BPP < 8 {
          if floats.floor(vk_FAC / 2) != (vk_FAC / 2)  {vk_FAC = vk_FAC - 1}
       }
       VIDSEEK_SPI()
    } else {
      f_seek(VideoLFN,(vk_FAC * VFRAME_MUL) + VIDEOFILE_LEAD)
      if VideoHeader.VTYPE < 5 {
         audFilePosition = (vk_FAC-2) * AUDIOFRAME_MUL
         AdjustAudioPosition()
         f_seek(AudioLFN, audFilePosition)
         DO_BUFFER_AUDIO = true
      }
    }
   Frame = vk_FAC
   CURFRAMEFLOAT_TOINT()
}

sub SET_USER_STARTFRAME() {
    vk_FAC = Peek24BitFloat(&cx16.r0)
    VIDSEEK_FRAME()
}

}
