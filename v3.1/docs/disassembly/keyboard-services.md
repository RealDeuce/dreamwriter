# Keyboard Processor

The high-level keyboard processing chain called from the IRQ FB handler
after all 10 keyboard rows have been scanned. See
[`keyboard-irq.md`](keyboard-irq.md) for the IRQ handler that populates
the matrix at `[1306..130F]` and calls this processor.

## C000:3AE3 — Keyboard Processor Entry

Called from the IRQ FB handler at `C000:0662` after a complete 10-row
scan with at least one key detected. Compares the new scan at
`[1306..130F]` against the previous scan saved at `[1310..1323]` to
detect key transitions (press/release).

```asm
; file 0xC3AE3
C000:3AE3  BB 0613           mov bx,1306     ; new scan
C000:3AE6  BE 1013           mov si,1310     ; previous scan
C000:3AE9  8A 07             mov al,[bx]     ; current row
C000:3AEB  3A 04             cmp al,[si]     ; compare with previous
C000:3AED  75 3F             jnz C000:3B2E   ; row changed -> process
C000:3AEF  46                inc si
C000:3AF0  3A 04             cmp al,[si]     ; compare with debounce copy
C000:3AF2  74 03             jz C000:3AF7    ; matches -> next row
C000:3AF4  E9 9800           jmp C000:3B8F   ; debounce mismatch -> process
```

Row-scan loop continues:

```asm
C000:3AF7  43                inc bx
C000:3AF8  46                inc si
C000:3AF9  81 FE 2413        cmp si,1324     ; end of matrix?
C000:3AFD  75 EA             jnz C000:3AE9   ; no -> next row
C000:3AFF  F6 06 9D15 01     test byte [159D],1
C000:3B04  74 07             jz C000:3B0D    ; no pending flag -> continue
C000:3B06  80 26 9D15 FE     and byte [159D],FE ; clear flag
C000:3B0B  F9                stc
C000:3B0C  C3                ret             ; return CF=1
```

If no rows changed and no debounce mismatches, falls through to
`C000:3B0D` which checks `[15A1]` and calls `C000:3CEB` (the key
repeat handler).

### Key Change Processing (C000:3B2E)

When a row changed, the processor:
1. Identifies which bit(s) changed (XOR old with new)
2. Looks up the key code from the keyboard translation table at
   `[1126]` (populated by `C000:3ED4` during init)
3. Applies modifiers (shift, control, alt) from `[1310]` row 0
4. Queues the translated key code for consumption

The keyboard translation tables were copied from ROM during init
by `C000:3EBB` (80 bytes to `[1643]`) and `C000:3ED4` (480 bytes
to `[1126]` with a 6-entry pointer table at `[1114]`).

### State Variables

| Address | Purpose |
| --- | --- |
| `[1306..130F]` | Current keyboard row scan (10 rows from port 0xB0) |
| `[1310..1319]` | Previous scan (for change detection) |
| `[131A..1323]` | Debounce copy |
| `[1324]` | Key repeat enabled flag |
| `[1325..1327]` | Key repeat state |
| `[132C]` | Scan state / empty-scan counter |
| `[132D]` | Row counter (0..9) |
| `[132E]` | Key repeat initial delay |
| `[132F..1332]` | Key repeat parameters |
| `[1114..111F]` | 6-entry pointer table into `[1126]` |
| `[1126..1305]` | Keyboard translation table (480 bytes) |
| `[1643..1692]` | Key code mapping table (80 bytes) |
| `[159D]` | Bit 0: pending key event flag |
| `[15A1]` | Key repeat active flag |
