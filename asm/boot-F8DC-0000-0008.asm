; Generated from disasm: F8DC:0000-0008
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0000

root_reset_trampoline:
    db 0xb0, 0x01    ; mov al,0x01
    db 0xe6, 0x16    ; out 0x16,al ; C0000..DFFFF -> ROM file 40000..5FFFF
    db 0xb0, 0x00    ; mov al,0x00
    db 0xe6, 0x17    ; out 0x17,al ; E0000..FFFFF -> ROM file 60000..7FFFF
    jmp 0xC000:0x0000
