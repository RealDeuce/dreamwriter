# Keyboard Row Scan IRQ

IRQ FB handler. Reads keyboard rows from port `0xB0` into the matrix at
`[1306..130F]`, one row per interrupt. After all 10 rows are scanned,
calls the higher-level keyboard processor at `C000:3AE3`.

The keyboard matrix at `[1306..130F]` is what
[`diagnostic-keyboard-check.md`](diagnostic-keyboard-check.md) compares
against the F+J+SPACE chord pattern.

## C000:05F7 — IRQ FB Handler

```asm
; file 0xC05F7
C000:05F7  50                push ax
C000:05F8  53                push bx
C000:05F9  1E                push ds
C000:05FA  B8 0000           mov ax,0
C000:05FD  8E D8             mov ds,ax
C000:05FF  B0 10             mov al,10
C000:0601  E6 90             out 90,al       ; LCD control
C000:0603  8A 1E 2D13        mov bl,[132D]   ; row counter
C000:0607  32 FF             xor bh,bh
C000:0609  E4 B0             in al,B0        ; read keyboard row
C000:060B  0A C0             or al,al
C000:060D  74 05             jz C000:0614    ; no keys in this row
C000:060F  80 0E 2C13 80     or byte [132C],80  ; flag: key detected
C000:0614  88 87 0613        mov [bx+1306],al   ; store row in matrix
C000:0618  FE 06 2D13        inc byte [132D]    ; next row
C000:061C  80 3E 2D13 0A     cmp byte [132D],A  ; all 10 rows?
C000:0621  75 CF             jnz C000:05F2      ; no -> clear IRQ and return
C000:0623  F6 06 2C13 80     test byte [132C],80
C000:0628  75 20             jnz C000:064A      ; key detected -> process
C000:062A  FE 06 2C13        inc byte [132C]    ; no-key scan counter
C000:062E  80 3E 2C13 0A     cmp byte [132C],A  ; 10 empty scans?
C000:0633  75 1A             jnz C000:064F      ; no -> reset counter, return
C000:0635  B0 FE             mov al,FE
C000:0637  E6 61             out 61,al          ; keyboard scan edge: FE
C000:0639  80 26 3A14 FB     and byte [143A],FB  ; clear bit 2 in IRQ mask
C000:063E  80 0E 3A14 08     or byte [143A],08   ; set bit 3
C000:0643  A0 3A14           mov al,[143A]
C000:0646  E6 60             out 60,al          ; update IRQ mask
C000:0648  EB A8             jmp short C000:05F2  ; -> clear IRQ, return
C000:064A  C6 06 2C13 00     mov byte [132C],0  ; reset no-key counter
C000:064F  C6 06 2D13 00     mov byte [132D],0  ; reset row counter
C000:0654  06                push es
C000:0655  51                push cx
C000:0656  52                push dx
C000:0657  56                push si
C000:0658  57                push di
C000:0659  55                push bp
C000:065A  A0 3A14           mov al,[143A]
C000:065D  0C 01             or al,01
C000:065F  E6 60             out 60,al          ; mask IRQ during processing
C000:0661  FB                sti
C000:0662  E8 7E34           call C000:3AE3     ; keyboard processor
C000:0665  FA                cli
C000:0666  A0 3A14           mov al,[143A]
C000:0669  E6 60             out 60,al          ; restore IRQ mask
C000:066B  5D                pop bp
C000:066C  5F                pop di
C000:066D  5E                pop si
C000:066E  5A                pop dx
C000:066F  59                pop cx
C000:0670  07                pop es
C000:0671  1F                pop ds
C000:0672  5B                pop bx
C000:0673  58                pop ax
C000:0674  CF                iret
```

Note: `C000:05F2` (the IRQ-clear return path) is the target at `C000:0621`
and `C000:0648`. It is above the handler entry point:

```asm
; file 0xC05F2 (shared IRQ clear/return)
C000:05F2  A0 3A14           mov al,[143A]
C000:05F5  E6 60             out 60,al       ; restore IRQ mask
                                              ; falls into the pop/iret at 0671
```

## State Variables

| Address | Purpose |
| --- | --- |
| `[1306..130F]` | Keyboard matrix: 10 rows from port `0xB0` reads |
| `[132C]` | Bit 7: key-detected flag. Low bits: consecutive empty-scan counter |
| `[132D]` | Current row counter (0..9) |
