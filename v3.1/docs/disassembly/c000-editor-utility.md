# C000 Editor/Spell Utility

The editor utility block at `C000:929B..9D63` (115 blocks,
self-contained). Reached via banked thunk B slot 10 (`C000:98E9`).
Contains text buffer management, cursor movement, and formatting
helpers used by the WP editor.

See [`banked-thunk-dispatch.md`](banked-thunk-dispatch.md) for the
thunk B dispatch table.

## C000:98E9 — Thunk B Slot 10 Entry

Dispatches editor operations. Saves BP, checks flags, then calls
`C000:9431` for the main editor operation loop.

## C000:9431 — Editor Operation Dispatcher

Calls `C000:929C` (state check), then processes text buffer
operations using `[741F]` (buffer length) and DX (offset).
Adjusts SI/DX to ensure valid buffer positions.

```asm
C000:9431  E868FE         call C000:929C       ; check state
C000:9434  7519           jnz 944F             ; not active -> skip
C000:9436  8B361F74       mov si,[741F]        ; buffer length
C000:943A  83C602         add si,byte +2
C000:943D  2BF2           sub si,dx            ; remaining
C000:943F  7802           js 9443              ; underflow
C000:9441  750B           jnz 944E             ; not at boundary
```

## C000:929C — Editor State Check

Checks `[73F7]` bit 0 (editor active) and `[7239]` bit 0
(spell check mode). Returns with ZF set if editor is inactive.

```asm
C000:929C  A0F773         mov al,[73F7]
C000:929F  A801           test al,1
C000:92A1  74F8           jz 929B              ; inactive -> ret
C000:92A3  A03972         mov al,[7239]
C000:92A6  A801           test al,1            ; spell check?
C000:92A8  C3             ret
```

## Key Internal Routines

| Address | Callers | Purpose |
| --- | --- | --- |
| `C000:929C` | `9431` | State check: editor active + spell mode |
| `C000:92FC` | `9333` | Buffer scan/search |
| `C000:9333` | `9C58`, `94AF` | Text block operation (calls BA35, 93C3, 92FC) |
| `C000:93AA` | `94AF` | Block format operation |
| `C000:93C3` | `9C58`, `9333` | Buffer fill/clear loop |
| `C000:93E9` | `9758` | Character insertion (calls 929C) |
| `C000:9431` | `98E9` | Main dispatcher |
| `C000:9461` | `99DE` | Position-based operation |
| `C000:94AF` | `9461` | Block operation with 9333 + 93AA |
| `C000:9530` | `7115` | Multi-service: 8415 + 7785 + 946F |
| `C000:9961` | `971C` | Flag check + E0E5 |
| `C000:99DE` | `997E` | Complex operation: 1F61 + 9461 + DC56 |
| `C000:9C58` | `9B1C` | Buffer reformat: 9333 + 93C3 |

## Editor State Variables

| Address | Purpose |
| --- | --- |
| `[73F7]` | Editor active flag (bit 0) |
| `[7239]` | Spell check mode (bit 0) |
| `[741F]` | Current buffer length |
| `[7415]` | Buffer cursor position |
| `[7423]` | Alternate cursor position |
| `[7430]` | Edit mode flag |
| `[7472]` | Buffer boundary low |
| `[7474]` | Buffer boundary high |
| `[7480]` | Operation flags |
| `[7491]` | Saved position |
| `[74BB]` | Last character code |
| `[74FD]` | Format position |
| `[7501]` | Operation counter |
| `[7504]` | Format output pointer |
| `[750E]` | Format flags |

## Support Routines (Outside Main Block)

| Address | Called from | Purpose |
| --- | --- | --- |
| `C000:B064` | `794D` | Extended text operation |
| `C000:B1A9` | `9523` | Buffer scan loop |
| `C000:BA35` | `9333` | Block copy helper |
| `C000:BBFE` | thunk slot 11 | Display + extended operation |
| `C000:DB96` | `91DB` | Character classification table |
| `C000:DC56` | `99DE` | Character property lookup |
| `C000:E0E5` | `9961` | Extended flag check |
