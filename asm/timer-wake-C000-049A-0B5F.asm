; Generated from disasm: C000:049A-0B5F
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x049A


irq_f9_timer_wake_C000_049A:
; file 0x4049A
    push ax
    push ds
    mov  ax,0
    mov  ds,ax
    mov  al,0x40
    out  0x90,al
    and  byte [0x6da9],0xfe
    pop  ds
    pop  ax
    sti
    iret
arm_timer_C000_0B3C:
; file 0x40B3C
    or   byte [0x6da9],0x01
    and  byte [0x6d4f],0xfd
    mov  al,[0x6d4f]
    out  0x60,al
    mov  al,ah
    out  0x53,al
    ret
disarm_timer_C000_0B50:
; file 0x40B50
    and  byte [0x6da9],0xfe
    or   byte [0x6d4f],0x02
    mov  al,[0x6d4f]
    out  0x60,al
    ret
