# Annotated Disassembly

This directory is the hand-annotated reachable-code disassembly for the
DreamWriter T400 v2.1 ROM image (`t4_ir_2.1.ic303`).

The goal is not a linear dump of every byte, and these files are not NASM input.
Each file starts from a confirmed entry point, follows reachable code
depth-first, and records indirect roots when the running code installs them.
Generated disassembly is treated as scaffolding; labels and comments here should
preserve the reasoning that makes the code understandable.

Generated reference indexes:

- [`symbol-index.html`](symbol-index.html) is a sortable address/name index for
  named labels in this directory.
- [`asset-index.md`](asset-index.md) lists documented PNG assets and descriptor
  dimensions.
- [`string-resource-index.md`](string-resource-index.md) lists documented
  string resources and final formatted text references.
- [`ram-ledger.md`](ram-ledger.md) and [`io-port-ledger.md`](io-port-ledger.md)
  summarize RAM and I/O-port references found in the notes.
- [`transfer-targets.md`](transfer-targets.md) audits direct call/jump targets;
  [`call-graph.dot`](call-graph.dot) exports the same transfer set as Graphviz.

## Conventions

- Addresses are written as the CPU address seen by the V20, with file offsets
  in comments when that prevents ambiguity.
- Instruction bytes are kept for short boot-critical listings so the annotation
  can be checked against `ndisasm`.
- For V20-only opcodes, unsupported NASM mnemonics, or disassembler-uncertain
  byte runs, preserve the raw bytes and annotate the effect instead of forcing
  the listing into assemblable syntax.
- `...` marks intentionally omitted instructions or data inside a described
  range. Do not infer contiguity across an ellipsis.
- Labels beginning with `root_` are externally reachable roots.
- Labels beginning with `seed_` are roots installed by code already reached,
  such as interrupt vectors, `INT 21h`, or low-RAM far-call table entries.
- `TODO-xref` marks a branch target that is reachable but not yet expanded in
  this directory.

## Current Slices

| File | Coverage |
| --- | --- |
| [`boot.md`](boot.md) | Reset vector handoff, early `C000` startup, cold/warm branch skeleton, bank-default helpers, and interrupt/vector installation roots. |
| [`installed-vectors.md`](installed-vectors.md) | Interrupt-vector ownership installed by `C000:0ED6`, default `iret` target, IRQ/INT 21h/INT 1 stubs, and low-RAM ABI table decode. |
| [`int21-dispatch.md`](int21-dispatch.md) | `INT 21h` dispatcher at `C000:5098`, service translation tables, shallow wrappers, date/time services, and private IOCTL subdispatcher. |
| [`int21-filesystem-front.md`](int21-filesystem-front.md) | `INT 21h` drive/DTA/free-space/create/open/find/delete/rename/metadata front-end paths. |
| [`int21-file-io.md`](int21-file-io.md) | `INT 21h` read/write/seek internals, local FAT12 chain handling, and DreamLink read/write branch boundaries. |
| [`int21-directory-core.md`](int21-directory-core.md) | Shared directory scan, filename parser, FAT12 helper, volume-header, and open-slot boundaries. |
| [`int21-handle-core.md`](int21-handle-core.md) | Handle-to-endpoint resolution, open-file state hydration, and directory-entry writeback core. |
| [`int21-format.md`](int21-format.md) | Private `INT 21h AH=FF/BL=A5` formatter for built-in RAM, PCMCIA SRAM card, and DreamLink initialize. |
| [`int21-endpoints.md`](int21-endpoints.md) | Private `AH=44` endpoint probe/status helpers, file date/time wrapper, and DreamLink finish helper. |
| [`dreamlink-file-core.md`](dreamlink-file-core.md) | DreamLink command framing, probe/listing, and file create/open/delete/read/write/close/rename/format senders. |
| [`dreamlink-response-details.md`](dreamlink-response-details.md) | DreamLink response scratch clearing, strict startup handshake, payload dispatch, and compact listing expansion. |
| [`int21-time-pack.md`](int21-time-pack.md) | FAT-style time/date packing for directory-entry writeback and DreamLink create metadata. |
| [`diagnostic-int1.md`](diagnostic-int1.md) | Installed `INT 1` diagnostic/single-step hook at `C000:157D`, including low-RAM watch state and `F8h` chaining. |
| [`sound-lowlevel.md`](sound-lowlevel.md) | Low-level tone gate helpers used by `INT 1` and buzzer paths. |
| [`display-resource-format.md`](display-resource-format.md) | Local descriptor notation for `C000:5AD6` string/display resources and fixed horizontal icon menu label tables. |
| [`display-stream.md`](display-stream.md) | Low-RAM display/poll far wrappers and `C000:5AD6` display-resource parser entry/state. |
| [`display-wrappers.md`](display-wrappers.md) | `DC98` text/control display wrappers around `C000:67AD` without entering menu renderers. |
| [`power-irq.md`](power-irq.md) | Installed `F8h` save/suspend and `FFh` warm/power-management roots, retained context checksum, RTC alarm preparation boundary, and terminal port `0x70` handoff. |
| [`keyboard-irq.md`](keyboard-irq.md) | Installed `F9h` timer/wake acknowledge, `FAh` keyboard scan-cycle reset, and `FBh` row-scan ISR through the `C000:5645` row-processor boundary. |
| [`keyboard-services.md`](keyboard-services.md) | Keyboard row processor, event queue, blocking/nonblocking `INT 21h` key services, and translation boundary. |
| [`keyboard-translation.md`](keyboard-translation.md) | Keyboard event translation paths, class selectors, ROM keymaps, RAM keymap copies, and direct table. |
| [`timer-wake.md`](timer-wake.md) | Installed `F9h` timer/wake acknowledge plus timer latch arm/disarm helpers. |
| [`device-irq.md`](device-irq.md) | Installed `FCh` RS-232 receive ISR, `FDh` serial transmit-ready acknowledge, and `FEh` Centronics ACK-driven byte feeder. |
| [`serial-services.md`](serial-services.md) | USART setup, `INT 21h` serial output, receive queue insert/drain, and XON/XOFF state. |
| [`printer-device.md`](printer-device.md) | Centronics stream starter and direct byte writer used by `INT 21h AH=05` and IRQ `FEh`. |
| [`idle-power.md`](idle-power.md) | Foreground idle loops, retained resume target setup, and rendered 48x40 battery-warning icon assets. |
| [`rtc-alarm-power.md`](rtc-alarm-power.md) | RTC alarm wake discriminator, framebuffer save/restore, fallback re-arm, and warm-start alarm wrapper. |
| [`rtc-programming.md`](rtc-programming.md) | RTC alarm register programming, minute-plus-one fallback, current-time snapshot, and alarm compare helpers. |
| [`serial-power-cleanup.md`](serial-power-cleanup.md) | RS-232/printer/power setup validators and retained-power serial cleanup. |
| [`battery-status.md`](battery-status.md) | Port `0xA0` main/retention/card battery, card-present, and card write-protect helpers. |
| [`storage-geometry.md`](storage-geometry.md) | PCMCIA SRAM capacity probe, local sector geometry helper, and card write-protect boundary. |
| [`storage-window-mapping.md`](storage-window-mapping.md) | Bank select helper, logical sector to CPU-window mapping, and format-time FAT/root clear helpers. |
| [`format-status-output.md`](format-status-output.md) | Shared format/transfer progress display resource and dynamic five-byte status field. |
| [`diagnostics-ui.md`](diagnostics-ui.md) | Diagnostic chord/UI boundary that seeds the installed `INT 1` watch state. |
| [`diagnostic-monitor.md`](diagnostic-monitor.md) | Built-in diagnostic command parser, memory/I/O dump and set commands, single-step state setup, keyboard/help helpers, and local output routines. |
| [`diagnostic-spell-services.md`](diagnostic-spell-services.md) | Diagnostic `Q/R` clear/reset spell service bodies behind banked service IDs `0x58` and `0x59`. |
| [`diagnostic-keyboard-check.md`](diagnostic-keyboard-check.md) | Diagnostic `K` command keyboard-coverage loop, local key-cell drawing helpers, key table format, and rendered keyboard bitmap assets. |
| [`low-ram-abi.md`](low-ram-abi.md) | Far-pointer table copied from `C000:0F94` to `0000:0200`, including display, keyboard, and file wrapper entries. |
| [`low-ram-abi-unknowns.md`](low-ram-abi-unknowns.md) | Remaining low-RAM ABI UI widgets: wrapped text, editable fields, prompt selector, and callback setter. |
| [`dc98-file-wrappers.md`](dc98-file-wrappers.md) | `DC98` DOS-like file wrappers, error mapper, and shallow higher-level file helpers. |
| [`menu-entry.md`](menu-entry.md) | `C688` cold/warm application entry, first two-button menu resource copy, embedded startup menu images, first input dispatch, and shared menu/event loop entry. |
| [`app-menu-event-loop.md`](app-menu-event-loop.md) | Shared `C688:EC9F` application menu/event loop, inline dispatch primitive, top-menu return paths, idle state table, and app-handler boundaries. |
| [`early-app-helper.md`](early-app-helper.md) | App-loop event `0xF5` forced diagnostic-monitor entry through `C688:01B0` and `C000:123C`. |
| [`top-icon-menus.md`](top-icon-menus.md) | Word-processor and organizer top icon menu wrappers, ROM icon tables, rendered PNGs beside each icon entry, and shared renderer boundary. |
| [`horizontal-icon-renderer.md`](horizontal-icon-renderer.md) | Shared `DC98:124C` horizontal icon table renderer, `DC98:1198` key loop, and selection marker helper. |
| [`wp-edit-text.md`](wp-edit-text.md) | WP EDIT TEXT entry semantics, shared editor loop boundary, redraw/update sequence, active-state snapshot, and manual-named key families. |
| [`wp-editor-viewport.md`](wp-editor-viewport.md) | WP editor viewport/window-state clamp, dirty redraw handoff, and low-RAM state fields behind `C688:44DB`. |
| [`wp-editor-redraw.md`](wp-editor-redraw.md) | WP editor redraw span/delta state emitter at `C688:18AC`, saved-state restore path, and small scratch-record helpers. |
| [`wp-submenus.md`](wp-submenus.md) | Word-processor FILE, PRINTER, COMMUNICATE, and OTHERS submenu wrappers, icon tables, and rendered PNG assets. |
| [`wp-clear-text.md`](wp-clear-text.md) | WP top-menu CLEAR TEXT confirmation loop, editor-clear redraw path, and decoded prompt/confirmation resources. |
| [`wp-file-handlers.md`](wp-file-handlers.md) | WP FILE submenu handlers, shared picker/name-entry UI layer, decoded prompt resources, and COPY direction/list boundary. |
| [`wp-communicate-handlers.md`](wp-communicate-handlers.md) | COMMUNICATE send/receive/terminal handlers, decoded prompt resources, and classic 128-byte checksum XMODEM paths. |
| [`document-picker-ui.md`](document-picker-ui.md) | Shared application-loop document/list re-entry roots, `LIST OF DOC.` template continuation, and SEARCH/REPLACE prompt variants. |
| [`setup-screens.md`](setup-screens.md) | Word-processor setup/settings editors for RS-232, printer, SYSTEM, and PREFERENCES, including backing state and decoded option strings. |
| [`wp-others-handlers.md`](wp-others-handlers.md) | OTHERS -> T I M E entry/Typin' Time dispatcher boundary and complete ROM CARD `EROMCARD.X` loader, including failure strings and payload header. |
| [`typin-time.md`](typin-time.md) | Typin' Time app state machine, test-selection grid, live supplied/free-entry typing flows, scoreboard/options/error review, and text/lesson resource formats. |
| [`typin-time-lessons.md`](typin-time-lessons.md) | Extracted Typin' Time lesson banks in menu order, with each label, cell pointer, line pointer, and final practice text line. |
| [`organizer-calculator.md`](organizer-calculator.md) | Organizer CALCULATOR app, fixed-point decimal arithmetic core, square-root path, rendered calculator glyph PNGs, and error strings. |
| [`organizer-calendar.md`](organizer-calendar.md) | Organizer CALENDAR app, two-month grid renderer, year/display-form prompts, explicit menu strings, and rendered small digit glyph asset. |
| [`organizer-scheduler.md`](organizer-scheduler.md) | Organizer SCHEDULER entry, foreground WEEKLY/CONTENT UI, `SCHEDULE.ODB` record format, edit/new/delete/alarm handlers, and scheduler alarm cache builder. |
| [`organizer-world-clock.md`](organizer-world-clock.md) | Organizer WORLD CLOCK app, city table picker, map/time bitmap renderers, time/date editor, display-form selector, and daily-alarm UI. |
| [`organizer-address-book.md`](organizer-address-book.md) | Organizer ADDRESS BOOK app, `ADDRESS.ODB` parser/serializer, sorted index/cache maintenance, two-view UI, and search/edit/delete handlers. |
| [`organizer-alarm.md`](organizer-alarm.md) | Shared Organizer scheduler/world-clock next-alarm selector, selected-alarm display loop, and low-RAM RTC alarm buffer handoff. |

## Root Expansion Queue

The boot slice has already exposed these next roots:

| Root | Source | Next slice |
| --- | --- | --- |
| Application printer formatters | Reached from `printer-device.md`. | User-facing print formatting before `INT 21h AH=05`. |
| `C688:EB5E` | Reached from `wp-submenus.md`. | WP PRINTER -> PRINT OUT application handler. |
| `C688:1A85`, `C688:1B12`, `C688:1B41`, `C688:1B6F`, `C688:1D75`, `C688:6B8C`, `C688:6BAA` | Reached from `wp-editor-viewport.md` and `wp-editor-redraw.md`. | Lower editor redraw/input helpers behind the viewport clamp and span emitter. |
| `C688:1DFD`, `C688:1FD3`, `C688:208D`, `C688:39B5`, `C688:39BE`, `C688:61DB` | Reached from `wp-editor-redraw.md`. | Deeper redraw/rendering exits and utility calls. |
| `C688:ED1F`, `C688:E274`, `C688:D8AF` | Reached from `app-menu-event-loop.md`. | Word-processor linguistic and document flows. |
| `C688:AD5C`, `C688:ED15` | Reached from `app-menu-event-loop.md`. | Print/merge/address app-loop handlers. |
