; Generated from disasm: C000:0F70-15EE
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0F70


; file 0x40F70
    mov  ax,0x157d
    mov  di,0x0004       ; IVT vector 01h
    stosw
    mov  ax,0xc000
    stosw
diagnostic_int1_C000_157D:
; file 0x4157D
    push ds
    push bp
    push bx
    mov  bp,sp
    mov  bx,0
    mov  ds,bx
    test byte [0x6ec0],0x80
    jnz  int1_active_C000_15CB
    mov  bx,[0x6ebc]
    cmp  bx,[bp+0x06]    ; saved IP
    jnz  int1_return_C000_15C7
    mov  bx,[0x6ebe]
    cmp  bx,[bp+0x08]    ; saved CS
    jnz  int1_return_C000_15C7
    cmp  byte [0x6ec0],0x01
    jnz  int1_chain_f8_C000_15AE
    or   byte [0x6ec0],0x80
    jmp  int1_active_C000_15CB
int1_chain_f8_C000_15AE:
    and  word [bp+0x0a],0xfeff ; clear TF
    push ax
    mov  bx,0x0028
    call C000:099C
    pop  ax
    pop  bx
    pop  bp
    pop  ds
    jmp  far [0x03e0]    ; chain to installed F8h

int1_clear_tf_C000_15C2:
    and  word [bp+0x0a],0xfeff

int1_return_C000_15C7:
    pop  bx
    pop  bp
    pop  ds
    iret
int1_active_C000_15CB:
    inc  byte [0x6ec0]
    jz   int1_clear_tf_C000_15C2
    push ax
    mov  bx,0x0028
    call C000:099C
    mov  ax,0x1388
    dec  ax
    jnz  C000:15DB
    call C000:09A9
    mov  bx,0x0080
    mov  ax,0x04b0
    dec  ax
    jnz  C000:15E7
    dec  bx
    jnz  C000:15E4
    pop  ax
    jmp  int1_return_C000_15C7
