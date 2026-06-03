; Generated from disasm: F8DC:0000-0008
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0000



; ---------------------------------------------------------------------------
; root_reset_vector
; file 0x7FFF0, CPU physical 0xFFFF0
;
; Reset begins at FFFF:0000 and jumps to F8DC:0000. The vector bytes are
; documented in docs/banking.md; the trampoline itself is below.

root_reset_trampoline:
; file 0x78DC0, CPU F8DC:0000
; Establish the normal high ROM windows before entering C000 startup.
    mov  al,0x01
    out  0x16,al      ; C0000..DFFFF -> ROM file 40000..5FFFF
    mov  al,0x00
    out  0x17,al      ; E0000..FFFFF -> ROM file 60000..7FFFF
    jmp  C000:0000

; ---------------------------------------------------------------------------
; root_c000_segment_head
; file 0x40000, CPU C000:0000
;
; The segment begins with a jump over service stubs and IRQ stubs. Startup
; later copies selected stubs into the IVT via install_vectors_C000_0ED6.

root_c000_entry:
