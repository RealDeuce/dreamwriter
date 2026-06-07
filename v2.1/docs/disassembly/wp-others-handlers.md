# Word-Processor OTHERS Handlers

This slice expands the two remaining `OTHERS` submenu handlers reached from
[`wp-submenus.md`](wp-submenus.md): `T I M E` and `ROM CARD`.

No new bitmap assets are reached here. The four OTHERS menu icons are rendered
beside their descriptor entries in [`wp-submenus.md`](wp-submenus.md#others-submenu).

## T I M E Entry

The `T I M E` label is not a clock-setting editor. It is the entry to the
Typin' Time application segment at `EBBB:0000`, file offset `0x6BBB0`. The
menu wrapper at `DC98:2D65` far-calls this entry, clears `AH`, and returns to
the WP top menu only when the low byte is `0x0B`.

```asm
typin_time_entry_EBBB_0000:
; file 0x6BBB0
EBBB:0000  1E                push ds
EBBB:0001  06                push es
EBBB:0002  16                push ss
EBBB:0003  8C 1E 40 8E       mov  [0x8e40],ds
EBBB:0007  8C 06 42 8E       mov  [0x8e42],es
EBBB:000B  8C 16 44 8E       mov  [0x8e44],ss
EBBB:000F  E8 BA 00          call EBBB:00CC
EBBB:0012  BB 00 00          mov  bx,0x0000
EBBB:0015  8E DB             mov  ds,bx
EBBB:0017  8E 16 44 8E       mov  ss,[0x8e44]
EBBB:001B  17                pop  ss
EBBB:001C  07                pop  es
EBBB:001D  1F                pop  ds
EBBB:001E  C7 06 19 71 00 00 mov  word [0x7119],0
EBBB:0024  CB                retf
```

The entry saves caller segment registers in low RAM before entering the app,
then restores the original stack/data state and clears the display-style word
at `[7119]` before returning. The temporary `ds=0` at `EBBB:0012` lets the
restore load `[8E44]` from low memory.

`EBBB:00CC` is the app initializer. It seeds the Typin' Time state words and
then calls the shared dispatcher at `EBBB:012E`, expanded in
[`typin-time.md`](typin-time.md).

```asm
typin_time_init_EBBB_00CC:
EBBB:00D5  C7 06 6E 8E 01 00 mov  word [0x8e6e],1
EBBB:00DB  C7 06 74 8E 3C 00 mov  word [0x8e74],0x003c
EBBB:00E1  B8 3C 00          mov  ax,0x003c
EBBB:00E4  A3 72 8E          mov  [0x8e72],ax
EBBB:00E7  C7 06 70 8E 00 00 mov  word [0x8e70],0
EBBB:00ED  C6 06 64 93 00    mov  byte [0x9364],0
EBBB:00F2  C7 06 52 8E 00 00 mov  word [0x8e52],0
EBBB:00F8  C7 06 54 8E 06 00 mov  word [0x8e54],6
EBBB:00FE  C7 06 58 8E 00 00 mov  word [0x8e58],0
EBBB:0104  B8 00 00          mov  ax,0
EBBB:0107  A3 56 8E          mov  [0x8e56],ax
EBBB:010A  E8 21 00          call EBBB:012E
```

The dispatcher is the first non-trivial app boundary. It uses `[8E52]` as an
outer selection index and `[8E54]` as the current state/action code. When
`[8E54]` is zero, it advances `[8E52]` modulo 16 and reads a word from
`F87B:(0004 + [8E52] * 2)` through the local far-word helper at `EBBB:0116`.

```asm
typin_time_dispatcher_EBBB_012E:
EBBB:013D  83 06 52 8E 01    add  word [0x8e52],1
EBBB:0142  A1 52 8E          mov  ax,[0x8e52]
EBBB:0145  3D 10 00          cmp  ax,0x0010
EBBB:014D  C7 06 52 8E 00 00 mov  word [0x8e52],0
...
EBBB:0158  B9 04 00          mov  cx,0x0004
EBBB:015B  BA 7B F8          mov  dx,0xf87b
EBBB:0162  E8 B1 FF          call EBBB:0116       ; read far word
EBBB:0168  A3 54 8E          mov  [0x8e54],ax
...
EBBB:0175  9A 00 F2 98 DC    call DC98:F200
EBBB:0182  9A 98 F1 98 DC    call DC98:F198
EBBB:018D  A3 90 8E          mov  [0x8e90],ax
EBBB:0190  A1 54 8E          mov  ax,[0x8e54]
EBBB:0220  2D 01 00          sub  ax,1
EBBB:0223  3D 14 00          cmp  ax,0x0014
EBBB:022B  D1 E0             shl  ax,1
EBBB:022D  8B D8             mov  bx,ax
EBBB:022F  2E FF A7 34 02    jmp  [cs:bx+0x0234]
```

The jump table at `EBBB:0234` has handlers for state codes `1..0x15`:

| State | Target | Notes |
| ---: | --- | --- |
| `1` | `EBBB:0196` -> `EBBB:0BF4` | Test-menu navigation. |
| `2` | `EBBB:019C` -> `EBBB:1250` | Live supplied-text test. |
| `3` | `EBBB:01A2` -> `EBBB:0550` | Scoreboard wrapper. |
| `4` | `EBBB:01A8` -> `EBBB:0568` | Scoreboard renderer. |
| `5` | `EBBB:01AE` -> `EBBB:182C` | Error-review header/status setup. |
| `6` | `EBBB:01B4` | Resets `[8E52]` and `[8E54]` to zero. |
| `7` | `EBBB:01C3` -> `EBBB:0274` | Intro/about screen and title animation. |
| `8` | `EBBB:01C9` -> `EBBB:047C` | Corpus choice screen. |
| `9` | `EBBB:01CF` -> `EBBB:1190` | Start-test handler. |
| `10` | `EBBB:01D5` -> `EBBB:0A56` | Menu-of-tests shell/reset handoff. |
| `11` | `EBBB:01DB` | No-op return to dispatcher loop. |
| `12` | `EBBB:01DE` -> `EBBB:0EC6` | Live-test footer/status prompt. |
| `13` | `EBBB:01E4` -> `EBBB:08B8` | Scoreboard command handler. |
| `14` | `EBBB:01EA` -> `EBBB:1862` | Options screen shell. |
| `15` | `EBBB:01F0` -> `EBBB:188C` | Options value renderer. |
| `16` | `EBBB:01F6` -> `EBBB:19C0` | Options navigation/value handler. |
| `17` | `EBBB:01FC` -> `EBBB:0A82` | Menu-of-tests grid renderer. |
| `18` | `EBBB:0202` -> `EBBB:0EF6` | Selected-test text pager. |
| `19` | `EBBB:0208` -> `EBBB:1B80` | Error-review renderer. |
| `20` | `EBBB:020E` -> `EBBB:1DB8` | Error-review pager. |
| `21` | `EBBB:0214` -> `EBBB:157A` | Live free-entry `YOURS` test. |

`EBBB:012E` returns `[8E90]` when `[8E54]` reaches zero. The OTHERS wrapper
only treats a low-byte `0x0B` return as a menu exit; other returns redraw the
OTHERS menu with `T I M E` selected.

The app internals are bottomed in [`typin-time.md`](typin-time.md).

## ROM CARD Loader

`DC98:2B75`, file offset `0x5F4F5`, is the complete OTHERS -> `ROM CARD`
loader. It searches for a normal filesystem entry named `EROMCARD.X`, loads it
to RAM at `0xA4F0`, validates the header words, calls the payload's far entry
pointer, and then runs the C688 cleanup path.

```asm
rom_card_loader_DC98_2B75:
; file 0x5F4F5
DC98:2B75  55                push bp
DC98:2B76  8B EC             mov  bp,sp
DC98:2B78  83 EC 44          sub  sp,0x44
DC98:2B7B  51                push cx
DC98:2B7C  52                push dx
DC98:2B7D  56                push si
DC98:2B7E  57                push di
DC98:2B7F  9A 70 0E 98 DC    call DC98:0E70
DC98:2B84  8D 5E EC          lea  bx,[bp-0x14]
DC98:2B87  C7 46 E8 00 00    mov  word [bp-0x18],0
DC98:2B8C  C7 46 EA 7A EF    mov  word [bp-0x16],0xef7a ; EF7A:0000
DC98:2B91  B8 00 00          mov  ax,0
DC98:2B94  8E C0             mov  es,ax
DC98:2B96  26 A0 05 68       mov  al,[es:0x6805]
DC98:2B9A  FE C0             inc  al
DC98:2B9C  88 07             mov  [bx],al
DC98:2B9E  43                inc  bx
DC98:2B9F  C6 07 3A          mov  byte [bx],':'
...
DC98:2BBE  9A 7B EF 98 DC    call DC98:EF7B       ; find first
DC98:2BC3  85 C0             test ax,ax
DC98:2BC5  74 54             jz   DC98:2C1B       ; found
DC98:2BC7  B8 00 00          mov  ax,0
DC98:2BCA  8E C0             mov  es,ax
DC98:2BCC  26 A0 05 68       mov  al,[es:0x6805]
DC98:2BD0  88 46 EC          mov  [bp-0x14],al
...
DC98:2BDC  9A 7B EF 98 DC    call DC98:EF7B       ; fallback find first
DC98:2BE1  85 C0             test ax,ax
DC98:2BE3  74 36             jz   DC98:2C1B       ; found
```

The path buffer at `[bp-0x14]` is first populated as
`([0x6805] + 1):EROMCARD.X`. If that candidate is not found, the same buffer is
rewritten as `[0x6805]:EROMCARD.X` and probed again. `DC98:EF7B` sets the
caller's DTA and then performs find-first through the DOS-like file layer.

If neither candidate exists, the loader displays a two-line message and waits
for `0x03` or `0x0B`:

```asm
DC98:2BE5  B8 00 00          mov  ax,0
DC98:2BE8  BB 96 EF          mov  bx,0xef96
DC98:2BEB  B9 A2 00          mov  cx,0x00a2
DC98:2BEE  BA 14 00          mov  dx,0x0014
DC98:2BF1  9A 81 0E 98 DC    call DC98:0E81
DC98:2BF6  B8 0C 00          mov  ax,0x000c
DC98:2BF9  BB 97 EF          mov  bx,0xef97
DC98:2BFC  B9 B7 00          mov  cx,0x00b7
DC98:2BFF  BA 28 00          mov  dx,0x0028
DC98:2C02  9A 81 0E 98 DC    call DC98:0E81
DC98:2C07  9A F9 0C 98 DC    call DC98:0CF9
```

String descriptors and final formatted text:

```text
EF7A:0000 char* filename
EROMCARD.X

EF96:0000 char*
No ROM card is in the slot

EF97:000C char* with F8/F9 style controls around CAN and F2 at end
Press CAN to exit
```

After a successful find-first, the DTA size fields at `[bp-0x29]` and
`[bp-0x27]` are compared against the C688 work-memory limit:

```asm
DC98:2C1B  9A E6 01 88 C6    call C688:01E6
DC98:2C20  8B F8             mov  di,ax           ; byte work-memory limit
DC98:2C22  33 DB             xor  bx,bx
DC98:2C24  8B C7             mov  ax,di
DC98:2C26  2B 46 D7          sub  ax,[bp-0x29]    ; file size low
DC98:2C29  1B 5E D9          sbb  bx,[bp-0x27]    ; file size high
DC98:2C2C  7D 3B             jnl  DC98:2C69
DC98:2C2E  9A 0C 02 88 C6    call C688:020C
...
```

Oversized files are rejected before opening:

```text
EF99:0004 char*
Inadequate work memory

EF97:000C char* with F8/F9/F2 controls
Press CAN to exit
```

The load path opens the same candidate path, reads the full file into the fixed
RAM load address, and closes the handle:

```asm
DC98:2C69  33 C0             xor  ax,ax
DC98:2C6B  50                push ax              ; mode 0
DC98:2C6C  8D 46 EC          lea  ax,[bp-0x14]
DC98:2C6F  50                push ax
DC98:2C70  9A 46 E9 98 DC    call DC98:E946       ; open
DC98:2C78  8B F0             mov  si,ax           ; handle
DC98:2C7A  83 FE 00          cmp  si,0
DC98:2C7D  7D 20             jnl  DC98:2C9F
...
DC98:2C9F  8B C6             mov  ax,si
DC98:2CA1  BB F0 A4          mov  bx,0xa4f0
DC98:2CA4  8B 4E D7          mov  cx,[bp-0x29]
DC98:2CA7  9A 08 EE 98 DC    call DC98:EE08       ; read
...
DC98:2CDB  8B C6             mov  ax,si
DC98:2CDD  9A 2E EE 98 DC    call DC98:EE2E       ; close
```

Failure strings:

```text
EF9A:000C char*
Can not open EROMCARD.X

EF9C:0004 char*
Not enough memory
```

The ROM-card-specific executable check happens only after the file is loaded:

```asm
DC98:2CE2  8B 1E F0 A4       mov  bx,[0xa4f0]
DC98:2CE6  A1 F2 A4          mov  ax,[0xa4f2]
DC98:2CE9  3D 97 19          cmp  ax,0x1997
DC98:2CEC  75 04             jnz  DC98:2CF2
DC98:2CEE  81 FB F0 A4       cmp  bx,0xa4f0
DC98:2CF2  74 1F             jz   DC98:2D13
DC98:2CF4  9A 0C 02 88 C6    call C688:020C
DC98:2CF9  B8 06 00          mov  ax,0x0006
DC98:2CFC  BB 9D EF          mov  bx,0xef9d
DC98:2CFF  B9 BD 00          mov  cx,0x00bd
DC98:2D02  BA 14 00          mov  dx,0x0014
DC98:2D05  9A 81 0E 98 DC    call DC98:0E81
```

```text
EF9D:0006 char*
ROM Card ID error
```

The accepted `EROMCARD.X` header for this ROM is:

| File offset | Required value |
| ---: | --- |
| `+0x00` | Word `0xA4F0`, matching the RAM load address. |
| `+0x02` | Word `0x1997`, the local executable signature. |
| `+0x04` | Far entry pointer, stored as offset then segment. |

The launch path passes the same byte work-memory limit in `AX`, calls the
payload through `C688:022B`, stores its return value, runs cleanup, and returns
that value to the OTHERS wrapper:

```asm
DC98:2D13  8B C7             mov  ax,di
DC98:2D15  9A 2B 02 88 C6    call C688:022B       ; call far [0xA4F4]
DC98:2D1A  8B C8             mov  cx,ax
DC98:2D1C  9A 0C 02 88 C6    call C688:020C
DC98:2D21  8B C1             mov  ax,cx
DC98:2D23  5F                pop  di
DC98:2D24  5E                pop  si
DC98:2D25  5A                pop  dx
DC98:2D26  59                pop  cx
DC98:2D27  8B E5             mov  sp,bp
DC98:2D29  5D                pop  bp
DC98:2D2A  C3                ret
```

`ROM CARD` therefore bottoms out here as a file loader, not as an
execute-in-place card mapping path. The broader loader ABI and example payload
format are summarized in [`../running-rom-card-binaries.md`](../../../docs/running-rom-card-binaries.md).

## Next Splits

No remaining OTHERS-handler-only roots are queued.
