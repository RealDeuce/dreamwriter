# Startup Display Init

This slice covers the startup display path reached from
[`boot.md`](boot.md) at `C000:0220` (normal resume). It checks the RTC
state via the routines in [`rtc-alarm-power.md`](rtc-alarm-power.md),
then renders the copyright/product banner screens from display scripts
in the C772 segment.

## C000:0987 — RTC Check and Startup Display Init

Called from `C000:0224` during normal resume. Calls `C000:08AA` to check
the RTC state and `[1439]` flag. If the RTC is normal and `[1439]` is
clear, renders the startup display and returns CF=0. If the RTC is
abnormal or `[1439]` is set, returns CF=1 without rendering.

```asm
; file 0xC0987
C000:0987  E8 20FF           call C000:08AA  ; RTC state gate
C000:098A  72 12             jc C000:099E    ; abnormal -> return (skip display)
C000:098C  BB 3313           mov bx,1333
C000:098F  43                inc bx          ; BX = 1334
C000:0990  8A 07             mov al,[bx]     ; AL = [1334] (sound slot selector)
C000:0992  E8 3004           call C000:0DC5  ; play multi-note sequence (slot AL)
C000:0995  E8 B100           call C000:0A49  ; CPU delay
C000:0998  E8 AE00           call C000:0A49  ; CPU delay
C000:099B  E8 D6FF           call C000:0974  ; restore framebuffer [9000]->[8000]
C000:099E  C3                ret
```

After cold init, `[1334]=0` (cleared by `C000:03BB`, explicitly set by
`C000:2FDC`). So the normal resume path plays sound slot 0: tone(`0x15D`)
+ silence + tone(`0x100`). See [`sound-lowlevel.md`](sound-lowlevel.md).

## C000:08AA — RTC State Gate

Checks `[1439]` (RTC abnormal flag, set by `C000:0498` during
power-down when the RTC is in its reset state). If set, waits for the
RTC to stabilize before proceeding. If clear, reads the RTC registers
directly.

```asm
; file 0xC08AA
C000:08AA  80 3E 3914 00     cmp byte [1439],0
C000:08AF  74 03             jz C000:08B4    ; clear -> check RTC now
C000:08B1  E9 9F00           jmp C000:0953   ; set -> wait for RTC stable
```

### C000:08B4 — Check RTC Now

```asm
C000:08B4  E8 8C05           call C000:0E43  ; read 11 RTC registers
C000:08B7  73 1A             jnc C000:08D3   ; RTC normal -> startup display init
C000:08B9  8B 1E 6714        mov bx,[1467]   ; RTC abnormal:
C000:08BD  53                push bx
C000:08BE  06                push es
C000:08BF  9A 5FCD F0DE      call far DEF0:CD5F
C000:08C4  07                pop es
C000:08C5  5B                pop bx
C000:08C6  89 1E 6714        mov [1467],bx   ; restore [1467]
C000:08CA  0B C0             or ax,ax
C000:08CC  74 03             jz C000:08D1    ; AX==0 -> return CF=1
C000:08CE  E9 BBFB           jmp C000:048C   ; AX!=0 -> power down
C000:08D1  F9                stc
C000:08D2  C3                ret             ; return CF=1 (RTC abnormal)
```

### C000:08D3 — Normal Startup Display Init

Performs a secondary RTC check. If normal, calls `DEF0:C5BC`, saves the
framebuffer, then renders 9 display script blocks from the C772 segment.

```asm
C000:08D3  E8 5905           call C000:0E2F  ; secondary RTC check (7 regs)
C000:08D6  73 03             jnc C000:08DB   ; normal -> continue
C000:08D8  E9 8000           jmp C000:095B   ; abnormal -> set [1439], halt
C000:08DB  06                push es
C000:08DC  9A BCC5 F0DE      call far DEF0:C5BC
C000:08E1  07                pop es
C000:08E2  E8 8400           call C000:0969  ; save framebuffer [8000]->[9000]
```

Renders copyright/product banners from C772 segment display scripts:

```asm
C000:08E5  BE C8ED           mov si,EDC8     ; "WORD PROCESSOR (C) 1992..."
C000:08E8  B9 0600           mov cx,6
C000:08EB  BA 72C7           mov dx,C772
C000:08EE  E8 665C           call C000:6557  ; render display script
C000:08F1  BE CEED           mov si,EDCE     ; text body
C000:08F4  B9 6300           mov cx,63
C000:08F7  BA 72C7           mov dx,C772
C000:08FA  E8 5A5C           call C000:6557
C000:08FD  BE 31EE           mov si,EE31     ; "International..."
C000:0900  B9 0700           mov cx,7
C000:0903  BA 72C7           mov dx,C772
C000:0906  E8 4E5C           call C000:6557
C000:0909  BE 38EE           mov si,EE38
C000:090C  B9 4400           mov cx,44
C000:090F  BA 72C7           mov dx,C772
C000:0912  E8 425C           call C000:6557
C000:0915  BE 7CEE           mov si,EE7C     ; "Copyright 1995..."
C000:0918  B9 3F00           mov cx,3F
C000:091B  BA 72C7           mov dx,C772
C000:091E  E8 365C           call C000:6557
C000:0921  BE BBEE           mov si,EEBB
C000:0924  B9 4400           mov cx,44
C000:0927  BA 72C7           mov dx,C772
C000:092A  E8 2A5C           call C000:6557
C000:092D  BE FFEE           mov si,EEFF     ; "US English..."
C000:0930  B9 3B00           mov cx,3B
C000:0933  BA 72C7           mov dx,C772
C000:0936  E8 1E5C           call C000:6557
C000:0939  BE 3AEF           mov si,EF3A     ; "Reproduction..."
C000:093C  B9 5A00           mov cx,5A
C000:093F  BA 72C7           mov dx,C772
C000:0942  E8 125C           call C000:6557
C000:0945  BE 94EF           mov si,EF94     ; trailing space/control
C000:0948  B9 0B00           mov cx,0B
C000:094B  BA 72C7           mov dx,C772
C000:094E  E8 065C           call C000:6557
C000:0951  F8                clc             ; return CF=0 (success)
C000:0952  C3                ret
```

### C000:0953 — Wait for RTC Stable

Reached when `[1439]!=0` from a previous boot. Waits for the RTC second
registers to read zero, then proceeds to the display init at `C000:08E2`.

```asm
C000:0953  E8 0C05           call C000:0E62  ; check RTC seconds clear
C000:0956  73 8A             jnc C000:08E2   ; stable -> display init
C000:0958  E9 31FB           jmp C000:048C   ; still unstable -> power down
```

### C000:095B — Set RTC Flag and Halt

Reached when the secondary RTC check at `C000:08D3` detects an abnormal
state.

```asm
C000:095B  E8 8303           call C000:0CE1  ; advance RTC minute
C000:095E  C6 06 3914 01     mov byte [1439],1  ; set RTC abnormal flag
C000:0963  E8 59FB           call C000:04BF  ; restore RTC control bits
C000:0966  E9 29FB           jmp C000:0492   ; -> halt
```

## C000:0969 — Save Framebuffer

Calls `C000:33E2` (serial output buffer flush — tests `[143D]`
bit 7, clears `[143D]` to 0, and if the flag was set, copies 16
bytes from `[9000]` to `[803A]` in 2-byte chunks across 8 rows
spaced 0x40 apart — a display overlay transfer), then copies 4 KiB
from `[8000..8FFF]` to `[9000..9FFF]`.

```asm
; file 0xC0969
C000:0969  E8 762A           call C000:33E2
C000:096C  BE 0080           mov si,8000
C000:096F  BF 0090           mov di,9000
C000:0972  EB 06             jmp short C000:097A
```

## C000:0974 — Restore Framebuffer

Copies 4 KiB from `[9000..9FFF]` to `[8000..8FFF]`.

```asm
; file 0xC0974
C000:0974  BE 0090           mov si,9000
C000:0977  BF 0080           mov di,8000
C000:097A  06                push es
C000:097B  8C D8             mov ax,ds
C000:097D  8E C0             mov es,ax
C000:097F  FC                cld
C000:0980  B9 0008           mov cx,800      ; 2048 words = 4 KiB
C000:0983  F3 A5             rep movsw
C000:0985  07                pop es
C000:0986  C3                ret
```

## Display Script Locations

The 9 display scripts rendered during startup are at these C772 segment
offsets (physical addresses in window 6):

| SI offset | Length | Content (from hex dump) |
| --- | ---: | --- |
| `EDC8` | `06` | Display control header |
| `EDCE` | `63` | "WORD PROCESSOR (C) 1992 NER Inc. Ver.3.00 and (C) 1992 mikrolab Ver.5.00. All Rights Reserved" |
| `EE31` | `07` | Display control |
| `EE38` | `44` | "International CorrectSpell English spelling correction system" |
| `EE7C` | `3F` | "Copyright 1995 by Inso Corporation. All Rights Reserved." |
| `EEBB` | `44` | Additional copyright text |
| `EEFF` | `3B` | "US English" text |
| `EF3A` | `5A` | "Reproduction" / license text |
| `EF94` | `0B` | Trailing control bytes |

### Display Script Raw Data (C772:EDB0, file 0xD64D0)

The INITIALIZING script at `C772:EDB0` (24 bytes, rendered by
`C000:09D4` during cold reinit):

```text
EDB0: FF 00 FF 04 00 06 FF 02 00 00 00 00  ; FF 00=clear, FF 04=font, FF 02=position
EDBC: 49 4E 49 54 49 41 4C 49 5A 49 4E 47  ; "INITIALIZING"
```

The startup menu script at `C772:EFB0` (file `0xD66D0`, rendered by
`C000:19A8` during application entry) contains `FF 42` bitmap
commands referencing button and label bitmaps:

```text
EFB0: FF 06 00 82 00                        ; FF 06=attribute
EFB5: FF 42 22 00 24 00 1B F0 72 C7         ; bitmap: 34×36 button at C772:F01B
EFBF: FF 40 0B 00 87 00                     ; FF 40=position
EFC5: FF 42 07 00 18 00 C5 F0 72 C7         ; bitmap: 7×24 "ORGN" at C772:F0C5
EFCF: FF 02 0C 00 6A 00                     ; FF 02=text cursor
EFD5: 4F 52 47 41 4E 49 5A 45 52 20 4D 45   ; "ORGANIZER ME"
EFE1: 4E 55                                 ; "NU"
EFE3: FF 40 06 00 3A 01                     ; position for WP button
EFE9: FF 42 22 00 24 00 1B F0 72 C7         ; bitmap: same button
EFF3: FF 40 0B 00 3F 01                     ; position
EFF9: FF 42 07 00 18 00 DA F0 72 C7         ; bitmap: 7×24 "WP" at C772:F0DA
F003: FF 02 0C 00 13 01                     ; text cursor
F009: 57 4F 52 44 20 50 52 4F 43 45 53 53   ; "WORD PROCESS"
F015: 4F 52 20 4D 45 4E 55                  ; "OR MENU"
```

See [`bitmaps.md`](../bitmaps.md) for rendered PNG images of the
button and label bitmaps.
