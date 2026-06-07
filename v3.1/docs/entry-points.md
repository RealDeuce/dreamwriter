# Confirmed Entry Points

Entry points confirmed from the boot disassembly. File offsets use the
banking model described in [`map.md`](map.md). All addresses are in the
C000 window (port `0x16=0x01`, file base `0xC0000`) unless noted.

## Reset and Startup

| Address | File offset | Meaning |
| --- | --- | --- |
| `FFFF:0000` | `0xFFFF0` | Reset vector: `CLI; JMP FAR F6E3:0000`. |
| `F6E3:0000` | `0xF6E30` | Reset trampoline: sets ports `0x16=0x01, 0x17=0x00`, jumps to `C000:0000`. |
| `C000:0000` | `0xC0000` | Main entry: `JMP SHORT C000:0029`. |
| `C000:0029` | `0xC0029` | Hardware init: bank ports, segment regs, I/O ports, temp stack. |
| `C000:0065` | `0xC0065` | Warm-RAM signature check: 4+1 bytes at `[1000]` vs `CS:7799`. |
| `C000:0085` | `0xC0085` | Cold stamp: writes signature to RAM, falls through to cold init. |
| `C000:0096` | `0xC0096` | Cold-start init: subsystem init, store validate, sets warm-retry. |
| `C000:00EC` | `0xC00EC` | Warm path: restores bank ports from mirrors, skips subsystem init. |
| `C000:0107` | `0xC0107` | Common init tail: clears state, calls warm-state validate, enters decision tree. |

## Boot Decision Tree

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:0148` | `0xC0148` | Resume check: tests `[1467]` for known app states. |
| `C000:016C` | `0xC016C` | Segment validate: compares `[1469]` with CS. |
| `C000:018A` | `0xC018A` | Cold reinit: full reinitialization, ends with `JMP FAR C772:0004`. |
| `C000:01DF` | `0xC01DF` | Warm resume: restore context, ends with `JMP FAR C772:0008`. |
| `C000:0220` | `0xC0220` | Diagnostic gate: install vectors, chord check, context verify, resume. |
| `C000:025E` | `0xC025E` | Resume from NMI: alternate resume path when `[1473]==0x4D0`. |

## Interrupt Stubs (C000 Jump Table)

| Address | File offset | Jump target | Meaning |
| --- | --- | --- | --- |
| `C000:0006` | `0xC0006` | `C000:6277` | INT 21h dispatch. |
| `C000:0009` | `0xC0009` | `C000:04D0` | IRQ F8 — NMI / save context. |
| `C000:000C` | `0xC000C` | `C000:05C0` | IRQ F9. |
| `C000:000F` | `0xC000F` | `C000:05D4` | IRQ FA. |
| `C000:0012` | `0xC0012` | `C000:05F7` | IRQ FB. |
| `C000:0015` | `0xC0015` | `C000:0676` | IRQ FC. |
| `C000:0018` | `0xC0018` | `C000:084A` | IRQ FD. |
| `C000:001B` | `0xC001B` | `C000:085E` | IRQ FE. |
| `C000:001E` | `0xC001E` | `C000:03FC` | IRQ FF — warm/power. |

## Interrupt Handlers

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:1161` | `0xC1161` | Install IVT: fills vectors `00h..F7h` with `C000:141F` (IRET), sets IRQ stubs, overwrites INT 01h and INT 21h, copies 41-entry far-call table to `[0200..029C]`. |
| `C000:141F` | `0xC141F` | Default interrupt target (single IRET). |
| `C000:1832` | `0xC1832` | INT 01h: diagnostic/single-step hook. |
| `C000:04D0` | `0xC04D0` | INT 02h (NMI) / IRQ F8: saves full register context to `[1453..146D]`, computes checksum, calls save_state, halts. |
| `C000:6277` | `0xC6277` | INT 21h dispatch: validity table at `C000:61DF`, dispatch table at `C000:623F`. |

## Power and Chord Detection

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:0492` | `0xC0492` | Halt loop: `OUT 70,01; JMP $`. RTC alarm wake. |
| `C000:048C` | `0xC048C` | Power-down: calls save_state, chord_check, then halt. |
| `C000:0498` | `0xC0498` | Warm IRQ chord check: scans keyboard, sets `[1439]` if chord held. |
| `C000:08AA` | `0xC08AA` | Chord gate: if `[1439]` set, waits for release; else checks chord now. |
| `C000:08B4` | `0xC08B4` | Check chord now: calls `0E43`, branches to init or power-down. |
| `C000:08D3` | `0xC08D3` | Normal startup init (no chord): secondary chord check, then renders 9 display scripts from C772 segment. |
| `C000:08E2` | `0xC08E2` | Startup init (chord flag was set): same display scripts, skips secondary check. |
| `C000:0953` | `0xC0953` | Wait for release: loops `0E62` until keys released, then goes to `08E2`. |
| `C000:095B` | `0xC095B` | Diagnostic flag halt: sets `[1439]=1`, halts. |
| `C000:0987` | `0xC0987` | Chord check and init: calls `08AA`, if no chord does display init + delay. |

## Keyboard Matrix and Chord

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:0E13` | `0xC0E13` | Scan keyboard matrix: reads ports `0xD0..0xDC` into `[1484..1490]`. |
| `C000:0E43` | `0xC0E43` | Scan chord (11-byte): compares `[142C..1436]` against scan buffer. CF=1 if match. |
| `C000:0E2F` | `0xC0E2F` | Scan chord (7-byte): compares `[1430..1436]` against `[148C..1490]`. CF=1 if match. |
| `C000:0E62` | `0xC0E62` | Check keyboard clear: returns CF=1 if `[1484]` and `[1485]` are zero. |

## Context Save/Restore

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:055E` | `0xC055E` | Context checksum: sums 15 words at `[1453..1470]`, stores at `[1471]`. |
| `C000:02A3` | `0xC02A3` | Context checksum verify: recomputes and compares, restores regs on match. |
| `C000:03EA` | `0xC03EA` | Restore saved context. |
| `C000:05A3` | `0xC05A3` | Save state. |

## Subsystem Init

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:0327` | `0xC0327` | Seed bank mirrors: writes `0F/1F/1E/1D/1C` defaults to `[147B..147F]`. |
| `C000:03A5` | `0xC03A5` | Keyboard scan start. |
| `C000:03BB` | `0xC03BB` | Hardware setup (phase 2). |
| `C000:0571` | `0xC0571` | RAM checksum init: checksums `1800:0008..FFFF`, stores at `1800:0006`. |
| `C000:0594` | `0xC0594` | RAM checksum compute: sums 0x7FFC words from `[SI]`. |
| `C000:09CE` | `0xC09CE` | NMI recovery init: display helper when `[1473]==0x4D0`. |
| `C000:09D4` | `0xC09D4` | Cold banner: renders "INITIALIZING" display script from `C772:EDB0`. |
| `C000:09EA` | `0xC09EA` | Cold early init: timed delays. |
| `C000:09B2` | `0xC09B2` | Framebuffer swap/restore (warm resume). |
| `C000:0969` | `0xC0969` | Framebuffer save: copies `[8000..8FFF]` to `[9000..9FFF]`. |
| `C000:0974` | `0xC0974` | Framebuffer restore: copies `[9000..9FFF]` to `[8000..8FFF]`. |
| `C000:0303` | `0xC0303` | Reinit app with swap: saves/restores framebuffer around `DEF0:5B03`. |
| `C000:0AA0` | `0xC0AA0` | Battery check: calls `C000:14D4`, sets `[146F]=0x1995` on failure. |
| `C000:2E2D` | `0xC2E2D` | Warm state validate: returns CF=1 on failure. |
| `C000:2E72` | `0xC2E72` | Subsystem init (organizer/menu). |
| `C000:4396` | `0xC4396` | Store validate/format. |
| `C000:5600` | `0xC5600` | File table init. |
| `C000:6523` | `0xC6523` | INT 21h services init. |
| `C000:6557` | `0xC6557` | Render display script: SI=offset, CX=length, DX=segment. |
| `C000:12CC` | `0xC12CC` | Install vectors and clear state (differs from `C000:1161`). |
| `C000:0B30` | `0xC0B30` | Timed delay: BX=outer, CX=inner loop counts. |
| `C000:0A49` | `0xC0A49` | Delay loop. |
| `C000:0DC5` | `0xC0DC5` | Display helper. |
| `C000:0CE1` | `0xC0CE1` | Diagnostic display init. |
| `C000:0CB3` | `0xC0CB3` | Clear diagnostic state. |
| `C000:0F0B` | `0xC0F0B` | Additional hardware restore (from context verify). |

## Diagnostic Monitor

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:131D` | `0xC131D` | Diagnostic command monitor: entered via banked thunk dispatch table slot 7 at `C000:1B38`. |
| `C000:1341` | `0xC1341` | Command loop: polls keyboard, dispatches commands. |
| `C000:1378` | `0xC1378` | Command dispatch table (7 entries). |
| `C000:13C5` | `0xC13C5` | Exit diagnostic: clears `[15A2]`, returns. |
| `C000:13F5` | `0xC13F5` | Diagnostic banner render: renders from `C000:76F5` ("Terminal mode"). |
| `C000:1420` | `0xC1420` | Software error halt: displays "Internal software error" message and halts. NOT the diagnostic monitor. |

## Banked Call Entries

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:0021` | `0xC0021` | Banked thunk entry A (calls `C000:19CB`). |
| `C000:0025` | `0xC0025` | Banked thunk entry B (calls `C000:1B28`). |
| `C000:1B28` | `0xC1B28` | Banked thunk dispatcher B: dispatch table at `C000:1B38`. |
| `C000:1B38` | `0xC1B38` | Banked thunk dispatch table (12 slots). Slot 7 = `C000:131D` (diagnostic monitor). |

## DEF0 Segment (Wrappers)

| Address | File offset | Meaning |
| --- | --- | --- |
| `DEF0:0000` | `0xDEF00` | Segment base. |
| `DEF0:000B` | `0xDEF0B` | Display init (called from diagnostic banner render). |
| `DEF0:0019` | `0xDEF19` | Display helper (called from diagnostic banner render). |
| `DEF0:0027` | `0xDEF27` | Display helper (called from diagnostic banner render). |
| `DEF0:0043` | `0xDEF43` | INT 21h AH=08h wrapper (keyboard input). |
| `DEF0:0063` | `0xDEF63` | INT 21h AH=0Bh wrapper (input status). |
| `DEF0:C5BC` | `0xDB4BC` | Startup display init (called from chord gate and warm IRQ). |
| `DEF0:CD5F` | `0xDBC5F` | Chord response handler (called when chord detected). |

## Far Call Targets

| Address | Meaning |
| --- | --- |
| `DEF0:5C07` | Application subsystem init (same address as v2.1). |
| `DEF0:5B03` | Application init / warm-start app entry (same address as v2.1). |
| `C772:0004` | Application entry — cold start. |
| `C772:0008` | Application entry — warm resume. |
