.include "../../vidvars.inc"

     .macpack longbranch

     .include "sdcard_spi.inc"

     .macro WaitForAFLOW
     .local waitloop
waitloop: lda VERA_ISR
          and #$08
          beq waitloop
     .endmacro

     .macro Pad3Byte
       nop
       nop
       rts
     .endmacro

.org $A000
jmp startplay                ;SYS $A000   (Starts Video Play)
Pad3Byte                     ;SYS $A003   (NOT NEEDED, IN STD ENGINE)
Pad3Byte                     ;SYS $A006   (NOT NEEDED, IN STD ENGINE)
Pad3Byte                     ;SYS $A009   (NOT NEEDED, IN STD ENGINE)
Pad3Byte                     ;SYS $A00C   (NOT NEEDED, IN STD ENGINE)
jmp SETVIDREAD_BITMAP        ;SYS $A00F
jmp SETVIDREAD_BITMAP_LOW    ;SYS $A012
jmp SETAUDIOREAD_SPI         ;SYS $A015
jmp SET_FRAME_38K            ;SYS $A018
jmp SET_FRAME_51K            ;SYS $A01B
jmp SET_FRAME_62K            ;SYS $A01E
jmp SetupAUDIO               ;SYS $A021   ( Place Holder for Audio Read LFN )
jmp FIX_ISOCURSOR            ;SYS $A024
jmp setControls              ;SYS $A027
jmp setControl1              ;SYS $A02A
jmp setControl2              ;SYS $A02D
jmp SETDEFAULT_CONTROLS      ;SYS $A030
jmp SETBANK_ZSMKIT           ;SYS $A033
jmp ZSMKIT_PAUSEALL          ;SYS $A036
jmp ZSMKIT_UNPAUSE           ;SYS $A039
jmp SETSPRITEREAD_SPI        ;SYS $A03C   (INTERNAL, new: HB sprite layout + loader setup, called by VIDKIT-B1)

startplay:
   lda LOCK_KEYS
   bne KEYS_LOCKED
   lda #$EA
   bra PUTKEYGUARD
KEYS_LOCKED:
   lda #$60
PUTKEYGUARD:
   sta KEYGUARD
   lda VHDR_VRATE
   sta VERA_RATEBYTE
   lda VHDR_XAUD_FLAG
   cmp #$58      ; X for extended Audio.
   bne mono8bit
   lda VHDR_XAUD_XCFG
   and #%00110000
   bra GetVolume
mono8bit:
   lda #0
GetVolume:
   ora Audio_Volume
   sta VERA_CFGBYTE
 lda 1
 pha
 stz 1
   stz PlayDone
   stz MANEXIT
   jsr SetupAUDIO
READAUDIOLEAD:
   lda DO_BUFFER_AUDIO
   beq FIRSTAUDIOFRAME   ; Skip Extra LeadIn if 0 in DO_BUFFER_AUDIO
LEADREADCALL:
   jsr $FFFF

FIRSTAUDIOFRAME:
        jsr $FFFF
        stz page_flag
        lda VERA_RATEBYTE
        sta VERA_AUDIORATE    ; start play after filling the FIFO
LOADFRAME_CALL1:
        jsr $FFFF
        AddByteVal VID_SECTOR_ADDER, VID_SECTOR_CURRENT
        inc24 FRAME_CURRENT


VidPlayLoop:
PLAYCONTROL1:
          jsr kbdbuf_peek
          beq DONECHECKER
PLAYCONTROL2:
          jsr ProcessKeys

DONECHECKER:
          lda PlayDone
          ; cmp #0
          bne over
LOADAUDIOCALL:
          jsr $FFFF

LOADFRAME_CALL2:
          jsr $FFFF
          AddByteVal VID_SECTOR_ADDER, VID_SECTOR_CURRENT
          inc24 FRAME_CURRENT
          cmp24 FRAME_CURRENT, FRAME_TARGET
          bne VidPlayLoop
          jsr setdone
          bra DONECHECKER
over:
         jsr CLRCHN
flushinput:
         jsr GETIN
         bne flushinput
  pla
  sta 1
         rts


ProcessKeys:
  jsr CLRCHN
  jsr GETIN
  cmp #17
  jeq VolumeDown
  cmp #145
  jeq VolumeUp
KEYGUARD:
  nop
  cmp #27
  jeq SetPlayDone
  cmp #135
  beq TURN_LOOP_ON
  cmp #32
  beq dopause
  ldx KEY_EXTRA
  beq skipEXTRAKEY
  cmp KEY_EXTRA
  beq do_EXTRAEXIT
skipEXTRAKEY:
  rts

do_EXTRAEXIT:
  sta MANEXIT
  bra setdone

TURN_LOOP_ON:
  lda #1
  sta LOOP_FLAG
  rts

dopause:
  stz VERA_AUDIORATE
pauseloop:
  jsr GETIN
  cmp #27
  beq SetPlayDone
  cmp #32
  beq endpause
  bra pauseloop
endpause:
  lda VERA_RATEBYTE
  sta VERA_AUDIORATE
  rts

SetPlayDone:
  lda #$FF
  sta MANEXIT
setdone:
  lda #$FF
  sta PlayDone
  rts

SetupAUDIO:
   stz VERA_AUDIORATE
   lda #%10000000
   sta AUDIO_CTRL    ; reset the Audio FIFO
   lda VERA_CFGBYTE
   sta AUDIO_CTRL
rts

ReadAudioLeadinSPI:   ;SPI LeadIn
 ph32 AUD_SECTOR_CURRENT
 cp32 AUD_LEAD_START, AUD_SECTOR_CURRENT
 jsr LoadLeadAudioSPI
 pl32 AUD_SECTOR_CURRENT
rts

LoadAudioFrameSPI:
WaitAFLOW:
  lda VERA_ISR
  and #$08
  beq WaitAFLOW
LoadLeadAudioSPI:
  lda AUD_FRAME_NUMSECTORS
  sta loop_ctr2
  MULTIBLK_START AUD_SECTOR_CURRENT
readAUDSECTOR:
  MultiBlock_WaitData
  jsr SDSEC_TO_AUDIO
  dec loop_ctr2
  jne readAUDSECTOR
  MULTIBLOCK_END
  AddByteVal AUD_SECTOR_ADDER, AUD_SECTOR_CURRENT
rts


SPI_loadframe8:
    lda page_flag
    beq HipageB
    wai
    jsr Copy_THE_Palette

    ; page flip
HI_PAGE_ACTIVE_8BIT:
    lda #%01001100
    sta $9F2F

    stz page_flag
    stz VERA_LADDR
    stz VERA_MADDR
    lda #%00010000
    sta VERA_HADDR
    bra ReadTheFrame

HipageB:
    wai
    jsr Copy_THE_Palette
    lda #1
    sta page_flag

    ; Page Flip
    lda #0
    sta $9F2F

HI_PAGE_ADDR_8BIT:
    lda #$98
    sta VERA_MADDR
HI_PAGE_HIADDR_8BIT:
    lda #%00010000
    sta VERA_HADDR

ReadTheFrame:
    MULTIBLK_START VID_SECTOR_CURRENT
    lda VID_FRAME_NUMSECTORS
    sta loop_ctr3
ReadVSector:
    MultiBlock_WaitData
    jsr SDSEC_TO_VRAM
    dec loop_ctr3
    jne ReadVSector

    lda VERA_LADDR
    sta PAL_ADDR1
    lda VERA_MADDR
    sta PAL_ADDR2
    lda VERA_HADDR
    sta PAL_ADDR3

CachePal:
    MultiBlock_WaitData
    jsr SDSEC_TO_VRAM
    MULTIBLOCK_END

doneFRAME:
rts

SPI_loadframeLOW:
    lda page_flag
    beq HipageBL

    wai
    ; page flip
HI_PAGE_ACTIVE_LOW:
    lda #%01001100
    ora G_WIDTH
    sta $9F2F
    lda #14
    sta PAL_OFFSET

    stz page_flag
    stz VERA_LADDR
    stz VERA_MADDR
    lda #%00010000
    sta VERA_HADDR
    bra ReadTheFrameL

HipageBL:
    wai
    lda #1
    sta page_flag

    ; Page Flip
    lda #0
    ora G_WIDTH
    sta $9F2F
    lda #15
    sta PAL_OFFSET
    stz VERA_LADDR

HI_PAGE_ADDR_LOW:
    lda #$98
    sta VERA_MADDR
HI_PAGE_HIADDR_LOW:
    lda #%00010000
    sta VERA_HADDR

ReadTheFrameL:
    MULTIBLK_START VID_SECTOR_CURRENT
    lda VID_FRAME_NUMSECTORS
    sta loop_ctr3
ReadVSectorL:
    MultiBlock_WaitData
    jsr SDSEC_TO_VRAM
    dec loop_ctr3
    jne ReadVSectorL

;set palette address
    stz VERA_LADDR
    lda #$FA
    sta VERA_MADDR
    lda #%00010001
    sta VERA_HADDR

SetPal:
    MultiBlock_WaitData
    jsr SDSEC_TO_VRAM
    MULTIBLOCK_END

doneFRAMEL:
rts

LOOPS:
  .byte 0

; Volume Up and Volume Down optimized by MooingLemur
; It's actually a little bit of Black Magic to me
; exactly how they work, but they do and very efficiently
; My original code worked but used at least 4 times as many cycles.
VolumeUp:
  pha ; 3
  lda AUDIO_CTRL ; 4
  inc ; 2
  bit #$0f ; 2
  beq :+ ; 2/3
  sta AUDIO_CTRL ; 4
: pla ; 4
 rts ; 6

VolumeDown:
  pha
  lda AUDIO_CTRL
  dec
  bmi :+
  sta AUDIO_CTRL
: pla
 rts

Copy_THE_Palette:
copypalette:
          lda #1
          sta VERA_CTRL
          lda PAL_ADDR1
          sta VERA_LADDR
          lda PAL_ADDR2
          sta VERA_MADDR
          lda PAL_ADDR3
          sta VERA_HADDR
          stz VERA_CTRL

          stz VERA_LADDR
          lda #$FA       ; THE PALETTE
          sta VERA_MADDR
          lda #%00010001
          sta VERA_HADDR

          ldx #16
ploop1:
          .repeat 32
          lda VERA_DATA1
          sta VERA_DATA0
          .endrepeat

          dex
          jne ploop1
 rts

; ---------------------------------------------------------------------
; Shared sector readers.  sdsector_to expands to ~400 bytes of unrolled (VRAM reader: sdsector_to_x128, ~790)
; code, so it lives here ONCE per target instead of being expanded inline
; at every call site.  Cost is jsr/rts = 12 cycles per 512 byte sector.
; Same register behaviour as the inline macro: A and X clobbered (X = 0).
; ---------------------------------------------------------------------
SDSEC_TO_VRAM:
    sdsector_to_x128 VERA_DATA0
    rts

SDSEC_TO_AUDIO:
    sdsector_to AUDIO_FIFO
    rts

; ---------------------------------------------------------------------
; HIGH BANDWIDTH SPRITE VIDEO  (VTYPE 21, 22, 26, 27)
;
; SETSPRITEREAD_SPI is called ONCE by VIDKIT-B1 (SPIVID jump table $A03C, INTERNAL)
; after the sector numbers are known.  It works out the VRAM layout of the two sprite
; buffers (512 byte units = 1 SD sector):
;     buffer 1 | staging (8bpp + palette only) | buffer 2 | staging
;   tier 1: start unit 152 = 1:$3000 when both buffers fit below the text map (unit 216 = 1:$B000)
;   tier 2/3: start unit 0.  Beyond unit 216 the text layer gets hidden (HB_HIDE_TEXT).
;   The limit is unit 252 ($1F800): 2 x 126 units, the last SD sector write must not reach the PSG.
; Results go to HB_* ($0497...) for VIDKIT-B2 setup_SpriteGrid.  Too big / no sprites / bad grid:
; IS_SUPPORTED_VIDEO is cleared so the players refuse the file.
; Frame file layout:  [frame sectors][512 byte palette sector (not for 22 / 27)]
;   8bpp : palette staged in VRAM behind the frame, copied to $1FA00 in VBlank
;   4bpp : palette sector goes straight to $1FA00 (encoder keeps the other frame's row 14/15)
; Frame 0 is loaded into buffer 2 (page_flag 0 -> load buffer 2), same as the bitmap loaders.
; ---------------------------------------------------------------------
HB_FLAG_4BPP = 1
HB_FLAG_PAL  = 2

SETSPRITEREAD_SPI:
    ; ---- number of sprites per buffer N = (FrameWidth / SpriteWidth) * (FrameHeight / SpriteHeight)
    lda VideoHeader_SpriteWidth
    jeq hb_reject
    lda VideoHeader_SpriteHeight
    jeq hb_reject
    lda VideoHeader_FrameWidth
    sta R0L
    lda VideoHeader_FrameWidth+1
    sta R0H
    lda VideoHeader_SpriteWidth
    jsr hb_shift
    lda R0L
    sta R1L                         ; columns
    lda VideoHeader_FrameHeight
    sta R0L
    lda VideoHeader_FrameHeight+1
    sta R0H
    lda VideoHeader_SpriteHeight
    jsr hb_shift
    stz R2L                         ; N = columns * rows  (repeated add)
    stz R2H
    ldx R0L                         ; rows
    jeq hb_reject
hb_mul:
    clc
    lda R2L
    adc R1L
    sta R2L
    bcc hb_mulc
    inc R2H
hb_mulc:
    dex
    bne hb_mul
    lda R2H
    jne hb_reject
    lda R2L
    jeq hb_reject
    cmp #64                         ; sprite 0 (mouse) is not used: 1..N and N+1..2N, N <= 63
    jcs hb_reject
    sta HB_NUMSPR
    sta hb_count

    ; ---- flags and buffer size in units
    lda VID_FRAME_NUMSECTORS
    sta R3L
    ldx #0
    lda VideoHeader_BPP
    cmp #4
    bne hb_f1
    ldx #HB_FLAG_4BPP
hb_f1:
    lda VID_HAS_PALETTE
    beq hb_f3
    txa
    ora #HB_FLAG_PAL
    tax
    lda VideoHeader_BPP
    cmp #8
    bne hb_f3
    inc R3L                         ; 8bpp: one staging sector behind each buffer
hb_f3:
    stx hb_flags
    lda R3L
    cmp #127                        ; 2 x units must be <= 252
    jcs hb_reject
    ldx #152                        ; tier 1 start (1:$3000)
    cmp #33
    bcc hb_f4
    ldx #0                          ; does not fit below the text map from there: start at 0:0000
hb_f4:
    stx R1L                         ; start unit of buffer 1
    txa
    clc
    adc R3L
    sta R1H                         ; start unit of buffer 2
    clc
    adc R3L                         ; end unit
    ldx #0
    cmp #217
    bcc hb_f5
    ldx #1                          ; runs over the text map
hb_f5:
    stx HB_HIDE_TEXT

    ; ---- VRAM addresses of the two buffers (middle byte / bank) for B2 and for our own loader
    lda R1L
    jsr hb_unit2addr
    sta HB_MID1
    sta hb_buf1_m
    stx HB_BANK1
    txa
    ora #%00010000                  ; auto increment 1
    sta hb_buf1_h
    lda R1H
    jsr hb_unit2addr
    sta HB_MID2
    sta hb_buf2_m
    stx HB_BANK2
    txa
    ora #%00010000
    sta hb_buf2_h

    ; ---- attribute address of sprite 2N byte 6 = $FC06 + 16 * N
    lda HB_NUMSPR
    lsr
    lsr
    lsr
    lsr
    clc
    adc #$FC
    sta hb_attrend_h
    lda HB_NUMSPR
    asl
    asl
    asl
    asl
    ora #6
    sta hb_attrend_l

    jmp hb_install                  ; patch the 8 bpp or 4 bpp frame loader, then SETDEFAULT_CONTROLS

hb_reject:
    stz IS_SUPPORTED_VIDEO
    rts

; A = 2^k (8..64): R0 (16 bit) >>= k
hb_shift:
    ldx #0
hb_sh1:
    lsr
    bcs hb_sh2
    inx
    bra hb_sh1
hb_sh2:
    txa
    beq hb_shret
hb_sh3:
    lsr R0H
    ror R0L
    dex
    bne hb_sh3
hb_shret:
    rts

; A = buffer start unit (512 bytes each)  ->  A = VRAM middle address byte, X = bank (0/1)
hb_unit2addr:
    ldx #0
    cmp #128
    bcc hb_u1
    ldx #1
    and #127
hb_u1:
    asl
    rts

; ---------------------------------------------------------------------
; Frame loaders.  One for 8 bpp, one for 4 bpp: nothing in the play path tests flags or loads
; values from variables.  hb_install (run once per video, from SETSPRITEREAD_SPI) writes the
; sprite count, buffer addresses, attribute address, sector count and the palette handling
; straight into the operands of these routines (HB8_* / HB4_*), the same way the standard
; sprite loaders are set up.
;   Palette handling is switched by patching:
;     HB8_PALCOPY  jsr Copy_THE_Palette   <-> nop nop nop   (22 / 27: no palette)
;     HBx_POST     nop nop (fall into the palette sector read)  <-> bra hbx_end   (22 / 27)
; ---------------------------------------------------------------------
SPI_loadsprite8:
    wai
HB8_PALCOPY:
    jsr Copy_THE_Palette            ; 8bpp + palette: staged palette -> VERA in this VBlank
    lda page_flag
    beq hb8_show1
    ; frame in buffer 2 is complete: show it, hide buffer 1, then load the next frame into buffer 1
HB8_ATTR_L:
    ldx #0
HB8_ATTR_H:
    ldy #0
    lda #%01001001                  ; stride -8, VRAM bank 1
    jsr hb8_swap
    stz page_flag
HB8_BUF1_M:
    lda #0
HB8_BUF1_H:
    ldx #0
    bra hb8_read
hb8_show1:
    ldx #$0E                        ; sprite 1, byte 6
    ldy #$FC
    lda #%01000001                  ; stride +8, VRAM bank 1
    jsr hb8_swap
    lda #1
    sta page_flag
HB8_BUF2_M:
    lda #0
HB8_BUF2_H:
    ldx #0
hb8_read:
    stz VERA_LADDR
    sta VERA_MADDR
    stx VERA_HADDR
    MULTIBLK_START VID_SECTOR_CURRENT
HB8_NSEC:
    lda #0
    sta loop_ctr3
hb8_rdsec:
    MultiBlock_WaitData
    jsr SDSEC_TO_VRAM
    dec loop_ctr3
    jne hb8_rdsec
HB8_POST:
    bra hb8_end                     ; patched to nop nop when a palette sector follows
    lda VERA_LADDR                  ; remember where the palette is staged
    sta PAL_ADDR1
    lda VERA_MADDR
    sta PAL_ADDR2
    lda VERA_HADDR
    sta PAL_ADDR3
    MultiBlock_WaitData
    jsr SDSEC_TO_VRAM
hb8_end:
    MULTIBLOCK_END
    rts

; A = VERA_HADDR (stride/bank)   X = VERA_LADDR   Y = VERA_MADDR   (address of the first sprite byte 6 to write)
; First N sprites in the stride direction get z-depth 3 (visible), the next N get 0 (hidden)
hb8_swap:
    stx VERA_LADDR
    sty VERA_MADDR
    sta VERA_HADDR
HB8_CNT1:
    ldx #0
    lda #%00001100
hb8_on:
    sta VERA_DATA0
    dex
    bne hb8_on
HB8_CNT2:
    ldy #0
hb8_off:
    stz VERA_DATA0
    dey
    bne hb8_off
    rts

SPI_loadsprite4:
    wai
    lda page_flag
    beq hb4_show1
HB4_ATTR_L:
    ldx #0
HB4_ATTR_H:
    ldy #0
    lda #%01001001
    jsr hb4_swap
    stz page_flag
HB4_BUF1_M:
    lda #0
HB4_BUF1_H:
    ldx #0
    bra hb4_read
hb4_show1:
    ldx #$0E
    ldy #$FC
    lda #%01000001
    jsr hb4_swap
    lda #1
    sta page_flag
HB4_BUF2_M:
    lda #0
HB4_BUF2_H:
    ldx #0
hb4_read:
    stz VERA_LADDR
    sta VERA_MADDR
    stx VERA_HADDR
    MULTIBLK_START VID_SECTOR_CURRENT
HB4_NSEC:
    lda #0
    sta loop_ctr3
hb4_rdsec:
    MultiBlock_WaitData
    jsr SDSEC_TO_VRAM
    dec loop_ctr3
    jne hb4_rdsec
HB4_POST:
    bra hb4_end                     ; patched to nop nop when a palette sector follows
    stz VERA_LADDR                  ; 4bpp: palette sector straight into the VERA palette
    lda #$FA
    sta VERA_MADDR
    lda #%00010001
    sta VERA_HADDR
    MultiBlock_WaitData
    jsr SDSEC_TO_VRAM
hb4_end:
    MULTIBLOCK_END
    rts

hb4_swap:
    stx VERA_LADDR
    sty VERA_MADDR
    sta VERA_HADDR
HB4_CNT1:
    ldx #0
    lda #%00001100
hb4_on:
    sta VERA_DATA0
    dex
    bne hb4_on
HB4_CNT2:
    ldy #0
hb4_off:
    stz VERA_DATA0
    dey
    bne hb4_off
    rts

; ---------------------------------------------------------------------
; Run once per video: copy the values worked out by SETSPRITEREAD_SPI into the loader that
; matches the bit depth, set the palette handling, and install it as the frame loader.
; ---------------------------------------------------------------------
hb_install:
    lda hb_flags
    and #HB_FLAG_4BPP
    jne hb_inst4

    lda hb_count
    sta HB8_CNT1+1
    sta HB8_CNT2+1
    lda hb_attrend_l
    sta HB8_ATTR_L+1
    lda hb_attrend_h
    sta HB8_ATTR_H+1
    lda hb_buf1_m
    sta HB8_BUF1_M+1
    lda hb_buf1_h
    sta HB8_BUF1_H+1
    lda hb_buf2_m
    sta HB8_BUF2_M+1
    lda hb_buf2_h
    sta HB8_BUF2_H+1
    lda VID_FRAME_NUMSECTORS
    sta HB8_NSEC+1
    lda hb_flags
    and #HB_FLAG_PAL
    beq hb_i8nopal
    lda #$20                        ; jsr Copy_THE_Palette
    sta HB8_PALCOPY
    lda #<Copy_THE_Palette
    sta HB8_PALCOPY+1
    lda #>Copy_THE_Palette
    sta HB8_PALCOPY+2
    lda #$EA                        ; nop nop: fall into the palette sector read
    sta HB8_POST
    sta HB8_POST+1
    bra hb_i8go
hb_i8nopal:
    lda #$EA                        ; no palette copy
    sta HB8_PALCOPY
    sta HB8_PALCOPY+1
    sta HB8_PALCOPY+2
    lda #$80                        ; bra hb8_end
    sta HB8_POST
    lda #(hb8_end - HB8_POST - 2)
    sta HB8_POST+1
hb_i8go:
    lda #<SPI_loadsprite8
    ldx #>SPI_loadsprite8
    bra hb_idone

hb_inst4:
    lda hb_count
    sta HB4_CNT1+1
    sta HB4_CNT2+1
    lda hb_attrend_l
    sta HB4_ATTR_L+1
    lda hb_attrend_h
    sta HB4_ATTR_H+1
    lda hb_buf1_m
    sta HB4_BUF1_M+1
    lda hb_buf1_h
    sta HB4_BUF1_H+1
    lda hb_buf2_m
    sta HB4_BUF2_M+1
    lda hb_buf2_h
    sta HB4_BUF2_H+1
    lda VID_FRAME_NUMSECTORS
    sta HB4_NSEC+1
    lda hb_flags
    and #HB_FLAG_PAL
    beq hb_i4nopal
    lda #$EA
    sta HB4_POST
    sta HB4_POST+1
    bra hb_i4go
hb_i4nopal:
    lda #$80                        ; bra hb4_end
    sta HB4_POST
    lda #(hb4_end - HB4_POST - 2)
    sta HB4_POST+1
hb_i4go:
    lda #<SPI_loadsprite4
    ldx #>SPI_loadsprite4
hb_idone:
    sta LOADFRAME_CALL1+1
    sta LOADFRAME_CALL2+1
    stx LOADFRAME_CALL1+2
    stx LOADFRAME_CALL2+2
    jmp SETDEFAULT_CONTROLS

hb_buf1_m:    .byte 0
hb_buf1_h:    .byte 0
hb_buf2_m:    .byte 0
hb_buf2_h:    .byte 0
hb_count:     .byte 0
hb_flags:     .byte 0
hb_attrend_l: .byte 0
hb_attrend_h: .byte 0

SETVIDREAD_BITMAP:
   lda #<SPI_loadframe8
   ldx #>SPI_loadframe8
   sta LOADFRAME_CALL1+1
   sta LOADFRAME_CALL2+1
   stx LOADFRAME_CALL1+2
   stx LOADFRAME_CALL2+2
jmp SETDEFAULT_CONTROLS

SETVIDREAD_BITMAP_LOW:
   lda #<SPI_loadframeLOW
   ldx #>SPI_loadframeLOW
   sta LOADFRAME_CALL1+1
   sta LOADFRAME_CALL2+1
   stx LOADFRAME_CALL1+2
   stx LOADFRAME_CALL2+2
   ; Fall through to SET_DEFAULT_CONTROLS

SETDEFAULT_CONTROLS:
    ldx #<kbdbuf_peek
    ldy #>kbdbuf_peek
    stx PLAYCONTROL1+1
    sty PLAYCONTROL1+2
    ldx #<ProcessKeys
    ldy #>ProcessKeys
    stx PLAYCONTROL2+1
    sty PLAYCONTROL2+2
rts


SETAUDIOREAD_SPI:
  lda #<LoadLeadAudioSPI
  ldx #>LoadLeadAudioSPI
  sta FIRSTAUDIOFRAME+1
  stx FIRSTAUDIOFRAME+2
  lda #<LoadAudioFrameSPI
  ldx #>LoadAudioFrameSPI
  sta LOADAUDIOCALL+1
  stx LOADAUDIOCALL+2
  lda #<ReadAudioLeadinSPI
  ldx #>ReadAudioLeadinSPI
  sta LEADREADCALL+1
  stx LEADREADCALL+2
 rts

SET_FRAME_38K:
     lda #%01001100
     sta HI_PAGE_ACTIVE_8BIT+1
     sta HI_PAGE_ACTIVE_LOW+1
     lda #$98
     sta HI_PAGE_ADDR_8BIT+1
     sta HI_PAGE_ADDR_LOW+1
     lda #%00010000
     sta HI_PAGE_HIADDR_8BIT+1
     sta HI_PAGE_HIADDR_LOW+1
  rts

 SET_FRAME_51K:
     lda #%01101000
     sta HI_PAGE_ACTIVE_8BIT+1
     sta HI_PAGE_ACTIVE_LOW+1
     lda #$D0
     sta HI_PAGE_ADDR_8BIT+1
     sta HI_PAGE_ADDR_LOW+1
     lda #%00010000
     sta HI_PAGE_HIADDR_8BIT+1
     sta HI_PAGE_HIADDR_LOW+1
  rts

SET_FRAME_62K:
     lda #%10000000
     sta HI_PAGE_ACTIVE_8BIT+1
     sta HI_PAGE_ACTIVE_LOW+1
     lda #$00
     sta HI_PAGE_ADDR_8BIT+1
     sta HI_PAGE_ADDR_LOW+1
     lda #%00010001
     sta HI_PAGE_HIADDR_8BIT+1
     sta HI_PAGE_HIADDR_LOW+1
  rts

zsm_getstate := $A02A
zsm_play := $A006
zsm_stop := $A009

.macro TrampJSR ttarget
  lda #<ttarget
  sta $040F
  lda #>ttarget
  sta $0410
  jsr $0400
.endmacro

ZSMKIT_UNPAUSE:
  lda ZKITBANK
  beq unpauseDONE
  sta Trampoline_BANK_Target
  stz R14
  ldx R14
unpauseLOOP:
  lda ZKitSlots, x
  beq unpauseSkip
  ldx R14
  TrampJSR zsm_play
  ldx R14
unpauseSkip:
  stz ZKitSlots, x
  inx
  cpx #8
  beq unpauseDONE
  stx R14
  bra unpauseLOOP
unpauseDONE:
rts

ZSMKIT_PAUSEALL:
  lda ZKITBANK     ; ZSM Kit loaded bank passed in R0
  beq zpauseDONE
  sta Trampoline_BANK_Target
  stz R14

zpauseloop:
  ldx R14
  TrampJSR zsm_getstate
  bcs ZPlaying
  ldx R14
  stz ZKitSlots, x
  txa
  cmp #7
  beq zpauseDONE
  inc R14
  bra zpauseloop

ZPlaying:
 ldx R14
 lda #1
 sta ZKitSlots, x
 TrampJSR zsm_stop
 lda R14
 cmp #7
 beq zpauseDONE
 inc R14
 bra zpauseloop
zpauseDONE:
rts

ZKitSlots:
 .byte 0,0,0,0,0,0,0,0

ZKITBANK:
 .byte 0

; Pass ZSMKIT Loaded bank in R0
SETBANK_ZSMKIT:
 ldx R0
 stx ZKITBANK
rts

ISOCURSOR:
FIX_ISOCURSOR:
  lda #$F8
  sta $9F20
  lda #$F4
  sta $9F21
  lda #%00010001
  sta $9F22
  ldx #6
curloop:
  stz $9F23
  dex
  bne curloop
  lda #$FF
  sta $9F23
  sta $9F23
  rts

setControls:
   jsr setControl1
   jmp setControl2

setControl1:
   lda R7L
   ldx R7H
   sta PLAYCONTROL1 + 1
   stx PLAYCONTROL1 + 2
   rts

setControl2:
   lda R8L
   ldx R8H
   sta PLAYCONTROL2 + 1
   stx PLAYCONTROL2 + 2
   rts

;


