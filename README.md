# DreamWriter T400 ROM 2.1 Notes

Working target: `t4_ir_2.1.ic303`

```text
Size:   524288 bytes
SHA256: bb6a437d4c25f90eb7a0b8bc3d41e1ca2c74196aabe60954a598c66405397757
```

This repo is for mapping and tooling around the 2.1 ROM only. MAME also has a
3.1 BIOS for `drwrt400`; it is not copied here. Be careful not to mix addresses
between 2.1 and 3.1.

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
C011A  jmp far C688:000B
```

In MAME, a normal reset takes the cold path: `C0095 -> C00E1`, not `C0142`.

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

In MAME, pressing F1 triggers IRQ `FF` and reaches `C02EE`. With
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

Likely screen buffer routines:

```asm
C07E9  copy 0x1000 -> 0x94F0
C07F4  copy 0x94F0 -> 0x1000
C4C4F  copy 0x94F0 -> 0x131B, 40 rows of 6 bytes with 0x3A stride
C4C6E  copy 0x131B -> 0x94F0, same layout
```

Working model: the original hardware has LCD scanout from RAM, either true
dual-ported RAM or bus-stealing/arbitrated video RAM. The firmware probably
does not bit-bang the LC7940/LC7942 refresh.

## ROM Card / PCMCIA Strings

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

Current hypothesis: `ROM CARD` menu path tries to open or execute
`EROMCARD.X`, then validates a ROM-card ID/header. Evidence is string-based so
far; the loader path still needs mapping.

## Open Questions

- Exact call graph and segment model for startup and shell.
- Which interrupt or hardware event real machines use to trigger `C02EE`.
- Whether MAME's reset preserves or clears the retained RAM needed after `C0329`.
- Actual LCD hardware scanout implementation.
- PCMCIA card electrical mode: SRAM/attribute/ROM card behavior.
- `EROMCARD.X` loader path and executable format.
- Menu/resource table formats for original-shell cloning.

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
- MAME F1 triggers synthetic IRQ `FF`, entering `C02EE`. Holding `F+J+SPACE`
  while pressing F1 reaches `C0329`, which arms the warm diagnostic state.
- `-steadykey` is bad for this driver; do not use it.
- The LCD is modeled as RAM scanout selected by I/O port `0x00`; the firmware
  is probably not bit-banging the LCD refresh.

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

The next useful work is not more manual breakpoint poking. Start building a
small mapping tool:

- load the ROM and define named segments/windows,
- seed known entry points,
- recursively follow near and far control flow,
- track known `DS/ES/SS` values where possible,
- mark uncertain indirect calls and jump tables for MAME trace validation,
- emit labels and cross-references in a machine-readable format.
