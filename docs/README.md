# ROM Notes Index

These notes track the DreamWriter T400 ROM 2.1 image only.

Start here:

| File | Purpose |
| --- | --- |
| [`map.md`](map.md) | Address model, coarse ROM layout, and reset chain. |
| [`rom-regions.tsv`](rom-regions.tsv) | Machine-readable first-pass code/data/resource region map. |
| [`banking.md`](banking.md) | MAME bank formula and confirmed ROM bank-switching routines. |
| [`spell-engine.md`](spell-engine.md) | Banked spell/grammar/linguistic service thunk and dispatcher notes. |
| [`entry-points.md`](entry-points.md) | Confirmed code entry points and direct branch/call inventory. |
| [`startup-ui.md`](startup-ui.md) | Cold-start UI path, inline display scripts, boot update sequence, and first menu graphic. |
| [`menu-dispatch.md`](menu-dispatch.md) | Inline key dispatch tables and the shared application menu event loop. |
| [`file-system.md`](file-system.md) | FILE menu storage flow, DOS-like file API wrappers, and directory/DTA evidence. |
| [`wp-editor-heap.md`](wp-editor-heap.md) | Word-processor live document heap, block allocator, and cross-application use evidence. |
| [`diagnostics.md`](diagnostics.md) | Diagnostic chord, command loop, banner/help strings, and warm IRQ entry. |
| [`hardware.md`](hardware.md) | Keyboard, LCD/framebuffer, I/O ports, and low RAM state seen so far. |
| [`hardware-confirmation.md`](hardware-confirmation.md) | Board-inspection checklist for confirming clocks, devices, ports, and status wiring. |
| [`fonts.md`](fonts.md) | Main glyph table, candidate width table, and font variants. |
| [`bitmaps.md`](bitmaps.md) | Confirmed LCD bitmap icons and candidate UI/icon resources. |
| [`strings.md`](strings.md) | String/resource landmarks for application-level mapping. |
| [`open-questions.md`](open-questions.md) | Working hypotheses and next traces. |
| [`reference/csimon.pdf`](reference/csimon.pdf) | CSi-Mon User's Guide v5.0, useful background for the high-ROM `CSiMON-88` monitor code. |

Reusable helpers live in `tools/rom2.py` at the repository root; see
[`tools/README.md`](../tools/README.md) for the command reference.

The local MAME driver snapshot in `mame/nakajies.cpp` is used as supporting
evidence for banking, IRQ, keyboard, LCD, RTC, and machine configuration notes.
