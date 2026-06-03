; Generated from disasm: C688:AD5C-ED18
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0xAD5C


print_merge_event_entry_C688_ED15:
; file 0x55595
    call C688:ACBC
    jmp  C688:EC9F
address_merge_reader_C688_AD5C:
; file 0x515DC
    push ds
    mov  si,cs
    mov  ds,si
    mov  dx,0xae3a
    xor  al,al
    mov  ah,0x3d
    call C688:01BD        ; INT 21h wrapper
    pop  ds
    jc   C688:AD48        ; ADDRESS.ODB missing prompt
    mov  [0x8253],ax
    xor  al,al
    mov  [0x8258],al
    mov  [0x8257],al
    mov  word [0x8255],0x0010
    mov  si,0x0011
    mov  ch,0x03
    call C688:EE9E        ; NAME LIST screen
    mov  al,0x00
    call C688:9541
address_list_next_index_C688_AD8C:
    mov  dx,[0x8255]
    mov  si,dx
    add  si,byte +0x04
    mov  [0x8255],si
    xor  cx,cx
    mov  al,cl
    mov  bx,[0x8253]
    mov  ah,0x42
    call C688:01BD        ; seek to dword index entry
    mov  dx,0x8259
    mov  cx,0x0002
    mov  bx,[0x8253]
    mov  ah,0x3f
    call C688:01BD        ; read low word of offset
    mov  si,[0x8259]
    or   si,si
    jz   C688:AE08
    mov  dx,si
    xor  cx,cx
    mov  al,cl
    mov  bx,[0x8253]
    mov  ah,0x42
    call C688:01BD        ; seek to record
    mov  dx,0x8259
    mov  cx,0x0018
    mov  bx,[0x8253]
    mov  ah,0x3f
    call C688:01BD        ; read leading name bytes
    mov  si,0x8259
    mov  dl,[si]
    cmp  dl,0x09
    jz   C688:ADF6
    cmp  dl,0x0a
    jz   C688:ADF6
    push si
    call C688:5B83
    pop  si
    inc  si
    cmp  si,0x8271
    jnz  C688:ADDE
    mov  dl,0x0c
    call C688:5B83
    inc  byte [0x8258]
    cmp  word [0x7a54],byte +0x09
    jc   C688:AE49
    jmp  C688:AD8C
address_list_done_C688_AE08:
    call C688:5C90
    call C688:5B7D
    call C688:44C4
    call C688:91D4
    call C688:727D
    call C688:0D05
    call C688:44C4
    and  byte [0x8db3],0xbf
    cmp  byte [0x794a],0x03
    jz   C688:AE2E
    or   byte [0x8db3],0x40
    mov  bx,[0x8253]
    mov  ah,0x3e
    call C688:01BD
    jmp  C688:EC9F
selected_address_stream_C688_AE5F:
; file 0x516DF
    and  byte [0x8db3],0xbf
    push ds
    mov  si,cs
    mov  ds,si
    mov  dx,0xae3a
    mov  al,0x00
    mov  ah,0x3d
    call C688:01BD
    pop  ds
    jnc  C688:AE7A
    call C688:AD4E
    ret
    mov  [0x8253],ax
    mov  dh,0x00
    mov  dl,[0x8257]
    add  dx,dx
    add  dx,dx
    add  dx,byte +0x10
    call C688:AF10
    mov  dx,[0x8259]
    mov  [0x8255],dx
    call C688:AF10
    mov  word [0x8251],0xeaed
address_template_loop_C688_AE9E:
    mov  si,[0x8251]
    cmp  byte [cs:si],0x0a
    jz   C688:AEB4
    call C688:AEBE
    mov  [0x8251],si
    call C688:AECF
    jmp  C688:AE9E
    mov  bx,[0x8253]
    mov  ah,0x3e
    call C688:01BD
    ret
emit_address_template_literal_C688_AEBE:
    mov  dl,[cs:si]
    inc  si
    cmp  dl,0x09
    jz   C688:AECE
    push si
    call C688:5B83
    pop  si
    jmp  C688:AEBE
    ret

emit_selected_address_field_C688_AECF:
    mov  al,[0x8257]
    cmp  al,[0x8258]
    jnz  C688:AEE8
    mov  dx,[0x8255]
    add  dx,byte +0x1e
    mov  [0x8255],dx
    call C688:AF10
    jmp  C688:AECF
    mov  bl,al
    mov  bh,0x00
    add  bx,0x8259
    mov  dl,[bx]
    cmp  dl,0x0a
    jz   C688:AF05
    inc  byte [0x8257]
    cmp  dl,0x09
    jz   C688:AF05
    call C688:5B83
    jmp  C688:AECF
    mov  dl,')'
    call C688:5B83
    mov  dl,0x0c
    call C688:5B83
    ret

load_address_chunk_C688_AF10:
    mov  cx,0x0000
    mov  al,0x00
    mov  bx,[0x8253]
    mov  ah,0x42
    call C688:01BD
    mov  dx,0x8259
    mov  cx,0x001e
    mov  bx,[0x8253]
    mov  ah,0x3f
    call C688:01BD
    mov  [0x8258],al
    mov  byte [0x8257],0x00
    ret
