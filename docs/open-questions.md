# Open Questions

1. The direct branch inventory over `0x40000..0x50000` is noisy because linear
   disassembly crosses inline data. Build a function-boundary-aware pass before
   promoting new targets.
2. Name more service IDs in the banked spell/linguistic dispatcher at
   `3000:4AA6`. Confirmed so far: startup IDs `0x00`, `0x01`, `0x3C`, `0x3D`
   and diagnostic `Q/R` IDs `0x58`, `0x59`.
3. Trace the text rendering routine that consumes the `0x580B6` glyph table and
   confirm the exact role of the candidate width/metadata table at `0x58000`.
4. Confirm how the renderer selects the bold glyph run at `0x586B6`, the
   small/down-shifted glyph run at `0x58CB6`, and the small-bold run at
   `0x592B6`, the narrow run at `0x598B6`, and the narrow-bold run at
   `0x59EB6`, the narrow-small run at `0x5A4B6`, and the narrow-small-bold run
   at `0x5AAB6`.
5. Identify the consumer and code mapping for the sparse/remapped glyph sets at
   `0x5B0B6`, `0x5B6B6`, `0x5BCB6`, and `0x5C2B6`.
6. Confirm whether the dense tables after `F8DC:000D` are glyph data, boot
   graphics, or another packed resource.
7. Classify the code or packed data beginning around `0x5C98E`, immediately
   after the MAME-declared glyph stream.
8. Finish naming the remaining non-file/private services behind the `INT 21h`
   dispatcher at `C000:5098`, especially early console/device helpers and the
   `AX=4420..4427` control calls.
9. Identify the encoding and consumer for the candidate status/icon resource
   cluster around `0x55110..0x552AC`.
10. Confirm how the startup banner resource at `0x53888..0x539AA` is selected.
   The manual and `mame/nakajies.cpp` TODO indicate boot should display the
   version/copyright notice, while the current emulated path appears to show
   only `INITIALIZING` before the menu. No direct `mov si,D008/D012/D02A`
   reference has been found yet.
11. Determine whether the missing startup banner is tied to hard V20 reset
   versus the retained-RAM power/wake path through IRQ `F8`/`FF` and port
   `0x70`.
12. Confirm the physical power-button wiring. Current firmware evidence suggests
    IRQ `F8` is the suspend/save side and IRQ `FF` is the wake/reset side, but
    MAME exposes only synthetic IRQ keys and no named power input.
13. Confirm the buzzer counter clock/waveform for ports `0x50..0x52`. Firmware
    clearly writes a 16-bit divisor and gates it with `0x52`, but the hardware
    clock and exact output shape are still unknown.
14. Identify the physical RS-232 USART and baud-clock source. Firmware behavior
    strongly matches an 8251/8251A-style USART at data port `0xC0` and
    status/control port `0xC1`, with baud selected by port `0x30` bits `0..2`,
    but the board markings should confirm the exact chip and clock. Hardware
    evidence says RTS/CTS and DTR are present, DTR duplicates RTS, and there is
    no CD/carrier-detect signal.
15. Confirm the physical Centronics and PCMCIA status wiring on port `0xA0`.
    Firmware clearly maps bit `0x02` to Centronics `BUSY`, bit `0x08` to main
    battery low, bit `0x04` to CR2032 retention battery low, bit `0x80` to a
    PCMCIA card access/presence gate, bit `0x10` to the PCMCIA SRAM-card battery
    warning path, and bit `0x40` to a likely write-protect path. Firmware also
    outputs Centronics data on port `0x40`, pulses port `0x30` bit `0x20` for
    strobe, and uses IRQ `FE` as ACK-driven output. Board pins are still needed
    to confirm whether any Centronics `PE`/`SEL`/`ERROR` lines are present on
    the same register or simply unused by the firmware.
16. Confirm the ROM-card executable format and card-drive mapping. Current
    trace of `DC98:2B75` finds `EROMCARD.X` through the same DOS-like file API
    used by the FAT12-style storage layer, loads it at `0xA4F0`, validates
    header words `0xA4F0/0x1997`, and calls far `[0xA4F4]`; remaining questions
    are the full header layout, how `[0x6805]` maps to the physical PCMCIA slot,
    and whether a stub can intentionally execute more code from the mapped card
    window.
17. Decode the custom volume header and geometry used under the FAT12-style file
    implementation. The lower handlers use standard 8.3 directory entries and
    FAT12 allocation, but mount/format code checks header words `0x1997` and
    `0x0126` rather than a stock DOS boot sector/BPB.
18. Decode the `C688:0240` inline display script opcode table at `C688:38A4`
    enough to split script bytes from code automatically.
19. Trace references to the main UI string cluster at `0x53800..0x58000` backward
    to identify menu handlers.
20. Split confirmed code from inline strings/data around `C000:1200..16FF`.
21. Split confirmed code from data in the `C688:0000..01FF` far-call area.
22. Name the low RAM variables in `6D00..70FF` as their roles become stable.
23. Decode the `FF 44` resource records handled at `C000:675D`; current evidence
    suggests positioned region/line/fill drawing rather than source-backed
    bitmap blits.
24. Decode the low-number `FF` display sub-opcodes, especially `FF 04` at
    `C000:60AF` and `FF 06` at `C000:605F`, which are distinct from the
    positioned `FF 40`/`42`/`44` drawing group.
25. Continue naming the `DC98:124C` horizontal icon menu call sites and their
    handlers. The compact 40x40 icon/label table consumer is now identified;
    remaining work is to name each wrapper, its return-key dispatch, and the
    submenu-specific handler targets.
