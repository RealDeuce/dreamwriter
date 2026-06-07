# RTC State and Power-Down

The RP5C01 RTC is mapped at ports `0xD0..0xDF`. Port `0xDD` is the RTC
control register; port `0xDF` is the test/reset register. Port `0x70` is
the RTC alarm enable.

These routines detect whether the RTC is in its reset state (coin battery
dead or freshly replaced) and set the `[1439]` flag accordingly. They are
NOT keyboard chord checks — the keyboard chord is at
[`diagnostic-keyboard-check.md`](diagnostic-keyboard-check.md).

## C000:0E13 — Read RTC Registers

Reads 13 RTC registers from ports `0xD0..0xDC` into RAM `[1484..1490]`,
low nibble only. Ports map to RP5C01 registers: `0xD0`=1-second through
`0xDC`=10-year.

```asm
; file 0xCE13
C000:0E13  50                push ax
C000:0E14  53                push bx
C000:0E15  52                push dx
C000:0E16  BA DC00           mov dx,DC       ; start at port DC (10-year)
C000:0E19  BB 9014           mov bx,1490     ; store descending
C000:0E1C  EC                in al,dx
C000:0E1D  24 0F             and al,0F       ; low nibble only
C000:0E1F  88 07             mov [bx],al
C000:0E21  81 FA D000        cmp dx,D0
C000:0E25  74 04             jz C000:0E2B    ; done
C000:0E27  4B                dec bx
C000:0E28  4A                dec dx
C000:0E29  EB F1             jmp short C000:0E1C
C000:0E2B  5A                pop dx
C000:0E2C  5B                pop bx
C000:0E2D  58                pop ax
C000:0E2E  C3                ret
```

Scan buffer layout:

| RAM | Port | RTC register |
| --- | ---: | --- |
| `[1484]` | `0xD0` | 1-second |
| `[1485]` | `0xD1` | 10-second |
| `[1486]` | `0xD2` | 1-minute |
| `[1487]` | `0xD3` | 10-minute |
| `[1488]` | `0xD4` | 1-hour |
| `[1489]` | `0xD5` | 10-hour |
| `[148A]` | `0xD6` | day-of-week |
| `[148B]` | `0xD7` | 1-day |
| `[148C]` | `0xD8` | 10-day |
| `[148D]` | `0xD9` | 1-month |
| `[148E]` | `0xDA` | 10-month |
| `[148F]` | `0xDB` | 1-year |
| `[1490]` | `0xDC` | 10-year |

## C000:0E43 — Check RTC State (11 Registers)

Reads RTC, forces `[148A]` (day-of-week) to match by copying `[1432]`
into it, then compares 11 bytes from `[142C..1436]` against scan buffer
`[1490..1486]` (descending). After RAM init (`C000:03BB` clears to zero,
`C000:0CA7` sets `[142C..142D]` and `[1435..1436]` to `0xFFFF`), the
expected pattern is `FF FF 00 00 00 00 00 00 00 FF FF`.

`0xFF` positions can never match a scan value (max `0x0F`) and act as
"ignore" sentinels. Returns CF=1 when month, day, and hour registers all
read zero — indicating the RTC is uninitialized.

```asm
; file 0xCE43
C000:0E43  E8 CDFF           call C000:0E13  ; read RTC -> [1484..1490]
C000:0E46  A0 3214           mov al,[1432]
C000:0E49  A2 8A14           mov [148A],al   ; force day-of-week to match
C000:0E4C  BF 9014           mov di,1490
C000:0E4F  BE 2C14           mov si,142C
C000:0E52  B9 0B00           mov cx,B
C000:0E55  FC                cld
C000:0E56  AC                lodsb
C000:0E57  3A 05             cmp al,[di]
C000:0E59  75 05             jnz C000:0E60   ; mismatch -> CF=0
C000:0E5B  4F                dec di
C000:0E5C  E2 F8             loop C000:0E56
C000:0E5E  F9                stc             ; all matched -> CF=1 (RTC reset)
C000:0E5F  C3                ret
C000:0E60  F8                clc             ; mismatch -> CF=0 (RTC normal)
C000:0E61  C3                ret
```

## C000:0E2F — Check RTC State (7 Registers)

Secondary check: 7 bytes from `[1430..1436]` against `[148C..1486]`.
Shares the compare loop at `C000:0E55`.

```asm
; file 0xCE2F
C000:0E2F  E8 E1FF           call C000:0E13
C000:0E32  A0 3214           mov al,[1432]
C000:0E35  A2 8A14           mov [148A],al
C000:0E38  BF 8C14           mov di,148C
C000:0E3B  BE 3014           mov si,1430
C000:0E3E  B9 0700           mov cx,7
C000:0E41  EB 12             jmp short C000:0E55
```

## C000:0E62 — Check RTC Seconds Clear

Returns CF=1 if `[1484]` (1-second) and `[1485]` (10-second) are both
zero. Used by `C000:0953` to detect when the RTC has stabilized after
an abnormal state.

```asm
; file 0xCE62
C000:0E62  E8 AEFF           call C000:0E13
C000:0E65  32 C0             xor al,al
C000:0E67  3A 06 8414        cmp al,[1484]
C000:0E6B  75 F3             jnz C000:0E60   ; nonzero -> CF=0
C000:0E6D  3A 06 8514        cmp al,[1485]
C000:0E71  75 ED             jnz C000:0E60   ; nonzero -> CF=0
C000:0E73  F9                stc             ; both zero -> CF=1
C000:0E74  C3                ret
```

## C000:0CA7 — Init RTC Check Sentinels

Sets `[142C..142D]=0xFFFF` and `[1435..1436]=0xFFFF` as "ignore"
positions in the RTC comparison pattern. Called from the subsystem init
chain via `C000:2F44`.

Falls through to `C000:0CB3`.

```asm
; file 0xCCA7
C000:0CA7  C7 06 2C14 FFFF   mov word [142C],FFFF
C000:0CAD  C7 06 3514 FFFF   mov word [1435],FFFF
```

## C000:0CB3 — Write Saved Time Back to RTC

Writes `[1430..1436]` to RTC ports `0xD2..0xD8` (1-minute through
10-day), skipping port `0xD6` (day-of-week). Sets RTC mode register
`0xDD` to `0xF9` before writing and `0xF8` after.

```asm
; file 0xCCB3
C000:0CB3  50                push ax
C000:0CB4  53                push bx
C000:0CB5  52                push dx
C000:0CB6  B0 F9             mov al,F9
C000:0CB8  E6 DD             out DD,al       ; RTC mode = F9
C000:0CBA  B0 FD             mov al,FD
C000:0CBC  E6 DF             out DF,al       ; RTC test/reset
C000:0CBE  BA D800           mov dx,D8       ; start at port D8 (10-day)
C000:0CC1  BB 3014           mov bx,1430
C000:0CC4  8A 07             mov al,[bx]
C000:0CC6  24 0F             and al,0F
C000:0CC8  81 FA D600        cmp dx,D6       ; skip day-of-week
C000:0CCC  74 01             jz C000:0CCF
C000:0CCE  EE                out dx,al       ; write to RTC port
C000:0CCF  81 FA D200        cmp dx,D2       ; done at port D2?
C000:0CD3  74 04             jz C000:0CD9
C000:0CD5  43                inc bx
C000:0CD6  4A                dec dx
C000:0CD7  EB EB             jmp short C000:0CC4
C000:0CD9  B0 F8             mov al,F8
C000:0CDB  E6 DD             out DD,al       ; RTC mode = F8
C000:0CDD  5A                pop dx
C000:0CDE  5B                pop bx
C000:0CDF  58                pop ax
C000:0CE0  C3                ret
```

## C000:0CE1 — Advance RTC Minute

Reads `[1486]` (1-minute) and `[1487]` (10-minute) from the scan buffer,
increments, handles BCD rollover (9→0 with carry, 5→0), writes the new
value to RTC ports `0xD2` and `0xD3`.

```asm
; file 0xCCE1
C000:0CE1  B0 F9             mov al,F9
C000:0CE3  E6 DD             out DD,al
C000:0CE5  B0 FD             mov al,FD
C000:0CE7  E6 DF             out DF,al
C000:0CE9  A0 8614           mov al,[1486]   ; 1-minute digit
C000:0CEC  8A 26 8714        mov ah,[1487]   ; 10-minute digit
C000:0CF0  FE C0             inc al
C000:0CF2  3C 0A             cmp al,A        ; 1-minute rollover?
C000:0CF4  75 0B             jnz C000:0D01
C000:0CF6  B0 00             mov al,0
C000:0CF8  FE C4             inc ah
C000:0CFA  80 FC 06          cmp ah,6        ; 10-minute rollover?
C000:0CFD  75 02             jnz C000:0D01
C000:0CFF  B4 00             mov ah,0
C000:0D01  E6 D2             out D2,al       ; write 1-minute
C000:0D03  8A C4             mov al,ah
C000:0D05  E6 D3             out D3,al       ; write 10-minute
C000:0D07  B0 F8             mov al,F8
C000:0D09  E6 DD             out DD,al
C000:0D0B  C3                ret
```

## C000:048C — Power Down

Saves state via `C000:05A3`, checks RTC state via `C000:0498`, enables
RTC alarm, then halts.

```asm
; file 0xC48C
C000:048C  E8 1401           call C000:05A3  ; save state
C000:048F  E8 0600           call C000:0498  ; RTC state check
C000:0492  B0 01             mov al,01
C000:0494  E6 70             out 70,al       ; RTC alarm enable
C000:0496  EB FE             jmp short C000:0496 ; HALT (infinite loop)
```

## C000:0498 — Power-Down RTC State Check

Checks the RTC via `C000:0E43` (11-register) and `C000:0E2F` (7-register).
If the RTC is normal (both CF=0), writes saved time back to the RTC via
`C000:0CB3` and clears `[1439]`. If either check indicates the RTC is in
reset state, advances the minute via `C000:0CE1` and sets `[1439]=1`.

```asm
; file 0xC498
C000:0498  E4 DD             in al,DD
C000:049A  24 F7             and al,F7       ; clear bit 3
C000:049C  E6 DD             out DD,al
C000:049E  06                push es
C000:049F  9A BCC5 F0DE      call far DEF0:C5BC
C000:04A4  07                pop es
C000:04A5  E8 9B09           call C000:0E43  ; check 11 RTC registers
C000:04A8  72 03             jc C000:04AD    ; abnormal -> skip secondary
C000:04AA  E8 8209           call C000:0E2F  ; check 7 RTC registers
C000:04AD  9C                pushf           ; save CF
C000:04AE  E4 DD             in al,DD
C000:04B0  0C 08             or al,08        ; set bit 3
C000:04B2  E6 DD             out DD,al
C000:04B4  9D                popf            ; restore CF
C000:04B5  72 0F             jc C000:04C6    ; either check abnormal ->
C000:04B7  E8 F907           call C000:0CB3  ; RTC normal: write saved time back
C000:04BA  C6 06 3914 00     mov byte [1439],0  ; clear RTC abnormal flag
C000:04BF  E4 DD             in al,DD
C000:04C1  0C 04             or al,04        ; set bit 2
C000:04C3  E6 DD             out DD,al
C000:04C5  C3                ret
C000:04C6  E8 1808           call C000:0CE1  ; RTC abnormal: advance minute
C000:04C9  C6 06 3914 01     mov byte [1439],1  ; set RTC abnormal flag
C000:04CE  EB EF             jmp short C000:04BF
```
