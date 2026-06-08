# DEF0 Display Services

The DEF0 display service layer. These routines build display scripts
dynamically in a work buffer at `[18F1]` using `FF xx` command opcodes,
then call `C000:3F35` (the display script renderer documented in
[`display-stream.md`](display-stream.md)) to render them.

All use the C-style stack frame convention: `PUSH BP; MOV BP,SP;
SUB SP,n`.

Far-call table entries #0-#11 and #15 are display services.

## Far-Call Table Display Entries

| # | RAM addr | Target | Purpose |
| ---: | --- | --- | --- |
| 0 | `[0200]` | `C000:3F35` | Display script render (far wrapper). |
| 1 | `[0204]` | `DEF0:0D91` | Build and render display script from parameters. |
| 2 | `[0208]` | `DEF0:0DF5` | Display page setup: build `FF 44` command, render. |
| 3 | `[020C]` | `DEF0:115C` | Display subsystem query/init (calls 0D80, 0DF5). |
| 4 | `[0210]` | `DEF0:1471` | Display area compute (BX*CX multiplication for page offset). |
| 5 | `[0214]` | `DEF0:1806` | Display parameter config (checks `[BP+8]` stack arg). |
| 6 | `[0218]` | `DEF0:1B00` | Display composite: calls 13A7, 1471, 1639. |
| 7 | `[021C]` | `DEF0:2097` | Display state query. |
| 8 | `[0220]` | `DEF0:0D80` | Display init: renders 15-byte script from `DEF0:EFFE`. |
| 9 | `[0224]` | `DEF0:0F87` | Display mode dispatch (CX=1..4 selects mode). |
| 10 | `[0228]` | `DEF0:0FE4` | Character filter (replaces `0x30` with `0x20` space). |
| 11 | `[022C]` | `DEF0:1775` | Set display callback pointers at `[1AF1..1AF3]`. |

Entry #15 (`[023C]` → `C000:3F47`) is a serial input wrapper, not
a display service. See [`c000-serial-io.md`](c000-serial-io.md).

## DEF0:0D80 — Display Init

Renders a fixed 15-byte display script from `DEF0:EFFE`. Called before
most display operations as a "clear/reset" step.

```asm
; file 0xDFC80
DEF0:0D80  51                push cx
DEF0:0D81  B8 0800           mov ax,8
DEF0:0D84  BB FEEF           mov bx,EFFE       ; script source
DEF0:0D87  B9 0F00           mov cx,F           ; 15 bytes
DEF0:0D8A  9A 353F 00C0      call far C000:3F35 ; render
DEF0:0D8F  59                pop cx
DEF0:0D90  CB                retf
```

## DEF0:0D91 — Build Display Script From Parameters

Takes AX, BX as parameters. Builds a display script command sequence
at `[18F1]` starting with `FF` prefix bytes, then calls `C000:3F35`
to render the constructed script.

```asm
DEF0:0D91  55                push bp
DEF0:0D92  8B EC             mov bp,sp
DEF0:0D94  83 EC 06          sub sp,6          ; 6-byte local frame
DEF0:0D97  51                push cx
DEF0:0D98  89 46 FC          mov [bp-4],ax
DEF0:0D9B  89 5E FE          mov [bp-2],bx
DEF0:0D9E  C7 46 FA F118     mov word [bp-6],18F1  ; script buffer
DEF0:0DA3  8B 5E FA          mov bx,[bp-6]
DEF0:0DA6  C6 07 FF          mov byte [bx],FF  ; FF prefix
DEF0:0DA9  FF 46 FA          inc word [bp-6]
DEF0:0DAC  8B 5E FA          mov bx,[bp-6]
DEF0:0DAF  C6 07 40          mov byte [bx],40  ; FF 40 = position command
```

Continues building the script and rendering it. The buffer at `[18F1]`
is used as scratch space for dynamically-generated display commands.

## DEF0:0DF5 — Display Page Setup

Takes AX (page mode), BX/CX/DX (dimensions). Builds an `FF 44` display
page command in the `[18F1]` buffer and renders it. This is the main
"set up a display page" call used by the menu system and application UI.

Large routine (file `0xDFCF5..0xDFE87`), 402 bytes.

## DEF0:115C — Display Subsystem Query/Init

Called from `DEF0:5C2E` (warm-start reinit). Takes AX (query type),
BX (parameter), CX (count). Calls `DEF0:0D80` (display init), then
builds and renders display pages via `DEF0:0DF5`.

## DEF0:1471 — Display Area Compute

Computes a display buffer offset from AX (page), BX*CX (area
dimensions). Used to calculate where in the display buffer to write.

## DEF0:1639 — Display Script Builder

Builds a complete display script in `[18F1]` from parameters and
renders it via `C000:3F35`. Called from `DEF0:1B00` (the composite
display service).

## DEF0:1B00 — Display Composite

The highest-level display service. Takes 4 parameters (AX, BX, CX, DX)
describing a full display operation, builds the necessary scripts by
calling `DEF0:13A7`, `DEF0:1471`, and `DEF0:1639`, then renders the
result.

## Display Script Buffer

The display services build scripts at `[18F1]` using `FF xx` command
opcodes:

| Command | Meaning |
| --- | --- |
| `FF 40` | Position (followed by x, y coordinates) |
| `FF 42` | Bitmap blit (followed by dimensions and source pointer) |
| `FF 44` | Page setup (followed by page parameters) |
| `FF 00` | Display control |
| `FF 02` | Text with position |
| `FF 04` | Attribute/mode change |
| `FF 06` | Resource reference |

These are the same opcodes processed by the display stream renderer
at `C000:6557`.
