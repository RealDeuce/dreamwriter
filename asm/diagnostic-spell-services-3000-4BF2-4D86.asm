; Generated from disasm: 3000:4BF2-4D86
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x4BF2


; file 0x34BF2
    call 3000:4CF4
    mov  sp,bp
    pop  bp
    ret

; file 0x34BFA
    call 3000:4D1A
    mov  sp,bp
    pop  bp
    ret
; file 0x34CF4
    mov  word [0x6bd4],0x6bd8
    mov  word [0x6bd6],0x9688
    jmp  3000:4D0D

    mov  bx,[0x6bd4]
    inc  word [0x6bd4]
    mov  byte [bx],0
    mov  ax,[0x6bd6]
    cmp  [0x6bd4],ax
    jc   3000:4D02
    sub  ax,ax
    ret
; file 0x34D1A
    call 3000:5016       ; candidate manager init
    or   ax,ax
    jz   3000:4D26
    mov  ax,0xffff
    ret

    mov  ax,0x84da
    push ax
    mov  ax,0x0108
    push ax
    call 3000:3646       ; initialize output record
    add  sp,4
    mov  word [0x8fee],0x84da
    push word [0x6004]
    call 3000:527C       ; rebuild selected slot pages
    add  sp,2
    call 3000:3AAC       ; validate engine buffer
    or   ax,ax
    jz   3000:4D66
    call 3000:4D6A
    call 3000:0037       ; INT 21h AX=4420 tone
    call 3000:0037
    call 3000:0037
    call 3000:0037
    call 3000:0037
    mov  word [0x6000],0
    jmp  3000:4D21

    sub  ax,ax
    ret
; file 0x34D6A
    call 3000:4F76
    mov  ax,0x6008
    push ax
    mov  ax,0x0bc4
    push ax
    call 3000:39E0
    add  sp,4
    call 3000:3A1E
    mov  word [0x6000],0
    sub  ax,ax
    ret
