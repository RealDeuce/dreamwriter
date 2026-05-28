# Entry Points

## Confirmed Entries

| Address | File offset | Meaning |
| --- | ---: | --- |
| `FFFF:0000` | `0x7FFF0` | CPU reset vector. Jumps to `F8DC:0000`. |
| `F8DC:0000` | `0x78DC0` | Reset trampoline. Initializes ports `0x16`/`0x17`, then jumps to `C000:0000`. |
| `C000:0000` | `0x40000` | Main startup entry. Begins with `jmp C000:0029`. |
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
| `C000:07E9` | `0x407E9` | LCD/framebuffer copy candidate, `0x1000 -> 0x94F0`. |
| `C000:07F4` | `0x407F4` | LCD/framebuffer copy candidate, `0x94F0 -> 0x1000`. |
| `C000:08DA` | `0x408DA` | Diagnostic gate on warm path. Calls `C000:1240`. |
| `C000:1240` | `0x41240` | Diagnostic entry routine. Calls chord compare, then diagnostic UI/loop. |
| `C000:1252` | `0x41252` | Compares RAM `6D06..6D0F` with expected `SPACE+F+J` matrix bytes. |
| `C000:1272` | `0x41272` | Diagnostic draw/init routine. |
| `C000:128F` | `0x4128F` | Diagnostic command loop/parser. |
| `C000:170E` | `0x4170E` | Far-call service wrapper used by `C688:9364`; service `AH=06` reaches the resource/text renderer. |
| `C000:1712` | `0x41712` | Far-call service wrapper used by `C688:936A`; service `AH=01` reaches the `D59C` resource table reader. |
| `C000:18EE` | `0x418EE` | Resource table reader for `D59C` / file base `0x559C0`; indexes by `DL` resource ID. |
| `C000:18A1` | `0x418A1` | Banked spell/linguistic service helper. Temporarily maps `3000:0000` to ROM file `0x30000` and calls it. |
| `3000:0000` | `0x30000` | Banked spell/linguistic service thunk. Switches to segment `3C00` and dispatches through `3000:4AA6`. |
| `3000:4AA6` | `0x34AA6` | Banked service dispatcher using service IDs `0x00..0x59`. |
| `C000:4A94` | `0x44A94` | Low-level keyboard/event idle routine. Restores IRQ mask to port `0x60`, executes `sti; hlt`, then returns. |
| `C000:4C4F` | `0x44C4F` | LCD/framebuffer copy candidate, `0x94F0 -> 0x131B`. |
| `C000:4C6E` | `0x44C6E` | LCD/framebuffer copy candidate, `0x131B -> 0x94F0`. |
| `C000:5097` | `0x45097` | Interrupt-style service dispatcher. Maps `AH` through byte table `C000:5000`, then calls handler from word table `C000:5060`. |
| `C000:5AD6` | `0x45AD6` | Low-level resource/text renderer. Consumes staged bytes, expands glyphs, and writes rows into the framebuffer at `0x1000`. |
| `C000:6648` | `0x46648` | `FF 42` bitmap blit handler for startup resource records; uses row count, bit width, and source far pointer. |
| `C000:675D` | `0x4675D` | `FF 44` positioned region/line/fill-style resource handler; exact field meanings still need decoding. |
| `C688:000B` | `0x4688B` | Main firmware far entry used after cold boot initialization. |
| `C688:000F` | `0x4688F` | Warm-path application entry. Calls into `C688:7752`, bypassing full main startup and boot-update sequence. |
| `C688:0053` | `0x468D3` | Retained/warm RAM signature check; returns carry on mismatch. |
| `C688:0240` | `0x46AC0` | Inline display/script interpreter entry; jumps to `C688:3879`. |
| `C688:29D9` | `0x49259` | Main application startup reached by `C688:000B`; clears UI work state and enters startup display path. |
| `C688:6B8C` | `0x4D40C` | Hands the copied `0x7F28` resource block to the `C000:170E` renderer service. |
| `C688:7766` | `0x4DFE6` | Startup display/update sequence that emits fixed update codes through `C688:77A3`. |
| `C688:77A3` | `0x4E023` | Individual boot update helper; switches display/profile state and applies the update. |
| `C688:77B4` | `0x4E034` | Copies first menu/graphic resource block from `C688:D133` / file `0x539B3`. |
| `C688:77C1` | `0x4E041` | Copies a `C688` resource block to low RAM `0x7F28`, then calls `C688:6B8C`. |
| `C688:8312` | `0x4EB92` | First menu/input dispatcher reached after the startup menu resource is copied. |
| `C688:92DF` | `0x4FB5F` | Inline key dispatch trampoline. Consumes caller-embedded key/target entries and rewrites the return address. |
| `C688:9364` | `0x4FBE4` | Far-call wrapper for `C000:170E`. |
| `C688:93B5` | `0x4FC35` | Keyboard/event wrapper; calls `C688:5358` and stores the returned byte in `[0x794A]`. |
| `C688:9541` | `0x4FDC1` | Screen resource loader used by menu setup wrappers such as `C688:7689`. Loads resource IDs or CS pointer blocks into `0x7F28` and interprets their payload. |
| `C688:EC9F` | `0x5551F` | Shared application menu/event loop after first-screen branch setup. |

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
