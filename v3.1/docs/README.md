# ROM 3.1 Notes Index

These notes track the DreamWriter T400 ROM 3.1 image. The shared hardware,
banking, and protocol docs in `../../docs/` apply to both v2.1 and v3.1.

## Version-Specific Docs

| File | Purpose |
| --- | --- |
| [`map.md`](map.md) | Address model, banking layout, code segment map, reset chain, and v2.1 comparison. |
| [`rom-regions.tsv`](rom-regions.tsv) | Machine-readable region map. |
| [`entry-points.md`](entry-points.md) | Confirmed code entry points. |

## Disassembly

Generated from a full recursive trace (4168 blocks, 45996 instructions
across 7 segments). Raw trace at [`disassembly/trace-full.txt`](disassembly/trace-full.txt).
Call graph at [`disassembly/call-graph.dot`](disassembly/call-graph.dot).

### C000 — Low-Level Firmware

| File | Scope |
| --- | --- |
| [`disassembly/boot.md`](disassembly/boot.md) | Boot spine: reset through cold/warm startup to application entry. References all other slices. |
| [`disassembly/installed-vectors.md`](disassembly/installed-vectors.md) | IVT installer, explicit vector assignments, low-RAM far-call table. |
| [`disassembly/power-irq.md`](disassembly/power-irq.md) | IRQ FF warm/power handler: chord check, diagnostic mode entry, context save + halt. |
| [`disassembly/device-irq.md`](disassembly/device-irq.md) | IRQ F9 (timer), FA (kbd reset), FC (serial rx), FD (serial tx), FE (parallel output). |
| [`disassembly/keyboard-irq.md`](disassembly/keyboard-irq.md) | IRQ FB keyboard row scan, matrix at [1306..130F]. |
| [`disassembly/keyboard-services.md`](disassembly/keyboard-services.md) | Keyboard processor: key change detection, translation tables, repeat handling. |
| [`disassembly/nmi-context.md`](disassembly/nmi-context.md) | NMI handler (INT 02h), context checksum, context verify + register restore. |
| [`disassembly/sound-lowlevel.md`](disassembly/sound-lowlevel.md) | Tone on/off (ports 50/51/52), tone+delay, multi-note driver, boot tone callers. |
| [`disassembly/rtc-alarm-power.md`](disassembly/rtc-alarm-power.md) | RTC register read/write (ports D0..DC), RTC state checks, power-down path. |
| [`disassembly/startup-display.md`](disassembly/startup-display.md) | RTC gate, copyright/product banner rendering from C772 display scripts. |
| [`disassembly/display-stream.md`](disassembly/display-stream.md) | Display script renderer (C000:6557) and far wrapper (C000:3F35, 136 callers). |
| [`disassembly/diagnostic-keyboard-check.md`](disassembly/diagnostic-keyboard-check.md) | F+J+SPACE keyboard chord check, diagnostic entry gate. |
| [`disassembly/diagnostic-monitor.md`](disassembly/diagnostic-monitor.md) | Terminal command monitor (banked thunk slot 7). |
| [`disassembly/subsystem-init.md`](disassembly/subsystem-init.md) | Bank mirrors, RAM clear, file/drive/storage init, state validation, full 2E72 init chain. |
| [`disassembly/int21-dispatch.md`](disassembly/int21-dispatch.md) | INT 21h DOS-like service dispatcher and function table. |
| [`disassembly/int21-file-io.md`](disassembly/int21-file-io.md) | INT 21h file operation handlers: create, open, close, read, write, seek, delete, find, rename. |
| [`disassembly/c000-serial-io.md`](disassembly/c000-serial-io.md) | Serial I/O and DreamLink: serial buffers, endpoint transport. |
| [`disassembly/c000-editor-utility.md`](disassembly/c000-editor-utility.md) | Editor/spell utility (C000:929B..9D63): text buffer management, cursor, formatting. |

### C772 — Application Runtime

| File | Scope |
| --- | --- |
| [`disassembly/app-entry.md`](disassembly/app-entry.md) | C772:0004 (cold) and C772:0008 (warm) entry points, cold init chain, storage endpoint cycling. |
| [`disassembly/menu-interpreter.md`](disassembly/menu-interpreter.md) | Menu scripting engine: bytecode interpreter loop, dispatch table (96 opcodes), handler classification. |
| [`disassembly/c772-native-helpers.md`](disassembly/c772-native-helpers.md) | Native helpers: state management (45A7/4556), text buffer ops (3BB6-3C2D), service dispatcher (8415), DEF0 callbacks (E800-E946). |

### DEF0 — Service/Wrapper Layer

| File | Scope |
| --- | --- |
| [`disassembly/def0-wrappers.md`](disassembly/def0-wrappers.md) | DEF0 segment thin wrappers (display, keyboard, file, date/time). |
| [`disassembly/def0-app-init.md`](disassembly/def0-app-init.md) | DEF0:5C07 (cold init), DEF0:5B03 (session init), DEF0:57EF (entry #39), session management. |
| [`disassembly/def0-display-services.md`](disassembly/def0-display-services.md) | Far-call table display entries #0-#15, display script builder API. |
| [`disassembly/def0-display-rendering.md`](disassembly/def0-display-rendering.md) | Display rendering pipeline (DEF0:01BA..0D80), glyph/bitmap data references. |
| [`disassembly/def0-display-subsystem.md`](disassembly/def0-display-subsystem.md) | Display configuration (DEF0:A000..BFFF), LCD geometry, display page management. |
| [`disassembly/def0-cursor-state.md`](disassembly/def0-cursor-state.md) | Cursor state, wrapper inner routines (CE03/CE36/CE6A/CE92), date/time, CFDE display refresh. |
| [`disassembly/def0-menu-display.md`](disassembly/def0-menu-display.md) | Menu display system (DEF0:2000..29DB), interactive menus, C772 callbacks. |
| [`disassembly/def0-file-dialogs.md`](disassembly/def0-file-dialogs.md) | File management UI (DEF0:29DC..4AA9), directory listing, file open/save/delete dialogs. |
| [`disassembly/def0-file-services.md`](disassembly/def0-file-services.md) | Far-call table file entries #16-#39, DEF0:DFD5 file service core. |
| [`disassembly/def0-keyboard-subsystem.md`](disassembly/def0-keyboard-subsystem.md) | Keyboard/input processing (DEF0:6278..6FFF), input fields, character handling. |
| [`disassembly/def0-storage-subsystem.md`](disassembly/def0-storage-subsystem.md) | Internal storage management (DEF0:7000..9FFF), file handle table, document format. |

### Dispatch and Thunks

| File | Scope |
| --- | --- |
| [`disassembly/banked-thunk-dispatch.md`](disassembly/banked-thunk-dispatch.md) | Banked call mechanism: thunk A/B tables (C000:0021/0025), 12 slots each. |

### Window 7 and Banked Segments

| File | Scope |
| --- | --- |
| [`disassembly/ee17-utility.md`](disassembly/ee17-utility.md) | EE17 utility library: state block management, display page init (212 blocks). |
| [`disassembly/ef8a-utility.md`](disassembly/ef8a-utility.md) | EF8A utility routines (31 blocks). Called from EE17 via segment alias. |
| [`disassembly/ed1b-ad00-banked.md`](disassembly/ed1b-ad00-banked.md) | ED1B bank-switch wrappers (12 blocks) and AD00 ROM CARD subsystem (458 blocks). |

## Shared Docs

| File | Purpose |
| --- | --- |
| [`banking.md`](../../docs/banking.md) | Bank formula, reset mapping, and per-version startup tables. |
| [`hardware.md`](../../docs/hardware.md) | Keyboard, LCD, I/O ports, serial, printer, RTC, power. |
| [`diagnostics.md`](../../docs/diagnostics.md) | Diagnostic chord and command loop. |
