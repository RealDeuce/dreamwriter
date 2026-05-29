# Open Questions

1. The direct branch inventory over `0x40000..0x50000` is noisy because linear
   disassembly crosses inline data. Build a function-boundary-aware pass before
   promoting new targets.
2. Name more service IDs in the banked spell/grammar/linguistic dispatcher at
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
   versus retained-RAM wake paths. The auto power-off timeout now confirms one
   retained transition route through `C000:035D` and `out 0x70,0x01`, while IRQ
   `F8` uses a separate suspend/save route ending in `out 0xDD,0xF8`.
12. Confirm the physical power-button and power-management wiring. Current
    firmware evidence suggests IRQ `F8`, IRQ `FF`, the auto-off timeout path,
    and external reset/wake hardware are related, but MAME exposes only
    synthetic IRQ keys and no named power-management device.
13. Confirm the buzzer counter clock/waveform for ports `0x50..0x52`. Firmware
    clearly writes a 16-bit divisor and gates it with `0x52`, but the hardware
    clock and exact output shape are still unknown.
14. Confirm the RS-232 baud-clock source. Firmware behavior matches an
    8251/8251A-compatible USART at data port `0xC0` and status/control port
    `0xC1`, likely a NEC uPD71051, with baud selected by port `0x30` bits
    `0..2`; port `0x30` bit `0x08` is also pulsed during USART setup and may
    reset or load nearby baud-clock glue. Hardware evidence says RTS/CTS and
    DTR are present, DTR duplicates RTS, and there is no CD/carrier-detect
    signal.
15. Confirm the physical Centronics and PCMCIA status wiring on port `0xA0`.
    Firmware clearly maps bit `0x02` to Centronics `BUSY`, bit `0x08` to main
    battery low, bit `0x04` to CR2032 retention battery low, bit `0x80` to a
    PCMCIA card access/presence gate, bit `0x10` to the PCMCIA SRAM-card battery
    warning path, and bit `0x40` to a likely write-protect path. Firmware also
    outputs Centronics data on port `0x40`, pulses port `0x30` bit `0x20` for
    strobe, and uses IRQ `FE` as ACK-driven output. Board pins are still needed
    to confirm whether any Centronics `PE`/`SEL`/`ERROR` lines are present on
    the same register or simply unused by the firmware.
16. Confirm the external PCMCIA memory decode, ROM-card executable format, and
    card-drive mapping. MAME now has the slot/status lines wired, but no card
    memory window is exposed yet. Current trace of `DC98:2B75` finds
    `EROMCARD.X` through the same DOS-like file API
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
23. Finish decoding the non-rectangle `FF 44` forms handled at `C000:675D`.
    The simple rectangle form is now known: `+1 y`, `+3 x`, `+5 height`,
    `+7 width`, `+D mode` with `+9/+B` zero; nonzero `+9` or `+B` dispatches
    to framebuffer copy/shift-looking helpers at `C000:644D` or `C000:63C6`.
24. Decode the low-number `FF` display sub-opcodes, especially `FF 04` at
    `C000:60AF` and `FF 06` at `C000:605F`, which are distinct from the
    positioned `FF 40`/`42`/`44` drawing group.
25. Continue naming the `DC98:124C` horizontal icon menu call sites and their
    handlers. The compact 40x40 icon/label table consumer is now identified;
    remaining work is to name each wrapper, its return-key dispatch, and the
    submenu-specific handler targets.
26. Confirm the physical RTC chip and alarm wiring. MAME maps ports
    `0xD0..0xDF` to a Ricoh `RP5C01`, and the observed `0xDD..0xDF` control
    writes now match that device's mode/test/reset registers. The remaining
    hardware question is whether the RP5C01 alarm output is wired into the
    power/reset logic, an IRQ source, or both. The `0xD6` weekday/status field
    also still needs board/datasheet confirmation.
27. Ask the MAME team how `rp5c01_device` should be initialized for this driver.
    The generic MAME startup path calls `set_rtc_datetime()` for battery-backed
    RTC devices after `nvram_load()`, and `RP5C01` implements both the RTC and
    NVRAM interfaces. In practice the DreamWriter still appears to require
    manually setting the time/date. Before adding a driver-specific
    `set_current_time()` call, confirm whether this is expected `RP5C01`
    behavior, a driver configuration issue, or a core/device bug.
28. Determine how the high-ROM `CSiMON-88` monitor path is selected. The entry
    stub at `FFDF:0005` initializes the USART and dispatches into the CSiMON
    region around `0xFC000`, but no normal firmware branch to that stub and no
    ROM read/branch on port `0x20` has been found. Hardware tracing should check
    whether a fixture strap, reset-vector overlay, or external serial/boot mode
    can select this monitor.
29. Decode the low mapped engine page format at file `0x00000..0x1B413`. The
    banked linguistic wrapper maps it at CPU `0x60000..0x7B412`, followed by a
    short zero tail and then `0xFF` padding through CPU `0x7BFFF`. The direct
    consumer is now known: `3000:527C` builds slot-0 page descriptors beginning
    at `6000:0000` and immediately reads the first byte of file `0x00000`.
    What remains unknown is the page record format and which parser/thesaurus
    routines consume each page after setup. The confirmed dictionary reader at
    `3000:660F` can also address this area in principle if handed a
    signed-negative logical stream offset around `-0x1CFF0..-0x1BDE`, but the
    known seek callers use non-negative offsets so far. Large positive offsets
    around `0xE4000..0xFF412` would wrap to this area in the reader's 20-bit
    segment math, but the confirmed stream API rejects positive seeks above
    `0x14000`.
30. Decode the Thesaurus service handlers behind the traced editor path. The
    `F8` / observed Alt+8 entry now reaches `C688:E274`, draws resource `0x76`,
    and uses banked services `0x46`, `0x47`, and `0x3C + selected-number`.
    The remaining question is whether those handlers consume the slot-0 page
    data as thesaurus-specific data, grammar-specific data, or common
    linguistic engine data.
