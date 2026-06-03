# Entry Points

## Confirmed Entries

The table below is for the T400 v2.1 ROM unless noted otherwise.

| Address | File offset | Meaning |
| --- | ---: | --- |
| `FFFF:0000` | `0x7FFF0` | CPU reset vector. Jumps to `F8DC:0000`. |
| `F8DC:0000` | `0x78DC0` | Reset trampoline. Initializes ports `0x16`/`0x17`, then jumps to `C000:0000`. |
| `FFDF:0005` | `0x7FDF5` | High-ROM CSiMON monitor/loader entry candidate. Mirrors reset bank setup, writes `0x20` to port `0x20`, initializes buzzer/control/USART state, waits on serial input, sends `0x78` repeatedly, then enters a small `CS:`-relative dispatch/decode loop. With the bytes at `FFDF:0000`, the dispatcher reaches a far jump to `FC0A:07FA` / physical `0xFC89A`, near strings identifying `CSiMON-88 - Rommed V4.02`. Reachability is not yet known. |
| `C000:0000` | `0x40000` | Main startup entry. Begins with `jmp C000:0029`. |
| `C000:0006` | `0x40006` | `INT 21h` vector target installed by `C000:0ED6`; jumps to `C000:5098`. |
| `C000:0009` | `0x40009` | IRQ `F8` stub, jumps to `C000:03AE` for save/suspend context. |
| `C000:000C` | `0x4000C` | IRQ `F9` stub, jumps to `C000:049A`; very short acknowledge/flag-clear handler. |
| `C000:000F` | `0x4000F` | IRQ `FA` stub, jumps to `C000:04AE`; keyboard scan-cycle/reset helper. |
| `C000:0012` | `0x40012` | IRQ `FB` stub, jumps to `C000:04D1`; keyboard row scan path. |
| `C000:0015` | `0x40015` | IRQ `FC` stub, jumps to `C000:0550`; RS-232 receive path. |
| `C000:0018` | `0x40018` | IRQ `FD` stub, jumps to `C000:0724`; very short acknowledge/flag-clear handler. |
| `C000:001B` | `0x4001B` | IRQ `FE` stub, jumps to `C000:0738`; Centronics ACK-driven output path. |
| `C000:001E` | `0x4001E` | IRQ `FF` stub, jumps to `C000:02EE` warm/power-management handler. |
| `C000:02EE` | `0x402EE` | Warm/power-management IRQ path. Checks existing warm markers and diagnostic chord; either sets `[6809]=1992` and returns or prepares warm/diagnostic state before the `out 0x70,0x01` terminal loop. |
| `C000:035D` | `0x4035D` | Retained power-transition path used by auto-off and related suspend routes. Checksums saved state, prepares RTC alarm/power state, writes `0x01` to port `0x70`, then loops. |
| `C000:0376` | `0x40376` | RTC alarm/power-off preparation helper. Temporarily disables RTC timer advance, selects a stored alarm or current-minute+1 alarm, then enables the RP5C01 alarm bit. |
| `C000:03AE` | `0x403AE` | Save/suspend context path. Stores general registers and far return state under `6D65..6D87`. |
| `C000:044B` | `0x4044B` | Built-in store checksum helper used during retained power transition when `[7036] != 0`. Checksums `1800:0008..7FFF` into `1800:0006`. |
| `C000:047D` | `0x4047D` | Retained transition cleanup helper. Disarms the `F9` timer, reloads `[680B]` from `[6D31]`, snapshots `[6D4F]`, and performs serial cleanup if receive IRQs are enabled. |
| `C000:049A` | `0x4049A` | IRQ `F9` acknowledge handler. Clears port `0x90` bit `0x40`, clears `[6DA9]` bit `0x01`, then `iret`. Candidate simple periodic wake source. |
| `C000:04AE` | `0x404AE` | IRQ `FA` keyboard scan-cycle/reset helper. Updates the IRQ mask and calls `C000:106F` to reset keyboard row scan state. |
| `C000:04D1` | `0x404D1` | IRQ `FB` keyboard row scan ISR. Reads port `0xB0`, stores rows at `6D06..6D0F`, and calls `C000:5645` after the tenth row. |
| `C000:04DD` | `0x404DD` | Keyboard scan ISR stores raw rows at RAM `6D06..6D0F`. |
| `C000:0550` | `0x40550` | IRQ `FC` serial receive ISR. Reads status/control port `0xC1`, reads received data from `0xC0`, and queues bytes via `C000:4BED`. |
| `C000:0724` | `0x40724` | IRQ `FD` acknowledge handler. Clears port `0x90` bit `0x04`, clears `[70A5]` bit `0x08`, then `iret`. |
| `C000:0738` | `0x40738` | IRQ `FE` Centronics ACK handler. Clears IRQ source bit `0x02`, emits the next byte from `[6D92]` through port `0x40`, and pulses port `0x30` bit `0x20`. |
| `C000:077C` | `0x4077C` | Far-call buzzer preview wrapper. Calls `C000:0B16` with `AL` selecting a sound sequence. |
| `C000:0784` | `0x40784` | Alarm wake discriminator used after warm/startup paths. Checks `[6D4E]`, compares the RTC against the selected alarm buffer, and branches into alarm display or fallback re-arm handling. Can reprogram the minute+1 fallback alarm and jump to the terminal port `0x70` transition. |
| `C000:07E9` | `0x407E9` | LCD/framebuffer copy candidate, `0x1000 -> 0x94F0`. |
| `C000:07F4` | `0x407F4` | LCD/framebuffer copy candidate, `0x94F0 -> 0x1000`. |
| `C000:0807` | `0x40807` | Alarm wake wrapper. Calls `C000:0784`; when an alarm is accepted, plays the configured power-on buzzer and restores the saved screen. |
| `C000:08E7` | `0x408E7` | Centronics idle helper. Writes `0xFF` to parallel data port `0x40`. |
| `C000:08EC` | `0x408EC` | Centronics output starter. Enables the ACK-driven path, marks `[6DA4]=1`, and sends the first byte through `C000:0920`. |
| `C000:08DA` | `0x408DA` | Diagnostic gate on warm path. Calls `C000:1240`. |
| `C000:0920` | `0x40920` | Centronics direct byte output. Writes port `0x40`, waits for `0xA0` bit `0x02` to clear, then pulses port `0x30` bit `0x20` for strobe. |
| `C000:096A` | `0x4096A` | Tone helper. Programs sound divisor through ports `0x50`/`0x51`, gates output through `0x52`, and busy-waits for duration. |
| `C000:09AE` | `0x409AE` | RTC time write helper. Writes BCD shadow bytes `6D96..6D9B` to RTC ports `0xD0..0xD5`. |
| `C000:09C9` | `0x409C9` | RTC date write helper. Writes BCD shadow bytes `6D9C..6DA2` to RTC ports `0xD6..0xDC`. |
| `C000:09EC` | `0x409EC` | RTC write setup. Selects RP5C01 mode 1, resets/clears control state, sets 24-hour mode through port `0xDA`, then returns to mode 0 with timer disabled for the caller's BCD writes. |
| `C000:0A11` | `0x40A11` | Stored RTC alarm programmer. Writes low nibbles from `6D45..6D4A` into RP5C01 mode 1 day/hour/minute alarm registers. |
| `C000:0A3F` | `0x40A3F` | Short RTC alarm programmer. Writes current minute + 1 into RP5C01 mode 1 minute alarm registers. |
| `C000:0A6A` | `0x40A6A` | Combined battery-warning status query. Returns `AL=1..3` for main, CR2032 retention, or PCMCIA SRAM-card battery low, or zero when none are active. |
| `C000:0A93` | `0x40A93` | Main battery low helper. Tests port `0xA0` bit `0x08` twice. |
| `C000:0AA4` | `0x40AA4` | CR2032 memory-retention battery low helper. Tests port `0xA0` bit `0x04` twice. |
| `C000:0AB2` | `0x40AB2` | PCMCIA SRAM-card battery low helper. Requires port `0xA0` bit `0x80` clear and bit `0x10` clear. |
| `C000:0AC4` | `0x40AC4` | PCMCIA card access/presence helper. Sets carry when port `0xA0` bit `0x80` is set. |
| `C000:0ACE` | `0x40ACE` | PCMCIA card write-protect helper candidate. Sets carry when port `0xA0` bit `0x40` is set. |
| `C000:0B16` | `0x40B16` | Table-driven buzzer sequence player used by the WP SYSTEM `POWER ON BUZZER` preview. |
| `C000:0B60` | `0x40B60` | RTC snapshot helper. Reads ports `0xD0..0xDC` into BCD shadow buffer `6D96..6DA2`, low nibble only. |
| `C000:0B7C` | `0x40B7C` | Short RTC alarm compare helper. Compares selected alarm day/hour/minute fields against the RTC shadow. |
| `C000:0B90` | `0x40B90` | Full RTC alarm compare helper. Compares selected alarm date/time fields `6D41..6D4B` against the RTC shadow. |
| `C000:0BAF` | `0x40BAF` | Minute-fallback RTC compare helper. Checks whether RTC seconds are `00`. |
| `C000:0ED6` | `0x40ED6` | Interrupt/vector setup. Fills most IVT entries with `C000:118B`, installs IRQ stubs, installs `INT 21h` as `C000:0006`, installs `INT 1` as `C000:157D`, and copies the `C000:0F94` far-call table to RAM `0x0200`. |
| `C000:0F94` | `0x40F94` | Startup far-call table copied to RAM `0x0200`. This is the underlying vector table used by the 325 ROM's `F200:xxxx` trampoline page; the T400 keeps the low-RAM table but does not keep the `F200` trampoline page itself. |
| `C000:106F` | `0x4106F` | Keyboard row-scan reset/start helper. Enables the `FB` row-scan source through port `0x60`, dummy-reads `0xB0`, pulses port `0x61` from `0xFE` to `0xFF`, and clears row index `[6D29]`. |
| `C000:123C` | `0x4123C` | Forced diagnostic-monitor entry. Skips the `SPACE+F+J` chord check and enters the `C000:1247` diagnostic banner/parser loop directly. |
| `C000:1240` | `0x41240` | Diagnostic entry routine. Calls chord compare, then diagnostic UI/loop. |
| `C000:1252` | `0x41252` | Compares RAM `6D06..6D0F` with expected `SPACE+F+J` matrix bytes. |
| `C000:1272` | `0x41272` | Diagnostic draw/init routine. |
| `C000:128F` | `0x4128F` | Diagnostic command loop/parser. |
| `C000:1534` | `0x41534` | Diagnostic dump byte reader. For `I`/`L` commands, reads the current port through `in al,dx`; otherwise reads memory through the selected segment/address. |
| `C000:170E` | `0x4170E` | Far-call service wrapper used by `C688:9364`; service `AH=06` reaches the resource/text renderer. |
| `C000:1712` | `0x41712` | Far-call service wrapper used by `C688:936A`; dispatches the second service table, including `AH=01` for the `D59C` resource table reader and `AH=07` for terminal mode. |
| `C000:18EE` | `0x418EE` | Resource table reader for `D59C` / file base `0x559C0`; indexes by `DL` resource ID. |
| `C000:18A1` | `0x418A1` | Banked spell/grammar/linguistic service helper. Temporarily maps `3000:0000` to ROM file `0x30000` and calls it. |
| `C000:1DD9` | `0x41DD9` | Transfer-engine script command dispatcher reached by `C000:17ED`; command table includes file, stream, and XMODEM helpers. |
| `C000:1F17` | `0x41F17` | Private format helper. Selects target drive `8/9/10`, sets `BL=A5`, and calls `INT 21h AH=FF`. |
| `C000:1F8D` | `0x41F8D` | Transfer file-read chunk helper. Opens the selected file and returns 128-byte chunks in buffer `6C08`. |
| `C000:2034` | `0x42034` | Transfer-engine buffered file writer. Creates the selected output file and writes 128-byte chunks through `INT 21h AH=40`. |
| `C000:22F3` | `0x422F3` | Non-XMODEM serial stream receiver. Captures serial bytes through `C000:5117`, stops on Ctrl-Z/status, optionally decodes `0x08` control escapes, and writes 128-byte chunks. |
| `C000:2422` | `0x42422` | Non-XMODEM serial stream sender. Reads 128-byte file chunks and emits bytes through `INT 21h AH=04`, with control/newline expansion. |
| `C000:260D` | `0x4260D` | XMODEM sender. Waits for NAK, sends SOH packets with 128 data bytes plus one additive checksum byte, and finishes with EOT. |
| `C000:2702` | `0x42702` | XMODEM receiver. Sends NAK, accepts 132-byte SOH packets, verifies the 8-bit checksum and block number, writes 128 data bytes, and ACKs/EOTs. |
| `C000:2852` | `0x42852` | Far-call first-byte reader used by the COMMUNICATE ASCII-conversion prompt; opens the selected file, reads one byte into `6C08`, and returns it. |
| `C000:2C4A` | `0x42C4A` | Private `INT 21h AH=FF` direct service. With `BL=A5`, formats built-in/card storage or jumps into the DreamLink-specific path. |
| `3000:0000` | `0x30000` | Banked spell/grammar/linguistic service thunk. Switches to segment `3C00` and dispatches through `3000:4AA6`. |
| `3000:4AA6` | `0x34AA6` | Banked service dispatcher using service IDs `0x00..0x59`. |
| `C000:3064` | `0x43064` | Private `INT 21h AX=4428` endpoint probe. Returns availability bits for built-in RAM, PCMCIA SRAM card, and DreamLink. |
| `C000:311E` | `0x4311E` | Private `INT 21h AX=4429` DreamLink finish/flush helper; returns success without action for non-DreamLink handles. |
| `C000:3C08` | `0x43C08` | Card-storage capacity probe used during format. Write-tests the banked card window in 32 KiB steps and records the detected count. |
| `C000:3F78` | `0x43F78` | DreamLink command-frame prefix sender. Delays, then sends byte `0x13`. |
| `C000:4082` | `0x44082` | DreamLink shared response parser. Validates the expected command byte in `[7037]`, reads status/payload bytes, and dispatches command-specific payload handlers. |
| `C000:4384` | `0x44384` | DreamLink create/truncate sender for `AH=3C`. |
| `C000:4459` | `0x44459` | DreamLink open sender for `AH=3D`. |
| `C000:44C0` | `0x444C0` | DreamLink read setup sender for `AH=3F`. |
| `C000:4511` | `0x44511` | DreamLink read data receiver. Handles block boundaries, EOF byte `0x1A`, and `0x08` escape decoding. |
| `C000:4622` | `0x44622` | DreamLink write setup sender for `AH=40`. |
| `C000:4647` | `0x44647` | DreamLink write data sender. Handles block boundaries and `0x08` escapes for control bytes. |
| `C000:4707` | `0x44707` | DreamLink close sender for `AH=3E`. |
| `C000:47AC` | `0x447AC` | DreamLink initialize/format sender reached by private `AH=FF`, `BL=A5`, `DL=0A`. |
| `C000:49C2` | `0x449C2` | Auto power-off countdown check in an idle path. Decrements `[680B]`; when it reaches zero and `[6D31] != 0`, saves resume target `4977` and jumps to the retained power-transition path at `C000:035D`. |
| `C000:4961` | `0x44961` | Periodic idle warm/power marker check. Sets carry when `[680D] == 0` and `[6809] == 0x1992`, causing timer-driven wait loops to enter the retained power-transition path. |
| `C000:4A8D` | `0x44A8D` | Main keyboard/event idle loop. Uses `C000:4B2D` to check the keyboard ring buffer, reloads `[680B]` from `[6D31]` on keyboard activity, and enters the retained power-transition path on timeout. |
| `C000:4A94` | `0x44A94` | Low-level keyboard/event idle routine. Restores IRQ mask to port `0x60`, executes `sti; hlt`, then returns. |
| `C000:4B2D` | `0x44B2D` | Keyboard/event ring-buffer dequeue helper. Uses `[70E2]` and `[70E3]`; sets `[70A5]` bit `0x01` when no event is available. |
| `C000:4C39` | `0x44C39` | Battery-warning icon restore/clear helper. Restores the saved 48x40 screen area if a warning icon is active, then clears `[6D52]`. |
| `C000:4C4F` | `0x44C4F` | Battery-warning screen-area restore helper, `0x94F0 -> 0x131B`. |
| `C000:4C6E` | `0x44C6E` | Battery-warning screen-area save helper, `0x131B -> 0x94F0`. |
| `C000:4C91` | `0x44C91` | Battery-warning poll/display state machine. Rotates `[6D52]` through main, CR2032, and PCMCIA SRAM-card battery warning slots. |
| `C000:4CDC` | `0x44CDC` | Force-display the main battery low warning icon. Sets `[6D52]=2`, saves the screen area, and draws icon index `0`. |
| `C000:4D07` | `0x44D07` | Draws a 48x40 battery warning icon selected by `AL` from the table at `C000:4D30`. |
| `C000:5098` | `0x45098` | `INT 21h` service dispatcher. Maps `AH` through byte table `C000:5000`, then calls handler from word table `C000:5060`. File services reach the FAT12-style handlers around `C000:29AD..3F1C`. |
| `C000:516F` | `0x4516F` | `INT 21h AH=2A` get date. Snapshots the RTC shadow, decodes year/month/day, computes weekday with `C000:5308`, and returns DOS-style registers. |
| `C000:51C7` | `0x451C7` | `INT 21h AH=2B` set date. Converts binary year/month/day to BCD shadow bytes and writes RTC date registers. |
| `C000:5209` | `0x45209` | `INT 21h AH=2C` get time. Snapshots the RTC shadow and decodes hour/minute/second into DOS-style registers. |
| `C000:523D` | `0x4523D` | `INT 21h AH=2D` set time. Converts binary hour/minute/second to BCD shadow bytes and writes RTC time registers. |
| `C000:5308` | `0x45308` | Weekday calculator used by `INT 21h AH=2A`; computes `0..6` from year/month/day rather than returning the RTC `0xD6` shadow byte. |
| `C000:5645` | `0x45645` | Keyboard row processor called after each completed 10-row scan. Maintains first-stage/stable row state at `6D10..6D23`, handles two-sample debounce, queues press/repeat events, and clears repeat state on matching release. |
| `C000:5870` | `0x45870` | Keyboard event builder/enqueuer. Converts the repeating/current stable key address and bit mask into `DL=(row<<3)+bit`, builds `DH` flags through `C000:58A6`, and queues the resulting word through `C000:4B5C`. |
| `C000:58A6` | `0x458A6` | Keyboard modifier snapshot builder. Adds shifted/caps/control/alt bits to `DH` from stable row state and sticky/modifier state bytes before an event is queued. |
| `C000:5915` | `0x45915` | Keyboard event translator. Consumes the dequeued `DX` event word, selects normal/shift/control/caps/alt translation tables, and returns the translated byte used by `INT 21h AH=08`. |
| `C000:5AD6` | `0x45AD6` | Low-level resource/text renderer. Consumes staged bytes, expands glyphs, and writes rows into the framebuffer at `0x1000`. |
| `C000:6648` | `0x46648` | `FF 42` bitmap blit handler for startup resource records; uses row count, bit width, and source far pointer. |
| `C000:675D` | `0x4675D` | `FF 44` positioned rectangle/fill handler. The simple form uses `+1 y`, `+3 x`, `+5 height`, `+7 width`, and `+D mode`; nonzero `+9/+B` dispatches to copy/shift-looking helpers. |
| `C688:000B` | `0x4688B` | Main firmware far entry used after cold boot initialization. |
| `C688:000F` | `0x4688F` | Warm-path application entry. Calls into `C688:7752`, bypassing full main startup and boot-update sequence. |
| `C688:0013` | `0x46893` | COMMUNICATE serial-transfer preflight. If active target `[6806]` is DreamLink `0x0A`, resets it to built-in target `0x08`. |
| `C688:0053` | `0x468D3` | Retained/warm RAM signature check; returns carry on mismatch. |
| `C688:019D` | `0x46A1D` | Diagnostic display-script wrapper. Renders 15 bytes from `C688:017F` through `C000:16E7`. |
| `C688:01AB` | `0x46A2B` | Diagnostic display-script wrapper variant. Renders 15 bytes from `C688:018E` through the same `C000:16E7` path. |
| `C688:01B0` | `0x46A30` | App-loop forced diagnostic wrapper for event `0xF5`; far-calls `C000:123C` and returns to `C688:ED1D`. |
| `C688:01E6` | `0x46A66` | ROM-card execution setup. Sets `ES=0x0A4F`, calls setup helpers, marks `[6D54]=1`, and returns `[7A54] * 0x80` as the loader's work-memory/file-size limit. |
| `C688:020C` | `0x46A8C` | ROM-card execution cleanup. Sets `ES=0x0A4F`, calls cleanup/service helpers, and clears `[6D54]`. |
| `C688:022B` | `0x46AAB` | ROM-card executable trampoline. Saves `CX/DX/SI/DI/BP`, calls the far entry pointer loaded at `[0xA4F4]`, and preserves the loaded program's returned `AX`. |
| `C688:0240` | `0x46AC0` | Inline display/script interpreter entry; jumps to `C688:3879`. |
| `C688:042D` | `0x46CAD` | Display/script state-bit helper. Uses the byte mask table at `C688:0475` and RAM-pointer table at `C688:047D`. |
| `C688:294B` | `0x491CB` | WP editor heap RAM probe. Walks the candidate window table at `C688:8A17`, write-tests memory, and builds the 128-byte block free list. |
| `C688:29D9` | `0x49259` | Main application startup reached by `C688:000B`; clears UI work state and enters startup display path. |
| `C688:3879` | `0x4A0F9` | Inline display-script dispatcher body. Pops the caller return address as a script pointer and dispatches through the table at `C688:38A4`. |
| `C688:39C7` | `0x4A247` | Editor block allocator. Takes one block from `[7A50]`, links it into the active editor streams, and decrements `[7A54]`. |
| `C688:3A38` | `0x4A2B8` | Editor block release/rotate helper. Returns a block to the free list and increments `[7A54]`. |
| `C688:3E81` | `0x4A701` | Editor control-code classifier. Scans the overlapping table at `C688:3E60..3E7E` for command/control bytes and branches to editor text-flow handlers. |
| `C688:6391` | `0x4CC11` | Editor command dispatch. Selects the compact jump-opcode table at `C688:63F8` or the alternate table at `C688:670F` and jumps using the low byte of `[79C4]`. |
| `C688:6897` | `0x4D117` | Editor display/action classifier. Uses the packed nibble/action table at `C688:6978` to update `[7F23]` and dispatch display/editor state actions. |
| `C688:6B8C` | `0x4D40C` | Hands the copied `0x7F28` resource block to the `C000:170E` renderer service. |
| `C688:71A4` | `0x4DA24` | Selection/list wrapper using buffer `0x7555`; calls `C688:721D` for draw/setup and `C688:722F` for key handling. |
| `C688:721D` | `0x4DA9D` | Chooses `C688:9461` for `CL != 0` selectable menu/list drawing, otherwise calls `C688:9541` directly. |
| `C688:72E5` | `0x4DB65` | Selection/list wrapper variant used by several application submenu loops. |
| `C688:7689` | `0x4DF09` | Screen/resource setup wrapper used by first-menu and file/menu flows; clears per-screen state, calls `C688:9541`, and enters the selection/list setup path. |
| `C688:7766` | `0x4DFE6` | Startup display/update sequence that emits fixed update codes through `C688:77A3`. |
| `C688:77A3` | `0x4E023` | Individual boot update helper; switches display/profile state and applies the update. |
| `C688:77B4` | `0x4E034` | Copies first menu/graphic resource block from `C688:D133` / file `0x539B3`. |
| `C688:77C1` | `0x4E041` | Copies a `C688` resource block to low RAM `0x7F28`, then calls `C688:6B8C`. |
| `C688:7836` | `0x4E0B6` | Small WP status/template display record consumed through `C688:9D50`; code resumes at `C688:7841`. |
| `C688:7841` | `0x4E0C1` | Shared FILE picker selection resolver. Returns the current directory-entry pointer in `BX`; callers inspect `[BX+04]` flag bits. |
| `C688:788A` | `0x4E10A` | Shared FILE edit/list descriptor setup using filename buffer `778A`. |
| `C688:788D` | `0x4E10D` | Shared FILE edit/list descriptor setup. Writes mode, buffer pointer, maximum length, and descriptor pointer fields at `7506..7510`. |
| `C688:790E` | `0x4E18E` | WP FILE -> DELETE handler. Draws confirmation prompts and deletes the selected document through the DOS-like file API. |
| `C688:7993` | `0x4E213` | WP FILE -> INITIALIZE handler. Draws the initialize confirmation flow and invokes the private format path. |
| `C688:7A1B` | `0x4E29B` | WP FILE -> RENAME handler. Uses the shared picker/name-entry UI, validates the replacement filename, and commits through the file API. |
| `C688:7B41` | `0x4E3C1` | WP FILE -> RECALL handler. Uses the shared picker, checks selected-file flags, and loads or inserts the selected document into editor state. |
| `C688:7C1D` | `0x4E49D` | WP FILE -> STORE handler. Copies the current document name into the file buffer, prompts for filename/overwrite/secret state, and stores the document. |
| `C688:7D28` | `0x4E5A8` | Shared FILE error/status prompt dispatcher. Maps result codes to message resources and waits for CAN/TAB. |
| `C688:7DE1` | `0x4E661` | Shared FILE filename/default-label buffer seed. Initializes `778A[0]` and `778A[0x10]`. |
| `C688:7E3E` | `0x4E6BE` | COMMUNICATE -> RECEIVE FILE handler. Prompts for output filename and enters the non-XMODEM stream receive path. |
| `C688:7F5A` | `0x4E7DA` | COMMUNICATE -> SEND FILE handler. Uses the shared picker, optional ASCII-conversion prompt, and non-XMODEM stream send path. |
| `C688:8005` | `0x4E885` | COMMUNICATE -> RECEIVE FILE XMODEM handler. Prompts for output filename, sets `[8294]=1`, and enters the XMODEM receiver. |
| `C688:811D` | `0x4E99D` | COMMUNICATE -> SEND FILE XMODEM handler. Uses the shared picker, sets `[8294]=3`, and enters the XMODEM sender. |
| `C688:81A1` | `0x4EA21` | Shared FILE directory/list setup helper. |
| `C688:81A8` | `0x4EA28` | Shared FILE directory/list setup plus picker refresh, preserving `[75EF]`. |
| `C688:81B7` | `0x4EA37` | Shared selected-file flag check. Calls `DC98:2887`, displays resource `0x8D`, and returns a zero/nonzero status. |
| `C688:81C9` | `0x4EA49` | Shared selected-entry validator; resolves current selection and performs the flag-`0x04` check when needed. |
| `C688:82A6` | `0x4EAA6` | Shared 8.3-style filename validator/blank-pad helper used by STORE and RENAME. |
| `C688:82FF` | `0x4EAFF` | Shared filename-entry field dispatcher. Runs the one-field input loop with `CL=1` and returns `[794A]`. |
| `C688:8263` | `0x4EAE3` | COMMUNICATE ASCII-conversion prompt helper. Reads the first selected-file byte and, when needed, asks `Convert to ASCII ?`. |
| `C688:8312` | `0x4EB92` | First menu/input dispatcher reached after the startup menu resource is copied. |
| `C688:8319` | `0x4EB99` | Shared app-loop first-menu/input re-entry target for event `0x0A`; see `docs/disassembly/document-picker-ui.md`. |
| `C688:8A17` | `0x4F297` | Candidate RAM-window probe table walked by `C688:294B` while building the WP editor heap. |
| `C688:8CFB` | `0x4F57B` | Shared document/list continuation after the `LIST OF DOC.` template. Handles current selection state, inline key dispatch, and returns to the shared application event loop. |
| `C688:8D0F` | `0x4F58F` | Shared app-loop `REPLACE SEARCH` prompt root for event `0x1C`; draws resources `0x38` and `0x19`, edits the 16-byte search field, and dispatches local prompt actions. |
| `C688:8D23` | `0x4F5A3` | Shared app-loop `SEARCH` prompt root for event `0x1B`; draws resources `0x38` and `0x37`, edits the 16-byte search field, and dispatches local prompt actions. |
| `C688:9187` | `0x4FA07` | Shared document picker entry. Calls the storage-target setup path, invokes `DC98:52E5` with `[6806] | 0x40`, then copies the selected name into the caller buffer. |
| `C688:92DF` | `0x4FB5F` | Inline key dispatch trampoline. Consumes caller-embedded key/target entries and rewrites the return address. |
| `C688:9364` | `0x4FBE4` | Far-call wrapper for `C000:170E`. |
| `C688:93B5` | `0x4FC35` | Keyboard/event wrapper; calls `C688:5358` and stores the returned byte in `[0x794A]`. |
| `C688:9461` | `0x4FCE1` | Selectable menu/list drawing layer. Calls the cached `AL=5` path in `C688:9541`, then runs inline `C688:0240` scripts for per-item work. |
| `C688:9541` | `0x4FDC1` | Screen resource loader used by menu setup wrappers such as `C688:7689`. Loads resource IDs or CS pointer blocks into `0x7F28` and interprets their payload. |
| `C688:96E1` | `0x4FF61` | Invalidates the `C688:9541` `AL=5` resource cache by setting `[7574]`/`[7575]` to `FF`. |
| `C688:9A12` | `0x50292` | Editor accented-character output helper. Checks accent/compose state, consults the C688:9A90 tables, and emits `0xF4`/`0xF5` control bytes plus the composed character. |
| `C688:9AF6` | `0x50376` | Accented-character trigger lookup. Scans the C688:9A98 trigger list in CS and returns a pointer used by `C688:9B0A`. |
| `C688:9B0A` | `0x5038A` | Accented-character table walker. Uses the C688:9A99 pointer table and returns the matching character/glyph pair or the zero terminator. |
| `C688:9B2B` | `0x503AB` | WP status/layout refresh front end. Rebuilds status RAM templates, applies display-state flags, and dispatches selected records through the C000 renderer. |
| `C688:9D79` | `0x505F9` | WP status metric formatter. Formats current page/line/column-ish values into `0x76E4`, `0x76F6`, and `0x770E`, blanking leading zeroes. |
| `C688:9DFB` | `0x5067B` | WP status offset calculator. Derives `[79C1]` from free heap count and editor layout state before status resources are refreshed. |
| `C688:9E7E` | `0x506FE` | WP status resource copy tail. Copies a fixed 0x14-byte template from `C688:EAD9` to `0x8231`, then renders the `C688:EACE` record. |
| `C688:A647` | `0x50EC7` | First printer token handler after the C688:A527 vector table. Emits the inline record at `C688:A65F`, then chains through style/setup handlers. |
| `C688:AA76` | `0x512F6` | Shared printer inline-record emitter. Waits for the printer/output queue through `C688:AA84`, then emits the caller-selected CS record through `C688:CC1F`. |
| `C688:AAA6` | `0x51326` | WP `PRINTER` -> `PRINT OUT` flow. Presents print dialogs/ranges and routes formatted output toward the printer emitter. |
| `C688:AD5C` | `0x515DC` | Opens `H:ADDRESS.ODB`, reads 0x18/0x1E-byte chunks through the DOS-like API, and emits address-book fields into the output/editor stream. |
| `C688:AE5F` | `0x516DF` | Second `H:ADDRESS.ODB` reader/dump helper. Opens the same filename and steps through records using `C688:AF10` sector/record reads. |
| `C688:AF10` | `0x51790` | Address-book record reader. Seeks to `DX`, reads 0x1E bytes into `0x8259`, stores returned count in `[8258]`, and resets `[8257]`. |
| `C688:B056` | `0x518D6` | Printer table-dispatch helper. Uses `AL=[829E] & 7` as an index into the `CS:SI` table selected by the caller, then jumps through the selected word pointer. |
| `C688:B171` | `0x519F1` | Printer motion table setup helper. Selects table bases at `C688:B223`/`B28B` or `C688:B223`/`B547`, emits the selected byte templates, and adjusts spacing state. |
| `C688:B803` | `0x52083` | Printer spacing increment helper. Updates `[8298]`, emits spacing escape sequences according to `[829E]`, and shares the `C688:B862` byte-output helper. |
| `C688:BA91` | `0x52311` | Printer helper table launcher. Points `SI` at the `C688:BA97` table and jumps through shared table handling. |
| `C688:BBCB` | `0x5244B` | Start of printer escape/control handler cluster after the dispatch tables; nearby handlers emit ESC/P-style setup sequences. |
| `C688:C057` | `0x528D7` | Default printer character/control output stub reached through the C688:BFA7 vector table; selected neighboring stubs load alternate output bytes and jump to `C688:CFF1`. |
| `C688:C680` | `0x52F00` | Printer character table consumer and formatter front end. Uses the character-map/width tables at `C688:C0F4..C680`, then dispatches selected handlers through later printer text tables. |
| `C688:CD82` | `0x53602` | Printer text formatting tail after the C688:CC61 handler vector table; contains small wrappers around the common printer byte/spacing helpers. |
| `C688:CFF1` | `0x53871` | Printer/character output tail. Calls the spacing/position flush helper, emits `AL` through `C688:C82A`, then calls the backspace/spacing restore helper before returning. |
| `C688:EB2E` | `0x553AE` | WP FILE -> RECALL far wrapper. Sets `ES=0A4F`, calls C688 internal target `7B41`, and returns `[794A]` in `AL`. |
| `C688:EB46` | `0x553C6` | WP top menu -> CLEAR TEXT far wrapper. Sets `ES=0A4F`, calls C688 internal target `EC77`, and returns `[794A]` in `AL`. |
| `C688:EB5E` | `0x553DE` | WP PRINTER -> PRINT OUT far wrapper. Sets `ES=0A4F`, calls `C688:AAA6`, and returns `[794A]` in `AL`. |
| `C688:EB91` | `0x55411` | WP FILE -> INITIALIZE far wrapper. Sets `ES=0A4F`, calls C688 internal target `7993`, and returns `[794A]` in `AL`. |
| `C688:EBA9` | `0x55429` | WP FILE -> DELETE far wrapper. Sets `ES=0A4F`, calls C688 internal target `790E`, and returns `[794A]` in `AL`. |
| `C688:EBC1` | `0x55441` | WP FILE -> RENAME far wrapper. Sets `ES=0A4F`, calls C688 internal target `7A1B`, and returns `[794A]` in `AL`. |
| `C688:EBD9` | `0x55459` | WP FILE -> STORE far wrapper. Sets `ES=0A4F`, calls C688 internal target `7C1D`, and returns `[794A]` in `AL`. |
| `C688:EBF1` | `0x55471` | WP COMMUNICATE -> first RECEIVE FILE far wrapper. Sets `ES=0A4F`, calls C688 internal target `7E3E`, and returns `[794A]` in `AL`. |
| `C688:EC09` | `0x55489` | WP COMMUNICATE -> second RECEIVE FILE far wrapper. Sets `ES=0A4F`, calls C688 internal targets `0013` and `8005`, and returns `[794A]` in `AL`. |
| `C688:EC24` | `0x554A4` | WP COMMUNICATE -> first SEND FILE far wrapper. Sets `ES=0A4F`, calls C688 internal targets `0013` and `7F5A`, and returns `[794A]` in `AL`. |
| `C688:EC3F` | `0x554BF` | WP COMMUNICATE -> second SEND FILE far wrapper. Sets `ES=0A4F`, calls C688 internal targets `0013` and `811D`, and returns `[794A]` in `AL`. |
| `C688:EC5A` | `0x554DA` | WP COMMUNICATE -> TERMINAL far wrapper. Sets `ES=0A4F`, calls the C688 service path at `936A` with `AH=07`, stores `AL` in `[794A]`, and returns it. |
| `C688:EC9F` | `0x5551F` | Shared application menu/event loop after first-screen branch setup. |
| `C000:0BFC` | `0x40BFC` | Builds the RS-232C USART async mode byte from `6D2B..6D2D`. |
| `C000:0C30` | `0x40C30` | Pulses port `0x30` bit `0x08` high then low using the `[6D94]` mirror, likely a USART/baud-clock setup strobe. |
| `C000:0C58` | `0x40C58` | Programs RS-232C: baud latch on port `0x30`, 8251-style reset/mode/command sequence on port `0xC1`, and IRQ/buffer state. |
| `C000:0CBC` | `0x40CBC` | Serial initialization wrapper. Validates `6D2A..6D2E`, then calls `C000:0C58`. |
| `C000:0D4F` | `0x40D4F` | Serial transmit-ready/status check using port `0xC1`. |
| `C000:0D96` | `0x40D96` | Serial transmit data helper; writes byte to port `0xC0`. |
| `C000:1089` | `0x41089` | Terminal-mode loop. Initializes serial, polls translated keys, remaps arrows to one-byte C0 controls, and sends through `INT 21h AH=04`. |
| `C000:4B8D` | `0x44B8D` | Serial receive queue drain / software flow-control helper. Sends XON when space recovers. |
| `C000:4BED` | `0x44BED` | Serial receive queue insert helper. Sends XOFF/XON flow-control bytes when enabled. |
| `C000:41A8` | `0x441A8` | DreamLink serial peer probe. Programs the USART for `9600 8N1` with XON/XOFF disabled, then restores the user setting bytes in RAM without reinitializing the USART. |
| `DC98:0D2A` | `0x5D6AA` | Get-date wrapper around `INT 21h AH=2A`; stores weekday/year/month/day at `72DD`, `72D7`, `72D9`, and `72DB`. |
| `DC98:0D4E` | `0x5D6CE` | Get-time wrapper around `INT 21h AH=2C`; stores hour/minute/second at `72DF`, `72E1`, and `72E3`. |
| `DC98:0D72` | `0x5D6F2` | Set-date wrapper around `INT 21h AH=2B`; loads year/month/day from `72D7`, `72D9`, and `72DB`. |
| `DC98:0D8F` | `0x5D70F` | Set-time wrapper around `INT 21h AH=2D`; loads hour/minute/second from `72DF`, `72E1`, and `72E3`. |
| `DC98:0E81` | `0x5D801` | Text output helper used by the horizontal icon menu renderer for label text. |
| `DC98:1198` | `0x5DB18` | Horizontal icon menu key loop. Handles selection redraw, arrows, numeric shortcuts, and select/cancel-style keys. |
| `DC98:124C` | `0x5DBCC` | Horizontal icon menu renderer. Consumes compact icon/label tables and generates `FF 42` 40x40 bitmap blit records. |
| `DC98:22A1` | `0x5EC21` | Shared SET UP screen for printer `SET UP 2` and COMMUNICATE `SET UP`; edits RS-232C settings at `6D2A..6D2E`. |
| `DC98:24DB` | `0x5EE5B` | WP `PRINTER` -> `SET UP 1`; edits printer model, parallel/serial interface, and paper feed at `6D59..6D5B`. |
| `DC98:265D` | `0x5EFDD` | WP `PRINTER` submenu wrapper around `DC98:124C`. |
| `DC98:26B8` | `0x5F038` | WP `COMMUNICATE` submenu wrapper around `DC98:124C`. |
| `DC98:275A` | `0x5F0DA` | WP `FILE` submenu wrapper around `DC98:124C`. |
| `DC98:2807` | `0x5F187` | WP top icon menu wrapper around `DC98:124C`. |
| `DC98:2B75` | `0x5F4F5` | WP OTHERS -> ROM CARD loader. Finds `EROMCARD.X`, checks it against the `[7A54] * 0x80` work-memory limit, loads it at `0xA4F0`, validates header words `0xA4F0/0x1997`, then calls the loaded far entry pointer. |
| `DC98:2D2B` | `0x5F6AB` | WP `OTHERS` submenu wrapper around `DC98:124C`. |
| `DC98:455F` | `0x60EDF` | WP FILE -> COPY direction selector. Handles Built-in/Card/DreamLink copy directions. |
| `DC98:4D67` | `0x616E7` | Directory-list builder. Uses DOS find-first/find-next on `X:*.*`, reads standard DTA fields, sorts 19-byte records, and caps at 128 entries. |
| `DC98:52E5` | `0x61C65` | Document picker/list UI. Calls `DC98:4D67` to enumerate files and `DC98:4EAF`/`5198` to draw and navigate the list. |
| `DC98:53C3` | `0x61D43` | Organizer top icon menu wrapper around `DC98:124C`; stores selected index in `[82A6]`. |
| `DC98:54C2` | `0x61E42` | Calculator numeric display renderer. Builds inline `FF 42` bitmap records from the 8x12 digit resource at `F16C:000A`. |
| `DC98:583E` | `0x621BE` | Calculator input display redraw helper. Uses the same `F16C` 8x12 digit/punctuation resource family. |
| `DC98:640F` | `0x62D8F` | Calculator main event loop. Reads key events, applies the private calculator translation table at `C000:5619..5644`, and dispatches digit/operator handlers. |
| `DC98:6A38` | `0x633B8` | Organizer CALCULATOR handler. Initializes display areas, BCD buffers at `85EE`/`8600`, display glyph selectors `[8648]`/`[8649]`, then calls `DC98:640F`. |
| `DC98:990D` | `0x6628D` | Organizer SCHEDULER handler. Displays `*** WAIT ***`, builds `<drive>:SCHEDULE.ODB`, opens or creates an `ORGAN[SCHEDULE]` database, and returns to the Organizer menu if no entries are available. |
| `DC98:9AC8` | `0x66448` | WORLD CLOCK large time renderer. Builds an inline script with `FF 42` 7x12 digit bitmaps from `F16C:000A` and 4x12 separators from `F16C:008C`. |
| `DC98:A06C` | `0x669EC` | WORLD CLOCK current-time redraw wrapper. Updates the base time, applies the second-city offset, and calls `DC98:9AC8` for both displayed clocks. |
| `DC98:A0CC` | `0x66A4C` | Organizer WORLD CLOCK map redraw helper. Emits the static map resource and overlays the two city markers from city-table coordinates. |
| `DC98:AAD5` | `0x67455` | WORLD CLOCK -> SET TIME/DATE handler. Draws the edit screen, reads date/time through `DC98:0D2A`/`0D4E`, edits fields, then writes accepted values through `DC98:0D72`/`0D8F`. |
| `DC98:AD1B` | `0x6769B` | WORLD CLOCK -> DISPLAY FORM handler. Edits `[6808]` between 24-hour and 12-hour display modes. |
| `DC98:B457` | `0x67DD7` | WORLD CLOCK -> DAILY ALARM handler. Edits four daily-alarm rows stored at `89F2`, each with a time word plus label text. |
| `DC98:B67C` | `0x67FFC` | Organizer WORLD CLOCK main screen. Draws the city labels, map/header/menu resources, blinks the selected city marker, and dispatches the `H`/`2`/`S`/`F`/`A` subcommands. |
| `DC98:D3BB` | `0x69D3B` | Next-alarm selector called by the retained power-transition path. Scans scheduler alarm entries and WORLD CLOCK daily alarms, then writes the selected date/time into `6D41..6D4C` for the RP5C01 alarm programmer. |
| `DC98:CF12` | `0x69892` | Organizer ADDRESS BOOK handler. Confirmed to enter normally in MAME after the built-in store banking fix. |
| `DC98:E946` | `0x6B2C6` | File open wrapper used by the ROM-card loader before reading `EROMCARD.X`. |
| `DC98:EE08` | `0x6B788` | File read wrapper around DOS-like `int 21h AH=3F`; ROM-card loader reads into `0xA4F0` through this path. |
| `DC98:EE1B` | `0x6B79B` | File write wrapper around DOS-like `int 21h AH=40`. |
| `DC98:EE2E` | `0x6B7AE` | File close wrapper around DOS-like `int 21h AH=3E`. |
| `DC98:EE40` | `0x6B7C0` | File delete wrapper around DOS-like `int 21h AH=41`. |
| `DC98:EE56` | `0x6B7D6` | File rename wrapper around DOS-like `int 21h AH=56`. |
| `DC98:EE72` | `0x6B7F2` | File seek wrapper around DOS-like `int 21h AH=42`. |
| `DC98:EF7B` | `0x6B8FB` | Find-first wrapper. Sets caller DTA with `AH=1A`, then calls `AH=4E`; used to probe `EROMCARD.X`. |
| `DC98:EF9A` | `0x6B91A` | Find-next wrapper. Sets caller DTA with `AH=1A`, then calls `AH=4F`. |

## DreamWriter 450 Reset Entries

The T450 ROM `t4_ir_35ba308.ic303` is 1 MiB and starts from a different top
bank than the 512 KiB T400 v2.1 image:

| Address | File offset | Meaning |
| --- | ---: | --- |
| `FFFF:0000` | `0xFFFF0` | CPU reset vector. Jumps to `F7A1:0000`. |
| `F7A1:0000` | `0xF7A10` | Reset trampoline. Initializes ports `0x16`/`0x17`, then jumps to `C000:0000`. |
| `C000:0000` | `0xC0000` | Main startup entry. Begins with `jmp C000:0029`. |
| `C000:0305` | `0xC0305` | Seeds default bank values for ports `0x11..0x15`: `0x0F`, `0x1F`, `0x1E`, `0x1D`, `0x1C`. |

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
C000:00FA  call C000:4811       ; built-in store validation/init
C000:011A  jmp far C688:000B
```

`C000:4811` selects built-in store `08` and calls `C000:045A` to validate the
DreamWriter volume header/checksum at segment `1800`. If validation fails, it
calls the private format/init service through `INT 21h` with
`AH=FF/BL=A5/DL=08`. This is the cold/reset path that produces the visible
`INITIALIZING` RAM-store initialization screen.

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
