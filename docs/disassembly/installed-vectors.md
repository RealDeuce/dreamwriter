# Installed Vectors

This slice follows the roots installed by `install_vectors_C000_0ED6` in
[`boot.md`](boot.md). It records ownership of the interrupt vectors and the
low-RAM far-call table, then names the larger handler splits.

No image assets are reached in this slice.

## IVT Ownership

`C000:0ED6` runs before the cold/warm startup branch completes. It points `ES`
at low RAM, fills IVT vectors `00h..F7h` with `C000:118B`, then overwrites the
vectors that the firmware owns directly.

```asm
install_vectors_C000_0ED6:
C000:0ED6  FC                cld
C000:0ED7  06                push es
C000:0ED8  BD 00 00          mov  bp,0
C000:0EDB  8E C5             mov  es,bp
C000:0EDD  BB 00 C0          mov  bx,0xc000
C000:0EE0  BA 8B 11          mov  dx,0x118b
C000:0EE3  BF 00 00          mov  di,0x0000
...
C000:0F24  B9 E7 00          mov  cx,0x00e7       ; fill vectors 11h..F7h
C000:0F27  8B C2             mov  ax,dx
C000:0F29  AB                stosw
C000:0F2A  8B C3             mov  ax,bx
C000:0F2C  AB                stosw
C000:0F2D  E2 F8             loop C000:0F27
```

The default installed target is intentionally boring:

```asm
default_interrupt_target_C000_118B:
; file 0x4118B
C000:118B  CF                iret
```

Bytes after `C000:118B` are not part of the default interrupt target. They begin
another routine/resource sequence at `C000:118C`; do not treat that adjacent
data as part of the installed default vector.

## Explicit Interrupt Vectors

| Vector | IVT offset | Installed target | Target meaning |
| ---: | ---: | --- | --- |
| `01h` | `0x0004` | `C000:157D` | Diagnostic/single-step hook. |
| `21h` | `0x0084` | `C000:0006` -> `C000:5098` | DOS-like/private service dispatcher. |
| `F8h` | `0x03E0` | `C000:0009` -> `C000:03AE` | Save/suspend context path. |
| `F9h` | `0x03E4` | `C000:000C` -> `C000:049A` | Short timer/wake acknowledge path. |
| `FAh` | `0x03E8` | `C000:000F` -> `C000:04AE` | Keyboard scan-cycle reset/start path. |
| `FBh` | `0x03EC` | `C000:0012` -> `C000:04D1` | Keyboard row scan ISR. |
| `FCh` | `0x03F0` | `C000:0015` -> `C000:0550` | RS-232 receive ISR. |
| `FDh` | `0x03F4` | `C000:0018` -> `C000:0724` | Short serial transmit acknowledge path. |
| `FEh` | `0x03F8` | `C000:001B` -> `C000:0738` | Centronics ACK-driven output path. |
| `FFh` | `0x03FC` | `C000:001E` -> `C000:02EE` | Warm/power-management path. |

All other vectors from `00h..F7h`, except the overrides above, point at
`C000:118B` and immediately `iret`.

```asm
; IRQ vectors F8h..FFh
C000:0F2F  BB 00 C0          mov  bx,0xc000
C000:0F32  B9 04 00          mov  cx,0x0004
C000:0F35  BF E0 03          mov  di,0x03e0
C000:0F38  BA 09 00          mov  dx,0x0009
C000:0F3B  8B C2             mov  ax,dx
C000:0F3D  AB                stosw
C000:0F3E  8B C3             mov  ax,bx
C000:0F40  AB                stosw
C000:0F41  83 C2 03          add  dx,byte +0x03
C000:0F44  E2 F5             loop C000:0F3B      ; F8h..FBh
C000:0F46  8B C2             mov  ax,dx           ; FCh -> C000:0015
C000:0F48  AB                stosw
C000:0F49  8B C3             mov  ax,bx
C000:0F4B  AB                stosw
C000:0F4C  83 C2 03          add  dx,byte +0x03
C000:0F4F  8B C2             mov  ax,dx           ; FDh -> C000:0018
C000:0F51  AB                stosw
C000:0F52  8B C3             mov  ax,bx
C000:0F54  AB                stosw
C000:0F55  83 C2 03          add  dx,byte +0x03
C000:0F58  B9 02 00          mov  cx,0x0002
C000:0F5B  8B C2             mov  ax,dx           ; FEh, FFh
C000:0F5D  AB                stosw
C000:0F5E  8B C3             mov  ax,bx
C000:0F60  AB                stosw
C000:0F61  83 C2 03          add  dx,byte +0x03
C000:0F64  E2 F5             loop C000:0F5B

; INT 21h
C000:0F66  B8 06 00          mov  ax,0x0006
C000:0F69  BF 84 00          mov  di,0x0084
C000:0F6C  AB                stosw
C000:0F6D  8B C3             mov  ax,bx
C000:0F6F  AB                stosw

; INT 1
C000:0F70  B8 7D 15          mov  ax,0x157d
C000:0F73  BF 04 00          mov  di,0x0004
C000:0F76  AB                stosw
C000:0F77  B8 00 C0          mov  ax,0xc000
C000:0F7A  AB                stosw
```

## Installed Stub Heads

The stubs at the start of the `C000` segment are tiny near jumps. Their
handlers are the next useful split, not part of this ownership slice.

```asm
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
```

## Handler Split Points

`INT 21h` and the IRQ roots are deliberately split because they cross different
subsystems.

| Root | Split | First observations |
| --- | --- | --- |
| `C000:5098` | `int21-dispatch.md` | Saves caller registers, maps `AH` through `C000:5000`, dispatches through `C000:5060`, and reflects carry into the caller flags before `iret`. |
| `C000:157D` | [`diagnostic-int1.md`](diagnostic-int1.md) | Uses low-RAM breakpoint/watch state at `6EBC..6EC0`; can chain through IVT vector `F8h`. |
| `C000:02EE`, `C000:03AE` | `power-irq.md` | Warm/power and save/suspend paths; both work with the retained context area `6D65..6D87`. |
| `C000:049A`, `C000:04AE`, `C000:04D1` | `keyboard-irq.md` | F9 acknowledge plus FA/FB keyboard scan sequencing. |
| `C000:0550`, `C000:0724`, `C000:0738` | `device-irq.md` | RS-232 receive queueing, transmit acknowledge, and Centronics ACK-driven byte output. |

## Low-RAM Far-Call Table

After installing interrupt vectors, `C000:0ED6` copies `C000:0F94..1037` to
`0000:0200`. This is a far-pointer ABI table, not interrupt-vector data.

```asm
C000:0F7B  1E                push ds
C000:0F7C  BF 00 02          mov  di,0x0200
C000:0F7F  8C D8             mov  ax,ds
C000:0F81  8E C0             mov  es,ax
C000:0F83  BE 94 0F          mov  si,0x0f94
C000:0F86  B8 00 C0          mov  ax,0xc000
C000:0F89  8E D8             mov  ds,ax
C000:0F8B  B9 52 00          mov  cx,0x0052       ; 0xA4 bytes, 41 far ptrs
C000:0F8F  F3 A5             rep  movsw
C000:0F91  1F                pop  ds
C000:0F92  07                pop  es
C000:0F93  C3                ret
```

The full table is decoded in [`low-ram-abi.md`](low-ram-abi.md). Current pointer
summary:

| RAM vector | Startup target | Current read |
| ---: | --- | --- |
| `[0200]` | `C000:67AD` | Display/resource stream consumer. |
| `[0204]` | `DC98:0E81` | Text/display wrapper. |
| `[0208]` | `DC98:0EE5` | Display/blit wrapper. |
| `[020C]` | `DC98:124C` | Horizontal icon menu renderer. |
| `[0210]` | `DC98:1555` | Wrapped text block renderer. |
| `[0214]` | `DC98:18EA` | Editable text input widget. |
| `[0218]` | `DC98:1BB7` | Grid-oriented editable text widget. |
| `[021C]` | `DC98:214E` | Styled prompt/selection widget. |
| `[0220]` | `DC98:0E70` | Display helper around `C000:67AD`. |
| `[0224]` | `DC98:1077` | Numeric-to-decimal string formatter. |
| `[0228]` | `DC98:10D4` | Leading-zero cleanup for formatted numeric strings. |
| `[022C]` | `DC98:1859` | Input-widget idle callback setter. |
| `[0230]` | `DC98:0CF9` | Blocking key read wrapper around `INT 21h AH=08`. |
| `[0234]` | `DC98:0D19` | Input/idle wrapper used by menu waits. |
| `[0238]` | `DC98:0DAF` | Tone-duration wrapper around `C000:096A`. |
| `[023C]` | `C000:67BF` | Poll/idle wrapper around `C000:49FD`. |
| `[0240]` | `DC98:E8D5` | File open/create convenience wrapper. |
| `[0244]` | `DC98:E946` | File open/create implementation helper. |
| `[0248]` | `DC98:EE08` | File read wrapper around `INT 21h AH=3F`. |
| `[024C]` | `DC98:EA54` | Higher-level file read/write helper. |
| `[0250]` | `DC98:EE2E` | File close wrapper around `INT 21h AH=3E`. |
| `[0254]` | `DC98:EE40` | File delete wrapper around `INT 21h AH=41`. |
| `[0258]` | `DC98:EE40` | Duplicate delete wrapper entry. |
| `[025C]` | `DC98:EE56` | File rename wrapper around `INT 21h AH=56`. |
| `[0260]` | `DC98:EE72` | File seek wrapper around `INT 21h AH=42`. |
| `[0264]` | `DC98:EE8A` | Current-position wrapper around `INT 21h AX=4201`. |
| `[0268]` | `DC98:EA98` | Current-position-vs-EOF helper. |
| `[026C]` | `DC98:EB1D` | Higher-level file helper in the `EA54..ED12` helper cluster. |
| `[0270]` | `DC98:EC2A` | File-length helper preserving current position. |
| `[0274]` | `DC98:EEA6` | File attribute get/set wrapper. |
| `[0278]` | `DC98:EC86` | Caller-record fill helper from file/find metadata. |
| `[027C]` | `DC98:ED12` | Caller-record fill helper from file/find metadata. |
| `[0280]` | `DC98:EFD6` | Get free space wrapper around `INT 21h AH=36`. |
| `[0284]` | `DC98:EF7B` | Find-first wrapper; sets DTA, then `INT 21h AH=4E`. |
| `[0288]` | `DC98:EF9A` | Find-next wrapper; sets DTA, then `INT 21h AH=4F`. |
| `[028C]` | `DC98:F000` | File attribute wrapper. |
| `[0290]` | `DC98:F018` | File date/time wrapper. |
| `[0294]` | `DC98:F03A` | File attribute wrapper. |
| `[0298]` | `DC98:F052` | Set file date/time wrapper around `INT 21h AX=5701`. |
| `[029C]` | `DC98:52E5` | Document picker/list UI. |
| `[02A0]` | `DC98:2887` | Application/menu boundary; deferred. |
