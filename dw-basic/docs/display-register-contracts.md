# Display Register Contracts

This note covers the GW-BASIC text-output path used by `SCROUT`:

```text
SCROUT
  -> console_buffer_put_at_cursor
  -> console_draw_at_cursor
     -> console_cell_xy
     -> dw_puts_cs_raw
        -> ROM vector [0204] / DC98:0E81
```

The goal is to preserve only the registers required by the caller/callee
contracts, not to wrap every internal call with broad save frames.

## ROM Text Helper

`dw_puts_cs_raw` calls the T400 2.1 text helper through low-RAM vector `[0204]`
(`DC98:0E81`).

Inspected ROM behavior:

- Entry `AX:BX` is the source string far pointer.
- The wrapper must enter with `DS=0` so `[0204]` and the helper scratch buffer
  at `DS:72E5` refer to low RAM.
- The helper stores the source pointer in stack locals, emits an `FF 40`
  display stream at `DS:72E5`, reads string bytes with `LES BX,[BP-4]`, and
  calls `C000:67AD`.
- `DC98:0E81` explicitly changes `ES`.
- `C000:67AD` saves/restores `BP`, `DI`, `SI`, `DX`, and `CX`.
- `SS` is used implicitly for `BP`-relative locals but is not modified.

Current `dw_puts_cs_raw` contract:

- Input: `AX = CS-relative NUL-terminated string`.
- Preserves: `AX`, `BX`, `DS`, `ES`.
- Preserved by inspected callee behavior: `CX`, `DX`, `SI`, `DI`, `BP`, `SS`.
- Flags are not preserved.

## Console Helpers

`console_cell_xy` converts the logical cell in `console_col/console_row` to
pixel coordinates.

- Output: `CX = x`, `DX = y`.
- Preserves: `AX`.
- Clobbers: `CX`, `DX`, flags.

`console_draw_at_cursor` draws the string in `AX` at the current logical cell.

- Input: `AX = CS-relative NUL-terminated string`.
- Preserves: `CX`, `DX`.
- Relies on `dw_puts_cs_raw` and the ROM helper preserving segment registers.

`console_buffer_put_at_cursor` updates the 80x8 shadow text buffer.

- Input: `AL = character`.
- Preserves: `AX`, `BX`, `DI`.
- Clobbers: `DX`, flags.

## SCROUT

No standalone Microsoft-source ABI block for `SCROUT` was found. The routine is
an OEM-supplied external, so the conservative ABI is to preserve caller state
except for explicit result flags. The original direct call sites in
`gw-basic/scndrv.asm` and `gw-basic/gwsts.asm` confirm that several registers
are live across calls.

Direct-call evidence:

- `gw-basic/scndrv.asm:1786..1791` sets `AX=" "`, loops on `DH` against `CH`,
  and calls `SCROUT` inside the loop. `AX`, `CX`, and `DX` must survive.
- `gw-basic/scndrv.asm:1946..1952` sets `DH` and `AX`, calls `SCROUT`, then
  uses `DH` immediately to update the line terminator. `DX` must survive.
- `gw-basic/scndrv.asm:2059..2066` loops with `LODSW`, calls `SCROUT`, then
  increments `DH` and decrements `CH`. `SI`, `CX`, and `DX` must survive.
- `gw-basic/scndrv.asm:2166..2173` saves only `AX` and `DX` around `SCROUT`
  inside code that still uses `BX`/`CX` state afterward. `BX` and `CX` must
  survive.
- `gw-basic/gwsts.asm:1530..1549` saves `AX`, `BX`, and `CX` around `SCROUT`
  but increments `DH` after return. `DX` must survive.
- `gw-basic/scndrv.asm:1114..1117` uses carry from `SCROUT` only for the
  optional escape-sequence path. With `ESCCTL=0`, returning carry clear is the
  non-continuation result.

No original direct caller saves segment registers around `SCROUT`; they are
therefore part of the caller state that an OEM implementation must not damage.
`BP`, `DI`, and `SS` are likewise not arguments to `SCROUT` and are not saved by
callers.

Current `SCROUT` contract:

- Input: `AX = character`, `DH = 1-based column`, `DL = 1-based row`.
- Output: carry clear; escape-sequence continuation is not implemented.
- Preserves: `AX`, `BX`, `CX`, `DX`, `SI`, `DI`, `BP`, `DS`, `ES`, `SS`.
- Internally saves `AX`, `BX`, `CX`, and `DX`, plus one word for the console
  cursor snapshot. Those are the registers this implementation modifies
  directly. `SI`, `DI`, `BP`, and `SS` are not modified by `SCROUT`; `DS` and
  `ES` are preserved by `dw_puts_cs_raw` at the ROM-call boundary.
