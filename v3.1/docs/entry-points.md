# Confirmed Entry Points

Every label is derived from reading the actual instructions at each
address. File offsets use the banking model in [`map.md`](map.md).
Segment file bases: C000=`0xC0000`, C772=`0xC7720`, DEF0=`0xDEF00`,
EE17=`0xEE170`, EF8A=`0xEF8A0`, ED1B=`0xED1B0`, AD00=`0xAD000`.

## 1. Reset and Boot (C000:0000-02FF)

| Address | File offset | Description |
| --- | ---: | --- |
| `FFFF:0000` | `0xFFFF0` | CPU reset vector; `CLI; JMP FAR F6E3:0000`. |
| `F6E3:0000` | `0xF6E30` | Reset trampoline; sets ports `0x16=0x01, 0x17=0x00`; `JMP FAR C000:0000`. |
| `C000:0000` | `0xC0000` | `JMP SHORT C000:0029`. |
| `C000:0029` | `0xC0029` | boot_entry: sets bank ports 10/16/17, zeroes SS/DS/ES, writes hardware I/O ports 90/20/00/DE/DD/40, sets SP=6F00, calls IVT installer. |
| `C000:0065` | `0xC0065` | Compares 5 bytes at `[1000..1004]` against `CS:7799` ("218") + `CS:64CF`. |
| `C000:0085` | `0xC0085` | Cold-start path: stamps signature bytes, seeds bank mirrors, clears RAM, inits storage/drives/subsystems, calls `DEF0:5C07`. |
| `C000:0096` | `0xC0096` | Delays, seeds bank mirrors, clears RAM, inits storage/drives/subsystems, sets warm-retry flag and `[146F]=0x1995`. |
| `C000:00EC` | `0xC00EC` | Warm path: restores bank ports 11-15 from `[147B..147F]`, calls `C000:2E2D` validation. |
| `C000:0107` | `0xC0107` | Clears volatile state bytes, sets `[1109]=1`, calls state validation and enters decision tree. |
| `C000:0148` | `0xC0148` | Tests `[1467]` against `0x0000, 0x320D, 0x30E7, 0x316D`; unrecognized -> `C000:025E`. |
| `C000:016C` | `0xC016C` | Compares `[1469]` with CS; mismatch -> `C000:018A`. Tests `[146F]`. |
| `C000:018A` | `0xC018A` | Renders "INITIALIZING" (`C772:EDB0`), clears RAM, reinits all subsystems, calls `DEF0:5B03`, `JMP FAR C772:0004`. |
| `C000:01DF` | `0xC01DF` | Three delays, seeds bank mirrors, clears framebuffer, checks keyboard chord (`C000:0AA0`), enters app via `C772:0008`. |
| `C000:0220` | `0xC0220` | Clears keyboard state, does RTC check + display init (`C000:0987`), checks keyboard chord, verifies context checksum, resumes saved far pointer. |
| `C000:0242` | `0xC0242` | Context resume: restores saved far return pointer from `[1453..1456]`. |
| `C000:025E` | `0xC025E` | Alternate resume path when `[1467]` not recognized. |
| `C000:027E` | `0xC027E` | Resume retry: calls `C000:02A3` checksum verify, retries or falls to reinit. |
| `C000:02A3` | `0xC02A3` | Context checksum verify: recomputes `[1453..1470]` sum, compares `[1471]`. Returns CF=0 on match. |
| `C000:02BE` | `0xC02BE` | Restores bank ports 11-15 from `[147B..147F]`, restores BX/CX/DX/SI/DI/ES/BP from `[1455..145F]`. |

## 2. Power/NMI/Context (C000:0300-05FF)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:0303` | `0xC0303` | Saves framebuffer (`C000:0969`), calls `DEF0:5B03`, restores framebuffer (`C000:0974`). |
| `C000:0327` | `0xC0327` | Writes `0F/1F/1E/1D/1C` to `[147B..147F]` (bank port mirror defaults). |
| `C000:033B` | `0xC033B` | Storage endpoint dispatch: dispatches on BL/DL for drive selection. |
| `C000:03A5` | `0xC03A5` | Clears 0x400 bytes at `[AAFB..]`. |
| `C000:03BB` | `0xC03BB` | Clears `[1006..CEEE]` to zero, skipping `[6D00..6F00]`. Fills `[0400..0FFE]` with `0x73`. |
| `C000:03EA` | `0xC03EA` | `REP STOSW` filling `[8000..8FFF]` with zero (clears 4 KiB framebuffer). |
| `C000:03FC` | `0xC03FC` | irq_ff_warm: warm/power IRQ handler. Restores framebuffer, checks keyboard chord, enters power-down or warm resume. |
| `C000:0430` | `0xC0430` | Checks keyboard chord (`C000:14E6`), decides diagnostic vs warm path. |
| `C000:044B` | `0xC044B` | Warm state marker check: tests `[1109]` for `0x1995`. |
| `C000:0466` | `0xC0466` | Power-down entry from warm IRQ: calls `C000:0DFF`, enters halt at `C000:0492`. |
| `C000:047F` | `0xC047F` | Power-down prep: checksums context (`C000:055E`), checksums store (`C000:0571`), saves state (`C000:05A3`). |
| `C000:048C` | `0xC048C` | Power-down: calls `C000:05A3` (save state), `C000:0498` (RTC check). |
| `C000:0492` | `0xC0492` | `OUT 70,01` (RTC alarm enable); `JMP $` (infinite halt). |
| `C000:0498` | `0xC0498` | RTC check + writeback: reads RTC via `C000:0E43`/`C000:0E2F`, writes saved time back or advances minute. |
| `C000:04BF` | `0xC04BF` | Sets `[1109]=0x1995` before halt. |
| `C000:04C6` | `0xC04C6` | RTC minute advance wrapper: calls `C000:0CE1`, sets `[1439]=1`. |
| `C000:04D0` | `0xC04D0` | int_02h_nmi / IRQ F8 handler. Saves full context to `[1453..146D]`, checksums it, saves state, halts. Early exit if `[1109]==1` or `0x1995`. |
| `C000:04FB` | `0xC04FB` | NMI continuation: full context save, checksum, halt. |
| `C000:055E` | `0xC055E` | Sums 15 words at `[1453..1470]`, stores result at `[1471]`. |
| `C000:0571` | `0xC0571` | Sets DS=0x1800, checksums 0x7FFC words from `[0008]`, stores at `[0006]`. |
| `C000:0580` | `0xC0580` | RAM checksum verify: compares computed checksum against stored value. |
| `C000:0594` | `0xC0594` | Checksum verify result handler. |
| `C000:05A3` | `0xC05A3` | Save state: copies `[1335]->[110B]`, copies interrupt mask shadow, calls `C000:0FB5` and `C000:0E9F`. |

## 3. IRQ Handlers (C000:05C0-08FF)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:05C0` | `0xC05C0` | irq_f9: timer/wake acknowledge handler. |
| `C000:05D4` | `0xC05D4` | irq_fa: keyboard scan-cycle/reset helper, calls `C000:1303`. |
| `C000:05F7` | `0xC05F7` | irq_fb_keyboard: keyboard row scan ISR. Reads port `0xB0`, stores rows at `[1306..130F]`, calls `C000:3AE3` after tenth row. |
| `C000:0676` | `0xC0676` | irq_fc: RS-232 serial receive ISR. Reads status port `0xC1`, data port `0xC0`, queues bytes via `C000:3396`. |
| `C000:06EF` | `0xC06EF` | Serial receive dispatch: checks error bits, routes to echo/flow-control helpers. |
| `C000:071A` | `0xC071A` | Serial error handler: calls tone helpers `C000:0B62`/`C000:0B6F`. |
| `C000:0753` | `0xC0753` | Serial transmit helper for echo/flow-control byte output. |
| `C000:084A` | `0xC084A` | irq_fd: serial transmit acknowledge handler. Clears port `0x90` bit. |
| `C000:085E` | `0xC085E` | irq_fe: Centronics ACK-driven output handler. Emits next byte from queue through port `0x40`. |
| `C000:088F` | `0xC088F` | Centronics strobe/status continuation. |
| `C000:08A2` | `0xC08A2` | Buzzer/display helper called from `DEF0:27E3`. Calls `C000:0DC5`. |

## 4. Startup Display and Sound (C000:08AA-0BAF)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:08AA` | `0xC08AA` | RTC gate: checks `[1439]`, calls `C000:0953` (wait for RTC stable). RTC normal -> `C000:08D3`. RTC abnormal -> calls `DEF0:CD5F`, may power down. |
| `C000:08D3` | `0xC08D3` | Secondary RTC check (`C000:0E2F`). If normal: calls `DEF0:C5BC`, saves framebuffer, renders 9 display scripts from C772. |
| `C000:08DB` | `0xC08DB` | Calls `DEF0:C5BC` before display init. |
| `C000:08E2` | `0xC08E2` | Renders 9 display scripts from C772 (copyright/product banners). |
| `C000:0953` | `0xC0953` | RTC stable check: calls `C000:0E62`. If clear: falls to display init. If not: powers down (`C000:048C`). |
| `C000:095B` | `0xC095B` | Calls `C000:0CE1` (advance RTC minute), sets `[1439]=1`, halts. |
| `C000:0969` | `0xC0969` | Saves framebuffer: calls `C000:33E2`, copies `[8000..8FFF]` -> `[9000..9FFF]`. |
| `C000:0974` | `0xC0974` | Restores framebuffer: copies `[9000..9FFF]` -> `[8000..8FFF]`. |
| `C000:0987` | `0xC0987` | RTC + display init path: calls `C000:08AA`, display helper, delays, restores framebuffer. |
| `C000:09B2` | `0xC09B2` | Three timed delays (calls `C000:0B30` x3). |
| `C000:09CE` | `0xC09CE` | Calls `C000:0DC5` with AL=4. Runs when `[1473]==0x4D0` (previous NMI). |
| `C000:09D4` | `0xC09D4` | Renders "INITIALIZING" display script from `C772:EDB0`, delays. |
| `C000:09EA` | `0xC09EA` | Two timed delays (calls `C000:0B30` x2). |
| `C000:0A32` | `0xC0A32` | Two delays called from IOCTL dispatch. |
| `C000:0A45` | `0xC0A45` | Delay helper called from `DEF0:00F9` (set date wrapper). |
| `C000:0A49` | `0xC0A49` | Display restore helper for `C000:0987` path. |
| `C000:0A55` | `0xC0A55` | Framebuffer save called from `DEF0:CD6F`. |
| `C000:0A5F` | `0xC0A5F` | Framebuffer restore called from `DEF0:CDED`. |
| `C000:0A69` | `0xC0A69` | Power-down loop: calls `DEF0:CD5F`, retries until CF clears. |
| `C000:0AA0` | `0xC0AA0` | Keyboard chord check (F+J+SPACE): calls `C000:14D4`; if chord held and diagnostic exited (CF=1), sets `[146F]=0x1995`. |
| `C000:0AE6` | `0xC0AE6` | int21_printer_output_impl: printer output via port `0x40` or Centronics path. |
| `C000:0B08` | `0xC0B08` | Printer output retry: polls keyboard (`C000:3168`), retries. |
| `C000:0B12` | `0xC0B12` | Printer/buzzer port setup for Centronics output. |
| `C000:0B30` | `0xC0B30` | Timed delay: BX=outer count, CX=inner count. |
| `C000:0B62` | `0xC0B62` | Tone helper (low frequency). |
| `C000:0B6F` | `0xC0B6F` | Tone helper (high frequency). |

## 5. RTC and Keyboard (C000:0B74-0F0A)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:0B74` | `0xC0B74` | int21_get_date_impl: reads RTC, decodes year/month/day, computes weekday. |
| `C000:0BBF` | `0xC0BBF` | int21_set_date_impl: converts binary date to BCD, writes RTC date registers. |
| `C000:0BFA` | `0xC0BFA` | int21_get_time_impl: reads RTC ports `0xD0..0xDC` into shadow, decodes hour/minute/second. |
| `C000:0C24` | `0xC0C24` | int21_set_time_impl: converts binary time to BCD, writes RTC time registers. |
| `C000:0C50` | `0xC0C50` | RTC time write subroutine: writes BCD time to ports `0xD2..0xD8`. |
| `C000:0C6B` | `0xC0C6B` | RTC date write subroutine: writes BCD date to ports `0xD6..0xDC`. |
| `C000:0C86` | `0xC0C86` | RTC write finalize. |
| `C000:0C8E` | `0xC0C8E` | RTC low-nibble reader for BCD conversion. |
| `C000:0CA7` | `0xC0CA7` | Sets `[142C..142D]=0xFFFF`, `[1435..1436]=0xFFFF` (RTC check sentinels). |
| `C000:0CB3` | `0xC0CB3` | Writes saved RTC time from `[1430..1436]` to ports `0xD2..0xD8` (skipping `0xD6`). |
| `C000:0CE1` | `0xC0CE1` | Reads `[1486..1487]` (RTC minute digits), increments, writes to ports `0xD2..0xD3`. |
| `C000:0D0C` | `0xC0D0C` | Serial input/output router for thunk_slot_8. |
| `C000:0D42` | `0xC0D42` | Serial transmit-ready/status check using port `0xC1`. |
| `C000:0D53` | `0xC0D53` | Serial transmit data helper: writes byte to port `0xC0`. |
| `C000:0D61` | `0xC0D61` | Serial transmit with handshake: checks CTS then sends. |
| `C000:0D73` | `0xC0D73` | Serial CTS check helper. |
| `C000:0D7D` | `0xC0D7D` | Serial DTR control helper. |
| `C000:0DC5` | `0xC0DC5` | Timed delay with configurable count from AL. |
| `C000:0DEB` | `0xC0DEB` | Keyboard ring buffer check: reads `[1310]` debounce state. |
| `C000:0DFF` | `0xC0DFF` | Input status helper: reads keyboard scan state, checks for pending chars. |
| `C000:0E13` | `0xC0E13` | Reads RTC ports `0xD0..0xDC` (RP5C01) into `[1484..1490]`, low nibble only. |
| `C000:0E2F` | `0xC0E2F` | Secondary RTC check: 7 bytes from `[1430..1436]` against `[148C..1486]`. |
| `C000:0E43` | `0xC0E43` | Primary RTC check: calls `C000:0E13`, compares 11 bytes. Returns CF=1 when RTC uninitialized. |
| `C000:0E62` | `0xC0E62` | RTC zero check: calls `C000:0E13`, checks `[1484]` and `[1485]` both zero. |
| `C000:0E75` | `0xC0E75` | Serial echo handler: echoes received char back, calls display update. |
| `C000:0E92` | `0xC0E92` | Keyboard buffer peek: reads next char without consuming. |
| `C000:0EAF` | `0xC0EAF` | LCD control register write helper. |
| `C000:0EE3` | `0xC0EE3` | LCD/display port initialization. |
| `C000:0F0B` | `0xC0F0B` | LCD bank/mode register setup: calls `C000:0EAF`, `C000:0EE3`. |

## 6. IVT and Vectors (C000:0F6F-12CB)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:0F6F` | `0xC0F6F` | LCD clear: calls `C000:2F54`, `C000:0F0B`. |
| `C000:0FA2` | `0xC0FA2` | Serial polling loop: calls `C000:10A9` in loop. |
| `C000:0FA8` | `0xC0FA8` | Serial receive byte read. |
| `C000:0FB0` | `0xC0FB0` | Serial port status query for IOCTL dispatch. |
| `C000:0FD1` | `0xC0FD1` | Serial transmit loop: retries until ready. |
| `C000:0FDA` | `0xC0FDA` | int21_aux_output_impl: serial output via `C000:0FD1`. |
| `C000:0FFC` | `0xC0FFC` | int21_aux_output: serial output with keyboard check. |
| `C000:1021` | `0xC1021` | Aux input buffer helper called from `C000:3354`. |
| `C000:102D` | `0xC102D` | Serial echo/display loop body. |
| `C000:104F` | `0xC104F` | Terminal mode dispatch for serial I/O. |
| `C000:1061` | `0xC1061` | XON/XOFF flow-control handler: calls `DEF0:00B8`. |
| `C000:10A9` | `0xC10A9` | Aux input poll: calls `C000:3336`. |
| `C000:10B2` | `0xC10B2` | Terminal mode input loop body. |
| `C000:10C9` | `0xC10C9` | Terminal mode serial transmit loop. |
| `C000:10DB` | `0xC10DB` | XON/XOFF handler for terminal mode, calls `DEF0:00B8`. |
| `C000:1123` | `0xC1123` | Serial break/reset helper. |
| `C000:1161` | `0xC1161` | install_vectors: fills IVT `00h..F7h` with `C000:141F` (IRET), writes IRQ stubs F8h-FFh, overwrites INT 01h/21h, copies far-call table to `[0200..029C]`. |
| `C000:12CC` | `0xC12CC` | Clears 20 bytes at `[1310..1323]`, clears state bytes, masks port `0x60` bits, pulses port `0x61`, clears `[132D]`. |

## 7. Diagnostic (C000:1303-15C2)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:1303` | `0xC1303` | Keyboard scan reset: clears row index, resets scan hardware. |
| `C000:131D` | `0xC131D` | thunk_slot_7: sets `[15A2]=1`, renders terminal banner from `C000:76F5`, enters command loop. |
| `C000:1341` | `0xC1341` | Command loop: polls keyboard (`C000:3168`), dispatches on key code. |
| `C000:1378` | `0xC1378` | Command dispatch table (7 entries). |
| `C000:13C5` | `0xC13C5` | Exit: clears `[15A2]`, returns. |
| `C000:13DD` | `0xC13DD` | Display/send helper: calls `DEF0:0035`. |
| `C000:13F5` | `0xC13F5` | Terminal init: calls `DEF0:000B`, clears LCD, renders 47 bytes from `C000:76F5`, calls `DEF0:0027` and `DEF0:0019`. |
| `C000:141F` | `0xC141F` | Single IRET (default vector target). |
| `C000:1420` | `0xC1420` | Software error halt: sets `[1109]=0x1999`, renders "Internal software error..." from `C000:1450`, halts. |
| `C000:14D4` | `0xC14D4` | Chord compare driver: calls `C000:14E6` to compare keyboard matrix. If match: renders diagnostic banner, enters command loop, loops until exit. |
| `C000:14DB` | `0xC14DB` | thunk_slot_6: renders diagnostic entry banner (`C000:1506`), enters diagnostic UI loop (`C000:1523`). |
| `C000:14E6` | `0xC14E6` | `REPE CMPSB` comparing 10 bytes at `[1306..130F]` against `CS:14FC`. Returns ZF=1 on match. |
| `CS:14FC` | `0xC14FC` | Chord pattern: `00 08 00 00 80 00 00 00 40 00` = SPACE+F+J. |
| `C000:1506` | `0xC1506` | Renders diagnostic entry banner from `C772:005D` (69 bytes). |
| `C000:1523` | `0xC1523` | Diagnostic UI command loop: handles keys `0x0B`/`0x02`/`0x03` exit, `0x3F` help, `0x4B`/`0x6B` commands, `0xDA` special. |
| `C000:1564` | `0xC1564` | Diagnostic display helper: calls `DEF0:0019`, `C000:6557`. |
| `C000:1569` | `0xC1569` | Diagnostic command: calls `DEF0:0D25`. |
| `C000:1595` | `0xC1595` | Diagnostic command helper: calls `C000:1B4F`. |

## 8. Banked Thunks (C000:15C3-1DFF)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:15C3` | `0xC15C3` | Diagnostic helper: calls `DEF0:0035` x2. |
| `C000:16BE` | `0xC16BE` | Display byte output: calls `C000:1919` x2. |
| `C000:17AF` | `0xC17AF` | Display word output: calls `C000:1905` x2. |
| `C000:1832` | `0xC1832` | INT 01h single-step handler. |
| `C000:1880` | `0xC1880` | Tone/buzzer dispatch: calls `C000:0B62` or `C000:0B6F`. |
| `C000:18A5` | `0xC18A5` | Banked service: calls `C000:1B4F`. |
| `C000:18B3` | `0xC18B3` | Diagnostic command handler (from `C000:1523`). |
| `C000:18CC` | `0xC18CC` | Diagnostic command handler (alternate). |
| `C000:18FA` | `0xC18FA` | Display address output: calls `C000:1905` x2 for SEG:OFF. |
| `C000:1905` | `0xC1905` | Display word: calls `C000:1919` x2 for high/low byte. |
| `C000:1919` | `0xC1919` | Display hex nibble. |
| `C000:1929` | `0xC1929` | Diagnostic helper: called from `DEF0:0035`. |
| `C000:194B` | `0xC194B` | Called from `DEF0:0D4F`: calls `C000:0A69` (power-down loop). |
| `C000:195B` | `0xC195B` | Diagnostic command: calls `DEF0:0D25`. |
| `C000:196D` | `0xC196D` | Diagnostic helper: calls `DEF0:0035` x2. |
| `C000:197E` | `0xC197E` | Display script render: calls `C000:6557`. |
| `C000:19A0` | `0xC19A0` | Display/service helper: calls `DEF0:0019`, `C000:6557`. |
| `C000:19C3` | `0xC19C3` | Banked thunk entry from `C772:970F`: calls `C000:19CB`. |
| `C000:19C7` | `0xC19C7` | Banked thunk entry from `C772:9715`: calls `C000:1B28`. |
| `C000:19CB` | `0xC19CB` | Thunk dispatcher: saves bank state, calls `C000:19F0` for slot dispatch. |
| `C000:19E7` | `0xC19E7` | thunk_slot_9: error halt (`C000:1420`). |
| `C000:19F0` | `0xC19F0` | Thunk slot router: indexes AH, jumps to handler. |
| `C000:1B28` | `0xC1B28` | Dispatch table at `C000:1B38` (12 slots). Indexes on AH, jumps to handler. |
| `C000:1B4C` | `0xC1B4C` | thunk_slot_0: jumps to thunk_slot_9. |
| `C000:1B4F` | `0xC1B4F` | thunk_slot_4: service dispatch with validation. |
| `C000:1D85` | `0xC1D85` | thunk_slot_3: Centronics printer output, calls `C000:0B12`. |
| `C000:1D8C` | `0xC1D8C` | thunk_slot_1: tests `[15A2]`, falls to thunk_slot_0. |
| `C000:1DCF` | `0xC1DCF` | thunk_slot_8: serial I/O dispatch, routes to `C000:0D0C`/`0D53`/`0D61`. |

## 9. Thunk Slot Summary

| Slot | Address | Description |
| ---: | --- | --- |
| 0 | `C000:1B4C` | Jump to thunk_slot_9 (error halt). |
| 1 | `C000:1D8C` | Tests `[15A2]`, falls to slot 0. |
| 3 | `C000:1D85` | Centronics printer output. |
| 4 | `C000:1B4F` | Service dispatch with validation. |
| 6 | `C000:14DB` | Diagnostic entry banner + UI loop. |
| 7 | `C000:131D` | Terminal diagnostic command monitor. |
| 8 | `C000:1DCF` | Serial I/O dispatch. |
| 9 | `C000:19E7` | Error halt (`C000:1420`). |
| 10 | `C000:98E9` | Editor/display service, calls `C000:9431`. |
| 11 | `C000:BBFE` | Calls `C000:794D` x2. |

## 10. Subsystem Init (C000:1F61-2FFF)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:1F61` | `0xC1F61` | Called from editor init at `C000:99DE`. |
| `C000:23CC` | `0xC23CC` | Drive init helper: calls `C000:2B86`, `C000:2754`. |
| `C000:248D` | `0xC248D` | Drive init continuation. |
| `C000:2872` | `0xC2872` | Display render during storage init: calls `C000:6557`. |
| `C000:28A5` | `0xC28A5` | Storage sector read: calls `C000:28D9`. |
| `C000:28D9` | `0xC28D9` | Low-level storage I/O dispatcher. |
| `C000:2939` | `0xC2939` | Storage display helper: calls `C000:2872`. |
| `C000:2B86` | `0xC2B86` | Drive parameter init subroutine. |
| `C000:2DD5` | `0xC2DD5` | Far-call target from `C772:7841`: calls `C000:2DD9`. |
| `C000:2DD9` | `0xC2DD9` | Subsystem dispatch entry. |
| `C000:2E2D` | `0xC2E2D` | Validation: checks `[1337]==0x7CE`, validates `[1106]` against 8/9/A/B. Returns CF=1 if fail. |
| `C000:2E72` | `0xC2E72` | Subsystem init chain: sets `[1106]=8`, `[1339]=8`, calls RAM checksum verify, seeds bank mirrors, chain of init subroutines. |
| `C000:2EA8` | `0xC2EA8` | Init subroutine (part of `C000:2E72` chain). |
| `C000:2F32` | `0xC2F32` | Init subroutine: calls `C000:0CA7` (RTC sentinels). |
| `C000:2F7C` | `0xC2F7C` | Init subroutine. |
| `C000:2FB0` | `0xC2FB0` | Init subroutine. |
| `C000:2FD5` | `0xC2FD5` | Init subroutine. |

## 11. Serial/DreamLink (C000:3168-35FF)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:3168` | `0xC3168` | Keyboard poll: reads keyboard ring buffer, returns translated keycode. |
| `C000:3204` | `0xC3204` | Keyboard buffer read helper. |
| `C000:320D` | `0xC320D` | int21_char_input_impl: blocking keyboard read with echo, calls debounce/display. |
| `C000:3336` | `0xC3336` | int21_aux_input_impl: serial byte receive from ring buffer. |
| `C000:3354` | `0xC3354` | Aux input buffer read helper. |
| `C000:3396` | `0xC3396` | Serial receive queue insert: called from IRQ FC handler. |
| `C000:33E2` | `0xC33E2` | Display state save for framebuffer copy. |
| `C000:350A` | `0xC350A` | Keyboard debounce helper. |

## 12. Keyboard Services (C000:3AE3-3EFF)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:3AE3` | `0xC3AE3` | Keyboard row processor: called after completed 10-row scan. Maintains debounce, queues press/repeat events. |
| `C000:3DBA` | `0xC3DBA` | Keyboard translation table lookup. |
| `C000:3EAC` | `0xC3EAC` | Keyboard modifier snapshot builder. |
| `C000:3EBB` | `0xC3EBB` | Keyboard event handler (part of init chain). |

## 13. Display Wrappers (C000:3F0C-3FC8)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:3F0C` | `0xC3F0C` | Display wrapper called from `DEF0:2BFC`. |
| `C000:3F35` | `0xC3F35` | Display script renderer (far-call target): called from `DEF0:0D80` and far-call table `[0200]`. Calls `C000:6557`. |
| `C000:3F47` | `0xC3F47` | Display script renderer (alternate far wrapper, far-call table `[023C]`). |

## 14. INT 21h File Ops (C000:3F5F-6276)

### Disk/DTA Services

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:3F5F` | `0xC3F5F` | int21_select_disk_impl: selects active drive. |
| `C000:3F71` | `0xC3F71` | int21_get_disk_impl: returns current drive in AL. |
| `C000:3F7B` | `0xC3F7B` | int21_set_dta_impl: sets DTA address from DS:DX. |
| `C000:3F88` | `0xC3F88` | int21_get_dta_impl: returns DTA address in ES:BX. |
| `C000:3F98` | `0xC3F98` | int21_disk_free_impl: returns free space for selected drive. |
| `C000:3FC9` | `0xC3FC9` | IOCTL helper. |

### File Create/Open/Close

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:40B3` | `0xC40B3` | int21_create_file_impl (AH=3Ch): creates or truncates file. |
| `C000:412B` | `0xC412B` | int21_create_new_impl (AH=5Bh): creates new file, fails if exists. |
| `C000:4212` | `0xC4212` | File allocation table helper. |
| `C000:424C` | `0xC424C` | File create continuation. |
| `C000:425B` | `0xC425B` | File timestamp helper: calls `C000:0BFA` (get time). |
| `C000:4273` | `0xC4273` | File timestamp write. |
| `C000:429B` | `0xC429B` | int21_open_file_impl (AH=3Dh): opens existing file. |
| `C000:4329` | `0xC4329` | Directory entry parser. |
| `C000:436C` | `0xC436C` | int21_close_file_impl (AH=3Eh): closes file handle. |
| `C000:4396` | `0xC4396` | Storage endpoint dispatch: dispatches on BL (`0xA5`) and DL (`0x08`/`0x09`/`0x0A`/`0x0B`). |
| `C000:4498` | `0xC4498` | Drive/bank select helper for storage ops. |
| `C000:44E9` | `0xC44E9` | FAT sector reader. |

### Directory Search

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:453D` | `0xC453D` | int21_find_first_impl (AH=4Eh): finds first matching file. |
| `C000:4589` | `0xC4589` | int21_find_next_impl (AH=4Fh): finds next matching file. |
| `C000:4756` | `0xC4756` | int21_rename_impl (AH=56h): renames file. |
| `C000:4892` | `0xC4892` | int21_get_set_date_impl (AH=57h): gets/sets file date/time. |
| `C000:48D6` | `0xC48D6` | IOCTL handler: calls `C000:60A7`. |

### File Read/Write/Seek

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:4984` | `0xC4984` | int21_read_file_impl (AH=3Fh): reads from file handle. |
| `C000:4AE2` | `0xC4AE2` | int21_write_file_impl (AH=40h): writes to file handle. |
| `C000:4B6D` | `0xC4B6D` | Cluster chain walker for read/write. |
| `C000:4CE9` | `0xC4CE9` | Sector read/write dispatch: calls `C000:50BA`, `C000:4DA3`, `C000:5816`. |
| `C000:4DA3` | `0xC4DA3` | Sector buffer manager. |
| `C000:4DDA` | `0xC4DDA` | int21_seek_impl (AH=42h): seeks file to offset. |
| `C000:4EC2` | `0xC4EC2` | Seek offset calculator. |
| `C000:4F2E` | `0xC4F2E` | File traversal helper. |
| `C000:4F70` | `0xC4F70` | Directory chain walker. |
| `C000:4F8E` | `0xC4F8E` | Find file in directory. |
| `C000:4F9B` | `0xC4F9B` | int21_delete_file_impl (AH=41h): deletes file. |
| `C000:5026` | `0xC5026` | int21_get_set_attrs_impl (AH=43h): gets/sets file attributes. |
| `C000:50BA` | `0xC50BA` | Sector I/O dispatcher. |
| `C000:50F5` | `0xC50F5` | Directory entry allocator. |
| `C000:5118` | `0xC5118` | Find-next continuation. |
| `C000:5216` | `0xC5216` | Storage format helper. |
| `C000:5228` | `0xC5228` | Storage validation. |
| `C000:524E` | `0xC524E` | FAT chain helper. |
| `C000:525D` | `0xC525D` | FAT update helper. |
| `C000:528B` | `0xC528B` | Filename parser for 8.3 format. |
| `C000:5428` | `0xC5428` | Directory attribute matcher. |
| `C000:5487` | `0xC5487` | Sector read helper. |
| `C000:5527` | `0xC5527` | Checksum helper for storage validation. |
| `C000:55C2` | `0xC55C2` | Storage write helper. |
| `C000:5600` | `0xC5600` | Fills `[6F5E..6F61]` with `0xFF`. |
| `C000:5644` | `0xC5644` | Directory entry builder. |
| `C000:569B` | `0xC569B` | File close: flushes buffers. |
| `C000:5703` | `0xC5703` | File size calculator. |
| `C000:572E` | `0xC572E` | Directory entry writer. |
| `C000:57E5` | `0xC57E5` | File buffer flush. |
| `C000:5816` | `0xC5816` | Sector write to storage. |
| `C000:587C` | `0xC587C` | File handle validator. |
| `C000:58B8` | `0xC58B8` | Display render during file ops: calls `C772:8411`, `C000:2957`. |
| `C000:58CE` | `0xC58CE` | Display update after file close. |
| `C000:58FF` | `0xC58FF` | Storage init helper. |
| `C000:591F` | `0xC591F` | Storage device reset. |
| `C000:5949` | `0xC5949` | XON/XOFF handler for file transfer. |
| `C000:598D` | `0xC598D` | Storage completion handler. |
| `C000:5A0B` | `0xC5A0B` | Storage dispatch entry. |
| `C000:5AC8` | `0xC5AC8` | File path helper. |
| `C000:5D25` | `0xC5D25` | File create/open shared entry. |
| `C000:5DB7` | `0xC5DB7` | File delete shared entry. |
| `C000:60A7` | `0xC60A7` | IOCTL service body. |
| `C000:6149` | `0xC6149` | Rename directory entry update. |

## 15. INT 21h Dispatch (C000:6277-641F)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:6277` | `0xC6277` | INT 21h dispatch: validity table at `C000:61DF`, dispatch table at `C000:623F`. |
| `C000:62F6` | `0xC62F6` | int21_aux_input (AH=03h): serial input with keyboard check. |
| `C000:6325` | `0xC6325` | int21_printer_output (AH=05h): calls `C000:0AE6`. |
| `C000:6334` | `0xC6334` | int21_char_input (AH=08h): calls `C000:320D`. |
| `C000:633B` | `0xC633B` | int21_input_status (AH=0Bh): calls `C000:30E7`. |
| `C000:6342` | `0xC6342` | int21_select_disk (AH=0Eh): calls `C000:3F5F`. |
| `C000:6346` | `0xC6346` | int21_get_disk (AH=19h): calls `C000:3F71`. |
| `C000:634A` | `0xC634A` | int21_set_dta (AH=1Ah): calls `C000:3F7B`. |
| `C000:634E` | `0xC634E` | int21_get_date (AH=2Ah): calls `C000:0B74`. |
| `C000:635B` | `0xC635B` | int21_set_date (AH=2Bh): calls `C000:0BBF`. |
| `C000:6362` | `0xC6362` | int21_get_time (AH=2Ch): calls `C000:0BFA`. |
| `C000:636C` | `0xC636C` | int21_set_time (AH=2Dh): calls `C000:0C24`. |
| `C000:6373` | `0xC6373` | int21_get_dta (AH=2Fh): calls `C000:3F88`. |
| `C000:6377` | `0xC6377` | int21_disk_free (AH=36h): calls `C000:3F98`. |
| `C000:637B` | `0xC637B` | int21_create_file (AH=3Ch): calls `C000:40B3`. |
| `C000:637F` | `0xC637F` | int21_open_file (AH=3Dh): calls `C000:429B`. |
| `C000:6383` | `0xC6383` | int21_close_file (AH=3Eh): calls `C000:436C`. |
| `C000:6387` | `0xC6387` | int21_read_file (AH=3Fh): calls `C000:4984`. |
| `C000:638B` | `0xC638B` | int21_write_file (AH=40h): calls `C000:4AE2`. |
| `C000:638F` | `0xC638F` | int21_delete_file (AH=41h): calls `C000:4F9B`. |
| `C000:6393` | `0xC6393` | int21_seek (AH=42h): calls `C000:4DDA`. |
| `C000:6397` | `0xC6397` | int21_get_set_attrs (AH=43h): calls `C000:5026`. |
| `C000:639B` | `0xC639B` | int21_ioctl (AH=44h): IOCTL dispatch with subfunction table. |
| `C000:6405` | `0xC6405` | int21_find_first (AH=4Eh): calls `C000:453D`. |
| `C000:6409` | `0xC6409` | int21_find_next (AH=4Fh): calls `C000:4589`. |
| `C000:640D` | `0xC640D` | int21_rename (AH=56h): calls `C000:4756`. |
| `C000:6411` | `0xC6411` | int21_get_set_date (AH=57h): calls `C000:4892`. |
| `C000:6415` | `0xC6415` | int21_create_new (AH=5Bh): calls `C000:412B`. |
| `C000:6419` | `0xC6419` | Weekday calculator used by get_date. |

### INT 21h Input Status Implementation

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:30E7` | `0xC30E7` | int21_input_status_impl (AH=0Bh): checks keyboard/serial input status. |

## 16. Display Renderer (C000:6523-6BFF)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:6523` | `0xC6523` | Display state init: sets `[16E6]=6`, `[16E5]=6`, calls subroutines, initializes drive/file state. |
| `C000:6557` | `0xC6557` | Display script renderer body: SI=offset, CX=length, DX=segment. Processes `FF xx` command stream. |
| `C000:6585` | `0xC6585` | Display script loop: fetches next command byte, dispatches. |
| `C000:68A5` | `0xC68A5` | disp_cmd_5: display command handler. |
| `C000:68A7` | `0xC68A7` | disp_cmd_0: display command handler (primary text renderer). |
| `C000:68D5` | `0xC68D5` | disp_cmd_7: jumps to `C000:6557` (script restart). |
| `C000:68D8` | `0xC68D8` | disp_cmd_16: display parameter set. |
| `C000:68DF` | `0xC68DF` | disp_cmd_17: display parameter set. |
| `C000:68E6` | `0xC68E6` | disp_cmd_18: display parameter set. |
| `C000:68ED` | `0xC68ED` | disp_cmd_19: display parameter set. |
| `C000:68F4` | `0xC68F4` | disp_cmd_20: display parameter set. |
| `C000:6900` | `0xC6900` | disp_cmd_21: display conditional. |
| `C000:6924` | `0xC6924` | disp_cmd_22: display parameter set. |
| `C000:692B` | `0xC692B` | disp_cmd_23: display jump. |
| `C000:6933` | `0xC6933` | disp_cmd_24: display parameter set. |
| `C000:693A` | `0xC693A` | disp_cmd_25: display area clear, calls `C000:6CA7`. |
| `C000:6948` | `0xC6948` | disp_cmd_26: display parameter set. |
| `C000:6954` | `0xC6954` | disp_cmd_27: display parameter set. |
| `C000:6960` | `0xC6960` | disp_cmd_28: display parameter set. |
| `C000:6967` | `0xC6967` | disp_cmd_30: display conditional/mode select. |
| `C000:6BAA` | `0xC6BAA` | disp_cmd_31: bitmap blit handler. |
| `C000:6BF6` | `0xC6BF6` | Display init subroutine called from `C000:6523`. |
| `C000:6CA7` | `0xC6CA7` | Display area clear/fill. |
| `C000:6E55` | `0xC6E55` | Display string output helper. |

## 17. Interrupt Stubs (C000 Jump Table)

| Address | Jump target | IRQ/Vector |
| --- | --- | --- |
| `C000:0006` | `C000:6277` | INT 21h |
| `C000:0009` | `C000:04D0` | F8 -- NMI/save-suspend |
| `C000:000C` | `C000:05C0` | F9 -- timer/wake |
| `C000:000F` | `C000:05D4` | FA -- keyboard scan reset |
| `C000:0012` | `C000:05F7` | FB -- keyboard row scan |
| `C000:0015` | `C000:0676` | FC -- RS-232 receive |
| `C000:0018` | `C000:084A` | FD -- serial transmit ack |
| `C000:001B` | `C000:085E` | FE -- Centronics ACK |
| `C000:001E` | `C000:03FC` | FF -- warm/power |
| `C000:0021` | via `C000:19CB` | Banked thunk (RETF) |
| `C000:0025` | via `C000:1B28` | Banked thunk (RETF) |

## 18. Editor Utility (C000:75B5-BBFE)

| Address | File offset | Description |
| --- | ---: | --- |
| `C000:75B5` | `0xC75B5` | Display string output for AD00 ROM card: calls `C000:6E55`. |
| `C000:75FD` | `0xC75FD` | Display script render for AD00: calls `C000:6557`. |
| `C000:794D` | `0xC794D` | Editor service helper called from thunk_slot_11. |
| `C000:89C1` | `0xC89C1` | Cross-segment call target (also `C772:12A1`). |
| `C000:90B6` | `0xC90B6` | Cross-segment call target (also `C772:1996`). |
| `C000:91DB` | `0xC91DB` | Cross-segment call target (also `C772:1ABB`): calls `C000:DB96`. |
| `C000:9431` | `0xC9431` | Editor/display service body for thunk_slot_10. |
| `C000:9698` | `0xC9698` | Editor helper. |
| `C000:98E9` | `0xC98E9` | thunk_slot_10: editor/display service, calls `C000:9431`. |
| `C000:993F` | `0xC993F` | Editor init helper. |
| `C000:99DE` | `0xC99DE` | Editor state initializer. |
| `C000:9333` | `0xC9333` | Editor service helper. |
| `C000:BA35` | `0xCBA35` | Cross-segment call target (also `C772:4315`). |
| `C000:BBFE` | `0xCBBFE` | thunk_slot_11: calls `C000:794D` x2. |
| `C000:DB96` | `0xCDB96` | Editor internal routine. |

## 19. C772 Entry Points

### Application Entry

| Address | File offset | Description |
| --- | ---: | --- |
| `C772:0004` | `0xC7724` | Application entry -- cold start. Called from `C000:018A`. Calls `C772:2A6A`. |
| `C772:0008` | `0xC7728` | Application entry -- warm resume. Called from `C000:01DF`. Calls `C772:84DE`. |
| `C772:000C` | `0xC772C` | Application entry -- display reset. Called from `DEF0:2662`/`2612`/`2636`. |

### VM Opcode Handlers

| Address | File offset | Description |
| --- | ---: | --- |
| `C772:03E6` | `0xC7B06` | vm_op_9E: calls `C772:0446`. |
| `C772:03EC` | `0xC7B0C` | vm_op_A0: calls `C772:0446`. |
| `C772:03F2` | `0xC7B12` | vm_op_A4: calls `C772:044B`. |
| `C772:03F8` | `0xC7B18` | vm_op_A2: calls `C772:044B`. |
| `C772:03FE` | `0xC7B1E` | vm_op_56: calls `C772:041A`. |
| `C772:0406` | `0xC7B26` | vm_op_5A: calls `C772:041A`. |
| `C772:040E` | `0xC7B2E` | vm_op_58: calls `C772:041A`. |
| `C772:041A` | `0xC7B3A` | VM arithmetic shared body. |
| `C772:044B` | `0xC7B6B` | VM comparison shared body. |
| `C772:04E8` | `0xC7C08` | vm_op_B8: no-op / placeholder. |
| `C772:0BE9` | `0xC8309` | vm_op_BC: calls `C772:5E35`. |
| `C772:2DBD` | `0xCA4DD` | vm_op_22: conditional branch. |
| `C772:3668` | `0xCAD88` | vm_op_04: block move with display update. |
| `C772:3672` | `0xCAD92` | vm_op_06: register load. |
| `C772:367D` | `0xCAD9D` | vm_op_02: register store. |
| `C772:367E` | `0xCAD9E` | vm_op_00: no-op. |
| `C772:3684` | `0xCADA4` | vm_op_B2: extended register op. |
| `C772:3690` | `0xCADB0` | vm_op_68: shift/rotate. |
| `C772:3696` | `0xCADB6` | vm_op_66: word load, calls `C772:37B3`. |
| `C772:369E` | `0xCADBE` | vm_op_B6: calls `C772:98EC`. |
| `C772:36B0` | `0xCADD0` | vm_op_6E: shift/branch. |
| `C772:36B9` | `0xCADD9` | vm_op_70: jump. |
| `C772:36BD` | `0xCADDD` | vm_op_72: conditional, calls `C772:37B3`. |
| `C772:36D3` | `0xCADF3` | vm_op_6A: shift/compare. |
| `C772:36DC` | `0xCADFC` | vm_op_12: immediate load. |
| `C772:36E9` | `0xCAE09` | vm_op_6C: word op with `C772:393E`. |
| `C772:36F8` | `0xCAE18` | vm_op_76: word load. |
| `C772:36FE` | `0xCAE1E` | vm_op_A8: extended op. |
| `C772:370E` | `0xCAE2E` | vm_op_7C: word load. |
| `C772:3715` | `0xCAE35` | vm_op_74: conditional. |
| `C772:371C` | `0xCAE3C` | vm_op_A6: register op. |
| `C772:3724` | `0xCAE44` | vm_op_78: conditional jump. |
| `C772:3728` | `0xCAE48` | vm_op_AA: extended op, calls `C772:37B3`. |
| `C772:373B` | `0xCAE5B` | vm_op_7A: conditional branch. |
| `C772:374A` | `0xCAE6A` | vm_op_B0: extended compute. |
| `C772:3763` | `0xCAE83` | vm_op_AE: jump. |
| `C772:3767` | `0xCAE87` | vm_op_AC: double-word op. |
| `C772:378E` | `0xCAEAE` | vm_op_B4: recursive call, calls `C772:37B3` x2. |
| `C772:37B3` | `0xCAED3` | VM operand fetch shared helper. |
| `C772:37C1` | `0xCAEE1` | vm_op_40: branch to `C772:3945`. |
| `C772:37CB` | `0xCAEEB` | vm_op_42: branch to `C772:3945`. |
| `C772:37D5` | `0xCAEF5` | vm_op_0A: branch to `C772:5E35`. |
| `C772:37DF` | `0xCAEFF` | vm_op_0C: branch to `C772:5E35`. |
| `C772:37E9` | `0xCAF09` | vm_op_24: display update, calls `C772:1ADB`. |
| `C772:37FB` | `0xCAF1B` | vm_op_14: branch to `C772:3C2D`. |
| `C772:3800` | `0xCAF20` | vm_op_18: branch to `C772:3C2D`. |
| `C772:3805` | `0xCAF25` | vm_op_16: branch to `C772:3BFA`. |
| `C772:380A` | `0xCAF2A` | vm_op_36: branch. |
| `C772:380E` | `0xCAF2E` | vm_op_1A: branch to `C772:5E35`. |
| `C772:3815` | `0xCAF35` | vm_op_4C: branch to `C772:5E35`. |
| `C772:381A` | `0xCAF3A` | vm_op_80: calls `C772:45A7`. |
| `C772:3824` | `0xCAF44` | vm_op_34: branch to `C772:5E35`. |
| `C772:382B` | `0xCAF4B` | vm_op_4A: branch to `C772:5E35`. |
| `C772:3830` | `0xCAF50` | vm_op_1E: extended op. |
| `C772:383E` | `0xCAF5E` | vm_op_1C: extended op. |
| `C772:384C` | `0xCAF6C` | vm_op_44: branch to `C772:5E35`. |
| `C772:3851` | `0xCAF71` | vm_op_46: branch to `C772:5E35`. |
| `C772:3856` | `0xCAF76` | vm_op_32: branch to `C772:5E35`. |
| `C772:385D` | `0xCAF7D` | vm_op_26: branch to `C772:5E35`. |
| `C772:3864` | `0xCAF84` | vm_op_3E: calls `C772:2B21`. |
| `C772:386A` | `0xCAF8A` | vm_op_2E: branch to `C772:5E1E`. |
| `C772:3872` | `0xCAF92` | vm_op_30: branch to `C772:5E22`. |
| `C772:387A` | `0xCAF9A` | vm_op_08: no-op / sync. |
| `C772:3880` | `0xCAFA0` | vm_op_9A: display state conditional. |
| `C772:3889` | `0xCAFA9` | vm_op_8E: display flag test. |
| `C772:3891` | `0xCAFB1` | vm_op_98: display flag test. |
| `C772:3899` | `0xCAFB9` | vm_op_94: display flag test. |
| `C772:38A1` | `0xCAFC1` | vm_op_92: display flag test. |
| `C772:38A9` | `0xCAFC9` | vm_op_90: display flag test. |
| `C772:38B1` | `0xCAFD1` | vm_op_96: display flag test. |
| `C772:38B9` | `0xCAFD9` | vm_op_8C: display flag test. |
| `C772:38C1` | `0xCAFE1` | vm_op_8A: display flag test. |
| `C772:38C9` | `0xCAFE9` | vm_op_9C: display flag test. |
| `C772:38D1` | `0xCAFF1` | vm_op_84: display flag test. |
| `C772:38DB` | `0xCAFFB` | vm_op_86: display flag test. |
| `C772:38E8` | `0xCB008` | vm_op_88: display flag test. |
| `C772:38F0` | `0xCB010` | vm_op_82: display state update. |
| `C772:3903` | `0xCB023` | vm_op_50: branch to `C772:393E`. |
| `C772:390A` | `0xCB02A` | vm_op_52: branch to `C772:393E`. |
| `C772:3911` | `0xCB031` | vm_op_54: branch to `C772:393E`. |
| `C772:3918` | `0xCB038` | vm_op_5E: conditional branch. |
| `C772:3925` | `0xCB045` | vm_op_60: conditional branch. |
| `C772:3932` | `0xCB052` | vm_op_5C: subroutine call. |
| `C772:3BD8` | `0xCB2F8` | vm_op_28: block operation. |
| `C772:3BFA` | `0xCB31A` | vm_op_62: extended block op. |
| `C772:45A7` | `0xCBCC7` | vm_op_38: far call dispatch. |
| `C772:4C6D` | `0xCC38D` | fmt_op_0: format operation, calls `C772:A1A8`. |
| `C772:5E00` | `0xCD520` | vm_op_BA: branch select. |
| `C772:5E18` | `0xCD538` | vm_op_20: branch to `C772:5E35`. |
| `C772:5E1E` | `0xCD53E` | vm_op_64: branch. |
| `C772:5E22` | `0xCD542` | vm_op_7E: branch. |
| `C772:5E2B` | `0xCD54B` | vm_op_2A: branch. |
| `C772:5E2F` | `0xCD54F` | vm_op_2C: branch. |
| `C772:5E35` | `0xCD555` | VM instruction return/advance shared tail. |
| `C772:64EA` | `0xDC00A` | vm_op_3C: far call with args, calls `C772:45A7`. |
| `C772:64F4` | `0xDC014` | vm_op_3A: far call with args, calls `C772:45A7`. |
| `C772:6CE0` | `0xDE400` | vm_op_10: display output. |
| `C772:6CE4` | `0xDE404` | vm_op_0E: display update, calls `C772:0DC0`. |
| `C772:E81F` | `0xD5F3F` | vm_op_BE: display helper, calls `C772:7115`. |

### Format Opcodes

| Address | File offset | Description |
| --- | ---: | --- |
| `C772:0480` | `0xC7BA0` | fmt_op_3: format helper. |
| `C772:0485` | `0xC7BA5` | fmt_op_4: format helper. |
| `C772:048A` | `0xC7BAA` | fmt_op_5: format helper. |
| `C772:048F` | `0xC7BAF` | fmt_op_2: format helper. |
| `C772:33E9` | `0xCAB09` | fmt_op_6: format with display update, calls `C772:365E`, `C772:3864`. |

### C772 Native Helpers

| Address | File offset | Description |
| --- | ---: | --- |
| `C772:01CD` | `0xC78ED` | Called from `DEF0:2CDD`: display setup with `C772:45A7`, `C772:8526`, `C772:92AA`. |
| `C772:01F3` | `0xC7913` | Called from `DEF0:2CDD`: calls `C772:941D`, `C772:9715`. |
| `C772:0212` | `0xC7932` | Called from `DEF0:2D9C`. |
| `C772:0221` | `0xC7941` | Called from `DEF0:2ADA`. |
| `C772:0802` | `0xC7F22` | Display helper: calls `C772:022D`. |
| `C772:0DC0` | `0xC84E0` | Display helper: calls `C772:022D`. |
| `C772:0EB2` | `0xC85D2` | Display helper called from `C772:A126`. |
| `C772:10BF` | `0xC87DF` | Display layout manager: calls `C772:380E`, `C772:1176`, `C772:11D2`. |
| `C772:1101` | `0xC8821` | Display frame: calls `C772:78FE`, `C772:795D`. |
| `C772:110F` | `0xC882F` | Display link: calls `C772:111C`, `C772:45A7`. |
| `C772:111C` | `0xC883C` | Display body: calls `C772:1BAB`, `C772:1AD4`, `C772:6476`. |
| `C772:1176` | `0xC8896` | Display element: calls `C772:11D2`, `C772:970F`. |
| `C772:2A6A` | `0xCA18A` | Cold-start app init: calls `C772:29DC`, `C772:2E38`, `C772:6476`, `C772:022D`. |
| `C772:393E` | `0xCB05E` | VM subroutine return handler. |
| `C772:3C2D` | `0xCB34D` | VM stack adjust helper. |
| `C772:4556` | `0xCBC76` | VM far call return handler. |
| `C772:6476` | `0xCDB96` | Display refresh helper. |
| `C772:7115` | `0xCE835` | Display render dispatch. |
| `C772:78FE` | `0xCF01E` | Cursor position helper. |
| `C772:84DE` | `0xCFBFE` | Warm-start app resume entry. |
| `C772:8411` | `0xCFB31` | Display callback from `C000:58B8`. |
| `C772:8526` | `0xCFC46` | Display setup helper. |
| `C772:92AA` | `0xD09CA` | Display init helper. |
| `C772:941D` | `0xD0B3D` | Display state helper. |
| `C772:970F` | `0xD0E2F` | Banked thunk call: calls `C000:19C3`. Far-call target from `C772:6E80`. |
| `C772:9715` | `0xD0E35` | Banked thunk call: calls `C000:19C7`. Far-call target from `C772:844B`. |
| `C772:98EC` | `0xD100C` | Display helper called from vm_op_B6. |
| `C772:9A8C` | `0xD11AC` | Display helper called from `C772:84F2`. |

### Search/Landing Points

| Address | File offset | Description |
| --- | ---: | --- |
| `C772:215F` | `0xC987F` | landing_215F: branch target. |
| `C772:6BE3` | `0xCE303` | landing_6BE3: branch target. |
| `C772:9652` | `0xD0D72` | search_96_0B: search entry. |
| `C772:966B` | `0xD0D8B` | search_96_13: search helper, calls `C772:965A`. |
| `C772:9677` | `0xD0D97` | search_96_12: search helper, calls `C772:9653`. |

### C772 Far-Call Targets (from DEF0)

| Address | File offset | Description |
| --- | ---: | --- |
| `C772:E81A` | `0xD5F3A` | Called from `DEF0:26B4`. |
| `C772:E832` | `0xD5F52` | Called from `DEF0:279D`: calls `C772:E963`. |
| `C772:E84A` | `0xD5F6A` | Called from `DEF0:25B7`: calls `C772:AE4B`. |
| `C772:E87D` | `0xD5F9D` | Called from `DEF0:2739`: calls `C772:6F33`. |
| `C772:E895` | `0xD5FB5` | Called from `DEF0:26F8`: calls `C772:6EB1`. |
| `C772:E8AD` | `0xD5FCD` | Called from `DEF0:270E`: calls `C772:6FB9`. |
| `C772:E8C5` | `0xD5FE5` | Called from `DEF0:26E2`: calls `C772:71EB`. |
| `C772:E8DD` | `0xD5FFD` | Called from `DEF0:264C`: calls `C772:7453`. |
| `C772:E8F5` | `0xD6015` | Called from `DEF0:2662`: calls `C772:000C`, `C772:7608`. |
| `C772:E910` | `0xD6030` | Called from `DEF0:2612`: calls `C772:000C`, `C772:7560`. |
| `C772:E92B` | `0xD604B` | Called from `DEF0:2636`: calls `C772:000C`, `C772:770C`. |
| `C772:E946` | `0xD6066` | Called from `DEF0:2678`: calls `C772:9715`. |

## 20. DEF0 Far-Call Table Entries

The far-call table at `[0200..029C]` is installed by `C000:1161` and
contains 41 entries (38 to DEF0, 2 to C000). These provide the C772
application layer with indirect access to services.

### Display Services (#0-#11, #15)

| # | RAM addr | Target | File offset | Description |
| ---: | --- | --- | ---: | --- |
| 0 | `[0200]` | `C000:3F35` | `0xC3F35` | Display script render (far wrapper). |
| 1 | `[0204]` | `DEF0:0D91` | `0xDFC91` | Build + render display script from params. |
| 2 | `[0208]` | `DEF0:0DF5` | `0xDFCF5` | Display page setup (FF 44 command). |
| 3 | `[020C]` | `DEF0:115C` | `0xE005C` | Display subsystem query/init. |
| 4 | `[0210]` | `DEF0:1471` | `0xE0371` | Display area compute (page offset). |
| 5 | `[0214]` | `DEF0:1806` | `0xE0706` | Display parameter config. |
| 6 | `[0218]` | `DEF0:1B00` | `0xE0A00` | Display composite (calls 13A7, 1471, 1639). |
| 7 | `[021C]` | `DEF0:2097` | `0xE0F97` | Display state query. |
| 8 | `[0220]` | `DEF0:0D80` | `0xDFC80` | Display init: renders 15-byte script. |
| 9 | `[0224]` | `DEF0:0F87` | `0xDFE87` | Display mode dispatch (CX=1..4). |
| 10 | `[0228]` | `DEF0:0FE4` | `0xDFEE4` | Character filter (0x30 -> 0x20). |
| 11 | `[022C]` | `DEF0:1775` | `0xE0675` | Set display callback pointers. |
| 15 | `[023C]` | `C000:3F47` | `0xC3F47` | Display script render (alternate). |

### Keyboard/Input Services (#12-#14)

| # | RAM addr | Target | File offset | Description |
| ---: | --- | --- | ---: | --- |
| 12 | `[0230]` | `DEF0:0043` | `0xDEF43` | INT 21h AH=08h wrapper (keyboard char, no echo). |
| 13 | `[0234]` | `DEF0:0063` | `0xDEF63` | INT 21h AH=0Bh wrapper (input status). |
| 14 | `[0238]` | `DEF0:00F9` | `0xDEFF9` | INT 21h AH=2Bh wrapper (set date). |

### File Services (#16-#39)

| # | RAM addr | Target | File offset | Description |
| ---: | --- | --- | ---: | --- |
| 16 | `[0240]` | `DEF0:DAD6` | `0xEC9D6` | File service (standalone). |
| 17 | `[0244]` | `DEF0:DB47` | `0xECA47` | File service, calls `DEF0:E14C`. |
| 18 | `[0248]` | `DEF0:E022` | `0xECF22` | File op via core `DEF0:DFD5`. |
| 19 | `[024C]` | `DEF0:DC5E` | `0xECB5E` | File op via E08C helper. |
| 20 | `[0250]` | `DEF0:E048` | `0xECF48` | File op via core. |
| 21 | `[0254]` | `DEF0:E05A` | `0xECF5A` | File op via core. |
| 22 | `[0258]` | `DEF0:E05A` | `0xECF5A` | Same as #21 (duplicate). |
| 23 | `[025C]` | `DEF0:E070` | `0xECF70` | File service (standalone). |
| 24 | `[0260]` | `DEF0:E08C` | `0xECF8C` | File helper (also called by #19, #27, #28). |
| 25 | `[0264]` | `DEF0:E0A4` | `0xECFA4` | File op via core. |
| 26 | `[0268]` | `DEF0:DCA2` | `0xECBA2` | File service (standalone). |
| 27 | `[026C]` | `DEF0:DD27` | `0xECC27` | File op via E08C helper. |
| 28 | `[0270]` | `DEF0:DE34` | `0xECD34` | File op via E0A4 + E08C. |
| 29 | `[0274]` | `DEF0:E0C0` | `0xECFC0` | File service (standalone). |
| 30 | `[0278]` | `DEF0:DE90` | `0xECD90` | File service (standalone). |
| 31 | `[027C]` | `DEF0:DF1C` | `0xECE1C` | File service (standalone). |
| 32 | `[0280]` | `DEF0:E1F0` | `0xED0F0` | File op via core. |
| 33 | `[0284]` | `DEF0:E195` | `0xED095` | File op via core. |
| 34 | `[0288]` | `DEF0:E1B4` | `0xED0B4` | File op via core. |
| 35 | `[028C]` | `DEF0:E21A` | `0xED11A` | File service (standalone). |
| 36 | `[0290]` | `DEF0:E232` | `0xED132` | File service (standalone). |
| 37 | `[0294]` | `DEF0:E254` | `0xED154` | File op via core. |
| 38 | `[0298]` | `DEF0:E26C` | `0xED16C` | File op via core. |
| 39 | `[029C]` | `DEF0:57EF` | `0xE46EF` | Combined display render + file init. |

## 21. DEF0 Service Entry Points

### Wrapper Functions (DEF0:000B-00F9)

| Address | File offset | Description |
| --- | ---: | --- |
| `DEF0:000B` | `0xDEF0B` | Wrapper: calls `DEF0:CE03`. Called from `C000:1506`. |
| `DEF0:0019` | `0xDEF19` | Wrapper: calls `DEF0:CE6A`. Called from `C000:1523`. |
| `DEF0:0027` | `0xDEF27` | Wrapper: calls `DEF0:CE36`. Called from `C000:1506`. |
| `DEF0:0035` | `0xDEF35` | Wrapper: calls `DEF0:CE92`. Called from `C000:1929`. |
| `DEF0:0043` | `0xDEF43` | INT 21h AH=08h: keyboard char input (no echo). Returns AL; checks `0xEB` special. |
| `DEF0:0063` | `0xDEF63` | INT 21h AH=0Bh: check keyboard input status. |
| `DEF0:0074` | `0xDEF74` | INT 21h AH=2Ah: get date; stores to `[18E3..18E9]`. Near RET. |
| `DEF0:0098` | `0xDEF98` | INT 21h AH=2Ch: get time; stores to `[18EB..18F1]`. |
| `DEF0:00B8` | `0xDEFB8` | Flow-control helper: calls `DEF0:0098`. Called from `ED1B:0E51`. |
| `DEF0:00BC` | `0xDEFBC` | Service helper called from `DEF0:9DE1`. |
| `DEF0:00D9` | `0xDEFD9` | Service helper called from `DEF0:9DE1`. |
| `DEF0:00F9` | `0xDEFF9` | INT 21h AH=2Bh: set date. Called from `ED1B:0EB1`. |
| `DEF0:010D` | `0xDF00D` | Service helper called from `DEF0:8987`. |

### Display Rendering (DEF0:0D80-1B00)

| Address | File offset | Description |
| --- | ---: | --- |
| `DEF0:0D80` | `0xDFC80` | Display init: renders 15-byte script from `DEF0:EFFE` via `C000:3F35`. |
| `DEF0:0D91` | `0xDFC91` | Build display script from params. Called from `ED1B:0D63`. |
| `DEF0:0DF5` | `0xDFCF5` | Display page setup (FF 44 command). Large routine, 402 bytes. |
| `DEF0:0F87` | `0xDFE87` | Display mode dispatch (CX=1..4). |
| `DEF0:101E` | `0xDFF1E` | Display helper. |
| `DEF0:115C` | `0xE005C` | Display subsystem query/init. |
| `DEF0:1471` | `0xE0371` | Display area compute. |
| `DEF0:15B0` | `0xE04B0` | Display helper. |
| `DEF0:1639` | `0xE0539` | Display script builder, calls `C000:3F35`. |
| `DEF0:1775` | `0xE0675` | Set display callback pointers. |
| `DEF0:1806` | `0xE0706` | Display parameter config. |
| `DEF0:1B00` | `0xE0A00` | Display composite service. |

### Application/Menu Services (DEF0:2097-2EAB)

| Address | File offset | Description |
| --- | ---: | --- |
| `DEF0:2097` | `0xE0F97` | Display state query. |
| `DEF0:2435` | `0xE1335` | Display callback target. |
| `DEF0:2761` | `0xE1661` | Display far-call helper: calls `DEF0:115C`. Called from `C772:E801`. |
| `DEF0:2EAB` | `0xE1DAB` | File + display helper: calls `C000:3F35`, `DEF0:0DF5`. |

### File/Storage Services (DEF0:32D8-5C7C)

| Address | File offset | Description |
| --- | ---: | --- |
| `DEF0:32D8` | `0xE21D8` | Display mode + file dispatch: calls `DEF0:0F87`, `DEF0:0FE4`, `DEF0:0D91`. |
| `DEF0:330E` | `0xE220E` | File service: calls `C000:3F35`. |
| `DEF0:3F22` | `0xE2E22` | File dispatch caller. |
| `DEF0:3F3C` | `0xE2E3C` | File dispatch caller. |
| `DEF0:462D` | `0xE352D` | File helper caller. |
| `DEF0:5614` | `0xE4514` | File service: calls `C000:3F35`. |
| `DEF0:57EF` | `0xE46EF` | Combined display render + file init. Called from `C772:9555`. |
| `DEF0:5B03` | `0xE4A03` | App reinit: called from `C000:018A` (cold reinit), `C000:0303` (warm resume). |
| `DEF0:5BD1` | `0xE4AD1` | Called from `C772:7499`: calls `DEF0:32A4`. |
| `DEF0:5C07` | `0xE4B07` | Cold init: calls `EE17:16C1`, `DEF0:A718`, `DEF0:6278`, `DEF0:88E2`, `DEF0:C11C`. Called from `C000:0085`. |
| `DEF0:5C2E` | `0xE4B2E` | Warm reinit: calls `DEF0:5C07`, `DEF0:115C`, `EE17:16CA`. Called from `C772:84E8`. |

### Storage Subsystem (DEF0:6278-A600)

| Address | File offset | Description |
| --- | ---: | --- |
| `DEF0:6278` | `0xE5178` | Storage init subroutine called from `DEF0:5C07`. |
| `DEF0:65C8` | `0xE54C8` | Storage service: calls `C000:3F35` x2. |
| `DEF0:662F` | `0xE552F` | Storage dispatch caller. |
| `DEF0:6913` | `0xE5813` | Storage service. |
| `DEF0:6C8C` | `0xE5B8C` | Storage dispatch caller. |
| `DEF0:7D60` | `0xE6C60` | File dialog helper. |
| `DEF0:7DE6` | `0xE6CE6` | File dialog helper, calls `DEF0:C455`. |
| `DEF0:7F07` | `0xE6E07` | File dialog helper. |
| `DEF0:8082` | `0xE6F82` | File dialog dispatch. |
| `DEF0:85E2` | `0xE74E2` | File dialog caller. |
| `DEF0:88E2` | `0xE77E2` | Service init subroutine called from `DEF0:5C07`. |
| `DEF0:8987` | `0xE7887` | Service dispatch caller. |
| `DEF0:8AB4` | `0xE79B4` | Storage helper. |
| `DEF0:8FC0` | `0xE7EC0` | Storage helper. |
| `DEF0:9058` | `0xE7F58` | Storage init: calls `DEF0:0074`, `DEF0:0098`. |
| `DEF0:90B8` | `0xE7FB8` | Storage service body. |
| `DEF0:92C4` | `0xE81C4` | Storage service: calls `DEF0:0DF5`. |
| `DEF0:9BFC` | `0xE8AFC` | Storage dispatch caller. |
| `DEF0:9DE1` | `0xE8CE1` | Service dispatcher. |
| `DEF0:A4F8` | `0xE93F8` | Storage service. |
| `DEF0:A600` | `0xE9500` | Storage dispatch caller. |
| `DEF0:A718` | `0xE9618` | Storage init subroutine called from `DEF0:5C07`. |
| `DEF0:AA59` | `0xE9959` | Storage service caller. |
| `DEF0:AAEF` | `0xE99EF` | Storage service caller. |

### Printer/Output Services (DEF0:B0BF-BDBC)

| Address | File offset | Description |
| --- | ---: | --- |
| `DEF0:B0BF` | `0xE9FBF` | Printer service: calls `DEF0:1471` x6. |
| `DEF0:B4A3` | `0xEA3A3` | Printer/file service. |
| `DEF0:B4E6` | `0xEA3E6` | Printer/file service. |
| `DEF0:B5E7` | `0xEA4E7` | Printer service. |
| `DEF0:B618` | `0xEA518` | Printer dispatch caller. |
| `DEF0:B8FC` | `0xEA7FC` | Printer service: calls `DEF0:0D80`, multiple `DEF0:0DF5`. |
| `DEF0:B9A2` | `0xEA8A2` | Printer service. |
| `DEF0:BA28` | `0xEA928` | Printer service. |
| `DEF0:BA57` | `0xEA957` | Printer dispatch caller. |
| `DEF0:BC16` | `0xEAB16` | Printer service. |
| `DEF0:BD6F` | `0xEAC6F` | Printer dispatch caller. |
| `DEF0:BDBC` | `0xEACBC` | Printer dispatch caller. |

### Power/RTC Services (DEF0:C11C-CD8B)

| Address | File offset | Description |
| --- | ---: | --- |
| `DEF0:C11C` | `0xEB01C` | Service init subroutine called from `DEF0:5C07`. |
| `DEF0:C3B9` | `0xEB2B9` | RTC helper called from `DEF0:C5BC`. |
| `DEF0:C455` | `0xEB355` | RTC/power helper. |
| `DEF0:C5BC` | `0xEB4BC` | RTC init: calls `DEF0:0074`, `DEF0:0098`, `DEF0:C3B9`. Called from `C000:0498`/`C000:08DB`. |
| `DEF0:C879` | `0xEB779` | Power/RTC helper. |
| `DEF0:CC59` | `0xEBB59` | Power management service. |
| `DEF0:CD5F` | `0xEBC5F` | Power-down handler: called when RTC abnormal during boot. |
| `DEF0:CD6F` | `0xEBC6F` | Framebuffer save for power-down. |
| `DEF0:CD8B` | `0xEBC8B` | Power management dispatch. |
| `DEF0:CDED` | `0xEBCED` | Framebuffer restore from power-down. |

### Display Rendering Engine (DEF0:CE03-DA1B)

| Address | File offset | Description |
| --- | ---: | --- |
| `DEF0:CE03` | `0xEBD03` | Display render: calls `DEF0:0D80`, `DEF0:D234`. |
| `DEF0:CE36` | `0xEBD36` | Display render variant (called from wrapper `DEF0:0027`). |
| `DEF0:CE6A` | `0xEBD6A` | Display render variant (called from wrapper `DEF0:0019`). |
| `DEF0:CE92` | `0xEBD92` | Display render variant (called from wrapper `DEF0:0035`). |
| `DEF0:CF36` | `0xEBE36` | Cursor/display state helper. |
| `DEF0:CF3B` | `0xEBE3B` | Cursor/display state helper. |
| `DEF0:CF40` | `0xEBE40` | Cursor/display state helper. |
| `DEF0:CF45` | `0xEBE45` | Cursor/display state helper. |
| `DEF0:CFCF` | `0xEBECF` | Display buffer write: calls `C000:3F35`. |
| `DEF0:CFDE` | `0xEBEDE` | Display state byte writer. |
| `DEF0:D135` | `0xEC035` | Display buffer large write: calls `C000:3F35`. |
| `DEF0:D187` | `0xEC087` | Cursor position helper: calls `DEF0:CFDE` x2. |
| `DEF0:D19A` | `0xEC09A` | Cursor position helper: calls `DEF0:CFDE` x2. |
| `DEF0:D234` | `0xEC134` | Display render body. |
| `DEF0:D247` | `0xEC147` | Display state update. |
| `DEF0:D33F` | `0xEC23F` | Display dispatch helper. |
| `DEF0:D344` | `0xEC244` | Display dispatch helper: calls `DEF0:CFDE` x2. |
| `DEF0:D5B4` | `0xEC4B4` | Cursor/display helper. |
| `DEF0:D5B9` | `0xEC4B9` | Cursor/display helper: calls `DEF0:CFDE`, `DEF0:D984`. |
| `DEF0:D58F` | `0xEC48F` | Cursor/display helper. |
| `DEF0:D5C0` | `0xEC4C0` | Cursor/display helper. |
| `DEF0:D5D6` | `0xEC4D6` | Cursor/display helper. |
| `DEF0:D5EA` | `0xEC4EA` | Cursor/display helper. |
| `DEF0:D60D` | `0xEC50D` | Cursor + display init: calls `DEF0:CFDE`, `DEF0:0D80`. |
| `DEF0:D94D` | `0xEC84D` | Display helper. |
| `DEF0:D95A` | `0xEC85A` | Display helper: calls `DEF0:CFDE` x2. |
| `DEF0:D96D` | `0xEC86D` | Display buffer write: calls `C000:3F35`. |
| `DEF0:D984` | `0xEC884` | Display buffer large write: calls `C000:3F35`. |

### Miscellaneous (DEF0:DA1B-E296)

| Address | File offset | Description |
| --- | ---: | --- |
| `DEF0:DAD6` | `0xEC9D6` | File service entry #16. |
| `DEF0:DB47` | `0xECA47` | File service entry #17. |
| `DEF0:DFD5` | `0xECED5` | File service core (shared by 13 entries). |
| `DEF0:E022` | `0xECF22` | File service entry #18. |
| `DEF0:E048` | `0xECF48` | File service entry #20. |
| `DEF0:E05A` | `0xECF5A` | File service entries #21/#22. |
| `DEF0:E070` | `0xECF70` | File service entry #23. |
| `DEF0:E08C` | `0xECF8C` | File helper (entries #19, #24, #27, #28). |
| `DEF0:E0A4` | `0xECFA4` | File service entry #25. |
| `DEF0:E0C0` | `0xECFC0` | File service entry #29. |
| `DEF0:E119` | `0xED019` | Service helper called from `DEF0:DD60`. |
| `DEF0:E14C` | `0xED04C` | File service helper (called by entry #17). |
| `DEF0:E1F0` | `0xED0F0` | File service entry #32. |
| `DEF0:E195` | `0xED095` | File service entry #33. |
| `DEF0:E1B4` | `0xED0B4` | File service entry #34. |
| `DEF0:E21A` | `0xED11A` | File service entry #35. |
| `DEF0:E232` | `0xED132` | File service entry #36. |
| `DEF0:E254` | `0xED154` | File service entry #37. |
| `DEF0:E26C` | `0xED16C` | File service entry #38. |
| `DEF0:E288` | `0xED188` | Service helper called from `DEF0:39E3`. |
| `DEF0:E28E` | `0xED18E` | Service helper called from `DEF0:459B`. |

## 22. EE17/EF8A Utility

### EE17 Printer/Spelling Services

| Address | File offset | Description |
| --- | ---: | --- |
| `EE17:0009` | `0xEE179` | File I/O helper: calls `C000:3F35` x3. |
| `EE17:0047` | `0xEE1B7` | Data buffer init/reset. |
| `EE17:0060` | `0xEE1D0` | Data processing body. |
| `EE17:00FD` | `0xEE26D` | File read loop: calls `C000:3F35`. |
| `EE17:03DE` | `0xEE54E` | File write helper: calls `C000:3F35`. |
| `EE17:076E` | `0xEE8DE` | File service: calls `C000:3F35`. |
| `EE17:07FE` | `0xEE96E` | File + data service: calls `C000:3F35`, `EE17:0060`. |
| `EE17:0817` | `0xEE987` | Data compare helper. |
| `EE17:0847` | `0xEE9B7` | Data scan helper. |
| `EE17:087A` | `0xEE9EA` | Data match helper. |
| `EE17:08AD` | `0xEEA1D` | Data buffer reader. |
| `EE17:08E1` | `0xEEA51` | Data validation. |
| `EE17:091B` | `0xEEA8B` | Data lookup. |
| `EE17:0943` | `0xEEAB3` | Data scanner. |
| `EE17:098B` | `0xEEAFB` | Data lookup variant. |
| `EE17:09D1` | `0xEEB41` | Data validation variant. |
| `EE17:0A1F` | `0xEEB8F` | Data match variant. |
| `EE17:0A4D` | `0xEEBBD` | Data scan variant. |
| `EE17:0A78` | `0xEEBE8` | Data process: calls `EE17:0A4D`, `EE17:0047`. |
| `EE17:0AF4` | `0xEEC64` | Data dispatch. |
| `EE17:0BA0` | `0xEED10` | Data service: calls `EE17:08AD`, `EE17:08E1`. |
| `EE17:0BF9` | `0xEED69` | Data service body. |
| `EE17:0C49` | `0xEEDB9` | Data service body. |
| `EE17:0C5F` | `0xEEDCF` | Data service body. |
| `EE17:0C76` | `0xEEDE6` | Data service dispatch. |
| `EE17:0C87` | `0xEEDF7` | Data service: calls `EE17:08AD`, `EE17:087A`, `EE17:0BA0`. |
| `EE17:0CB3` | `0xEEE23` | Data service. |
| `EE17:0D9E` | `0xEEF0E` | Data service. |
| `EE17:0E9E` | `0xEF00E` | Data service: calls `C000:3F35`. |
| `EE17:0EAC` | `0xEF01C` | Data service: calls `C000:3F35`, `EE17:0BA0`, `EE17:08AD`. |
| `EE17:0F54` | `0xEF0C4` | Data service. |
| `EE17:103B` | `0xEF1AB` | Main service dispatcher: calls `EE17:07FE`, `EE17:0009`, `EE17:076E`, `DEF0:0043`. |
| `EE17:1103` | `0xEF273` | Process entry: calls `EE17:0A78`, `EE17:0E9E`. |
| `EE17:1411` | `0xEF581` | File service: calls `C000:3F35`, `EF8A:00F0`. |
| `EE17:16B9` | `0xEF829` | Service cleanup/exit. |
| `EE17:16C1` | `0xEF831` | Cold init entry: calls `EE17:0047`. Called from `DEF0:5C07`. |
| `EE17:16CA` | `0xEF83A` | Warm reinit entry: calls `DEF0:0D80`, `DEF0:0DF5`, `EE17:0047`, `EE17:03DE`, `EE17:07FE`, `EE17:103B`. Called from `DEF0:5C2E`. |

### EF8A Pattern Matcher

| Address | File offset | Description |
| --- | ---: | --- |
| `EF8A:000F` | `0xEF8AF` | Pattern element reader. |
| `EF8A:0020` | `0xEF8C0` | Pattern element reader variant. |
| `EF8A:0037` | `0xEF8D7` | Pattern element reader variant. |
| `EF8A:0057` | `0xEF8F7` | Pattern element reader variant. |
| `EF8A:007B` | `0xEF91B` | Pattern loop entry. |
| `EF8A:00B6` | `0xEF956` | Pattern element reader variant. |
| `EF8A:00F0` | `0xEF990` | Pattern matcher entry: called from `EE17:1411`. |
| `EF8A:010E` | `0xEF9AE` | Pattern match: calls `EE17:0A4D`, `EE17:0047`. |
| `EF8A:0123` | `0xEF9C3` | Pattern matcher body: calls multiple element readers. |
| `EF8A:01B8` | `0xEFA58` | Pattern matcher continuation. |

## 23. ED1B Bank Switch

| Address | File offset | Description |
| --- | ---: | --- |
| `ED1B:0D25` | `0xEDE45` | Bank switch entry: calls `AD00:009A`. Called from `DEF0:27B9`. |
| `ED1B:0D63` | `0xEDE83` | Bank switch service: calls `DEF0:0D91`. Called from AD00 opcodes. |
| `ED1B:0DB3` | `0xEDED3` | Bank switch service: calls `DEF0:0D80`. Called from `AD00:0288`. |
| `ED1B:0E1E` | `0xEDF3E` | Bank switch service. Called from AD00 display ops. |
| `ED1B:0E51` | `0xEDF71` | Bank switch service: calls `DEF0:00B8`. Called from `AD00:1F4E`. |
| `ED1B:0E81` | `0xEDFA1` | Bank switch service: calls `DEF0:0043`. Called from AD00 input ops. |
| `ED1B:0EB1` | `0xEDFD1` | Bank switch service: calls `DEF0:00F9`. Called from `AD00:1270`. |
| `ED1B:0EE9` | `0xEE009` | Bank switch service: calls `DEF0:0063`. Called from AD00 status ops. |
| `ED1B:0F1A` | `0xEE03A` | Bank switch helper. Called from `AD00:0577`. |
| `ED1B:0F4C` | `0xEE06C` | Bank switch helper. Called from `AD00:0577`. |

## 24. AD00 ROM Card

### Dispatcher

| Address | File offset | Description |
| --- | ---: | --- |
| `AD00:009A` | `0xAD09A` | ROM card init: sets up state at `[1B02..1B24]`, calls `AD00:00FC`. RETF. |
| `AD00:00FC` | `0xAD0FC` | ROM card dispatcher: main loop calling opcode handlers. |
| `AD00:0108` | `0xAD108` | Dispatcher loop body. |

### Opcode Handlers

| Address | File offset | Description |
| --- | ---: | --- |
| `AD00:0164` | `0xAD164` | ad00_op_0: calls `AD00:0BCE`. |
| `AD00:016A` | `0xAD16A` | ad00_op_1: calls `AD00:122A`. |
| `AD00:0170` | `0xAD170` | ad00_op_2: calls `AD00:051E`. |
| `AD00:0176` | `0xAD176` | ad00_op_20: calls `AD00:0536`. |
| `AD00:017C` | `0xAD17C` | ad00_op_3: calls `AD00:1806` (display output). |
| `AD00:0182` | `0xAD182` | ad00_op_4: direct continuation. |
| `AD00:0191` | `0xAD191` | ad00_op_5: calls `AD00:0242` (key input). |
| `AD00:0197` | `0xAD197` | ad00_op_6: calls `AD00:044A`. |
| `AD00:019D` | `0xAD19D` | ad00_op_7: calls `AD00:116A`. |
| `AD00:01A3` | `0xAD1A3` | ad00_op_8: calls `AD00:0A30` (display with data). |
| `AD00:01A9` | `0xAD1A9` | ad00_op_9: no-op / placeholder. |
| `AD00:01AC` | `0xAD1AC` | ad00_op_10: calls `AD00:0EA0` (display output). |
| `AD00:01B2` | `0xAD1B2` | ad00_op_11: calls `AD00:0892`. |
| `AD00:01B8` | `0xAD1B8` | ad00_op_12: calls `AD00:183C` (display output). |
| `AD00:01BE` | `0xAD1BE` | ad00_op_13: calls `AD00:1866`. |
| `AD00:01C4` | `0xAD1C4` | ad00_op_14: calls `AD00:199A`. |
| `AD00:01CA` | `0xAD1CA` | ad00_op_15: calls `AD00:0A5C` (display with data). |
| `AD00:01D0` | `0xAD1D0` | ad00_op_16: calls `AD00:0ED0` (display + string output). |
| `AD00:01D6` | `0xAD1D6` | ad00_op_17: calls `AD00:1B5A`. |
| `AD00:01DC` | `0xAD1DC` | ad00_op_18: calls `AD00:1D92`. |
| `AD00:01E2` | `0xAD1E2` | ad00_op_19: calls `AD00:1554`. |

### AD00 Service Routines

| Address | File offset | Description |
| --- | ---: | --- |
| `AD00:003C` | `0xAD03C` | String length helper (strlen). Called from `AD00:1408`. |
| `AD00:0058` | `0xAD058` | Integer-to-string formatter. Called from `AD00:066E`. |
| `AD00:0242` | `0xAD242` | Key input handler: calls `C000:75FD`, `ED1B:0EE9`. |
| `AD00:044A` | `0xAD44A` | Service routine: calls `C000:75FD`. |
| `AD00:051E` | `0xAD51E` | Service routine: calls `AD00:0536`. |
| `AD00:0536` | `0xAD536` | Service routine: calls `C000:75FD` x2, `ED1B:0F1A`, `ED1B:0F4C`. |
| `AD00:0892` | `0xAD892` | Service routine. |
| `AD00:0A30` | `0xADA30` | Display with data: calls `C000:75FD`, `AD00:1FD2`. |
| `AD00:0A5C` | `0xADA5C` | Display with data: calls `C000:75FD`. |
| `AD00:0B76` | `0xADB76` | Display helper: calls `ED1B:0D63`. |
| `AD00:0BCE` | `0xADBCE` | Service routine for op_0. |
| `AD00:0EA0` | `0xADEA0` | Display output: calls `C000:75FD`, `AD00:1E44`, `AD00:1E6C`. |
| `AD00:0ED0` | `0xADED0` | Display + string: calls `C000:75FD`, `C000:75B5`. |
| `AD00:116A` | `0xAE16A` | Service routine for op_7. |
| `AD00:122A` | `0xAE22A` | Service routine for op_1. |
| `AD00:1554` | `0xAE554` | Service routine for op_19. |
| `AD00:1806` | `0xAE806` | Display output: calls `C000:75FD`, `AD00:1E44`, `AD00:1E6C`. |
| `AD00:183C` | `0xAE83C` | Display output: calls `C000:75FD`. |
| `AD00:1866` | `0xAE866` | Service routine for op_13. |
| `AD00:199A` | `0xAE99A` | Service routine for op_14. |
| `AD00:1B5A` | `0xAEB5A` | Service routine for op_17: calls `C000:75FD`. |
| `AD00:1D92` | `0xAED92` | Service routine for op_18. |
| `AD00:1E44` | `0xAEE44` | Display helper: calls `ED1B:0D63`. |
| `AD00:1E6C` | `0xAEE6C` | Display helper: calls `C000:75B5`. |
| `AD00:1F4E` | `0xAEF4E` | Input helper: calls `ED1B:0E51`. |
| `AD00:1FD2` | `0xAEFD2` | Data display: calls `AD00:2000`. |
| `AD00:2000` | `0xAF000` | Data display body. |
| `AD00:2116` | `0xAF116` | Display helper. |
| `AD00:2176` | `0xAF176` | Display helper: calls `ED1B:0E1E`. |
| `AD00:21BC` | `0xAF1BC` | Display helper: calls `AD00:2176`. |
| `AD00:223E` | `0xAF23E` | Display helper. |

## 25. Far-Call Targets (Cross-Segment)

Summary of confirmed far-call targets called from a different segment.

| Target | Callers | Description |
| --- | --- | --- |
| `DEF0:5C07` | `C000:0085` | Cold init. |
| `DEF0:5B03` | `C000:018A`, `C000:0303` | App reinit / warm resume. |
| `DEF0:C5BC` | `C000:0498`, `C000:08DB` | RTC init. |
| `DEF0:CD5F` | `C000:0A69`, `C000:08B4` | Power-down handler. |
| `C772:0004` | `C000:018A` | Application entry (cold). |
| `C772:0008` | `C000:01DF` | Application entry (warm). |
| `C772:8411` | `C000:58B8` | Display callback during file ops. |
| `C000:19C3` | `C772:970F` | Banked thunk entry (from C772). |
| `C000:19C7` | `C772:9715` | Banked thunk entry (from C772). |
| `C000:3F35` | `DEF0:0D80` + far-call table | Display script renderer. |
| `C000:75FD` | AD00 opcodes | Display render for ROM card. |
| `C000:75B5` | AD00 opcodes | String output for ROM card. |
| `AD00:009A` | `ED1B:0D25` | ROM card init. |
| `EE17:16C1` | `DEF0:5C07` | EE17 cold init. |
| `EE17:16CA` | `DEF0:5C2E` | EE17 warm reinit. |
| `EF8A:00F0` | `EE17:1411` | Pattern matcher entry. |
