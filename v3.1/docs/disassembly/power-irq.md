# Power IRQ (IRQ FF)

The warm/power management interrupt. Installed at IVT vector `FFh`
(`[03FC]`) pointing to `C000:001E` which jumps to `C000:03FC`.

Called by the power button (NMI triggers IRQ FF on `drwrt400`).
This handler decides whether to enter diagnostic mode, save context
and halt, or just IRET.

See [`boot.md`](boot.md) for the full startup flow,
[`diagnostic-keyboard-check.md`](diagnostic-keyboard-check.md) for the
chord compare at `C000:14E6`, and
[`rtc-alarm-power.md`](rtc-alarm-power.md) for the power-down path at
`C000:048C`.

## C000:03FC — IRQ FF Handler

```asm
; file 0xC03FC
C000:03FC  50                push ax
C000:03FD  53                push bx
C000:03FE  1E                push ds
C000:03FF  B8 0000           mov ax,0
C000:0402  8E D8             mov ds,ax
C000:0404  B0 01             mov al,01
C000:0406  E6 90             out 90,al       ; LCD control
C000:0408  A1 0911           mov ax,[1109]   ; startup state
C000:040B  3D 9519           cmp ax,1995     ; battery warning?
C000:040E  74 56             jz C000:0466    ; -> save_and_halt
C000:0410  3D 9919           cmp ax,1999     ; software error?
C000:0413  74 36             jz C000:044B    ; -> save_state_and_halt
C000:0415  83 3E 0D11 00     cmp word [110D],0
C000:041A  75 24             jnz C000:0440   ; [110D]!=0 -> diagnostic_mode
C000:041C  80 3E D816 01     cmp byte [16D8],1  ; framebuffer-swap active?
C000:0421  75 0D             jnz C000:0430
C000:0423  50                push ax
C000:0424  51                push cx
C000:0425  56                push si
C000:0426  57                push di
C000:0427  E8 4A05           call C000:0974  ; restore framebuffer [9000]->[8000]
C000:042A  5F                pop di
C000:042B  5E                pop si
C000:042C  59                pop cx
C000:042D  58                pop ax
```

Falls through to chord check at C000:0430.

## C000:0430 — Chord Check During Power IRQ

If `[1109]!=1` (not early startup), checks the keyboard chord
(F+J+SPACE) via `C000:14E6`. If the chord matches, enters diagnostic
mode by setting `[1109]=0x1992`.

```asm
; file 0xC0430
C000:0430  83 F8 01          cmp ax,1        ; early startup?
C000:0433  74 16             jz C000:044B    ; yes -> skip chord check
C000:0435  56                push si
C000:0436  57                push di
C000:0437  51                push cx
C000:0438  E8 AB10           call C000:14E6  ; compare keyboard matrix (F+J+SPACE)
C000:043B  59                pop cx
C000:043C  5F                pop di
C000:043D  5E                pop si
C000:043E  74 0B             jz C000:044B    ; chord matched -> save_state_and_halt
```

Falls through to diagnostic mode at C000:0440 if chord NOT matched
and `[110D]!=0`.

## C000:0440 — Enter Diagnostic Mode

Sets `[1109]=0x1992` (diagnostic state), then returns via IRET. On the
next boot cycle, the common init tail at `C000:0107` will see this
state and enter the diagnostic path.

```asm
; file 0xC0440
C000:0440  C7 06 0911 9219   mov word [1109],1992
C000:0446  1F                pop ds
C000:0447  5B                pop bx
C000:0448  58                pop ax
C000:0449  FB                sti
C000:044A  CF                iret
```

## C000:044B — Save State and Halt

Reached when the chord IS matched, or during battery/error states.
Clears `[1107]`, saves `[1467]=0x320D` and CS to `[1469]`, then falls
through to `C000:0466`.

```asm
; file 0xC044B
C000:044B  C6 06 0711 00     mov byte [1107],0
C000:0450  C7 06 6714 0D32   mov word [1467],320D
C000:0456  8C C8             mov ax,cs
C000:0458  A3 6914           mov [1469],ax
C000:045B  C7 06 6F14 9519   mov word [146F],1995 ; set battery warning flag
C000:0461  80 26 3C14 F7     and byte [143C],F7   ; clear bit 3
C000:0466  8B EC             mov bp,sp            ; -> context_save_and_halt
```

## C000:0466 — Save Context From Stack and Halt

Reached during battery warning state (`[1109]==0x1995`). Walks the
IRET frame on the stack to save the interrupted IP and CS.

```asm
; file 0xC0466
C000:0466  8B EC             mov bp,sp
C000:0468  83 C5 06          add bp,6        ; skip pushed AX/BX/DS
C000:046B  8B 46 00          mov ax,[bp+0]   ; interrupted IP
C000:046E  A3 7314           mov [1473],ax
C000:0471  83 C5 02          add bp,2
C000:0474  8B 46 00          mov ax,[bp+0]   ; interrupted CS
C000:0477  A3 7514           mov [1475],ax
C000:047A  E8 8209           call C000:0DFF  ; LCD/display cleanup
C000:047D  EB 13             jmp short C000:0492 ; -> halt_loop
```

## C000:047F — Context Save and Halt

Shared entry point reached from `C000:044B` and from `C000:318B`
(deep in the subsystem init chain). Checksums the context block,
optionally updates the RAM checksum, saves state, checks RTC, then
halts.

```asm
; file 0xC047F
C000:047F  E8 DC00           call C000:055E  ; context checksum
C000:0482  80 3E E26F 00     cmp byte [6FE2],0
C000:0487  74 03             jz C000:048C    ; skip RAM checksum if [6FE2]==0
C000:0489  E8 E500           call C000:0571  ; RAM checksum update
C000:048C  E8 1401           call C000:05A3  ; save additional state
C000:048F  E8 0600           call C000:0498  ; RTC state check + set [1439]
```

Falls through to `C000:0492` (halt loop). See
[`rtc-alarm-power.md`](rtc-alarm-power.md) for `C000:0492` and
`C000:0498`.

## Flow Summary

```text
IRQ FF (C000:03FC):
  [1109]==0x1995 (battery) -> save IP/CS from stack, halt
  [1109]==0x1999 (error)   -> save state, halt
  [110D]!=0                -> set [1109]=0x1992 (diagnostic), IRET
  [16D8]==1                -> restore framebuffer first
  [1109]!=1 (not early):
    C000:14E6 chord check (F+J+SPACE)
      matched   -> save [1467]=320D, context save, halt
      no match  -> set [1109]=0x1992 (diagnostic), IRET
  [1109]==1 (early)        -> save state, halt
```
