# dw-basic Porting Notes

The Microsoft GW-BASIC source is organized for OEM retargeting. The useful
porting boundary is the generalized I/O and OEM hook layer, not the DOS process
model.

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
| `SCROUT` | Draw a character at a cursor position. | LCD text/vector path or direct framebuffer writer. |
| `SCRINP` | Read character under cursor. | Framebuffer-backed screen model, or initially stub. |
| `SCROLL` | Scroll screen window. | Framebuffer line copy plus clear. |
| `CLREOL` | Clear from cursor to end of line. | Framebuffer fill. |
| `SETCSR` | Cursor display mode/position. | Initially no-op or inverse-cell cursor. |
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

The disk path is less clean. `giodsk.asm` uses CP/M/MS-DOS FCB-style calls via
the `CALLOS` macro in `msdosu`. A first bring-up can disable disk commands or
replace `CALLOS` with a DreamWriter file API shim for the subset used by
`LOAD`, `SAVE`, sequential input, and sequential output.

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
