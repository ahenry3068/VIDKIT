*=$0400
sta saveA
lda 0
pha 
lda banktarget
sta 0
lda saveA
jsr $FFFF
sta saveA
pla
sta 0
lda saveA
rts
banktarget:
.byte $FD
saveA:
.byte $FE
