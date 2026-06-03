; Generated from disasm: C000:0000-0F93
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0000



; ---------------------------------------------------------------------------
; root_c000_segment_head
; file 0x40000, CPU C000:0000
;
; The segment begins with a jump over service stubs and IRQ stubs. Startup
; later copies selected stubs into the IVT via install_vectors_C000_0ED6.

root_c000_entry:
    jmp  short startup_C000_0029
    nop
    ; data/padding
    ; data/padding

seed_int21_vector_target:
    jmp  int21_dispatch_C000_5098

seed_irq_f8_stub:
    jmp  irq_f8_save_suspend_C000_03AE
seed_irq_f9_stub:
    jmp  irq_f9_timer_ack_C000_049A
seed_irq_fa_stub:
    jmp  irq_fa_keyboard_scan_cycle_C000_04AE
seed_irq_fb_stub:
    jmp  irq_fb_keyboard_row_C000_04D1
seed_irq_fc_stub:
    jmp  irq_fc_serial_rx_C000_0550
seed_irq_fd_stub:
    jmp  irq_fd_serial_tx_ack_C000_0724
seed_irq_fe_stub:
    jmp  irq_fe_centronics_ack_C000_0738
seed_irq_ff_stub:
    jmp  irq_ff_warm_power_C000_02EE

; Far wrappers near the segment head. The first is the preserved-state front
; end for the `C000:170E` service table; the second dispatches the `C000:1712`
; service table, including the `D59C` resource reader at `C000:18EE`.
    call C000:1716       ; C000:170E service-table body
    retf
    call C000:1873       ; C000:1712 service-table body
    retf

; ---------------------------------------------------------------------------
; startup_C000_0029
; file 0x40029
;
; This is the normal cold/warm startup entry after reset trampoline banking.

startup_C000_0029:
    mov  al,0xff
    out  0x90,al       ; clear all currently active IRQ bits

; Select the baseline memory map.
    mov  al,0x17
    out  0x10,al       ; RAM page/window for 00000..1FFFF
    mov  al,0x0e
    out  0x11,al       ; upper internal RAM at 20000..3FFFF
    mov  al,0x1f
    out  0x12,al
    mov  al,0x1e
    out  0x13,al
    mov  al,0x1d
    out  0x14,al
    mov  al,0x1c
    out  0x15,al
    mov  al,0x01
    out  0x16,al       ; keep C000 segment mapped to ROM file 40000
    mov  al,0x00
    out  0x17,al       ; keep high ROM mapped to ROM file 60000

; Basic peripheral state.
    mov  al,0xf8
    out  0xdd,al       ; RP5C01 mode/timer state
    mov  al,0xf0
    out  0xde,al       ; RP5C01 control state
    mov  al,0x08
    out  0x00,al       ; LCD scanout base = 0x1000
    mov  al,0x00
    out  0x20,al       ; unknown/monitor handshake cleared

; Establish flat low-RAM segments and initial stack.
    mov  sp,0x6c06
    mov  ax,0x0000
    mov  ss,ax
    mov  ds,ax
    mov  es,ax
    xor  ax,ax
    mov  [0x70e7],al
    mov  [0x7036],al
    mov  [0x6da5],ax
    inc  ax
    mov  [0x6809],ax    ; early state marker = 1
    mov  al,0x5f
    mov  [0x6d94],al    ; port 0x30 mirror default
    mov  al,0xff
    out  0x40,al       ; Centronics data idle
    mov  al,0xff
    out  0x60,al       ; IRQ/source latch idle
    mov  byte [0x6805],0x48

; Seed later roots, then enter early hardware/app validation.
    call install_vectors_C000_0ED6
    call battery_startup_gate_C000_083B  ; main-battery startup gate
    call C688:0053       ; retained/warm RAM signature check
    jc   cold_start_C000_00E1
    call C000:47D3       ; retained date/time/serial/printer validation
    jc   cold_start_C000_00E1

; Warm/resume decision. The exact retained-state values are tracked in
; docs/hardware.md and docs/entry-points.md; branches are left as skeleton
; until the resume path is expanded.
    test byte [0x6d51],0x01
    pushf
    and  byte [0x6d51],0xfe
    popf
    jnz  warm_path_C000_011F
    mov  ax,[0x6d79]    ; saved return offset
    or   ax,ax
    jz   retained_target_default_C000_00C3
    cmp  ax,0x4a8d
    jz   retained_target_default_C000_00C3
    cmp  ax,0x4977
    jz   retained_target_default_C000_00C3
    cmp  ax,0x49fd
    jz   retained_target_default_C000_00C3
    jmp  warm_resume_alt_C000_0194

retained_target_default_C000_00C3:
    mov  bx,ax
    mov  ax,cs
    cmp  ax,[0x6d7b]    ; saved return segment
    jnz  cold_start_C000_00E1
    or   bx,bx
    jnz  retained_marker_check_C000_00D7
    mov  word [0x6d81],0x1995
retained_marker_check_C000_00D7:
    mov  ax,[0x6d81]
    or   ax,ax
    jnz  warm_path_C000_011F
    jmp  clean_resume_C000_0161

; ---------------------------------------------------------------------------
; cold_start_C000_00E1
;
; Reinitializes volatile state, validates/formats built-in storage if needed,
; then enters the C688 application runtime at C688:000B.

cold_start_C000_00E1:
    mov  word [0x6d81],0
    mov  al,0xff
    out  0x60,al
    mov  [0x6d4f],al
    call seed_default_bank_mirrors_C000_0225
    call clear_low_runtime_C000_02BE
    call display_keyboard_state_init_C000_5AA2
    call startup_buzzer_resource_C000_0825
    call C000:4811       ; built-in store validate/format path
    call DC98:539E       ; organizer/menu subsystem initializer
    call C000:02A3       ; banked spell/service init pair
    mov  sp,0x1000
    mov  word [0x6809],0
    mov  ax,0x0a4f
    mov  es,ax
    call open_file_table_init_C000_3CBB
    call keyboard_scan_start_C000_1038
    sti
    jmp  C688:000B       ; cold app/runtime entry root

; ---------------------------------------------------------------------------
; warm_path_C000_011F
;
; Restores bank defaults, stack, keyboard scan, alarm/diagnostic gates, then
; either resumes runtime or falls back to cold_start_C000_00E1.

warm_path_C000_011F:
    call seed_default_bank_mirrors_C000_0225
    mov  sp,0x1000
    mov  ax,0x0a4f
    mov  es,ax
    call keyboard_scan_start_C000_1038
    sti
    push es
    call clear_framebuffer_C000_02DC
    pop  es
    call alarm_wake_wrapper_C000_0807
    cmp  byte [0x6d54],0
    jnz  warm_diag_gate_C000_0142
    call C000:02B3       ; banked spell reset/check
    jnz  cold_start_C000_00E1
warm_diag_gate_C000_0142:
    call diagnostic_gate_C000_08DA
    mov  word [0x6809],0
    cmp  word [0x6d81],0x1995
    mov  word [0x6d81],0
    jz   C000:011A
    call open_file_table_init_C000_3CBB
    jmp  C688:000F       ; warm app/runtime entry root

clean_resume_C000_0161:
    call keyboard_scan_start_C000_1038
    sti
    call alarm_wake_wrapper_C000_0807
    call C000:02B3       ; banked spell reset/check
    jnz  resume_failed_C000_018F
    call diagnostic_gate_C000_08DA
    jc   warm_path_C000_011F
    cli
    call restore_saved_context_C000_01C5
    jc   resume_failed_C000_018F
    mov  word [0x6809],0
    mov  ds,[0x6d73]
    mov  ss,[0x6d77]
    mov  sp,[0x6d7d]
    jmp  far [ss:0x6d79]
resume_failed_C000_018F:
    jmp  cold_start_C000_00E1

    jmp  warm_path_C000_011F

warm_resume_alt_C000_0194:
    call keyboard_scan_start_C000_1038
    sti
    call startup_buzzer_variant_C000_081F
    call diagnostic_gate_C000_08DA
    jc   C000:0192       ; retry warm path
    cli
    call restore_saved_context_C000_01C5
    jc   resume_failed_C000_018F
    mov  word [0x6809],0
    mov  ss,[0x6d77]
    mov  sp,[0x6d7d]
    mov  ax,[0x6d65]
    push word [0x6d7f]
    mov  ds,[0x6d73]
    popf
    jmp  far [ss:0x6d79]

; ---------------------------------------------------------------------------
; restore_saved_context_C000_01C5
;
; Verifies retained context checksum, restores bank windows 0x11..0x15 from
; low-RAM mirrors, optionally reinitializes serial, restores general registers,
; and returns carry clear on success.

restore_saved_context_C000_01C5:
    mov  ax,0
    mov  ds,ax
    mov  si,0x6d65
    mov  cx,0x000f
    cld
    xor  bx,bx
checksum_loop_C000_01D3:
    lodsw
    add  bx,ax
    loop checksum_loop_C000_01D3
    cmp  bx,[0x6d83]
    jz   restore_banks_C000_01E0
    stc
    ret

restore_banks_C000_01E0:
    mov  ax,[0x6d8d]
    out  0x12,al
    mov  al,ah
    out  0x11,al
    mov  ax,[0x6d8f]
    out  0x14,al
    mov  al,ah
    out  0x13,al
    mov  al,[0x6d91]
    out  0x15,al
    test byte [0x6d50],0x10
    jnz  restore_irq_latch_C000_0202
    call serial_init_C000_0C58
    cli
restore_irq_latch_C000_0202:
    mov  al,[0x6d4f]
    out  0x60,al
    mov  bx,[0x6d67]
    mov  cx,[0x6d69]
    mov  dx,[0x6d6b]
    mov  si,[0x6d6d]
    mov  di,[0x6d6f]
    mov  es,[0x6d75]
    mov  bp,[0x6d71]
    clc
    ret

; ---------------------------------------------------------------------------
; Bank helper seeds used by cold and warm startup.

seed_default_bank_mirrors_C000_0225:
    mov  ah,0x0e
    mov  al,0x1f
    mov  [0x6d8d],ax    ; restore 0x12=1F, 0x11=0E
    mov  ah,0x1e
    mov  al,0x1d
    mov  [0x6d8f],ax    ; restore 0x14=1D, 0x13=1E
    mov  al,0x1c
    mov  [0x6d91],al    ; restore 0x15=1C
    ret

; Dynamic storage/card window helper. Included here because it is the first
; banking abstraction reached from startup and later used by storage code.
map_dynamic_window_C000_0239:
    cmp  dx,0x6000
    jc   .range_0000_5fff
    cmp  dx,0x8000
    jc   .range_6000_7fff
    cmp  dx,0xa000
    jc   .range_8000_9fff
    cmp  dx,0xc000
    jc   .range_a000_bfff
    cmp  dx,0xe000
    jc   .range_c000_dfff
    mov  ah,0x18
    mov  al,0x18
    sub  dx,0xa000
    jmp  .commit
.range_0000_5fff:
    mov  ah,0x1d
    mov  al,0x1c
    jmp  .commit
.range_6000_7fff:
    mov  ah,0x1c
    mov  al,0x1b
    sub  dx,0x2000
    jmp  .commit
.range_8000_9fff:
    mov  ah,0x1b
    mov  al,0x1a
    sub  dx,0x4000
    jmp  .commit
.range_a000_bfff:
    mov  ah,0x1a
    mov  al,0x19
    sub  dx,0x6000
    jmp  .commit
.range_c000_dfff:
    mov  ah,0x19
    mov  al,0x18
    sub  dx,0x8000
.commit:
    push bx
    mov  bx,[0x6d8f]
    mov  bl,ah
    mov  [0x6d8f],bx
    pop  bx
    mov  [0x6d91],al
    out  0x15,al
    mov  al,ah
    out  0x14,al
    ret

clear_low_runtime_C000_02BE:
    call clear_framebuffer_C000_02DC
    mov  cx,0x94f0
    mov  di,0x6c06
    sub  cx,di
    rep  stosb          ; zero 6C06..94EF
    mov  di,0x2000
    mov  cx,0x3800
    rep  stosb          ; zero 2000..57FF
    mov  cx,0x0800
    mov  di,0x5800
    rep  stosw          ; zero 5800..67FF
    ret

clear_framebuffer_C000_02DC:
    mov  ax,0
    mov  es,ax
    mov  cx,0x0800
    mov  di,0x1000
    mov  ax,0
    cld
    rep  stosw          ; clear 4 KiB LCD framebuffer
    ret

; ---------------------------------------------------------------------------
; install_vectors_C000_0ED6
; file 0x40ED6
;
; This routine is reached before cold/warm branching completes. It seeds most
; interrupt vectors with C000:118B, installs IRQ roots, installs INT 21h, and
; copies the low-RAM far-call table from C000:0F94 to 0000:0200.

install_vectors_C000_0ED6:
    cld
    push es
    mov  bp,0
    mov  es,bp
    mov  bx,0xc000
    mov  dx,0x118b       ; default vector target

; Fill IVT vectors 00h..F7h with the default C000:118B IRET target. The
; explicit overrides below replace INT 1, INT 21h, and F8h..FFh.
    mov  di,0x0000
    mov  cx,0x0003       ; vectors 00h..02h
default_vector_fill_00_02_C000_0EE9:
    mov  ax,dx
    stosw
    mov  ax,bx
    stosw
    loop default_vector_fill_00_02_C000_0EE9
    mov  ax,dx           ; vector 03h
    stosw
    mov  ax,bx
    stosw
    mov  cx,0x0003       ; vectors 04h..06h
default_vector_fill_04_06_C000_0EFA:
    mov  ax,dx
    stosw
    mov  ax,bx
    stosw
    loop default_vector_fill_04_06_C000_0EFA
    mov  cx,0x0005       ; vectors 07h..0Bh
default_vector_fill_07_0B_C000_0F05:
    mov  ax,dx
    stosw
    mov  ax,bx
    stosw
    loop default_vector_fill_07_0B_C000_0F05
    mov  ax,dx           ; vector 0Ch
    stosw
    mov  ax,bx
    stosw
    mov  cx,0x0003       ; vectors 0Dh..0Fh
default_vector_fill_0D_0F_C000_0F16:
    mov  ax,dx
    stosw
    mov  ax,bx
    stosw
    loop default_vector_fill_0D_0F_C000_0F16
    mov  ax,dx           ; vector 10h
    stosw
    mov  ax,bx
    stosw
    mov  cx,0x00e7       ; vectors 11h..F7h
default_vector_fill_11_F7_C000_0F27:
    mov  ax,dx
    stosw
    mov  ax,bx
    stosw
    loop default_vector_fill_11_F7_C000_0F27

; Install IRQ vectors F8..FF at IVT offsets 03E0..03FF. The first four loop
; iterations install C000:0009, 000C, 000F, 0012; the subsequent stores install
; 0015, 0018, 001B, and 001E.
    mov  bx,0xc000
    mov  cx,0x0004
    mov  di,0x03e0
    mov  dx,0x0009
seed_irq_vector_loop_C000_0F3B:
    mov  ax,dx
    stosw
    mov  ax,bx
    stosw
    add  dx,byte +0x03
    loop seed_irq_vector_loop_C000_0F3B
    mov  ax,dx           ; vector FC -> C000:0015
    stosw
    mov  ax,bx
    stosw
    add  dx,byte +0x03
    mov  ax,dx           ; vector FD -> C000:0018
    stosw
    mov  ax,bx
    stosw
    add  dx,byte +0x03
    mov  cx,0x0002
seed_irq_vector_tail_C000_0F5B:
    mov  ax,dx           ; FE, FF
    stosw
    mov  ax,bx
    stosw
    add  dx,byte +0x03
    loop seed_irq_vector_tail_C000_0F5B

; Install INT 21h at IVT offset 0x84.
    mov  ax,0x0006
    mov  di,0x0084
    stosw
    mov  ax,bx
    stosw

; Install INT 1 at IVT offset 0x04 for diagnostics/single-step.
    mov  ax,0x157d
    mov  di,0x0004
    stosw
    mov  ax,0xc000
    stosw

; Copy low-RAM far-call table C000:0F94..1037 to 0000:0200.
    push ds
    mov  di,0x0200
    mov  ax,ds          ; DS is zero from startup caller
    mov  es,ax
    mov  si,0x0f94
    mov  ax,0xc000
    mov  ds,ax
    mov  cx,0x0052
    nop
    rep  movsw
    pop  ds
    pop  es
    ret

seed_low_ram_far_call_table_C000_0F94:
; Data table, not code. Copied to 0000:0200 by install_vectors_C000_0ED6
; and decoded in low-ram-abi.md.
