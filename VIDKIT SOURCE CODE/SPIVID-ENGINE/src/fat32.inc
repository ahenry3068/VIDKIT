;.export sd_lfn_buffer,fat32_backup_working_dir_cluster,fat32_restore_working_dir_cluster

;;.export fat32_get_clusternr,sd_cluster_to_sector,fat32_cluster_tmp,fat32_current_cluster,fat32_get_files_init

;.export fat32_get_file,last_load_addres,file_is_app,fat32_load_file,fat32_get_path

;.export fat32_bin_cluster,fat32_working_dir_cluster,sd_ptr_tmp2

;.export fat32_open_file,fat32_last_state,fat32_close_file,fat32_read_byte
.macpack longbranch
.macro store_lfn_name_byte xx
.scope
    sta xx
    cmp #$FF
    beq keep_ff
        stz xx+1
        bra ready
    keep_ff:
        sta xx+1
    ready:
.endscope
.endmacro


SPI_CTRL = $9F3F
SPI_DATA = $9F3E

SD_CMD_READ_SECTOR = $51
SD_CMD_WRITE_SECTOR = $58

;SECTOR_BUFFER = $a000       ;512 bytes

;---------------------------------------------------------------------
sd_ptr = $40            ;assign zero page addresses to these 4 variable
sd_ptr_read = $42
sd_ptr_tmp = $44
sd_ptr_tmp2 = $46
;-----------------------------------------------------------------------
;.segment "ZEROPAGE"
;    sd_ptr: .RES 2
;    sd_ptr_read: .res 2
;    sd_ptr_tmp: .res 2
;    sd_ptr_tmp2: .res 2
;.segment "CODE"

sd_ptr_read_tmp:    .res 2

SECTOR_BUFFER:  .res 514    ;2 extra bytes!!!
spi_command:    .res 1
spi_args:       .res 4
spi_crc:        .res 1
sd_error:       .res 1

fat32_LBAstart: .res 4
fat32_BytesPerSec:  .res 2
fat32_SecPerClus:   .res 1
fat32_RsvdSecCnt:   .res 4
fat32_NumFATs:      .res 1
fat32_FATSz32:      .res 4
fat32_FirstDataSector:  .res 4
fat32_RootClus:  .res 4
fat32_current_cluster: .res 4
fat32_working_dir_cluster: .res 4
fat32_working_dir_sector:  .res 4
fat32_working_dir_sector_index: .res 1
fat32_return_filter: .res 1


fat32_last_first_cluster: .res 4
fat32_last_fat_sector: .res 4


fat32_compare_buffer: .res 255
fat32_eoc: .res 1
fat32_byte:  .res 1

sd_fat_offset:  .res 2


sd_cmd_tmp: .res 4

sd_sector_count:    .res 1
sd_last_sector: .res 4
sd_last_dirty:  .res 1

sd_lfn_buffer:  .res 255
sd_lfn_buffer_index:    .res 1
sd_lfn_buffer_end: .res 1


sd_is_lfn:      .res 1    
sd_lfn_buffer_index_last: .res 1
sd_tmp: .res 1
sd_tmp2: .res 1
sd_tmp3: .res 1






.segment "CODE"

start_cluster_offsets: .byte $1a,$1b,$14,$15

SD_PARTITION_TABLE = $01BE
SD_PARTITION_TYPE_OFFSET = $04

VBR_BytesPerSector = $0b
VBR_NumberOfFats = $10
VBR_SectorsPerCluster = $0d
VBR_ReservedSectors = $0e

VBR_SectorsPerFact = $24
VBR_RootCluster = $2c

file_not_found:
    sec
    
    rts
    
get_starting_sector:
    jsr fat32_get_clusternr
    bcs file_not_found
    copy32Bit fat32_last_first_cluster,fat32_current_cluster
    jsr sd_cluster_to_sector
    clc
    rts


    




;Gets first clusternr of file or directory
; - file/dirname is passed x/y (null terminated)
; - fat32_working_dir_cluster is filled with cluster of file list
; - result is written to ptr 
fat32_get_clusternr:
    stx sd_ptr_tmp
    sty sd_ptr_tmp+1
    
    
  ;  dbg32Bit fat32_working_dir_cluster
    copy32Bit fat32_working_dir_cluster,fat32_current_cluster
    lda #%00000000
    jsr fat32_get_files_init
    
    ;make all chars uppercase
    ldy #0
    :
        lda (sd_ptr_tmp),y
        jsr a_to_uppercase
        sta fat32_compare_buffer,y ;(sd_ptr_tmp),y
        iny
        cmp #0
        bne :-
    
    files_loop2:
        jsr fat32_get_file
        bcs end_of_list3

        


        
        ldx sd_lfn_buffer_index_last
        ;loop through all chars of filename
        ldy #0
        inloop2:
            lda fat32_compare_buffer,y ; (sd_ptr_tmp),y      ;file to find
            beq at_end_of_file_to_find
            lda sd_lfn_buffer,x     ;current file on disk
            jsr a_to_uppercase
            cmp fat32_compare_buffer,y ;(sd_ptr_tmp),y      ;file to find  
            bne files_loop2 ;no_match2
            iny
            inx
            bra inloop2
        ;all bytes matched, if y<sd_lfn_buffer_end then there is still no match
        at_end_of_file_to_find:
        txa
        cpx sd_lfn_buffer_end   ;file filename on disk is not yet done, we do not have match
        bne files_loop2 ;no_match2  
            ;revert pointer advancement
            
            jsr dec_sd_ptr_by_32

         ;   ldx #0
         ;   ldy #1
         ;   :
         ;       lda fat32_last_first_cluster-1,y
         ;       sta (ptr),y
         ;       iny
         ;       cpy #5
         ;       bne :-
            clc
        rts

    end_of_list3:
        sec ;no match
    rts


fat32_get_files_init:
    sta fat32_return_filter
    
   ; lda #(255-13)   ;lfn entries are stored backwards
    
    stz sd_lfn_buffer_index  
    dec sd_lfn_buffer_index
    stz sd_is_lfn

     
    stz sd_sector_count
    jsr sd_cluster_to_sector
    
    lda #<SECTOR_BUFFER
    sta sd_ptr_read
    lda #>SECTOR_BUFFER
    sta sd_ptr_read+1
    
    jsr sd_read_sector
    jsr set_sector_buffer_to_sd_ptr
    rts

goto_no_more_files: jmp no_more_files

;file is stored in (ptr)
goto_prep_next_file: jmp prep_next_file

fat32_get_file:

fat32_entry_offset_attrib  = $0b
fat32_entry_offset_size = $1c
fat32_entry_offset_timedate = $16

;date/time
;size

read_next_entry:
    lda fat32_eoc
    bne goto_no_more_files
    lda (sd_ptr)
    beq goto_no_more_files
    cmp #$E5    ;has been deleted
    beq goto_prep_next_file

    ldy #fat32_entry_offset_attrib ;attrib byte
    lda (sd_ptr),y
    cmp #$0f    ;is lfn
    bne file_is_sfn 
        ; we are going to read 13 bytes
        sec
        lda sd_lfn_buffer_index
        sbc #13
        pha
        tax
        read_lfn_entry $01,$0B
        read_lfn_entry $0E,$1A
        read_lfn_entry $1C,$20
        lda sd_lfn_buffer_index
        cmp #$FF
        bne not_first_entry
            stx sd_lfn_buffer_end
        not_first_entry:
        pla
        sta sd_lfn_buffer_index

        lda #1
        sta sd_is_lfn
        
    bra goto_prep_next_file
    file_is_sfn:
       ; sta (ptr)
        bit #$02        ;check if hidden flag is set, ifso: skip file
        bne goto_prep_next_file
        lda sd_is_lfn
        bne is_lfn      ;check if sfn is last entry of lfn chain
            ;copy filename from entry

            ;copy start cluster
            ldx #0
            :
                ldy start_cluster_offsets,x
                lda (sd_ptr),y 
                sta fat32_last_first_cluster,x
                inx
                cpx #4
                bne :- 
            
            stz sd_lfn_buffer_index
            ldy #0
            ldx #0
            lpzz:
                cpy #8
                bne no_dot_xx   
                    lda #'.'
                    sta sd_lfn_buffer,x
                    inx 
                    stx sd_tmp
                no_dot_xx:               
                cpy #11
                beq file_ended
                lda (sd_ptr),y
                iny
                cmp #' '
                beq lpzz ;next char
                sta sd_lfn_buffer,x
                inx
                bra lpzz

            
            file_ended:
            cpx sd_tmp
            bne no_dot_at_end
              dex
            no_dot_at_end:
            
            stx sd_lfn_buffer_end    


                
            
        is_lfn:
            ;sfn entry of LFN
            ;copy filename to user output

     
            
            ;copy start cluster
            ldx #0
            :
                ldy start_cluster_offsets,x
                lda (sd_ptr),y 
                sta fat32_last_first_cluster,x
                inx
                cpx #4
                bne :- 

                              
            lda sd_lfn_buffer_index
            sta sd_lfn_buffer_index_last
       

            stz sd_lfn_buffer_index  
            dec sd_lfn_buffer_index
            stz sd_is_lfn

            jsr fat32_advance_file_list_pointer

            clc
    
            rts

    prep_next_file:

    jsr fat32_advance_file_list_pointer
    jmp read_next_entry


a_to_uppercase:
    cmp #$61
    bcc not_in_range2        
    cmp #$7B
    bcs not_in_range2        
    sec                    
    sbc #$20              
    not_in_range2:
    rts
    
fat32_advance_file_list_pointer:
    stz fat32_eoc
    jsr inc_sd_ptr_by_32
    
    lda sd_ptr
    cmp #<(SECTOR_BUFFER + 512)
    bne not_at_end_of_sector
    lda sd_ptr+1
    cmp #>(SECTOR_BUFFER + 512)
    bne not_at_end_of_sector
    
    ;at and of sector
    jsr fat32_read_next_in_chain
    bcs at_end_of_chain
   
   
    jsr set_sector_buffer_to_sd_ptr
    ;let sec/cls bubble through
    rts

    not_at_end_of_sector:
    clc
    rts
    at_end_of_chain:


    jsr set_sector_buffer_to_sd_ptr
    lda #0      ;make sure the next itaraion reads a zero
    sta (sd_ptr) 
    inc fat32_eoc
    rts
    
no_more_files:
    sec
    rts

fat32_check_eoc:
    lda fat32_current_cluster+3  
    cmp #$0F   
    bne NotEOC

    lda fat32_current_cluster+2
    cmp #$FF                  
    bne NotEOC

    lda fat32_current_cluster+1  
    cmp #$FF        
    bne NotEOC

    lda fat32_current_cluster  
    cmp #$F8                
    bcs IsEOC               

NotEOC:

    clc
    rts

IsEOC:

    sec
    rts
    
fat32_read_next_in_chain:
    inc sd_sector_count
    lda sd_sector_count
    cmp fat32_SecPerClus
    bne read_next_sector    ;read next sector in cluster
   
    
    jsr fat32_get_next_cluster_from_fat
    ;check if found cluster is and of chain marker
    jsr fat32_check_eoc
    bcc not_eoc
   
    
    sec     ;is end of chain
    rts
    
    not_eoc:
    stz sd_sector_count
    
    read_next_sector:
    
    jsr sd_cluster_to_sector
    jsr sd_read_sector
    clc
    rts


;read fat sector based on fat32_current_cluster + sd_sector_count
fat32_read_fat_sector:
    stz32Bit sd_cmd_tmp

    ;calculate fat1 sector + offset in sector
    lda fat32_current_cluster
    sta sd_cmd_tmp
    and #$7F        ;get remainder
    sta sd_fat_offset
    stz sd_fat_offset+1

    lda fat32_current_cluster+1
    sta sd_cmd_tmp+1
    lda fat32_current_cluster+2
    sta sd_cmd_tmp+2
    lda fat32_current_cluster+3
    sta sd_cmd_tmp+3
    
    ;time 4 as each entry is 4 bytes long
    asl sd_fat_offset
    rol sd_fat_offset+1
    asl sd_fat_offset
    rol sd_fat_offset+1
    
    ;divide by 128 (128 cluster allocations per sector) (quotient)
    LDX #7              ; 7 shifts
    ShiftLoop:
        lsr sd_cmd_tmp+3    
        ror sd_cmd_tmp+2   
        ror sd_cmd_tmp+1
        ror sd_cmd_tmp
        dex
        bne ShiftLoop    
    

    ;Add LBAStart
    adc32bit sd_cmd_tmp,fat32_LBAstart

    ;add reserved sector count
    adc32bit sd_cmd_tmp,fat32_RsvdSecCnt

    copy32Bit sd_cmd_tmp,spi_args
    ;shouldnt we convert cluster to sector??
    
    copy32Bit spi_args,fat32_last_fat_sector
    jsr sd_read_sector
    
    rts

;TODO: maybe reserver 512bytes for the fat sector so it can be read less times
fat32_get_next_cluster_from_fat:
    ;fat32_current_cluster holds currentcluster
    
    jsr fat32_read_fat_sector
    
    ;get next cluster from fat1
    clc
    lda #<SECTOR_BUFFER
    adc sd_fat_offset
    sta sd_ptr_read
    lda #>SECTOR_BUFFER
    adc sd_fat_offset+1
    sta sd_ptr_read+1

    ldy #0
    :
        lda (sd_ptr_read),y
        sta fat32_current_cluster,y
        iny
        cpy #4
        bne :- 

    rts

sd_read_boot_sector:
    stz32Bit fat32_LBAstart
    stz sd_sector_count
    jsr set_sector_buffer_to_sd_ptr
    
    stz $00    ;save to rambank 0
    stz32Bit spi_args       ;sector 0
    jsr sd_read_sector
 
    lda SECTOR_BUFFER+SD_PARTITION_TABLE+SD_PARTITION_TYPE_OFFSET
    cmp #$0b
    beq has_partition_table
    cmp #$0c
    beq has_partition_table
    bra handle_boot_sector
    
    has_partition_table:
    ldx #0
    :
        lda SECTOR_BUFFER+SD_PARTITION_TABLE+8,x
        sta fat32_LBAstart,x
        sta spi_args,x
        inx
        cpx #4
        bne :-
        jsr sd_read_sector
        
    handle_boot_sector:
    lda SECTOR_BUFFER+VBR_BytesPerSector
    sta fat32_BytesPerSec
    lda SECTOR_BUFFER+VBR_BytesPerSector+1
    sta fat32_BytesPerSec+1

    ;store Sectors per cluster
    lda SECTOR_BUFFER+VBR_SectorsPerCluster
    sta fat32_SecPerClus

    ;Store Reserverd Sector Count
    stz32Bit fat32_RsvdSecCnt
    lda SECTOR_BUFFER+VBR_ReservedSectors
    sta fat32_RsvdSecCnt
    lda SECTOR_BUFFER+VBR_ReservedSectors+1
    sta fat32_RsvdSecCnt+1  
 
    ;store Number of fats
    lda SECTOR_BUFFER+VBR_NumberOfFats
    sta fat32_NumFATs

    ;Store sectors per fat
    lda SECTOR_BUFFER+VBR_SectorsPerFact
    sta fat32_FATSz32
    lda SECTOR_BUFFER+VBR_SectorsPerFact+1
    sta fat32_FATSz32+1
    lda SECTOR_BUFFER+VBR_SectorsPerFact+2
    sta fat32_FATSz32+2
    lda SECTOR_BUFFER+VBR_SectorsPerFact+3
    sta fat32_FATSz32+3

    ;Store cluster number of the root directory. subtract 2 to get correct offset
    sec
    lda SECTOR_BUFFER+VBR_RootCluster
    sbc #2
    sta fat32_RootClus
    lda SECTOR_BUFFER+VBR_RootCluster+1
    sbc #0
    sta fat32_RootClus+1
    lda SECTOR_BUFFER+VBR_RootCluster+2
    sbc #0
    sta fat32_RootClus+2
    lda SECTOR_BUFFER+VBR_RootCluster+3
    sbc #0
    sta fat32_RootClus+3
    

  ;Calculate first data sector
        
    ;load fat size
    stz32Bit fat32_FirstDataSector

    lda fat32_RsvdSecCnt
    sta fat32_FirstDataSector
    lda fat32_RsvdSecCnt+1
    sta fat32_FirstDataSector+1

    ;add fat size per FAT, normaly 2 fats
    ldx fat32_NumFATs
    :
        adc32bit fat32_FirstDataSector,fat32_FATSz32
        dex
        bne :-

    ;now we have first data sector??
    ldx fat32_SecPerClus
    :
        adc32bit fat32_FirstDataSector,fat32_RootClus
        dex
        bne :-  
            
    adc32bit fat32_FirstDataSector,fat32_LBAstart
    
   
    stz32Bit fat32_working_dir_cluster
    lda #2
    sta fat32_working_dir_cluster       ;first cluster of root starts as cluster 2
    copy32Bit fat32_working_dir_cluster,fat32_current_cluster
    jsr sd_cluster_to_sector
    copy32Bit spi_args,fat32_working_dir_sector
    stz fat32_working_dir_sector_index

rts

;fat32_current_cluster holds clusternr
sd_cluster_to_sector:
    ;(sd_current_cluster * fat32_SecPerClus) + sd_data_offset
    stz32Bit spi_args
    
    ldx fat32_SecPerClus
    :
        adc32bit spi_args,fat32_current_cluster
        dex
        bne :-
    adc32bit spi_args,fat32_FirstDataSector

    ldx fat32_SecPerClus
        :
        sec
        lda spi_args
        sbc #2
        sta spi_args
        lda spi_args+1
        sbc #0
        sta spi_args+1
        lda spi_args+2
        sbc #0
        sta spi_args+2
        lda spi_args+3
        sbc #0
        sta spi_args+3
        dex
        bne :-
    
    
    ;add sd_sector_count
    clc
    lda spi_args
    adc sd_sector_count
    sta spi_args
    
    lda spi_args+1
    adc #0
    sta spi_args+1
    lda spi_args+2
    adc #0
    sta spi_args+2
    lda spi_args+3
    adc #0
    sta spi_args+3
    rts



sector_already_in_buffer: rts

sd_read_sector:
   ; lda #':'
   ; jsr dbg_char
   ; dbg32Bit spi_args
   ; jsr dbg_lf
    cmp32Bit sd_last_sector,spi_args
    beq sector_already_in_buffer

      
    
    
    copy32Bit spi_args,sd_last_sector
  
    
    
    jsr sd_select
   
    lda #<SECTOR_BUFFER
    sta sd_ptr_read
    lda #>SECTOR_BUFFER
    sta sd_ptr_read+1
    
    lda #SD_CMD_READ_SECTOR
    sta spi_command
    jsr send_sd_cmd

	lda SPI_CTRL;
	ora #$04    ;set bit 5 AutoTX
	sta SPI_CTRL

    ;expecting 512 bytes
    :
 	lda SPI_DATA    ;init first transfer
  ;  jsr dbg
    nop ;give spi time to send and receive a byte
    nop    
    cmp #$FE
    bne :-
    ;lda SPI_DATA     ;Expect $00
    ;lda SPI_DATA     ;Expect $00
    ;we can unroll this even further to increase performance
    ;read 512 bytes
    ldx #2
    lpx:
        ldy #0
        :
            lda SPI_DATA
            sta (sd_ptr_read),y  
            iny
            bne :- 
        inc sd_ptr_read+1
        dex
        bne :-
    jsr sd_deselect
    ;disable autotx
    lda SPI_CTRL
    AND #%11111001
    sta SPI_CTRL
    rts

sd_card_not_responding:
    lda #$FF
    sta sd_error
    jsr dbg
    rts

init_sd_card:
    stz sd_last_dirty

    lda #$FF
    sta sd_last_sector
    sta sd_last_sector+1
    sta sd_last_sector+2
    sta sd_last_sector+3
    
    stz sd_error
   ;To initialize an sd-card we need to:
    ; - Set slow clock
    ; - Send 10x $FF with ChipSelect=High -> for spi: results in last bit unset
    ; - Send CMD0 (Go idle state) $40 $00 $00 $00 $00 $FF (last crc check)
    ; - Wait for response $01, meaning: card is in idle state
    
    
    ;slow clock and enable SD
    lda #%00000010
    sta SPI_CTRL
    
    ;pass about 80us, sending $FF with CS=high
    lda #$FF
    ldx #10
    :
        sta SPI_DATA
        jsr wait_spi
        dex
        bne :-

    lda #%00000011     ; bit1 = slow, bit0 = 1 → CS low (asserted)
    sta SPI_CTRL

    ;Clear command    
    stz spi_args
    stz spi_args+1
    stz spi_args+2
    stz spi_args+3
        
    lda #$40        ;CMD0 SD_CMD_GO_IDLE_STATE
    sta spi_command
    jsr send_sd_cmd
    bcs sd_card_not_responding
    ;Result should be $01 meaning the sd card is in idle state
    cmp #$01
    beq sd_card_is_in_idle_state
        lda #1  
        jsr raise_error
    sd_card_is_in_idle_state:

    ;Check SD-card version:
    lda #$48        ;CMD8   SEND_IF_COND
    sta spi_command
    lda #$AA
    sta spi_args
    lda #$01
    sta spi_args+1
    jsr send_sd_cmd
    cmp #$01
    beq sd_card_is_supported
        lda #2  ;sd-card is old, not supported
        jsr raise_error
    sd_card_is_supported:
 
    ;expecting 4 more bytes, returning the args send    
    jsr read_spi_byte
    jsr read_spi_byte
    jsr read_spi_byte
    jsr read_spi_byte
    
    
    ;zero out args that we used for CMD8
    stz spi_args
    stz spi_args+1

wait:
    lda #$77        ;CMD55  SD_SEND_OP_COND
    sta spi_command
    jsr send_sd_cmd
    
    cmp #$01
    beq all_ok
    cmp #$00
    beq all_ok
        lda #3  ;not sure what this error means
        jsr raise_error
    all_ok:
    
    lda #$69    ;ACMD41
    sta spi_command
    jsr send_sd_cmd

    cmp #0  ;keep doing this until response =0, meaning SD-card is ready
    bne wait

    ;disable slow clock
    lda SPI_CTRL
    and #%11111100
    sta SPI_CTRL 
    rts
    



send_sd_cmd:
    ;unroled for maximum performance
    lda spi_command
    sta SPI_DATA

    jsr wait_spi

    ;Send args in reverse order as sd-card expects big endian
    lda spi_args+3
    sta SPI_DATA
    jsr wait_spi

    lda spi_args+2
    sta SPI_DATA
    jsr wait_spi

    lda spi_args+1
    sta SPI_DATA
    jsr wait_spi    

    lda spi_args
    sta SPI_DATA
    jsr wait_spi

    lda spi_crc ;#$FF    ;dummy crc
    sta SPI_DATA
    jsr wait_spi
    
    jsr wait_response
    
    rts

read_spi_byte:
    lda #$FF
    sta SPI_DATA
    jsr wait_spi
    lda SPI_DATA
    rts
    
spi_transfer:
    sta SPI_DATA
    jsr wait_spi
  ;  lda SPI_DATA
    rts
;we can do this inline to prevent jsr/rts for performance (use macro)
wait_spi:
    bit SPI_CTRL   ;  update gflags
    bmi wait_spi    ; if bit 7 is set, keep looping
    rts

wait_response:
    ldx #0
wait_response_loop:
    inx
    beq spi_time_out
    lda #$FF
    sta SPI_DATA
    jsr wait_spi
    lda SPI_DATA
   ; jsr dbg
    cmp #$FF
    beq wait_response_loop

    clc
    rts
spi_time_out:
    sec
    rts

fat32_is_root_cluster:
    lda fat32_current_cluster+1
    ora fat32_current_cluster+2
    ora fat32_current_cluster+3
    bne :+
    lda fat32_current_cluster
    cmp #2
    bne :+
    rts
    :

    rts


inc_sd_ptr_by_32:
    clc
    lda sd_ptr
    adc #32
    sta sd_ptr
    lda sd_ptr+1
    adc #0
    sta sd_ptr+1    

    rts

dec_sd_ptr_by_32:
    sec
    lda sd_ptr
    sbc #32
    sta sd_ptr
    lda sd_ptr+1
    sbc #0
    sta sd_ptr+1     

    rts

set_sector_buffer_to_sd_ptr:
    lda #<SECTOR_BUFFER
    sta sd_ptr
    lda #>SECTOR_BUFFER
    sta sd_ptr+1
    rts

raise_error:
    jsr dbg
    lda #$FF
    jsr dbg
    jsr dbg
    jsr dbg
    jsr dbg
    jmp hlt    
    
    
sd_select:
    lda SPI_CTRL
    ORA #%00000001
    sta SPI_CTRL 
    rts
    
sd_deselect:
    lda SPI_CTRL
    AND #%11111110
    sta SPI_CTRL
    rts



name_already_exists:
    ply
    plx
    sec
    rts
    
        
