# Diagnostic Keyboard Check

The diagnostic mode entry gate. Compares the keyboard matrix at
`[1306..130F]` (populated by the IRQ FB handler at
[`keyboard-irq.md`](keyboard-irq.md) from port `0xB0` reads) against a
ROM pattern at `CS:14FC`. The chord is **F + J + SPACE**, identical to
v2.1.

This is separate from the RTC state checks in
[`rtc-alarm-power.md`](rtc-alarm-power.md). Both are called during boot
but serve different purposes: the RTC check detects coin-battery failure,
while this check enters the diagnostic UI.

## C000:0AA0 — Boot Chord Gate

Called from the warm-resume path (`C000:01F6`) and the normal-resume path
(`C000:0227`). Calls `C000:14D4` to compare the keyboard matrix. If the
chord is held, the user enters the diagnostic UI; when they exit,
`[146F]` is set to `0x1995`.

```asm
; file 0xCAA0
C000:0AA0  E8 310A           call C000:14D4  ; chord compare + diagnostic loop
C000:0AA3  72 01             jc C000:0AA6    ; CF=1: chord held, diagnostic exited
C000:0AA5  C3                ret             ; CF=0: no chord
C000:0AA6  C7 06 6F14 9519   mov word [146F],1995
C000:0AAC  C3                ret
```

## C000:14D4 — Chord Compare and Diagnostic Entry

Compares the keyboard matrix against the ROM chord pattern. If the chord
matches (ZF=1 from `C000:14E6`), renders the diagnostic entry banner and
enters the diagnostic command loop. Loops until the user exits the
diagnostic (CF=1 from `C000:1523`). Returns CF=0 if the chord was never
held, CF=1 if the diagnostic was entered and exited.

```asm
; file 0xC14D4
C000:14D4  E8 0F00           call C000:14E6  ; compare keyboard matrix
C000:14D7  74 02             jz C000:14DB    ; ZF=1: chord matched
C000:14D9  F8                clc
C000:14DA  C3                ret             ; no chord -> CF=0
C000:14DB  E8 2800           call C000:1506  ; render diagnostic entry banner
C000:14DE  E8 4200           call C000:1523  ; diagnostic command loop
C000:14E1  72 02             jc C000:14E5    ; CF=1: user exited
C000:14E3  EB F6             jmp short C000:14DB  ; loop back
C000:14E5  C3                ret             ; CF=1
```

## C000:14E6 — Compare Keyboard Matrix Against ROM Pattern

Uses `REPE CMPSB` to compare 10 bytes at `DS:[1306..130F]` (keyboard
matrix from IRQ FB / port `0xB0`) against `ES:DI` pointing at
`CS:[14FC..1505]` (ROM chord pattern). Returns ZF=1 if all 10 bytes
match, ZF=0 otherwise.

```asm
; file 0xC14E6
C000:14E6  06                push es
C000:14E7  BF 00C0           mov di,C000
C000:14EA  8E C7             mov es,di       ; ES = C000 (code segment)
C000:14EC  BF FC14           mov di,14FC     ; ES:DI = CS:14FC
C000:14EF  BE 0613           mov si,1306     ; DS:SI = [1306] (keyboard matrix)
C000:14F2  B9 0A00           mov cx,A        ; 10 bytes
C000:14F5  FC                cld
C000:14F6  F3 A6             repe cmpsb      ; compare
C000:14F8  07                pop es
C000:14F9  0B C9             or cx,cx        ; CX==0 -> all matched -> ZF=1
C000:14FB  C3                ret
```

## Chord Pattern at CS:14FC

```text
file 0xC14FC:  00 08 00 00 80 00 00 00 40 00
```

| Row | Byte | Bit | Key (from MAME `nakajies.cpp` matrix) |
| ---: | ---: | --- | --- |
| ROW0 | `00` | — | (no keys) |
| ROW1 | `08` | bit 3 | SPACE |
| ROW2 | `00` | — | (no keys) |
| ROW3 | `00` | — | (no keys) |
| ROW4 | `80` | bit 7 | F |
| ROW5 | `00` | — | (no keys) |
| ROW6 | `00` | — | (no keys) |
| ROW7 | `00` | — | (no keys) |
| ROW8 | `40` | bit 6 | J |
| ROW9 | `00` | — | (no keys) |

The chord is **F + J + SPACE** — identical to v2.1.

## C000:1506 — Render Diagnostic Entry Banner

Renders 69 bytes of display script from `C772:005D`.

```asm
; file 0xC1506
C000:1506  9A 0B00 F0DE      call far DEF0:000B  ; display init
C000:150B  BE 5D00           mov si,5D
C000:150E  BA 72C7           mov dx,C772
C000:1511  B9 4500           mov cx,45       ; 69 bytes
C000:1514  E8 4050           call C000:6557  ; render display script
C000:1517  B8 0000           mov ax,0
C000:151A  BB 0200           mov bx,2
C000:151D  9A 2700 F0DE      call far DEF0:0027
C000:1522  C3                ret
```

## C000:1523 — Diagnostic Entry Command Loop

Handles the initial diagnostic prompt. Distinct from the terminal
monitor at [`diagnostic-monitor.md`](diagnostic-monitor.md). Accepts
exit keys (`0x0B`, `0x02`, `0x03`), help (`0x3F`), command keys
(`0x4B`, `0x6B`), and special (`0xDA`).

```asm
; file 0xC1523
C000:1523  80 26 3C14 F7     and byte [143C],F7  ; clear bit 3
C000:1528  E8 8803           call C000:18B3
C000:152B  B8 0100           mov ax,1
C000:152E  9A 1900 F0DE      call far DEF0:0019
C000:1533  E8 33F5           call C000:0A69  ; read key (INT 21h AH=08)
C000:1536  E8 9303           call C000:18CC
C000:1539  3C 01             cmp al,01
C000:153B  74 34             jz C000:1571    ; key 01 -> ?
C000:153D  0A C0             or al,al
C000:153F  74 EA             jz C000:152B    ; no key -> loop
C000:1541  3C 0B             cmp al,0B
C000:1543  74 1D             jz C000:1562    ; EXIT -> return CF=1
C000:1545  3C 02             cmp al,02
C000:1547  74 19             jz C000:1562    ; CANCEL -> return CF=1
C000:1549  3C 03             cmp al,03
C000:154B  74 15             jz C000:1562    ; key 03 -> return CF=1
C000:154D  3C 3F             cmp al,3F       ; '?' help
C000:154F  74 13             jz C000:1564
C000:1551  3C 4B             cmp al,4B       ; 'K' keyboard check
C000:1553  74 14             jz C000:1569
C000:1555  3C 6B             cmp al,6B       ; 'k' keyboard check
C000:1557  74 10             jz C000:1569
C000:1559  3C DA             cmp al,DA       ; special
C000:155B  74 66             jz C000:15C3
C000:155D  E8 C903           call C000:1929  ; other key handling
C000:1560  EB C9             jmp short C000:152B  ; -> loop
C000:1562  F9                stc             ; EXIT
C000:1563  C3                ret
```
