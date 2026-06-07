# Setup Screens

This slice expands the small word-processor setup/settings handlers reached
from [`wp-submenus.md`](wp-submenus.md):

| Entry | File | Menu path | Backing state |
| --- | ---: | --- | --- |
| `DC98:22A1` | `0x5EC21` | COMMUNICATE -> SET UP, PRINTER -> SET UP 2 | RS-232 bytes `6D2A..6D2E`. |
| `DC98:24DB` | `0x5EE5B` | PRINTER -> SET UP 1 | Printer bytes `6D59..6D5B`. |
| `DC98:288A` | `0x5F20A` | OTHERS -> SYSTEM | Auto-off/buzzer bytes `6D2F..6D31`. |
| `DC98:2A83` | `0x5F403` | OTHERS -> PREFERENCES | Grammar/sticky-shift bytes `6D55`, `6D24`. |

No image assets are reached here. These screens use the display text/resource
helpers documented in [`display-wrappers.md`](display-wrappers.md) and the
shared field selector at `DC98:214E`.

`EBBB:0000`, the OTHERS -> `T I M E` target, is expanded separately in
[`wp-others-handlers.md`](wp-others-handlers.md), with app internals in
[`typin-time.md`](typin-time.md). Its correct file base is `0x6BBB0`, and the
entry fans out through a much larger application-style dispatcher rather than
one of these compact settings editors.

## Shared Field Selector

`DC98:214E` is the common option-field editor. Callers pass:

```text
AX:BX = NUL-terminated option-line string
CX    = pointer to the selected option word
DX    = field width/limit used by the draw helper
stack = y, x, active_flag/style words
```

The helper counts `{` characters in the option-line string to determine how many
choices are available, draws the line through the local render helper at
`DC98:20AA`, and when active waits for `DC98:0CF9`.

Accepted active-field keys:

| Key | Behavior |
| ---: | --- |
| `0x10` | Increment selected option when not already at the last `{...}` item. |
| `0x11` | Decrement selected option when above zero. |
| `0x12` | Return to caller as a row-navigation key when enabled by flags. |
| `0x13` | Return to caller as a row-navigation key when enabled by flags. |
| `0x20` | Return Space when enabled by flags. |
| `0xDA` | Accept current field value and return. |
| `0x03`, `0x0B`, optionally `0x02` | Cancel/exit according to caller flags. |

`DC98:1859` stores an optional far callback at `74E5:74E7`. `DC98:214E` calls
that callback while waiting for input if no key is pending. The printer setup
screen uses this to redraw the interface row when the selected printer model
forces a different interface default.

## RS-232 Setup

`DC98:22A1` draws the RS-232 setup page, copies the current RS-232 setup bytes
into stack locals, edits five rows, and commits only on `0xDA`.

```asm
rs232_setup_DC98_22A1:
; file 0x5EC21
DC98:22A1  55                push bp
DC98:22A2  8B EC             mov  bp,sp
DC98:22A4  83 EC 0A          sub  sp,0x0a
...
DC98:22AB  9A 70 0E 98 DC    call DC98:0E70
DC98:22B0  B8 0C 00          mov  ax,0x000c
DC98:22B3  BB C4 EF          mov  bx,0xefc4
DC98:22BB  9A 81 0E 98 DC    call DC98:0E81       ; title
...
DC98:22C0  A0 2A 6D          mov  al,[0x6d2a]
DC98:22C5  2D 03 00          sub  ax,3            ; baud UI index 0..4
...
DC98:2456  81 FF DA 00       cmp  di,0x00da
DC98:245A  75 24             jnz  not_accept
DC98:245C  8B 46 F6          mov  ax,[bp-0x0a]
DC98:245F  04 03             add  al,3
DC98:2461  A2 2A 6D          mov  [0x6d2a],al
DC98:2464  8B 46 F8          mov  ax,[bp-0x08]
DC98:2467  A2 2B 6D          mov  [0x6d2b],al
DC98:246A  8B 46 FA          mov  ax,[bp-0x06]
DC98:246D  A2 2C 6D          mov  [0x6d2c],al
DC98:2470  8B 46 FC          mov  ax,[bp-0x04]
DC98:2473  A2 2D 6D          mov  [0x6d2d],al
DC98:2476  8B 46 FE          mov  ax,[bp-0x02]
DC98:2479  A2 2E 6D          mov  [0x6d2e],al
```

State mapping:

| UI row | Options | Backing byte |
| --- | --- | --- |
| `BAUD RATE` | `1200`, `2400`, `4800`, `9600`, `19200` | `[6D2A] = selected_index + 3`. |
| `BIT LENGTH` | `7`, `8` | `[6D2B] = selected_index`. |
| `STOP BITS` | `1`, `2` | `[6D2C] = selected_index`. |
| `PARITY` | `NONE`, `ODD`, `EVEN` | `[6D2D] = selected_index`. |
| `X ON/OFF` | `DISABLE`, `ENABLE` | `[6D2E] = selected_index`. |

String descriptors and final formatted text:

```text
EFC4:000C char* with style controls E4 E4 F8 before text
RS-232C SET UP

EFD2:0008 char* option line
BAUD RATE : {1200} {2400} {4800} {9600} {19200}

EFD5:0008 char* option line
BIT LENGTH: { 7 }   { 8 }

EFD7:0002 char* option line
STOP BITS : { 1 }   { 2 }

EFD8:000C char* option line
PARITY    : {NONE}  {ODD}  {EVEN}

EFDA:000E char* option line
X ON/OFF  : {DISABLE}   {ENABLE}
```

## Printer Setup

`DC98:24DB` edits printer model, interface, and paper-feed mode. It mirrors the
backing bytes into scratch words at `6D5C`, `6D5E`, and `6D60`, then commits
only on `0xDA`.

```asm
printer_setup_DC98_24DB:
; file 0x5EE5B
DC98:24DB  51                push cx
DC98:24DC  52                push dx
DC98:24DD  56                push si
DC98:24DE  57                push di
DC98:24DF  9A 70 0E 98 DC    call DC98:0E70
...
DC98:24F5  A0 59 6D          mov  al,[0x6d59]
DC98:24F8  A2 62 6D          mov  [0x6d62],al
DC98:2501  A0 59 6D          mov  al,[0x6d59]
DC98:2506  A3 5C 6D          mov  [0x6d5c],ax
...
DC98:258D  B8 99 24          mov  ax,0x2499
DC98:2590  BB 98 DC          mov  bx,0xdc98
DC98:2593  9A 59 18 98 DC    call DC98:1859       ; install redraw callback
...
DC98:2631  A1 5C 6D          mov  ax,[0x6d5c]
DC98:2634  A2 59 6D          mov  [0x6d59],al
DC98:2637  A1 5E 6D          mov  ax,[0x6d5e]
DC98:263A  A2 5A 6D          mov  [0x6d5a],al
DC98:263D  A1 60 6D          mov  ax,[0x6d60]
DC98:2640  A2 5B 6D          mov  [0x6d5b],al
```

The callback at `DC98:2499` keeps the interface row consistent while the printer
model row is active. If the currently selected model word at `[6D5C]` is `6`
and the previous model byte `[6D62]` is not `6`, it forces `[6D5E]=1`;
otherwise it restores the interface selection from `[6D63]`. It then redraws
the interface field.

State mapping:

| UI row | Options | Backing byte |
| --- | --- | --- |
| `PRINTER` | `X24E`, `XIII`, `LQ`, `FX`, `BJ-10e`, `JET`, `WRITER` | `[6D59]`. |
| `INTERFACE` | `PARALLEL`, `SERIAL` | `[6D5A]`. |
| `PAPER FEED` | `AUTOMATIC`, `MANUAL` | `[6D5B]`. |

String descriptors and final formatted text:

```text
EFC3:000C char* with style control F8 before text
PRINTER SET UP

EFC5:000E char* model-family header with E2 style separators
            IBM   IBM  EPSON  EPSON  CANON   HP   IMAGE

EFC9:000A char* option line with E2 style separators
PRINTER   : {X24E}  {XIII}   {LQ}     {FX}   {BJ-10e}  {JET}  {WRITER}

EFCE:0004 char* option line
INTERFACE : {PARALLEL}   {SERIAL}

EFD0:0006 char* option line
PAPER FEED: {AUTOMATIC}  {MANUAL}
```

## System Settings

`DC98:288A` edits auto power-off and power-on buzzer settings. It commits only
on `0xDA`; `0x03` and `0x0B` return without storing the local selections.

```asm
system_settings_DC98_288A:
; file 0x5F20A
DC98:288A  55                push bp
DC98:288B  8B EC             mov  bp,sp
DC98:288D  83 EC 06          sub  sp,0x06
...
DC98:2894  9A 70 0E 98 DC    call DC98:0E70
DC98:2899  B8 0C 00          mov  ax,0x000c
DC98:289C  BB 81 EF          mov  bx,0xef81
DC98:289F  B9 14 00          mov  cx,0x0014
DC98:28A2  9A AD 67 00 C0    call C000:67AD       ; title stream
...
DC98:2966  83 FF 20          cmp  di,0x20
DC98:296B  83 7E FC 03       cmp  word [bp-0x04],3
DC98:2971  8B 46 FC          mov  ax,[bp-0x04]
DC98:2974  9A 7C 07 00 C0    call C000:077C       ; preview buzzer type
...
DC98:298D  8B 46 FA          mov  ax,[bp-0x06]
DC98:2990  A2 2F 6D          mov  [0x6d2f],al
DC98:2993  8B 46 FC          mov  ax,[bp-0x04]
DC98:2996  A2 30 6D          mov  [0x6d30],al
DC98:29A8  B8 79 EF          mov  ax,0xef79
DC98:29AD  8B 5E FA          mov  bx,[bp-0x06]
DC98:29B2  26 8B 87 02 00    mov  ax,[es:bx+0x0002]
DC98:29B7  A3 31 6D          mov  [0x6d31],ax
```

Space previews the buzzer sound when the buzzer selection is `TYPE 1..3`.
Selection `NO` is value `3` and skips the preview call.

Auto-off table at `EF79:0002`, file `0x6F792`:

| UI choice | `[6D2F]` | `[6D31]` reload |
| --- | ---: | ---: |
| `2` minutes | `0` | `0x04B0` / `1200` |
| `3` minutes | `1` | `0x0708` / `1800` |
| `5` minutes | `2` | `0x0BB8` / `3000` |
| `10` minutes | `3` | `0x1770` / `6000` |
| `15` minutes | `4` | `0x2328` / `9000` |
| `20` minutes | `5` | `0x2EE0` / `12000` |
| `UNLIMITED` | `6` | `0x0000` |

The reload values match a 10 Hz idle counter.

String/display descriptors and final formatted text:

```text
EF81:000C display stream, length 0x14
FF 02 01 00 14 00 F8 "SYSTEM SET UP"

SYSTEM SET UP

EF83:0000 char* option line
AUTO POWER OFF PERIOD   : { 2 } { 3 } { 5 } { 10 } { 15 } { 20 } { UNLIMITED }

EF88:0000 char*
(minutes)

EF88:000A char* option line
POWER ON BUZZER         : { TYPE 1 } { TYPE 2 } { TYPE 3 } { NO }

EF8C:000C char* instruction
(Press SPACE to hear the sound)
```

One nearby write remains noted rather than over-interpreted: on accept the
routine writes either `0x2C` or `0x2E` to `[7718]` based on local word
`[bp-0x02]`. In this function body that local word is not visibly initialized
before the comparison.

## Preferences

`DC98:2A83` is the OTHERS -> PREFERENCES screen. It edits two toggle rows and
commits only on `0xDA`.

```asm
preferences_DC98_2A83:
; file 0x5F403
DC98:2A83  55                push bp
DC98:2A84  8B EC             mov  bp,sp
DC98:2A86  83 EC 04          sub  sp,0x04
...
DC98:2A8D  9A 70 0E 98 DC    call DC98:0E70
DC98:2A92  B8 0E 00          mov  ax,0x000e
DC98:2A95  BB 8E EF          mov  bx,0xef8e
DC98:2A98  B9 19 00          mov  cx,0x0019
DC98:2A9B  9A AD 67 00 C0    call C000:67AD       ; title stream
DC98:2AA2  A1 55 6D          mov  ax,[0x6d55]
DC98:2AA5  89 46 FE          mov  [bp-0x02],ax
DC98:2AA8  A0 24 6D          mov  al,[0x6d24]
DC98:2AAD  89 46 FC          mov  [bp-0x04],ax
...
DC98:2B4D  8B 46 FE          mov  ax,[bp-0x02]
DC98:2B50  A3 55 6D          mov  [0x6d55],ax
DC98:2B53  8B 46 FC          mov  ax,[bp-0x04]
DC98:2B56  A2 24 6D          mov  [0x6d24],al
```

State mapping:

| UI row | Options | Backing state |
| --- | --- | --- |
| `GRAMMAR CHECKING` | `ON`, `OFF` | word `[6D55]`; existing startup initializes this to `0`. |
| `STICKY SHIFT KEY` | `ON`, `OFF` | byte `[6D24]`; keyboard code references this byte. |

String/display descriptors and final formatted text:

```text
EF8E:000E display stream, length 0x19
FF 40 01 00 14 00 F8 "EDITOR PREFERENCES"

EDITOR PREFERENCES

EF90:0008 char* option line
GRAMMAR CHECKING     :  { ON }     { OFF }

EF93:0004 char* option line
STICKY SHIFT KEY     :  { ON }     { OFF }
```

## Bottom

These setup roots do not branch into document handlers, the diagnostic monitor,
or the large `EBBB` application segment. Their live descendants are local
display/edit helpers, `DC98:0CF9` for key reads, `DC98:0D19` for nonblocking
status during callback idle, and `C000:077C` for the system buzzer preview.
