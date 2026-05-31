# dw-basic Porting Notes

The Microsoft GW-BASIC source is organized for OEM retargeting. The useful
porting boundary is the generalized I/O and OEM hook layer, not the DOS process
model.

The target CPU is the NEC V20, so the port may use 80186-class instruction
forms such as `pusha`/`popa`, `enter`/`leave`, immediate `push`, immediate
`imul`, and `bound` when they solve a concrete porting problem. The current
flat model still assembles as 16-bit code and avoids newer instructions unless
they make an OEM wrapper contract clearer.

## Reference Modules

High-value files in `../gw-basic`:

| File | Role |
| --- | --- |
| `oem.h` | Feature switches and OEM configuration. |
| `gio86u` | Generalized I/O dispatch function constants. |
| `giotbl.asm` | Device name table and dispatch/init/term table generator. |
| `gio86.asm` | Device-independent OPEN/CLOSE/input/output plumbing. |
| `giodsk.asm` | Disk/file dispatch implementation using old FCB-style OS calls. |
| `giokyb.asm` | Keyboard queue, key polling, soft key, and break handling. |
| `gioscn.asm` | SCRN device implementation over the screen driver. |
| `scndrv.asm` | OS-independent screen driver over OEM primitives. |
| `gwinit.asm` | Startup, data initialization, memory sizing, and banner path. |
| `gwmain.asm` | Main interpreter, statement dispatch, direct mode, and program flow. |
| `gwram.asm` | Runtime data declarations and initial RAM layout. |
| `gwdata.asm` | Constants, messages, tables, and device state. |

## DreamWriter Shim Boundary

The first DreamWriter-specific module should provide these primitives:

| Primitive | GW-BASIC use | DreamWriter source |
| --- | --- | --- |
| `SCROUT` | Draw a character at a cursor position. | Implemented over the console shadow buffer and ROM text vector. |
| `SCRINP` | Read character under cursor. | Implemented from the console shadow buffer. |
| `SCROLL` | Scroll screen window. | Framebuffer line copy plus clear. |
| `CLREOL` | Clear from cursor to end of line. | Implemented by blanking cells through `SCROUT`. |
| `SETCSR` | Cursor display mode/position. | The converted GW-BASIC routine calls the DreamWriter `CSRDSP` hook. |
| `KEYINP` | Poll for one key without blocking. | T400 keyboard vector or direct key queue. |
| `DONOTE` | Start/stop sound. | T400 beeper port path; initially stub. |

The first checked-in shim layer is intentionally smaller and lives in
`src/include/dwapi.asm`:

| Shim | Current behavior |
| --- | --- |
| `dw_puts_cs` | Prints a NUL-terminated string from the current code segment through low-RAM vector `[0204]` / `DC98:0E81`. |
| `dw_getkey` | Blocks for one key through low-RAM vector `[0230]` / `DC98:0CF9`. |

These wrappers preserve the application data segment around firmware calls, but
enter the T400 2.1 firmware with `DS=0`. The text helper receives the string as
an explicit `AX:BX` far pointer and uses `DS:72E5` as its temporary
display-command buffer, matching the ROM-card loader's own call state.

Keep ROM-specific call targets encapsulated behind this shim layer. For the
T400 2.1 ROM, `DW_VEC_PUTS` and `DW_VEC_GETKEY` name the low-RAM vector table
offsets. A later port to another DreamWriter ROM should provide the same shim
entry points and adjust only this vector table binding or a small
ROM-compatibility include.

The `EROMCARD.X` entry must also preserve the caller's `DS` across the whole
program. The ROM-card loader calls the entry as a far target and expects to
return to firmware data state afterward; leaving `DS=CS` can make the caller
appear hung after the external program exits.

`src/include/dwconsole.asm` is the first reusable consumer of this shim layer.
It tracks an 80x8 logical text grid using 6x8 cells and provides `console_putc`,
`console_puts`, `console_backspace`, `console_goto`, `console_clear`, and
`console_read_line`. This is the intended nucleus for direct-mode BASIC console
I/O; the ROM-card smoke program should stay a thin caller of these routines.
Line editing records the input start cell and maps Backspace from the buffer
length back to a screen cell, so wrapped input can erase the previous character
instead of depending on whatever cursor column happens to be current.
The initial cursor is a non-blinking reverse-video space, emitted as
`F2 char F3` through the ROM text helper. The console maintains an 80x8 shadow
text buffer so the cursor can invert and later restore the actual character in
the cell. `console_show_cursor` records the logical and displayed cursor cell,
and `console_hide_cursor` erases that recorded cell rather than assuming the
logical cursor has not moved. A logical column of 80 is the one-past-right-edge
state and displays by sticking to column 79, so a full line still has a visible
cursor.

The display register-preservation contracts for `SCROUT` through the ROM text
vector are documented in [`display-register-contracts.md`](display-register-contracts.md).

`SCROLL` is implemented as the GW-BASIC OEM primitive, using the source cell,
destination cell, and size registers expected by `scndrv.asm`. It moves the
matching 80x8 shadow text cells and raw LCD pixels for the same 6x8-cell
rectangle. The pixel path is a bit-level memmove, so non-byte-aligned 6-pixel
columns and overlapping down/right moves work correctly. Byte-aligned
rectangles use the V20/8086 string-instruction fast path (`rep movsw` forward,
`rep movsb` backward), so the common full-width vertical text scroll does not
fall through to the bit-at-a-time path. `SCROLL` deliberately does not clear
newly exposed cells; the generic screen driver does that with `CLREOL`/`SCROUT`
after calling `SCROLL`. The current console newline path also calls this
primitive, then clears the exposed bottom row for its own simpler console
semantics.

Direct LCD helpers use `lcd_framebuffer_base` as runtime display state. It is
initialized to the normal T400 framebuffer at `0x1000`, but code that switches
LCD scanout, such as the BASIC wrapper's alternate `0x8000` framebuffer, must
call `lcd_set_framebuffer_base` after changing the display buffer. The
framebuffer address is not a compile-time property of the console. Near code
keeps `DS` as the application data segment; direct framebuffer copies use
explicit segment-zero memory accesses instead of changing `DS` around console
state reads.

`SCROUT`, `SCRINP`, `SCROLL`, and `CLREOL` are exported with the 1-based
position contract used by `scndrv.asm`: `DH/AH/BH=column`, `DL/AL/BL=line`.
They preserve the console's local cursor state because GW-BASIC tracks cursor
position in its own screen-driver variables and passes explicit positions to
the OEM hooks. `CSRDSP` is the cursor display OEM hook; it receives `AL` as the
cursor type and reads the canonical 1-based position from `CSRX`/`CSRY`.

`src/gw/dwio.asm` exports the OMF-facing DreamWriter hook module. It reuses
the same console primitive layer for `CLRSCN`, `SCROLL`, `SCROUT`, `SCRINP`,
and `CLREOL`, and implements `KEYINP` as a nonblocking poll through the ROM's
`INT 21h` keyboard services. OEM wrappers are kept strict: unless a return
register or flag is part of the documented contract, the wrapper preserves it.
The lower `dw_puts_cs_raw` and `dw_getkey` firmware-vector wrappers follow the
same rule rather than relying on inspected ROM implementation details. The T400
keyboard table reports cursor events as `0x10..0x13`, physical `INSERT` as
`0x0D`, and physical `ENTER` as `0xDA`.
`KEYINP` maps those into Microsoft Universal keyboard controls:

| DreamWriter event | MS Universal result |
| ---: | ---: |
| `0x10` right | `AX=0xFF1C`, carry set |
| `0x11` left | `AX=0xFF1D`, carry set |
| `0x12` down | `AX=0xFF1F`, carry set |
| `0x13` up | `AX=0xFF1E`, carry set |
| `0x0D` insert | `AX=0xFF12`, carry set |
| `0x7F` delete, if produced | `AX=0xFF7F`, carry set |
| `0xDA` enter/select | `AL=0x0D`, carry clear |

Returning cursor and editor controls in the `0xFFxx` form is important:
`POLKEY` only runs `ON KEY` trap checks for two-byte MS Universal control
functions, and the line editor treats `AH=0xFF` as an editor operation rather
than as two printable bytes.

This matches the GW-BASIC split: text scrolling is not a graphics command, but
on a shared bitmap display it must move whatever pixels are already in the
scrolled rectangle rather than redrawing only shadow text cells and erasing
plotted graphics.

The disk path is less clean. `giodsk.asm` uses CP/M/MS-DOS FCB-style calls via
the `CALLOS` macro in `msdosu`. A first bring-up can disable disk commands or
replace `CALLOS` with a DreamWriter file API shim for the subset used by
`LOAD`, `SAVE`, sequential input, and sequential output.

## Linker

The converted GW-BASIC modules are assembled with `nasm -f obj` and linked with
the vendored `third_party/flatlink` copy:

```sh
gmake -C dw-basic gw-basic-bin
```

The target uses `flatlink -f bin -offset 2048 -maxfixups 10000`, producing
`build/gw-basic.bin` and `build/gw-basic.map`. Offset `0x0800` leaves room for
the ROM CARD header and first-stage loader in the same segment. The card build
copies the flatlink output to `build/GWBASIC.OVR`; the file itself starts with
the first byte that must be loaded at `CS:0800`. `src/eromcard_gw.asm` opens
`I:GWBASIC.OVR`, reads it back to `CS:0800`, and jumps to the map-derived
`INIT` offset.

The local flatlink copy has two small compatibility fixes needed by NASM's OMF
output for this source set:

| Fix | Reason |
| --- | --- |
| Segment-zero `PUBDEF` records are accepted as absolute public symbols. | `gwdata.obj` exports absolute constants such as `OPCNT` and `CNSLEN`; other modules import them. |
| The per-object extern-name limit uses the allocated fixup-name capacity instead of the segment limit. | `gwmain.obj` has more than 100 extern names. |

The first wrapped payload is `build/EROMCARD-GW.X`, built by
`gmake -C dw-basic basic-payload`. It is intentionally a small first-stage
loader: the ROM CARD entry sets `DS=CS`, checks the loader-provided work-memory
limit against `LSTVAR + 2 + GW_BASIC_MIN_FREE`, loads `GWBASIC.OVR` while still
using the ROM loader's original stack, then switches to a private stack below the
loader-provided limit before jumping to GW-BASIC's `INIT`. If any check fails,
it prints an error and returns. The default reserve is 4096 bytes and can be
overridden on the make command line.

## Initial Feature Set

Start small:

| Area | First-pass choice |
| --- | --- |
| Direct mode | Required. |
| Program entry/edit/list/run | Required after direct mode. |
| Floating point/math | Keep. |
| Sequential files | Second milestone. |
| Random files/FIELD/GET/PUT | Defer. |
| Graphics | Defer. |
| COM/LPT devices | Defer. |
| `SOUND`/`BEEP` | Stub first, wire later. |
| `PEEK`/`POKE`/`INP`/`OUT` | Decide explicitly; useful on this machine, risky for users. |

## NASM Conversion Rules

Expected mechanical work:

| Original pattern | NASM direction |
| --- | --- |
| `CSEG SEGMENT`, `DSEG SEGMENT`, `ASSUME` | Replace with explicit `section`/segment conventions or flat binary layout. |
| `INCLUDE OEM.H` | Convert to NASM `%include` and `%define` switch files. |
| `PUBLIC` / `EXTRN` | Convert to `global` / `extern`. |
| `OFFSET symbol` | Usually `symbol`; audit cases where segment-relative values matter. |
| `LOW expr` | Usually `expr & 0xff`; prefer named constants where possible. |
| `INS86 ...` | Decode each emitted instruction and replace with real NASM instructions. |
| MASM macros | Convert only the macros still used by the selected first-pass modules. |

The goal is not to translate every file blindly. Bring up the smallest linked
subset first, then add features behind the DreamWriter shim layer.
