# ROM Notes Index

These notes track the DreamWriter T400 ROM 2.1 image only.

Start here:

| File | Purpose |
| --- | --- |
| `map.md` | Address model, coarse ROM layout, and reset chain. |
| `banking.md` | MAME bank formula and confirmed ROM bank-switching routines. |
| `spell-engine.md` | Banked spell/linguistic service thunk and dispatcher notes. |
| `entry-points.md` | Confirmed code entry points and direct branch/call inventory. |
| `startup-ui.md` | Cold-start UI path, inline display scripts, boot update sequence, and first menu graphic. |
| `menu-dispatch.md` | Inline key dispatch tables and the shared application menu event loop. |
| `file-system.md` | FILE menu storage flow, DOS-like file API wrappers, and directory/DTA evidence. |
| `diagnostics.md` | Diagnostic chord, command loop, banner/help strings, and warm IRQ entry. |
| `hardware.md` | Keyboard, LCD/framebuffer, I/O ports, and low RAM state seen so far. |
| `fonts.md` | Main glyph table, candidate width table, and font variants. |
| `bitmaps.md` | Confirmed LCD bitmap icons and candidate UI/icon resources. |
| `strings.md` | String/resource landmarks for application-level mapping. |
| `open-questions.md` | Working hypotheses and next traces. |

Reusable helpers live in `../tools/rom2.py`.

The local MAME driver snapshot in `../mame/nakajies.c` is used as supporting
evidence for banking, IRQ, keyboard, LCD, RTC, and machine configuration notes.
