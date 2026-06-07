# ROM Notes Index

These notes primarily track the DreamWriter T400 ROM 2.1 image. Unless a page
explicitly says it is comparative, `t4_ir_2.1.ic303` and the helpers in
`../../tools/` are the source of truth. A small number of comparative notes use
other DreamWriter ROMs only when they clarify T400 behavior or possible
`EROMCARD.X` experiments.

Start here:

| File | Purpose |
| --- | --- |
| [`map.md`](map.md) | Address model, coarse ROM layout, and reset chain. |
| [`rom-regions.tsv`](rom-regions.tsv) | Machine-readable first-pass code/data/resource region map. |
| [`banking.md`](../../docs/banking.md) | MAME bank formula and confirmed ROM bank-switching routines. |
| [`spell-engine.md`](spell-engine.md) | Banked spell/grammar/linguistic service thunk and dispatcher notes. |
| [`entry-points.md`](entry-points.md) | Confirmed code entry points and direct branch/call inventory. |
| [`disassembly/`](disassembly/) | Hand-annotated reachable-code disassembly, starting with reset and boot. |
| [`startup-ui.md`](startup-ui.md) | Cold-start UI path, inline display scripts, boot update sequence, and first menu graphic. |
| [`menu-dispatch.md`](menu-dispatch.md) | Inline key dispatch tables and the shared application menu event loop. |
| [`file-system.md`](file-system.md) | FILE menu storage flow, DOS-like file API wrappers, and directory/DTA evidence. |
| [`running-rom-card-binaries.md`](../../docs/running-rom-card-binaries.md) | Practical workflow for running arbitrary `EROMCARD.X` binaries through OTHERS -> ROM CARD. |
| [`basic-eromcard.md`](../../docs/basic-eromcard.md) | Comparative feasibility notes for wrapping the DreamWriter 325 BASIC interpreter as T400 `EROMCARD.X`; depends on a non-T400 source ROM. |
| [`dreamlink-protocol.md`](../../docs/dreamlink-protocol.md) | DreamLink RS-232 file-transfer protocol, command frames, listings, and data stream framing. |
| [`wp-editor-heap.md`](wp-editor-heap.md) | Word-processor live document heap, block allocator, and cross-application use evidence. |
| [`diagnostics.md`](../../docs/diagnostics.md) | Diagnostic chord, command loop, banner/help strings, and warm IRQ entry. |
| [`hardware.md`](../../docs/hardware.md) | Keyboard, LCD/framebuffer, I/O ports, serial, printer, PCMCIA, sound, RTC, power, and low RAM state. |
| [`hardware-confirmation.md`](../../docs/hardware-confirmation.md) | Board-inspection checklist for confirming clocks, devices, ports, and status wiring. |
| [`fonts.md`](fonts.md) | Main glyph table, candidate width table, and font variants. |
| [`bitmaps.md`](bitmaps.md) | Confirmed LCD bitmap icons and candidate UI/icon resources. |
| [`strings.md`](strings.md) | String/resource landmarks for application-level mapping. |
| [`open-questions.md`](open-questions.md) | Unresolved questions after the current ROM/tooling audit. |
| [`reference/csimon.pdf`](../../docs/reference/csimon.pdf) | CSi-Mon User's Guide v5.0, useful background for the high-ROM `CSiMON-88` monitor code. |
| [`reference/dreamlink-manual.pdf`](../../docs/reference/dreamlink-manual.pdf) | DreamLink PC software manual; documents FILE -> STORE/RECALL transfer flow, host-side file format selection, and print-through mode. |
| [`reference/dreamwriter-t400-manual.pdf`](../../docs/reference/dreamwriter-t400-manual.pdf) | DreamWriter T400 user manual; broad user-facing reference, currently missing pages 10 and 11 in the source copy. |
| [`reference/dreamwriter-t400-manual.txt`](../../docs/reference/dreamwriter-t400-manual.txt) | Layout-preserving OCR text extracted from the two-up T400 manual scan; useful for search and command names, but not authoritative for exact page geometry. |

Reusable helpers live in `tools/rom2.py` at the repository root; see
[`tools/README.md`](../../tools/README.md) for the command reference.

The first-pass machine-readable ROM split is [`rom-regions.tsv`](rom-regions.tsv).
Topic notes should agree with that map or explicitly mark a claim as tentative
or comparative.

The local MAME driver snapshot in `mame/nakajies.cpp` is used as supporting
evidence for banking, IRQ, keyboard, LCD, RTC, and machine configuration notes.
