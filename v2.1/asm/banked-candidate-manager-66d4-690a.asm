; Generated from disasm: 3000:66D4-690A
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x66D4


; helper call targets covered by later slices
candidate_search_C3000_9848    equ 0x9848

candidate_state_init_C3000_66D4:
; file 0x366D4
    push bp
    mov  bp,sp
    sub  sp,byte +0x2
    mov  word [0x712e],0xffff
    mov  word [0x6e48],0
    call 0x88a0
    mov  [0x7132],ax
    or   ax,ax
    jnz  loc_66F8
loc_66F0:
    mov  ax,0xffff
    mov  sp,bp
    pop  bp
    ret
loc_66F8:
    push word [0x7132]
    call 0x96d6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_670E
    mov  word [0x7132],0
    jmp  loc_66F0
loc_670E:
    mov  word [bp-0x2],0
loc_6713:
    mov  ax,0x50
    imul word [bp-0x2]
    add  ax,0x6e5e
    mov  bx,[bp-0x2]
    shl  bx,1
    mov  [bx+0x6e4a],ax
    inc  word [bp-0x2]
    cmp  word [bp-0x2],byte +0x9
    jl   loc_6713
    mov  word [0x7130],0
    sub  ax,ax
    mov  sp,bp
    pop  bp
    ret
candidate_result_list_build_C3000_673A:
; file 0x3673A
    push bp
    mov  bp,sp
    mov  word [0x7130],0
    mov  word [0x6e5c],0xffff
    mov  word [0x712e],0
    mov  ax,0x6e4a
    push ax
    mov  ax,0x9
    push ax
    mov  ax,0x1
    push ax
    push word [bp+0x4]
    call candidate_search_C3000_9848
    add  sp,byte +0x8
    mov  [0x6e48],ax
    or   ax,ax
    jg   loc_6774
    mov  ax,0xffff
    mov  [0x712e],ax
    pop  bp
    ret
loc_6774:
    mov  ax,[0x6e48]
    pop  bp
    ret
candidate_copy_primary_field_C3000_677A:
; file 0x3677A
    push bp
    mov  bp,sp
    sub  sp,byte +0x4
    push di
    push si
    cmp  word [0x712e],byte +0x0
    jl   loc_6792
    mov  ax,[0x6e48]
    cmp  [0x712e],ax
    jl   loc_67A4
loc_6792:
    mov  bx,[bp+0x4]
    mov  byte [bx],0
    mov  ax,0xffff
    mov  [0x712e],ax
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
loc_67A4:
    mov  bx,[0x712e]
    shl  bx,1
    mov  si,[bx+0x6e4a]
loc_67AE:
    cmp  byte [si],0
    jz   loc_67C2
    inc  si
    cmp  byte [si-0x1],0x20
    jnz  loc_67AE
    jmp  loc_67C2
loc_67BC:
    cmp  byte [si],0x20
    jnz  loc_67C7
    inc  si
loc_67C2:
    cmp  byte [si],0
    jnz  loc_67BC
loc_67C7:
    mov  di,[bp+0x4]
    jmp  loc_67D5
loc_67CC:
    cmp  byte [si],0x20
    jz   loc_67DA
    lodsb
    mov  [di],al
    inc  di
loc_67D5:
    cmp  byte [si],0
    jnz  loc_67CC
loc_67DA:
    mov  byte [di],0
    mov  ax,di
    sub  ax,[bp+0x4]
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
candidate_copy_secondary_tail_C3000_67E8:
; file 0x367E8
    push bp
    mov  bp,sp
    sub  sp,byte +0x6
    push di
    push si
    mov  bx,[bp+0x4]
    mov  byte [bx],0
    cmp  word [0x712e],byte +0x0
    jl   loc_6806
    mov  ax,[0x6e48]
    cmp  [0x712e],ax
    jl   loc_6812
loc_6806:
    mov  ax,0xffff
    mov  [0x712e],ax
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
loc_6812:
    mov  bx,[0x712e]
    shl  bx,1
    mov  si,[bx+0x6e4a]
    mov  word [bp-0x6],0
loc_6824:
    inc  word [bp-0x6]
    cmp  word [bp-0x6],byte +0x2
    jnl  loc_6846
loc_682D:
    cmp  byte [si],0
    jz   loc_6839
    inc  si
    cmp  byte [si-0x1],0x20
    jnz  loc_682D
loc_6839:
    cmp  byte [si],0
    jz   loc_6824
    cmp  byte [si],0x20
    jnz  loc_6824
    inc  si
    jmp  loc_6839
loc_6846:
    mov  di,[bp+0x4]
loc_6849:
    lodsb
    mov  [di],al
    inc  di
    or   al,al
    jnz  loc_6849
    mov  ax,di
    sub  ax,[bp+0x4]
    dec  ax
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
candidate_next_C3000_685E:
; file 0x3685E
    inc  word [0x712e]
    mov  ax,[0x6e48]
    cmp  [0x712e],ax
    jl   loc_6872
    dec  word [0x712e]
    sub  ax,ax
    ret
loc_6872:
    mov  word [0x7130],0
    mov  ax,0x1
    ret

candidate_previous_C3000_687C:
    dec  word [0x712e]
    jns  loc_6888
    sub  ax,ax
    mov  [0x712e],ax
    ret
loc_6888:
    mov  word [0x7130],0
    mov  ax,0x1
    ret
related_word_next_C3000_6892:
; file 0x36892
    push bp
    mov  bp,sp
    sub  sp,byte +0x2
    push si
    mov  bx,[bp+0x4]
    mov  byte [bx],0
    cmp  word [0x7130],byte +0x0
    jnz  loc_68C8
    mov  ax,0x7130
    push ax
    mov  ax,[0x712e]
    inc  ax
    push ax
    call 0xa45c
    add  sp,byte +0x4
    or   ax,ax
    jnz  loc_68C2
loc_68B9:
    mov  ax,0xffff
    pop  si
    mov  sp,bp
    pop  bp
    ret
loc_68C2:
    mov  word [0x6e5c],0xffff
loc_68C8:
    cmp  word [0x6e5c],byte +0x0
    jl   loc_68DE
    mov  bx,[0x6e5c]
    shl  bx,1
    mov  si,[0x7130]
    cmp  word [bx+si],byte +0x0
    jz   loc_68E2
loc_68DE:
    inc  word [0x6e5c]
loc_68E2:
    mov  bx,[0x6e5c]
    shl  bx,1
    mov  si,[0x7130]
    mov  ax,[bx+si]
    mov  [bp-0x2],ax
    or   ax,ax
    jz   loc_68B9
    push ax
    push word [bp+0x4]
    call 0x960a
    add  sp,byte +0x4
    mov  [bp-0x2],ax
    sub  ax,[bp+0x4]
    pop  si
    mov  sp,bp
    pop  bp
    ret
related_word_previous_C3000_690A:
; file 0x3690A
    push bp
