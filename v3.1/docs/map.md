# ROM Map

Working target: `t4_ir_3.1_e588.ic303`

```text
Size:   1048576 bytes
SHA256: d105317a9818a1b29b5d6f4c676f96bbd961646a571a0f4b6dc9b88cbe1de8e2
```

## Address Model

The v3.1 ROM is a 1 MiB image. MAME loads it at region offset `0x00000`,
filling the entire `bios` region. The ROM is not identity-mapped into the CPU
address space; the banking hardware selects which 128 KiB chunks are visible at
any time, and most CPU windows are RAM at startup.

For the normal `C000:xxxx` code window (port `0x16 = 0x01`), the bank formula
gives ROM bank `((0x01 & 0x0F) ^ 0x0F) = 0x0E`, and the file offset is
`(0x0E * 0x20000) % 0x100000 = 0xC0000`. So:

```text
C000:0000 -> file 0xC0000
C000:1234 -> file 0xC1234
```

For the high ROM window (port `0x17 = 0x00`), bank `0x0F`, file base `0xE0000`:

```text
F6E3:0000 -> file 0xF6E30
FFFF:0000 -> file 0xFFFF0
```

For segments loaded into other windows, the file offset depends on the active
bank register value. Use `tools/rom2.py bank` for conversion checks (note:
`rom2.py` constants are currently v2.1-specific; pass `--rom` for the v3.1
image but expect address math to be wrong until the tool is updated).

The v2.1 shortcut `file = physical - 0x80000` does NOT apply here. Each
conversion requires knowing the bank state.

## Banking Model

Detailed banking notes are in [`banking.md`](../../docs/banking.md).

MAME maps the 1 MiB V20 address space as eight 128 KiB windows selected by I/O
ports `0x10..0x17`. For bank register value `v`, values `0x00..0x07` select ROM
bank `((v & 0x0F) ^ 0x0F)`, bit `0x10` selects RAM, and bit `0x08` alone
selects RAM with the page following the CPU window (the 1 MiB DreamWriter
behavior documented in `banking.md`).

For the 1 MiB ROM, bank `N` maps to file offset `(N * 0x20000) % 0x100000`.
All 8 ROM banks (0..7 via values 0x07..0x00) address distinct 128 KiB chunks
covering the full image.

### Cold-Start Bank Mapping

T400 v3.1 startup at `C000:0029` writes port `0x10`, then restores ports
`0x11..0x15` from low-RAM defaults seeded by routine `C000:0327`. The resulting
map is:

| Port | Value | CPU range | Mapping |
| ---: | ---: | --- | --- |
| `0x10` | `0x17` | `00000..1FFFF` | RAM (bit-4) |
| `0x11` | `0x0F` | `20000..3FFFF` | RAM (bit-3, page follows window) |
| `0x12` | `0x1F` | `40000..5FFFF` | RAM (bit-4) |
| `0x13` | `0x1E` | `60000..7FFFF` | RAM (bit-4) |
| `0x14` | `0x1D` | `80000..9FFFF` | RAM (bit-4) |
| `0x15` | `0x1C` | `A0000..BFFFF` | RAM (bit-4) |
| `0x16` | `0x01` | `C0000..DFFFF` | ROM file `0xC0000..0xDFFFF` |
| `0x17` | `0x00` | `E0000..FFFFF` | ROM file `0xE0000..0xFFFFF` |

This matches the T450 defaults documented in `banking.md`. The key difference
from v2.1 is port `0x11 = 0x0F` (v2.1 uses `0x0E`). Both expose the upper
128 KiB RAM page in the `0x20000..0x3FFFF` window, but through different
selection mechanisms.

Routine `C000:0327` seeds the default bank mirrors:

```asm
[147B] = 0F1F  ; port 0x12 from AL=1F, port 0x11 from AH=0F
[147D] = 1E1D  ; port 0x14 from AL=1D, port 0x13 from AH=1E
[147F] = 1C    ; port 0x15
```

## Code Segment Map

Confirmed from a full recursive disassembly trace (4168 blocks, 45996
instructions) starting at `C000:0029` with IRQ, thunk, INT 21h,
menu VM, and dispatch table seeds.

### Window 6 — Port 0x16=0x01, Bank 14, File 0xC0000 (Fixed)

| Segment | File base | Instructions | Role |
| --- | ---: | ---: | --- |
| `C000` | `0xC0000` | 9827 | Low-level firmware: boot, IRQs, banking, I/O ports, diagnostics. |
| `C772` | `0xC7720` | 9851 | Application runtime: word processor, organizer, menus. |
| `DEF0` | `0xDEF00` | 20494 | Service/wrapper layer between C000 and C772. Far-call table targets. |

All three segments share window 6. `DEF0` is the v3.1 equivalent of
v2.1's `DC98`. The high instruction count in `DEF0` reflects its role as
the crossroads — both `C000` and `C772` call into it heavily.

### Window 7 — Port 0x17=0x00, Bank 15, File 0xE0000 (Fixed)

| Segment | File base | Instructions | Role |
| --- | ---: | ---: | --- |
| `EE17` | `0xEE170` | 2261 | Utility library. Calls `C000:3F35` repeatedly. Zero data gaps. |
| `EF8A` | `0xEF8A0` | 265 | Utility routines called from EE17 via far-call with segment alias. |
| `ED1B` | `0xED1B0` | 278 | Bank-switch wrappers. Callbacks from AD00 to DEF0 services. |

### Window 5 — Port 0x15=0x02 (Banked During Call)

| Segment | File base | Instructions | Role |
| --- | ---: | ---: | --- |
| `AD00` | `0xAD000` | 3020 | ROM CARD subsystem. 21-opcode dispatch table at `AD00:0202`. |

### Banked (Dynamic Port Remap)

| Segment | Window | Bank ports | Role |
| --- | ---: | --- | --- |
| `3000` | 1 | `0x11=0x02, 0x12=0x17, 0x13=0x03, 0x14=0x02` | Linguistic engine (spell/grammar/thesaurus). Not traced. |

### RAM Segments (Not Traceable From ROM)

| Segment | Window | Notes |
| --- | ---: | --- |
| `9820` | 4 | Called from `C772:0E55`. Probably ROM CARD execution entry. |
| `73A4` | 3 | Called from `C772:7337`. Runtime-populated code. |

### Absent From v3.1

The v2.1 ROM contains a CSiMON debug monitor at file `0x7C000..0x7FF0A`.
No CSiMON strings or code appear in the v3.1 image; the equivalent high-ROM
space contains the world-clock city database and other application data.

## Reset Chain

The CPU reset vector is at physical `0xFFFF0`, file `0xFFFF0`:

```asm
FFFF:0000  cli
FFFF:0001  jmp far F6E3:0000
```

The reset trampoline at file `0xF6E30` performs two port writes before
entering the normal firmware segment:

```asm
F6E3:0000  cli
F6E3:0001  mov al,01
F6E3:0003  out 16,al
F6E3:0005  mov al,00
F6E3:0007  out 17,al
F6E3:0009  jmp far C000:0000
```

Normal startup then begins at `C000:0000`:

```asm
C000:0000  jmp C000:0029
```

### Comparison With v2.1

| Element | v2.1 | v3.1 |
| --- | --- | --- |
| Reset vector file offset | `0x7FFF0` | `0xFFFF0` |
| Trampoline segment | `F8DC:0000` (file `0x78DC0`) | `F6E3:0000` (file `0xF6E30`) |
| Trampoline port values | `0x16=0x01, 0x17=0x00` | same |
| C000:0000 file offset | `0x40000` | `0xC0000` |
| Bank seed routine | `C000:0225` | `C000:0327` |
| Port 0x11 default | `0x0E` | `0x0F` |
| Application entry | `C688:000B` | `C772:0004` |
| State marker RAM | `[6809]` | `[146F]` |
| Warm-RAM signature | `"047"` at `C000:6963` | `"218"` at `C000:7799` |
| Diagnostic banner | `"Diagnostic 21BAB047"` (file `0x46912`) | `"Diagnostic 31BAB218"` (file `0xC7789`) |
