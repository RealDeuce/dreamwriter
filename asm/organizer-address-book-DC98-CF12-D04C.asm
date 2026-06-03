; Generated from disasm: DC98:CF12-D04C
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0xCF12


; file 0x69892
    push bp
    sub  sp,0x0408
    call DC98:0E70
    call DC98:2887
    mov  ax,0x000a
    mov  bx,0xf17b
    mov  cx,0x0012
    call C000:67AD       ; "*** WAIT ***"
    lea  ax,[bp-0x320]
    mov  [0x82b0],ax     ; dword offset table
    lea  ax,[bp-0x3e8]
    mov  [0x82b2],ax     ; one-byte name cache
    mov  cx,0x0006
    mov  dx,0xf1c5       ; ADDRESS header
    mov  bx,0x00c8       ; 200 slots
    call DC98:BB4F        ; create ODB
...
    mov  ax,0x0006
    mov  bx,0xf1c5       ; ADDRESS header
    mov  cx,0x00c8
    call DC98:BA42        ; validate/read index
    call DC98:B9F2        ; load first-byte cache
    call DC98:CB04        ; foreground UI
; file 0x68372
...
DC98:B9F9  mov  ax,[0x82a8]
DC98:BA02  add  bx,[0x82b0]
DC98:BA0D  call DC98:EE72       ; seek to record offset
DC98:BA15  mov  bx,[0x82b2]
DC98:BA1E  call DC98:EE08       ; read one byte
...
DC98:BA35  mov  byte [bx],0     ; clear remaining cache slots
; file 0x68CB4
DC98:C351  mov  ax,0xf1b4
DC98:C356  mov  al,[es:bx+0x0008] ; map proposed name byte
...
DC98:C373  mov  bx,[0x82b2]
DC98:C37D  mov  al,[es:bx+0x0008] ; map cached first byte
DC98:C382  cmp  al,[bp-0x29]
...
DC98:C397  call DC98:BF47        ; extract stored NAME
DC98:C3BA  call DC98:C30F        ; mapped string compare
; file 0x68704
...
DC98:BDAC  shl  cx,1
DC98:BDB2  add  cx,0x000c       ; y = row * 8 + 0x0c
DC98:BDC9  mov  word [bx],0x0008
DC98:BDD4  mov  word [bx],0x0107 ; clear row rectangle
...
DC98:BE2C  mov  si,[di]         ; NAME
DC98:BE44  cmp  dx,0x18         ; max 24 visible chars
...
DC98:BE78  mov  si,[di+0x04]    ; TEL
DC98:BE91  cmp  cx,0x10         ; max 16 visible chars
