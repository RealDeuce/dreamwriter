; Generated from disasm: 3000:4AA6-5135
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x4AA6


; helper call targets covered by later slices
candidate_state_init_C3000_66D4equ 0x66D4
candidate_result_list_build_C3000_673Aequ 0x673A
candidate_copy_primary_field_C3000_677Aequ 0x677A
candidate_next_C3000_685E      equ 0x685E
related_word_next_C3000_6892   equ 0x6892

banked_linguistic_dispatch_C3000_4AA6:
; file 0x34AA6
    push bp
    mov  bp,sp
    sub  sp,byte +0x2
    mov  word [0x6bd8],0
    mov  ax,[bp+0x4]
    cmp  ax,0x59
    jna  loc_4ABD
    jmp  loc_4C02
loc_4ABD:
    add  ax,ax
    xchg ax,bx
    jmp  [cs:bx+0x4c0a]
service_query_active_slot_C3000_4B80:
; file 0x34B80
    mov  ax,[0x6004]
    inc  ax
    jmp  loc_4CBE

service_select_slot0_C3000_4B88:
    sub  ax,ax
loc_4B8A:
    push ax
    call 0x527c
    jmp  loc_4B03

service_select_slot1_C3000_4B92:
    mov  ax,0x1
    jmp  loc_4B8A

service_reset_parser_C3000_4B98:
    call loc_4F38
    jmp  loc_4CBE

service_grammar_word_C3000_4BA4:
    push word [bp+0x6]
    call loc_4F44
    jmp  loc_4B03
service_selected_result_C3000_4BCA:
; file 0x34BCA
    mov  ax,[bp+0x4]
    sub  ax,0x3c
    mov  [bp-0x2],ax
    push ax
    push word [bp+0x6]
    call selected_result_expand_C3000_5026
    jmp  loc_4AE2

service_result_count_C3000_4BDE:
    push word [bp+0x6]
    call result_count_C3000_50C4
    jmp  loc_4B03

service_result_row_C3000_4BE8:
    push word [bp+0x6]
    call result_row_C3000_50F4
    jmp  loc_4B03
candidate_manager_init_C3000_5016:
; file 0x35016
    call candidate_state_init_C3000_66D4
    or   ax,ax
    jnl  loc_5022
    mov  ax,0xffff
    ret
loc_5022:
    sub  ax,ax
    ret

selected_result_expand_C3000_5026:
    push bp
    mov  bp,sp
    sub  sp,byte +0x6
    push si
    dec  word [bp+0x6]
    call candidate_next_C3000_685E
    mov  word [bp-0x4],0
...
    mov  ax,0x9366
    push ax
    call related_word_next_C3000_6892
    add  sp,byte +0x2
    or   ax,ax
    jnl  loc_506C
    mov  bx,[bp+0x4]
    mov  byte [bx],0
    sub  ax,ax
    pop  si
    mov  sp,bp
    pop  bp
    ret
result_count_C3000_50C4:
; file 0x350C4
    push bp
    mov  bp,sp
    mov  word [0x8f24],0
    push word [bp+0x4]
    call candidate_result_list_build_C3000_673A
    add  sp,byte +0x2
    mov  [0x8454],ax
    or   ax,ax
    jnl  loc_50E2
    mov  ax,0xffff
    pop  bp
    ret
loc_50E2:
    cmp  word [0x8454],byte +0x9
    jng  loc_50EF
    mov  word [0x8454],0x9
loc_50EF:
    mov  ax,[0x8454]
    pop  bp
    ret
result_row_C3000_50F4:
; file 0x350F4
    push bp
    mov  bp,sp
    sub  sp,byte +0x4
    push si
    mov  ax,[0x8454]
    cmp  [0x8f24],ax
    jl   loc_510C
    mov  ax,0xffff
    pop  si
    mov  sp,bp
    pop  bp
    ret
loc_510C:
    mov  bx,[bp+0x4]
    inc  word [bp+0x4]
    mov  al,[0x8f24]
    add  al,0x31
    mov  [bx],al
    mov  bx,[bp+0x4]
    inc  word [bp+0x4]
    mov  byte [bx],0x29
    mov  bx,[bp+0x4]
    inc  word [bp+0x4]
    mov  byte [bx],0x20
    mov  word [0x8eee],0x9366
    mov  ax,0x9366
    push ax
    call candidate_copy_primary_field_C3000_677A
translate_caller_text_C3000_4FDA:
; file 0x34FDA
    push bp
    mov  bp,sp
    sub  sp,byte +0x4
    push si
    mov  word [bp-0x2],0x8f00
    jmp  loc_4FFE
loc_4FE8:
    mov  bx,[bp-0x2]
    mov  si,[bp-0x4]
    and  si,0xff
    mov  al,[si+0x1504]
    mov  [bx],al
    inc  word [bp+0x4]
    inc  word [bp-0x2]
loc_4FFE:
    mov  bx,[bp+0x4]
    mov  al,[bx]
    mov  [bp-0x4],al
    or   al,al
    jnz  loc_4FE8
    mov  bx,[bp-0x2]
    mov  byte [bx],0
    pop  si
    mov  sp,bp
    pop  bp
    ret
