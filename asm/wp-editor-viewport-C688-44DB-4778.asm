; Generated from disasm: C688:44DB-4778
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x44DB


root_editor_viewport_update_C688_44DB:
; file 0x4AD5B
    xchg si,dx
    add  si,cx
    push si
    jmp  C688:44F4

range_editor_viewport_update_C688_44E2:
    mov  [0x7958],cx
    mov  [0x7946],si
    xchg si,dx
    add  si,cx
    push si
    dec  si
    mov  [0x795a],si
shared_editor_viewport_body_C688_44F4:
    mov  [0x772c],cx
    push dx
    mov  al,[0x7a56]
    test al,0x01
    jz   C688:4503
    pop  si
    pop  si
    ret
    call C688:1B41
    mov  si,0x790d
    and  byte [si],0xbf
    pop  si
    mov  dx,[0x78f5]
    xor  al,al
    mov  [0x7730],al
    mov  [0x7731],al
initial_viewport_delta_C688_4519:
    sub  si,dx
    mov  cl,0x04
    jz   C688:4534
    js   C688:4534
    mov  bx,si
    mov  al,bh
    or   al,al
    jnz  C688:452F
    mov  al,bl
    dec  al
    jz   C688:4534
    call C688:18AC
    jmp  C688:4559
    mov  cl,0x14
    xchg si,dx
    mov  si,0
    xor  al,al
    sub  si,dx
    call C688:18AC
...
    mov  dx,[0x772c]
    call C688:1A85
viewport_state_seed_C688_4559:
    mov  dx,[0x79f6]
    mov  si,[0x772c]
    add  si,dx
    mov  [0x771b],dx
    mov  [0x772c],si
    mov  dx,[0x7954]
    mov  si,[0x7950]
    add  si,dx
    mov  [0x7952],si
    mov  si,0
    mov  [0x796b],si
    xor  al,al
    mov  [0x771d],al
    mov  si,0x7f28
    mov  [0x79e2],si
    mov  al,[0x795e]
    mov  [0x799a],al
    mov  cl,0
    call C688:18AC
viewport_range_bounds_C688_4597:
    mov  al,[0x771d]
    or   al,al
    jz   C688:4602
    mov  dx,[0x79f6]
    mov  si,[0x7973]
    add  si,dx
    jc   C688:45B8
    xchg si,dx
    mov  si,[0x78fd]
    sub  si,dx
    mov  si,[0x79f6]
    jns  C688:45DB
    mov  si,[0x7907]
    mov  [0x7971],si
...
    mov  dx,[0x78fb]
    mov  [0x7973],dx
    mov  al,[0x79a1]
    test al,0x01
    jz   C688:45E9
    mov  si,0x0002
    mov  dx,[0x772c]
    add  si,dx
    mov  [0x772c],si
negative_delta_emit_seed_C688_4602:
    mov  si,[0x771b]
    test si,0x8000
    jz   C688:4626
    mov  byte [0x771d],0x01
    mov  bx,si
    mov  al,bl
    inc  al
    jz   C688:4626
    mov  al,[0x795f]
    mov  si,0x7f28
    call C688:1A51
    mov  [0x79e2],si
    call C688:1B12
final_viewport_clamp_C688_465A:
    mov  si,[0x7901]
    mov  cx,[0x78fd]
    sub  si,cx
    add  si,dx
    mov  dx,[0x7971]
    add  si,dx
    jmp  C688:469E
...
    mov  si,[0x772c]
    add  si,dx
    mov  [0x772c],si
    mov  si,[0x7971]
    mov  [0x7973],si

redraw_handoff_C688_46B2:
    mov  si,[0x772c]
    mov  dx,[0x7958]
    sub  si,dx
    test si,0x8000
    jz   C688:46CD
    inc  si
    cmp  si,0
    jnz  C688:473F
    mov  byte [0x7730],0x01
...
    mov  [0x7731],al
    call C688:6B8C
    xor  al,al
    mov  si,0x790d
    test byte [si],0x40
    jz   C688:4749
    and  byte [si],0xbf
    or   al,al
    lahf
    push ax
    mov  si,0x7f28
    mov  [0x79e2],si
    jnz  C688:4707
    call C688:1B6F
    mov  [0x79e2],si
    mov  cx,[0x7a60]
    call C688:1D75
    mov  si,[0x79e2]
    mov  dx,0x7f28
    xor  al,al
    mov  [0x772b],al
    sub  si,dx
    mov  [0x7727],si
redraw_loop_or_return_C688_4724:
    mov  al,0x05
    mov  [0x771d],al
    mov  si,0x7724
    mov  [0x771b],si
...
    mov  al,0xff
    mov  [0x794e],al
    mov  [0x771d],al
    jmp  C688:46EC
    mov  si,[0x796b]
    mov  dx,[0x772c]
    add  si,dx
...
    mov  al,[0x795e]
    mov  [0x799a],al
    jz   C688:4778
    call C688:1A85
    jmp  C688:1A7B
