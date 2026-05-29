# Entry Points

## Confirmed Entries

| Address | File offset | Meaning |
| --- | ---: | --- |
| `FFFF:0000` | `0x7FFF0` | CPU reset vector. Jumps to `F8DC:0000`. |
| `F8DC:0000` | `0x78DC0` | Reset trampoline. Initializes ports `0x16`/`0x17`, then jumps to `C000:0000`. |
| `C000:0000` | `0x40000` | Main startup entry. Begins with `jmp C000:0029`. |
| `C000:0006` | `0x40006` | `INT 21h` vector target installed by `C000:0ED6`; jumps to `C000:5098`. |
| `C000:0009` | `0x40009` | IRQ `F8` stub, jumps to `C000:03AE` for save/suspend context. |
| `C000:000C` | `0x4000C` | IRQ `F9` stub, jumps to `C000:049A`. |
| `C000:000F` | `0x4000F` | IRQ `FA` stub, jumps to `C000:04AE`. |
| `C000:0012` | `0x40012` | IRQ `FB` stub, jumps to `C000:04D1`; keyboard row scan path. |
| `C000:0015` | `0x40015` | IRQ `FC` stub, jumps to `C000:0550`. |
| `C000:0018` | `0x40018` | IRQ `FD` stub, jumps to `C000:0724`. |
| `C000:001B` | `0x4001B` | IRQ `FE` stub, jumps to `C000:0738`. |
| `C000:001E` | `0x4001E` | IRQ `FF` stub, jumps to `C000:02EE` wake/reset-ish handler. |
| `C000:02EE` | `0x402EE` | Warm IRQ path; checks diagnostic chord and sets resume state. |
| `C000:03AE` | `0x403AE` | Save/suspend context path. Stores general registers and far return state under `6D65..6D87`. |
| `C000:04DD` | `0x404DD` | Keyboard scan ISR stores raw rows at RAM `6D06..6D0F`. |
| `C000:0550` | `0x40550` | IRQ `FC` serial receive ISR. Reads status/control port `0xC1`, reads received data from `0xC0`, and queues bytes via `C000:4BED`. |
| `C000:0738` | `0x40738` | IRQ `FE` Centronics ACK handler. Clears IRQ source bit `0x02`, emits the next byte from `[6D92]` through port `0x40`, and pulses port `0x30` bit `0x20`. |
| `C000:077C` | `0x4077C` | Far-call buzzer preview wrapper. Calls `C000:0B16` with `AL` selecting a sound sequence. |
| `C000:07E9` | `0x407E9` | LCD/framebuffer copy candidate, `0x1000 -> 0x94F0`. |
| `C000:07F4` | `0x407F4` | LCD/framebuffer copy candidate, `0x94F0 -> 0x1000`. |
| `C000:08E7` | `0x408E7` | Centronics idle helper. Writes `0xFF` to parallel data port `0x40`. |
| `C000:08EC` | `0x408EC` | Centronics output starter. Enables the ACK-driven path, marks `[6DA4]=1`, and sends the first byte through `C000:0920`. |
| `C000:08DA` | `0x408DA` | Diagnostic gate on warm path. Calls `C000:1240`. |
| `C000:0920` | `0x40920` | Centronics direct byte output. Writes port `0x40`, waits for `0xA0` bit `0x02` to clear, then pulses port `0x30` bit `0x20` for strobe. |
| `C000:096A` | `0x4096A` | Tone helper. Programs sound divisor through ports `0x50`/`0x51`, gates output through `0x52`, and busy-waits for duration. |
| `C000:0A6A` | `0x40A6A` | Combined battery-warning status query. Returns `AL=1..3` for main, CR2032 retention, or PCMCIA SRAM-card battery low, or zero when none are active. |
| `C000:0A93` | `0x40A93` | Main battery low helper. Tests port `0xA0` bit `0x08` twice. |
| `C000:0AA4` | `0x40AA4` | CR2032 memory-retention battery low helper. Tests port `0xA0` bit `0x04` twice. |
| `C000:0AB2` | `0x40AB2` | PCMCIA SRAM-card battery low helper. Requires port `0xA0` bit `0x80` clear and bit `0x10` clear. |
| `C000:0AC4` | `0x40AC4` | PCMCIA card access/presence helper. Sets carry when port `0xA0` bit `0x80` is set. |
| `C000:0ACE` | `0x40ACE` | PCMCIA card write-protect helper candidate. Sets carry when port `0xA0` bit `0x40` is set. |
| `C000:0B16` | `0x40B16` | Table-driven buzzer sequence player used by the WP SYSTEM `POWER ON BUZZER` preview. |
| `C000:0ED6` | `0x40ED6` | Interrupt/vector setup. Fills most IVT entries with `C000:118B`, installs IRQ stubs, installs `INT 21h` as `C000:0006`, installs `INT 1` as `C000:157D`, and copies a far-call table to RAM `0x0200`. |
| `C000:1240` | `0x41240` | Diagnostic entry routine. Calls chord compare, then diagnostic UI/loop. |
| `C000:1252` | `0x41252` | Compares RAM `6D06..6D0F` with expected `SPACE+F+J` matrix bytes. |
| `C000:1272` | `0x41272` | Diagnostic draw/init routine. |
| `C000:128F` | `0x4128F` | Diagnostic command loop/parser. |
| `C000:170E` | `0x4170E` | Far-call service wrapper used by `C688:9364`; service `AH=06` reaches the resource/text renderer. |
| `C000:1712` | `0x41712` | Far-call service wrapper used by `C688:936A`; service `AH=01` reaches the `D59C` resource table reader. |
| `C000:18EE` | `0x418EE` | Resource table reader for `D59C` / file base `0x559C0`; indexes by `DL` resource ID. |
| `C000:18A1` | `0x418A1` | Banked spell/linguistic service helper. Temporarily maps `3000:0000` to ROM file `0x30000` and calls it. |
| `C000:1F17` | `0x41F17` | Private format helper. Selects target drive `8/9/10`, sets `BL=A5`, and calls `INT 21h AH=FF`. |
| `C000:2C4A` | `0x42C4A` | Private `INT 21h AH=FF` direct service. With `BL=A5`, formats built-in/card storage or jumps into the DreamLink-specific path. |
| `3000:0000` | `0x30000` | Banked spell/linguistic service thunk. Switches to segment `3C00` and dispatches through `3000:4AA6`. |
| `3000:4AA6` | `0x34AA6` | Banked service dispatcher using service IDs `0x00..0x59`. |
| `C000:3064` | `0x43064` | Private `INT 21h AX=4428` endpoint probe. Returns availability bits for built-in RAM, PCMCIA SRAM card, and DreamLink. |
| `C000:311E` | `0x4311E` | Private `INT 21h AX=4429` DreamLink finish/flush helper; returns success without action for non-DreamLink handles. |
| `C000:3C08` | `0x43C08` | Card-storage capacity probe used during format. Write-tests the banked card window in 32 KiB steps and records the detected count. |
| `C000:4A94` | `0x44A94` | Low-level keyboard/event idle routine. Restores IRQ mask to port `0x60`, executes `sti; hlt`, then returns. |
| `C000:4C39` | `0x44C39` | Battery-warning icon restore/clear helper. Restores the saved 48x40 screen area if a warning icon is active, then clears `[6D52]`. |
| `C000:4C4F` | `0x44C4F` | LCD/framebuffer copy candidate, `0x94F0 -> 0x131B`. |
| `C000:4C6E` | `0x44C6E` | LCD/framebuffer copy candidate, `0x131B -> 0x94F0`. |
| `C000:4C91` | `0x44C91` | Battery-warning poll/display state machine. Rotates `[6D52]` through main, CR2032, and PCMCIA SRAM-card battery warning slots. |
| `C000:4CDC` | `0x44CDC` | Force-display the main battery low warning icon. Sets `[6D52]=2`, saves the screen area, and draws icon index `0`. |
| `C000:4D07` | `0x44D07` | Draws a 48x40 battery warning icon selected by `AL` from the table at `C000:4D30`. |
| `C000:5098` | `0x45098` | `INT 21h` service dispatcher. Maps `AH` through byte table `C000:5000`, then calls handler from word table `C000:5060`. File services reach the FAT12-style handlers around `C000:29AD..3F1C`. |
| `C000:5AD6` | `0x45AD6` | Low-level resource/text renderer. Consumes staged bytes, expands glyphs, and writes rows into the framebuffer at `0x1000`. |
| `C000:6648` | `0x46648` | `FF 42` bitmap blit handler for startup resource records; uses row count, bit width, and source far pointer. |
| `C000:675D` | `0x4675D` | `FF 44` positioned region/line/fill-style resource handler; exact field meanings still need decoding. |
| `C688:000B` | `0x4688B` | Main firmware far entry used after cold boot initialization. |
| `C688:000F` | `0x4688F` | Warm-path application entry. Calls into `C688:7752`, bypassing full main startup and boot-update sequence. |
| `C688:0053` | `0x468D3` | Retained/warm RAM signature check; returns carry on mismatch. |
| `C688:01E6` | `0x46A66` | ROM-card execution setup. Prepares the `0xA4F0` load context, marks `[6D54]=1`, and returns `[7A54] * 0x80` as the loader's work-memory limit. |
| `C688:020C` | `0x46A8C` | ROM-card execution cleanup. Tears down the `0xA4F0` context and clears `[6D54]`. |
| `C688:022B` | `0x46AAB` | ROM-card executable trampoline. Calls the far entry pointer loaded at `[0xA4F4]`. |
| `C688:0240` | `0x46AC0` | Inline display/script interpreter entry; jumps to `C688:3879`. |
| `C688:29D9` | `0x49259` | Main application startup reached by `C688:000B`; clears UI work state and enters startup display path. |
| `C688:6B8C` | `0x4D40C` | Hands the copied `0x7F28` resource block to the `C000:170E` renderer service. |
| `C688:71A4` | `0x4DA24` | Selection/list wrapper using buffer `0x7555`; calls `C688:721D` for draw/setup and `C688:722F` for key handling. |
| `C688:721D` | `0x4DA9D` | Chooses `C688:9461` for `CL != 0` selectable menu/list drawing, otherwise calls `C688:9541` directly. |
| `C688:72E5` | `0x4DB65` | Selection/list wrapper variant used by several application submenu loops. |
| `C688:7766` | `0x4DFE6` | Startup display/update sequence that emits fixed update codes through `C688:77A3`. |
| `C688:77A3` | `0x4E023` | Individual boot update helper; switches display/profile state and applies the update. |
| `C688:77B4` | `0x4E034` | Copies first menu/graphic resource block from `C688:D133` / file `0x539B3`. |
| `C688:77C1` | `0x4E041` | Copies a `C688` resource block to low RAM `0x7F28`, then calls `C688:6B8C`. |
| `C688:8312` | `0x4EB92` | First menu/input dispatcher reached after the startup menu resource is copied. |
| `C688:92DF` | `0x4FB5F` | Inline key dispatch trampoline. Consumes caller-embedded key/target entries and rewrites the return address. |
| `C688:9364` | `0x4FBE4` | Far-call wrapper for `C000:170E`. |
| `C688:93B5` | `0x4FC35` | Keyboard/event wrapper; calls `C688:5358` and stores the returned byte in `[0x794A]`. |
| `C688:9461` | `0x4FCE1` | Selectable menu/list drawing layer. Calls the cached `AL=5` path in `C688:9541`, then runs inline `C688:0240` scripts for per-item work. |
| `C688:9541` | `0x4FDC1` | Screen resource loader used by menu setup wrappers such as `C688:7689`. Loads resource IDs or CS pointer blocks into `0x7F28` and interprets their payload. |
| `C688:96E1` | `0x4FF61` | Invalidates the `C688:9541` `AL=5` resource cache by setting `[7574]`/`[7575]` to `FF`. |
| `C688:AAA6` | `0x51326` | WP `PRINTER` -> `PRINT OUT` flow. Presents print dialogs/ranges and routes formatted output toward the printer emitter. |
| `C688:EC9F` | `0x5551F` | Shared application menu/event loop after first-screen branch setup. |
| `C000:0BFC` | `0x40BFC` | Builds the RS-232C USART async mode byte from `6D2B..6D2D`. |
| `C000:0C58` | `0x40C58` | Programs RS-232C: baud latch on port `0x30`, 8251-style reset/mode/command sequence on port `0xC1`, and IRQ/buffer state. |
| `C000:0CBC` | `0x40CBC` | Serial initialization wrapper. Validates `6D2A..6D2E`, then calls `C000:0C58`. |
| `C000:0D4F` | `0x40D4F` | Serial transmit-ready/status check using port `0xC1`. |
| `C000:0D96` | `0x40D96` | Serial transmit data helper; writes byte to port `0xC0`. |
| `C000:4B8D` | `0x44B8D` | Serial receive queue drain / software flow-control helper. Sends XON when space recovers. |
| `C000:4BED` | `0x44BED` | Serial receive queue insert helper. Sends XOFF/XON flow-control bytes when enabled. |
| `C000:41A8` | `0x441A8` | DreamLink serial peer probe. Temporarily forces `9600 8N1`, XON/XOFF disabled. |
| `DC98:0E81` | `0x5D801` | Text output helper used by the horizontal icon menu renderer for label text. |
| `DC98:1198` | `0x5DB18` | Horizontal icon menu key loop. Handles selection redraw, arrows, numeric shortcuts, and select/cancel-style keys. |
| `DC98:124C` | `0x5DBCC` | Horizontal icon menu renderer. Consumes compact icon/label tables and generates `FF 42` 40x40 bitmap blit records. |
| `DC98:22A1` | `0x5EC21` | Shared SET UP screen for printer `SET UP 2` and COMMUNICATE `SET UP`; edits RS-232C settings at `6D2A..6D2E`. |
| `DC98:24DB` | `0x5EE5B` | WP `PRINTER` -> `SET UP 1`; edits printer model, parallel/serial interface, and paper feed at `6D59..6D5B`. |
| `DC98:265D` | `0x5EFDD` | WP `PRINTER` submenu wrapper around `DC98:124C`. |
| `DC98:26B8` | `0x5F038` | WP `COMMUNICATE` submenu wrapper around `DC98:124C`. |
| `DC98:275A` | `0x5F0DA` | WP `FILE` submenu wrapper around `DC98:124C`. |
| `DC98:2807` | `0x5F187` | WP top icon menu wrapper around `DC98:124C`. |
| `DC98:2B75` | `0x5F4F5` | WP OTHERS -> ROM CARD loader. Finds `EROMCARD.X`, loads it at `0xA4F0`, validates header words `0xA4F0/0x1997`, then calls the loaded far entry pointer. |
| `DC98:2D2B` | `0x5F6AB` | WP `OTHERS` submenu wrapper around `DC98:124C`. |
| `DC98:455F` | `0x60EDF` | WP FILE -> COPY direction selector. Handles Built-in/Card/DreamLink copy directions. |
| `DC98:4D67` | `0x616E7` | Directory-list builder. Uses DOS find-first/find-next on `X:*.*`, reads standard DTA fields, sorts 19-byte records, and caps at 128 entries. |
| `DC98:52E5` | `0x61C65` | Document picker/list UI. Calls `DC98:4D67` to enumerate files and `DC98:4EAF`/`5198` to draw and navigate the list. |
| `DC98:53C3` | `0x61D43` | Organizer top icon menu wrapper around `DC98:124C`; stores selected index in `[82A6]`. |
| `DC98:E946` | `0x6B2C6` | File open wrapper used by the ROM-card loader before reading `EROMCARD.X`. |
| `DC98:EE08` | `0x6B788` | File read wrapper around DOS-like `int 21h AH=3F`; ROM-card loader reads into `0xA4F0` through this path. |
| `DC98:EE1B` | `0x6B79B` | File write wrapper around DOS-like `int 21h AH=40`. |
| `DC98:EE2E` | `0x6B7AE` | File close wrapper around DOS-like `int 21h AH=3E`. |
| `DC98:EE40` | `0x6B7C0` | File delete wrapper around DOS-like `int 21h AH=41`. |
| `DC98:EE56` | `0x6B7D6` | File rename wrapper around DOS-like `int 21h AH=56`. |
| `DC98:EE72` | `0x6B7F2` | File seek wrapper around DOS-like `int 21h AH=42`. |
| `DC98:EF7B` | `0x6B8FB` | Find-first wrapper. Sets caller DTA with `AH=1A`, then calls `AH=4E`; used to probe `EROMCARD.X`. |
| `DC98:EF9A` | `0x6B91A` | Find-next wrapper. Sets caller DTA with `AH=1A`, then calls `AH=4F`. |

## Boot Path

After the reset trampoline reaches `C000:0000`, startup initializes hardware and
RAM state, then checks for a retained warm state:

```asm
C000:0090  call far C688:0053   ; retained/warm RAM signature check
C000:0095  jc C000:00E1         ; cold boot if signature mismatch
C000:0097  call C000:47D3       ; validate warm state
C000:009A  jc C000:00E1         ; cold boot if invalid
```

Cold boot clears `[6D81]`, performs setup, and jumps into the main firmware:

```asm
C000:00E1  mov word [6D81],0000
...
C000:011A  jmp far C688:000B
```

The warm path can reach the diagnostic gate, and one non-diagnostic warm branch
jumps to the second application entry:

```asm
C000:0142  call C000:08DA
C000:015C  jmp far C688:000F
```

## Linear Branch Inventory

This is intentionally a linear disassembly scan, so entries inside inline data
must be treated as candidates until a function-boundary pass confirms them.

Command:

```sh
tools/rom2.py xrefs --start 0x40000 --end 0x50000 --format markdown --limit 20
```

Current high-traffic direct targets in the `C000` segment window:

| Count | Target | File | Ops |
| ---: | --- | ---: | --- |
| 121 | `C000:6AC0` | `0x46AC0` | `call` |
| 62 | `C000:C41A` | `0x4C41A` | `call,jmp` |
| 52 | `C000:A3E2` | `0x4A3E2` | `call,jmp` |
| 49 | `C000:AD44` | `0x4AD44` | `call` |
| 47 | `C000:DF09` | `0x4DF09` | `call` |
| 43 | `C000:A36B` | `0x4A36B` | `call` |
| 43 | `C000:C403` | `0x4C403` | `call,jmp` |
| 38 | `C000:0DC4` | `0x40DC4` | `call,jmp` |
| 34 | `C000:A3AF` | `0x4A3AF` | `call,jmp` |
| 33 | `C000:A38D` | `0x4A38D` | `call,jmp` |
| 28 | `C000:85FC` | `0x485FC` | `jmp` |
| 21 | `C000:0E3E` | `0x40E3E` | `call,jmp` |
| 21 | `C000:ACF3` | `0x4ACF3` | `call,jmp` |
| 18 | `C000:C414` | `0x4C414` | `call` |
| 17 | `C000:5AD6` | `0x45AD6` | `call,jmp` |
| 16 | `C000:89D0` | `0x489D0` | `jmp,jz` |
| 16 | `C000:957A` | `0x4957A` | `call,jmp` |
| 16 | `C000:9F68` | `0x49F68` | `call` |
| 15 | `C000:3B69` | `0x43B69` | `call` |
| 15 | `C000:C3FD` | `0x4C3FD` | `call` |

The noisy targets above are useful mostly as a warning: the linear scan is
already crossing data tables. Confirmed code should be promoted into the table
at the top of this file only after local disassembly and runtime behavior agree.
