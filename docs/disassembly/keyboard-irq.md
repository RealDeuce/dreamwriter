# Keyboard IRQ Roots

This slice follows the installed `F9h`, `FAh`, and `FBh` IRQ roots from
[`installed-vectors.md`](installed-vectors.md). `F9h` is a short wake/timer
acknowledge path. `FAh` and `FBh` form the keyboard scan-cycle and row-scan
sequence.

No image assets are reached in this slice.

## IRQ F9 Timer/Wake Acknowledge

```asm
seed_irq_f9_stub:
; file 0x4000C
C000:000C  E9 8B 04          jmp  irq_f9_timer_ack_C000_049A
```

The handler clears port `0x90` bit `0x40` and clears `[6DA9] bit 0x01`. The
same software bit is also cleared by the explicit timer disarm helper
`C000:0B50`, so this root is treated as a timer/wake acknowledge source rather
than keyboard-row processing.

```asm
irq_f9_timer_ack_C000_049A:
; file 0x4049A
C000:049A  50                push ax
C000:049B  1E                push ds
C000:049C  B8 00 00          mov  ax,0
C000:049F  8E D8             mov  ds,ax
C000:04A1  B0 40             mov  al,0x40
C000:04A3  E6 90             out  0x90,al
C000:04A5  80 26 A9 6D FE    and  byte [0x6da9],0xfe
C000:04AA  1F                pop  ds
C000:04AB  58                pop  ax
C000:04AC  FB                sti
C000:04AD  CF                iret
```

## IRQ FA Scan-Cycle Reset

```asm
seed_irq_fa_stub:
; file 0x4000F
C000:000F  E9 9C 04          jmp  irq_fa_keyboard_scan_cycle_C000_04AE
```

`FAh` sets port `0x60` mirror bit `0x04`, clears IRQ source bit `0x20`, resets
the scan idle/state byte `[6D28]`, and calls `C000:106F` to start a new row
scan.

```asm
irq_fa_keyboard_scan_cycle_C000_04AE:
; file 0x404AE
C000:04AE  50                push ax
C000:04AF  53                push bx
C000:04B0  1E                push ds
C000:04B1  B8 00 00          mov  ax,0
C000:04B4  8E D8             mov  ds,ax
C000:04B6  80 0E 4F 6D 04    or   byte [0x6d4f],0x04
C000:04BB  A0 4F 6D          mov  al,[0x6d4f]
C000:04BE  E6 60             out  0x60,al
C000:04C0  B0 20             mov  al,0x20
C000:04C2  E6 90             out  0x90,al
C000:04C4  C6 06 28 6D 00    mov  byte [0x6d28],0
C000:04C9  E8 A3 0B          call keyboard_scan_reset_C000_106F
C000:04CC  1F                pop  ds
C000:04CD  5B                pop  bx
C000:04CE  58                pop  ax
C000:04CF  FB                sti
C000:04D0  CF                iret
```

The scan reset helper clears port `0x60` mirror bit `0x08`, dummy-reads the row
port, pulses port `0x61` from `0xFE` to `0xFF`, and clears row index `[6D29]`.

```asm
keyboard_scan_reset_C000_106F:
; file 0x4106F
C000:106F  80 26 4F 6D F7    and  byte [0x6d4f],0xf7
C000:1074  A0 4F 6D          mov  al,[0x6d4f]
C000:1077  E6 60             out  0x60,al
C000:1079  E4 B0             in   al,0xb0
C000:107B  B0 FE             mov  al,0xfe
C000:107D  E6 61             out  0x61,al
C000:107F  B0 FF             mov  al,0xff
C000:1081  E6 61             out  0x61,al
C000:1083  C6 06 29 6D 00    mov  byte [0x6d29],0
C000:1088  C3                ret
```

## IRQ FB Row Scan

```asm
seed_irq_fb_stub:
; file 0x40012
C000:0012  E9 BC 04          jmp  irq_fb_keyboard_row_C000_04D1
```

`FBh` reads one row from port `0xB0`, stores it at `6D06 + [6D29]`, and advances
the row index. A completed ten-row scan calls the larger row processor at
`C000:5645`.

```asm
irq_fb_keyboard_row_C000_04D1:
; file 0x404D1
C000:04D1  50                push ax
C000:04D2  53                push bx
C000:04D3  1E                push ds
C000:04D4  B8 00 00          mov  ax,0
C000:04D7  8E D8             mov  ds,ax
C000:04D9  B0 10             mov  al,0x10
C000:04DB  E6 90             out  0x90,al
C000:04DD  8A 1E 29 6D       mov  bl,[0x6d29]
C000:04E1  32 FF             xor  bh,bh
C000:04E3  E4 B0             in   al,0xb0
C000:04E5  0A C0             or   al,al
C000:04E7  74 05             jz   C000:04EE
C000:04E9  80 0E 28 6D 80    or   byte [0x6d28],0x80
C000:04EE  88 87 06 6D       mov  [bx+0x6d06],al
C000:04F2  FE 06 29 6D       inc  byte [0x6d29]
C000:04F6  80 3E 29 6D 0A    cmp  byte [0x6d29],0x0a
C000:04FB  75 CF             jnz  irq_fa_return_C000_04CC
```

If no row in a completed scan was active, `[6D28]` increments as an idle-scan
counter. After ten empty scans, the firmware writes `0xFE` to port `0x61`,
clears port `0x60` bit `0x04`, sets bit `0x08`, and returns to the scan-cycle
source.

```asm
C000:04FD  F6 06 28 6D 80    test byte [0x6d28],0x80
C000:0502  75 20             jnz  active_scan_C000_0524
C000:0504  FE 06 28 6D       inc  byte [0x6d28]
C000:0508  80 3E 28 6D 0A    cmp  byte [0x6d28],0x0a
C000:050D  75 1A             jnz  complete_scan_C000_0529
C000:050F  B0 FE             mov  al,0xfe
C000:0511  E6 61             out  0x61,al
C000:0513  80 26 4F 6D FB    and  byte [0x6d4f],0xfb
C000:0518  80 0E 4F 6D 08    or   byte [0x6d4f],0x08
C000:051D  A0 4F 6D          mov  al,[0x6d4f]
C000:0520  E6 60             out  0x60,al
C000:0522  EB A8             jmp  irq_fa_return_C000_04CC

active_scan_C000_0524:
C000:0524  C6 06 28 6D 00    mov  byte [0x6d28],0
```

At the full-scan boundary, the handler resets `[6D29]`, temporarily enables
interrupts, calls the row processor, then restores the port `0x60` mirror.

```asm
complete_scan_C000_0529:
C000:0529  C6 06 29 6D 00    mov  byte [0x6d29],0
C000:052E  06                push es
C000:052F  51                push cx
C000:0530  52                push dx
C000:0531  56                push si
C000:0532  57                push di
C000:0533  55                push bp
C000:0534  A0 4F 6D          mov  al,[0x6d4f]
C000:0537  0C 01             or   al,0x01
C000:0539  E6 60             out  0x60,al
C000:053B  FB                sti
C000:053C  E8 06 51          call keyboard_row_processor_C000_5645
C000:053F  FA                cli
C000:0540  A0 4F 6D          mov  al,[0x6d4f]
C000:0543  E6 60             out  0x60,al
C000:0545  5D                pop  bp
C000:0546  5F                pop  di
C000:0547  5E                pop  si
C000:0548  5A                pop  dx
C000:0549  59                pop  cx
C000:054A  07                pop  es
C000:054B  1F                pop  ds
C000:054C  5B                pop  bx
C000:054D  58                pop  ax
C000:054E  FB                sti
C000:054F  CF                iret
```

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6D06..6D0F` | Raw ten-row keyboard matrix cache. |
| `6D28` | Scan state/idle counter; bit `0x80` marks activity during the current full scan. |
| `6D29` | Current row index, reset after ten rows. |
| `6D4F` | Port `0x60` mirror used to switch scan-cycle and row-scan sources. |

The row processor and foreground key services are expanded in
[`keyboard-services.md`](keyboard-services.md). Timer latch programming is
expanded in [`timer-wake.md`](timer-wake.md).
