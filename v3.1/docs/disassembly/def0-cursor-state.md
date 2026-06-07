# DEF0 Cursor and Display State Management

The cursor positioning, display state management, and display script
builder routines at `DEF0:C000..DA5C` (209 blocks). Includes the
wrapper inner routines (`CE03`, `CE36`, `CE6A`, `CE92`) called from
the thin wrappers at `DEF0:000B..0042`, the date/time processing
at `DEF0:C5BC`, and the display script builder `DEF0:CFDE`.

See [`def0-wrappers.md`](def0-wrappers.md) for the thin wrappers
and [`def0-display-rendering.md`](def0-display-rendering.md) for
the low-level rendering chain.

## Wrapper Inner Routines

### DEF0:CE03 — Display Clear (wrapper at DEF0:000B)

Calls `DEF0:0D80` (display init), clears 7 display state words at
`[A9C9..A9D5]`, then calls `DEF0:D234` (display script builder) to
render the cleared state.

```asm
DEF0:CE03  9A800DF0DE     call far DEF0:0D80   ; display init
DEF0:CE08  C706D5A90000   mov word [A9D5],0    ; clear state
DEF0:CE0E  C706D1A90000   mov word [A9D1],0
DEF0:CE14  C706D3A90000   mov word [A9D3],0
DEF0:CE1A  C706CFA90000   mov word [A9CF],0
DEF0:CE20  C706CDA90000   mov word [A9CD],0
DEF0:CE26  C706CBA90000   mov word [A9CB],0
DEF0:CE2C  C706C9A90000   mov word [A9C9],0
DEF0:CE32  E8FF03         call DEF0:D234       ; rebuild display
DEF0:CE35  C3             ret
```

### DEF0:CE36 — Set Cursor Position (wrapper at DEF0:0027)

Takes AX (column), BX (row). Clamps column to 79 (`0x4F`) and
row to 7, stores to `[A9C9]` and `[A9CB]`, calls `DEF0:CFDE`
(display refresh) twice.

```asm
DEF0:CE3C  E89F01         call DEF0:CFDE       ; refresh before
DEF0:CE3F  83F94F         cmp cx,byte +0x4F
DEF0:CE42  7E03           jng CE47
DEF0:CE44  B94F00         mov cx,0x4F          ; clamp to 79
DEF0:CE47  890EC9A9       mov [A9C9],cx        ; store column
DEF0:CE4B  83FA07         cmp dx,byte +0x7
DEF0:CE4E  7E03           jng CE53
DEF0:CE50  BA0700         mov dx,0x7           ; clamp to 7
DEF0:CE53  8916CBA9       mov [A9CB],dx        ; store row
DEF0:CE57  E88401         call DEF0:CFDE       ; refresh after
```

### DEF0:CE6A — Display Update Check (wrapper at DEF0:0019)

Compares AX against `[A9D1]`. If equal, returns immediately
(no update needed). Otherwise falls through to update logic.

```asm
DEF0:CE6A  3B06D1A9       cmp ax,[A9D1]
DEF0:CE6E  7501           jnz CE71
DEF0:CE70  C3             ret                  ; no change
```

### DEF0:CE92 — Display Content Update (wrapper at DEF0:0035)

Takes AX (content parameter). Calls `DEF0:CEAD` (compute display
update), then `DEF0:CFDE` (refresh), `DEF0:CF4B` (state update),
`DEF0:CFDE` (refresh again).

## DEF0:CFDE — Display Refresh (46 callers)

The most-called routine in the DEF0 segment. Builds `FF 06`
(resource reference) display commands from cursor state variables
and renders via `C000:3F35`.

Checks `[A9D1]` — if zero, skips rendering (no active content).
Otherwise builds a display script with the current cursor position
from `[A9C9]` (column) and `[A9CB]` (row):

```asm
DEF0:CFE6  833ED1A900     cmp word [A9D1],byte +0x0
DEF0:CFEB  7503           jnz CFF0
DEF0:CFED  E99100         jmp D081             ; skip if no content
; ...
DEF0:D019  A1CBA9         mov ax,[A9CB]        ; row
DEF0:D01C  D1E0           shl ax,1             ; * 2 for word index
DEF0:D024  A1C9A9         mov ax,[A9C9]        ; column
DEF0:D027  BB0600         mov bx,6
DEF0:D02A  F7E3           mul bx              ; * 6 pixels per column
```

## DEF0:D234 — Display Script Builder (6 callers)

Builds complete display scripts from the cursor state variables.
Called from `DEF0:CE03` (clear) and from display update paths.

## DEF0:CF4B — Display State Update

Updates the display state after content changes. Called from
`DEF0:CE92` and internal update paths.

## DEF0:C5BC — Date/Time Processor

Called from `C000:0498` (boot path). Reads current date (`DEF0:0074`,
INT 21h AH=2Ah) and time (`DEF0:0098`, INT 21h AH=2Ch), converts
to a single value for the world clock display.

Calculates days since base date (`0x63DF`) and time in minutes
(hours * 60 + minutes):

```asm
DEF0:C5CA  B8E318         mov ax,18E3          ; date storage
DEF0:C5CD  E8E9FD         call DEF0:C3B9       ; convert to day count
DEF0:C5D0  2DDF63         sub ax,63DF          ; days since base date
DEF0:C5D3  83DB00         sbb bx,byte +0x0
; ...
DEF0:C5D9  A1EB18         mov ax,[18EB]        ; hours
DEF0:C5DC  BB3C00         mov bx,3C            ; * 60
DEF0:C5DF  F7E3           mul bx
DEF0:C5E1  0306ED18       add ax,[18ED]        ; + minutes
```

## DEF0:C11C — App State Init

Clears `[A00E]`. Called from `DEF0:5C07` (cold init).

```asm
DEF0:C11C  C6060EA000     mov byte [A00E],0
DEF0:C121  C3             ret
```

## DEF0:C122..C2FB — App State Services

Called from the warm reinit path (`DEF0:5CB8`). Application state
management routines.

## Display State Variables

| Address | Purpose |
| --- | --- |
| `[A9C9]` | Cursor column (0..79) |
| `[A9CB]` | Cursor row (0..7) |
| `[A9CD]` | Display attribute |
| `[A9CF]` | Display mode |
| `[A9D1]` | Active content flag (0 = no content) |
| `[A9D3]` | Display page index |
| `[A9D5]` | Display update counter |
| `[A00E]` | Application state byte |

## Entry Points

| Address | Caller | Purpose |
| --- | --- | --- |
| `DEF0:C11C` | `DEF0:5C07` | App state init |
| `DEF0:C122` | `DEF0:5CB8` | App state services |
| `DEF0:C2FB` | `DEF0:5CD8` | State query |
| `DEF0:C394` | `DEF0:5CD8` | State update |
| `DEF0:C455` | internal | State modifier (7 callers) |
| `DEF0:C51F` | `DEF0:5E3B` | State reset |
| `DEF0:C5BC` | `C000:0498` | Date/time processor |
| `DEF0:CD5F` | `C000:0A69` | Boot display state init |
| `DEF0:CE03` | `DEF0:000B` | Display clear |
| `DEF0:CE36` | `DEF0:0027` | Set cursor position |
| `DEF0:CE6A` | `DEF0:0019` | Display update check |
| `DEF0:CE92` | `DEF0:0035` | Content update |
| `DEF0:CFDE` | 46 callers | Display refresh |
| `DEF0:D234` | 6 callers | Display script builder |

## Block Map (209 blocks)

| Address range | Blocks | Purpose |
| --- | --- | --- |
| `DEF0:C11C..C5BC` | ~30 | App state init + services |
| `DEF0:C5BC..CD5F` | ~50 | Date/time + boot display |
| `DEF0:CD5F..CE92` | ~10 | Boot state init + wrapper inners |
| `DEF0:CE92..CFDE` | ~15 | Display state update chain |
| `DEF0:CFDE..D234` | ~10 | Display refresh |
| `DEF0:D234..DA5C` | ~94 | Display script builders |
