# C772 Native Helpers

The C772 segment native code (994 blocks) called by the menu
interpreter opcode handlers and by DEF0 service callbacks. The
segment splits into the bytecode VM (documented in
[`menu-interpreter.md`](menu-interpreter.md)) and native x86
routines that the VM opcodes call.

See [`app-entry.md`](app-entry.md) for the cold/warm entry points.

## Segment Layout

| Address range | Blocks | Purpose |
| --- | --- | --- |
| `C772:0004..022D` | 14 | Entry points + far-call wrappers |
| `C772:0300..0BEF` | 20 | VM outlier handlers + helpers |
| `C772:0D20..2FFF` | 234 | Display update + text processing |
| `C772:3600..39FF` | 86 | VM core (interpreter + dispatch + handlers) |
| `C772:3A00..45FF` | 74 | Text buffer operations + state |
| `C772:4600..5FFF` | 130 | Document editing + format dispatch |
| `C772:6000..7FFF` | 212 | Page layout + cursor management |
| `C772:8000..8FFF` | 88 | Application service dispatcher |
| `C772:9000..9FFF` | 71 | Print / file / preview services |
| `C772:A000..BFFF` | 45 | Formatting helpers |
| `C772:D000..DFFF` | 4 | Printer support |
| `C772:E800..EFFF` | 32 | DEF0 callbacks |

## Key Routines

### C772:45A7 — State Snapshot (32 callers)

Copies 107 bytes (`0x6B`) from `[73F7]` to `[0000:DI]` using
`[7487]` as the destination base. Called before any operation that
may modify application state. REP MOVSB with CLD.

```asm
C772:45A7  8B3E8774       mov di,[7487]       ; destination base
C772:45AB  BEF773         mov si,73F7         ; source: app state block
C772:45AE  B96B00         mov cx,6B           ; 107 bytes
C772:45B1  06             push es
C772:45B2  BD0000         mov bp,0
C772:45B5  8EC5           mov es,bp           ; ES = 0 (low RAM)
C772:45B7  FC             cld
C772:45B8  F3A4           rep movsb           ; copy
C772:45BA  07             pop es
C772:45BB  8BD7           mov dx,di           ; DX = end pointer
```

### C772:8415 — Application Service Dispatcher (31 callers)

The main service entry point, called from `C772:8411` (which is
called from `C000:58B8` via far-call). Dispatches application
requests through:

1. `C772:5202` — check if service is available (`[7577]`)
2. `C772:8526` — refresh application state
3. `C772:98EC` — state comparison check
4. `C772:2DBD` — flag-based dispatch (`[74B2]` bit 0 → `C772:41AC`)
5. `C772:45A7` — state snapshot
6. `C772:8526` — final state refresh

### C772:8526 — State Refresh (11 callers)

Calls `C772:8534` twice (with AL=5 and AL=0) then `C772:9A8C`
(invalidate state cache). `8534` in turn calls `C772:4556`
(state restore) and `C772:0D20` (display updater).

### C772:3C2D — Text Buffer Write-Forward (30 callers)

Writes AL to the text buffer at `[740D]+DL`, increments the
position counter at `[7411]`. Bounds-checked against `0x7C` (124).

```asm
C772:3C2D  BE1174         mov si,7411         ; position counter
C772:3C30  8A14           mov dl,[si]
C772:3C32  FE04           inc byte [si]       ; advance position
C772:3C34  80FA7C         cmp dl,7C           ; bounds check
C772:3C37  730A           jnc 3C43            ; overflow → return
C772:3C39  8B1E0D74       mov bx,[740D]       ; buffer base
C772:3C3D  02DA           add bl,dl           ; + offset
C772:3C3F  268807         mov [es:bx],al      ; write character
```

### C772:3BB6 — Text Buffer Read-Forward (18 callers)

Reads a character from the text buffer at `[740F]+AL`, increments
position at `[7413]`. Reverse of `3C2D`.

### C772:3BFA — Text Buffer Write-Backward (17 callers)

Writes AL to text buffer, decrements position. Reverse of `3C2D`.

### C772:3BD8 — Text Buffer Read-Backward (15 callers)

Reads from text buffer, decrements position. Reverse of `3BB6`.

### C772:5E35 — Far-Call Setup (18 callers)

Sets up state for far-call operations: saves `[710F]`, sets
`[710F]=74E5`, clears `[7478]`, reads `[745F]`. Used as the entry
point for document editing operations.

### C772:4556 — State Restore (11 callers)

Restores 107 bytes from `[0000:SI]` to `[73F7]` — the reverse
of `C772:45A7`. Then calculates buffer sizes from `[73FF]-[73FD]`
and `[7403]-[7401]`, stores to `[74C4]` and `[74C6]`.

### C772:970F / 9715 — Thunk Wrappers (13 / 9 callers)

Far-call wrappers: `C000:19C3` calls `C000:19CB` (thunk A entry)
then RETF. `C000:19C7` calls `C000:1B28` (thunk B entry) then RETF.

### C772:9A8C — Invalidate State Cache

Sets `[7094]` and `[7095]` to `0xFF` — marks the cached state as
invalid so the next `C772:98EC` check will force a refresh.

### C772:0D20 — Display Updater

Called from `C772:8534`. Checks `[73F7]` — if zero, skips update.
Otherwise calls `C772:0D7E` (compute display), `C772:0DAB`
(render), then loops through `[7457]` and `[745A]` state entries,
calling `C772:78FE` and `C772:795D` for page layout updates.

## Far-Call Wrappers (0004-022D)

| Address | Caller | Purpose |
| --- | --- | --- |
| `C772:01CD` | `DEF0:2CDD` | File dialog: init (calls 45A7, 8526, 92AA) |
| `C772:01F3` | `DEF0:2CDD` | File dialog: finalize (calls 941D, 9715) |
| `C772:0212` | `DEF0:2D9C` | File dialog: indirect call via `[CA04]` |
| `C772:0221` | `DEF0:2ADA` | File dialog: clear flag `[7A44] &= 0x7F` |

## DEF0 Callbacks (E800-EFFF, 32 blocks)

Twelve callbacks called from [`def0-menu-display.md`](def0-menu-display.md)
menu system. All follow the same pattern:

```asm
push cx/dx/si/di/bp
mov bp,0xCEF          ; ES = application data segment
mov es,bp
call C772:inner       ; application-specific handler
pop bp/di/si/dx/cx
mov al,[746C]         ; result byte
mov ah,0
retf
```

| Callback | Inner call | Called from |
| --- | --- | --- |
| `C772:E801` | `C772:853B`, `DEF0:2761` | `C772:84DE` |
| `C772:E81A` | `C772:7115` | `DEF0:26B4` |
| `C772:E832` | `C772:E963` | `DEF0:279D` |
| `C772:E84A` | `C772:AE4B` | `DEF0:25B7` |
| `C772:E87D` | inner | `DEF0:2739` |
| `C772:E895` | inner | `DEF0:26F8` |
| `C772:E8AD` | inner | `DEF0:270E` |
| `C772:E8C5` | inner | `DEF0:26E2` |
| `C772:E8DD` | inner | `DEF0:264C` |
| `C772:E8F5` | inner | `DEF0:2662` |
| `C772:E910` | inner | `DEF0:2612` |
| `C772:E92B` | inner | `DEF0:2636` |
| `C772:E946` | inner | `DEF0:2678` |

## Application State Block

The 107-byte state block at `[73F7..7461]` is the core application
state. Snapshot/restore operations copy this block to/from low RAM.

| Offset | Address | Purpose |
| --- | --- | --- |
| `+0x00` | `[73F7]` | Active flag (0 = inactive) |
| `+0x06` | `[73FD]` | Buffer A start |
| `+0x08` | `[73FF]` | Buffer A end |
| `+0x0A` | `[7401]` | Buffer B start |
| `+0x0C` | `[7403]` | Buffer B end |
| `+0x16` | `[740D]` | Read buffer base |
| `+0x18` | `[740F]` | Write buffer base |
| `+0x1A` | `[7411]` | Write cursor position |
| `+0x1C` | `[7413]` | Read cursor position |
| `+0x60` | `[7457]` | Display state A |
| `+0x63` | `[745A]` | Display state B |
| `+0x66` | `[745D]` | Display mode pointer |
| `+0x68` | `[745F]` | Display parameter |

## Related State Variables

| Address | Purpose |
| --- | --- |
| `[7040]` | Menu active flag |
| `[7094]` | State cache A (0xFF = invalid) |
| `[7095]` | State cache B (0xFF = invalid) |
| `[710D]` | Display pointer (saved/restored by thunk) |
| `[710F]` | State pointer (saved/restored by thunk) |
| `[7478]` | Operation flag |
| `[7487]` | State snapshot destination base |
| `[746C]` | Callback result byte |
| `[74B2]` | Service dispatch flags |
| `[74BD]` | Current mode |
| `[74BE]` | Operation state |
| `[74C4]` | Buffer A size |
| `[74C6]` | Buffer B size |
| `[7576]` | Page count |
| `[7577]` | Service available flag |
| `[7A44]` | File dialog state flags |

## Text Buffer Model

The C772 text editor uses a split-buffer (gap buffer) model:

- Read buffer at `[740F]` with cursor at `[7413]`, max position `0x7C` (124)
- Write buffer at `[740D]` with cursor at `[7411]`, max position `0x7C` (124)
- Buffer content addressed via ES segment (set to `0xCEF` by callbacks)
- Four operations: read-forward (`3BB6`), read-backward (`3BD8`),
  write-forward (`3C2D`), write-backward (`3BFA`)
