# DC98 File Wrappers

This slice follows the `DC98` file-service wrappers exposed by the low-RAM ABI
table. These are service wrappers around the DOS-like `INT 21h` layer and a few
small higher-level helpers; it does not enter document pickers, menus, or app
handlers.

No image assets or string resources are reached in this slice.

## Open/Create Convenience

`DC98:E8D5` is the low-RAM ABI entry at `[0240]`. It pushes a default mode word
`0x0061`, the caller's `AX` path pointer, and calls `DC98:E946`.

```asm
file_open_default_DC98_E8D5:
; file 0x6B255
DC98:E8D5  53                push bx
DC98:E8D6  BB 61 00          mov  bx,0x0061
DC98:E8D9  53                push bx
DC98:E8DA  50                push ax
DC98:E8DB  9A 46 E9 98 DC    call DC98:E946
DC98:E8E0  83 C4 06          add  sp,6
DC98:E8E3  CB                retf
```

`DC98:E946` is the implementation wrapper at `[0244]`. It tries to open the
path through `DC98:EF32` (`INT 21h AH=3D`), applies flag policy, optionally
creates through `DC98:EED2` (`AH=3C`), and records per-handle flag bits at
`8D93 + handle`.

Important mode bits observed:

| Bit | Effect |
| ---: | --- |
| `0x03` | Low two bits become the `AH=3D` open mode. |
| `0x10` | Stored as per-handle flag bit `0x02`; `DC98:EA54` uses it to seek EOF before writes. |
| `0x20` | Enables create-on-missing when `[680F] == 2`; an optional stack word is converted to a boolean through `DC98:E8E4`. |
| `0x40` | Enables replace/create policy. |
| `0x80` with `0x20` | Forces close, status `[680F]=0x11`, and failure. |

## Direct INT 21h Wrappers

These wrappers are the stable DOS-like service surface.

| Wrapper | Low-RAM ABI | INT 21h service | Return convention |
| --- | ---: | --- | --- |
| `DC98:EE08` | `[0248]` | `AH=3F` read, `BX=handle`, `CX=count`, `DS:DX=buffer` | bytes read in `AX`, or `AX=FFFF`. |
| `DC98:EE1B` | local helper | `AH=40` write | bytes written in `AX`, or `AX=FFFF`. |
| `DC98:EE2E` | `[0250]` | `AH=3E` close | `AX=0` success, `AX=FFFF` error. |
| `DC98:EE40` | `[0254]`, `[0258]` | `AH=41` delete | `AX=0` success, `AX=FFFF` error. |
| `DC98:EE56` | `[025C]` | `AH=56` rename | `AX=0` success, `AX=FFFF` error. |
| `DC98:EE72` | `[0260]` | `AH=42` seek | new position in `BX:AX`, or `FFFF:FFFF`. |
| `DC98:EE8A` | `[0264]` | `AX=4201`, zero delta | current position in `BX:AX`, or `FFFF:FFFF`. |
| `DC98:EEA6` | `[0274]` | `AX=4300/4301` | Clears/sets read-only bit from caller flag. |
| `DC98:EED2` | local helper | `AH=3C` create/truncate | handle in `AX`, or `AX=FFFF`. |
| `DC98:EEE7` | local helper | `AH=43` get/set attribute by caller `AL` | attribute in `AX`, or `AX=FFFF`. |
| `DC98:EF32` | local helper | `AH=3D` open | handle in `AX`, or `AX=FFFF`. |
| `DC98:EF45` | local helper | `AX=4400` IOCTL/status | status word in `AX`, or `AX=FFFF`. |
| `DC98:EF59` | local helper | `AH=57` get/set date-time | time/date in `AX:BX`, or `FFFF:FFFF`. |
| `DC98:EF7B` | `[0284]` | `AH=1A`, then `AH=4E` find first | `AX=0` success; error mapped in `[680F]`. |
| `DC98:EF9A` | `[0288]` | `AH=1A`, then `AH=4F` find next | `AX=0` success; error mapped in `[680F]`. |
| `DC98:EFD6` | `[0280]` | `AH=36` free space | Writes `DX,BX,AX,CX` to caller record; `AX=0` success. |
| `DC98:F000` | `[028C]` | `AX=4300` get attributes | Writes `CX` to caller word; `AX=0` success. |
| `DC98:F018` | `[0290]` | `AX=5700` get date/time | Writes date/time words to caller pointers; `AX=0` success. |
| `DC98:F03A` | `[0294]` | `AX=4301` set attributes | `AX=0` success. |
| `DC98:F052` | `[0298]` | `AX=5701` set date/time | `AX=0` success. |
| `DC98:F06A` | local helper | none | Returns current mapped status `[680F]`. |
| `DC98:F06E` | local helper | `AX=4428` | Direct IOCTL passthrough. |
| `DC98:F074` | local helper | `AX=4429`, `BX=AX` | Direct IOCTL passthrough. |

Representative wrappers:

```asm
file_read_DC98_EE08:
; file 0x6B788
DC98:EE08  52                push dx
DC98:EE09  8B D3             mov  dx,bx
DC98:EE0B  8B D8             mov  bx,ax
DC98:EE0D  B4 3F             mov  ah,0x3f
DC98:EE0F  CD 21             int  0x21
DC98:EE11  73 06             jnc  read_ok_DC98_EE19
DC98:EE13  E8 B5 FF          call map_file_error_DC98_EDCB
DC98:EE16  B8 FF FF          mov  ax,0xffff
DC98:EE19  5A                pop  dx
DC98:EE1A  CB                retf

file_seek_DC98_EE72:
DC98:EE72  51                push cx
DC98:EE73  52                push dx
DC98:EE74  87 CA             xchg dx,cx
DC98:EE76  93                xchg ax,bx
DC98:EE77  B4 42             mov  ah,0x42
DC98:EE79  CD 21             int  0x21
DC98:EE7B  8B DA             mov  bx,dx
```

## Error Mapping

`DC98:EDCB` maps DOS-style error values into firmware status word `[680F]`.
Error `0x50` maps directly to status `0x11`. Errors `0x20` and `0x21` use
table index `5`; errors above `0x13` clamp to index `0x13`; otherwise the error
code itself indexes a table at `F50C:000E`.

```asm
map_file_error_DC98_EDCB:
; file 0x6B74B
DC98:EDCB  51                push cx
DC98:EDCC  8B C8             mov  cx,ax
DC98:EDCE  83 F9 50          cmp  cx,0x50
DC98:EDD3  C7 06 0F 68 1100  mov  word [0x680f],0x0011
...
DC98:EDF6  B8 0C F5          mov  ax,0xf50c
DC98:EDF9  8E C0             mov  es,ax
DC98:EDFB  26 8A 87 0E 00    mov  al,[es:bx+0x000e]
DC98:EE00  98                cbw
DC98:EE01  A3 0F 68          mov  [0x680f],ax
DC98:EE04  8B C1             mov  ax,cx
DC98:EE06  59                pop  cx
DC98:EE07  C3                ret
```

## Higher-Level Helpers

`DC98:EA54` is the `[024C]` write helper. If the per-handle flag bit `0x02` is
set, it seeks to EOF before writing. A zero count returns `AX=0` without
calling `INT 21h`.

`DC98:EA98` compares the current file position with EOF. It saves current
position, seeks to EOF, restores the saved position, and returns:

```text
AX = FFFF on seek error
AX = 0001 if current_position >= eof
AX = 0000 if current_position < eof
```

`DC98:EC2A` returns file length while preserving the original file position:
save current position, seek EOF, restore current position, return EOF in
`BX:AX` or `FFFF:FFFF`.

`DC98:EC86` and `DC98:ED12` fill caller records from find/status/date metadata.
They remain service-level helpers, but their record format is a higher-level
runtime structure rather than the raw DOS DTA.

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `680F` | Firmware file/status word set by `DC98:EDCB` and open policy. |
| `8D93 + handle` | Per-open-handle flag byte set by `DC98:E946`; bit `0x02` drives append-before-write in `DC98:EA54`. |
| `F50C:000E+index` | Error-code translation table for `[680F]`. |

