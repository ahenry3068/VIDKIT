VideoHeader {
  &ubyte[4]          ID = $500
  &ubyte          VTYPE = $504
  &ubyte            BPP = $505
  &ubyte            FPS = $506
  &ubyte    SpriteWidth = $507
  &ubyte   SpriteHeight = $508
  &uword     FrameWidth = $509
  &uword    FrameHeight = $50B
  &uword    NumFramesLO = $50D
  &uword    NumFramesHI = $50F
  &ubyte          SHint = $511
  &ubyte       VERARate = $512
  &uword AudioFrameSize = $513
  &ubyte      XAUD_FLAG = $515
  &ubyte      XCFG_BYTE = $516
  &uword        X_F_FPS = $517
  &ubyte[7]       Extra = $519
  &float        AspectF = $51A   ; HINT "A": display aspect (width/height) as CBM float, = Extra[1..5]
 }
; $520 Next Free.  PCM Volume Var stored there !

WAVHeader {
   &ubyte[4]            RIFFID = $522
   &uword        WAVDATASIZExL = $526
   &uword        WAVDATASIZExH = $528
   &ubyte[4]             WAVID = $52A
   &ubyte[4]         SUBCHKID1 = $52E
   &uword        SUBCHK1SIZExL = $532
   &uword        SUBCHK1SIZExH = $534
   &uword         AUDIO_FORMAT = $536
   &uword       AUDIO_CHANNELS = $538
   &uword        SAMPLE_RATExL = $53A
   &uword        SAMPLE_RATExH = $53C
   &uword          BYTE_RATExL = $53E
   &uword          BYTE_RATExH = $540
   &uword          BLOCK_ALIGN = $542
   &uword          SAMPLE_BITS = $544
   &ubyte[4]         SUBCHKID2 = $546
   &uword        SUBCHK2SIZExL = $54A
   &uword        SUBCHK2SIZExH = $54C
}

ZCMHeader {
    &uword       lptr = $522   ; $FFFF identify's HUGE ZCM
    &ubyte    banknum = $524   ; for standard ZCM
    &uword  SizeLow32 = $524   ; for HUGE ZCM
    &ubyte  SizeLow24 = $525   ; for standard ZCM
    &uword   SizeHigh = $526   ; Multiply by 256 for Standard ZCM, Multiply by 65536 for HUGE ZCM
    &ubyte  ZCFG_BYTE = $528   ; LOW Nibble of ZCFG_BYTE is requested VOLUME and is masked out/ignored by this code
    &ubyte ZRATE_BYTE = $529   ; This and ZCFG are copied directly to the VERA PCM control registers (sans the Volume nibble)
}

VIDKIT {

&uword ORG_ISR = $041E
&uword CINV = $0314

%option merge
%asm {{
SET_PLAYDONE .macro
           lda #$FF
           sta $33
         .endmacro
     }}

; Mirroring the Video and Audio Header Variables
; as an Array variable for reading in with GETIN.
      &ubyte[32] vHeader = $500
 &ubyte[3] vHdrNUMFRAMES = $50D
           &ubyte Volume = $520

       &ubyte[8] zHeader = $522
      &ubyte[44] wHeader = $522
   &ubyte[44] AUD_Header = $522

&ubyte AUDIO_CTRL = $9F3B
const uword joystick_get = $FF56
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
      ubyte MYBANK

; will be set to $FF if Video is exited by the user
; in the Bank where the Video Engine code is located

; $22 to $33 are defined and used in the
; ca65 ENGINE code. !


&bool DO_BUFFER_AUDIO = $27
&ubyte G_WIDTH = $28

&ubyte PlayDone = $32
&bool LOCK_KEYS = $33

&ubyte[3] FRAME_CURRENT=$34
; $35 - $36
&ubyte[3] FRAME_TARGET=$37
; $38 - $39

&ubyte AUD_SECTOR_ADDER = $3C
&ubyte VID_SECTOR_ADDER = $3D

&ubyte[4] VID_SECTOR_CURRENT = $3E
&uword[2] @nosplit VID_SECTOR_CURRENTw = $3E

&ubyte[4] AUD_SECTOR_START = $42
&uword[2] @nosplit AUD_SECTOR_STARTw = $42

&ubyte[4] AUD_SECTOR_CURRENT = $46
&uword[2] @nosplit AUD_SECTOR_CURRENTw = $46

&ubyte[4] VID_SECTOR_START = $4A
&uword[2] @nosplit VID_SECTOR_STARTw = $4A

&ubyte AUD_FRAME_NUMSECTORS = $4E
&ubyte VID_FRAME_NUMSECTORS = $4F
&bool COPYDOWN_PAL = $50
&ubyte KEY_EXTRA = $52
&byte VERA_CFG_BYTE = $54

&ubyte STASHVEC = $03B2
&ubyte AUDIO_FIFO = $9F3D
&byte AUDIO_FIFOs = $9F3D
&ubyte VERA_AUDIORATE = $9F3C

extsub $0400 = Trampoline()
&uword Trampoline_JSR_Target =  $040F
&ubyte Trampoline_BANK_Target = $041B
; saveA at $041C --> Free After

; $041D
; $041E
; $041F

&bool LOOP_ON = $0421
&bool IS_VIDEO = $0422
&bool IS_BITMAP_VIDEO = $0423
&bool IS_SPRITE_VIDEO = $0424
&bool IS_SUPPORTED_VIDEO = $0425
&bool IS_STD_VIDEO = $0426
&bool IS_SPI_VIDEO = $0427
&bool AUDIO_TRACK_IN_SEPERATEFILE = $0428
&bool MAKE_WIDE_SCREEN = $0429
&bool IS_TALL_VIDEO = $042A
&bool K_TYPE = $042B  ; Hi bandwidth Bitmap "Tall"
&bool VID_HAS_PALETTE = $042C

&bool IS_PCM_ONLY = $042D
&bool IS_Z_FILE = $042E
&bool IS_WAV_FILE = $042F
&bool PCM_IS_STEREO = $0430
&bool PCM_IS_16BIT = $0431
&bool VID_FILE_FOUND = $0432
&bool PCM_FILE_FOUND = $0433
&bool PAL_FILE_FOUND = $0434
&bool READY_TO_PLAY = $0435
&bool LOOP_FLAG = $0436
&bool success = $0437

&ubyte SCR_SAVEMODE = $0438
&ubyte CHARSET_SAVE = $0439
&bool DISABLE_RESTORE = $043A

&ubyte  VERAcfgvar = $043B
&ubyte drivenumber = $043C

&float          F_FPS = $043D
&float       TRUE_FPS = $0442
&float          Frame = $0447
&float         BFrame = $044C
&float     VFRAME_MUL = $0451
&float AUDIOFRAME_MUL = $0456
&float VIDEOFILE_LEAD = $045B

     &long RESET_FRAME = $0460
     &ubyte[4]  RFRAME = $0460
      &bool  PAL_RESET = $0464
        &ubyte MANEXIT = $0465
       &bool KEEP_OPEN = $0466
 &bool NO_SCREENCHANGE = $0467
   &bool SCREEN_IS_SET = $0468
&ubyte[4] AUD_LEAD_START = $0469
 ; $46A-$46C

&float tmpf = $046D
&float tmpf2 = $0472
&float vk_FAC = $0477
&float PCM_BYTEsPerSecond = $047C
&float Video_START_SECTOR = $0481
&float Audio_START_SECTOR = $0486
&float audFilePosition = $048B
&ubyte SAVE_DC_VIDEO = $0490
&bool  PCM_EOF = $0491
&uword DefPAL_PTR = $0492
&ubyte PalBank = $0494
&ubyte HighRAMBank = $0495

&bool MANAGE_SCREEN = $0496
&bool HAS_ASPECT = $049D       ; VIDKIT 2.1: SHint=="A" (aspect float valid in VideoHeader.AspectF)


; FREE...

; $0497 - $049F
; $04A0 - $04AF
; $04B0 - $04BF
; $04C0 - $04CF
; $04D0 - $04DF
; $04E0 - $04EF
; $04F0 - $04FF


; WAV, ZCM & SPV File Headers
; $500
; $54C

ubyte VideoLFN = 4
ubyte AudioLFN = 6
uword tmpw
uword tmpw2


sub read4hex() -> uword {
    str hex = "0000"
    for cx16.r4L in 0 to 3 {
        hex[cx16.r4L] = cbm.CHRIN()
    }
    return conv.hex2uword(hex)
}

sub Peek24BitFloat(uword addr) -> float {
  return (@(addr) as ubyte) as float + ((peekw(addr+1) as uword) as float * 256.0)
}

sub GetFilePosition(ubyte Channel) -> float {
    my_f_tell(Channel)
    return (65536.0 * cx16.r1 as float) + cx16.r0 as float
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

sub f_seekL(ubyte channel, ubyte[] seekpos ) {
&ubyte[4] targ = $04 ; seek command at r0 to r2
    cx16.r0 = mkword(channel,'P')
    for cx16.r12L in 0 to 3 { targ[cx16.r12L] = seekpos[cx16.r12L]}
    %asm {{ jmp p8s_f_seek.p8l_doseek }}
}

sub f_seek(ubyte channel, float seekpos) {
        ; gets the (32 bits) position + file size of the opened read file channel
        cx16.r2 = floats.floor(seekpos/65536.0) as uword
        cx16.r1 = (seekpos - (cx16.r2 as float * 65536.0)) as uword
        cx16.r0 = mkword(channel,'P')   ; complete building the P command
doseek:
        cbm.SETNAM(6, &cx16.r0)
        cbm.SETLFS(15, drivenumber, 15)
        void cbm.OPEN()
        void cbm.CHKIN(15)        ; use #15 as input channel
        %asm {{
              jmp p8s_Flush15
            }}
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

sub CURFRAMEINT_TOFLOAT() {
    Frame = (FRAME_CURRENT[0] as float) + (256.0 * FRAME_CURRENT[1] as float) + (65536.0 * FRAME_CURRENT[2] as float)
}

sub CURFRAMEFLOAT_TOINT() {
    tmpf = floats.floor((Frame / 65536.0))
    FRAME_CURRENT[2] = tmpf as ubyte
    tmpw = ( Frame - (tmpf * 65536.0) ) as uword
    FRAME_CURRENT[1] = msb(tmpw)
    FRAME_CURRENT[0] = lsb(tmpw)
}

sub CURFRAME_ZERO() {
    Frame = 0
    FRAME_CURRENT[0] = 0
    FRAME_CURRENT[1] = 0
    FRAME_CURRENT[2] = 0
}

sub AdjustAudioPosition() {
  float Divisor = 1
  if PCM_IS_16BIT { Divisor = Divisor * 2 }
  if PCM_IS_STEREO { Divisor = Divisor * 2 }
  if Divisor > 1 { while (floats.floor(audFilePosition/Divisor) * Divisor) != audFilePosition { audFilePosition = audFilePosition + 1 } }
}



}
