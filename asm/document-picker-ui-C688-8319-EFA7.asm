; Generated from disasm: C688:8319-EFA7
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x8319


first_menu_reentry_C688_8319:
; file 0x4EB99
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
document_list_continuation_C688_8CFB:
; file 0x4F57B
    mov  al,[0x7520]
    or   al,al
    jz   C688:8D0C
    test al,0x02
    jnz  C688:8D09
    jmp  C688:8D7A
    jmp  C688:8DBF
    jmp  C688:EC9F
document_list_refresh_C688_8D72:
    mov  al,[0x7520]
    or   al,0x01
    mov  [0x7520],al

document_list_refresh_C688_8D7A:
    call C688:8F40
    call C688:5108
    call C688:44C4
    jmp  C688:EC9F
replace_search_prompt_root_C688_8D0F:
; file 0x4F58F
    mov  word [0x757d],0x8d0f
    mov  si,0x0038
    call C688:7689
    mov  si,0x0019
    call C688:7689
    jmp  C688:8D35

search_prompt_root_C688_8D23:
; file 0x4F5A3
    mov  word [0x757d],0x8d23
    mov  si,0x0038
    call C688:7689
    mov  si,0x0037
    call C688:7689
prompt_common_input_C688_8D35:
    xor  al,al
    mov  [0x7520],al
    mov  ch,0x06
    mov  cl,0x01
    mov  dx,0x7a30
    call C688:71C6       ; edit field at 7A30
    mov  si,0x7a30
    mov  cl,0x10
    call C688:93CE       ; trim trailing spaces to NUL
    and  byte [0x79ec],0xef
    mov  ch,0x10
    mov  si,0x7a30
    call C688:EF86       ; classify field
    jnc  C688:8D60
    or   byte [0x79ec],0x10
    call C688:92DF
prompt_default_restart_C688_8D6C:
    mov  si,[0x757d]
    jmp  si
replace_second_prompt_or_search_refresh_C688_8D86:
    cmp  word [0x757d],0x8d23
    jz   C688:8D72
    mov  si,0x0018
    call C688:7689
    xor  al,al
    mov  ch,0x06
    mov  cl,0x01
    mov  dx,0x7a1f
    call C688:71C6
    mov  si,0x7a1f
    mov  cl,0x10
    call C688:93CE
    mov  ch,0x10
    mov  si,0x7a1f
    call C688:EF86
    call C688:92DF
replace_commit_selected_C688_8DBF:
    mov  si,0x0001
    jmp  C688:8DC7

replace_commit_clear_prompt_C688_8DC4:
    mov  si,0x0000

replace_commit_common_C688_8DC7:
    mov  [0x757d],si
    mov  si,0x0001
    mov  [0x7781],si
    mov  al,[0x7520]
    or   al,0x02
    mov  [0x7520],al
    call C688:8F40
    call C688:50FC
    jmp  C688:8DE8

replace_reselect_C688_8DE2:
    call C688:8F40
    call C688:5108
    push ax
    call C688:44C4
    pop  ax
    test al,0x10
    jnz  C688:8D83
    mov  al,[0x757d]
    or   al,al
    jz   C688:8E1C
    call C688:2A90
    call C688:2CFA
    call C688:44C4
    mov  al,0x04
    mov  [0x79a6],al
    call C688:9347
    call C688:93B5
    mov  al,[0x794a]
    cmp  al,0x1d
    jnz  C688:8E15
    jmp  C688:8DE2
    cmp  al,0xda
    jz   C688:8E1C
    jmp  C688:EC9F
replace_final_stage_C688_8E1C:
    mov  si,0x0001
    mov  [0x7781],si
    call C688:8F40
    mov  si,0x7a1f
    mov  di,0x75a0
    mov  bx,0x0010
    push es
    mov  bp,0x0000
    mov  es,bp
    cld
    rep  movsb
    pop  es
    call C688:0240
; inline display/control bytes: A8 C7 0A 3A 18 00
    mov  al,0xff
    mov  [0x757a],al
    call C688:8F0D
    xor  al,al
    mov  [0x757a],al
    call C688:0240
; inline display/control bytes: 1E 38 00
    mov  al,[0x7520]
    cmp  al,0x08
    jnc  C688:8EB7
    mov  si,0x7f28
    mov  ch,0x10
    call C688:8EE9
...
    mov  ch,0x10
    mov  si,0x7a1f
    mov  al,[si]
    cmp  al,0x61
    cmp  al,0x7b
    and  al,0xdf       ; lowercase to uppercase
    mov  [si],al
...
    call C688:5102
    mov  al,[0x79a6]
    cmp  al,0x6a
    jz   C688:8EDA
    call C688:44C4
    mov  si,0x75a0
    mov  di,0x7a1f
    mov  bx,0x0010
    push es
    mov  bp,0x0000
    mov  es,bp
    cld
    rep  movsb
    pop  es
    jmp  C688:8DDD

work_memory_full_exit_C688_8EDA:
    call C688:44C4
    call C688:EE98
    mov  si,0x0055
    call C688:96EA
    jmp  C688:EC9F
scan_space_or_letter_C688_8EE9:
    dec  ch
    mov  al,[si]
    inc  si
    or   al,al
    jnz  C688:8EF3
    ret
    cmp  al,0x20
    jz   C688:8F08
    cmp  al,0x41
    jc   C688:8EE9
    cmp  al,0x5b
    jc   C688:8F08
    cmp  al,0x61
    jc   C688:8EE9
    cmp  al,0x7b
    jnc  C688:8EE9
    ret
    xor  al,al
    inc  al
    ret
build_search_mask_C688_8F0D:
    mov  ch,0x10
    mov  dx,0x7a30
    mov  si,0x7f28
    xor  al,al
    mov  [si],al
    mov  di,dx
    mov  al,[di]
    inc  dx
    or   al,al
    jnz  C688:8F23
    ret
    push cx
    push dx
    push si
    call C688:97E7
    pop  si
    pop  dx
    pop  cx
    jz   C688:8F2F
    ret
    and  al,0x0f
    cmp  al,0x07
    jz   C688:8F3B
    mov  al,[0x7576]
    mov  [si],al
    inc  si
    dec  ch
    jnz  C688:8F15
    ret
snapshot_display_state_C688_8F40:
    mov  al,[0x7948]
    mov  [0x7948],al
    mov  [0x799c],al
    ret
trim_trailing_spaces_C688_93CE:
    push word [0x75ef]
    push ax
    push cx
    push dx
    push si
    mov  dh,0x00
    mov  dl,cl
    add  si,dx
    mov  ch,cl
    dec  si
    mov  al,[si]
    cmp  al,0x20
    jz   C688:93EB
    mov  ch,0x01
    cmp  al,0xff
    jnz  C688:944E
    xor  al,al
    mov  [si],al
    dec  ch
    jnz  C688:93DE
...
    pop  si
    pop  dx
    pop  cx
    pop  ax
    pop  word [0x75ef]
    ret
classify_prompt_field_C688_EF86:
    mov  al,[si]
    or   al,al
    jnz  C688:EF8D
    ret
    cmp  al,0x20
    jz   C688:EF99
    cmp  al,0x41
    jc   C688:EFA0
    cmp  al,0x5b
    jnc  C688:EFA0
    mov  al,0x08
    mov  [0x7520],al
    stc
    ret
    inc  si
    dec  ch
    jnz  C688:EF86
    xor  al,al
    ret
