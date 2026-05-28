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

Confirmed/candidate screen buffer routines:

| Address | File offset | Operation |
| --- | ---: | --- |
| `C000:07E9` | `0x407E9` | Calls `C000:4C39`, then copies `0x1000 -> 0x94F0` for `0x800` words. |
| `C000:07F4` | `0x407F4` | Copies `0x94F0 -> 0x1000` for `0x800` words. |
| `C000:4C4F` | `0x44C4F` | Candidate copy `0x94F0 -> 0x131B`, 40 rows of 6 bytes with `0x3A` stride. |
| `C000:4C6E` | `0x44C6E` | Candidate copy `0x131B -> 0x94F0`, same layout. |

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
| `0x30` | Diagnostic `T`/`N` handling toggles bit `0x80` via `[6D94]`. |
| `0x40` | Startup writes `0xFF`. |
| `0x50..0x52` | MAME comments suggest sound counter low/high and enable/disable, based on boot and beep-like writes. |
| `0x60` | IRQ enable register in MAME; firmware mirrors the written value at `[6D4F]`. The idle wait at `C000:4A94` writes `[6D4F]` here immediately before `sti; hlt`. |
| `0x61` | Keyboard idle path writes `0xFE`. |
| `0x70` | Warm diagnostic IRQ path writes `0x01` before halting in a loop. |
| `0x90` | IRQ active/source clear register in MAME. Bit 7 clears vector `F8`; bit 0 clears vector `FF`. |
| `0xA0` | MAME returns `0xF7`; comment says bit 3 is battery-low when set, so this reports battery OK. |
| `0xB0` | Keyboard row input port; returns the row selected by the keyboard timer state. |
| `0xC0..0xC1` | Communication or peripheral status/data in IRQ path around `C000:0550`. |
| `0xD0..0xDF` | Mapped to Ricoh `RP5C01` RTC in MAME. Existing notes around `0xDD..0xDE` are therefore RTC-register accesses, not generic control ports. |

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
| `6D06..6D0F` | Raw keyboard matrix rows. |
| `6D28` | Keyboard scan state/idle counter. |
| `6D29` | Keyboard scan row index. |
| `6D4F` | Port `0x60` state mirror. |
| `6D51` | Flags; diagnostic paths clear bit `0x08`. |
| `6D65..6D87` | Saved resume context/checksum area used by suspend/warm paths. |
| `6D79` | Saved resume IP. Diagnostic warm entry stores `4A8D`. |
| `6D7B` | Saved resume CS. |
| `6D7D` | Saved resume SP. |
| `6D81` | Diagnostic/warm marker; `1995` requests diagnostic/warm handling. |
| `6D83` | Checksum over saved context. |
| `6D94` | Port `0x30` value mirror. |
