  SPI_DATA := $9F3E
  SPI_CTRL := $9F3F
     CMD18 := ($40 | 18)


 .macro sdsector_to target
  .local loop
     ldx #4
loop:
     .repeat 128
        lda SPI_DATA
        sta target
     .endrepeat
     dex
     jne loop
   .endmacro

   .macro sdsector_toVram
      sdsector_to VERA_DATA0
   .endmacro

   .macro sdsector_toAudioFIFO
      sdsector_to AUDIO_FIFO
   .endmacro


      .macro spi_read
      .local waitbit
         lda #$FF
         sta SPI_DATA
waitbit: bit SPI_CTRL
         bmi waitbit
         lda SPI_DATA
      .endmacro

      .macro spi_write target
      .local waitbit
         lda target
         sta SPI_DATA
waitbit: bit SPI_CTRL
         bmi waitbit
      .endmacro

        .macro spi_waitready
      .local done
      .local timeout
      .local wr_end
         sec
-:       ldx #0
--:      ldy #0
---:
         spi_read
         cmp #$FF
         beq done
         dey
         bne ---
         dex
         bne --
         bcc timeout
         clc
         bra -
done:  sec
timeout:
      .endmacro



    .macro spi_select
      .local error
      .local s_end
	    lda #$01 ; Select. Not auto-TX.
	    sta SPI_CTRL
        spi_read
	    spi_waitready
	    bcc error
	    bra s_end
error:
	spi_deselect
	clc
s_end:
      .endmacro



      .macro spi_deselect
         stz SPI_CTRL
         spi_read
      .endmacro

      .macro Set_AutoTX
         lda #$05
         sta SPI_CTRL
         lda SPI_DATA
         nop
      .endmacro


     .macro sdcard_sendcmd cmdbyte, sectorAddr
     .local sc_error, endcmd, wait_response
        spi_deselect
        spi_select
        bcc sc_error
        spi_write cmdbyte
        spi_write sectorAddr + 3
        spi_write sectorAddr + 2
        spi_write sectorAddr + 1
        spi_write sectorAddr
        spi_write #1
        ldy #(10+1)
wait_response:
        dey
        beq sc_error
        spi_read
        bit #$80
        bne wait_response
        sec
        bra endcmd
sc_error:
     clc
endcmd:
     .endmacro

    .macro StartMULTI_BLK TargetSector
            sdcard_sendcmd #CMD18, TargetSector
            Set_AutoTX
    .endmacro


; General purpose MACROs for manipulating 32 & 24 bit values.


.macro inc24 target
     .local doneinc
          inc target
          bne doneinc
          inc target+1
          bne doneinc
          inc target+2
doneinc:
     .endmacro

     .macro inc32 target
     .local doneinc
          inc24 target
          bne doneinc
          inc target+3
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

      .macro ld24 target
          lda target
          ldx target+1
          ldy target+2
      .endmacro

      .macro st24 target
         sta target
         stx target+1
         sty target+2
      .endmacro

      .macro ph32 target
          lda target+3
          pha
          ld24 target
          pha
          phy
          phx
      .endmacro

      .macro pl32 target
         plx
         ply
         pla
         st24 target
         pla
         sta target+3
      .endmacro
