# C000 Thunk A Services

The thunk A service handlers at `C000:1A00..22FF` (67 blocks).
Reached from the thunk A dispatch table at `C000:1A00` (12 entries)
via the thunk A entry at `C000:19CB`. These provide core display
rendering, keyboard, serial, and DreamLink services to the C772
application runtime.

See [`banked-thunk-dispatch.md`](banked-thunk-dispatch.md) for the
thunk A dispatch mechanism.

## Thunk A Dispatch Table (C000:1A00, 12 entries)

| Slot | Handler | Callers | Purpose |
| ---: | --- | --- | --- |
| 0, 6 | `C000:1AA2` | Spell check (`C772:970F` AH=6), display services | Multi-function service dispatch |
| 1, 11 | `C000:1A9D` | State queries | Load DI from `[710F]` (state pointer) |
| 2, 5, 7 | `C000:1A18` | Key input | Key event dispatch: tests `[7195]`, calls serial I/O and key translation |
| 3 | `C000:1A95` | Sound | Returns AL from `[7195]` (via `C000:1D85` fixed beep) |
| 4 | `C000:1A55` | DreamLink | DreamLink service: calls `C772:CF7C`, key translate |
| 8, 9, 10 | `C000:19E7` | Error | Software error halt (via `C000:1DCF` endpoint dispatch) |

## C000:1AA2 — Multi-Function Service (Slot 0/6)

The main thunk A handler. Dispatches on AX to select the operation:

```asm
C000:1AA2  3D0200         cmp ax,2
C000:1AA5  7C2F           jl 1AD6       ; AX < 2: state save
C000:1AA7  7411           jz 1ABA       ; AX == 2: (unused?)
C000:1AA9  3D0500         cmp ax,5
C000:1AAC  7438           jz 1AE6       ; AX == 5: display script render
C000:1AAE  3D0300         cmp ax,3
C000:1AB1  742A           jz 1ADA       ; AX == 3: text output service
C000:1AB3  3D0400         cmp ax,4
C000:1AB6  7417           jz 1ACF       ; AX == 4: state save + display
; other: falls through
```

| AX | Handler | Behavior |
| ---: | --- | --- |
| < 2 | `C000:1AD6` | State save: calls `C000:2295`. |
| 3 | `C000:1ADA` | Text output service: calls `C000:1DEA`. |
| 4 | `C000:1ACF` | State save + display init: calls `C000:2295`, `C000:0FB0`. |
| 5 | `C000:1AE6` | Display script render: calls `C000:6557` x2 with parameters from SI/DX/CX. |

## C000:1DEA — Text Output Service

Called from slot 0 (AX=3). The text output engine for the display.
Loops reading characters, calls `C000:1E60` (character setup) and
`C000:20D3` (character classification). Large routine spanning
`C000:1DEA..2069` (24 blocks).

Character processing pipeline:
1. `C000:1E60` — Set up character from source
2. `C000:1EC0` — Character attribute lookup
3. `C000:1EE0` / `C000:1EFD` — Character width/positioning
4. `C000:2036` — Pixel-level character blit
5. `C000:21A3` — Advance cursor position
6. `C000:21C3` — Line wrap/scroll check
7. `C000:21DC` — Multi-byte character handler

## C000:1A18 — Key Event Dispatch (Slot 2/5/7)

Tests `[7195]` for the key source mode. If nonzero, calls
`C000:316D` (serial I/O input). Always calls `C000:0A69`
(key code translation). Dispatches on the translated key code
for special handling (error halt via `C000:19E7` if invalid).

## C000:1A55 — DreamLink Service (Slot 4)

Tests `[7195]` and DL value. If valid, calls `C772:CF7C` (far call
into C772 DreamLink handler) and `C000:0A69` (key translate).
Falls through to `C000:19E7` (error halt) if DL is invalid.

## C000:1DCF — Endpoint Dispatch (Slot 8)

Dispatches on `[6F51]` (DreamLink endpoint):
- `0x0A` → `C000:0D42` (DreamLink endpoint check)
- `0x0B` → `C000:0D53`
- other → `C000:0D61`

## C000:2295 — State Save

Saves display state: reads `[7195]`, stores configuration to
`[143C]` flag byte. Called from slot 0 before display operations.

## C772 Blocks Reached via Thunk A

The thunk A services call into C772 for application-level
operations:

| Address | Called from | Purpose |
| --- | --- | --- |
| `C772:CF7C` | `C000:1A55` (slot 4) | DreamLink protocol handler |
| `C772:CE6C` | `C772:CF86` | DreamLink sub-handler: calls `C772:8976`, `970F`, `C50D`, `CB7x` |
