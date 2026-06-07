# Confirmed Entry Points

Every label is derived from reading the actual instructions at each
address. File offsets use the banking model in [`map.md`](map.md). All
addresses are in the C000 window (port `0x16=0x01`, file base `0xC0000`)
unless noted.

## Reset and Startup

| Address | File offset | What it does |
| --- | --- | --- |
| `FFFF:0000` | `0xFFFF0` | `CLI; JMP FAR F6E3:0000`. |
| `F6E3:0000` | `0xF6E30` | Sets ports `0x16=0x01, 0x17=0x00`; `JMP FAR C000:0000`. |
| `C000:0000` | `0xC0000` | `JMP SHORT C000:0029`. |
| `C000:0029` | `0xC0029` | Sets bank ports 10/16/17, zeroes SS/DS/ES, writes hardware I/O ports 90/20/00/DE/DD/40, sets SP=6F00, calls IVT installer. |
| `C000:0065` | `0xC0065` | Compares 5 bytes at `[1000..1004]` against `CS:7799` ("218") + `CS:64CF`. |
| `C000:0085` | `0xC0085` | Stamps signature bytes from ROM into RAM `[1000..]`. |
| `C000:0096` | `0xC0096` | Cold-start: delays, seeds bank mirrors, clears RAM, inits storage/drives/subsystems, sets warm-retry flag and `[146F]=0x1995`. |
| `C000:00EC` | `0xC00EC` | Warm path: restores bank ports 11-15 from `[147B..147F]`. |
| `C000:0107` | `0xC0107` | Clears volatile state bytes, sets `[1109]=1`, calls state validation and enters decision tree. |

## Boot Decision Tree

| Address | File offset | What it does |
| --- | --- | --- |
| `C000:0148` | `0xC0148` | Tests `[1467]` against `0x0000, 0x320D, 0x30E7, 0x316D`; unrecognized -> C000:025E. |
| `C000:016C` | `0xC016C` | Compares `[1469]` with CS; mismatch -> C000:018A. Tests `[146F]`. |
| `C000:018A` | `0xC018A` | Renders "INITIALIZING" (C772:EDB0), clears RAM, reinits all subsystems, calls DEF0:5B03, `JMP FAR C772:0004`. |
| `C000:01DF` | `0xC01DF` | Three delays, seeds bank mirrors, clears framebuffer, checks keyboard chord (F+J+SPACE via C000:0AA0), then enters app via C772. |
| `C000:0220` | `0xC0220` | Clears keyboard state, does RTC check + display init (C000:0987), checks keyboard chord (C000:0AA0), verifies context checksum, resumes saved far pointer. |
| `C000:025E` | `0xC025E` | Alternate resume path when `[1467]` not recognized. |

## Keyboard Chord Check (F+J+SPACE)

| Address | File offset | What it does |
| --- | --- | --- |
| `C000:0AA0` | `0xC0AA0` | Calls C000:14D4; if chord held and diagnostic exited (CF=1), sets `[146F]=0x1995`. |
| `C000:14D4` | `0xC14D4` | Calls C000:14E6 to compare keyboard matrix. If match: renders diagnostic banner (C000:1506), enters command loop (C000:1523), loops until exit (CF=1). No match: returns CF=0. |
| `C000:14E6` | `0xC14E6` | `REPE CMPSB` comparing 10 bytes at `DS:[1306..130F]` (keyboard matrix from IRQ FB / port 0xB0) against `CS:[14FC..1505]`. Returns ZF=1 on match. |
| `CS:14FC` | `0xC14FC` | Chord pattern: `00 08 00 00 80 00 00 00 40 00` = ROW1 bit3 (SPACE) + ROW4 bit7 (F) + ROW8 bit6 (J). |

## RTC State Check

| Address | File offset | What it does |
| --- | --- | --- |
| `C000:0E13` | `0xC0E13` | Reads RTC ports `0xD0..0xDC` (RP5C01) into `[1484..1490]`, low nibble only. |
| `C000:0E43` | `0xC0E43` | Calls C000:0E13, compares 11 bytes from `[142C..1436]` against `[1490..1486]`. Returns CF=1 when month/day/hour registers are all zero (RTC uninitialized). |
| `C000:0E2F` | `0xC0E2F` | Secondary check: 7 bytes from `[1430..1436]` against `[148C..1486]`. |
| `C000:0E62` | `0xC0E62` | Calls C000:0E13, checks `[1484]` and `[1485]` both zero. Returns CF=1 if so. |
| `C000:0CA7` | `0xC0CA7` | Sets `[142C..142D]=0xFFFF`, `[1435..1436]=0xFFFF` (RTC check sentinels). Called from subsystem init. |
| `C000:0CB3` | `0xC0CB3` | Writes saved RTC time from `[1430..1436]` out to ports `0xD2..0xD8` (skipping `0xD6`). |
| `C000:0CE1` | `0xC0CE1` | Reads `[1486..1487]` (RTC minute digits), increments, writes to ports `0xD2..0xD3`. Advances the RTC minute register. |

## RTC + Display Init Path

| Address | File offset | What it does |
| --- | --- | --- |
| `C000:0987` | `0xC0987` | Calls C000:08AA (RTC gate). If CF=0: reads `[1334]`, calls display helper, two delays, restores framebuffer. |
| `C000:08AA` | `0xC08AA` | Checks `[1439]`. If set: calls C000:0953 (wait for RTC stable). If clear: calls C000:0E43 (RTC check). RTC normal -> C000:08D3 (display init). RTC abnormal -> calls DEF0:CD5F, may power down. |
| `C000:08D3` | `0xC08D3` | Secondary RTC check (C000:0E2F). If normal: calls DEF0:C5BC, saves framebuffer, renders 9 display scripts from C772 (copyright/product banners). Returns CF=0. |
| `C000:0953` | `0xC0953` | Calls C000:0E62 (check RTC registers clear). If clear: falls through to display init at C000:08E2. If not: powers down (C000:048C). |
| `C000:095B` | `0xC095B` | Calls C000:0CE1 (advance RTC minute), sets `[1439]=1`, halts. |

## Power Down and NMI

| Address | File offset | What it does |
| --- | --- | --- |
| `C000:0492` | `0xC0492` | `OUT 70,01` (RTC alarm enable); `JMP $` (infinite halt). |
| `C000:048C` | `0xC048C` | Calls C000:05A3 (save state), C000:0498 (RTC check + set [1439]), then falls through to C000:0492 halt. |
| `C000:0498` | `0xC0498` | Reads RTC via C000:0E43 and C000:0E2F. RTC normal: writes saved time back to RTC (C000:0CB3), clears `[1439]`. RTC abnormal: advances minute (C000:0CE1), sets `[1439]=1`. |
| `C000:04D0` | `0xC04D0` | NMI/IRQ F8 handler. Saves full context to `[1453..146D]`, checksums it (C000:055E), saves state (C000:05A3), halts. Early exit if `[1109]==1` or `0x1995`. |
| `C000:055E` | `0xC055E` | Sums 15 words at `[1453..1470]`, stores result at `[1471]`. |
| `C000:05A3` | `0xC05A3` | Copies `[1335]->[110B]`, copies interrupt mask shadow `[143A]->[143B]`, calls C000:0FB5 and C000:0E9F (if bit 4 of `[143A]` clear). |

## Context Save/Restore

| Address | File offset | What it does |
| --- | --- | --- |
| `C000:02A3` | `0xC02A3` | Recomputes context checksum, compares with `[1471]`. On match: restores bank ports 11-15 from `[147B..147F]`, restores BX/CX/DX/SI/DI/ES/BP from `[1455..145F]`. Returns CF=0. Mismatch: CF=1. |
| `C000:03EA` | `0xC03EA` | `REP STOSW` filling `[8000..8FFF]` with zero (clears 4 KiB framebuffer). |
| `C000:0969` | `0xC0969` | Calls C000:33E2, then copies `[8000..8FFF]` -> `[9000..9FFF]` (save framebuffer). |
| `C000:0974` | `0xC0974` | Copies `[9000..9FFF]` -> `[8000..8FFF]` (restore framebuffer). |
| `C000:0303` | `0xC0303` | Saves framebuffer (C000:0969), calls DEF0:5B03, restores framebuffer (C000:0974). Preserves `[1467]`. |

## Subsystem Init

| Address | File offset | What it does |
| --- | --- | --- |
| `C000:0327` | `0xC0327` | Writes `0F/1F/1E/1D/1C` to `[147B..147F]` (bank port mirror defaults for 1 MiB ROM). |
| `C000:03A5` | `0xC03A5` | Clears 0x400 bytes at `[AAFB..]` to zero. |
| `C000:03BB` | `0xC03BB` | Clears `[1006..CEEE]` to zero, skipping `[6D00..6F00]`. Fills `[0400..0FFE]` with `0x73`. |
| `C000:0571` | `0xC0571` | Sets DS=0x1800, checksums 0x7FFC words from `[0008]`, stores result at `[0006]`. |
| `C000:09B2` | `0xC09B2` | Three timed delays (calls C000:0B30 three times). |
| `C000:09CE` | `0xC09CE` | Calls C000:0DC5 with AL=4. Runs only when `[1473]==0x4D0` (previous NMI). |
| `C000:09D4` | `0xC09D4` | Renders display script from `C772:EDB0` ("INITIALIZING"), delays. |
| `C000:09EA` | `0xC09EA` | Two timed delays (calls C000:0B30 twice). |
| `C000:0B30` | `0xC0B30` | Timed delay: BX=outer count, CX=inner count. |
| `C000:2E2D` | `0xC2E2D` | Checks `[1337]==0x7CE`, validates `[1106]` against 8/9/A/B, calls four subroutines. Returns CF=1 if validation fails. |
| `C000:2E72` | `0xC2E72` | Sets `[1106]=8`, `[1339]=8`, calls RAM checksum verify (C000:0580), seeds bank mirrors, then chain of init subroutines. |
| `C000:4396` | `0xC4396` | Storage endpoint dispatch. Dispatches on BL (`0xA5`) and DL (`0x08`/`0x09`/`0x0A`/`0x0B`). |
| `C000:5600` | `0xC5600` | Fills `[6F5E..6F61]` with `0xFF`. |
| `C000:6523` | `0xC6523` | Sets `[16E6]=6`, `[16E5]=6`, calls two subroutines, initializes drive/file state words. |
| `C000:6557` | `0xC6557` | Render display script. SI=offset, CX=length, DX=segment. |
| `C000:12CC` | `0xC12CC` | Clears 20 bytes at `[1310..1323]`, clears state bytes, masks port 0x60 bits, pulses port 0x61 (keyboard scan edge), clears `[132D]`. |

## Interrupt Handlers

| Address | File offset | What it does |
| --- | --- | --- |
| `C000:1161` | `0xC1161` | Installs IVT: fills vectors `00h..F7h` with `C000:141F` (IRET), writes IRQ stubs F8h-FFh, overwrites INT 01h (`C000:1832`) and INT 21h (`C000:0006`), copies 41-entry far-call table to `[0200..029C]`. |
| `C000:141F` | `0xC141F` | Single IRET (default vector target). |
| `C000:1832` | `0xC1832` | INT 01h handler. |
| `C000:04D0` | `0xC04D0` | INT 02h (NMI) / IRQ F8. Saves context, checksums, halts. |
| `C000:6277` | `0xC6277` | INT 21h dispatch. Validity table at `C000:61DF`, dispatch table at `C000:623F`. |

## Interrupt Stubs (C000 Jump Table)

| Address | Jump target | IRQ |
| --- | --- | --- |
| `C000:0006` | `C000:6277` | INT 21h |
| `C000:0009` | `C000:04D0` | F8 — NMI |
| `C000:000C` | `C000:05C0` | F9 |
| `C000:000F` | `C000:05D4` | FA |
| `C000:0012` | `C000:05F7` | FB — keyboard row scan (reads port 0xB0 into `[1306+row]`) |
| `C000:0015` | `C000:0676` | FC |
| `C000:0018` | `C000:084A` | FD |
| `C000:001B` | `C000:085E` | FE |
| `C000:001E` | `C000:03FC` | FF — warm/power |

## Diagnostic Monitor

| Address | File offset | What it does |
| --- | --- | --- |
| `C000:131D` | `0xC131D` | Sets `[15A2]=1`, renders terminal banner from `C000:76F5` ("Terminal mode   press CAN to stop"), enters command loop. Reached via banked thunk dispatch table slot 7 at `C000:1B38`. |
| `C000:1341` | `0xC1341` | Command loop: polls keyboard (C000:3168), dispatches on key code. |
| `C000:1378` | `0xC1378` | Command dispatch table (7 entries). |
| `C000:13C5` | `0xC13C5` | Exit: clears `[15A2]`, returns. |
| `C000:13F5` | `0xC13F5` | Calls DEF0:000B, clears LCD (C000:0F6F), renders 47 bytes from `C000:76F5`, calls DEF0:0027 and DEF0:0019. |
| `C000:1420` | `0xC1420` | Software error halt. Sets `[1109]=0x1999`, renders "Internal software error. Please reset this computer and contact NTS." from `C000:1450`, halts with `JMP $`. NOT the diagnostic monitor. |
| `C000:1506` | `0xC1506` | Renders diagnostic entry banner from `C772:005D` (69 bytes). |
| `C000:1523` | `0xC1523` | Diagnostic UI command loop (separate from C000:1341 terminal monitor). Handles keys: `0x0B`/`0x02`/`0x03` exit, `0x3F` = help, `0x4B`/`0x6B` = commands, `0xDA` = special. |

## Banked Call Entries

| Address | File offset | What it does |
| --- | --- | --- |
| `C000:0021` | `0xC0021` | Calls `C000:19CB`, then RETF. |
| `C000:0025` | `0xC0025` | Calls `C000:1B28`, then RETF. |
| `C000:1B28` | `0xC1B28` | Dispatch table at `C000:1B38` (12 slots). Indexes on `AH`, jumps to handler. |
| Slot 7 | | `C000:131D` — diagnostic command monitor. |

## Far Call Targets

| Address | What it does |
| --- | --- |
| `DEF0:5C07` | Called during cold init and cold reinit. |
| `DEF0:5B03` | Called during cold reinit (C000:01C3), warm resume via C000:0303, and other paths. |
| `DEF0:C5BC` | Called before display init (C000:08DC) and during power-down RTC check (C000:049F). |
| `DEF0:CD5F` | Called when RTC is abnormal during boot (C000:08BF). |
| `C772:0004` | Application entry — cold start. |
| `C772:0008` | Application entry — warm resume. |
