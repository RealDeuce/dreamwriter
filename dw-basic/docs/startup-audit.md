# DW-BASIC Startup Audit

This note audits the ported GW-BASIC path from the DreamWriter ROM CARD entry
through the first jump to `READY`. It is intentionally limited to the linked
configuration in `dw-basic/GNUmakefile`: text console and keyboard are enabled,
graphics, disk files, printers, serial, joystick/lightpen, raw I/O, PEEK/POKE,
USR, and sound/play are disabled.

## Happy-Path Call Graph

`EROMCARD.X` wrapper (`src/eromcard_gw.asm`)

- ROM loader calls `entry`.
- `entry`
  - saves the ROM loader stack.
  - reserves a private wrapper stack and computes `basic_limit`.
  - displays `LOADING DW-BASIC` via `print_message -> dw_puts_cs`.
  - `open_overlay -> ROM vector 0x0244` opens `I:GWBASIC.OVR`.
  - `read_overlay -> ROM vector 0x0248` reads the overlay at
    `GW_BASIC_LOAD_OFFSET`.
  - `close_overlay -> ROM vector 0x0250`.
  - `verify_overlay` checks the first 16 overlay bytes against the built file.
  - stores `basic_limit` in `DW_LOADER_LIMIT`.
  - sets `SS:SP` to the BASIC work area and jumps to `GW_INIT`.

`INIT` (`src/gw/gwinit.asm`)

- Establishes flat ROM CARD segment model:
  - `DS = ES = SS = CS`.
  - temporary stack at `BUF+128`.
  - copies ROM constants from `CONSTR` to `RAMLOW`.
- Screen/device bring-up:
  - `SCNIPL`
    - clears `ESCFLG`.
  - `GWINI`
    - `CLRSCN -> console_clear`.
    - `SCNSWI(80, 8)` sets the physical/logical screen size and reserves the
      last LCD row for soft keys.
    - clears `KEYSW`.
    - `SCNBRK`.
    - `SCNCLR`.
  - `SCNCLR`
    - `TTBINI`.
    - `GRPINI -> GRPSIZ`.
    - `WHOME`, then `SCNLOC`.
    - `KEYDSP`; with `KEYSW=0`, this only calls `CLREOL` on the soft-key row.
  - `SNDRST`.
  - `GIOINI`
    - `MSISET`, patched to a ROM CARD no-op instead of installing DOS
      interrupt vectors.
    - clears transient file/device state.
    - `DOALDV` initializes linked non-disk devices:
      - `KYBINI`.
      - `SCNINI`.
      - `CONS` no-op init.
    - `FINPRT` resets `PTRFIL` to the keyboard/screen console.
- Memory setup:
  - sets `MEMSIZ` and `MAXMEM` from `DW_LOADER_LIMIT`.
  - forces an empty command tail at `CPMWRM+128`.
  - computes `TXTTAB`, `STKLOW`, `FILTAB`, `FRETOP`, `TOPMEM`, and the final
    BASIC stack.
  - `REASON` validates available memory.
- Startup display:
  - sets `KEYSW=255`.
  - `GETHED` returns the empty OEM heading string with Z set.
  - `STROUT` prints the OEM heading string, then the Microsoft heading.
  - `SKEYON`
    - sets `KEYSW=255`.
    - `FKYADV` confirms one soft-key page exists.
    - `KEYDSP`.
  - `KEYDSP`
    - turns cursor off with `SETCSR -> CSRDSP`.
    - `GETFMT -> FKYFMT`.
    - for each displayed key, writes key number/text with `SCROUT`.
    - toggles text attributes through `XFGBG -> GETFBC/SETFBC`.
    - restores the user cursor with `SETCSR -> CSRDSP`.
- Tail path:
  - sets `INITFG=255`.
  - jumps to `INITSA`.

`INITSA` (`src/gw/itsa86.asm`)

- `NODSKS`.
  - This is the real GW-BASIC startup scratch path, not the disabled disk-file
    shim. It clears program text and falls through to `CLEARC`.
  - `CLEARC -> INITRP -> GRPRST -> GRPINI/GETFBC/SETATR -> SNDINI -> STKINI`.
- `MAPINI`.
  - Patched to `ret` because the flat ROM CARD build already has the final
    segment layout.
- Ensures the program text starts with a zero terminator.
- Reads the forced-empty command tail from `TEMP8`.
- Empty tail branches to `GREADY -> READY`.
- Non-empty tail would jump to `LRUN`, but this path is unreachable in the
  current wrapper because `INIT` writes a zero command tail.

## Startup OEM Contract Audit

The following hooks are on the happy path and must behave as real contracts,
not generic stubs.

| Symbol | Caller contract | Current audit result |
| --- | --- | --- |
| `CLRSCN` | Clear LCD and shadow text, preserve caller state. | Implemented by `console_clear`. It now uses `cld` before `rep stosb`, so inherited DF cannot corrupt the shadow buffer. |
| `SCNSWI` | Machine-independent screen size setter. | Real converted routine; `GWINI` passes 80 columns and 8 rows. |
| `SCNCLR` | Home text/graphics cursor and refresh soft-key row. | Real converted routine; depends on `GRPINI`, `GRPSIZ`, `KEYDSP`, `CLREOL`. |
| `GRPINI` | Center graphics cursor using physical pixel dimensions. | Real `gengrp` routine. Uses `GRPSIZ`, which returns 479x63 as max coordinates. |
| `GRPRST` | Preserve registers and reset graphics state. | Real `gengrp` routine. Uses `GETFBC` and `SETATR`; both must return normally. |
| `GETFBC` | Return deterministic foreground/background values. | Fixed to return foreground `AL=1`, background `BL=0`, carry clear. The previous version left `BX` undefined. |
| `SETATR` | Accept default draw attribute during graphics reset. | Minimal success return. Safe while `PIXSIZ=0`; real pixel drawing is disabled. |
| `GWINI` | OEM startup initialization. | Clears the LCD, sets 80x8 screen size, clears soft-key state, and delegates to real screen init. It preserves `AX`/`CX`; no downstream startup caller depends on other registers. |
| `MSISET`/`MSIRST` | Install/restore DOS Ctrl-C and critical-error vectors while preserving registers. | Patched to `RET` for ROM CARD. The original converted body used DOS `INT 21h` vector services, which are not valid in this environment. |
| `SCROUT` | Draw one character at 1-based `DH` column and `DL` row without changing logical cursor. | Implemented over the DreamWriter firmware text vector plus a shadow cell buffer. Returns carry clear. This is correct for startup because `ESCCTL=0` and startup only emits normal bytes. |
| `CLREOL` | Clear from 1-based `DH,DL` to end of line. | Implemented by repeated `SCROUT`. Used by `KEYDSP` with soft keys off. |
| `SCRINP` | Read one screen cell at 1-based `DH,DL`. | Implemented from the shadow text buffer. Not on startup before `READY`, but required by enabled screen editor paths. |
| `CSRDSP` | Display or hide cursor type `AL` at caller-provided `DX` position; preserve registers/flags. | Implemented. `SETCSR` supplies `AL` from `CSRTYP`; callers that need a visible cursor set `DX` first. Off-cursor calls do not require a meaningful position. |
| `KEYINP` | Poll keyboard. Z set means no key; C set means two-byte/control key. Preserve non-result registers. | Implemented over DreamWriter INT 21h key status/read calls, with DreamWriter cursor/insert/delete/return translated to the MS Universal editor codes expected by `giokyb`. Not on startup until the first input wait. |
| `FKYADV` | Select/confirm a soft-key page and return NZ if displayable. | Minimal one-page implementation. It intentionally returns NZ. |
| `FKYFMT` | Return `BX` pointing to key count, chars per key, and first key number. | Returns 10 keys, 6 chars/key, first key 1; this matches `GETFMT`'s table layout. |
| `GETHED` | Return OEM heading pointer in `BX`; Z set controls heading behavior. | Returns an empty string and Z set, so the Microsoft heading is still printed. |
| `SYSTME` | Exit to host/system. | Currently halts forever. Not on the successful startup-to-READY path, but `SYSTEM` will not return to the ROM CARD menu yet. |

## Stub Audit

The linked image still has several symbols that exist only because converted
modules reference optional OEM surfaces. They fall into three groups.

### Disabled Feature Errors

These should enter a GW-BASIC error path because their feature is disabled:

- `DLINE`, `GPUTG`, `MACLNG`, `MCLXEQ`, `PEKFLT`, `POKFLT`, `SETC`.

These currently jump to `FCERR`. That is acceptable for unreachable or disabled
statements/functions because GW-BASIC's error path resets the runtime stack.

`LCPY` was not safe as a direct `FCERR` jump. `LCOPYS` pushes `BX`, calls
`LCPY`, and explicitly expects the OEM routine to signal failure with carry set
so the caller can pop `BX` before raising `FCERR`. `LCPY` now returns `STC`.

### Startup-Used Minimal Success Hooks

These are not full feature implementations, but they are used by enabled code
and must return success for startup/editor correctness:

- `GETFBC`, `SETFBC`, `SETATR`, `GRPSIZ`, `PIXSIZ`.
- `FKYADV`, `FKYFMT`.
- `CSRATR`, `SETCLR`, `SWIDTH`.
- `INFMAP`, `INKMAP`, `MAPSUP`, `EDTMAP`, `PRTMAP`.

The mapping hooks are identity/no-op mappings for the current keyboard and
printer-free configuration. `CSRATR`, `SETCLR`, and `SWIDTH` accept requests but
do not change hardware state; this is acceptable for the first text-mode bringup
but should be revisited when attributes, WIDTH, or inverse-video fidelity become
test targets.

### Deferred Non-Startup Risks

The disk/program-file shim labels now jump to `DERFNF`:

- `CHNENT`, `FILIND`, `LRUN`, `OKGETM`, `OUTLOD`, `PRGFLI`.

That is not on the current happy path because the command tail is forced empty,
but it matters for user-visible `LOAD`, `RUN "file"`, `MERGE`, or related
statements. Earlier bring-up code jumped these through `NODSKS`; that was wrong
because `NODSKS` is the startup scratch routine, not a user command error path.
`DERFNF` is the conservative disabled-backend answer until real file support is
implemented.

The lightpen/joystick/trap hooks (`RDPEN`, `RDSTIK`, `RDTRIG`, `POLLEV`,
`POLCOM`) return success/no event. They are not part of the enabled startup path
and are currently blocked by the disabled feature configuration.

## Direction Flag Audit

The startup path crosses both converted Microsoft code and DreamWriter shim
code. Any shim using string instructions must not inherit an unknown DF.

- `console_clear` now executes `cld` before clearing the shadow text buffer.
- `console_puts` now preserves flags and executes `cld` before `lodsb`.
- `scroll_byte_rect` saves flags, chooses `cld` or `std` internally, executes
  `cld` before return, then restores the caller flags with `popf`.
- `console_clear_bottom_row` saves/restores flags and uses `cld` before its
  `rep stos*` operations.
- Converted GW-BASIC string loops audited in the startup display path already
  issue `cld` before `lodsb`/`stos*`.

## Remaining Audit Items

- Replace disk/program-file shim behavior with real file support before enabling
  command tails or BASIC file commands beyond clean `File not found` failures.
- Implement `SYSTME` as a proper return to the ROM CARD loader if `SYSTEM` is
  expected to work.
- Decide whether `SETFBC`/`GETFBC` and `CSRATR` should drive real inverse-video
  state. Startup no longer depends on this, but soft-key reverse video currently
  cannot be visually faithful.
- Keep `gengrp` linked only while its startup reset helpers are useful. If
  graphics statements remain disabled, all drawing entry points must continue to
  fail before reaching the pixel backend hooks.
