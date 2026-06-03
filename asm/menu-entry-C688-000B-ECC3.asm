; Generated from disasm: C688:000B-ECC3
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x000B


; cold path from C000:011A
    call C688:29D9
    retf

; warm path from C000:015C
    call C688:7752
    retf
; file 0x468D3
    mov  si,0x009d      ; expected bytes in CS
    mov  di,0x6800      ; retained RAM signature
    mov  cx,0x0004
    mov  al,[cs:si]
    cmp  al,[di]
    jnz  C688:0073
    inc  si
    inc  di
    loop C688:005C
    mov  si,0xd005
    mov  al,[cs:si]
    cmp  al,[di]
    jnz  C688:007C
    clc
    retf

; mismatch path rewrites the expected signature and returns carry set
    mov  al,[cs:si]
    mov  [di],al
    inc  si
    inc  di
    loop C688:0073
    mov  si,0xd005
    mov  al,[cs:si]
    mov  [di],al
    stc
    retf
; file 0x49259
    mov  di,0x77b8
    mov  cx,0x7f29
    sub  cx,0x77b8
    xor  al,al
    push es
    mov  bp,ds
    mov  es,bp
    cld
    rep  stosb          ; clear 77B8..7F28
    pop  es
    mov  si,[cs:0x2a63]
    mov  [0x7671],si
    mov  byte [0x7673],0
    mov  byte [0x8e3f],0
    call C688:294B       ; WP editor heap RAM probe
    call C688:2D75
    mov  al,0x02
    mov  word [0x75ed],0x793b
    call C688:61DB
    call C688:0240       ; inline script interpreter
    mov  al,0xff
    mov  [0x781b],al
    mov  [0x7810],al
    mov  [0x7994],al
    mov  si,0x3030
    mov  [0x787e],si
    mov  al,0x08
    mov  [0x798f],al
    mov  al,0x03
    mov  si,0x0004
    call C688:9541       ; resource loader
    call C688:9DFB
    call C688:441A
    jmp  C688:7729
; file 0x4DFA9
    call C688:7766       ; boot/update sequence
    mov  si,0x0001
    call C688:76BF
    mov  di,0x7746
    push es
    mov  bp,0
    mov  es,bp
    cld
    rep  movsb
    pop  es
    xor  al,al
    mov  [0x7a4d],al
    mov  byte [0x787c],0x0c
    mov  word [0x787e],0x3030
    call C688:77AA

; warm entry lands here through C688:000F
    call C688:77B4
    cmp  al,0x02
    jz   C688:775C
    jmp  C688:EB15       ; shared default/menu loop path
    push es
    call DC98:53C3       ; organizer top menu
    pop  es
    jmp  C688:EB15
    mov  al,0x0a
    call C688:8F43
    mov  si,0x0003
    call C688:9541
    call C688:599C
    call C688:44C4
    mov  al,0x04
    call C688:77A3
    mov  al,0x09
    call C688:77A3
    mov  al,0x02
    call C688:77A3
    mov  al,0x03
    call C688:77A3
    mov  al,0x03
    call C688:77A3
    mov  al,0x03
    call C688:77A3
    mov  al,0x05
    call C688:77A3
    mov  al,0x00
    call C688:77A3
    call C688:96E1
    ret
; file 0x4E034
    mov  si,0xd133      ; first-menu script source
    mov  cx,0x007c
    call C688:77C1
    call C688:8312
    ret

    push ds
    mov  ax,0xc688
    mov  ds,ax
    mov  di,0x7f28
    push es
    mov  bp,0
    mov  es,bp
    cld
    rep  movsb
    pop  es
    pop  ds
    mov  [0x79e2],di
    call C688:6B8C       ; hand copied script to renderer
    ret
; file 0x4EB92
    call C688:2D26
    call C688:4848
    ret

    call C688:8926
    call C688:F140
    and  byte [0x8db4],0xf7
    mov  si,0x005a
    mov  ch,0x03
    call C688:EE9E
    call C688:85B4
    call C688:8617
    call C688:90EC
    jmp  C688:834F

; C688:8337..834E is table/data, not linear code.
; [75EF] is initialized to the first word-table entry below.

    mov  word [0x75ef],0x833b
    mov  si,0x005b
    pop  si
    pop  word [0x75ef]
    mov  al,[0x794a]
    cmp  al,0x03
    jz   C688:83D8
    cmp  al,0xda
    jz   C688:83DD
    cmp  al,0x13
    jz   C688:8399
    cmp  al,0x12
    jz   C688:8399
    jmp  C688:92A0
    jmp  C688:928D
    call C688:898A
    jmp  C688:8419

    mov  al,[0x794a]
    cmp  al,0xda
    jz   C688:83EC
    mov  word [0x75ef],0x8347
    jmp  C688:83AB

    mov  si,0x0053
    call C688:7689
    call C688:8610
    call C688:89F6
    jz   C688:8402
    call C688:5B7D
    call C688:86C9
    jmp  C688:8413
    mov  si,0x78d1
    mov  bx,[si]
    mov  [0x78f5],bx
    inc  si
    inc  si
    mov  bx,[si]
    mov  [0x78d9],bx
    call C688:44C4
    call C688:88FC
    jmp  C688:EC9F
; file 0x5551F
    call C688:77DD
    mov  al,0xff
    mov  [0x75e4],al
    call C688:7795
    call C688:F13A
    call C688:8F40
    call C688:12D6
    mov  [0x794a],al
    call C688:44C4
    mov  al,[0x794a]
    cmp  al,0xff
    jnz  C688:ECC3
    jmp  C688:ED84
    call C688:92DF       ; inline key dispatch
