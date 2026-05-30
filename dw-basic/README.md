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

One MAME command line for the generated card image:

```sh
../mame/drwrt400 drwrt400 -pcmcia melcard_1m -sramcard /tmp/dw-card-1m-dw-basic.bin
```

Expected display:

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
