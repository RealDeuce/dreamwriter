# dw-basic

`dw-basic` is a NASM-targeted DreamWriter BASIC port workspace.

The starting point is Microsoft's 1983 GW-BASIC source tree in `../gw-basic`.
That tree is treated as read-only reference material. This directory is where
DreamWriter-specific build files, NASM sources, generated port artifacts, and
hardware shims should live.

## First Milestone

The current first milestone is deliberately small:

1. Build a valid `EROMCARD.X` with NASM.
2. Launch it through the T400 ROM CARD loader.
3. Print through the DreamWriter shim layer over the firmware display vector.
4. Read and echo a simple line through the reusable console layer.
5. Return cleanly to the ROM CARD caller.

Build it:

```sh
gmake -C dw-basic
```

Insert it into a formatted SRAM card image:

```sh
gmake -C dw-basic card
```

Default outputs:

```text
dw-basic/build/EROMCARD.X
/tmp/dw-card-1m-dw-basic.bin
```

Build the mechanically converted GW-BASIC object set and link it with the
vendored flatlink copy:

```sh
gmake -C dw-basic gw-basic-bin
```

That writes a zero-origin flat image and map:

```text
dw-basic/build/gw-basic.bin
dw-basic/build/gw-basic.map
```

This is a linker milestone, not yet the ROM CARD payload. The current linked
image resolves the converted interpreter modules and DreamWriter OEM hooks, but
still needs a loader/runtime wrapper before it can be launched by the firmware.

Build the first GW-BASIC ROM CARD payload:

```sh
gmake -C dw-basic basic-payload
```

That writes:

```text
dw-basic/build/EROMCARD-GW.X
dw-basic/build/GWBASIC.OVR
```

Install that payload into a formatted SRAM image:

```sh
gmake -C dw-basic basic-card
```

The BASIC card image installs a small `EROMCARD.X` first-stage loader plus
`GWBASIC.OVR`. `flatlink -offset 2048` gives the overlay addresses starting at
`0x0800`; the overlay file itself starts with the first byte to load there. The
first-stage loader opens `I:GWBASIC.OVR`, reads it to `CS:0800`, checks the ROM
CARD loader's incoming `AX` work-memory limit, then jumps into GW-BASIC. By
default it requires the linked static image end plus 4096 bytes of free BASIC
space; override with `GW_BASIC_MIN_FREE=...`. The default flat64 build disables
graphics with `GW_ENABLE_GRAPHICS=0`; use `gmake -C dw-basic flat-size-report`
to compare the flat image with the graphics-enabled profile and list large
static reservations.

One MAME command line for the generated card image:

```sh
../mame/drwrt400 drwrt400 -pccard melcard_1m -sramcard /tmp/dw-card-1m-dw-basic.bin
```

Expected display:

```text
LINE 03 SHOULD BE TOP
...
LINE 10 - PRESS KEY
```

The first preflight screen should show lines 3 through 10 after the console
forces bottom-row scrolling. Press any key.

The second preflight screen should show a small raw-pixel box near the left side
and a copied box lower and to the right. That screen calls the real `SCROLL`
primitive on a graphics-only rectangle, so it checks that scrolling moves pixels
that were not drawn through the text shadow buffer. Press any key.

The third preflight screen exercises the easier GW-BASIC OEM screen hooks. It
should show `SCROUT WROTE THIS`, then `SCRINP OK`, and the `CLREOL` line should
have the text after the marker erased. Press any key.

The normal smoke screen then appears:

```text
DW-BASIC BRINGUP
>
```

Printable keys should echo on the prompt line. The firmware reports Return as
the select event byte `0xDA`; the smoke target accepts that and ASCII carriage
return as line terminators. Accepted input should show the captured line after
`LINE:`; Backspace should erase one character; Escape should show `CANCELLED`.
After the result/cancel message, press any key to return.

The prompt is backed by `src/include/dwconsole.asm`, not by a one-off redraw
loop. It maintains logical 6x8 text-cell cursor state and emits changed
characters through the ROM text vector. The smoke target caps input at 78
printable characters, which fits the 80-column row after the `> ` prompt.
Backspace is anchored to the input buffer position, so the console layer is
ready for wrapped line editing even though this smoke target stays on one row.
During line input, the console displays a non-blinking block cursor using the
ROM reverse-video style control around the character in the current screen
cell. The console keeps an 80x8 shadow text buffer so hiding the cursor can
restore the cell it inverted.

## Port Shape

The practical port plan is:

1. Keep GW-BASIC's interpreter, tokenizer, evaluator, math, and editor logic as
   close to source as possible.
2. Port the old assembler syntax to NASM in controlled chunks.
3. Replace the OEM/OS layer with DreamWriter shims.
4. Initially disable graphics, COM, PLAY, and other nonessential features.
5. Bring up direct mode before saved-program load/save.

See [`docs/porting.md`](docs/porting.md) for the initial module map and
DreamWriter shim inventory.
