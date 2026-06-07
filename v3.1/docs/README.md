# ROM 3.1 Notes Index

These notes track the DreamWriter T400 ROM 3.1 image. The shared hardware,
banking, and protocol docs in `../../docs/` apply to both v2.1 and v3.1.

| File | Purpose |
| --- | --- |
| [`map.md`](map.md) | Address model, banking layout, reset chain, and v2.1 comparison. |
| [`rom-regions.tsv`](rom-regions.tsv) | Machine-readable region map (initial, from boot analysis only). |
| [`entry-points.md`](entry-points.md) | Confirmed code entry points. |
| [`disassembly/boot.md`](disassembly/boot.md) | Annotated boot disassembly from reset through cold/warm startup. |
| [`disassembly/installed-vectors.md`](disassembly/installed-vectors.md) | IVT ownership and low-RAM far-call table. |
| [`disassembly/int21-dispatch.md`](disassembly/int21-dispatch.md) | INT 21h DOS-like service dispatcher and function table. |
| [`disassembly/def0-wrappers.md`](disassembly/def0-wrappers.md) | DEF0 segment thin wrappers (display, keyboard, file, date/time). |

Shared docs:

| File | Purpose |
| --- | --- |
| [`banking.md`](../../docs/banking.md) | Bank formula, reset mapping, and per-version startup tables. |
| [`hardware.md`](../../docs/hardware.md) | Keyboard, LCD, I/O ports, serial, printer, RTC, power. |
| [`diagnostics.md`](../../docs/diagnostics.md) | Diagnostic chord and command loop. |
