# Boot Slice

DreamWriter T400 v2.1 annotated boot disassembly.

Source image: `t4_ir_2.1.ic303`, sha256 in `tools/rom2.py`.

This file follows reachable startup code depth-first from reset until the
firmware either reaches the application runtime, resumes a retained context, or
installs independent roots that are tracked in `README.md`.

This is an annotated listing, not NASM source. Keep raw bytes for V20-only or
ambiguous instructions instead of rewriting them into unsupported mnemonics.

```asm

; ---------------------------------------------------------------------------
; root_reset_vector
; file 0x7FFF0, CPU physical 0xFFFF0
;
; Reset begins at FFFF:0000 and jumps to F8DC:0000. The vector bytes are
; documented in docs/banking.md; the trampoline itself is below.

root_reset_trampoline:
; file 0x78DC0, CPU F8DC:0000
; Establish the normal high ROM windows before entering C000 startup.
F8DC:0000  B0 01             mov  al,0x01
F8DC:0002  E6 16             out  0x16,al      ; C0000..DFFFF -> ROM file 40000..5FFFF
F8DC:0004  B0 00             mov  al,0x00
F8DC:0006  E6 17             out  0x17,al      ; E0000..FFFFF -> ROM file 60000..7FFFF
F8DC:0008  EA 00 00 00 C0    jmp  C000:0000

; ---------------------------------------------------------------------------
; root_c000_segment_head
; file 0x40000, CPU C000:0000
;
; The segment begins with a jump over service stubs and IRQ stubs. Startup
; later copies selected stubs into the IVT via install_vectors_C000_0ED6.

root_c000_entry:
C000:0000  EB 27             jmp  short startup_C000_0029
C000:0002  90                nop
C000:0003  00 00             ; data/padding
C000:0005  00                ; data/padding

seed_int21_vector_target:
C000:0006  E9 8F 50          jmp  int21_dispatch_C000_5098

seed_irq_f8_stub:
C000:0009  E9 A2 03          jmp  irq_f8_save_suspend_C000_03AE
seed_irq_f9_stub:
C000:000C  E9 8B 04          jmp  irq_f9_timer_ack_C000_049A
seed_irq_fa_stub:
C000:000F  E9 9C 04          jmp  irq_fa_keyboard_scan_cycle_C000_04AE
seed_irq_fb_stub:
C000:0012  E9 BC 04          jmp  irq_fb_keyboard_row_C000_04D1
seed_irq_fc_stub:
C000:0015  E9 38 05          jmp  irq_fc_serial_rx_C000_0550
seed_irq_fd_stub:
C000:0018  E9 09 07          jmp  irq_fd_serial_tx_ack_C000_0724
seed_irq_fe_stub:
C000:001B  E9 1A 07          jmp  irq_fe_centronics_ack_C000_0738
seed_irq_ff_stub:
C000:001E  E9 CD 02          jmp  irq_ff_warm_power_C000_02EE

; Far wrappers near the segment head. The first is the preserved-state front
; end for the `C000:170E` service table; the second dispatches the `C000:1712`
; service table, including the `D59C` resource reader at `C000:18EE`.
C000:0021  E8 F2 16          call C000:1716      ; C000:170E service-table body
C000:0024  CB                retf
C000:0025  E8 4B 18          call C000:1873      ; C000:1712 service-table body
C000:0028  CB                retf

; ---------------------------------------------------------------------------
; startup_C000_0029
; file 0x40029
;
; This is the normal cold/warm startup entry after reset trampoline banking.

startup_C000_0029:
C000:0029  B0 FF             mov  al,0xff
C000:002B  E6 90             out  0x90,al       ; clear all currently active IRQ bits

; Select the baseline memory map.
C000:002D  B0 17             mov  al,0x17
C000:002F  E6 10             out  0x10,al       ; RAM page/window for 00000..1FFFF
C000:0031  B0 0E             mov  al,0x0e
C000:0033  E6 11             out  0x11,al       ; upper internal RAM at 20000..3FFFF
C000:0035  B0 1F             mov  al,0x1f
C000:0037  E6 12             out  0x12,al
C000:0039  B0 1E             mov  al,0x1e
C000:003B  E6 13             out  0x13,al
C000:003D  B0 1D             mov  al,0x1d
C000:003F  E6 14             out  0x14,al
C000:0041  B0 1C             mov  al,0x1c
C000:0043  E6 15             out  0x15,al
C000:0045  B0 01             mov  al,0x01
C000:0047  E6 16             out  0x16,al       ; keep C000 segment mapped to ROM file 40000
C000:0049  B0 00             mov  al,0x00
C000:004B  E6 17             out  0x17,al       ; keep high ROM mapped to ROM file 60000

; Basic peripheral state.
C000:004D  B0 F8             mov  al,0xf8
C000:004F  E6 DD             out  0xdd,al       ; RP5C01 mode/timer state
C000:0051  B0 F0             mov  al,0xf0
C000:0053  E6 DE             out  0xde,al       ; RP5C01 control state
C000:0055  B0 08             mov  al,0x08
C000:0057  E6 00             out  0x00,al       ; LCD scanout base = 0x1000
C000:0059  B0 00             mov  al,0x00
C000:005B  E6 20             out  0x20,al       ; unknown/monitor handshake cleared

; Establish flat low-RAM segments and initial stack.
C000:005D  BC 06 6C          mov  sp,0x6c06
C000:0060  B8 00 00          mov  ax,0x0000
C000:0063  8E D0             mov  ss,ax
C000:0065  8E D8             mov  ds,ax
C000:0067  8E C0             mov  es,ax
C000:0069  33 C0             xor  ax,ax
C000:006B  A2 E7 70          mov  [0x70e7],al
C000:006E  A2 36 70          mov  [0x7036],al
C000:0071  A3 A5 6D          mov  [0x6da5],ax
C000:0074  40                inc  ax
C000:0075  A3 09 68          mov  [0x6809],ax    ; early state marker = 1
C000:0078  B0 5F             mov  al,0x5f
C000:007A  A2 94 6D          mov  [0x6d94],al    ; port 0x30 mirror default
C000:007D  B0 FF             mov  al,0xff
C000:007F  E6 40             out  0x40,al       ; Centronics data idle
C000:0081  B0 FF             mov  al,0xff
C000:0083  E6 60             out  0x60,al       ; IRQ/source latch idle
C000:0085  C6 06 05 68 48    mov  byte [0x6805],0x48

; Seed later roots, then enter early hardware/app validation.
C000:008A  E8 49 0E          call install_vectors_C000_0ED6
C000:008D  E8 AB 07          call battery_startup_gate_C000_083B ; main-battery startup gate
C000:0090  9A 53 00 88 C6    call C688:0053      ; retained/warm RAM signature check
C000:0095  72 4A             jc   cold_start_C000_00E1
C000:0097  E8 39 47          call C000:47D3      ; retained date/time/serial/printer validation
C000:009A  72 45             jc   cold_start_C000_00E1

; Warm/resume decision. The exact retained-state values are tracked in
; docs/hardware.md and docs/entry-points.md; branches are left as skeleton
; until the resume path is expanded.
C000:009C  F6 06 51 6D 01    test byte [0x6d51],0x01
C000:00A1  9C                pushf
C000:00A2  80 26 51 6D FE    and  byte [0x6d51],0xfe
C000:00A7  9D                popf
C000:00A8  75 75             jnz  warm_path_C000_011F
C000:00AA  A1 79 6D          mov  ax,[0x6d79]    ; saved return offset
C000:00AD  0B C0             or   ax,ax
C000:00AF  74 12             jz   retained_target_default_C000_00C3
C000:00B1  3D 8D 4A          cmp  ax,0x4a8d
C000:00B4  74 0D             jz   retained_target_default_C000_00C3
C000:00B6  3D 77 49          cmp  ax,0x4977
C000:00B9  74 08             jz   retained_target_default_C000_00C3
C000:00BB  3D FD 49          cmp  ax,0x49fd
C000:00BE  74 03             jz   retained_target_default_C000_00C3
C000:00C0  E9 D1 00          jmp  warm_resume_alt_C000_0194

retained_target_default_C000_00C3:
C000:00C3  8B D8             mov  bx,ax
C000:00C5  8C C8             mov  ax,cs
C000:00C7  3B 06 7B 6D       cmp  ax,[0x6d7b]    ; saved return segment
C000:00CB  75 14             jnz  cold_start_C000_00E1
C000:00CD  0B DB             or   bx,bx
C000:00CF  75 06             jnz  retained_marker_check_C000_00D7
C000:00D1  C7 06 81 6D 95 19 mov  word [0x6d81],0x1995
retained_marker_check_C000_00D7:
C000:00D7  A1 81 6D          mov  ax,[0x6d81]
C000:00DA  0B C0             or   ax,ax
C000:00DC  75 41             jnz  warm_path_C000_011F
C000:00DE  E9 80 00          jmp  clean_resume_C000_0161

; ---------------------------------------------------------------------------
; cold_start_C000_00E1
;
; Reinitializes volatile state, validates/formats built-in storage if needed,
; then enters the C688 application runtime at C688:000B.

cold_start_C000_00E1:
C000:00E1  C7 06 81 6D 00 00 mov  word [0x6d81],0
C000:00E7  B0 FF             mov  al,0xff
C000:00E9  E6 60             out  0x60,al
C000:00EB  A2 4F 6D          mov  [0x6d4f],al
C000:00EE  E8 34 01          call seed_default_bank_mirrors_C000_0225
C000:00F1  E8 CA 01          call clear_low_runtime_C000_02BE
C000:00F4  E8 AB 59          call display_keyboard_state_init_C000_5AA2
C000:00F7  E8 2B 07          call startup_buzzer_resource_C000_0825
C000:00FA  E8 14 47          call C000:4811      ; built-in store validate/format path
C000:00FD  9A 9E 53 98 DC    call DC98:539E      ; organizer/menu subsystem initializer
C000:0102  E8 9E 01          call C000:02A3      ; banked spell/service init pair
C000:0105  BC 00 10          mov  sp,0x1000
C000:0108  C7 06 09 68 00 00 mov  word [0x6809],0
C000:010E  B8 4F 0A          mov  ax,0x0a4f
C000:0111  8E C0             mov  es,ax
C000:0113  E8 A5 3B          call open_file_table_init_C000_3CBB
C000:0116  E8 1F 0F          call keyboard_scan_start_C000_1038
C000:0119  FB                sti
C000:011A  EA 0B 00 88 C6    jmp  C688:000B      ; cold app/runtime entry root

; ---------------------------------------------------------------------------
; warm_path_C000_011F
;
; Restores bank defaults, stack, keyboard scan, alarm/diagnostic gates, then
; either resumes runtime or falls back to cold_start_C000_00E1.

warm_path_C000_011F:
C000:011F  E8 03 01          call seed_default_bank_mirrors_C000_0225
C000:0122  BC 00 10          mov  sp,0x1000
C000:0125  B8 4F 0A          mov  ax,0x0a4f
C000:0128  8E C0             mov  es,ax
C000:012A  E8 0B 0F          call keyboard_scan_start_C000_1038
C000:012D  FB                sti
C000:012E  06                push es
C000:012F  E8 AA 01          call clear_framebuffer_C000_02DC
C000:0132  07                pop  es
C000:0133  E8 D1 06          call alarm_wake_wrapper_C000_0807
C000:0136  80 3E 54 6D 00    cmp  byte [0x6d54],0
C000:013B  75 05             jnz  warm_diag_gate_C000_0142
C000:013D  E8 73 01          call C000:02B3      ; banked spell reset/check
C000:0140  75 9F             jnz  cold_start_C000_00E1
warm_diag_gate_C000_0142:
C000:0142  E8 95 07          call diagnostic_gate_C000_08DA
C000:0145  C7 06 09 68 00 00 mov  word [0x6809],0
C000:014B  81 3E 81 6D 95 19 cmp  word [0x6d81],0x1995
C000:0151  C7 06 81 6D 00 00 mov  word [0x6d81],0
C000:0157  74 C1             jz   C000:011A
C000:0159  E8 5F 3B          call open_file_table_init_C000_3CBB
C000:015C  EA 0F 00 88 C6    jmp  C688:000F      ; warm app/runtime entry root

clean_resume_C000_0161:
C000:0161  E8 D4 0E          call keyboard_scan_start_C000_1038
C000:0164  FB                sti
C000:0165  E8 9F 06          call alarm_wake_wrapper_C000_0807
C000:0168  E8 48 01          call C000:02B3      ; banked spell reset/check
C000:016B  75 22             jnz  resume_failed_C000_018F
C000:016D  E8 6A 07          call diagnostic_gate_C000_08DA
C000:0170  72 AD             jc   warm_path_C000_011F
C000:0172  FA                cli
C000:0173  E8 4F 00          call restore_saved_context_C000_01C5
C000:0176  72 17             jc   resume_failed_C000_018F
C000:0178  C7 06 09 68 00 00 mov  word [0x6809],0
C000:017E  8E 1E 73 6D       mov  ds,[0x6d73]
C000:0182  8E 16 77 6D       mov  ss,[0x6d77]
C000:0186  8B 26 7D 6D       mov  sp,[0x6d7d]
C000:018A  36 FF 2E 79 6D    jmp  far [ss:0x6d79]
resume_failed_C000_018F:
C000:018F  E9 4F FF          jmp  cold_start_C000_00E1

C000:0192  EB 8B             jmp  warm_path_C000_011F

warm_resume_alt_C000_0194:
C000:0194  E8 A1 0E          call keyboard_scan_start_C000_1038
C000:0197  FB                sti
C000:0198  E8 84 06          call startup_buzzer_variant_C000_081F
C000:019B  E8 3C 07          call diagnostic_gate_C000_08DA
C000:019E  72 F2             jc   C000:0192      ; retry warm path
C000:01A0  FA                cli
C000:01A1  E8 21 00          call restore_saved_context_C000_01C5
C000:01A4  72 E9             jc   resume_failed_C000_018F
C000:01A6  C7 06 09 68 00 00 mov  word [0x6809],0
C000:01AC  8E 16 77 6D       mov  ss,[0x6d77]
C000:01B0  8B 26 7D 6D       mov  sp,[0x6d7d]
C000:01B4  A1 65 6D          mov  ax,[0x6d65]
C000:01B7  FF 36 7F 6D       push word [0x6d7f]
C000:01BB  8E 1E 73 6D       mov  ds,[0x6d73]
C000:01BF  9D                popf
C000:01C0  36 FF 2E 79 6D    jmp  far [ss:0x6d79]

; ---------------------------------------------------------------------------
; restore_saved_context_C000_01C5
;
; Verifies retained context checksum, restores bank windows 0x11..0x15 from
; low-RAM mirrors, optionally reinitializes serial, restores general registers,
; and returns carry clear on success.

restore_saved_context_C000_01C5:
C000:01C5  B8 00 00          mov  ax,0
C000:01C8  8E D8             mov  ds,ax
C000:01CA  BE 65 6D          mov  si,0x6d65
C000:01CD  B9 0F 00          mov  cx,0x000f
C000:01D0  FC                cld
C000:01D1  33 DB             xor  bx,bx
checksum_loop_C000_01D3:
C000:01D3  AD                lodsw
C000:01D4  03 D8             add  bx,ax
C000:01D6  E2 FB             loop checksum_loop_C000_01D3
C000:01D8  3B 1E 83 6D       cmp  bx,[0x6d83]
C000:01DC  74 02             jz   restore_banks_C000_01E0
C000:01DE  F9                stc
C000:01DF  C3                ret

restore_banks_C000_01E0:
C000:01E0  A1 8D 6D          mov  ax,[0x6d8d]
C000:01E3  E6 12             out  0x12,al
C000:01E5  8A C4             mov  al,ah
C000:01E7  E6 11             out  0x11,al
C000:01E9  A1 8F 6D          mov  ax,[0x6d8f]
C000:01EC  E6 14             out  0x14,al
C000:01EE  8A C4             mov  al,ah
C000:01F0  E6 13             out  0x13,al
C000:01F2  A0 91 6D          mov  al,[0x6d91]
C000:01F5  E6 15             out  0x15,al
C000:01F7  F6 06 50 6D 10    test byte [0x6d50],0x10
C000:01FC  75 04             jnz  restore_irq_latch_C000_0202
C000:01FE  E8 57 0A          call serial_init_C000_0C58
C000:0201  FA                cli
restore_irq_latch_C000_0202:
C000:0202  A0 4F 6D          mov  al,[0x6d4f]
C000:0205  E6 60             out  0x60,al
C000:0207  8B 1E 67 6D       mov  bx,[0x6d67]
C000:020B  8B 0E 69 6D       mov  cx,[0x6d69]
C000:020F  8B 16 6B 6D       mov  dx,[0x6d6b]
C000:0213  8B 36 6D 6D       mov  si,[0x6d6d]
C000:0217  8B 3E 6F 6D       mov  di,[0x6d6f]
C000:021B  8E 06 75 6D       mov  es,[0x6d75]
C000:021F  8B 2E 71 6D       mov  bp,[0x6d71]
C000:0223  F8                clc
C000:0224  C3                ret

; ---------------------------------------------------------------------------
; Bank helper seeds used by cold and warm startup.

seed_default_bank_mirrors_C000_0225:
C000:0225  B4 0E             mov  ah,0x0e
C000:0227  B0 1F             mov  al,0x1f
C000:0229  A3 8D 6D          mov  [0x6d8d],ax    ; restore 0x12=1F, 0x11=0E
C000:022C  B4 1E             mov  ah,0x1e
C000:022E  B0 1D             mov  al,0x1d
C000:0230  A3 8F 6D          mov  [0x6d8f],ax    ; restore 0x14=1D, 0x13=1E
C000:0233  B0 1C             mov  al,0x1c
C000:0235  A2 91 6D          mov  [0x6d91],al    ; restore 0x15=1C
C000:0238  C3                ret

; Dynamic storage/card window helper. Included here because it is the first
; banking abstraction reached from startup and later used by storage code.
map_dynamic_window_C000_0239:
C000:0239  81 FA 00 60       cmp  dx,0x6000
C000:023D  72 22             jc   .range_0000_5fff
C000:023F  81 FA 00 80       cmp  dx,0x8000
C000:0243  72 22             jc   .range_6000_7fff
C000:0245  81 FA 00 A0       cmp  dx,0xa000
C000:0249  72 26             jc   .range_8000_9fff
C000:024B  81 FA 00 C0       cmp  dx,0xc000
C000:024F  72 2A             jc   .range_a000_bfff
C000:0251  81 FA 00 E0       cmp  dx,0xe000
C000:0255  72 2E             jc   .range_c000_dfff
C000:0257  B4 18             mov  ah,0x18
C000:0259  B0 18             mov  al,0x18
C000:025B  81 EA 00 A0       sub  dx,0xa000
C000:025F  EB 2C             jmp  .commit
.range_0000_5fff:
C000:0261  B4 1D             mov  ah,0x1d
C000:0263  B0 1C             mov  al,0x1c
C000:0265  EB 26             jmp  .commit
.range_6000_7fff:
C000:0267  B4 1C             mov  ah,0x1c
C000:0269  B0 1B             mov  al,0x1b
C000:026B  81 EA 00 20       sub  dx,0x2000
C000:026F  EB 1C             jmp  .commit
.range_8000_9fff:
C000:0271  B4 1B             mov  ah,0x1b
C000:0273  B0 1A             mov  al,0x1a
C000:0275  81 EA 00 40       sub  dx,0x4000
C000:0279  EB 12             jmp  .commit
.range_a000_bfff:
C000:027B  B4 1A             mov  ah,0x1a
C000:027D  B0 19             mov  al,0x19
C000:027F  81 EA 00 60       sub  dx,0x6000
C000:0283  EB 08             jmp  .commit
.range_c000_dfff:
C000:0285  B4 19             mov  ah,0x19
C000:0287  B0 18             mov  al,0x18
C000:0289  81 EA 00 80       sub  dx,0x8000
.commit:
C000:028D  53                push bx
C000:028E  8B 1E 8F 6D       mov  bx,[0x6d8f]
C000:0292  8A DC             mov  bl,ah
C000:0294  89 1E 8F 6D       mov  [0x6d8f],bx
C000:0298  5B                pop  bx
C000:0299  A2 91 6D          mov  [0x6d91],al
C000:029C  E6 15             out  0x15,al
C000:029E  8A C4             mov  al,ah
C000:02A0  E6 14             out  0x14,al
C000:02A2  C3                ret

clear_low_runtime_C000_02BE:
C000:02BE  E8 1B 00          call clear_framebuffer_C000_02DC
C000:02C1  B9 F0 94          mov  cx,0x94f0
C000:02C4  BF 06 6C          mov  di,0x6c06
C000:02C7  2B CF             sub  cx,di
C000:02C9  F3 AA             rep  stosb          ; zero 6C06..94EF
C000:02CB  BF 00 20          mov  di,0x2000
C000:02CE  B9 00 38          mov  cx,0x3800
C000:02D1  F3 AA             rep  stosb          ; zero 2000..57FF
C000:02D3  B9 00 08          mov  cx,0x0800
C000:02D6  BF 00 58          mov  di,0x5800
C000:02D9  F3 AB             rep  stosw          ; zero 5800..67FF
C000:02DB  C3                ret

clear_framebuffer_C000_02DC:
C000:02DC  B8 00 00          mov  ax,0
C000:02DF  8E C0             mov  es,ax
C000:02E1  B9 00 08          mov  cx,0x0800
C000:02E4  BF 00 10          mov  di,0x1000
C000:02E7  B8 00 00          mov  ax,0
C000:02EA  FC                cld
C000:02EB  F3 AB             rep  stosw          ; clear 4 KiB LCD framebuffer
C000:02ED  C3                ret

; ---------------------------------------------------------------------------
; install_vectors_C000_0ED6
; file 0x40ED6
;
; This routine is reached before cold/warm branching completes. It seeds most
; interrupt vectors with C000:118B, installs IRQ roots, installs INT 21h, and
; copies the low-RAM far-call table from C000:0F94 to 0000:0200.

install_vectors_C000_0ED6:
C000:0ED6  FC                cld
C000:0ED7  06                push es
C000:0ED8  BD 00 00          mov  bp,0
C000:0EDB  8E C5             mov  es,bp
C000:0EDD  BB 00 C0          mov  bx,0xc000
C000:0EE0  BA 8B 11          mov  dx,0x118b       ; default vector target

; Fill IVT vectors 00h..F7h with the default C000:118B IRET target. The
; explicit overrides below replace INT 1, INT 21h, and F8h..FFh.
C000:0EE3  BF 00 00          mov  di,0x0000
C000:0EE6  B9 03 00          mov  cx,0x0003       ; vectors 00h..02h
default_vector_fill_00_02_C000_0EE9:
C000:0EE9  8B C2             mov  ax,dx
C000:0EEB  AB                stosw
C000:0EEC  8B C3             mov  ax,bx
C000:0EEE  AB                stosw
C000:0EEF  E2 F8             loop default_vector_fill_00_02_C000_0EE9
C000:0EF1  8B C2             mov  ax,dx           ; vector 03h
C000:0EF3  AB                stosw
C000:0EF4  8B C3             mov  ax,bx
C000:0EF6  AB                stosw
C000:0EF7  B9 03 00          mov  cx,0x0003       ; vectors 04h..06h
default_vector_fill_04_06_C000_0EFA:
C000:0EFA  8B C2             mov  ax,dx
C000:0EFC  AB                stosw
C000:0EFD  8B C3             mov  ax,bx
C000:0EFF  AB                stosw
C000:0F00  E2 F8             loop default_vector_fill_04_06_C000_0EFA
C000:0F02  B9 05 00          mov  cx,0x0005       ; vectors 07h..0Bh
default_vector_fill_07_0B_C000_0F05:
C000:0F05  8B C2             mov  ax,dx
C000:0F07  AB                stosw
C000:0F08  8B C3             mov  ax,bx
C000:0F0A  AB                stosw
C000:0F0B  E2 F8             loop default_vector_fill_07_0B_C000_0F05
C000:0F0D  8B C2             mov  ax,dx           ; vector 0Ch
C000:0F0F  AB                stosw
C000:0F10  8B C3             mov  ax,bx
C000:0F12  AB                stosw
C000:0F13  B9 03 00          mov  cx,0x0003       ; vectors 0Dh..0Fh
default_vector_fill_0D_0F_C000_0F16:
C000:0F16  8B C2             mov  ax,dx
C000:0F18  AB                stosw
C000:0F19  8B C3             mov  ax,bx
C000:0F1B  AB                stosw
C000:0F1C  E2 F8             loop default_vector_fill_0D_0F_C000_0F16
C000:0F1E  8B C2             mov  ax,dx           ; vector 10h
C000:0F20  AB                stosw
C000:0F21  8B C3             mov  ax,bx
C000:0F23  AB                stosw
C000:0F24  B9 E7 00          mov  cx,0x00e7       ; vectors 11h..F7h
default_vector_fill_11_F7_C000_0F27:
C000:0F27  8B C2             mov  ax,dx
C000:0F29  AB                stosw
C000:0F2A  8B C3             mov  ax,bx
C000:0F2C  AB                stosw
C000:0F2D  E2 F8             loop default_vector_fill_11_F7_C000_0F27

; Install IRQ vectors F8..FF at IVT offsets 03E0..03FF. The first four loop
; iterations install C000:0009, 000C, 000F, 0012; the subsequent stores install
; 0015, 0018, 001B, and 001E.
C000:0F2F  BB 00 C0          mov  bx,0xc000
C000:0F32  B9 04 00          mov  cx,0x0004
C000:0F35  BF E0 03          mov  di,0x03e0
C000:0F38  BA 09 00          mov  dx,0x0009
seed_irq_vector_loop_C000_0F3B:
C000:0F3B  8B C2             mov  ax,dx
C000:0F3D  AB                stosw
C000:0F3E  8B C3             mov  ax,bx
C000:0F40  AB                stosw
C000:0F41  83 C2 03          add  dx,byte +0x03
C000:0F44  E2 F5             loop seed_irq_vector_loop_C000_0F3B
C000:0F46  8B C2             mov  ax,dx           ; vector FC -> C000:0015
C000:0F48  AB                stosw
C000:0F49  8B C3             mov  ax,bx
C000:0F4B  AB                stosw
C000:0F4C  83 C2 03          add  dx,byte +0x03
C000:0F4F  8B C2             mov  ax,dx           ; vector FD -> C000:0018
C000:0F51  AB                stosw
C000:0F52  8B C3             mov  ax,bx
C000:0F54  AB                stosw
C000:0F55  83 C2 03          add  dx,byte +0x03
C000:0F58  B9 02 00          mov  cx,0x0002
seed_irq_vector_tail_C000_0F5B:
C000:0F5B  8B C2             mov  ax,dx           ; FE, FF
C000:0F5D  AB                stosw
C000:0F5E  8B C3             mov  ax,bx
C000:0F60  AB                stosw
C000:0F61  83 C2 03          add  dx,byte +0x03
C000:0F64  E2 F5             loop seed_irq_vector_tail_C000_0F5B

; Install INT 21h at IVT offset 0x84.
C000:0F66  B8 06 00          mov  ax,0x0006
C000:0F69  BF 84 00          mov  di,0x0084
C000:0F6C  AB                stosw
C000:0F6D  8B C3             mov  ax,bx
C000:0F6F  AB                stosw

; Install INT 1 at IVT offset 0x04 for diagnostics/single-step.
C000:0F70  B8 7D 15          mov  ax,0x157d
C000:0F73  BF 04 00          mov  di,0x0004
C000:0F76  AB                stosw
C000:0F77  B8 00 C0          mov  ax,0xc000
C000:0F7A  AB                stosw

; Copy low-RAM far-call table C000:0F94..1037 to 0000:0200.
C000:0F7B  1E                push ds
C000:0F7C  BF 00 02          mov  di,0x0200
C000:0F7F  8C D8             mov  ax,ds          ; DS is zero from startup caller
C000:0F81  8E C0             mov  es,ax
C000:0F83  BE 94 0F          mov  si,0x0f94
C000:0F86  B8 00 C0          mov  ax,0xc000
C000:0F89  8E D8             mov  ds,ax
C000:0F8B  B9 52 00          mov  cx,0x0052
C000:0F8E  90                nop
C000:0F8F  F3 A5             rep  movsw
C000:0F91  1F                pop  ds
C000:0F92  07                pop  es
C000:0F93  C3                ret

seed_low_ram_far_call_table_C000_0F94:
; Data table, not code. Copied to 0000:0200 by install_vectors_C000_0ED6
; and decoded in low-ram-abi.md.
```
