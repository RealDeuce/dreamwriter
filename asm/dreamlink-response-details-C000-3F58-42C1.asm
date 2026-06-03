; Generated from disasm: C000:3F58-42C1
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x3F58


clear_response_scratch_C000_3F58:
; file 0x43F58
    push ax
    xor  al,al
    mov  [0x704c],al
    mov  [0x704d],al
    mov  [0x704e],al
    mov  [0x704f],al
    mov  [0x7050],al
    mov  [0x7051],al
    mov  [0x7052],al
    mov  [0x7053],al
    mov  [0x7054],al
    pop  ax
    ret
strict_handshake_C000_3F8C:
; file 0x43F8C
    call clear_response_scratch_C000_3F58
    call send_dreamlink_prefix_C000_3F78
    push si
    mov  si,0x3f89
    call send_inline_bytes_C000_0EB7
    pop  si
...
    mov  [0x704f],al
    cmp  al,0x13
...
    mov  [0x7050],al
    cmp  al,0x18
...
    mov  [0x7052],al
    cmp  al,0x06
...
    mov  [0x7054],al
    cmp  al,0x11
dreamlink_response_C000_4082:
; file 0x44082
    call clear_response_scratch_C000_3F58
    call serial_recv_byte_C000_0E3E
    mov  [0x704f],al
    cmp  al,0x13
    jz   response_prefix_ok_C000_4093
    clc
    ret
    call serial_recv_byte_C000_0E3E
    mov  [0x7050],al
    cmp  al,[0x7037]
expected_response_C000_40BB:
    call serial_recv_byte_C000_0E3E
    mov  [0x7051],al
    mov  word [0x703b],0
    cmp  al,0
    jz   parse_success_payload_C000_40E3
    call serial_recv_byte_C000_0E3E
    mov  [0x703b],ax
    mov  [0x7052],al
    call recv_response_trailer_C000_411C
dreamlink_name_payload_C000_4217:
; file 0x44217
    mov  dx,0x001f
    mov  di,0x6f34
receive_name_byte_C000_421D:
    push dx
    push di
    call serial_recv_byte_C000_0E3E
    jc   name_payload_error_C000_423E
    or   dx,dx
    jz   name_capacity_full_C000_422E
    dec  dx
    mov  [di],al
    inc  di
    or   al,al
    jnz  receive_name_byte_C000_421D
    call serial_recv_byte_C000_0E3E
    mov  [0x7053],al
dreamlink_listing_payload_C000_4296:
; file 0x44296
    mov  dx,0
    mov  byte [0x7039],0
    mov  al,[0x7038]
    mov  cl,5
    shl  ax,cl
    mov  bx,ax
    call prefill_listing_entry_C000_4365
    call serial_recv_byte_C000_0E3E
    call expand_listing_byte_C000_42CC
    jc   listing_payload_parser_error_C000_42C8
    jnz  receive_listing_byte_C000_42AC
    call serial_recv_byte_C000_0E3E
    mov  [0x7053],al
