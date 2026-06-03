; Generated from disasm: DC98:0DAF-0DC2
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0DAF

tone_duration_wrapper_DC98_0DAF:
    db 0x55    ; push bp
    db 0x57    ; push di
    db 0x56    ; push si
    db 0x52    ; push dx
    db 0x51    ; push cx
    db 0x8b, 0xcb    ; mov cx,bx
    db 0x8b, 0xd8    ; mov bx,ax
    call 0xC000:0x087F
    db 0x59    ; pop cx
    db 0x5a    ; pop dx
    db 0x5e    ; pop si
    db 0x5f    ; pop di
    db 0x5d    ; pop bp
    db 0xcb    ; retf

; helper call targets covered by other slices
tone_duration_far_C000_087F equ 0x087F
