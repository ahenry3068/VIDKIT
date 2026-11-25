R0  := 2
R0L := 2
R0H := 3
R1  := 4
R1L := 4
R1H := 5
R2  := 6
R2L := 6
R2H := 7
R3  := 8
R3L := 8
R3H := 9
R4  := $0A
R4L := $0A
R4H := $0B
R5  := $0C
R5L := $0C
R5H := $0D
R6L := $0E
R6H := $0F
R7  := $10
R7L := $10
R7H := $11
R8  := $12
R8L := $12
R8H := $13

R14  := $1E
R14L := $1E
R14H := $1F
R15  := $20
R15L := $20
R15H := $21

Trampoline := $0400
Trampoline_JSR_Target := $040F
Trampoline_BANK_Target := $041B

VERA_LADDR := $9F20
VERA_ADDRL := VERA_LADDR
VERA_MADDR := $9F21
VERA_ADDRM := VERA_MADDR
VERA_HADDR := $9F22
VERA_ADDRH := VERA_HADDR
VERA_DATA0 := $9F23
VERA_DATA1 := $9F24
 VERA_CTRL := $9F25
 VERA_ISR  := $9F27
AUDIO_CTRL := $9F3B
AUDIO_FIFO := $9F3D
VERA_AUDIORATE := $9F3C
AUDIO_RATE := VERA_AUDIORATE

 .macro SETUP_FX_CLEAR
   stz VERA_CTRL
 .endmacro

L0_CONFIG := $9F2D
L0_TILEBASE := $9F2F
L0_HSCROLL_H := $9F31
PAL_OFFSET := L0_HSCROLL_H

CLOSE := $FFC3
OPEN := $FFC0
SETLFS := $FFBA
SETNAM := $FFBD
CHKIN := $FFC6
CLRCHN := $FFCC
MACPTR := $FF44
GETIN := $FFE4
READST := $FFB7
kbdbuf_peek := $FEBD

   
       PAL_ADDR1 := $24
       PAL_ADDR2 := $25
       PAL_ADDR3 := $26
 DO_BUFFER_AUDIO := $27
         G_WIDTH := $28
      PAL_LOBYTE := $29
       G_PALSIZE := $2A
          palptr := $2B
       LOOPS_255 := $2C
       BYTES_REM := $2D

       page_flag := $2E
       loop_ctr2 := $2F
       loop_ctr1 := $30
       loop_ctr3 := $31
        PlayDone := $32
      LOCK_KEYS  := $33

FRAME_CURRENT := $34  ; 24 bit
                ; $35
                ; $36
FRAME_TARGET := $37  ; 24 bit
                ; $38
                ; $39

          ; free $3A-$3B
 AUD_SECTOR_ADDER := $3C
 VID_SECTOR_ADDER := $3D

VID_SECTOR_CURRENT := $3E ; 32 bit
                    ;$3F
                    ;$40
                    ;$41

AUD_SECTOR_START := $42 ; 32 bit
                    ;$43
                    ;$44
                    ;$45

 AUD_SECTOR_CURRENT := $46 ; 32 bit
                   ;$47
                   ;$48
                   ;$49

VID_SECTOR_START := $4A
                   ;4B
                   ;4C
                   ;4D

AUD_FRAME_NUMSECTORS := $4E
VID_FRAME_NUMSECTORS := $4F
        COPYDOWN_PAL := $50
           KEY_EXTRA := $52
       VERA_RATEBYTE := $55
        VERA_CFGBYTE := $54


 AUD_LEAD_START := $0469
    drivenumber := $043C

; These values are read directly from the SPV Header
; Which is always loaded at $500
           VHDR_VRATE := $512
       VHDR_XAUD_FLAG := $515
       VHDR_XAUD_XCFG := $516
        DO_LOOP_VIDEO := $58F
         LOOP_PLAY_ON := $436
              PCM_EOF := $491

  Audio_Volume := $520
       MANEXIT := $465
     LOOP_FLAG := $436
                ;$38
                ;$39


; ---- High bandwidth sprite results (written by SETSPRITEREAD_SPI, read by VIDKIT-B2) and SPV header bytes ----
; Names match the Prog8 names (VideoHeader.X -> VideoHeader_X)
                   HB_MID1 := $0497
                  HB_BANK1 := $0498
                   HB_MID2 := $0499
                  HB_BANK2 := $049A
                 HB_NUMSPR := $049B
              HB_HIDE_TEXT := $049C
           VideoHeader_BPP := $0505
   VideoHeader_SpriteWidth := $0507
  VideoHeader_SpriteHeight := $0508
    VideoHeader_FrameWidth := $0509   ; 16 bit
   VideoHeader_FrameHeight := $050B   ; 16 bit
           VID_HAS_PALETTE := $042C
        IS_SUPPORTED_VIDEO := $0425
