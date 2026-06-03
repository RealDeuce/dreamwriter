; Generated from disasm: C000:3064-3173
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x3064


endpoint_probe_C000_3064:
; file 0x43064
    mov  al,0
    mov  ah,[0x6fa5]
    mov  bx,[0x6fa3]
    push bx

; built-in RAM filesystem
    mov  byte [0x6fa5],0x08
    mov  word [0x6fa3],0x1800
    push ax
    call mount_current_endpoint_C000_3B69
    pop  ax
    jc   C000:3083
    or   al,0x01

; PCMCIA SRAM card filesystem
    mov  byte [0x6fa5],0x09
    mov  word [0x6fa3],0x4000
    push ax
    call mount_current_endpoint_C000_3B69
    pop  ax
    jc   C000:3097
    or   al,0x02

; DreamLink peer
    push ax
    call dreamlink_probe_C000_41A8
    pop  ax
    jc   C000:30A0
    or   al,0x04

    mov  [0x6fa5],ah
    pop  bx
    mov  [0x6fa3],bx
    mov  ah,0
    mov  [bp+0x00],ax
    clc
    ret
ioctl_4400_C000_30B0:
; file 0x430B0
    call resolve_handle_C000_4064
    mov  ax,[bp+0x00]
    cmp  al,0x28
    jnz  C000:30BC
    jmp  endpoint_probe_C000_3064
    cmp  al,0x29
    jz   dreamlink_finish_wrapper_C000_311E
service_57_file_datetime_C000_30DA:
; file 0x430DA
    call resolve_handle_C000_4064
    mov  ax,[bp+0x00]
    or   al,al
    jz   get_file_datetime_C000_30F5
    dec  al
    jz   set_file_datetime_C000_3108
...
    call C000:3DB3
    mov  cx,[bx+0x16]
    mov  [bp+0x04],cx
    mov  dx,[bx+0x14]
    mov  [bp+0x06],dx
...
    mov  byte [0x7036],1
    mov  [bx+0x16],cx
    mov  [bx+0x14],dx
dreamlink_finish_wrapper_C000_311E:
    call dreamlink_finish_C000_3125
    mov  [bp+0x00],ax
    ret

dreamlink_finish_C000_3125:
; file 0x43125
    call resolve_handle_C000_4064
    mov  al,[0x6fa5]
    cmp  al,0x0a
    jz   C000:3134
    mov  ax,0
    clc
    ret
    mov  dl,0x1a
    push dx
    call serial_send_byte_C000_0DC4
...
    mov  dl,[0x7049]
    call serial_send_byte_C000_0DC4
    mov  dl,0x11
    call serial_send_byte_C000_0DC4
    call C000:3FF3
    mov  byte [0x7037],0x40
    call dreamlink_response_C000_4082
