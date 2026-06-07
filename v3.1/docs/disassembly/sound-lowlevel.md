# Low-Level Sound Helpers

Sound output uses three ports: `0x50` (frequency low byte), `0x51`
(frequency high byte), and `0x52` (enable `0x7F` / disable `0xFF`).
Lower BX values produce higher-pitched tones (BX is a timer divider).

## C000:0B62 — Tone On

Writes BX as the frequency divider and enables the sound output.

```asm
; file 0xCB62
C000:0B62  8A C3             mov al,bl
C000:0B64  E6 50             out 50,al       ; frequency low byte
C000:0B66  8A C7             mov al,bh
C000:0B68  E6 51             out 51,al       ; frequency high byte
C000:0B6A  B0 7F             mov al,7F
C000:0B6C  E6 52             out 52,al       ; enable sound
C000:0B6E  C3                ret
```

## C000:0B6F — Tone Off

```asm
; file 0xCB6F
C000:0B6F  B0 FF             mov al,FF
C000:0B71  E6 52             out 52,al       ; disable sound
C000:0B73  C3                ret
```

## C000:0B30 — Tone With Duration

Plays a tone at frequency BX for a duration controlled by CX, then
silences. If BX==0, silences immediately (no tone). Calls `C000:0D42`
during the delay to poll for early exit (returns CF=1 if interrupted).

```asm
; file 0xCB30
C000:0B30  50                push ax
C000:0B31  53                push bx
C000:0B32  51                push cx
C000:0B33  0B DB             or bx,bx
C000:0B35  74 05             jz C000:0B3C    ; BX==0 -> silence
C000:0B37  E8 2800           call C000:0B62  ; tone on at frequency BX
C000:0B3A  EB 03             jmp short C000:0B3F
C000:0B3C  E8 3000           call C000:0B6F  ; tone off
C000:0B3F  0B C9             or cx,cx
C000:0B41  74 1B             jz C000:0B5E    ; CX==0 -> skip delay
C000:0B43  8B D9             mov bx,cx       ; BX = outer loop count
C000:0B45  B9 6400           mov cx,64       ; CX = 100 inner iterations
C000:0B48  51                push cx
C000:0B49  B9 1E00           mov cx,1E       ; inner-inner delay
C000:0B4C  E2 FE             loop C000:0B4C  ; spin 30 cycles
C000:0B4E  59                pop cx
C000:0B4F  E8 F001           call C000:0D42  ; poll for interrupt/key
C000:0B52  F9                stc
C000:0B53  75 06             jnz C000:0B5B   ; interrupted -> early exit
C000:0B55  E2 F1             loop C000:0B48  ; inner loop
C000:0B57  4B                dec bx
C000:0B58  75 EB             jnz C000:0B45   ; outer loop
C000:0B5A  F8                clc             ; completed normally
C000:0B5B  E8 1100           call C000:0B6F  ; tone off
C000:0B5E  59                pop cx
C000:0B5F  5B                pop bx
C000:0B60  58                pop ax
C000:0B61  C3                ret
```

## C000:0B12 — Fixed Startup Beep

Plays a fixed-frequency beep at divider `0x0200`, delays `0x8000` cycles,
silences, then delays `0x5000` cycles. Called via banked thunk slot 3
(`C000:1D85`).

```asm
; file 0xCB12
C000:0B12  B9 0002           mov cx,200
C000:0B15  8A C1             mov al,cl      ; AL = 0x00
C000:0B17  E6 50             out 50,al      ; freq low = 0x00
C000:0B19  8A C5             mov al,ch      ; AL = 0x02
C000:0B1B  E6 51             out 51,al      ; freq high = 0x02
C000:0B1D  B0 7F             mov al,7F
C000:0B1F  E6 52             out 52,al      ; enable sound
C000:0B21  B9 0080           mov cx,8000
C000:0B24  E2 FE             loop C000:0B24  ; delay
C000:0B26  B0 FF             mov al,FF
C000:0B28  E6 52             out 52,al      ; disable sound
C000:0B2A  B9 0050           mov cx,5000
C000:0B2D  E2 FE             loop C000:0B2D  ; silence delay
C000:0B2F  C3                ret
```

## C000:0DC5 — Multi-Note Sequence Driver

Plays a sequence of (duration, frequency) pairs from a table indexed by
AL (0..4). Each entry is 3 bytes: 1-byte CX value, 2-byte BX value.
Terminated by CX==0. Calls `C000:0B30` for each note.

Table pointers at `CS:0D89`:

| Slot | Pointer | Notes | Called from |
| ---: | --- | --- | --- |
| 0 | `C000:0D93` | tone(`0x698`,8) silence(2) tone(`0x100`,4) | `C000:0992` (normal resume, via `[1334]`) |
| 1 | `C000:0D9D` | tone(`0x2BA`,4) | |
| 2 | `C000:0DA1` | 5 descending tones (`0x126`→`0xC4`) | |
| 3 | `C000:0DB1` | silence(2) | |
| 4 | `C000:0DB5` | 5 ascending tones (`0xC4`→`0x126`) | `C000:09CE` (NMI recovery) |

```asm
; file 0xCDC5
C000:0DC5  3C 05             cmp al,5
C000:0DC7  73 21             jnc C000:0DEA   ; slot >= 5 -> return
C000:0DC9  8A D8             mov bl,al
C000:0DCB  32 FF             xor bh,bh
C000:0DCD  D1 E3             shl bx,1
C000:0DCF  2E 8B B7 890D     mov si,[cs:bx+0D89]  ; SI = table pointer
C000:0DD4  2E 8A 0C          mov cl,[cs:si]  ; CL = duration
C000:0DD7  0A C9             or cl,cl
C000:0DD9  74 0F             jz C000:0DEA    ; zero -> done
C000:0DDB  32 ED             xor ch,ch       ; CX = duration byte
C000:0DDD  46                inc si
C000:0DDE  2E 8B 1C          mov bx,[cs:si]  ; BX = frequency
C000:0DE1  46                inc si
C000:0DE2  46                inc si
C000:0DE3  E8 4AFD           call C000:0B30  ; play tone(BX, CX)
C000:0DE6  72 02             jc C000:0DEA    ; interrupted -> stop
C000:0DE8  EB EA             jmp short C000:0DD4 ; next entry
C000:0DEA  C3                ret
```

## C000:0A49 — CPU Delay Loop

Pure delay, no sound. Nested loop: outer CX=`0x80`, inner SI=`0x4B0`.

```asm
; file 0xCA49
C000:0A49  B9 8000           mov cx,80
C000:0A4C  BE B004           mov si,4B0
C000:0A4F  4E                dec si
C000:0A50  75 FD             jnz C000:0A4F
C000:0A52  E2 F8             loop C000:0A4C
C000:0A54  C3                ret
```

## Boot Startup Tone Callers

These routines are called directly from the boot path. Each calls
`C000:0B30` to produce startup tones.

### C000:09EA — Cold-Start Tones

Two tones: low (`0x698`) then higher (`0x126`), each for duration 12.

```asm
; file 0xC9EA
C000:09EA  BB 9806           mov bx,698     ; low tone
C000:09ED  B9 0C00           mov cx,C       ; duration 12
C000:09F0  E8 3D01           call C000:0B30
C000:09F3  BB 2601           mov bx,126     ; higher tone
C000:09F6  B9 0C00           mov cx,C       ; duration 12
C000:09F9  E8 3401           call C000:0B30
C000:09FC  C3                ret
```

### C000:09B2 — Warm-Resume Tones

Three tones: low-mid-low (`0x698`-`0x574`-`0x698`), each for duration 25.

```asm
; file 0xC9B2
C000:09B2  BB 9806           mov bx,698     ; low tone
C000:09B5  B9 1900           mov cx,19      ; duration 25
C000:09B8  E8 7501           call C000:0B30
C000:09BB  BB 7405           mov bx,574     ; mid tone
C000:09BE  B9 1900           mov cx,19
C000:09C1  E8 6C01           call C000:0B30
C000:09C4  BB 9806           mov bx,698     ; low tone
C000:09C7  B9 1900           mov cx,19
C000:09CA  E8 6301           call C000:0B30
C000:09CD  C3                ret
```

### C000:09CE — NMI Recovery Tone

Plays slot 4 (five ascending tones). Only called when `[1473]==0x4D0`.

```asm
; file 0xC9CE
C000:09CE  B0 04             mov al,4
C000:09D0  E8 F203           call C000:0DC5
C000:09D3  C3                ret
```

### C000:09D4 — Cold-Reinit Banner + Tone

Renders the "INITIALIZING" display script from `C772:EDB0`, then plays a
single mid-pitch tone (`0x574`) for duration 100.

```asm
; file 0xC9D4
C000:09D4  BE B0ED           mov si,EDB0
C000:09D7  B9 1800           mov cx,18
C000:09DA  BA 72C7           mov dx,C772
C000:09DD  E8 775B           call C000:6557  ; render display script
C000:09E0  BB 7405           mov bx,574     ; mid tone
C000:09E3  B9 6400           mov cx,64      ; duration 100
C000:09E6  E8 4701           call C000:0B30
C000:09E9  C3                ret
```

## Boot Tone Summary

| Boot path | Caller | Tones |
| --- | --- | --- |
| Cold start (sig mismatch) | `C000:09EA` | low(`698`) + high(`126`) |
| Cold reinit (validation fail) | `C000:09D4` | long mid(`574`) with "INITIALIZING" banner |
| Warm resume (retry flag set) | `C000:09B2` | low(`698`) + mid(`574`) + low(`698`) |
| Normal resume ([146F]==0) | `C000:0DC5` slot 0 | high(`15D`) + silence + high(`100`) |
| NMI recovery ([1473]==4D0) | `C000:0DC5` slot 4 | 5 ascending (`C4`→`DC`→`E9`→`106`→`126`) |
| Fixed beep (thunk slot 3) | `C000:0B12` | single beep at `200` |
