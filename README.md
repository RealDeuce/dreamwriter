# DreamWriter T400 ROM 2.1 Notes

Working target: `t4_ir_2.1.ic303`

```text
Size:   524288 bytes
SHA256: bb6a437d4c25f90eb7a0b8bc3d41e1ca2c74196aabe60954a598c66405397757
```

This repo is for mapping and tooling around the T400 2.1 ROM. MAME also has a
3.1 BIOS for `drwrt400`; it is not copied here. Be careful not to mix addresses
between 2.1 and 3.1. Comparative notes may reference other DreamWriter ROMs, but
those addresses are explicitly labeled as non-T400.

Unless a page explicitly says it is comparative, treat `t4_ir_2.1.ic303` plus
the disassembly helpers in `tools/` as the source of truth. The first-pass
machine-readable split is [`docs/rom-regions.tsv`](docs/rom-regions.tsv);
topic pages should agree with that map or explain why they are provisional.

Related projects:

| Project | Notes |
| --- | --- |
| [Dreamulator](https://github.com/realDeuce/dreamulator) | DreamWriter emulator project and the more interesting related codebase for running and experimenting with these machines. |
| [DreamWriter 200 notes](https://github.com/RealDeuce/dreamwriter200) | Similar ROM-map notes focused on the DreamWriter 200; useful for comparison, but generally a less complete version of this T400 content. |

## MAME

Machine:

```sh
mame drwrt400 -bios v2_1
```

Useful debugger command line:

```sh
mame drwrt400 -bios v2_1 -debug -debugger imgui \
  -video bgfx -bgfx_path /usr/local/share/mame/bgfx -window \
  -update_in_pause -ui_active
```

Do not use `-steadykey` for this driver. It makes the keyboard unusable in
testing.

MAME debug input port maps F1-F8 to synthetic IRQ vectors:

```text
F1 -> irq FF
F2 -> irq FE
F3 -> irq FD
F4 -> irq FC
F5 -> irq FB
F6 -> irq FA
F7 -> irq F9
F8 -> irq F8
```

## ROM Mapping

The 2.1 ROM is 512 KiB and is loaded at ROM region offset `0x80000` in MAME.
For the normal 2.1 `C000:xxxx` code we have been using:

```text
physical address C0000..FFFFF -> file offset 40000..7FFFF
```

Example:

```text
C000:1240 physical C1240 -> file offset 0x41240
```

The reset vector is at the end of the 1 MiB CPU address space and jumps into
ROM startup code. Real-mode segment aliases matter; always track `CS`, `DS`,
`ES`, and `SS` when interpreting near references.

Working notes are split by topic under `docs`, with this README serving as the
central index for the repo. Address, string, and direct branch/call inspection
helpers are in `tools/rom2.py`; see [`tools/README.md`](tools/README.md) for
the command reference.

## Documentation Index

| File | Description |
| --- | --- |
| [`docs/README.md`](docs/README.md) | Index for the topic-specific ROM notes. |
| [`docs/map.md`](docs/map.md) | Address model, coarse ROM layout, and reset chain. |
| [`docs/rom-regions.tsv`](docs/rom-regions.tsv) | Machine-readable first-pass code/data/resource region map. |
| [`docs/banking.md`](docs/banking.md) | MAME bank formula and confirmed ROM bank-switching routines. |
| [`docs/spell-engine.md`](docs/spell-engine.md) | Banked spell/grammar/linguistic service thunk and dispatcher notes. |
| [`docs/entry-points.md`](docs/entry-points.md) | Confirmed code entry points and direct branch/call inventory. |
| [`docs/startup-ui.md`](docs/startup-ui.md) | Cold-start UI path, inline display scripts, boot update sequence, and first menu graphic. |
| [`docs/menu-dispatch.md`](docs/menu-dispatch.md) | Inline key dispatch tables and the shared application menu event loop. |
| [`docs/file-system.md`](docs/file-system.md) | FILE menu storage flow, DOS-like file API wrappers, and directory/DTA evidence. |
| [`docs/running-rom-card-binaries.md`](docs/running-rom-card-binaries.md) | Practical workflow for running arbitrary `EROMCARD.X` binaries through OTHERS -> ROM CARD. |
| [`docs/basic-eromcard.md`](docs/basic-eromcard.md) | Comparative feasibility notes for wrapping the DreamWriter 325 BASIC interpreter as T400 `EROMCARD.X`; depends on a non-T400 source ROM. |
| [`docs/dreamlink-protocol.md`](docs/dreamlink-protocol.md) | DreamLink RS-232 file-transfer protocol, command frames, listings, and data stream framing. |
| [`docs/wp-editor-heap.md`](docs/wp-editor-heap.md) | Word-processor live document heap, block allocator, and cross-application use evidence. |
| [`docs/diagnostics.md`](docs/diagnostics.md) | Diagnostic chord, command loop, banner/help strings, and warm IRQ entry. |
| [`docs/hardware.md`](docs/hardware.md) | Keyboard, LCD/framebuffer, I/O ports, serial, printer, PCMCIA, sound, RTC, power, and low RAM state. |
| [`docs/hardware-confirmation.md`](docs/hardware-confirmation.md) | Board-inspection checklist for confirming clocks, devices, ports, and status wiring. |
| [`docs/fonts.md`](docs/fonts.md) | Main glyph table, width table candidates, and font variants. |
| [`docs/bitmaps.md`](docs/bitmaps.md) | Confirmed LCD bitmap icons and candidate UI/icon resources. |
| [`docs/strings.md`](docs/strings.md) | String/resource landmarks for application-level mapping. |
| [`docs/open-questions.md`](docs/open-questions.md) | Unresolved questions after the current ROM/tooling audit. |
| [`docs/reference/csimon.pdf`](docs/reference/csimon.pdf) | CSi-Mon User's Guide v5.0, useful background for the high-ROM `CSiMON-88` monitor code. |
| [`docs/reference/dreamlink-manual.pdf`](docs/reference/dreamlink-manual.pdf) | DreamLink PC software manual; documents FILE -> STORE/RECALL transfer flow, host-side file format selection, and print-through mode. |
| [`docs/reference/dreamwriter-t400-manual.pdf`](docs/reference/dreamwriter-t400-manual.pdf) | DreamWriter T400 user manual; broad user-facing reference, currently missing pages 10 and 11 in the source copy. |
| [`tools/README.md`](tools/README.md) | Command reference for `tools/rom2.py`. |
| [`dw-basic/README.md`](dw-basic/README.md) | NASM-targeted DreamWriter BASIC port workspace and first `EROMCARD.X` smoke target. |

## Boot Path

Startup begins at `C000:0000`:

```asm
C0000  jmp C0029
```

Important early path:

```asm
C0090  call far C688:0053   ; retained/warm RAM signature check
C0095  jc C00E1             ; cold boot if signature mismatch
C0097  call C47D3           ; validate warm state
C009A  jc C00E1             ; cold boot if invalid
...
C0142  call C08DA           ; diagnostic gate on warm path
```

Cold boot goes to `C00E1` and then into the main firmware:

```asm
C00E1  mov word [6d81],0000
...
C00FA  call C4811           ; built-in store validation/init
...
C011A  jmp far C688:000B
```

In MAME, a normal reset takes the cold path: `C0095 -> C00E1`, not `C0142`.
That is the expected route to the `INITIALIZING` screen when retained RAM is not
recognized. `C4811` selects built-in store `08`, checks the DreamWriter header
and checksum at segment `1800`, and invokes `INT 21h` service
`AH=FF/BL=A5/DL=08` to initialize the 160 KiB built-in store if the check fails.

## Diagnostic Entry

Diagnostic banner:

```text
file 0x46912 / phys C6912:
Diagnostic 21BAB047 (97Apr14)        K: Keyboard check
```

Diagnostic command text includes:

```text
Mxxxx:yyyy     dump Memory
Sxxxx:yyyy,zz  Set memory
Y,Zxxxx:yyyy   Single step
Iyyyy  dump I/O,  L=dump I/O(alarm)
T=Card ATTR, N=COM, Q/R=Clear/Reset spell
```

Main diagnostic gate:

```asm
C08DA  call C1240
C08DD  jc C08E0
C08DF  ret
C08E0  mov word [6d81],1995
```

Diagnostic entry routine:

```asm
C1240  call C1252           ; compare keyboard chord
C1243  jz C1247             ; enter diagnostic if matched
C1245  clc
C1246  ret
C1247  call C1272           ; draw/init diagnostic
```

Chord compare:

```asm
C1252  push es
C1253  mov di,C000
C1256  mov es,di
C1258  mov di,1268
C125B  mov si,6D06
C125E  mov cx,000A
C1262  repe cmpsb
```

Expected bytes at `6D06..6D0F`:

```text
00 08 00 00 80 00 00 00 40 00
```

Using the MAME keyboard matrix, this is:

```text
SPACE + F + J
```

Confirmed in MAME: holding `F+J+SPACE` produces exactly those bytes at
`6D06..6D0F`.

## Warm IRQ Path

The diagnostic chord is checked by the synthetic/wake IRQ path, not by cold
boot.

Low ROM vector stubs:

```asm
C000:0009  jmp C03AE   ; irq F8, save/suspend context
C000:001E  jmp C02EE   ; irq FF, wake/reset-ish handler
```

`C02EE` path:

```asm
C0316  call C1252      ; compare F+J+SPACE
C031C  jz C0329
...
C0329  mov byte [6807],00
C032E  mov word [6d79],4a8d
C0336  mov [6d7b],cs
C0339  mov word [6d81],1995
...
C0370  mov al,01
C0372  out 70,al
C0374  jmp C0374
```

In MAME, the `Home` power key samples the held keyboard rows into `6D06..6D0F`
before the retained-RAM wake/reset path, and reset entry samples them again
before the ROM starts. The port `0x61` `FE -> FF` scan-enable edge samples them
again after the firmware resets its scan state. Holding `F+J+SPACE` while
pressing `Home` therefore reaches the ROM's warm diagnostic path. The synthetic
F1 IRQ can still be used as a direct debugger shortcut to `C02EE`; with
`F+J+SPACE` held, breakpoints at `C02EE`, `C0316`, `C0329`, and `C0370` all hit.

## Keyboard

Raw keyboard rows are stored in low RAM at `6D06..6D0F`.

Keyboard scan ISR excerpt:

```asm
C04DD  mov bl,[6d29]      ; row index
C04E3  in al,0xb0         ; current row bits
C04EE  mov [bx+6d06],al   ; raw row state
```

The firmware stores level state, not just key edges. Normal key repeat is handled
higher up using state around `6EB0..6EB3`.

## LCD / Framebuffer Model

MAME models the display as a RAM scanout window selected by I/O port `0x00`.

ROM boot writes:

```asm
C0055  mov al,08
C0057  out 00,al
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

Screen buffer routines:

```asm
C07E9  copy 0x1000 -> 0x94F0
C07F4  copy 0x94F0 -> 0x1000
C4C4F  restore battery-warning screen area, 0x94F0 -> 0x131B
C4C6E  save battery-warning screen area, 0x131B -> 0x94F0
```

The `C000:4C4F`/`C000:4C6E` pair is tied to the documented battery-warning
icons, not a general LCD buffer swap. It copies 40 rows of 6 bytes with a
`0x3A` row gap, matching a 48x40-pixel warning area.

Working model: the original hardware has LCD scanout from RAM, either true
dual-ported RAM or bus-stealing/arbitrated video RAM. The firmware probably
does not bit-bang the LC7940/LC7942 refresh.

## ROM Card / PCMCIA Storage

Useful strings in 2.1:

```text
EROMCARD.X
ROM CARD
No ROM card is in the slot
Can not open EROMCARD.X
ROM Card ID error
Card is write-protected
Card memory read error
FORMAT SETTING
Card Memory-
```

The `ROM CARD` menu path is decoded at `DC98:2B75`. It builds
`([0x6805]+1):EROMCARD.X`, falls back to `[0x6805]:EROMCARD.X`, opens it via
the DOS-like file services, checks that it fits within `[7A54] * 0x80` bytes of
work memory, loads it to `0xA4F0`, validates header words
`[0xA4F0] == 0xA4F0` and `[0xA4F2] == 0x1997`, then calls the far entry stored
at `[0xA4F4]`. The far pointer is stored in normal x86 `offset,segment` order at
file offset `+0x04`; the loaded entry receives `AX = [7A54] * 0x80`. See
[`docs/file-system.md`](docs/file-system.md#rom-card-loader).

This is not a CP/M `.COM`, PC DOS `.COM`, or MZ `.EXE` load path: the loader
requires the custom `0xA4F0/0x1997` header and calls an explicit far pointer.

The `FILE` menu storage paths distinguish built-in RAM, card storage, and
DreamLink transfer. The local storage layer is FAT12-derived but uses a custom
volume header/geometry block; see [`docs/file-system.md`](docs/file-system.md).

## Audit Notes

The README and topic indexes were last reconciled against
`tools/rom2.py verify`, `docs/rom-regions.tsv`, direct string scans,
positioned bitmap-record scans, and the code-only I/O summary on 2026-06-02.

Items that still cannot be answered from the T400 2.1 ROM alone are kept in
[`docs/open-questions.md`](docs/open-questions.md). Comparative files such as
[`docs/basic-eromcard.md`](docs/basic-eromcard.md) and the non-T400 rows in
[`docs/running-rom-card-binaries.md`](docs/running-rom-card-binaries.md) require
the external ROM images named in those pages.

## Open Questions

- Physical power/wake path and the exact selector/timing for the startup
  copyright banner. The `INITIALIZING` path is now traced to the cold
  retained-RAM/init branch.
- Board-level wiring for port `0xA0` battery, card, and printer-status bits.
- `EROMCARD.X` candidate-drive mapping and whether a loaded stub can execute
  further code from PCMCIA memory.
- Custom FAT12-derived volume header and geometry details.
- Remaining display/resource script opcodes and status-icon cluster.
- Recursive disassembler/function-boundary tooling for broader call graphs.

## Initial Tooling Goals

1. Build a recursive real-mode disassembler pass.
2. Normalize segment:offset references to physical addresses when possible.
3. Emit labels for known entry points and RAM globals.
4. Extract strings, fonts, bitmaps, menus, and command tables.
5. Cross-check static findings with MAME debugger traces.

## Handoff Notes

Current high-confidence findings:

- Work from `t4_ir_2.1.ic303` only.
- The diagnostic chord is `F+J+SPACE`.
- MAME keyboard matrix correctly reports held-key level state for that chord.
- Normal MAME reset takes the cold boot path and does not check the diagnostic
  chord.
- MAME `Home` samples the held keyboard rows before the retained-RAM wake/reset
  path, and reset entry samples them again before the ROM starts. Holding
  `F+J+SPACE` while pressing `Home` reaches the warm diagnostic state. F1
  remains a direct synthetic IRQ `FF` debugger shortcut.
- `-steadykey` is bad for this driver; do not use it.
- The LCD is modeled as RAM scanout selected by I/O port `0x00`; the firmware
  is probably not bit-banging the LCD refresh.
- `DC98:124C` renders the horizontal icon menus from table records containing
  text and bitmap far pointers.
- `DC98:2B75` is the `ROM CARD` loader for `EROMCARD.X`.
- RS-232 setup uses an 8251-like control/data interface at `0xC1`/`0xC0`; port
  `0x30` selects its baud-clock divider and also carries the Centronics strobe.
  The printer path uses data port `0x40` and status bits on `0xA0`.
- Battery warning icons are selected from `C000:4D30` and drawn via the
  `C000:4C39` path, with status helpers around `C000:0A6A`.

Useful debugger checks:

```text
d 6d06          ; inspect raw keyboard rows
wpset 6d06,10,w ; break on raw keyboard matrix writes
bpset c0095     ; warm-check branch point
bpset c00e1     ; cold path
bpset c0142     ; warm diagnostic-call path
bpset c02ee     ; IRQ FF handler
bpset c0316     ; IRQ FF diagnostic chord compare
bpset c0329     ; IRQ FF chord accepted / warm state armed
bpset c0370     ; IRQ FF hardware reset/wake request
bpset c1240     ; diagnostic gate
bpset c1252     ; diagnostic chord compare
```

The next useful tooling work is a recursive pass beyond the current
range-oriented helpers:

- load the ROM and define named segments/windows,
- seed known entry points,
- recursively follow near and far control flow,
- track known `DS/ES/SS` values where possible,
- mark uncertain indirect calls and jump tables for MAME trace validation,
- emit labels and cross-references in a machine-readable format.
