# Installed Vectors

This slice follows the roots installed by `install_vectors_C000_1161` in
[`boot.md`](boot.md). It records ownership of the interrupt vectors and the
low-RAM far-call table.

## IVT Ownership

`C000:1161` runs during cold/warm startup. It points `ES` at segment `0`,
then fills IVT vectors manually with `STOSW`, writing each offset/segment
pair individually, filling them in groups with the default target
interleaved.

```asm
install_vectors_C000_1161:
; file 0xC1161
C000:1161  FC                cld
C000:1162  06                push es
C000:1163  BD 0000           mov bp,0
C000:1166  8E C5             mov es,bp
C000:1168  BB 00C0           mov bx,C000        ; segment for all vectors
C000:116B  BA 1F14           mov dx,141F        ; default handler offset
C000:116E  BF 0000           mov di,0000        ; IVT base
```

The default target `C000:141F` is a single `IRET`.

### Vector Fill Sequence

| DI range | Vectors | Target |
| --- | --- | --- |
| `0x0000..0x0003` | INT 00h | `C000:141F` (default) |
| `0x0004..0x0007` | INT 01h | `C000:141F` (default, overwritten later) |
| `0x0008..0x000B` | INT 02h (NMI) | `C000:04D0` |
| `0x000C..0x000F` | INT 03h | `C000:141F` (default) |
| `0x0010..0x001B` | INT 04h..06h | `C000:141F` (default, cx=3 loop) |
| `0x001C..0x002F` | INT 07h..0Bh | `C000:141F` (default, cx=5 loop) |
| `0x0030..0x0033` | INT 0Ch | `C000:141F` (default) |
| `0x0034..0x003F` | INT 0Dh..0Fh | `C000:141F` (default, cx=3 loop) |
| `0x0040..0x0043` | INT 10h | `C000:141F` (default) |
| `0x0044..0x03DF` | INT 11h..F7h | `C000:141F` (default, cx=0xE7 loop) |

### Hardware IRQ Stubs (F8h..FFh)

Written at DI=0x03E0 with incrementing offsets starting at DX=0x0009:

```asm
C000:11C3  BB 00C0           mov bx,C000
C000:11C6  B9 0400           mov cx,4
C000:11C9  BF E003           mov di,03E0        ; INT F8h
C000:11CC  BA 0900           mov dx,0009        ; C000:0009
```

| Vector | IVT offset | Target | Jump target | Meaning |
| ---: | ---: | --- | --- | --- |
| `F8h` | `0x03E0` | `C000:0009` | `C000:04D0` | Save/suspend (same as NMI!) |
| `F9h` | `0x03E4` | `C000:000C` | `C000:05C0` | Timer/wake. |
| `FAh` | `0x03E8` | `C000:000F` | `C000:05D4` | Keyboard scan reset. |
| `FBh` | `0x03EC` | `C000:0012` | `C000:05F7` | Keyboard row scan ISR. |
| `FCh` | `0x03F0` | `C000:0015` | `C000:0676` | RS-232 receive ISR. |
| `FDh` | `0x03F4` | `C000:0018` | `C000:084A` | Serial transmit ack. |
| `FEh` | `0x03F8` | `C000:001B` | `C000:085E` | Centronics ACK output. |
| `FFh` | `0x03FC` | `C000:001E` | `C000:03FC` | Warm/power-management. |

### Explicit Overwrites

After filling the table, two vectors are overwritten:

```asm
C000:11FA  B8 0600           mov ax,0006        ; INT 21h -> C000:0006
C000:11FD  BF 8400           mov di,0084
C000:1200  AB                stosw
C000:1201  8B C3             mov ax,bx          ; segment C000
C000:1203  AB                stosw
C000:1204  B8 3218           mov ax,1832        ; INT 01h -> C000:1832
C000:1207  BF 0400           mov di,0004
C000:120A  AB                stosw
C000:120B  B8 00C0           mov ax,C000
C000:120E  AB                stosw
```

### Final Summary

| Vector | IVT offset | Target | Meaning |
| ---: | ---: | --- | --- |
| `01h` | `0x0004` | `C000:1832` | Diagnostic/single-step hook. |
| `02h` | `0x0008` | `C000:04D0` | NMI handler. |
| `21h` | `0x0084` | `C000:0006` -> `C000:6277` | DOS-like service dispatcher. |
| `F8h` | `0x03E0` | `C000:0009` -> `C000:04D0` | Save/suspend context. |
| `F9h` | `0x03E4` | `C000:000C` -> `C000:05C0` | Timer/wake ack. |
| `FAh` | `0x03E8` | `C000:000F` -> `C000:05D4` | Keyboard scan reset/start. |
| `FBh` | `0x03EC` | `C000:0012` -> `C000:05F7` | Keyboard row scan ISR. |
| `FCh` | `0x03F0` | `C000:0015` -> `C000:0676` | RS-232 receive ISR. |
| `FDh` | `0x03F4` | `C000:0018` -> `C000:084A` | Serial transmit ack. |
| `FEh` | `0x03F8` | `C000:001B` -> `C000:085E` | Centronics ACK output. |
| `FFh` | `0x03FC` | `C000:001E` -> `C000:03FC` | Warm/power-management. |

All other vectors `00h..F7h` point at `C000:141F` (IRET).

## Low-RAM Far-Call Table

After installing vectors, the installer copies 0x52 words (41 far pointers)
from `CS:1228` to `DS:0200`:

```asm
C000:120F  1E                push ds
C000:1210  BF 0002           mov di,0200
C000:1213  8C D8             mov ax,ds
C000:1215  8E C0             mov es,ax
C000:1217  BE 2812           mov si,1228
C000:121A  B8 00C0           mov ax,C000
C000:121D  8E D8             mov ds,ax
C000:121F  B9 5200           mov cx,52         ; 82 words = 41 far ptrs
C000:1222  90                nop
C000:1223  F3 A5             rep movsw
C000:1225  1F                pop ds
C000:1226  07                pop es
C000:1227  C3                ret
```

| RAM addr | Target | Notes |
| --- | --- | --- |
| `[0200]` | `C000:3F35` | |
| `[0204]` | `DEF0:0D91` | |
| `[0208]` | `DEF0:0DF5` | |
| `[020C]` | `DEF0:115C` | |
| `[0210]` | `DEF0:1471` | |
| `[0214]` | `DEF0:1806` | |
| `[0218]` | `DEF0:1B00` | |
| `[021C]` | `DEF0:2097` | |
| `[0220]` | `DEF0:0D80` | |
| `[0224]` | `DEF0:0F87` | |
| `[0228]` | `DEF0:0FE4` | |
| `[022C]` | `DEF0:1775` | |
| `[0230]` | `DEF0:0043` | |
| `[0234]` | `DEF0:0063` | |
| `[0238]` | `DEF0:00F9` | |
| `[023C]` | `C000:3F47` | |
| `[0240]` | `DEF0:DAD6` | |
| `[0244]` | `DEF0:DB47` | |
| `[0248]` | `DEF0:E022` | |
| `[024C]` | `DEF0:DC5E` | |
| `[0250]` | `DEF0:E048` | |
| `[0254]` | `DEF0:E05A` | |
| `[0258]` | `DEF0:E05A` | (duplicate) |
| `[025C]` | `DEF0:E070` | |
| `[0260]` | `DEF0:E08C` | |
| `[0264]` | `DEF0:E0A4` | |
| `[0268]` | `DEF0:DCA2` | |
| `[026C]` | `DEF0:DD27` | |
| `[0270]` | `DEF0:DE34` | |
| `[0274]` | `DEF0:E0C0` | |
| `[0278]` | `DEF0:DE90` | |
| `[027C]` | `DEF0:DF1C` | |
| `[0280]` | `DEF0:E1F0` | |
| `[0284]` | `DEF0:E195` | |
| `[0288]` | `DEF0:E1B4` | |
| `[028C]` | `DEF0:E21A` | |
| `[0290]` | `DEF0:E232` | |
| `[0294]` | `DEF0:E254` | |
| `[0298]` | `DEF0:E26C` | |
| `[029C]` | `DEF0:57EF` | |

38 of 40 entries target `DEF0:xxxx`; the remaining two target `C000:3F35`
and `C000:3F47`.
