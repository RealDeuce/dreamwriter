# Storage Geometry And Card Probe

This slice follows the storage geometry helpers reached from
[`int21-format.md`](int21-format.md) and
[`int21-directory-core.md`](int21-directory-core.md).

No image assets or string resources are reached in this slice.

## PCMCIA SRAM Capacity Probe

`C000:3C08` is the card-format capacity probe. It first calls the card-access
helper `C000:0AC4`; if the card is absent/not ready, it sets filesystem status
`0x08` and returns carry set.

```asm
card_capacity_probe_C000_3C08:
; file 0x43C08
C000:3C08  E8 B9 CE          call card_access_check_C000_0AC4
C000:3C0B  73 07             jnc  card_present_C000_3C14
C000:3C0D  C6 06 C1 6E 08    mov  byte [0x6ec1],0x08
C000:3C12  F9                stc
C000:3C13  C3                ret
```

The probe then write-tests up to sixteen 32 KiB windows. It uses the common bank
helper `C000:0239`, maps candidate windows beginning at segment `0x4000`, writes
`0x5EA6` at `ES:0000`, verifies it, then leaves `0xFFFF` in each detected
window.

```asm
C000:3C14  33 DB             xor  bx,bx
C000:3C16  B9 10 00          mov  cx,0x0010
C000:3C1A  BA 00 00          mov  dx,0
probe_window_C000_3C1D:
C000:3C1E  E8 18 C6          call card_bank_helper_C000_0239
C000:3C24  05 00 40          add  ax,0x4000
C000:3C27  8E C0             mov  es,ax
C000:3C29  B8 A6 5E          mov  ax,0x5ea6
C000:3C2C  26 A3 00 00       mov  [es:0],ax
C000:3C30  26 39 06 00 00    cmp  [es:0],ax
C000:3C37  B8 FF FF          mov  ax,0xffff
C000:3C3A  26 A3 00 00       mov  [es:0],ax
C000:3C3E  43                inc  bx
C000:3C3F  81 C2 00 08       add  dx,0x0800
```

A second pass counts only windows that still read back `0xFFFF` and writes a
small index into each confirmed window. The count is stored in `[6FAD]`.

```asm
C000:3C49  8B CB             mov  cx,bx
C000:3C4B  33 DB             xor  bx,bx
verify_window_C000_3C50:
C000:3C51  E8 E5 C5          call card_bank_helper_C000_0239
C000:3C5C  26 A1 00 00       mov  ax,[es:0]
C000:3C60  3D FF FF          cmp  ax,0xffff
C000:3C65  26 89 1E 00 00    mov  [es:0],bx
C000:3C6A  81 C2 00 08       add  dx,0x0800
C000:3C6E  43                inc  bx
C000:3C72  88 1E AD 6F       mov  [0x6fad],bl
```

Each counted unit represents 32 KiB, because `DX` advances by `0x0800`
paragraphs. On success, `C000:3C76` stores `count * 0x20` in `[6F21]` and calls
the formatter helper at `C000:23D9`. On failure, it sets status `0x13`.

```asm
finish_card_geometry_C000_3C76:
C000:3C76  0B DB             or   bx,bx
C000:3C78  74 0F             jz   no_card_space_C000_3C89
C000:3C7A  B8 20 00          mov  ax,0x0020
C000:3C7D  F7 E3             mul  bx
C000:3C7F  A3 21 6F          mov  [0x6f21],ax
C000:3C83  E8 53 E7          call C000:23D9
C000:3C87  F8                clc
C000:3C88  C3                ret
```

This is common-memory SRAM probing. It does not read CIS tuples, use
even-byte-only attribute-space addressing, or switch to a distinct attribute
window.

## Local Sector Geometry Helper

`C000:3C90` prepares a local sector/window operation from `[6F54]`, stores
`[6F21] = [6F54] * 4`, sets `[6F23]=0x0E`, then calls the adjacent formatter
helper at `C000:23DE`.

```asm
local_sector_geometry_C000_3C90:
; file 0x43C90
C000:3C90  8B 1E 54 6F       mov  bx,[0x6f54]
C000:3C94  B8 04 00          mov  ax,0x0004
C000:3C97  F7 E3             mul  bx
C000:3C99  A3 21 6F          mov  [0x6f21],ax
C000:3C9C  C6 06 23 6F 0E    mov  byte [0x6f23],0x0e
C000:3CA2  E8 39 E7          call C000:23DE
```

## Card Write-Protect Check

`C000:3CA7` is the write-permission boundary used by write/delete/format paths.
Built-in endpoint `0x08` is always allowed. Other endpoints call `C000:0ACE`;
carry from that helper becomes filesystem status `0x0B`.

```asm
storage_write_check_C000_3CA7:
; file 0x43CA7
C000:3CA7  80 3E A5 6F 08    cmp  byte [0x6fa5],0x08
C000:3CAC  74 05             jz   write_ok_C000_3CB3
C000:3CAE  E8 1D CE          call card_write_protect_C000_0ACE
C000:3CB1  72 02             jc   write_protected_C000_3CB5
C000:3CB3  F8                clc
C000:3CB4  C3                ret
C000:3CB5  C6 06 C1 6E 0B    mov  byte [0x6ec1],0x0b
C000:3CBA  C3                ret
```

## State Boundary

| RAM/Port | Meaning |
| ---: | --- |
| `6F21` | Formatter/window geometry byte count or sector offset helper. |
| `6F23` | Local formatter operation byte, set to `0x0E` by `C000:3C90`. |
| `6F54` | Sector index used by local geometry helper. |
| `6FAD` | Card geometry count in 32 KiB units. |
| `0xA0 bit 0x80` | Card absent/not-ready gate consumed by `C000:0AC4`. |
| `0xA0 bit 0x40` | Card write-protect bit consumed by `C000:0ACE`. |

Bank/window mapping is expanded in
[`storage-window-mapping.md`](storage-window-mapping.md). Formatter progress
output is expanded in [`format-status-output.md`](format-status-output.md).
