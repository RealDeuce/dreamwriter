# Hardware Notes

## Keyboard

Raw keyboard rows are stored in low RAM at `6D06..6D0F`.

Keyboard scan ISR excerpt:

```asm
C000:04DD  mov bl,[6D29]      ; row index
C000:04E3  in al,0B0          ; current row bits
C000:04EE  mov [bx+6D06],al   ; raw row state
```

When a full 10-row scan completes, the ISR calls `C000:5645`, which appears to
be higher-level keyboard processing:

```asm
C000:0529  mov byte [6D29],00
...
C000:053C  call C000:5645
```

The firmware stores level state, not just key edges. Normal key repeat is
handled higher up using state around `6EB0..6EB3`.

MAME models a 10-row, active-high keyboard matrix. The periodic keyboard timer
runs at 250 Hz. It increments `m_matrix`, asserts IRQ bit `0x10` for row scans
(vector `FB`), and after row 9 resets `m_matrix` to zero and asserts IRQ bit
`0x20` (vector `FA`). Reading port `0xB0` returns `ROW[m_matrix - 1]`, or zero
when `m_matrix` is zero.

| Row | Bits |
| ---: | --- |
| 0 | `01` Left Shift, `02` Right Shift, `08` Left, `10` Enter |
| 1 | `01` Alt, `02` backtick, `04` Can, `08` Space, `40` 5 |
| 2 | `01` Control, `02` Caps Lock, `04` 1, `08` Tab |
| 3 | `01` 3, `02` 2, `04` Q, `08` W, `10` E, `40` S, `80` D |
| 4 | `01` 4, `04` Z, `08` X, `10` A, `40` R, `80` F |
| 5 | `04` B, `08` V, `10` T, `20` Y, `40` G, `80` C |
| 6 | `01` 6, `02` Down, `04` Insert, `08` Right, `10` backslash, `20` slash, `40` H, `80` N |
| 7 | `01` equals, `02` 7, `04` Orgn, `08` Up, `10` WP, `20` U, `40` M, `80` K |
| 8 | `01` 8, `02` minus, `04` right bracket, `08` left bracket, `10` quote, `20` I, `40` J, `80` comma |
| 9 | `01` 0, `02` 9, `04` Backspace, `08` P, `10` semicolon, `20` L, `40` O, `80` period |

The calculator app has its own ROM translation table at `C000:5619..5644`.
It maps the physical `M,J,K,L,U,I,O,7,8,9` cluster to digits `0..9`, which
makes a MAME host numeric-keypad overlay plausible. The printed calculator
legends remap the operator keys: physical `0` is divide, `P` is multiply,
`;`/`:` is subtract, `/` is add, `,` is decimal point, `.` is plus/minus, and
`RET` is equals. Candidate extra host keycodes should follow those legends:
keypad `/` on physical `0`, keypad `*` on physical `P`, keypad `-` on physical
`;`, keypad `+` on physical `/`, keypad `.` on physical `,`, and keypad Enter
on physical `RET`. Because the real keyboard has the calculator overlay printed
on these keys, unconditional MAME keypad aliases are acceptable.

## LCD / Framebuffer

MAME models the display as a RAM scanout window selected by I/O port `0x00`.

ROM boot writes:

```asm
C000:0055  mov al,08
C000:0057  out 00,al
```

MAME interprets that as:

```text
lcd_base = value << 9
0x08 << 9 = 0x1000
```

Display geometry in MAME:

```text
480 x 64 pixels
64 bytes per row stride
60 visible bytes per row
4096-byte scanout block
```

MAME renders 60 bytes per row, most-significant bit first, from:

```text
main_ram + (lcd_memory_start << 9) + y * 64 + x
```

Screen buffer routines:

| Address | File offset | Operation |
| --- | ---: | --- |
| `C000:07E9` | `0x407E9` | Calls `C000:4C39`, then copies `0x1000 -> 0x94F0` for `0x800` words. |
| `C000:07F4` | `0x407F4` | Copies `0x94F0 -> 0x1000` for `0x800` words. |
| `C000:4C4F` | `0x44C4F` | Battery-warning area restore, `0x94F0 -> 0x131B`, 40 rows of 6 bytes with `0x3A` stride. |
| `C000:4C6E` | `0x44C6E` | Battery-warning area save, `0x131B -> 0x94F0`, same layout. |

Font table notes are in `fonts.md`. Bitmap and UI resource notes are in
`bitmaps.md`.

Far wrappers exist near `C000:088F` and `C000:0899`:

```asm
C000:0892  call C000:07E9
C000:0898  retf
C000:089C  call C000:07F4
C000:08A2  retf
```

## Ports Seen So Far

| Port | Evidence |
| ---: | --- |
| `0x00` | LCD scanout base select. Boot writes `0x08`. |
| `0x10..0x17` | Bank select registers for eight 128 KiB CPU windows. Bit `0x10` selects RAM; otherwise the low nibble selects a ROM bank through `((v & 0x0F) ^ 0x0F)`. |
| `0x20` | Startup writes `0x00`. |
| `0x30` | Control latch mirrored at `[6D94]`. Diagnostic `T`/`N` toggles bit `0x80`; RS-232 setup writes bit `0x10` plus inverted baud index in bits `0..2`; Centronics output pulses bit `0x20` for `-STB`. |
| `0x40` | Centronics parallel data output latch. Startup/idle writes `0xFF`. |
| `0x50..0x52` | Buzzer/tone counter. Firmware writes a 16-bit divisor to `0x50`/`0x51`, writes `0x7F` to `0x52` to enable, and writes `0xFF` to `0x52` to disable. |
| `0x60` | IRQ enable register in MAME; firmware mirrors the written value at `[6D4F]`. The idle wait at `C000:4A94` writes `[6D4F]` here immediately before `sti; hlt`; Centronics output clears bit `0x40` while ACK-driven output is active and sets it when the buffer empties. |
| `0x61` | Keyboard idle path writes `0xFE`. |
| `0x70` | Warm diagnostic IRQ path writes `0x01` before halting in a loop. |
| `0x90` | IRQ active/source clear register in MAME. Bit `n` clears vector `FF-n`; confirmed uses include bit 7 for vector `F8`, bit 3 for serial receive vector `FC`, bit 1 for Centronics ACK vector `FE`, and bit 0 for vector `FF`. |
| `0xA0` | Shared status input. Printer output tests bit `0x02` as Centronics `BUSY`; battery/card helpers test bits `0x04`, `0x08`, `0x10`, `0x40`, and `0x80`. Current battery-warning mapping is bit `0x08` main battery low, bit `0x04` CR2032 retention battery low, and PCMCIA SRAM-card battery low when bit `0x80` is clear and bit `0x10` is clear. Bit `0x40` is likely SRAM-card write-protect. |
| `0xB0` | Keyboard row input port; returns the row selected by the keyboard timer state. |
| `0xC0` | RS-232 USART data register. Firmware writes transmit bytes here and reads receive bytes here. |
| `0xC1` | RS-232 USART status/control register. Firmware reads status here and writes reset/mode/command bytes here. |
| `0xD0..0xDF` | RTC register block. MAME maps this range to a Ricoh `RP5C01`; firmware reads/writes `0xD0..0xDC` as 4-bit BCD time/date registers and uses `0xDD..0xDF` as control/mode registers. |

## RTC

The Organizer -> WORLD CLOCK -> SET TIME/DATE path does not access RTC ports
directly. It calls DOS-like `INT 21h` services through `DC98` wrappers:

| Service | App wrapper | C000 handler | Meaning |
| ---: | --- | --- | --- |
| `AH=2A` | `DC98:0D2A` | `C000:516F` | Get date. |
| `AH=2B` | `DC98:0D72` | `C000:51C7` | Set date. |
| `AH=2C` | `DC98:0D4E` | `C000:5209` | Get time. |
| `AH=2D` | `DC98:0D8F` | `C000:523D` | Set time. |

`C000:0B60` snapshots RTC ports `0xD0..0xDC` into the BCD shadow buffer
`6D96..6DA2`, masking each read to the low nibble. The public get-date/time
handlers convert those BCD nibbles into DOS-style binary registers:

| RTC port | Shadow | Meaning |
| ---: | ---: | --- |
| `0xD0` | `6D96` | Seconds ones. |
| `0xD1` | `6D97` | Seconds tens. |
| `0xD2` | `6D98` | Minutes ones. |
| `0xD3` | `6D99` | Minutes tens. |
| `0xD4` | `6D9A` | Hours ones. |
| `0xD5` | `6D9B` | Hours tens. |
| `0xD6` | `6D9C` | RTC weekday/status register candidate. Left unchanged by the binary date conversion, then still written by the date write helper; not used for `AH=2A`'s weekday return. |
| `0xD7` | `6D9D` | Day ones. |
| `0xD8` | `6D9E` | Day tens. |
| `0xD9` | `6D9F` | Month ones. |
| `0xDA` | `6DA0` | Month tens. |
| `0xDB` | `6DA1` | Year ones. |
| `0xDC` | `6DA2` | Year tens. |

The year conversion treats RTC years `80..99` as `1980..1999` and `00..79` as
`2000..2079`:

```asm
C000:5182  mov dh,[6DA2]   ; year tens
C000:5185  cmp dh,08
C000:5188  mov cx,076C     ; 1900
C000:518B  jae C000:5190
C000:518D  mov cx,07D0     ; 2000 when tens < 8
```

`AH=2A` returns the weekday in `AL`, but that value is computed in firmware by
`C000:5308` from the decoded year/month/day. The RTC's own `0xD6` shadow byte is
not used for this return path.

Set-time and set-date convert binary values back to BCD shadow bytes, then write
the RTC:

```asm
C000:09AE  ; write time shadow 6D96..6D9B to ports D0..D5
C000:09C9  ; write date shadow 6D9C..6DA2 to ports D6..DC
```

Before writes, `C000:09EC` emits a small control sequence through `0xDD`,
`0xDF`, `0xDE`, and `0xDA`; afterwards the write helpers restore `0xDD` to
`0xF8`. The exact RP5C01 mode/control interpretation should be checked against
the physical board or a chip datasheet before naming those bits as more than
firmware-observed control writes.

## RS-232C USART

The WP -> COMMUNICATE -> SET UP screen at `DC98:22A1` is the `RS-232C SET UP`
menu. It edits five bytes:

| Address | Menu field | Values |
| ---: | --- | --- |
| `6D2A` | Baud rate | `3..7` for `1200`, `2400`, `4800`, `9600`, `19200`. |
| `6D2B` | Bit length | `0` = 7 bits, `1` = 8 bits. |
| `6D2C` | Stop bits | `0` = 1 stop bit, `1` = 2 stop bits. |
| `6D2D` | Parity | `0` = none, `1` = odd, `2` = even. |
| `6D2E` | XON/XOFF | `0` = disabled, `1` = enabled. |

`C000:0CBC` is the serial initialization wrapper. It validates those settings
through `C000:48D5`, builds a mode byte at `C000:0BFC`, then programs the
hardware through `C000:0C58`.

The programming sequence strongly resembles an Intel 8251/8251A-style USART, not
an 8250-compatible UART. `C000:0C43` writes the classic 8251 sync-reset/mode/
command sequence to control port `0xC1`:

```asm
C000:0C43  mov dx,00C1
C000:0C46  xor al,al
C000:0C49  out dx,al       ; 00
C000:0C4A  out dx,al       ; 00
C000:0C4B  out dx,al       ; 00
C000:0C4C  mov al,40
C000:0C4E  out dx,al       ; internal reset
C000:0C4F  mov ax,[6EAC]
C000:0C52  out dx,al       ; async mode byte
C000:0C53  mov al,37
C000:0C55  out dx,al       ; command: TxEN, DTR, RxEN, error reset, RTS
```

For the normal user-configured setup path, the mode-byte construction also
matches an 8251 async mode word:

```asm
C000:0BFC  mov al,4A       ; 7 data bits, no parity, 1 stop bit, 16x clock
C000:0C0E  or  al,0C       ; 8 data bits
C000:0C17  or  al,C0       ; 2 stop bits
C000:0C20  or  al,10       ; parity enable
C000:0C29  or  al,20       ; even parity
```

`C000:0BFC` has one special case before that normal path: when `[8294] bit 0` is
set, it starts from mode byte `0x4E` and skips the user bit-length, stop-bit, and
parity modifications. The exact mode that sets `[8294]` still needs naming.

Baud selection is not done with 8250 divisor latches. `C000:0C58` writes the
inverted baud index into bits `0..2` of port `0x30`, while preserving the rest of
the `[6D94]` latch:

```asm
C000:0C64  mov al,[6D94]
C000:0C67  or  al,10
C000:0C69  and al,F8
C000:0C6B  mov ah,[6D2A]
C000:0C6F  not ah
C000:0C71  and ah,07
C000:0C74  or  al,ah
C000:0C76  out 30,al
```

The highest menu setting, `19200`, is still plausible with this model. The mode
word uses the 8251-style 16x async clock factor, so `19200` requires a
`307.2 kHz` TxC/RxC clock. The firmware does not synthesize that inside the
USART; it selects an external baud-clock divider through port `0x30`.

Transmit waits on `0xC1` status bit `0` and requires bit `7`, then writes the
byte to `0xC0`:

```asm
C000:0D4F  mov dx,00C1
C000:0D53  in  al,dx
C000:0D55  test al,01      ; transmit ready
...
C000:0D46  in  al,dx
C000:0D4A  test al,80      ; modem/status gate
...
C000:0D9C  mov dx,00C0
C000:0D9F  out dx,al       ; transmit data
```

On an 8251-style USART, command byte `0x37` asserts both RTS and DTR while
enabling transmit/receive and resetting errors. The hardware/manual evidence
indicates DTR duplicates RTS and there is no CD/carrier-detect signal. The
firmware's transmit-ready check should still be treated as CTS-influenced until
the exact chip and glue logic are confirmed.

Receive is interrupt-driven through IRQ vector `FC` at `C000:0550`, which clears
IRQ bit `0x08`, reads `0xC1`, records framing/parity/overrun-like bits
`0x08/0x10/0x20` in `[6D57]`, acknowledges with command `0x37`, then reads the
received byte from `0xC0` and queues it through `C000:4BED`. XON/XOFF handling
uses `0x13`/`0x11` when `6D2E` is enabled.

`C000:41A8`, the DreamLink endpoint probe, temporarily forces `9600 8N1` with
XON/XOFF disabled (`6D2A=6`, `6D2B=1`, `6D2C=0`, `6D2D=0`, `6D2E=0`) while
probing the peer, then restores the user's settings.

## Centronics Parallel Port

The WP -> PRINTER menu at `DC98:265D` has `PRINT OUT`, `SET UP 1`, and
`SET UP 2`. `SET UP 2` reuses the RS-232 setup screen above. `SET UP 1` at
`DC98:24DB` edits three printer fields:

| Address | Menu field | Values |
| ---: | --- | --- |
| `6D59` | Printer model | Seven models from the setup string table. |
| `6D5A` | Interface | `0` = parallel, `1` = serial. |
| `6D5B` | Paper feed | `0` = automatic, `1` = manual. |

The setup strings start around `0x6FC3D` and include `PRINTER SET UP`,
`PRINTER`, `INTERFACE : {PARALLEL} {SERIAL}`, and
`PAPER FEED: {AUTOMATIC} {MANUAL}`.

The low-level parallel path matches a simple output-only Centronics interface.
The manual only names `-STB`, `BUSY`, and `-ACK`, and the firmware has not shown
any readback path from the printer data latch.

`C000:0920` writes one byte to the data latch, polls status bit `0x02`, then
pulses bit `0x20` of the `0x30` control latch:

```asm
C000:0920  mov al,dl
C000:0922  out 40,al       ; data byte
C000:092A  in  al,A0
C000:092C  test al,02      ; BUSY
C000:092E  jnz C000:0942
C000:0930  mov al,[6D94]
C000:0933  or  al,20
C000:0935  out 30,al       ; assert -STB through glue/inversion
...
C000:093B  and al,DF
C000:093D  out 30,al       ; release -STB
```

`C000:0738`, IRQ vector `FE`, is the ACK-driven output feeder. It clears IRQ
source bit `0x02` through port `0x90`, reads the next byte through pointer
`[6D92]`, outputs it on `0x40`, and pulses the same strobe bit. A `0x00`
terminator disables the ACK path by setting bit `0x40` in the port `0x60` mirror
`[6D4F]`.

The direct starter at `C000:08EC` also reads through `[6D92]`; it clears
`[6D4F]` bit `0x40`, writes port `0x60`, marks `[6DA4]=1`, and sends the first
byte through `C000:0920`.

Likely signal map so far:

| Signal | Firmware evidence |
| --- | --- |
| Data `D0..D7` | Output byte on port `0x40`. |
| `-STB` | Port `0x30` bit `0x20`, pulsed high then low by firmware. External glue may invert the physical line. |
| `BUSY` | Port `0xA0` bit `0x02`; when set, `C000:0920` waits/retries via `C000:49F8`. |
| `-ACK` | IRQ vector `FE`; handler clears port `0x90` bit `0x02` and feeds the next byte. |

Port `0xA0` may also carry additional Centronics status lines such as paper
empty, select, or error, but the confirmed non-printer consumers are the
battery/card warning helpers. The exact bit ownership needs board-level
confirmation.

## Battery And Card Status Inputs

The three documented 48x40 battery warning icons at `C000:4D30`, `C000:4E20`,
and `C000:4F10` are selected by the low-level warning path around `C000:4C91`.
Each icon is `0xF0` bytes: 40 rows by 6 bytes per row.

`C000:4D07` draws icon index `AL` into the top-left warning area at `0x131B`.
`C000:4C6E` first saves that screen area to scratch buffer `0x94F0`, then
`C000:4C39`/`C000:4C4F` restore it after the warning clears or the event loop
resumes normal drawing.

```asm
C000:4CE6  call C000:4C6E  ; save 48x40 screen area
C000:4CEB  mov  al,[6D52]
C000:4CEE  sub  al,02      ; warning slot 2..4 -> icon index 0..2
C000:4CF0  call C000:4D07  ; draw selected battery icon
C000:4CF3  or   byte [6D52],80
```

`C000:4C91` is called from the low-level wait/event path at `C000:4AD1`. It
rotates through warning states in `[6D52]` so all active warnings can be shown
without permanently replacing the underlying screen content:

| Warning slot | Helper | Icon index | Meaning | Port `0xA0` test |
| ---: | --- | ---: | --- | --- |
| `2` | `C000:0A93` | `0` | Main battery low. | Bit `0x08` set on two reads. |
| `3` | `C000:0AA4` | `1` | CR2032 memory-retention battery low. | Bit `0x04` set on two reads. |
| `4` | `C000:0AB2` | `2` | PCMCIA SRAM-card battery low. | Bit `0x80` clear and bit `0x10` clear on two reads. |

`C000:0A6A` is the combined battery-status service. It returns `AL=1`, `2`, or
`3` for the same priority order, or zero when no warning is active. The dispatch
stub at `C000:192E` exposes the combined query and the three individual helpers
through `DL=0..3`.

The SRAM-card warning is gated by bit `0x80`: when bit `0x80` is set, the
combined query suppresses the bit `0x10` card-battery test, and `C000:0AC4`
reports a card-access failure. Current best read is therefore:

| Port `0xA0` bit | Current interpretation |
| ---: | --- |
| `0x02` | Centronics `BUSY`, active high. |
| `0x04` | CR2032 memory-retention battery low, active high. |
| `0x08` | Main battery low, active high. |
| `0x10` | PCMCIA SRAM-card battery status, active-low low-battery indication when a card is present. |
| `0x40` | Likely SRAM-card write-protect; `C000:0ACE` sets carry when this bit is set and card write paths report error `0x0B`. |
| `0x80` | PCMCIA card absent/not-ready gate; `C000:0AC4` sets carry when this bit is set. |

The local MAME snapshot currently returns fixed `0xF7` for port `0xA0` while
only documenting bit 3 as main battery low. That does not fully match this
firmware path: bit `0x04` set would be interpreted as the CR2032 retention
battery warning, while bit `0x08` clear keeps the main battery warning off.

## Buzzer / Tone Counter

The WP -> OTHERS -> SYSTEM screen has a `POWER ON BUZZER` setting with
`TYPE 1`, `TYPE 2`, `TYPE 3`, and `NO`. In that menu, pressing Space previews
the selected type:

```asm
DC98:2966  cmp di,0020          ; Space
DC98:296B  cmp word [bp-4],0003 ; 3 == NO
DC98:2971  mov ax,[bp-4]        ; 0..2 == TYPE 1..3
DC98:2974  call C000:077C       ; preview sound
```

`C000:077C` is a far wrapper around `C000:0B16`, the table-driven sound player.
The sound tables start at `C000:0ADA` / file `0x40ADA`. Each entry is a sequence
of:

```text
duration-byte, divisor-word-le
...
00 terminator
```

For each note, `C000:096A` either programs the tone or turns it off for a rest:

```asm
C000:099C  mov al,bl
C000:099E  out 50,al       ; divisor low
C000:09A0  mov al,bh
C000:09A2  out 51,al       ; divisor high
C000:09A4  mov al,7F
C000:09A6  out 52,al       ; enable

C000:09A9  mov al,FF
C000:09AB  out 52,al       ; disable
```

That is a hardware tone/counter interface, not a simple CPU-toggled one-bit
speaker loop. The exact input clock and output waveform still need hardware or
MAME confirmation.

Current MAME status: `mame/nakajies.cpp` creates a `SPEAKER_SOUND` device and
has comments listing the same `0x50..0x52` writes, but `nakajies_io_map` does
not currently map those ports. Sound support should therefore be implementable
once the board identifies whether these ports feed a simple divider, a gate
around a fixed oscillator, or a small tone-generator IC.

Confirmed preview sequences:

| UI option | Value | Sequence |
| --- | ---: | --- |
| `TYPE 1` | `0` | `(duration 8, divisor 0x015D)`, `(duration 2, rest)`, `(duration 4, divisor 0x0100)`. |
| `TYPE 2` | `1` | `(duration 4, divisor 0x02BA)`. |
| `TYPE 3` | `2` | `(duration 5, divisor 0x0126)`, `0x0106`, `0x00E9`, `0x00DC`, `0x00C4`. |
| `NO` | `3` | No preview; the menu skips `C000:077C`. |

Lower divisors should produce higher tones if the counter is a normal divider.
That matches the UI comments in `mame/nakajies.cpp`: type 2 is the simple lower
sound, while type 3 is the highest-frequency sound.

## Auto Power-Off

The WP -> OTHERS -> SYSTEM screen also has an `AUTO POWER OFF PERIOD` setting
with choices `2`, `3`, `5`, `10`, `15`, `20`, and `UNLIMITED` minutes. The UI
stores the selected index in `[6D2F]`, then maps it through a word table at
`EF79:0002` / file `0x6F792` and stores the active reload value in `[6D31]`.

| UI choice | `[6D2F]` | `[6D31]` reload |
| --- | ---: | ---: |
| `2` minutes | `0` | `0x04B0` / `1200` |
| `3` minutes | `1` | `0x0708` / `1800` |
| `5` minutes | `2` | `0x0BB8` / `3000` |
| `10` minutes | `3` | `0x1770` / `6000` |
| `15` minutes | `4` | `0x2328` / `9000` |
| `20` minutes | `5` | `0x2EE0` / `12000` |
| `UNLIMITED` | `6` | `0x0000` |

The values match a 10 Hz idle countdown. The active countdown lives in
`[680B]`; idle paths reload it from `[6D31]` and decrement it while checking
for keyboard/activity and battery-warning work. The decrement is foreground
idle-loop code after `sti; hlt` returns, not code inside an interrupt handler;
the interrupt source that wakes `hlt` still needs hardware confirmation. When
`[680B]` reaches zero and `[6D31] != 0`, the firmware enters a retained
power-transition path:

```asm
C000:49C2  dec word [680B]
C000:49C8  cmp word [6D31],00
C000:49CD  jz  C000:49D6
C000:49CF  cli
C000:49D0  call C000:4A34   ; save resume target [6D79] = 4977
C000:49D3  jmp  C000:035D   ; checksum retained state, power transition, loop
```

A similar idle loop at `C000:4A8D` saves resume target `4A8D` through
`C000:4A43`, clears any battery-warning overlay through `C000:4C39`, and jumps
to the same `C000:035D` transition. This timeout route terminates through the
IRQ `FF`-style `out 0x70,0x01; jmp $` sequence, rather than the IRQ `F8`
handler's `out 0xDD,0xF8; jmp $` sequence.

Keyboard activity resets the timer in this idle path. `C000:4B2D` checks the
keyboard/event ring buffer using read/write offsets at `[70E2]` and `[70E3]`;
if a key/event is available, the caller branches through `C000:4AF2`, reloads
`[680B]` from `[6D31]`, clears any active battery-warning overlay, and then
translates the key through `C000:5915`:

```asm
C000:4AB3  call C000:4A84   ; sti; hlt
C000:4AB6  call C000:4B2D   ; poll/dequeue keyboard event
C000:4AB9  test byte [70A5],01
C000:4ABE  jz   C000:4AF2  ; key/event present
...
C000:4AF6  mov  ax,[6D31]
C000:4AF9  mov  [680B],ax
C000:4AFC  call C000:4C39  ; clear warning overlay
C000:4B0F  call C000:5915  ; translate key/event
```

Two short IRQ handlers are plausible simple `hlt` wake sources:

```asm
C000:049A  ; IRQ F9
  out 90,40
  and byte [6DA9],FE
  sti
  iret

C000:0724  ; IRQ FD
  out 90,04
  and byte [70A5],F7
  sti
  iret
```

`F9` is especially interesting because the idle loops test `[6DA9]` bit `0x01`
near the auto-off decrement sites. The actual periodic source and frequency
still need hardware confirmation. As an emulator working hypothesis, driving
IRQ `F9` at 10 Hz should wake `hlt` often enough for the auto-off countdown and
time-display refresh paths without pretending that keypresses are occurring.

This matches an observed MAME behavior change: before adding a 10 Hz IRQ `F9`
source, the Organizer WORLD CLOCK seconds display advanced only when keypresses
woke the CPU. With the 10 Hz source present, seconds advance normally, and the
selected home-city field blinks at a sub-second UI rate, likely divided down
from the same periodic wake source. The exact blink divisor has not been traced.

## Power / Wake Hypothesis

MAME does not model a named power key or switch. It exposes a synthetic debug
input port where host `F8` asserts IRQ vector `F8` and host `F1` asserts IRQ
vector `FF`.

The firmware handlers make those two vectors look like opposite sides of the
power path:

```asm
C000:03AE  ; IRQ F8
  out 90,80          ; clear IRQ F8 source
  save DS/BX/CX/DX/SI/DI/ES/SS/IP/CS/flags/SP under 6D65..6D87
  call C000:0438     ; checksum saved context into [6D83]
  call C000:047D
  out DD,F8
  jmp $              ; wait for hardware power transition

C000:02EE  ; IRQ FF
  out 90,01          ; clear IRQ FF source
  inspect [6809] and saved/warm state
  optional warm/diagnostic setup
  out 70,01
  jmp $              ; wait for hardware reset/wake transition
```

That fits a physical power control better than a normal scanned keyboard key.
A latching switch could plausibly present one edge/state as the suspend/save
interrupt and another as the wake/reset interrupt, with external hardware doing
the actual power or reset transition while the CPU spins in those terminal
loops. The exact electrical behavior is still unconfirmed.

## Low RAM State

| Address | Meaning seen so far |
| ---: | --- |
| `6807` | Cleared on diagnostic chord in warm IRQ path. |
| `6809` | Startup/warm state marker. Values include `0001`, `1992`, `1995`, `1999`. |
| `680B` | Active auto power-off countdown. Reloaded from `[6D31]` and decremented in idle paths. |
| `6D06..6D0F` | Raw keyboard matrix rows. |
| `6D28` | Keyboard scan state/idle counter. |
| `6D29` | Keyboard scan row index. |
| `6D2A..6D2E` | RS-232C setup bytes: baud index, bit length, stop bits, parity, XON/XOFF. |
| `6D2F` | Auto power-off period index from WP -> OTHERS -> SYSTEM: `0..6` = `2`, `3`, `5`, `10`, `15`, `20`, `UNLIMITED`. |
| `6D30` | Power-on buzzer setting: `0..2` = types 1..3, `3` = no buzzer. |
| `6D31` | Auto power-off countdown reload value, selected from `[6D2F]`; `0` disables timeout. |
| `6D4F` | Port `0x60` state mirror. |
| `6D51` | Flags; diagnostic paths clear bit `0x08`. |
| `6D52` | Battery-warning display state. Values `2..4` select main, CR2032, or PCMCIA SRAM-card battery warning checks; bit `0x80` marks that an icon is currently displayed. |
| `6D57` | RS-232 receive/error flags; IRQ `FC` ORs in bits `0x08`, `0x10`, and `0x20` from status port `0xC1`. |
| `6D59..6D5B` | Printer setup bytes: printer model, interface, paper feed. |
| `6D65..6D87` | Saved resume context/checksum area used by suspend/warm paths. |
| `6D79` | Saved resume IP. Diagnostic warm entry stores `4A8D`. |
| `6D7B` | Saved resume CS. |
| `6D7D` | Saved resume SP. |
| `6D81` | Diagnostic/warm marker; `1995` requests diagnostic/warm handling. |
| `6D96..6DA2` | RTC BCD shadow read from ports `0xD0..0xDC`: seconds, minutes, hours, candidate weekday/status, day, month, and year nibbles. |
| `72D7..72E3` | Date/time wrapper cache used by WORLD CLOCK and SET TIME/DATE: year, month, day, weekday, hour, minute, second. |
| `6D83` | Checksum over saved context. |
| `6D92` | Centronics output pointer used by `C000:0738` and `C000:08EC`. |
| `6D94` | Port `0x30` value mirror. |
| `6DA4` | Centronics ACK-feed active flag; IRQ `FE` only emits bytes when this is `1`. |
