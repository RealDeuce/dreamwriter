# Application Entry Points

The C772 segment entry points reached from the boot path. Cold start
enters at `C772:0004`, warm resume at `C772:0008`. Both eventually
reach the menu scripting interpreter at `C772:3944` via `C772:022D`.

See [`boot.md`](boot.md) for the full boot flow and
[`menu-interpreter.md`](menu-interpreter.md) for the bytecode engine.

## C772:0004 — Cold Start Entry

Called from `C000:01DA` (`JMP FAR C772:0004`) after cold init or cold
reinit. Calls `C772:2A6A` which clears application state RAM, runs the
cold-start init chain, then enters the interpreter.

```asm
; file 0xC7724
C772:0004  E8 632A           call C772:2A6A
C772:0007  CB                retf
```

### C772:2A6A — Cold Init Chain

Clears `[72DA..7A4B]` (application state area, ~1900 bytes), then calls
three init routines and yields to the interpreter.

```asm
; file 0xC9E8A
C772:2A6A  BF DA72           mov di,72DA     ; start of app state
C772:2A6D  B9 4B7A           mov cx,7A4B
C772:2A70  81 E9 DA72        sub cx,72DA     ; CX = 0x771 = 1905 bytes
C772:2A74  32 C0             xor al,al
C772:2A76  06                push es
C772:2A77  8C DD             mov bp,ds
C772:2A79  8E C5             mov es,bp
C772:2A7B  FC                cld
C772:2A7C  F3 AA             rep stosb        ; clear [72DA..7A4A]
C772:2A7E  07                pop es
C772:2A7F  2E8B36F42A        mov si,[cs:2AF4] ; load init pointer
C772:2A84  89369371          mov [7193],si    ; store to [7193]
C772:2A88  C606957100        mov byte [7195],0
```

The bytes after `CALL 022D` at `C772:2A8B` are the initial bytecode
program — the first thing the interpreter executes on cold start.

## C772:0008 — Warm Start Entry

Called from `C000:021B` (`JMP FAR C772:0008`) after warm resume. Calls
`C772:84DE` which checks the warm-start state and either re-enters
the app directly or falls back to a display reinit.

```asm
; file 0xC7728
C772:0008  E8 D384           call C772:84DE
C772:000B  CB                retf
```

### C772:84DE — Warm Start Handler

```asm
; file 0xCFBFE
C772:84DE  E8 6400           call C772:8545   ; check warm state
C772:84E1  3C 02             cmp al,2
C772:84E3  74 03             jz C772:84E8     ; state==2 -> reinit display
C772:84E5  E9 1963           jmp C772:E801    ; else -> app-specific resume
```

If warm state is 2, reinits the DEF0 subsystem via `DEF0:5C2E`:

```asm
C772:84E8  06                push es
C772:84E9  9A 2E5C F0DE      call far DEF0:5C2E  ; warm subsystem reinit
C772:84EE  07                pop es
C772:84EF  E9 0F63           jmp C772:E801    ; -> app-specific resume
...
```

## C772:002E — Reset Storage Endpoint

Small utility called from `C772:7327` (a menu handler). Resets the
storage endpoint byte to 8 (built-in storage).

```asm
; file 0xC774E
C772:002E  C6 06 0611 08     mov byte [1106],8
C772:0033  F8                clc
C772:0034  C3                ret
```

## C772:0035 — Cycle Storage Endpoint

Increments `[1106]` through valid endpoint values (8..B, skipping to
C, wrapping back to 8).

```asm
; file 0xC7755
C772:0035  A0 0611           mov al,[1106]
C772:0038  FE C0             inc al
C772:003A  3C 0B             cmp al,B
C772:003C  75 02             jnz C772:0040
C772:003E  B0 0C             mov al,C        ; skip B -> C
C772:0040  3C 0C             cmp al,C
C772:0042  72 15             jc C772:0059     ; valid -> store
C772:0044  B0 08             mov al,8        ; wrap to 8
C772:0046  EB 11             jmp short C772:0059
```

## Application State RAM

| Address range | Size | Purpose |
| --- | --- | --- |
| `[72DA..7A4A]` | 1905 | Application state (cleared on cold start) |
| `[73F7..7461]` | 107 | Copied by opcode 0x38 handler (state save) |
| `[7487]` | 2 | State save destination pointer |
| `[1106]` | 1 | Current storage endpoint (8=built-in, 9=PCMCIA, C=?) |
| `[1112]` | 2 | Set to `0x723A` during init |
