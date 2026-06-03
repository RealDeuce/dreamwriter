; Generated from disasm: C688:EB46-EC9E
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0xEB46


wp_clear_text_wrapper_C688_EB46:
; file 0x553C6
    push cx
    push dx
    push si
    push di
    push bp
    mov  bp,0x0a4f
    mov  es,bp
    call C688:EC77
    pop  bp
    pop  di
    pop  si
    pop  dx
    pop  cx
    mov  al,[0x794a]
    mov  ah,0
    retf
wp_clear_text_worker_C688_EC77:
; file 0x554F7
    mov  si,0x0008
    call C688:EE84        ; display prompt/read key
    cmp  al,0x03
    jz   clear_text_return_C688_EC9E
    or   al,0x20
    cmp  al,'n'
    jz   clear_text_return_C688_EC9E
    call C688:EF81        ; AL |= 20h; compare 'y'
    jnz  C688:EC77
    call C688:7766        ; rebuild empty editor state
    xor  al,al
    mov  si,0x0009
    call C688:96EA        ; display confirmation + delay
    mov  si,0x8e00
    xor  al,al
    mov  [si],al
clear_text_return_C688_EC9E:
    ret
