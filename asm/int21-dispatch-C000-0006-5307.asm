; Generated from disasm: C000:0006-5307
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0006


seed_int21_vector_target:
; file 0x40006
    jmp  int21_dispatch_C000_5098
int21_dispatch_C000_5098:
; file 0x45098
    push bp
    push si
    push di
    sub  sp,byte +0x0e
    mov  bp,sp
    mov  [bp+0x00],ax
    mov  [bp+0x02],bx
    mov  [bp+0x04],cx
    mov  [bp+0x06],dx
    mov  [bp+0x08],ds
    mov  [bp+0x0a],es
    mov  si,0
    mov  ds,si
    mov  [0x6f5f],ah     ; original service number
    mov  word [0x6ec1],0

    cmp  ah,0xff
    jz   private_format_C000_5112
    cmp  ah,0x60
    jnc  unsupported_service_C000_5110
    xor  al,al
    xchg ah,al           ; AX = AH service number
    mov  si,ax
    mov  al,[cs:si+0x5000]
    cmp  al,0xff
    jz   unsupported_service_C000_5110
    shl  ax,1
    mov  si,ax
    mov  ax,[cs:si+0x5060]
    sti
    call ax
    cli
    lahf                 ; preserve handler flags
    add  sp,byte +0x0e
    sahf
    mov  ax,[bp+0x00]
    mov  bx,[bp+0x02]
    mov  cx,[bp+0x04]
    mov  dx,[bp+0x06]
    mov  ds,[bp+0x08]
    mov  es,[bp+0x0a]
    pop  di
    pop  si
    mov  bp,sp           ; BP points at saved FLAGS
    jc   return_with_carry_C000_510A
    and  byte [bp+0x06],0xfe
    pop  bp
    iret
return_with_carry_C000_510A:
    or   byte [bp+0x06],0x01
    pop  bp
    iret

unsupported_service_C000_5110:
    jmp  short C000:5110

private_format_C000_5112:
    call C000:2C4A
    jmp  C000:50E7
service_03_serial_input_status_C000_5117:
    call C000:4B8D
    test byte [0x70a5],0x02
    jz   C000:5142
    call C000:49F8
    or   al,al
    jz   service_03_serial_input_status_C000_5117
    mov  ah,0x80
    or   ah,[0x6d57]
    and  byte [0x6d57],0x01
    and  ah,0xfe
    mov  bx,[bp+0x02]
    mov  bl,ah
    mov  [bp+0x02],bx
    mov  [bp+0x00],ax
    ret
    mov  ah,0
    jmp  C000:512A

service_05_parallel_output_C000_5146:
    call C000:0920
    mov  bx,[bp+0x02]
    mov  bl,al
    mov  [bp+0x02],bx
    mov  [bp+0x00],ax
    ret

service_08_blocking_key_C000_5155:
    call C000:4A8D
    mov  [bp+0x00],al
    ret

service_0B_key_status_C000_515C:
    call C000:4977
    mov  [bp+0x00],al
    ret
    call C000:28A7        ; AH=0E
    ret
    call C000:28B9        ; AH=19
    ret
    call C000:28C3        ; AH=1A
    ret

    call C000:28D0        ; AH=2F
    ret
    call C000:28E0        ; AH=36
    ret
    call C000:29AD        ; AH=3C
    ret
    call C000:2B84        ; AH=3D
    ret
    call C000:2C41        ; AH=3E
    ret
    call C000:3194        ; AH=3F
    ret
    call C000:32B1        ; AH=40
    ret
    call C000:3730        ; AH=41
    ret
    call C000:356F        ; AH=42
    ret
    call C000:37A7        ; AH=43
    ret
    call C000:2DE2        ; AH=4E
    ret
    call C000:2E27        ; AH=4F
    ret
    call C000:2FE5        ; AH=56
    ret
    call C000:30DA        ; AH=57
    ret
    call C000:2A1B        ; AH=5B
    ret
service_2A_get_date_C000_516F:
    call C000:517C
    mov  [bp+0x00],al    ; AL = weekday
    mov  [bp+0x04],cx    ; CX = year
    mov  [bp+0x06],dx    ; DH = month, DL = day
    ret

    call C000:0B60        ; read RTC shadow
...
    mov  ax,cx           ; year
    mov  bl,dh           ; month
    mov  cl,dl           ; day
    call C000:5308        ; weekday
    ret

service_2B_set_date_C000_51C7:
    call C000:51CE
    mov  [bp+0x00],al
    ret
    mov  si,0x6d96
...
    call C000:09C9        ; write RTC date
    ret

service_2C_get_time_C000_5209:
    call C000:5213
    mov  [bp+0x04],cx    ; CH = hour, CL = minute
    mov  [bp+0x06],dx    ; DH = second
    ret
    call C000:0B60        ; read RTC shadow
...
    ret

service_2D_set_time_C000_523D:
    call C000:5244
    mov  [bp+0x00],al
    ret
    mov  si,0x6d96
...
    call C000:09AE        ; write RTC time
    ret
service_44_ioctl_C000_5298:
    mov  ax,[bp+0x00]
    or   al,al
    jz   ioctl_4400_C000_52C1
    sub  ax,0x4420
    jz   ioctl_4420_C000_52C5
    dec  ax
    jz   ioctl_4421_C000_52C9
...
    dec  ax
    jz   ioctl_4428_C000_52EC
    dec  ax
    jz   ioctl_4429_C000_52F0
    stc
    ret

    call C000:30B0        ; AX=4400
    ret
    call C000:086C        ; AX=4420
    ret
    mov  al,[0x70e6]     ; AX=4421
    mov  [bp+0x00],ax
    ret
    call C000:0CBC        ; AX=4422
    ret
    call C000:0D25        ; AX=4423
    ret
    call C000:5A2F        ; AX=4424
    ret
    call C000:5948        ; AX=4425
    ret
    or   byte [0x6d51],0x08 ; AX=4426
    ret
    and  byte [0x6d51],0xf7 ; AX=4427
    ret
    call C000:3064        ; AX=4428 endpoint probe
    ret
    call C000:311E        ; AX=4429 DreamLink finish
    ret
