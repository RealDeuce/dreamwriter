# Hardware Notes

## Keyboard

Raw keyboard rows are stored in low RAM at `6D06..6D0F`.

Port `0x61` appears to control or reset the external keyboard row-scan sequencer.
Only three direct writes have been found, all in keyboard scan code:

```asm
C000:050F  mov  al,0FE
C000:0511  out  61,al       ; stop/idle row scan after repeated empty scans

C000:107B  mov  al,0FE
C000:107D  out  61,al
C000:107F  mov  al,0FF
C000:1081  out  61,al       ; pulse before starting/resetting row scan
```

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

The scan flow now looks like this:

| Step | Firmware behavior |
| --- | --- |
| Scan-cycle IRQ `FA` | `C000:04AE` sets port `0x60` bit `0x04`, then calls `C000:106F`. |
| Start/reset row scan | `C000:106F` clears port `0x60` bit `0x08`, writes the IRQ/source mask, dummy-reads `0xB0`, pulses port `0x61` from `0xFE` to `0xFF`, and clears row index `[6D29]`. |
| Row IRQ `FB` | `C000:04D1` reads port `0xB0` into `6D06..6D0F`, using `[6D29]` as the row index. |
| Empty-idle fallback | After ten full scans with no active row, the ISR writes `0xFE` to port `0x61`, clears port `0x60` bit `0x04`, sets bit `0x08`, and returns to the scan-cycle source. |

MAME models a 10-row, active-high keyboard matrix. The periodic keyboard timer
currently runs at `X301 / 20480`, or about `960 Hz` from the known 19.66 MHz
crystal.
It increments `m_matrix`, asserts IRQ bit `0x10` for row scans (vector `FB`),
and after row 9 resets `m_matrix` to zero and asserts IRQ bit `0x20` (vector
`FA`). Reading port `0xB0` returns `ROW[m_matrix - 1]`, or zero when
`m_matrix` is zero.

The keyboard scan source appears separate from the `F9` idle/wake timer latch
at port `0x53`, but MAME currently models both as derived from the same
`X301 / 20480` clock. The rate is inferred from the firmware repeat counters
and tied to a plausible CPU/crystal divider rather than the RTC. A full keyboard
scan consumes ten row IRQs plus the scan-cycle/reset IRQ, so about `960 Hz`
produces roughly 87 full scans/second. The repeat path seeds `[6EB3]` with
`0x41` on a new keypress and reloads it with `0x08` after each repeat, giving
about a 0.75 second initial delay and about 11 repeats/second. The previous
250 Hz row timer
stretched the initial repeat delay to almost three seconds, which made held keys
in the WP editor appear not to repeat.

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

Font table notes are in [`fonts.md`](fonts.md). Bitmap and UI resource notes
are in [`bitmaps.md`](bitmaps.md).

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
| `0x10..0x17` | Bank select registers for eight 128 KiB CPU windows. Values `0x00..0x07` select ROM banks, and values with bit `0x10` set select RAM. The current MAME patch also enables bit `0x08` as RAM for specific DreamWriter configs that need it for their startup/internal-store windows; for that bit-3-only case the RAM page follows the CPU window. |
| `0x20` | CSiMON monitor-entry/status handshake candidate. Normal DreamWriter startup writes `0x00` at `C000:005B`; the high-ROM CSiMON entry stub at `FFDF:0005` writes `0x20` after it is already running. No reads or other confirmed values have been found. |
| `0x30` | Control latch mirrored at `[6D94]`. Bits `0..2` select the RS-232 baud-clock divider, bit `0x08` is pulsed during USART setup, bit `0x10` is a persistent RS-232 enable/setup bit, bit `0x20` is pulsed for Centronics `-STB`, and diagnostic `T`/`N` temporarily writes bit `0x80`. No confirmed firmware read has been found. |
| `0x40` | Centronics parallel data output latch. Startup/idle writes `0xFF`. |
| `0x50..0x52` | Buzzer/tone counter. Firmware writes a 16-bit divisor to `0x50`/`0x51`, writes `0x7F` to `0x52` to enable, and writes `0xFF` to `0x52` to disable. |
| `0x53` | Timer latch for IRQ `F9`. Firmware writes small counts through `C000:0B3C`; observed values are `0x0A`, `0x56`, and `0x60`. Current MAME models this as a one-shot driven by `X301 / 20480`, so `0x60` expires at almost exactly 10 Hz. The latch value currently looks like a count only, not an interrupt-vector selector. |
| `0x60` | IRQ/source control register in MAME; firmware mirrors the written value at `[6D4F]`. The idle wait at `C000:4A94` writes `[6D4F]` here immediately before `sti; hlt`; Centronics output clears bit `0x40` while ACK-driven output is active and sets it when the buffer empties. The `F9` timer arm helper clears bit `0x02` here, while its disarm helper sets bit `0x02`, so this port is probably more than a plain IRQ mask. |
| `0x61` | Keyboard row-scan sequencer control candidate. `C000:106F` pulses `0xFE -> 0xFF` when starting/resetting row scanning; the row-scan ISR writes `0xFE` after repeated empty scans while switching back to the scan-cycle source. |
| `0x70` | Terminal power/reset transition control candidate. The ROM only writes `0x01`, at `C000:0372`, then spins forever. Warm diagnostic, auto-off, and RTC alarm re-arm paths all converge here after saving/checksumming retained state and preparing RTC alarm state. |
| `0x90` | IRQ active/source clear register in MAME. Bit `n` clears vector `FF-n`; confirmed uses include bit 7 for vector `F8`, bit 5 for keyboard scan-cycle/reset vector `FA`, bit 4 for keyboard row-scan vector `FB`, bit 3 for serial receive vector `FC`, bit 1 for Centronics ACK vector `FE`, and bit 0 for vector `FF`. |
| `0xA0` | Shared status input. Printer output tests bit `0x02` as Centronics `BUSY`; battery/card helpers test bits `0x04`, `0x08`, `0x10`, `0x40`, and `0x80`. Current battery-warning mapping is bit `0x08` main battery low, bit `0x04` CR2032 retention battery low, and PCMCIA SRAM-card battery low when bit `0x80` is clear and bit `0x10` is clear. Bit `0x40` is likely SRAM-card write-protect. No confirmed firmware consumer has been found for bits `0x01` or `0x20`. |
| `0xB0` | Keyboard row input port; returns the row selected by the keyboard timer state. |
| `0xC0` | RS-232 USART data register. Firmware writes transmit bytes here and reads receive bytes here. |
| `0xC1` | RS-232 USART status/control register. Firmware reads status here and writes reset/mode/command bytes here. |
| `0xD0..0xDF` | RTC register block. MAME maps this range to a Ricoh `RP5C01`; firmware reads/writes `0xD0..0xDC` as 4-bit BCD time/date registers and uses `0xDD..0xDF` as control/mode registers. |
| `0xE0..0xE1`, `0xEC..0xEF` | Fixed I/O touched only by small C688 wrappers found so far. `C688:01D0` writes `0x0A` to `0xE0` and `0x05` to `0xE1`; `C688:01DB` reads `0xEF`, `0xEE`, `0xED`, and `0xEC` in sequence and returns. These are adjacent to diagnostic/card wrapper code, so they are PCMCIA/card-control or external-connector candidates, but no caller or bit meaning is confirmed yet. |

Broad opcode sweeps for `in`/`out` produce many false positives because large
parts of the ROM are tables, text, fonts, and display resources. In the
reachable early `C000` service area and the high-ROM CSiMON entry stub, the
fixed hardware ports above account for the confirmed direct I/O. The two
important generic exceptions are deliberate monitor/diagnostic paths rather than
new fixed devices: the built-in diagnostic `I`/`L` commands read arbitrary ports
through `in al,dx`, and the embedded CSiMON monitor includes generic I/O command
families.

## Port `0x60` IRQ/Source Mask

Port `0x60` appears to be an active-low IRQ/source mask latch mirrored at
`[6D4F]`. Firmware never reads port `0x60` directly; it updates `[6D4F]`, writes
the mirror to the port, and uses port `0x90` separately to clear active IRQ
sources.

The bit order is likely opposite the port `0x90` clear register:

| Port `0x60` bit | Likely vector/source | Evidence |
| ---: | --- | --- |
| `0x01` | IRQ `F8` / power-management source | `C000:106A` clears it during keyboard/source reset setup; diagnostic error path writes raw `0x7E`, leaving this bit clear. `C000:0534` temporarily ORs bit `0x01` into the value written during high-level keyboard processing, without updating `[6D4F]`. |
| `0x02` | IRQ `F9` / `0x53` timer | `C000:0B3C` clears it before writing the timer count to port `0x53`; `C000:0B50` sets it when disarming. |
| `0x04` | IRQ `FA` / keyboard scan-cycle source | IRQ `FA` handler `C000:04AE` sets it, then calls the keyboard scan reset helper. The row-scan ISR clears it after repeated empty scans. |
| `0x08` | IRQ `FB` / keyboard row-scan source | `C000:106F` clears it when starting/resetting row scanning. The row-scan ISR sets it after repeated empty scans, apparently switching back to the scan-cycle source. |
| `0x10` | IRQ `FC` / USART receive-related source | Serial initialization at `C000:0C58` clears bits `0x10` and `0x20`; serial shutdown/idle helper `C000:0D25` sets them. |
| `0x20` | IRQ `FD` / USART transmit-ready-related source | Same serial initialization/shutdown evidence as bit `0x10`; IRQ `FD` is the short transmit-ready acknowledge handler at `C000:0724`. |
| `0x40` | IRQ `FE` / Centronics ACK source | Centronics output starter clears this bit before ACK-driven output; IRQ `FE` handler sets it when the byte stream ends. |
| `0x80` | IRQ `FF` / power or warm diagnostic source | `C000:106A` clears it during source reset setup; diagnostic error path writes raw `0x7E`, leaving it clear. Exact hardware source still needs confirmation. |

This active-low, ascending-vector interpretation explains why the old MAME
commented mask did not work: MAME stores active IRQ bits in port `0x90` order,
where bit `0x01` is vector `FF` and bit `0x80` is vector `F8`. Port `0x60`
appears to use bit `0x01` for vector `F8` and bit `0x80` for vector `FF`, so
the mask must be bit-reversed before applying it to MAME's current `m_irq_active`
representation.

## Port `0x30` Control Latch

Port `0x30` appears to be a write-only control latch with its persistent value
mirrored at `[6D94]`. No confirmed firmware read of port `0x30` has been found;
the direct `in 0x30` byte patterns inspected so far fall in text/data regions.
Firmware updates the mirror for persistent RS-232 baud state, but some callers
write temporary pulse values derived from the mirror without storing them back.

| Port `0x30` bit | Likely role | Evidence |
| ---: | --- | --- |
| `0x01..0x04` | RS-232 baud-clock divider select | `C000:0C58` writes `([6D2A] ^ 0xFF) & 0x07` into bits `0..2` while setting bit `0x10`, then stores the result in `[6D94]`. The high-ROM CSiMON entry stub writes `0x11`, matching the documented 9600 8N1 monitor setup under the current baud-divider model. |
| `0x08` | USART/baud-clock setup strobe candidate | `C000:0C30` writes `[6D94] | 0x08`, delays for four `nop`s, then writes the same value with bit `0x08` clear. `C000:0C58` calls this immediately after programming the baud bits, before the 8251-style command sequence. The CSiMON entry stub performs the same high-then-low pulse. |
| `0x10` | RS-232 enable/setup state | `C000:0C58` sets this bit while programming serial and stores it in `[6D94]`. `C000:0BDF` clears it when `[6DA5]` counts down to zero, then writes the mirror back to port `0x30`. |
| `0x20` | Centronics `-STB` pulse | `C000:0920` and IRQ `FE` at `C000:0738` write `[6D94] | 0x20`, delay for four `nop`s, then write the value with bit `0x20` clear after outputting a byte on port `0x40`. |
| `0x40` | No confirmed firmware use | Searches have not found a confirmed code path that sets or clears this bit. |
| `0x80` | Diagnostic external-control bit candidate | The diagnostic `T`/`N` commands at `C000:131C..1328` write either `[6D94] & 0x7F` or `[6D94] | 0x80` to port `0x30`, without updating `[6D94]`. The command text labels this area as `Card Attribute` / `COM`, so the physical target is still uncertain. |

## Port `0x70` Power Transition Strobe

Port `0x70` has only one confirmed access in the ROM:

```asm
C000:0370  mov  al,01
C000:0372  out  70,al
C000:0374  jmp  C000:0374
```

No reads or alternate written values have been found. That makes it look less
like a multi-bit control register and more like a terminal strobe/latch for
external power/reset hardware. Several routes converge on this same write:

| Route | Path into `out 0x70,0x01` |
| --- | --- |
| Warm/diagnostic IRQ `FF` branch | `C000:02EE` sets warm/diagnostic retained state, disarms the `F9` timer through `C000:0B50`, then jumps to `C000:0370`. |
| Auto-off / foreground retained transition | Idle loops save a resume target through `C000:4A25`, `4A34`, or `4A43`, then jump to `C000:035D`. |
| RTC alarm fallback re-arm | `C000:0784` can program the current-minute+1 fallback alarm and jump to `C000:0370`. |

The fuller retained transition at `C000:035D` runs preparation before the port
write:

```asm
C000:035D  call C000:0438     ; checksum saved CPU/resume state into [6D83]
C000:0360  cmp  byte [7036],00
C000:0367  call C000:044B     ; if [7036] set, checksum 1800:0008..7FFF
C000:036A  call C000:047D     ; disarm timer, reload auto-off counter, serial cleanup
C000:036D  call C000:0376     ; select/program next RTC alarm
C000:0370  out  70,01
```

`[7036]` is cleared during startup and set by filesystem/storage write-like
paths, including format/open-write/write/delete-ish handlers. When it is set,
`C000:044B` computes a checksum over the built-in store window at `1800:0008`
through `1800:7FFF` and stores the result at `1800:0006` before power
transition.

The most likely hardware role is therefore "commit retained power transition"
or "request external reset/wake sequencing", not a normal interrupt source. The
ROM reaches this write in terminal loops, sometimes after `cli`, so the real
machine likely relies on external power/reset glue, the power switch, or the RTC
alarm output to bring the CPU back through reset/warm startup.

## Port `0x20` CSiMON Handshake Candidate

Port `0x20` has only direct writes in early-startup style code. Normal
DreamWriter startup clears it:

```asm
C000:0055  mov  al,08
C000:0057  out  00,al       ; LCD scanout base
C000:0059  mov  al,00
C000:005B  out  20,al
```

A separate high-ROM CSiMON entry stub at physical `0xFFDF5` / file `0x7FDF5`
writes bit `0x20` instead:

```asm
FFDF:0005  cli
...
FFDF:0041  mov  al,20
FFDF:0043  out  20,al
FFDF:0045  mov  al,08
FFDF:0047  out  00,al
```

That high-ROM block mirrors the reset/startup bank setup, programs the buzzer,
toggles port `0x30`, initializes the USART at `0xC0/0xC1`, waits for serial
input, transmits `0x78` repeatedly, and then enters a small `CS:`-relative
dispatch/decode loop. With the initial bytes at `FFDF:0000`, that dispatcher
selects the table entry at `FFDF:0114`, which is a far jump to `FC0A:07FA`
(physical `0xFC89A` / file `0x7C89A`).

The target region is not anonymous DreamWriter application code. It contains
strings identifying `CSiMON-88 - Rommed V4.02 (No other software)` and a
`Copyright (C) 1990-1994 Concurrent Sciences Inc.` notice near physical
`0xFC0A3`. That makes the high-ROM path look more like an embedded CSiMON
monitor, manufacturing diagnostic, or fixture-selected loader/debug path than a
normal user-visible boot feature. No ROM branch from normal startup to
`FFDF:0005` has been found.

The local [`csimon.pdf`](reference/csimon.pdf) manual is for CSi-Mon v5.0 from
1998, not the v4.02 `CSiMON-88` image embedded here, so it should be treated as
a nearby-family reference rather than exact source. It still lines up closely:
the manual describes CSi-Mon as a Soft-Scope target monitor for embedded
systems, says ROM/RAM needs are roughly 20K ROM and 8K RAM, lists NEC `V20`
processor support, lists Intel `8251` UART support, and describes both serial
and ROM-socket/PromICE communication paths.

The ROM command dispatcher at `FC0A:086A` / physical `0xFC90A` accepts the same
broad command families described in the v5 manual's command tables:
execution/breakpoint commands such as `B`, `D`, `S`, `w`, and `x`; memory and
I/O commands such as `F`, `f`, `I`, `i`, `O`, `o`, `Q`, and `q`; register
commands `R`/`r`; configuration and version/reset commands `C`, `c`, `E`, `V`,
`v`, and `z`. The ROM also branches on a few additional or version-specific
characters (`M`, `X`, `a`, `m`, and some control characters) that still need
routine-by-routine decoding.

The v5 manual's troubleshooting section says ROMmed monitors should place the
public `hardware_reset` symbol at the processor's hardware reset address. This
DreamWriter ROM does not do that for the normal V20 reset vector: `FFFF:0000`
still jumps through `F8DC:0000` to the DreamWriter firmware. Therefore the
CSiMON path is probably selected by hardware outside the normal firmware path:
a fixture strap, ROM-emulator/PromICE style setup, reset-vector overlay, or
some other board-level mode. For MAME-only testing, the direct entry should be:

```text
PS = FFDF
PC = 0005
```

Do not enter it by setting only the linear debugger `GENPC` while `PS` still
names the normal reset segment. The entry stub uses `CS:`-relative data at
`FFDF:0000`, so it needs `CS/PS == FFDF`. The stub leaves the USART configured
as 9600 8N1 in the current MAME model (`port 0x30 = 0x11`, 8251 mode `0x4E`),
then transmits `0x78` repeatedly before entering the monitor.

Because the write happens after the high-ROM entry is already executing, and no
firmware read/branch on port `0x20` has been found, port `0x20` is unlikely to
be the software-selected trigger for CSiMON. It is more plausibly a handshake or
status output to external monitor/fixture hardware: normal firmware advertises
"not in monitor" with `0x00`, while the CSiMON entry advertises "monitor path
active" with bit `0x20`. The actual selection mechanism still looks external to
normal firmware.

References:

- Local CSi-Mon User's Guide Version 5.0:
  [`docs/reference/csimon.pdf`](reference/csimon.pdf)
- Concurrent UNIX Review, June 1991, "Soft-Scope III Cross Debugger And
  Software Monitor":
  <https://jacobfilipp.com/DrDobbs/articles/CUJ/1991/9106/newprod/newprod.htm>

Current evidence does not tie port `0x20` to the retained power-off handoff.
The `C000:035D`/`out 0x70,0x01` terminal power path never writes it.

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

The control writes now line up well with MAME's `RP5C01` model. The device only
uses the low nibble of each written byte, so the firmware's `0xF?` values are
effectively `0x0?` register values:

| Port | RP5C01 role | Firmware use |
| ---: | --- | --- |
| `0xDD` | Mode register: low bits select mode, bit `0x04` enables alarm output, bit `0x08` enables timer advance. | Startup writes `0xF8`, meaning mode 0 with timer enabled. RTC write setup uses `0xF1` and `0xF0` to access mode 1/control state with timer/alarm disabled. Alarm setup uses `0xF9`, then restores `0xF8`. The retained power-off helper ORs in bit `0x04` before leaving, enabling alarm output. |
| `0xDE` | Test register. | Startup and RTC write setup write `0xF0`, so the test register is cleared. |
| `0xDF` | Reset register: bit `0x01` resets alarm registers, bit `0x02` is timer reset, bits `0x04`/`0x08` disable the 16 Hz and 1 Hz output gates in MAME's model. | RTC write setup writes `0xFF`. Alarm programming writes `0xFD`, clearing only the timer-reset bit while leaving the alarm reset and output-gate disable bits set. |
| `0xDA` | Mode 0: month tens. Mode 1: 12/24-hour select. | RTC write setup writes `0x01` while in mode 1, matching 24-hour mode selection. Date writes later write `0xDA` as the month tens nibble while in mode 0. |

Two helpers program mode 1 alarm registers. `C000:0A11` copies low nibbles from
`6D45..6D4A` into alarm ports `0xD8` down through `0xD2`, skipping weekday port
`0xD6`; on an RP5C01 those are day, hour, and minute alarm fields. `C000:0A3F`
programs only the minute alarm fields at `0xD2/0xD3` to current minute + 1,
wrapping at 60.

The stored-alarm buffer is fed by `DC98:D3BB`, which is called during the
retained power-transition path. It reads the current date/time through the same
`DC98:0D2A`/`0D4E` wrappers used by WORLD CLOCK, then scans two user-visible
alarm sources:

| Source | Storage | Selection marker |
| --- | --- | --- |
| Scheduler alarms | Up to `0xC8` records beginning at `82C8`, with date/time words compared against the current date/time. | `6D4C = scheduler index`. |
| WORLD CLOCK daily alarms | Four rows at `89F2 + row * 0x17`; the first word is minutes after midnight, or `0xFFFF` for disabled. | `6D4C = 0x0100 + row`. |

`DC98:D3BB` writes the next selected alarm into `6D41..6D4C`. `6D41 == 0xFF`
marks "no pending alarm"; otherwise `6D41..6D46` hold the selected alarm date
nibbles, `6D47` is copied into the RTC weekday/status shadow before compare,
`6D48..6D4B` hold the selected alarm time nibbles, and `6D4C` records the
selected source/index. This means the WORLD CLOCK daily alarm feeds the RTC
alarm path rather than being only a foreground software compare.

The retained power-transition helper at `C000:0376` temporarily clears the
timer-enable bit in `0xDD`, checks stored alarm/schedule state, restores the
timer-enable bit, calls either `C000:0A11` or `C000:0A3F`, then enables the
alarm bit before returning to the `out 0x70,0x01; jmp $` terminal loop.
`C000:0A11` is used when the selected scheduler/daily alarm is still in the
future. If the selected alarm already compares equal to the current RTC
date/time, or equal by the shorter day/time compare, the helper uses `C000:0A3F`
to program current minute + 1 instead. That looks like an anti-retrigger or
short fallback wake while powering down. Together, the ROM behavior strongly
suggests port `0x70` controls an external power/reset latch and the RP5C01 alarm
output is intended to wake the unit for scheduled and daily alarms; the remaining
unknown is the exact external wiring.

The IRQ handlers themselves do not appear to read an alarm-status bit directly.
The periodic foreground wait loops do, however, check a warm/power-management
marker that IRQ `FF` can set. In the fall-through branch, `C000:02EE` writes
`[6809] = 0x1992` and returns with `iret`; in its warm/diagnostic branch it
prepares retained state and reaches the `out 0x70,0x01` terminal loop. The
timer-driven idle loops at `C000:4A04`, `C000:4A8D`, and `C000:4B1D` repeatedly
call `C000:4961`; that helper sets carry when `[680D] == 0` and
`[6809] == 0x1992`, causing the idle loop to save a resume target and enter the
retained power-transition path. `[680D]` is set while alarm UI/service code is
active, so it appears to suppress re-entering that transition while the alarm is
already being handled. This makes IRQ `FF` part of the warm/power-state
machinery, not clear evidence that it is the RTC alarm interrupt itself.

After a wake/reset reaches startup code, `C000:0807` calls `C000:0784`; if that
returns with carry clear, the caller plays the configured power-on buzzer and
restores the saved screen. `C000:0784` is the deeper RTC alarm discriminator:

| Path | Meaning |
| --- | --- |
| `[6D4E] == 0` | Normal stored scheduler/daily alarm path. `C000:0B90` snapshots the RTC and compares the full selected alarm buffer `6D41..6D4B` against current RTC date/time. If that is not equal, `C000:0B7C` compares the shorter day/hour/minute portion. |
| `[6D4E] != 0` | Current-minute+1 fallback path. `C000:0BAF` snapshots the RTC and checks whether seconds are `00`, apparently to avoid immediately retriggering while the minute fallback is active. |

The likely hardware model is therefore: the RTC alarm output causes external
power/reset hardware to bring the firmware back through a warm/startup path, and
the firmware then verifies whether the wake corresponds to a selected
scheduler/daily alarm or to the fallback minute alarm. If there is a dedicated
CPU interrupt for the RTC alarm line, it is not obvious from the ROM as a
handler that reads a status bit.

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

The WP -> COMMUNICATE -> TERMINAL entry point is `C688:EC5A`, which calls the
low-ROM terminal service through `C000:1712` with `AH=7`. The terminal loop at
`C000:1089` initializes the serial path, polls translated keys through
`int 21h AH=08`, and sends bytes through `int 21h AH=04`.

The terminal key translation at `C000:10E4` is a small one-byte remap, not an
ECMA-48 or VT52 escape-sequence generator:

| Physical key | Translated key code | Sent byte | Meaning |
| --- | ---: | ---: | --- |
| `LEFT` | `0x11` | `0x08` | BS |
| `RIGHT` | `0x10` | `0x0C` | FF |
| `DOWN` | `0x12` | `0x0A` | LF |
| `UP` | `0x13` | `0x0B` | VT |
| `TAB` | `0x09` | `0x09` | HT |
| `ENTER` | `0xDA` | `0x0D` | CR |

The keyboard tables backing this are at `C000:53E9` and related shifted/control
variants. In the normal table, the physical arrow positions translate to
`LEFT=0x11`, `DOWN=0x12`, `RIGHT=0x10`, and `UP=0x13`. The terminal loop sends
ordinary printable bytes unchanged for `0x20..0xBF`; other control-like key
codes are mostly ignored unless present in the `C000:10E4` remap table.

The receive side does not expose a raw path into the display-resource opcode
stream. `C000:1118` passes the received byte to `DC98:0038`, whose inner
renderer at `DC98:DCAC` accepts printable `0x20..0xDF`, handles a small set of
C0 controls (`0x07..0x0D`, `0x1A`, `0x1B`, `0x1E`), and maps received
`0xE0..0xFF` to a literal space before drawing. The `0x1B` path enters a
CSI-like parser at `DC98:E053`, but that parser dispatches named terminal
operations rather than copying arbitrary bytes into the display stream.
`DC98:DD4A` then builds a local
display stream containing `FF 02` cursor positioning, optional style bytes from
terminal state, and the sanitized character before calling `C000:67AD`. So
serial input can exercise the terminal's character/control handling, but not the
raw `FF 40`/`FF 42`/`FF 44` bitmap and drawing opcodes.

The terminal control parser is small and mostly ANSI/VT100-like. It enters the
parser on `ESC` (`0x1B`), requires `[`, accumulates decimal parameters and
semicolons in the buffer at `8C83`, and dispatches on the final byte:

| Sequence | Handler | Operation |
| --- | --- | --- |
| `ESC [ row ; col H` | `DC98:E17B` | Move cursor to `row,col`; parameters are 1-based, clamped to the 8x80 terminal area, and missing/zero values become 0. |
| `ESC [ row ; col f` | `DC98:E17B` | Same as `H`. |
| `ESC [ n A` | `DC98:E2D3` | Move cursor up `n` rows; default `n=1`, clamped at row 0. |
| `ESC [ n B` | `DC98:E31A` | Move cursor down `n` rows; default `n=1`, clamped at row 7. |
| `ESC [ n C` | `DC98:E249` | Move cursor right `n` columns; default `n=1`, clamped at column 79. |
| `ESC [ n D` | `DC98:E28C` | Move cursor left `n` columns; default `n=1`, clamped at column 0. |
| `ESC [ n J` | `DC98:E35D` | Erase display: `0` clears from cursor to end, `1` clears from start through cursor and leaves the cursor at home, `2` clears all and homes the cursor. |
| `ESC [ n K` | `DC98:E38E` | Erase line: `0` clears from cursor to end, `1` clears from start through cursor and leaves column 0 selected, `2` clears the whole line and leaves column 0 selected. |
| `ESC [ n L` | `DC98:E47D` | Insert `n` blank lines at the cursor row; default `n=1`, clamped to the remaining rows, and column becomes 0. |
| `ESC [ n M` | `DC98:E5AD` | Delete `n` lines at the cursor row; default `n=1`, clamped to the remaining rows, and column becomes 0. |
| `ESC [ s` | `DC98:E74C` | Save cursor column and row to `8C79`/`8C7B`. |
| `ESC [ u` | `DC98:E759` | Restore cursor column and row from `8C79`/`8C7B`. |
| `ESC [ ... m` | `DC98:E1CF` | SGR-style attributes. Recognized parameters are `0` reset, `1` bold (`F8` style byte), `4` underline-like (`F0` style byte), `7` reverse-like (`F2` style byte), and `8` conceal printable bytes as spaces. Multiple parameters are accepted. |
| `ESC [ > 5 h` | `DC98:E236` | Private cursor-state toggle; this path passes `0` to `DC98:DC69`, clearing the cursor-visible flag. |
| `ESC [ > 5 l` | `DC98:E236` | Private cursor-state toggle; this path passes `1` to `DC98:DC69`, setting the cursor-visible flag. |

No terminal query/report sequences are recognized in this parser. Final bytes
such as `n` for DSR/status report, `c` for device attributes, or cursor-position
report requests are not dispatched, and this receive-side parser does not call
the serial transmit helper.

MAME now maps ports `0xC0..0xC1` to the generic `I8251` device with the device
tag `upd71051`, matching the likely NEC uPD71051-compatible part. Port `0x30`
bits `0..2` scale a `19200 * 16` USART clock downward using the firmware's
inverted baud index, RX ready asserts IRQ vector `FC`, and transmit-ready now
asserts IRQ vector `FD`. The `FD` mapping is still an emulator hypothesis, but
the firmware's `FD` handler is a short acknowledge/flag-clear path and matches
the observed terminal behavior better than a receive-only USART model. The
driver wires the USART's `RTS`, `DTR`, and `TXD` outputs to the RS-232 port and
wires RS-232 `RXD` and `CTS` back into the USART. The driver also defaults the
`rs232:pty` option to RTS-style flow control, but the generic PTY backend
currently does not consume the guest's RTS/DTR modem-control outputs, so
host-to-DreamWriter PTY throttling still needs either upstream PTY support or a
different test backend.

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

MAME now attaches a `centronics` slot using the standard Centronics bus. Port
`0x40` feeds an `output_latch_device`, port `0x30` bit `0x20` drives the
Centronics strobe input, `BUSY` updates port `0xA0` bit `0x02`, and `ACK`
asserts IRQ vector `FE`.

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
| `0x01` | No confirmed firmware consumer found. |
| `0x02` | Centronics `BUSY`, active high. |
| `0x04` | CR2032 memory-retention battery low, active high. |
| `0x08` | Main battery low, active high. |
| `0x10` | PCMCIA SRAM-card battery status, active-low low-battery indication when a card is present. |
| `0x20` | No confirmed firmware consumer found. |
| `0x40` | Likely SRAM-card write-protect; `C000:0ACE` sets carry when this bit is set and card write paths report error `0x0B`. |
| `0x80` | PCMCIA card absent/not-ready gate; `C000:0AC4` sets carry when this bit is set. |

MAME now combines configurable battery inputs with live peripheral status:
Centronics `BUSY` supplies bit `0x02`, PC Card `BVD2` supplies bit `0x10`,
PC Card write-protect supplies bit `0x40`, and PC Card detect supplies bit
`0x80`. The main and CR2032 battery-low bits remain configurable inputs.

## PCMCIA Slot

MAME now attaches a `pcmcia` slot with existing SRAM-card device options:
`melcard_1m`, `sram_1m`, `sram_2m`, and `sram_4m`. Selecting an SRAM device
exposes an `sramcard` image slot accepting `.bin` files.

The current MAME patch also adds a tentative PC Card memory map for card-present
systems: bank values `0x18..0x1F` route the selected 128 KiB CPU window to SRAM
card pages `7..0`, so `0x1F` is card page 0, `0x1E` is card page 1, and so on.
This matches the card formatter's probe at `C000:3C08`, which writes through
16 consecutive 32 KiB pages beginning at segment `0x4000` while `C000:0239`
slides bank registers `0x14/0x15` downward through `0x1D..0x18`. This is still
a first-pass decode: the attribute/CIS space is not mapped, and the exact glue
logic that decides when those bank values mean card SRAM rather than internal
RAM needs hardware confirmation.

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
speaker loop. Current MAME maps ports `0x50..0x52` to a `BEEP` device:
`0x50/0x51` latch the 16-bit divisor, `0x52 = 0x7F` gates the tone on, and
other `0x52` writes turn it off. The first-pass tone clock is `X301 / 64`,
which is the 9.83 MHz CPU clock divided by 32, and the output route is `0.05`
gain, matching quieter portable/terminal beeper precedent in MAME.

Interactive testing confirms audible output in both the copyright/startup
buzzer path and the `INITIALIZING` path. The deep tone during `INITIALIZING`
matches the known boot write using divisor `0x0698`, which is about `182 Hz`
with the current `X301 / 64` tone clock.

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

The values match a nominal 10 Hz idle countdown. The active countdown lives in
`[680B]`; idle paths reload it from `[6D31]` and decrement it while checking
for keyboard/activity and battery-warning work. The decrement is foreground
idle-loop code after `sti; hlt` returns, not code inside an interrupt handler.
The wake source appears to be a programmable timer latch at port `0x53`, not a
free-running RTC interrupt. When `[680B]` reaches zero and `[6D31] != 0`, the
firmware enters a retained power-transition path:

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

Port `0x70` itself is not written throughout the countdown; it is written only
after the retained transition has saved/checksummed state and programmed the RTC
alarm. This argues that `0x70` is the final hardware handoff, while ports
`0x53`, `0x60`, `0xDD..0xDF`, and the retained RAM fields perform the software
preparation.

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

The timer arm/disarm helpers are:

```asm
C000:0B3C  or   byte [6DA9],01
C000:0B41  and  byte [6D4F],FD
C000:0B46  mov  al,[6D4F]
C000:0B49  out  60,al
C000:0B4B  mov  al,ah
C000:0B4D  out  53,al       ; arm timer count
C000:0B4F  ret

C000:0B50  and  byte [6DA9],FE
C000:0B55  or   byte [6D4F],02
C000:0B5A  mov  al,[6D4F]
C000:0B5D  out  60,al       ; mask/disarm timer IRQ path
C000:0B5F  ret
```

Direct callers arm counts `0x0A`, `0x56`, and `0x60`. The main keyboard idle
loop uses `0x60`; if the timer input is the same `X301 / 20480` rate used for
the keyboard scan model, `0x60` ticks expire at almost exactly 100 ms with the
current `X301 = 19.66 MHz` MAME constant. If the real crystal is the common
`19.6608 MHz` value, then `X301 / 20480 = 960 Hz` exactly and `0x60` produces
exactly 10 Hz. This is a more plausible hardware-shaped divider than the earlier
`X301 / 20000` approximation.

The alternate idle path at `C000:4974` splits the same nominal tick into two
timer writes:

```asm
C000:498E  call C000:0B50   ; clear/disarm previous F9 state
C000:4991  mov  ah,0x0A
C000:4993  call C000:0B3C   ; short foreground/service slice
...
C000:49C2  dec  word [680B] ; auto-off countdown tick
...
C000:49D6  mov  ah,0x56
C000:49D8  call C000:0B3C   ; long remainder before next entry
```

`0x0A + 0x56 = 0x60`, so these appear to be two phases of the same idle
cadence rather than separate clock rates.

There is no current ROM evidence that the value written to `0x53` selects the
interrupt vector. All direct `out 0x53` writes go through `C000:0B3C`, and all
observed wait loops track the same software pending bit, `[6DA9] bit `0x01`.
Only the `F9` handler and the explicit disarm helper clear that bit:

```asm
C000:049A  ; IRQ F9
  out 90,40
  and byte [6DA9],FE

C000:0B50  ; explicit disarm
  and byte [6DA9],FE
```

If `0x53` can route to another interrupt, that interrupt has not yet been found
clearing the matching software state. The stronger selector/control clue is
port `0x60` / `[6D4F]` bit `0x02`: `C000:0B3C` clears it before writing the
timer latch, while `C000:0B50` sets it when disarming.

Two short IRQ handlers are plausible simple `hlt` wake sources:

```asm
C000:049A  ; IRQ F9
  out 90,40
  and byte [6DA9],FE
  sti
  iret

C000:0724  ; IRQ FD, likely USART transmit-ready
  out 90,04
  and byte [70A5],F7
  sti
  iret
```

`F9` is especially interesting because the idle loops test `[6DA9]` bit `0x01`
near the auto-off decrement sites. MAME originally modeled this as a
free-running 10 Hz source, which was enough to make the Organizer WORLD CLOCK
seconds display advance without keypresses. The current working model follows
the ROM more closely: writes to port `0x53` schedule a one-shot `F9`, and the
firmware re-arms that one-shot each time it needs another idle wake. The exact
hardware divider still needs board confirmation.

## Power / Wake Hypothesis

MAME does not model a named power key or switch. It exposes a synthetic debug
input port where host `F8` asserts IRQ vector `F8` and host `F1` asserts IRQ
vector `FF`.

The firmware handlers make `F8` look like the save/suspend side of the power
path, while `FF` is the warm/diagnostic/power-management side we used in MAME to
make the copyright path reproducible:

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
  common branch: [6809]=1992; sti; iret
  warm/diagnostic branch: save warm target under 6D79..6D87
  out 70,01          ; terminal branch only
  jmp $              ; wait for external power/reset transition
```

That fits a physical power control better than a normal scanned keyboard key.
A latching switch could plausibly present one edge/state as the suspend/save
interrupt, with another external line or reset path bringing the machine back
through the warm/copyright logic. The exact electrical behavior is still
unconfirmed.

## Low RAM State

| Address | Meaning seen so far |
| ---: | --- |
| `6807` | Cleared on diagnostic chord in warm IRQ path. |
| `6809` | Startup/warm/power-management state marker. Values include `0001`, `1992`, `1995`, `1999`; IRQ `FF` writes `1992` in its fall-through branch, and periodic idle helper `C000:4961` tests for that value. |
| `680B` | Active auto power-off countdown. Reloaded from `[6D31]` and decremented in idle paths. |
| `680D` | Alarm/power service guard. When zero, `C000:4961` allows `[6809] == 0x1992` to force the retained power-transition path; alarm display/service code sets it nonzero while handling the event. |
| `7036` | Built-in store dirty/checksum-needed flag. Cleared at startup; storage write/format/delete-like paths set it. If nonzero during the `C000:035D` retained transition, `C000:044B` checksums `1800:0008..7FFF` into `1800:0006` before the port `0x70` power handoff. |
| `6D06..6D0F` | Raw keyboard matrix rows. |
| `6D28` | Keyboard scan state/idle counter. |
| `6D29` | Keyboard scan row index. |
| `6D2A..6D2E` | RS-232C setup bytes: baud index, bit length, stop bits, parity, XON/XOFF. |
| `6D2F` | Auto power-off period index from WP -> OTHERS -> SYSTEM: `0..6` = `2`, `3`, `5`, `10`, `15`, `20`, `UNLIMITED`. |
| `6D30` | Power-on buzzer setting: `0..2` = types 1..3, `3` = no buzzer. |
| `6D31` | Auto power-off countdown reload value, selected from `[6D2F]`; `0` disables timeout. |
| `6D41..6D4C` | Next alarm selection written by `DC98:D3BB`. `6D41 == 0xFF` means no pending alarm; otherwise date/time BCD nibbles feed the RP5C01 alarm programmer at `C000:0A11`. `6D4C < 0x0100` identifies a scheduler alarm record; `6D4C >= 0x0100` identifies a WORLD CLOCK daily-alarm row. |
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
