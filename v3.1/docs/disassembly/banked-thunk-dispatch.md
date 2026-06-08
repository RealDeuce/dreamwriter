# Banked Thunk Dispatch

The banked call mechanism used by the firmware to dispatch service
requests through two jump tables. The entry points at `C000:0021`
(thunk A) and `C000:0025` (thunk B) are in the C000 jump table and
are called via far-call from the application layer.

See [`installed-vectors.md`](installed-vectors.md) for how the IVT
entries at `C000:0021` and `C000:0025` are set up.

## C000:19CB — Thunk A Entry

Called from `C000:0021`. Saves registers, calls `C000:19F0` (the
dispatcher), restores registers, returns.

```asm
; file 0xC19CB
C000:19CB  50                push ax
C000:19CC  51                push cx
C000:19CD  52                push dx
C000:19CE  56                push si
C000:19CF  FF 36 0D71        push word [710D]
C000:19D3  FF 36 0F71        push word [710F]
C000:19D7  E8 1600           call C000:19F0    ; dispatch
C000:19DA  8F 06 0F71        pop word [710F]
C000:19DE  8F 06 0D71        pop word [710D]
C000:19E2  5E                pop si
C000:19E3  5A                pop dx
C000:19E4  59                pop cx
C000:19E5  58                pop ax
C000:19E6  C3                ret
```

### C000:19F0 — Thunk A Dispatcher

Indexes the dispatch table at `C000:1A00` by `AH` (swapped to AL,
doubled) and jumps to the handler.

```asm
; file 0xC19F0
C000:19F0  86 C4             xchg ah,al      ; AL = service ID
C000:19F2  B4 00             mov ah,0
C000:19F4  03 C0             add ax,ax        ; index * 2
C000:19F6  BF 001A           mov di,1A00      ; table base
C000:19F9  03 F8             add di,ax
C000:19FB  2E 8B 05          mov ax,[cs:di]   ; load handler address
C000:19FE  FF E0             jmp ax           ; dispatch
```

### Thunk A Dispatch Table (C000:1A00, 12 entries)

| Slot | Handler | Purpose |
| ---: | --- | --- |
| 0 | `C000:1AA2` | Multi-function dispatch on AX: renders display scripts (`C000:6557`), calls `C000:2295` (state save), `C000:1DEA` (service), `C000:211E`, `C000:2144`. |
| 1 | `C000:1A9D` | Load DI from `[710F]` (state pointer). |
| 2 | `C000:1A18` | Key event dispatch: tests `[7195]`, calls `C000:316D` (serial I/O) and `C000:0A69` (key translate). |
| 3 | `C000:1A95` | Fixed beep: calls `C000:0B12` (via `C000:1D85`). |
| 4 | `C000:1A55` | DreamLink service: calls `C772:CF7C` (far) and `C000:0A69`. Falls through to error halt if DL invalid. |
| 5 | `C000:1A18` | Same as slot 2. |
| 6 | `C000:1AA2` | Same as slot 0 (used by spell check via `C772:970F`). |
| 7 | `C000:1A18` | Same as slot 2. |
| 8 | `C000:19E7` | Software error halt entry (via `C000:1DCF`: dispatches on DreamLink endpoint `[6F51]`). |
| 9 | `C000:19E7` | Same as slot 8. |
| 10 | `C000:19E7` | Same as slot 8. |
| 11 | `C000:1A9D` | Same as slot 1. |

## C000:1B28 — Thunk B Entry

Called from `C000:0025`. Same register save/restore pattern as thunk A,
but dispatches through a different table at `C000:1B38`.

```asm
; file 0xC1B28
C000:1B28  86 C4             xchg ah,al
C000:1B2A  B4 00             mov ah,0
C000:1B2C  03 C0             add ax,ax
C000:1B2E  BF 381B           mov di,1B38
C000:1B31  03 F8             add di,ax
C000:1B33  2E 8B 05          mov ax,[cs:di]
C000:1B36  FF E0             jmp ax
```

### Thunk B Dispatch Table (C000:1B38, 12 entries)

| Slot | Handler | Purpose |
| ---: | --- | --- |
| 0 | `C000:1B4C` | |
| 1 | `C000:1D8C` | |
| 2 | `C000:1B4C` | Same as slot 0. |
| 3 | `C000:1D85` | Fixed beep (`C000:0B12`). See [`sound-lowlevel.md`](sound-lowlevel.md). |
| 4 | `C000:1B4F` | |
| 5 | `C000:1B4F` | Same as slot 4. |
| 6 | `C000:14DB` | Diagnostic chord entry loop. See [`diagnostic-keyboard-check.md`](diagnostic-keyboard-check.md). |
| 7 | `C000:131D` | Diagnostic command monitor. See [`diagnostic-monitor.md`](diagnostic-monitor.md). |
| 8 | `C000:1DCF` | |
| 9 | `C000:19E7` | Software error halt. |
| 10 | `C000:98E9` | Editor utility. Reached from `C000:929B..9D63` block. |
| 11 | `C000:BBFE` | |

## C000:19E7 — Software Error Halt Entry

Reached from thunk A slots 8-10 and thunk B slot 9. Sets `[1467]` to
`0x19E7` (self-reference as error marker), then jumps to the software
error halt at `C000:1420`.

```asm
; file 0xC19E7
C000:19E7  C7 06 6714 E719   mov word [1467],19E7
C000:19ED  E9 30FA           jmp C000:1420    ; software error halt
```

## C000:98E9 — Editor Utility Entry (Thunk B Slot 10)

Entry point into the `C000:929B..9D63` editor utility block (115
blocks, self-contained). This block contains text buffer management,
cursor movement, and formatting helpers used by the WP editor. All
internal — no external callers other than through this thunk slot.

The routines reference state variables in the `[73xx]` and `[74xx]`
ranges (C772 application state RAM) and the `[75xx]` range (editor
workspace).

## Usage

The thunk mechanism is invoked from the application layer via:

```asm
    MOV AH, service_id    ; 0..11
    CALL FAR [0200+n*4]   ; or directly via C000:0021/0025
```

The thunk entry pushes the service ID through `XCHG AH,AL`, doubles it,
indexes the table, and jumps to the handler. Handlers return via `RET`
to the thunk entry's register restore code.
