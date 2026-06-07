# ROM 3.1 Notes Index

These notes track the DreamWriter T400 ROM 3.1 image. The shared hardware,
banking, and protocol docs in `../../docs/` apply to both v2.1 and v3.1.

| File | Purpose |
| --- | --- |
| [`map.md`](map.md) | Address model, banking layout, reset chain, and v2.1 comparison. |
| [`rom-regions.tsv`](rom-regions.tsv) | Machine-readable region map (initial, from boot analysis only). |
| [`entry-points.md`](entry-points.md) | Confirmed code entry points from the boot path. |
| [`disassembly/boot.md`](disassembly/boot.md) | Annotated boot disassembly from reset through cold/warm startup. |

Shared docs:

| File | Purpose |
| --- | --- |
| [`banking.md`](../../docs/banking.md) | Bank formula, reset mapping, and per-version startup tables. |
| [`hardware.md`](../../docs/hardware.md) | Keyboard, LCD, I/O ports, serial, printer, RTC, power. |
| [`diagnostics.md`](../../docs/diagnostics.md) | Diagnostic chord and command loop. |
