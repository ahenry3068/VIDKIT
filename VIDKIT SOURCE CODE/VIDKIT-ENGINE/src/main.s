.export CLEARGRAPH
.export SETAUDIOREAD

.include "../../vidvars.inc"

     .macpack longbranch

  .macro incVERA
  .local skip
     inc $9F20
     bne skip
     inc $9F21.
   skip:
  .endmacro

  .macro inc24 target
     .local doneinc
          inc target
          bne doneinc
          inc target+1
          bne doneinc
          inc target+2
doneinc:
     .endmacro

      .macro cmp24 target,comptarget
     .local donecmp
            lda target
            cmp comptarget
            bne donecmp
            lda target+1
            cmp comptarget+1
            bne donecmp
            lda target+2
            cmp comptarget+2
donecmp:
      .endmacro


     .macro WaitForAFLOW
     .local waitloop
waitloop: lda VERA_ISR
          and #$08
          beq waitloop
     .endmacro


.org $A000
jmp startplay                ;SYS $A000   (Starts Video Play)
jmp CLEARALLBUFFERS          ;SYS $A003   (Utility routine, clears the ALL Video Buffer)
jmp SETAUDIOREAD             ;SYS $A006   (Sets the Size of the Audio Frame read)
jmp SETSPRITEREAD_8BPP       ;SYS $A009   (Sets up for 8 bpp Sprite (with palette) playback
jmp SETSPRITEREAD_4BPP       ;SYS $A00C   (Sets up for 4 bpp Sprite (with palette) playback
jmp SETVIDREAD_BITMAP        ;SYS $A00F   (Set up for bitmap (with palette) based videos)
jmp SETEXTERNAL_FRAMEREAD    ;SYS $A012   (Set an external Video frame reading procedure (address passed in X,Y)
jmp CLEARGRAPH               ;SYS $A015
jmp CLEARTEXTBUFFER          ;SYS $A018
jmp CLEARSPRITEBUFFER        ;SYS $A01B
jmp SETAUDIOLFN              ;SYS $A01E
jmp SETFILEREAD_PCM_ONLY     ;SYS $A021
jmp HIDEALLSPRITES           ;SYS $A024
;jmp PALSHIFT                 ;SYS $A027
nop
nop
nop
jmp SET_DEFAULT_PALETTE      ;SYS $A02A
jmp SETEXTERNAL_CONTROLS     ;SYS $A02D
jmp TURN_OFF_PALETTE_HANDLING  ;SYS $A030
jmp TURN_ON_PALETTE_HANDLING   ;SYS $A033
jmp DISK_FASTMODE              ;SYS $A036
jmp BLACKFADE                  ;SYS $A039
jmp PAL2BLACK                  ;SYS $A03C
jmp setControls                ;SYS $A03F
jmp setControl1                ;SYS $A042
jmp setControl2                ;SYS $A045
jmp SETDEFAULT_CONTROLS        ;SYS $A048

startplay:
       lda LOCK_KEYS       ; variable used to turn off controls
       bne keysoff
       lda #$EA      ; nop
       bra setKEYGuard
keysoff:
       lda #$60      ; rts
setKEYGuard:
       sta KEYGUARD  ; set termination point of ProcessKeys
   lda R0L
   sta VERA_RATEBYTE
   lda R0H
   and #%00110000
   ora Audio_Volume
   sta VERA_CFGBYTE
   stz MANEXIT
 lda 1
 pha
 stz 1
   stz PlayDone
   stz AUDIO_RATE
   lda #%10000000
   sta AUDIO_CTRL    ; reset the Audio FIFO
   lda VERA_CFGBYTE
   sta AUDIO_CTRL
READAUDIOLEAD:
   lda DO_BUFFER_AUDIO
   beq FIRSTAUDIOFRAME   ; Skip Extra LeadIn if 0 in DO_BUFFER_AUDIO

LoadAudioCall1:
   jsr LoadAudioFrame
FIRSTAUDIOFRAME:
   jsr LoadAudioFrame

        stz page_flag
        lda VERA_RATEBYTE
        sta AUDIO_RATE    ; start play after filling the FIFO
loadframe_call1:
        jsr loadframe_8bpp

VidPlayLoop:
          lda PlayDone
          ; cmp #0
          bne over

          WaitForAFLOW
LoadAudioCall2:
          jsr LoadAudioFrame
PlayControl1:
          jsr kbdbuf_peek
          beq loadframe_call2
PlayControl2:
          jsr ProcessKeys

loadframe_call2:
          jsr loadframe_8bpp
          bra VidPlayLoop
over:
         jsr CLRCHN
flushinput:
         jsr GETIN
         bne flushinput
  pla
  sta 1
         rts
         ;rts


AudioCheck:
   jsr READST
   beq over2
   lda #1
   sta PCM_EOF
   jmp setdone
over2:
   jmp kbdbuf_peek


ProcessKeys:
  jsr CLRCHN
  jsr GETIN
  cmp #17
  jeq VolumeDown
nextcheck:
  cmp #145
  jeq VolumeUp
KEYGUARD:
  nop
  cmp #32
  jeq dopause
  cmp #135
  jeq doTurnON_LOOP
  cmp #27
  jeq SetPlayDone
  ldx KEY_EXTRA
  beq skipEXTRAKEY
  cmp KEY_EXTRA
  jeq do_EXTRAEXIT

skipEXTRAKEY:
  rts

do_EXTRAEXIT:
  sta MANEXIT
  bra setdone

doTurnON_LOOP:
  lda #1
  sta LOOP_FLAG
  rts

dopause:
  stz AUDIO_RATE
pauseloop:
  jsr GETIN
  cmp #27
  beq SetPlayDone
  cmp #32
  beq endpause
  bra pauseloop
endpause:
  lda VERA_RATEBYTE
  sta AUDIO_RATE
  rts

SetPlayDone:
  lda #$FF
  sta MANEXIT
setdone:
  lda #$FF
  sta PlayDone
  rts


LoadAudioFrame:
audlfn1:
          ldx #6
          jsr CHKIN
abuff255: lda #6
          sta loop_ctr1
aloop1:   ldx #<AUDIO_FIFO
          ldy #>AUDIO_FIFO
AFRAME_BYTES:
          lda #255
          sec
          jsr MACPTR
          dec loop_ctr1
          bne aloop1
          ldx #<AUDIO_FIFO
          ldy #>AUDIO_FIFO
abuffloadrem:
          lda #114
          sec
          jmp MACPTR ;tail call optimized


LoadToVRAM:
        ldx #4
        jsr CHKIN
        lda LOOPS_255
        sta loop_ctr3
mloops: lda #255
        ldx #$23
        ldy #$9F
        sec
        jsr MACPTR
        dec loop_ctr3
        bne mloops
        lda BYTES_REM
        ldx #$23
        ldy #$9F
        sec
        jmp MACPTR


loadframe_8bpp:
    ldx #4
	jsr CHKIN
SBuffSize255:
    lda #70
    sta LOOPS_255
SBuffSizeRemainder:
	lda #70
    sta BYTES_REM
    lda page_flag
    beq Hipage
SpriteAttrEndAddr:
    ldx #$36
    ldy #$FE         ; start at sprite 70 (unless modified)
    lda #%01001001   ; and decrement
    jsr swapsprites

    stz page_flag
    stz VERA_LADDR
    stz VERA_MADDR
    bra Hiaddr

Hipage:
    ldx #$0E
    ldy #$FC
    lda #%01000001
    jsr swapsprites

    lda #1
    sta page_flag
HiSpriteDataLowAddr:
    lda #0
    sta VERA_LADDR
HiSpriteDataMidAddr:
    lda #$48
    sta VERA_MADDR
Hiaddr:
    lda #%00010000
    sta VERA_HADDR

    jsr LoadToVRAM

HandlePalette_8bpp:
    ; nop nop nop ; insert this code to disable palette Handling
    jsr CacheFullPalette
    inc24 FRAME_CURRENT
    cmp24 FRAME_CURRENT, FRAME_TARGET
    jeq setdone
    rts

CacheFullPalette:
; now load the palette for the frame
    lda VERA_LADDR
    sta PAL_ADDR1
    lda VERA_MADDR
    sta PAL_ADDR2
    lda VERA_HADDR
    sta PAL_ADDR3
	ldx #$23
	ldy #$9F
	lda #255
	sec
	jsr MACPTR
	ldx #$23
	ldy #$9F
	lda #255
	sec
	jsr MACPTR
	ldx #$23
	ldy #$9F
	lda #2
	sec
    jmp MACPTR


swapsprites:
          stx VERA_LADDR
          sty VERA_MADDR
          sta VERA_HADDR
          lda #1
          sta VERA_CTRL
          lda PAL_ADDR1
          sta VERA_LADDR
          lda PAL_ADDR2
          sta VERA_MADDR
          lda PAL_ADDR3
          sta VERA_HADDR
          stz VERA_CTRL
SpriteCount:
          ldx #35
          ldy #35
          lda #%00001100
          wai
sprloop1: sta VERA_DATA0
          dex
          bne sprloop1
sprloop2: stz VERA_DATA0
          dey
          bne sprloop2
SWAP_NOP:
          nop
          stz VERA_LADDR
          lda #$FA       ; THE PALETTE
          sta VERA_MADDR
          lda #%00010001
          sta VERA_HADDR
ploop2:   ldx #32
ploop1:   lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          lda VERA_DATA1
          sta VERA_DATA0
          dex
          bne ploop1
          rts

loadframe_4bpp:
    ldx #4
	jsr CHKIN
SBuffSize255_4bpp:
    lda #35
    sta LOOPS_255
SBuffSizeRemainder_4bpp:
	lda #35
    sta BYTES_REM
    lda page_flag
    beq Hipage_4bpp

SpriteAttrEndAddr_4bpp:
   ldx #$36
   ldy #$FE         ; start at sprite 70
   lda #%01001001   ; and decrement
   jsr swapsprites_4bpp
   ldx #$C0
   stx palptr

    stz page_flag
    stz VERA_LADDR
    lda #$30
    sta VERA_MADDR
    bra Hiaddr_4bpp

Hipage_4bpp:
    ldx #$0E
    ldy #$FC
    lda #%01000001
    jsr swapsprites_4bpp
    ldx #$E0
    stx palptr

    lda #1
    sta page_flag
HiSpriteDataLowAddr_4bpp:
    lda #0
    sta VERA_LADDR
HiSpriteDataMidAddr_4bpp:
    lda #$53
    sta VERA_MADDR
Hiaddr_4bpp:
    lda #%00010001
    sta VERA_HADDR

    jsr LoadToVRAM

; NOW WE GET THE PALETTE DATA FOR THE FRAME
GET_4BIT_PALETTE:
;   jmp INC_FRM_4BPP_SPRITE ; insert this code to turn off palette checks.
    lda palptr
	sta VERA_LADDR
	lda #$FB
	sta VERA_MADDR
	lda #%00010001
	sta VERA_HADDR
	ldx #$23
	ldy #$9F
	lda #32
	sec
	jsr MACPTR
INC_FRM_4BPP_SPRITE:
    inc24 FRAME_CURRENT
    cmp24 FRAME_CURRENT, FRAME_TARGET
	jeq setdone
    rts

swapsprites_4bpp:
          wai
          stx VERA_LADDR
          sty VERA_MADDR
          sta VERA_HADDR
SpriteCount4bpp:
          ldx #35
          ldy #35
          lda #%00001100
sprloop1_4bpp:
          sta VERA_DATA0
          dex
          bne sprloop1_4bpp
sprloop2_4bpp:
          stz VERA_DATA0
          dey
          bne sprloop2_4bpp
SWAP4_NOP:
          nop
          lda palptr
          sta VERA_LADDR
          lda #$FB
          sta VERA_MADDR
          lda #%00010001
          sta VERA_HADDR
          lda VERA_DATA0
          sta palbytes
          lda VERA_DATA0
          sta palbytes+1
          stz VERA_LADDR
          lda #$FA
          sta VERA_MADDR
          lda palbytes
          sta VERA_DATA0
          lda palbytes+1
          sta VERA_DATA0
          rts

loadframe_bitmap:
    ldx #4
	jsr CHKIN
SBuffSize255B:
    lda #37
    sta loop_ctr3
    wai
BIT_AFTER_WAI:
    ; jmp chk_page_flag ; code to insert to skip Palette changing !
    lda #1
    sta VERA_CTRL
    lda PAL_LOBYTE
    sta VERA_LADDR
    lda #$FB
    sta VERA_MADDR
    lda #%00010001
    sta VERA_HADDR
    stz VERA_CTRL
    sta VERA_HADDR
    lda #$FA
    sta VERA_MADDR
    stz VERA_LADDR
    .repeat 4
      lda $9F24
      sta $9F23
    .endrep
chk_page_flag:
    lda page_flag
    beq HipageB
    lda #%01001100
    ora G_WIDTH
    sta $9F2F
BIT_PAL_SKIP1:
    ;jmp zero_page_flag ; code to insert to skip palette changing
    lda #15
    sta PAL_OFFSET
    lda #$C0
    sta PAL_LOBYTE
zero_page_flag:
    stz page_flag
    stz VERA_LADDR
    stz VERA_MADDR
    bra HiaddrB
HipageB:
    lda #1
    sta page_flag
    lda #0
    ora G_WIDTH
    sta $9F2F
 BIT_PAL_SKIP2:
    ; jmp HI_ADDR_SET ; code to insert to skip palette changing
    lda #14
    sta PAL_OFFSET
    lda #$E0
    sta PAL_LOBYTE
 HI_ADDR_SET:
    lda #0
    sta VERA_LADDR
    lda #$98
    sta VERA_MADDR
HiaddrB:
    lda #%00010000
    sta VERA_HADDR
loop1B:
	ldx #$23
	ldy #$9F
	lda #$FF
	sec
	jsr MACPTR
	dec loop_ctr3
	bne loop1B
	ldx #$23
	ldy #$9F
SBuffSizeRemainderB:
	lda #$A5
	sec
BitMapFrame_LAST_MACPTR:
    ; jmp BIT_MAP_FRAME_INCREMENT ; code to insert to skip palette changing.
	jsr MACPTR
    lda PAL_LOBYTE
    sta VERA_LADDR
    lda #$FB
    sta VERA_MADDR
    lda #%00010001
    sta VERA_HADDR
	ldx #$23
	ldy #$9F
	lda G_PALSIZE
	sec
BIT_MAP_FRAME_INCREMENT:
	jsr MACPTR
    inc24 FRAME_CURRENT
    cmp24 FRAME_CURRENT, FRAME_TARGET
    jeq setdone
  rts

;PCOPYDOWN:
;    lda #%00010001
;    sta VERA_HADDR
;    lda #$FB
;    sta VERA_MADDR
;    lda PAL_LOBYTE
;    sta VERA_LADDR
;    ldx #0
;bploop:
;    lda VERA_DATA0
;    sta tmppal, x
;    inx
;    cpx #4
;    bne bploop
;    stz VERA_LADDR
;    lda #$FA
;    sta VERA_MADDR
;    ldx #0
;bploop2:
;    lda tmppal, x
;    sta VERA_DATA0
;    inx
;    cpx #4
;    bne bploop2
;  rts

;tmppal:
;   .byte 0,0,0,0

CLEARALLBUFFERS:
        jsr CLEARSPRITEBUFFER
        jsr CLEARTEXTBUFFER

CLEARGRAPH:
        stz $9F20
        stz $9F21
        lda #%00010000
        sta $9F22
        lda #0
        ldx #25
Cloop1:
        .repeat 12
          stz $9F23
        .endrep
        ina
        bne Cloop1
        dex
        bne Cloop1
      rts

CLEARTEXTBUFFER:
        stz $9F20
        lda #$B0
        sta $9F21
        lda #%00010001
        sta $9F22
        lda #0
        ldx #10
Ctloop1:
          .repeat 6
            stz $9F23
          .endrep
        ina
        bne Ctloop1
        dex
        bne Ctloop1
      rts

CLEARSPRITEBUFFER:
        stz $9F20
        lda #$30
        sta $9F21
        lda #%00010001
        sta $9F22
        lda #0
          ldx #32
Csloop1:  stz $9F23
          stz $9F23
          stz $9F23
          stz $9F23
        ina
        bne Csloop1
        dex
        bne Csloop1
      rts

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

; There is some duplication of capability here to
; because of migration of calling protocol from
; some older code to VIDKIT code.
setControls:
   jsr setControl1
   jmp setControl2

setControl1:
   lda R7L
   ldx R7H
   sta PlayControl1 + 1
   stx PlayControl1 + 2
   rts

setControl2:
   lda R8L
   ldx R8H
   sta PlayControl2 + 1
   stx PlayControl2 + 2
   rts

SetKeyboardPeek:
   stx PlayControl1+1  ; Call with PeekControl Pointer in XY
   sty PlayControl1+2
   rts

SETEXTERNAL_CONTROLS:
    jsr SetKeyboardPeek
    ldx $02
    ldy $03    ; R0 Main Control address
    stx PlayControl2+1
    sty PlayControl2+2
    rts

SETDEFAULT_CONTROLS:
    ldx #<kbdbuf_peek
    ldy #>kbdbuf_peek
    jsr SetKeyboardPeek
KeyProcess:
    ldx #<ProcessKeys
    ldy #>ProcessKeys
    stx PlayControl2+1
    sty PlayControl2+2
    rts

SETAUDIO_CONTROLS:
    ldx #<AudioCheck
    ldy #>AudioCheck
    stx PlayControl1+1
    sty PlayControl1+2
    bra KeyProcess

SETAUDIOLFN:
        lda R0L
        sta audlfn1+1
        rts

SETAUDIOREAD:
        lda R0H
        sta abuff255+1
        lda R1L
        sta abuffloadrem+1
        lda #255
        sta AFRAME_BYTES+1
MRTS:
        rts

SETSPRITEREAD_8BPP:
        lda R3L
        sta SBuffSize255+1
        lda R3H
        sta SBuffSizeRemainder+1
        lda R4L
        sta SpriteCount+1
        sta SpriteCount+3
        lda R5L
        sta SpriteAttrEndAddr+1
        lda R5H
        sta SpriteAttrEndAddr+3
        lda R6L
        sta HiSpriteDataLowAddr+1
        lda R6H
        sta HiSpriteDataMidAddr+1
        lda #<loadframe_8bpp
        ldx #>loadframe_8bpp
        sta loadframe_call1+1
        sta loadframe_call2+1
        stx loadframe_call1+2
        stx loadframe_call2+2
        jmp SETDEFAULT_CONTROLS

SETSPRITEREAD_4BPP:
        lda R3L
        sta SBuffSize255_4bpp+1
        lda R3H
        sta SBuffSizeRemainder_4bpp+1
        lda R4L
        sta SpriteCount4bpp+1
        sta SpriteCount4bpp+3
        lda R5L
        sta SpriteAttrEndAddr_4bpp+1
        lda R5H
        sta SpriteAttrEndAddr_4bpp+3
        lda R6L
        sta HiSpriteDataLowAddr_4bpp+1
        lda R6H
        sta HiSpriteDataMidAddr_4bpp +1
        lda #<loadframe_4bpp
        ldx #>loadframe_4bpp
        sta loadframe_call1+1
        sta loadframe_call2+1
        stx loadframe_call1+2
        stx loadframe_call2+2
        jmp SETDEFAULT_CONTROLS

SETVIDREAD_BITMAP:
        lda R3L
        sta SBuffSize255B+1
        lda R3H
        sta SBuffSizeRemainderB+1
        lda R2L
        sta G_WIDTH
        lda R4L
        sta G_PALSIZE
        lda #<loadframe_bitmap
        ldx #>loadframe_bitmap
        sta loadframe_call1+1
        sta loadframe_call2+1
        stx loadframe_call1+2
        stx loadframe_call2+2
        jmp SETDEFAULT_CONTROLS

SETFILEREAD_PCM_ONLY:    ; for playing WAV files and ZCM files.
        stz PCM_EOF
        stz DO_BUFFER_AUDIO
        lda #$FF
        sta AFRAME_BYTES+1
        lda #10
        sta abuff255+1
        sta abuffloadrem+1
        lda #<MRTS
        ldx #>MRTS
        sta loadframe_call1+1
        sta loadframe_call2+1
        stx loadframe_call1+2
        stx loadframe_call2+2
        jmp SETAUDIO_CONTROLS

HIDEALLSPRITES:
        lda #$0E
        sta VERA_LADDR
        lda #$FC
        sta VERA_MADDR
        lda #%01000001
        sta VERA_HADDR
        ldx #8
hloop:
        .repeat 16
           stz VERA_DATA0
        .endrep
        dex
        bne hloop
      rts

BLACKFADE:
       lda 0
       ina                           ; We are in Bank B, Increment to Bank C
       sta Trampoline_BANK_Target    ; And setup the Trampoline call !
       lda #$18
       sta Trampoline_JSR_Target
       lda #$B4                      ; $B418 is the Bank C call address for Fade2SolidColor
       sta Trampoline_JSR_Target+1
       stz 4
       stz 5 ; 0 out R1              ; Color passed at R1
       jmp Trampoline

; OLD BLACKFADE CODE
; NOW REPLACED BY A FADE2COLOR CALL TO
; VIDKIT-B3.BIN
;      lda #15
;      sta loop_ctr3
;faderloop:
;      wai
;      jsr PALSHIFT
;      dec loop_ctr3
;      bne faderloop
;      rts

;PALSHIFT:
;        stz 2
;        stz VERA_LADDR
;        lda #$FA
;        sta VERA_MADDR
;        lda #%00010001
;        sta VERA_HADDR
;mainstart:
;        lda VERA_MADDR
;        pha
;        lda VERA_LADDR
;        pha
;        lda VERA_DATA0   ; READ GB
;        ldx VERA_DATA0   ; READ R
;        pha              ; PUSH A
;        and #$0F         ; A is now BLUE
;        tay              ; Y IS NOW BLUE
;        beq skipbluedec
;        dey              ; DEC BLUE
;skipbluedec:
;        pla              ; POP A  (ORIGINAL GB)
;        .repeat 4
;         lsr
;        .endrepeat
;        beq skipgreendec
;        dea              ; DECREMENT GREEN
;skipgreendec:
;        .repeat 4
;          asl
;        .endrepeat       ; A IS NO G0
;        sty $20          ;
;        ora $20          ; A IS NOW GB DECREMENTED.
;        cpx #0
;        beq skipreddec
;        dex               ; DEC RED
;skipreddec:
;        tay
;        pla
;        sta VERA_LADDR
;        pla
;        sta VERA_MADDR
;stowit:
;        sty VERA_DATA0
;        stx VERA_DATA0
;        dec 2
;        bne mainstart
;        rts

TURN_ON_PALETTE_HANDLING:
     lda #$EA
     sta SWAP_NOP
     sta SWAP4_NOP
     lda #$A9  ; lda immediate
     sta BIT_AFTER_WAI
     sta BIT_PAL_SKIP1
     sta BIT_PAL_SKIP2

     ; operands for lda
     lda #15
     sta BIT_PAL_SKIP1+1
     lda #14
     sta BIT_PAL_SKIP2+1
     lda #1
     sta BIT_AFTER_WAI+1

     lda #$8D   ; sta absolute
     sta BIT_AFTER_WAI+2
     sta BIT_PAL_SKIP1+2
     sta BIT_PAL_SKIP2+2
     sta GET_4BIT_PALETTE+2

     lda #$A5  ; lda immediate
     sta GET_4BIT_PALETTE
     lda #<palptr
     sta GET_4BIT_PALETTE+1

     lda #$20     ; jsr instruction
     sta BitMapFrame_LAST_MACPTR
     sta HandlePalette_8bpp
     lda #<MACPTR
     sta BitMapFrame_LAST_MACPTR+1
     lda #>MACPTR
     sta BitMapFrame_LAST_MACPTR+2
     lda #<CacheFullPalette
     sta HandlePalette_8bpp+1
     lda #>CacheFullPalette
     sta HandlePalette_8bpp+2
     rts

TURN_OFF_PALETTE_HANDLING:
     lda #$60  ; rts opcode
     sta SWAP_NOP
     sta SWAP4_NOP
     lda #$EA  ; NOP opcode
     sta HandlePalette_8bpp
     sta HandlePalette_8bpp+1
     sta HandlePalette_8bpp+2

     lda #$4C     ; jmp instruction
     sta BitMapFrame_LAST_MACPTR
     sta GET_4BIT_PALETTE
     sta BIT_AFTER_WAI
     sta BIT_PAL_SKIP1
     sta BIT_PAL_SKIP2

     lda #<INC_FRM_4BPP_SPRITE
     sta GET_4BIT_PALETTE+1
     lda #>INC_FRM_4BPP_SPRITE
     sta GET_4BIT_PALETTE+2

     lda #<chk_page_flag
     sta BIT_AFTER_WAI+1
     lda #>chk_page_flag
     sta BIT_AFTER_WAI+2

     lda #<zero_page_flag
     sta BIT_PAL_SKIP1+1
     lda #>zero_page_flag
     sta BIT_PAL_SKIP1+2

     lda #<HI_ADDR_SET
     sta BIT_PAL_SKIP2+1
     lda #>HI_ADDR_SET
     sta BIT_PAL_SKIP2+2

     lda #<BIT_MAP_FRAME_INCREMENT
     sta BitMapFrame_LAST_MACPTR+1
     lda #>BIT_MAP_FRAME_INCREMENT
     sta BitMapFrame_LAST_MACPTR+2
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

SET_DEFAULT_PALETTE:
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

SETEXTERNAL_FRAMEREAD:
       stx loadframe_call1+1
       stx loadframe_call2+1
       sty loadframe_call1+2
       sty loadframe_call2+2
       rts

DISK_FASTMODE:
             lda #5
             ldx #<FastString
             ldy #>FastString
             jsr SETNAM
             lda #15
             ldx drivenumber
             ldy #15
             jsr SETLFS
             jsr OPEN
             ldx #15
             jsr CHKIN

flushchars:  jsr GETIN
             cmp #13
             bne flushchars
             lda #15
             jsr CLOSE
             jsr CLRCHN
             jmp READST
FastString:  .byte $55,$30,$3E,$42,$31,0
;            "U0>B1",0

PAL2BLACK:
    stz VERA_LADDR
    lda #$FA
    sta VERA_MADDR
    lda %00010001
    ldx #128
blkloop:
    .repeat 4
       stz VERA_DATA0
    .endrepeat
    dex
    bne blkloop
  rts



savectrl: .byte 0
palbytes: .word 00




