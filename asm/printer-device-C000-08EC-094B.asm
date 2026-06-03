; Generated from disasm: C000:08EC-094B
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x08EC


centronics_start_stream_C000_08EC:
; file 0x408EC
    mov  bx,[0x6d92]
    mov  dl,[bx]
    inc  bx
    mov  [0x6d92],bx
    cmp  dl,0
    jz   printer_return_C000_0915
    mov  byte [0x6da4],0
    and  byte [0x6d4f],0xbf
    mov  al,[0x6d4f]
    out  0x60,al
    nop
    mov  byte [0x6da4],1
    call centronics_write_dl_C000_0920
    ret
centronics_write_dl_C000_0920:
; file 0x40920
    mov  al,dl
    out  0x40,al
printer_wait_ready_C000_0924:
    mov  ax,[0x6d31]
    mov  [0x680b],ax
    in   al,0xa0
    test al,0x02        ; BUSY
    jnz  printer_wait_idle_C000_0942

printer_strobe_C000_0930:
    mov  al,[0x6d94]
    or   al,0x20
    out  0x30,al
    nop
    nop
    nop
    nop
    and  al,0xdf
    out  0x30,al
    mov  al,0
    ret

printer_wait_idle_C000_0942:
    call idle_until_event_C000_49F8
    cmp  al,0
    jz   printer_wait_ready_C000_0924
    mov  al,0xff
    ret
