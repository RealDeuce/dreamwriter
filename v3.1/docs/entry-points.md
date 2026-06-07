# Confirmed Entry Points

Entry points confirmed from the boot disassembly. File offsets use the
banking model described in [`map.md`](map.md).

## Reset and Startup

| Address | File offset | Meaning |
| --- | --- | --- |
| `FFFF:0000` | `0xFFFF0` | Reset vector: `CLI; JMP FAR F6E3:0000`. |
| `F6E3:0000` | `0xF6E30` | Reset trampoline: sets ports `0x16=0x01, 0x17=0x00`, jumps to `C000:0000`. |
| `C000:0000` | `0xC0000` | Main startup: `JMP SHORT C000:0029`. |
| `C000:0029` | `0xC0029` | Hardware init, bank setup, warm-RAM signature check. |

## Interrupt Stubs

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:0006` | `0xC0006` | INT 21h dispatch (-> `C000:6277`). |
| `C000:0009` | `0xC0009` | IRQ stub F8. |
| `C000:000C` | `0xC000C` | IRQ stub F9. |
| `C000:000F` | `0xC000F` | IRQ stub FA. |
| `C000:0012` | `0xC0012` | IRQ stub FB. |
| `C000:0015` | `0xC0015` | IRQ stub FC. |
| `C000:0018` | `0xC0018` | IRQ stub FD. |
| `C000:001B` | `0xC001B` | IRQ stub FE. |
| `C000:001E` | `0xC001E` | IRQ stub FF. |

## Banked Call Entries

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:0021` | `0xC0021` | Banked spell/linguistic thunk entry (calls `C000:19CB`). |
| `C000:0025` | `0xC0025` | Banked spell/linguistic thunk entry alt (calls `C000:1B28`). |

## Boot Path Routines

| Address | File offset | Meaning |
| --- | --- | --- |
| `C000:0327` | `0xC0327` | Seed default bank mirrors to `[147B..147F]`. |
| `C000:03A5` | `0xC03A5` | Keyboard scan start. |
| `C000:03BB` | `0xC03BB` | Hardware setup. |
| `C000:03EA` | `0xC03EA` | Resume saved context. |
| `C000:0571` | `0xC0571` | Subsystem init. |
| `C000:09B2` | `0xC09B2` | Pre-warm-resume handler. |
| `C000:09CE` | `0xC09CE` | Conditional init (when `[1473]==04D0`). |
| `C000:09D4` | `0xC09D4` | Cold reinit helper. |
| `C000:09EA` | `0xC09EA` | Cold-start init. |
| `C000:0AA0` | `0xC0AA0` | Post-resume check. |
| `C000:1161` | `0xC1161` | Early hardware init. |
| `C000:12CC` | `0xC12CC` | Install interrupt vectors. |
| `C000:2E2D` | `0xC2E2D` | Warm-state validation (sets CF on failure). |
| `C000:2E72` | `0xC2E72` | Organizer/menu init. |
| `C000:4396` | `0xC4396` | Built-in store validate/format. |
| `C000:5600` | `0xC5600` | File table init. |
| `C000:6277` | `0xC6277` | INT 21h dispatch target. |
| `C000:6523` | `0xC6523` | INT 21h services init. |

## Far Call Targets

| Address | Meaning |
| --- | --- |
| `DEF0:5C07` | Application subsystem init (same address as v2.1). |
| `DEF0:5B03` | Application init / warm-start app entry (same address as v2.1). |
| `C772:0004` | Application runtime entry (v2.1: `C688:000B`). |
