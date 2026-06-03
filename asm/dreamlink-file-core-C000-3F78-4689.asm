; Generated from disasm: C000:3F78-4689
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x3F78


send_dreamlink_prefix_C000_3F78:
; file 0x43F78
    mov  cx,0x16fa
    loop C000:3F7B
    mov  dl,0x13
    call serial_send_byte_C000_0DC4
    ret
send_dreamlink_filename_C000_400F:
; file 0x4400F
    mov  si,dx
    mov  cx,0x000c
    mov  es,[0x703d]
    mov  dl,[es:si]
    cmp  dl,0
    mov  al,dl
    call checksum_add_C000_4125
    call serial_send_byte_C000_0DC4
...
    mov  dl,0
    call serial_send_byte_C000_0DC4
dreamlink_response_C000_4082:
; file 0x44082
    call clear_response_scratch_C000_3F58
    call serial_recv_byte_C000_0E3E
    mov  [0x704f],al
    cmp  al,0x13
    jz   response_prefix_ok_C000_4093
    clc
    ret
...
    cmp  al,[0x7037]
    jz   expected_response_C000_40BB
    call serial_recv_byte_C000_0E3E
    mov  [0x7051],al
    mov  word [0x703b],0
    cmp  al,0
    jz   parse_success_payload_C000_40E3
    call serial_recv_byte_C000_0E3E
    mov  [0x703b],ax
    mov  [0x7052],al
    call recv_response_trailer_C000_411C
dreamlink_probe_C000_41A8:
; file 0x441A8
    mov  byte [0x6d2a],0x06
    mov  byte [0x6d2b],0x01
    mov  byte [0x6d2c],0
    mov  byte [0x6d2d],0
    mov  byte [0x6d2e],0
    call validate_and_init_serial_C000_0CBC
...
    call strict_handshake_C000_3F8C
    call send_dreamlink_prefix_C000_3F78
    mov  si,0x41a5 ; 02 47 11
    call send_inline_bytes_C000_0E98
    mov  byte [0x7037],0x47
    call dreamlink_response_C000_4082
dreamlink_fetch_directory_C000_4246:
; file 0x44246
    call send_dreamlink_prefix_C000_3F78
    mov  si,0x4240 ; 02 4E 11
    call send_inline_bytes_C000_0E98
    mov  byte [0x7037],0x4e
    call dreamlink_response_C000_4082
...
    mov  byte [0x7037],0x4f
    call dreamlink_response_C000_4082
dreamlink_create_C000_4384:
; file 0x44384
    add  dx,2
    call send_dreamlink_prefix_C000_3F78
    mov  dl,0x3c
    call serial_send_byte_C000_0DC4
    mov  byte [0x7049],0x3c
...
    call send_dreamlink_filename_C000_400F
    mov  dl,[0x7049]
    call serial_send_byte_C000_0DC4
    mov  dl,0x11
    call serial_send_byte_C000_0DC4
    mov  byte [0x7037],0x3c
    call dreamlink_response_C000_4082
dreamlink_read_start_C000_44C0:
; file 0x444C0
    mov  word [0x6f13],1
    call send_dreamlink_prefix_C000_3F78
    mov  dl,0x3f
    call serial_send_byte_C000_0DC4
    call send_dreamlink_handle_C000_4040
    mov  dl,0x11
    call serial_send_byte_C000_0DC4
    mov  byte [0x7037],0x3f
    call dreamlink_response_C000_4082
dreamlink_write_data_C000_4647:
; file 0x44647
    mov  [0x6f95],cx
    mov  bx,[0x704a]
...
    cmp  dl,0x20
    jnc  send_plain_byte_C000_468C
    mov  dl,0x08
    call serial_send_byte_C000_0DC4
    mov  ax,cx
    call checksum_add_C000_4125
    add  dl,0x60
