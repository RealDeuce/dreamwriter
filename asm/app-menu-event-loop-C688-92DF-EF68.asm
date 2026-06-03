; Generated from disasm: C688:92DF-EF68
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x92DF


inline_key_dispatch_C688_92DF:
; file 0x4FB5F
    call C688:EE8C

inline_key_dispatch_body_C688_92E2:
    mov  bp,sp
    xchg [bp+0],si      ; swap caller return address with SI
    push dx
    mov  dl,al
    mov  al,[cs:si]
    inc  si
    cmp  al,0
    jz   C688:9301
    cmp  al,0xff
    jz   C688:92FE
    cmp  al,dl
    jz   C688:92FE
    inc  si
    inc  si
    jmp  C688:92EA
    mov  si,[cs:si]
    pop  dx
    mov  bp,sp
    xchg [bp+0],si      ; ret lands at selected target
    mov  al,[0x794a]
    ret
root_app_menu_event_loop_C688_EC9F:
; file 0x5551F
    call C688:77DD
    mov  al,0xff
    mov  [0x75e4],al

loop_refresh_and_poll_C688_ECA7:
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
    call C688:92DF
wp_top_menu_default_C688_EB15:
; file 0x55395
    call C688:77AA
    xor  al,al
    mov  [0x7520],al
    push es
    call DC98:2807
    pop  es
    or   al,al
    jz   C688:EB2B
    jmp  C688:EF45
    jmp  C688:EC9F
organizer_then_wp_menu_C688_EF45:
; file 0x557C5
    push es
    call DC98:53C3
    pop  es
    jmp  C688:EB15
organizer_menu_event_C688_EF4F:
; file 0x557CF
    push es
    call DC98:53C3
    pop  es
    jmp  C688:EC9F
dc98_menu_helper_event_C688_EF59:
; file 0x557D9
    push es
    call DC98:4D08
    cmp  ax,0xffff
    jz   C688:EF67
    mov  [0x7884],al
    pop  es
    jmp  C688:EC9F
cancel_or_escape_event_C688_ECF6:
; file 0x55576
    test byte [0x8e3f],0x01
    jz   C688:ED04
    and  byte [0x8e3f],0xfe
    jmp  C688:ECA7
    call C688:622B
    call C688:0B11
    call C688:44C4
    mov  al,0x02
    call C688:77A3
    jmp  C688:EB15
no_event_dispatch_C688_ED84:
; file 0x55604
    mov  al,[0x79a6]
    call C688:92E2
    mov  cl,0xf8
    call C688:EEFE
    jc   C688:EDCB
...
    mov  si,0x0042
    call C688:96EA
    jmp  C688:EDB9
...
    call C688:8610
    call C688:5B90
...
    call C688:44C4
    mov  al,[0x79c1]
    mov  [0x75e4],al
    call C688:77DD
    jmp  C688:ECA7
    mov  si,0x0057
    jmp  C688:EDC1
    call C688:EE98
    mov  si,0x0058
    call C688:EE84
