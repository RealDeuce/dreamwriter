# ROM 3.1 Notes Index

These notes track the DreamWriter T400 ROM 3.1 image. The shared hardware,
banking, and protocol docs in `../../docs/` apply to both v2.1 and v3.1.

## Version-Specific Docs

| File | Purpose |
| --- | --- |
| [`map.md`](map.md) | Address model, banking layout, reset chain, and v2.1 comparison. |
| [`rom-regions.tsv`](rom-regions.tsv) | Machine-readable region map. |
| [`entry-points.md`](entry-points.md) | Confirmed code entry points. |

## Disassembly

| File | Scope |
| --- | --- |
| [`disassembly/boot.md`](disassembly/boot.md) | Boot spine: reset through cold/warm startup to application entry. References all other slices. |
| [`disassembly/installed-vectors.md`](disassembly/installed-vectors.md) | IVT installer, explicit vector assignments, low-RAM far-call table. |
| [`disassembly/sound-lowlevel.md`](disassembly/sound-lowlevel.md) | Tone on/off (ports 50/51/52), tone+delay, multi-note driver, boot tone callers. |
| [`disassembly/rtc-alarm-power.md`](disassembly/rtc-alarm-power.md) | RTC register read/write (ports D0..DC), RTC state checks, power-down path. |
| [`disassembly/nmi-context.md`](disassembly/nmi-context.md) | NMI handler (INT 02h), context checksum, context verify + register restore. |
| [`disassembly/startup-display.md`](disassembly/startup-display.md) | RTC gate, copyright/product banner rendering from C772 display scripts. |
| [`disassembly/diagnostic-keyboard-check.md`](disassembly/diagnostic-keyboard-check.md) | F+J+SPACE keyboard chord check, diagnostic entry gate. |
| [`disassembly/diagnostic-monitor.md`](disassembly/diagnostic-monitor.md) | Terminal command monitor (banked thunk slot 7). |
| [`disassembly/keyboard-irq.md`](disassembly/keyboard-irq.md) | IRQ FB keyboard row scan, matrix at [1306..130F]. |
| [`disassembly/subsystem-init.md`](disassembly/subsystem-init.md) | Bank mirrors, RAM clear, file/drive/storage init, state validation, init chain. |
| [`disassembly/int21-dispatch.md`](disassembly/int21-dispatch.md) | INT 21h DOS-like service dispatcher and function table. |
| [`disassembly/def0-wrappers.md`](disassembly/def0-wrappers.md) | DEF0 segment thin wrappers (display, keyboard, file, date/time). |

## Shared Docs

| File | Purpose |
| --- | --- |
| [`banking.md`](../../docs/banking.md) | Bank formula, reset mapping, and per-version startup tables. |
| [`hardware.md`](../../docs/hardware.md) | Keyboard, LCD, I/O ports, serial, printer, RTC, power. |
| [`diagnostics.md`](../../docs/diagnostics.md) | Diagnostic chord and command loop. |
