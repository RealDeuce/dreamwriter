# Diagnostic Monitor

This slice expands the diagnostic command parser rooted at `C000:128F`, reached
from [`diagnostics-ui.md`](diagnostics-ui.md). It covers the built-in monitor
commands, dump/set/single-step plumbing, local output helpers, and the boundary
to the already documented [`diagnostic-int1.md`](diagnostic-int1.md) hook.

No image assets are reached in this slice.

String/display resources:

- The diagnostic banner/help page is documented in
  [`diagnostics-ui.md`](diagnostics-ui.md).
- This slice also reaches two raw ASCII status strings used by the single-step
  command.

## Entry And Chord

`C000:1240` is the warm-path diagnostic gate. It calls `C000:1252`, which
compares keyboard matrix bytes at `6D06..6D0F` against the expected
`SPACE+F+J` chord bytes stored at `C000:1268`.

```asm
diagnostic_gate_C000_1240:
; file 0x41240
C000:1240  E8 0F 00          call C000:1252
C000:1243  74 02             jz   C000:1247
C000:1245  F8                clc
C000:1246  C3                ret
C000:1247  E8 28 00          call C000:1272
C000:124A  E8 42 00          call C000:128F
C000:124D  72 02             jc   C000:1251
C000:124F  EB F6             jmp  C000:1247
C000:1251  C3                ret
```

The compare helper preserves `ES` and returns with flags from `or cx,cx`.

```asm
diagnostic_chord_compare_C000_1252:
; file 0x41252
C000:1252  06                push es
C000:1253  BF 00 C0          mov  di,0xc000
C000:1256  8E C7             mov  es,di
C000:1258  BF 68 12          mov  di,0x1268
C000:125B  BE 06 6D          mov  si,0x6d06
C000:125E  B9 0A 00          mov  cx,0x000a
C000:1261  FC                cld
C000:1262  F3 A6             repe cmpsb
C000:1264  07                pop  es
C000:1265  0B C9             or   cx,cx
C000:1267  C3                ret
```

Chord bytes:

```text
file 0x41268:
00 08 00 00 80 00 00 00 40 00
```

## Startup Banner

`C000:1272` clears/initializes the diagnostic display and renders the first
`0x42` bytes from `C688:0086`, file `0x46906`. The full resource is decoded in
[`diagnostics-ui.md`](diagnostics-ui.md).

```asm
diagnostic_draw_short_banner_C000_1272:
; file 0x41272
C000:1272  9A 0E 00 98 DC    call DC98:000E
C000:1277  BE 86 00          mov  si,0x0086
C000:127A  BA 88 C6          mov  dx,0xc688
C000:127D  B9 42 00          mov  cx,0x0042
C000:1280  E8 53 48          call C000:5AD6
C000:1283  B8 00 00          mov  ax,0
C000:1286  BB 02 00          mov  bx,2
C000:1289  9A 2A 00 98 DC    call DC98:002A
C000:128E  C3                ret
```

## Command Line State

The monitor uses a small command line and parsed-command state block:

| RAM | Meaning |
| ---: | --- |
| `6C06..6C86` | NUL-terminated typed command line. |
| `6C56..6C66` | Sixteen-byte row scratch used for printable ASCII after hex bytes. |
| `6EB5` | Current edit pointer into `6C06..6C86`. |
| `6EB7` | Parsed segment/base word, or I/O high/base word. |
| `6EB9` | Parsed offset/port word. |
| `6EBB` | Active command letter; defaults to `M`. |
| `6EBC` | Single-step watched IP for `INT 1`. |
| `6EBE` | Single-step watched CS for `INT 1`. |
| `6EC0` | Single-step state byte consumed by the installed `INT 1` hook. |

The reset helper clears the parser state and sets the default command to memory
dump:

```asm
diagnostic_reset_command_state_C000_15FE:
; file 0x415FE
C000:15FE  C7 06 B7 6E 0000  mov  word [0x6eb7],0
C000:1604  C7 06 B5 6E 066C  mov  word [0x6eb5],0x6c06
C000:160A  8B 1E B5 6E       mov  bx,[0x6eb5]
C000:160E  C6 07 00          mov  byte [bx],0
C000:1611  C6 06 BB 6E 4D    mov  byte [0x6ebb],'M'
C000:1616  C3                ret
```

## Command Loop

`C000:128F` is the interactive parser. It clears diagnostic bit `0x08` in
`[6D51]`, initializes the command line, waits for key input through `C000:08A3`,
updates the typed buffer through `C000:1617`, and dispatches on special keys.

```asm
diagnostic_command_loop_C000_128F:
; file 0x4128F
C000:128F  80 26 51 6D F7    and  byte [0x6d51],0xf7
C000:1294  E8 67 03          call C000:15FE
C000:1297  B8 01 00          mov  ax,1
C000:129A  9A 1C 00 98 DC    call DC98:001C
C000:129F  E8 01 F6          call C000:08A3
C000:12A2  E8 72 03          call C000:1617
C000:12A5  3C 01             cmp  al,1
C000:12A7  74 34             jz   diagnostic_reset_C000_12DD
C000:12A9  0A C0             or   al,al
C000:12AB  74 EA             jz   C000:1297
C000:12AD  3C 0B             cmp  al,0x0b
C000:12AF  74 1D             jz   diagnostic_exit_C000_12CE
C000:12B1  3C 02             cmp  al,0x02
C000:12B3  74 19             jz   diagnostic_exit_C000_12CE
C000:12B5  3C 03             cmp  al,0x03
C000:12B7  74 15             jz   diagnostic_exit_C000_12CE
C000:12B9  3C 3F             cmp  al,'?'
C000:12BB  74 13             jz   diagnostic_help_C000_12D0
C000:12BD  3C 4B             cmp  al,'K'
C000:12BF  74 14             jz   diagnostic_keyboard_C000_12D5
C000:12C1  3C 6B             cmp  al,'k'
C000:12C3  74 10             jz   diagnostic_keyboard_C000_12D5
C000:12C5  3C DA             cmp  al,0xda
C000:12C7  74 66             jz   diagnostic_parse_enter_C000_132F
C000:12C9  E8 A8 03          call C000:1674
C000:12CC  EB C9             jmp  C000:1297
```

Exit keys `0x0B`, `0x02`, and `0x03` return carry set to the warm diagnostic
gate. A typed reset key `0x01` recalculates a checksum-like word through
`C000:044B`, writes `[6D59]=0x55`, and jumps to the cold reset path at
`C000:0029`.

```asm
diagnostic_exit_C000_12CE:
C000:12CE  F9                stc
C000:12CF  C3                ret

diagnostic_help_C000_12D0:
C000:12D0  E8 18 04          call C000:16EB
C000:12D3  EB C2             jmp  C000:1297

diagnostic_keyboard_C000_12D5:
C000:12D5  E8 CE 03          call C000:16A6
C000:12D8  E8 97 FF          call C000:1272
C000:12DB  EB B2             jmp  C000:128F

diagnostic_reset_C000_12DD:
C000:12DD  E8 6B F1          call C000:044B
C000:12E0  C6 06 59 6D 55    mov  byte [0x6d59],0x55
C000:12E5  E9 41 ED          jmp  C000:0029
```

## Command Dispatch

When the user presses the `0xDA` enter/select key, the parser scans the command
line at `6C06`, uppercases the command letter, and collects hexadecimal fields.

Recognized command letters:

| Command | Parser path | Current interpretation |
| --- | --- | --- |
| `Mxxxx:yyyy` | command byte `M` | Dump memory from `segment=xxxx`, `offset=yyyy`. |
| `Iyyyy` | command byte `I` | Dump I/O ports starting at `yyyy`; no segment prefix is printed. |
| `L` | command byte `L` | Write `0xF9` to port `0xDD`, dump from I/O port `0x00D0`, then restore `0xF8` to `0xDD`. |
| `Sxxxx:yyyy,zz` | command byte `S` | Write byte `zz` to memory `xxxx:yyyy`, then redisplay one byte at that address. |
| `Yxxxx:yyyy` | command byte `Y` | Set `6EC0=1`, seed the watched CS:IP, and toggle trap flag. |
| `Zxxxx:yyyy` | command byte `Z` | Seed the watched CS:IP with `6EC0=0`, and toggle trap flag. |
| `T` | inline path | Write `[6D94] | 0x80` to port `0x30`; diagnostic help labels this `Card ATTR`. |
| `N` | inline path | Write `[6D94] & 0x7F` to port `0x30`; diagnostic help labels this `COM`. |
| `Q` | service path | Calls banked linguistic service ID `0x58`, labelled `Clear spell` by help text, then falls through to the `P`-style dump base. See [`diagnostic-spell-services.md`](diagnostic-spell-services.md). |
| `R` | service path | Calls banked linguistic service ID `0x59`, labelled `Reset spell` by help text, writes setup values to ports `0x13`/`0x14`, then falls through to the `P`-style dump base. See [`diagnostic-spell-services.md`](diagnostic-spell-services.md). |
| `P` | command byte `P` | Selects a built-in dump base of `0000:3000`, then falls into the dump engine. |

The command scanner accepts hex digits by folding letters to uppercase and
packing each nibble into `DX`.

```asm
diagnostic_parse_enter_C000_132F:
; file 0x4132F
C000:132F  E8 86 03          call C000:16B8       ; CR/LF
C000:1332  B8 00 00          mov  ax,0
C000:1335  9A 1C 00 98 DC    call DC98:001C
C000:133A  BB 06 6C          mov  bx,0x6c06
C000:133D  8A 07             mov  al,[bx]
C000:133F  3C DA             cmp  al,0xda
C000:1341  74 A5             jz   C000:12E8
C000:1343  BA 00 00          mov  dx,0
C000:1346  B1 04             mov  cl,4
C000:1348  24 DF             and  al,0xdf
...
C000:1376  43                inc  bx
C000:1377  25 5F 00          and  ax,0x005f
C000:137A  3C 41             cmp  al,'A'
C000:137C  72 04             jc   C000:1382
C000:137E  2C 37             sub  al,0x37
C000:1382  24 0F             and  al,0x0f
C000:1384  D3 E2             shl  dx,cl
C000:1386  0B D0             or   dx,ax
```

Field separators:

```text
':' stores the current DX into [6EB7] and starts a new field.
',' stores the current DX into [6EB9] and starts a new field.
0xDA finishes the command and dispatches through [6EBB].
```

## Dump Engine

The dump engine displays addresses, sixteen hex bytes per line, and an ASCII
sidecar. For memory commands, `6EB7:6EB9` is the source. For `I` and `L`, the
source is the I/O port in `6EB9`.

```asm
diagnostic_dump_engine_C000_1409:
; file 0x41409
C000:1409  BA 07 00          mov  dx,7           ; default seven rows
C000:140C  52                push dx
C000:140D  80 3E BB 6E 49    cmp  byte [0x6ebb],'I'
C000:1412  74 13             jz   C000:1427
C000:1414  80 3E BB 6E 4C    cmp  byte [0x6ebb],'L'
C000:1419  74 0C             jz   C000:1427
C000:141B  8B 1E B7 6E       mov  bx,[0x6eb7]
C000:141F  E8 23 02          call C000:1645      ; print segment
C000:1422  B0 3A             mov  al,':'
C000:1424  E8 4D 02          call C000:1674
C000:1427  8B 1E B9 6E       mov  bx,[0x6eb9]
C000:142B  E8 17 02          call C000:1645      ; print offset/port
...
C000:1439  B9 10 00          mov  cx,0x0010
C000:143E  E8 73 00          call C000:14B4      ; read one byte
C000:1441  46                inc  si
C000:1442  89 36 B9 6E       mov  [0x6eb9],si
C000:1447  E8 06 02          call C000:1650      ; print byte as hex
...
C000:1467  E8 70 00          call C000:14DA      ; print ASCII sidecar
C000:146A  E8 4B 02          call C000:16B8      ; CR/LF
C000:146D  4A                dec  dx
C000:146E  75 9C             jnz  C000:140C
```

The byte reader switches between memory and I/O based on the active command:

```asm
diagnostic_read_dump_byte_C000_14B4:
; file 0x414B4
C000:14B4  8C D9             mov  cx,ds
C000:14B6  8B 36 B9 6E       mov  si,[0x6eb9]
C000:14BA  80 3E BB 6E 49    cmp  byte [0x6ebb],'I'
C000:14BF  74 13             jz   C000:14D4
C000:14C1  80 3E BB 6E 4C    cmp  byte [0x6ebb],'L'
C000:14C6  74 0C             jz   C000:14D4
C000:14C8  8B 16 B7 6E       mov  dx,[0x6eb7]
C000:14CC  8E DA             mov  ds,dx
C000:14CE  8A 1C             mov  bl,[si]
C000:14D0  8E D9             mov  ds,cx
C000:14D2  EB 05             jmp  C000:14D9
C000:14D4  8B D6             mov  dx,si
C000:14D6  EC                in   al,dx
C000:14D7  8A D8             mov  bl,al
C000:14D9  C3                ret
```

After seven rows, `L` restores the RTC/alarm control write:

```asm
C000:1470  80 3E BB 6E 4C    cmp  byte [0x6ebb],'L'
C000:1475  75 04             jnz  C000:147B
C000:1477  B0 F8             mov  al,0xf8
C000:1479  E6 DD             out  0xdd,al
```

The navigation keys after a dump page are:

| Key | Behavior |
| ---: | --- |
| `0x12` | Draw next page from the current post-dump address. |
| `0x13` | Draw previous page. The code subtracts `0xE0` after the 7-row dump, producing a net `-0x70` page step from the original page start. |
| `0x0B`, `0x03` | Return carry set to the diagnostic gate. |
| Other | Return carry clear to redraw the diagnostic banner and command loop. |

## Set Memory

The `S` command writes one byte to memory at `6EB7:6EB9`, then switches the
active command to `M` and redisplays one byte.

```asm
diagnostic_set_memory_C000_13E6:
; file 0x413E6
C000:13E6  8B 3E B9 6E       mov  di,[0x6eb9]
C000:13EA  8B 36 B7 6E       mov  si,[0x6eb7]
C000:13EE  1E                push ds
C000:13EF  8E DE             mov  ds,si
C000:13F1  88 15             mov  [di],dl
C000:13F3  1F                pop  ds
C000:13F4  C6 06 BB 6E 4D    mov  byte [0x6ebb],'M'
C000:13F9  BA 01 00          mov  dx,1
C000:13FC  EB 0E             jmp  C000:140C
```

## Single-Step Commands

`Y` and `Z` store a watched CS:IP for the installed `INT 1` hook, then toggle
the CPU trap flag by editing the FLAGS word saved by `pushf`.

```asm
diagnostic_single_step_C000_14FA:
; file 0x414FA
C000:14FA  89 16 B9 6E       mov  [0x6eb9],dx
C000:14FE  8B 1E B9 6E       mov  bx,[0x6eb9]
C000:1502  89 1E BC 6E       mov  [0x6ebc],bx
C000:1506  8B 1E B7 6E       mov  bx,[0x6eb7]
C000:150A  89 1E BE 6E       mov  [0x6ebe],bx
C000:150E  B8 00 00          mov  ax,0
C000:1511  9A 1C 00 98 DC    call DC98:001C
C000:1516  9C                pushf
C000:1517  8B EC             mov  bp,sp
C000:1519  81 76 00 00 01    xor  word [bp+0],0x0100
C000:151E  F7 46 00 00 01    test word [bp+0],0x0100
C000:1523  74 25             jz   trap_removed_C000_154A
```

`Y` sets `[6EC0]=1` before entering this block. `Z` leaves `[6EC0]=0`.

Raw string descriptors:

```text
file 0x4155E / C000:155E:
char[15] "TRAP WAS SET AT"

file 0x4156D / C000:156D:
char[16] "TRAP WAS REMOVED"
```

Final formatted status text:

```text
TRAP WAS SET AT xxxx:yyyy
TRAP WAS REMOVED
```

The `xxxx:yyyy` address is printed from `[6EB7]:[6EB9]` after the `TRAP WAS SET
AT` string.

## Keyboard And Help Helpers

The `K` command temporarily sets bit `0x01` in `[6D51]`, calls `DC98:0CA2`, then
clears the bit. The keyboard-check screen/action is expanded in
[`diagnostic-keyboard-check.md`](diagnostic-keyboard-check.md).

```asm
diagnostic_keyboard_check_C000_16A6:
; file 0x416A6
C000:16A6  80 0E 51 6D 01    or   byte [0x6d51],0x01
C000:16AB  06                push es
C000:16AC  9A A2 0C 98 DC    call DC98:0CA2
C000:16B1  07                pop  es
C000:16B2  80 26 51 6D FE    and  byte [0x6d51],0xfe
C000:16B7  C3                ret
```

The `?` helper redraws the full help page using `0xF9` bytes from the
diagnostic display resource:

```asm
diagnostic_help_page_C000_16EB:
; file 0x416EB
C000:16EB  B8 00 00          mov  ax,0
C000:16EE  9A 1C 00 98 DC    call DC98:001C
C000:16F3  BE 86 00          mov  si,0x0086
C000:16F6  BA 88 C6          mov  dx,0xc688
C000:16F9  B9 F9 00          mov  cx,0x00f9
C000:16FC  E8 D7 43          call C000:5AD6
C000:16FF  E8 FC FE          call C000:15FE
C000:1702  B8 00 00          mov  ax,0
C000:1705  BB 07 00          mov  bx,7
C000:1708  9A 2A 00 98 DC    call DC98:002A
C000:170D  C3                ret
```

## Output Helpers

The monitor prints through `DC98:0038`.

```asm
diagnostic_putc_C000_1674:
; file 0x41674
C000:1674  3C 08             cmp  al,0x08
C000:1676  74 10             jz   diagnostic_backspace_C000_1688
C000:1678  3C 20             cmp  al,0x20
C000:167A  72 0B             jc   C000:1687
C000:167C  3C D0             cmp  al,0xd0
C000:167E  73 07             jnc  C000:1687
C000:1680  B4 00             mov  ah,0
C000:1682  9A 38 00 98 DC    call DC98:0038
C000:1687  C3                ret
```

Hex helpers:

```text
C000:1645  print BX as four hex digits.
C000:1650  print BL as two hex digits.
C000:1664  print low nibble of BL as one hex digit.
C000:14DA  print printable ASCII sidecar, replacing <0x20 and >=0xC0 with '.'.
C000:16B8  print CR/LF.
```

## Next Splits

No remaining diagnostic-monitor splits are queued outside application handlers.
