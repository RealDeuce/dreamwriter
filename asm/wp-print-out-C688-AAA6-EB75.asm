; Generated from disasm: C688:AAA6-EB75
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0xAAA6


wp_print_out_wrapper_C688_EB5E:
; file 0x553DE
    push cx
    push dx
    push si
    push di
    push bp
    mov  bp,0x0a4f
    mov  es,bp
    call C688:AAA6
    pop  bp
    pop  di
    pop  si
    pop  dx
    pop  cx
    mov  al,[0x794a]
    mov  ah,0
    retf
wp_print_out_flow_C688_AAA6:
; file 0x51326
    mov  word [0x7813],0x0001
    mov  word [0x7815],0x03e7
    mov  word [0x790f],0x0001
    and  byte [0x8db3],0x7d
    or   byte [0x8db3],0x01
    call C688:8610
    call C688:4F63
    lahf
    push ax
    call C688:44C4
    pop  ax
    sahf
    jnc  print_range_screen_C688_AAE0
    mov  si,0x0035
    call C688:EE84
    cmp  al,0x0b
    jz   print_out_return_C688_AADF
    cmp  al,0x03
    jnz  C688:AAD1
print_out_return_C688_AADF:
    ret
print_range_screen_C688_AAE0:
    call C688:F140
    mov  si,0x000a
    mov  ch,0x03
    call C688:EE9E
    mov  word [0x75ef],0xaa96
...
    cmp  byte [0x794a],0x13
    jnz  C688:AB1D
    add  word [0x75ef],byte +0x02
    jmp  C688:928D
    cmp  byte [0x794a],0xda
    jnz  C688:AB1A
    mov  si,0x000d
    call C688:7689
    call C688:AB37
    cmp  al,'Y'
    jnz  C688:AB34
    jmp  C688:AC99
    jmp  C688:AAA6
print_confirmed_C688_AC99:
; file 0x51519
    call C688:90EC
    call C688:69BC
    call C688:ACAF
    call C688:10A4
    mov  si,0x001a
    mov  ch,0x02
    call C688:EE9E
    jmp  C688:AD05

set_print_active_C688_ACAF:
    mov  word [0x7817],0x0001
    mov  si,0x77f1
    or   byte [si],0x01
    ret
print_merge_side_entry_C688_ACBC:
; file 0x5153C
    call C688:8610
    call C688:4F63
    lahf
    push ax
    call C688:44C4
    pop  ax
    sahf
    jnc  C688:ACDA
    mov  si,0x0035
    call C688:EE84
    cmp  al,0x0b
    jz   C688:ACD9
    cmp  al,0x03
    jnz  C688:ACCB
    ret
print_output_loop_C688_AD05:
    mov  si,0x001c
    call C688:7689
    call C688:AD39
    mov  si,0x77f1
    test byte [si],0x80
    jnz  C688:AD05
    jmp  C688:AD18

print_output_helper_C688_AD39:
    mov  cl,0x01
    call C688:9461
    call C688:930B
    call C688:779A
    call C688:93B5
    ret
