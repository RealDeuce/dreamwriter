# Boot Disassembly

Depth-first trace from reset through cold/warm startup to the application
entry point. Every call target was disassembled and labeled from its actual
instructions, not inferred from v2.1.

See [`../map.md`](../map.md) for the address model and banking layout.

## Reset Vector

; file 0xFFFF0

```asm
FFFF:0000  FA                cli
FFFF:0001  EA 0000 E3F6      jmp far F6E3:0000
```

## Reset Trampoline

; file 0xF6E30

```asm
F6E3:0000  FA                cli
F6E3:0001  B0 01             mov al,01
F6E3:0003  E6 16             out 16,al       ; window 6 -> ROM bank 14 (file C0000)
F6E3:0005  B0 00             mov al,00
F6E3:0007  E6 17             out 17,al       ; window 7 -> ROM bank 15 (file E0000)
F6E3:0009  EA 0000 00C0      jmp far C000:0000
```

## C000:0000 — Entry and Jump Table

; file 0xC0000

```asm
C000:0000  EB 27             jmp short C000:0029
C000:0002  00 00             ;
C000:0004  00 00             ;
C000:0006  E9 6E62           jmp C000:6277      ; INT 21h dispatch
C000:0009  E9 C404           jmp C000:04D0      ; IRQ F8 / NMI
C000:000C  E9 B105           jmp C000:05C0      ; IRQ F9
C000:000F  E9 C205           jmp C000:05D4      ; IRQ FA
C000:0012  E9 E205           jmp C000:05F7      ; IRQ FB — keyboard row scan
C000:0015  E9 5E06           jmp C000:0676      ; IRQ FC
C000:0018  E9 2F08           jmp C000:084A      ; IRQ FD
C000:001B  E9 4008           jmp C000:085E      ; IRQ FE
C000:001E  E9 DB03           jmp C000:03FC      ; IRQ FF — warm/power
C000:0021  E8 A719           call C000:19CB      ; banked thunk entry A
C000:0024  CB                retf
C000:0025  E8 001B           call C000:1B28      ; banked thunk entry B
C000:0028  CB                retf
```

## C000:0029 — Hardware Init

; file 0xC0029

Sets bank ports, zeroes segment registers, writes hardware I/O ports,
sets temporary stack, then calls IVT installer.

```asm
C000:0029  FA                cli
C000:002A  B0 17             mov al,17
C000:002C  E6 10             out 10,al       ; window 0 -> RAM
C000:002E  B0 01             mov al,01
C000:0030  E6 16             out 16,al       ; window 6 -> ROM bank 14
C000:0032  B0 00             mov al,00
C000:0034  E6 17             out 17,al       ; window 7 -> ROM bank 15
C000:0036  B8 0000           mov ax,0
C000:0039  8E D0             mov ss,ax
C000:003B  8E D8             mov ds,ax       ; DS = 0 for the rest of boot
C000:003D  8E C0             mov es,ax
C000:003F  B0 FF             mov al,FF
C000:0041  E6 90             out 90,al       ; port 90 — LCD control
C000:0043  A2 3A14           mov [143A],al   ; shadow
C000:0046  B0 00             mov al,00
C000:0048  E6 20             out 20,al       ; port 20
C000:004A  B0 40             mov al,40
C000:004C  E6 00             out 00,al       ; port 00 — LCD base
C000:004E  B0 F0             mov al,F0
C000:0050  E6 DE             out DE,al       ; port DE — RTC mode
C000:0052  B0 F8             mov al,F8
C000:0054  E6 DD             out DD,al       ; port DD — RTC control
C000:0056  B0 5F             mov al,5F
C000:0058  A2 8214           mov [1482],al   ; port 30 shadow
C000:005B  B0 FF             mov al,FF
C000:005D  E6 40             out 40,al       ; port 40 — serial control
C000:005F  BC 006F           mov sp,6F00     ; temporary stack
C000:0062  E8 FC10           call C000:1161  ; IVT installer (verified)
```

## C000:0065 — Warm-RAM Signature Check

; file 0xC0065

Compares 4 bytes at RAM `[1000..1003]` against ROM signature at `CS:7799`.
The signature is `32 31 38 20` = ASCII `"218 "`.

```asm
C000:0065  BE 9977           mov si,7799
C000:0068  BF 0010           mov di,1000
C000:006B  B9 0400           mov cx,4
C000:006E  2E 8A04           mov al,[cs:si]
C000:0071  3A 05             cmp al,[di]
C000:0073  75 10             jnz C000:0085   ; mismatch -> cold_stamp
C000:0075  46                inc si
C000:0076  47                inc di
C000:0077  E2 F5             loop C000:006E
```

All 4 matched — check a 5th byte:

```asm
C000:0079  BE CF64           mov si,64CF
C000:007C  2E 8A04           mov al,[cs:si]
C000:007F  3A 05             cmp al,[di]     ; RAM [1004]
C000:0081  75 0B             jnz C000:008E   ; mismatch -> cold_stamp_partial
C000:0083  EB 67             jmp short C000:00EC ; all matched -> warm_path
```

### C000:0085 — cold_stamp

Writes remaining signature bytes from ROM to RAM, stamps secondary byte,
then enters cold-start init:

```asm
C000:0085  2E 8A04           mov al,[cs:si]
C000:0088  88 05             mov [di],al
C000:008A  46                inc si
C000:008B  47                inc di
C000:008C  E2 F7             loop C000:0085
C000:008E  BE CF64           mov si,64CF
C000:0091  2E 8A04           mov al,[cs:si]
C000:0094  88 05             mov [di],al
```

Falls through to C000:0096.

## C000:0096 — Cold-Start Init

; file 0xC0096

Reached on first boot or when the warm-RAM signature doesn't match.
Seeds bank mirrors, restores bank ports, initializes subsystems, then
sets warm-retry flag and jumps to common_init_tail.

```asm
C000:0096  E8 5109           call C000:09EA  ; three timed delays
C000:0099  E8 8B02           call C000:0327  ; seed bank mirrors [147B..147F]
C000:009C  A1 7B14           mov ax,[147B]   ; restore port 11 (AH) and 12 (AL)
C000:009F  86 C4             xchg ah,al
C000:00A1  E6 11             out 11,al
C000:00A3  8A C4             mov al,ah
C000:00A5  E6 12             out 12,al
C000:00A7  A1 7D14           mov ax,[147D]   ; restore port 13 (AH) and 14 (AL)
C000:00AA  86 C4             xchg ah,al
C000:00AC  E6 13             out 13,al
C000:00AE  8A C4             mov al,ah
C000:00B0  E6 14             out 14,al
C000:00B2  A0 7F14           mov al,[147F]   ; restore port 15
C000:00B5  E6 15             out 15,al
C000:00B7  E8 0103           call C000:03BB  ; clear RAM [1006..CEEE], fill [0400..0FFE] with 0x73
C000:00BA  E8 6664           call C000:6523  ; init drive/file state words
C000:00BD  E8 6702           call C000:0327  ; seed bank mirrors again
C000:00C0  C6 06 0510 48     mov byte [1005],48
C000:00C5  B3 A5             mov bl,A5       ; BL=A5
C000:00C7  B2 08             mov dl,08       ; DL=08 (built-in storage endpoint)
C000:00C9  B4 FF             mov ah,FF
C000:00CB  E8 C842           call C000:4396  ; storage endpoint dispatch (BL=A5, DL=08)
C000:00CE  E8 A004           call C000:0571  ; checksum 1800:0008..FFFF, store at 1800:0006
C000:00D1  E8 9E2D           call C000:2E72  ; subsystem init chain
C000:00D4  9A 075C F0DE      call far DEF0:5C07
C000:00D9  E8 C902           call C000:03A5  ; clear 0x400 bytes at [AAFB..]
C000:00DC  E8 2155           call C000:5600  ; fill [6F5E..6F61] with FF (clear file handles)
C000:00DF  80 0E 3C14 01     or byte [143C],01  ; set warm-retry flag (bit 0)
C000:00E4  C7 06 6F14 9519   mov word [146F],1995
C000:00EA  EB 1B             jmp short C000:0107
```

### C000:00EC — warm_path

Reached when all 5 signature bytes match. Restores bank ports from saved
mirrors without reinitializing subsystems:

```asm
C000:00EC  A1 7B14           mov ax,[147B]
C000:00EF  86 C4             xchg ah,al
C000:00F1  E6 11             out 11,al
C000:00F3  8A C4             mov al,ah
C000:00F5  E6 12             out 12,al
C000:00F7  A1 7D14           mov ax,[147D]
C000:00FA  86 C4             xchg ah,al
C000:00FC  E6 13             out 13,al
C000:00FE  8A C4             mov al,ah
C000:0100  E6 14             out 14,al
C000:0102  A0 7F14           mov al,[147F]
C000:0105  E6 15             out 15,al
```

Falls through to C000:0107.

## C000:0107 — Common Init Tail

; file 0xC0107

Clears volatile state bytes, sets `[1109]=1` (startup state), then enters
the warm/cold decision tree.

```asm
C000:0107  33 C0             xor ax,ax
C000:0109  A2 D516           mov [16D5],al
C000:010C  A2 3E14           mov [143E],al
C000:010F  A2 3F14           mov [143F],al
C000:0112  A2 4014           mov [1440],al
C000:0115  A2 E26F           mov [6FE2],al
C000:0118  A3 9314           mov [1493],ax
C000:011B  A2 D816           mov [16D8],al
C000:011E  40                inc ax
C000:011F  A3 0911           mov [1109],ax   ; [1109] = 1
C000:0122  C6 06 0510 48     mov byte [1005],48
C000:0127  81 3E 7314 D004   cmp word [1473],4D0  ; previous NMI?
C000:012D  75 03             jnz C000:0132
C000:012F  E8 9C08           call C000:09CE  ; display helper (AL=4 -> C000:0DC5)
```

`C000:09CE` runs only if `[1473]==0x04D0`, meaning the previous session
was terminated by the NMI handler (which stores `0x04D0` there).

```asm
C000:0132  E8 F82C           call C000:2E2D  ; validate stored state
```

`C000:2E2D` checks `[1337]==0x7CE`, validates `[1106]` against `8/9/A/B`,
calls four subroutines, returns CF=1 if validation fails.

```asm
C000:0135  72 53             jc C000:018A    ; validation failed -> cold_reinit
C000:0137  F6 06 3C14 01     test byte [143C],01  ; warm-retry flag?
C000:013C  9C                pushf
C000:013D  80 26 3C14 FE     and byte [143C],FE   ; clear it
C000:0142  9D                popf
C000:0143  74 03             jz C000:0148    ; flag was clear -> resume_check
C000:0145  E9 9700           jmp C000:01DF   ; flag was set -> warm_resume
```

## C000:0148 — Resume Check

; file 0xC0148

Tests `[1467]` (saved application state word) against known values.

```asm
C000:0148  A1 6714           mov ax,[1467]
C000:014B  0B C0             or ax,ax
C000:014D  74 1D             jz C000:016C    ; zero -> segment_validate
C000:014F  3D 0D32           cmp ax,320D
C000:0152  74 18             jz C000:016C
C000:0154  3D E730           cmp ax,30E7
C000:0157  74 13             jz C000:016C
C000:0159  3D 6D31           cmp ax,316D
C000:015C  74 0E             jz C000:016C
C000:015E  81 3E 7314 D004   cmp word [1473],4D0
C000:0164  E9 F700           jmp C000:025E   ; unrecognized state -> nmi_resume
```

Known state values `0x0000, 0x320D, 0x30E7, 0x316D` proceed to
segment validation. Any other value goes to the NMI resume path at
C000:025E.

### C000:016C — Segment Validate

```asm
C000:016C  8B D8             mov bx,ax       ; BX = [1467]
C000:016E  8C C8             mov ax,cs
C000:0170  3B 06 6914        cmp ax,[1469]   ; saved CS == current CS?
C000:0174  75 14             jnz C000:018A   ; mismatch -> cold_reinit
C000:0176  0B DB             or bx,bx
C000:0178  75 06             jnz C000:0180
C000:017A  C7 06 6F14 9519   mov word [146F],1995
C000:0180  A1 6F14           mov ax,[146F]
C000:0183  0B C0             or ax,ax
C000:0185  75 58             jnz C000:01DF   ; nonzero -> warm_resume
C000:0187  E9 9600           jmp C000:0220   ; zero -> normal_resume
```

Three outcomes from the decision tree:
- `[1469] != CS` → cold_reinit (saved context from a different ROM)
- `[146F] != 0` → warm_resume
- `[146F] == 0` → normal_resume (C000:0220)

## C000:018A — Cold Reinit

; file 0xC018A

Full reinitialization when stored state validation fails.

```asm
C000:018A  E8 4708           call C000:09D4  ; render "INITIALIZING" banner (C772:EDB0), delay
C000:018D  C7 06 6F14 0000   mov word [146F],0
C000:0193  B0 FF             mov al,FF
C000:0195  E6 60             out 60,al       ; port 60 — interrupt mask
C000:0197  A2 3A14           mov [143A],al
C000:019A  E8 8A01           call C000:0327  ; seed bank mirrors
C000:019D  E8 1B02           call C000:03BB  ; clear RAM
C000:01A0  B0 FF             mov al,FF
C000:01A2  A2 3A14           mov [143A],al
C000:01A5  E8 7B63           call C000:6523  ; init drive/file state
C000:01A8  E8 C72C           call C000:2E72  ; subsystem init chain
C000:01AB  9A 075C F0DE      call far DEF0:5C07
C000:01B0  E8 F201           call C000:03A5  ; clear [AAFB..] area
C000:01B3  BC 0010           mov sp,1000     ; final stack pointer
C000:01B6  B8 EF0C           mov ax,0CEF
C000:01B9  8E C0             mov es,ax       ; ES = 0CEF
C000:01BB  E8 4254           call C000:5600  ; clear file handles
C000:01BE  E8 0B11           call C000:12CC  ; clear keyboard state, IRQ setup
C000:01C1  FB                sti
C000:01C2  06                push es
C000:01C3  9A 035B F0DE      call far DEF0:5B03
C000:01C8  07                pop es
C000:01C9  B8 EF0C           mov ax,0CEF
C000:01CC  8E C0             mov es,ax
C000:01CE  C7 06 6F14 0000   mov word [146F],0
C000:01D4  C7 06 0911 0000   mov word [1109],0  ; startup complete
C000:01DA  EA 0400 72C7      jmp far C772:0004  ; APPLICATION ENTRY (cold)
```

## C000:01DF — Warm Resume

; file 0xC01DF

Resumes from warm state. Three timed delays, seeds bank mirrors, clears
framebuffer, checks keyboard chord, then re-enters the application.

```asm
C000:01DF  E8 D007           call C000:09B2  ; three timed delays
C000:01E2  E8 4201           call C000:0327  ; seed bank mirrors
C000:01E5  BC 0010           mov sp,1000     ; final stack
C000:01E8  B8 EF0C           mov ax,0CEF
C000:01EB  8E C0             mov es,ax
C000:01ED  E8 DC10           call C000:12CC  ; clear keyboard state, IRQ setup
C000:01F0  FB                sti
C000:01F1  06                push es
C000:01F2  E8 F501           call C000:03EA  ; clear framebuffer [8000..8FFF]
C000:01F5  07                pop es
C000:01F6  E8 A708           call C000:0AA0  ; KEYBOARD CHORD CHECK (F+J+SPACE)
C000:01F9  81 3E 6F14 9519   cmp word [146F],1995
C000:01FF  74 C1             jz C000:01C2    ; [146F]==1995 -> call DEF0:5B03 + app entry
C000:0201  E8 FC53           call C000:5600  ; clear file handles
C000:0204  E8 FC00           call C000:0303  ; save framebuffer, call DEF0:5B03, restore
C000:0207  81 3E 6F14 9719   cmp word [146F],1997
C000:020D  74 BA             jz C000:01C9    ; [146F]==1997 -> app entry (skip DEF0:5B03)
C000:020F  C7 06 6F14 0000   mov word [146F],0
C000:0215  C7 06 0911 0000   mov word [1109],0
C000:021B  EA 0800 72C7      jmp far C772:0008  ; APPLICATION ENTRY (warm)
```

Note: warm resume enters at `C772:0008`, cold start at `C772:0004`.

## C000:0220 — Normal Resume

; file 0xC0220

Reached when `[146F]==0` and segment validation passed. Installs vectors,
does RTC check and display init, checks keyboard chord, verifies saved
context checksum, then resumes the saved far pointer.

```asm
C000:0220  E8 A910           call C000:12CC  ; clear keyboard state, IRQ setup
C000:0223  FB                sti
C000:0224  E8 6007           call C000:0987  ; RTC check + startup display init
C000:0227  E8 7608           call C000:0AA0  ; KEYBOARD CHORD CHECK (F+J+SPACE)
C000:022A  72 B3             jc C000:01DF    ; chord was held -> warm_resume
C000:022C  FA                cli
C000:022D  E8 7300           call C000:02A3  ; verify saved context checksum
C000:0230  72 27             jc C000:0259    ; checksum bad -> cold_reinit
C000:0232  E8 CE00           call C000:0303  ; save framebuffer, call DEF0:5B03, restore
C000:0235  81 3E 6F14 9719   cmp word [146F],1997
C000:023B  75 05             jnz C000:0242
C000:023D  BC 0010           mov sp,1000
C000:0240  EB 87             jmp short C000:01C9 ; -> app entry
C000:0242  C7 06 0911 0000   mov word [1109],0
C000:0248  8E 1E 6114        mov ds,[1461]   ; restore saved DS
C000:024C  8E 16 6514        mov ss,[1465]   ; restore saved SS
C000:0250  8B 26 6B14        mov sp,[146B]   ; restore saved SP
C000:0254  36 FF2E 6714      jmp far [ss:1467] ; RESUME saved far pointer
```

### C000:0259

```asm
C000:0259  E9 2EFF           jmp C000:018A   ; -> cold_reinit
```

## C000:0AA0 — Keyboard Chord Check (F+J+SPACE)

; file 0xC0AA0

The diagnostic entry gate. Calls C000:14D4 which compares the keyboard
matrix at `[1306..130F]` against the ROM pattern at `CS:14FC`. If the
chord is held, enters the diagnostic command loop. On diagnostic exit,
sets `[146F]=0x1995`.

```asm
C000:0AA0  E8 310A           call C000:14D4  ; chord compare + diagnostic loop
C000:0AA3  72 01             jc C000:0AA6    ; CF=1: diagnostic was entered and exited
C000:0AA5  C3                ret             ; CF=0: no chord held
C000:0AA6  C7 06 6F14 9519   mov word [146F],1995
C000:0AAC  C3                ret
```

### C000:14D4 — Chord Compare and Diagnostic Loop

```asm
C000:14D4  E8 0F00           call C000:14E6  ; compare keyboard matrix vs ROM pattern
C000:14D7  74 02             jz C000:14DB    ; ZF=1: chord matched -> diagnostic
C000:14D9  F8                clc
C000:14DA  C3                ret             ; no chord -> return CF=0
C000:14DB  E8 2800           call C000:1506  ; render diagnostic banner (C772:005D)
C000:14DE  E8 4200           call C000:1523  ; diagnostic command loop
C000:14E1  72 02             jc C000:14E5    ; CF=1 from 1523: user exited
C000:14E3  EB F6             jmp short C000:14DB ; loop back to banner
C000:14E5  C3                ret             ; return CF=1
```

### C000:14E6 — Compare Keyboard Matrix Against ROM Pattern

Compares 10 bytes at `DS:[1306..130F]` (the keyboard matrix, populated by
the IRQ FB handler at C000:05F7 from port `0xB0` reads) against
`CS:[14FC..1505]`:

```asm
C000:14E6  06                push es
C000:14E7  BF 00C0           mov di,C000
C000:14EA  8E C7             mov es,di
C000:14EC  BF FC14           mov di,14FC     ; ES:DI = CS:14FC (ROM pattern)
C000:14EF  BE 0613           mov si,1306     ; DS:SI = [1306] (keyboard matrix)
C000:14F2  B9 0A00           mov cx,A        ; 10 bytes
C000:14F5  FC                cld
C000:14F6  F3 A6             repe cmpsb
C000:14F8  07                pop es
C000:14F9  0B C9             or cx,cx        ; CX==0 means all matched -> ZF=1
C000:14FB  C3                ret
```

### Chord Pattern at CS:14FC

```text
C000:14FC  00 08 00 00 80 00 00 00 40 00
```

| Row | Byte | Bit | Key (from MAME `nakajies.cpp`) |
| --- | ---: | --- | --- |
| ROW0 | `00` | — | no keys |
| ROW1 | `08` | bit 3 | SPACE |
| ROW2 | `00` | — | no keys |
| ROW3 | `00` | — | no keys |
| ROW4 | `80` | bit 7 | F |
| ROW5 | `00` | — | no keys |
| ROW6 | `00` | — | no keys |
| ROW7 | `00` | — | no keys |
| ROW8 | `40` | bit 6 | J |
| ROW9 | `00` | — | no keys |

The chord is **F + J + SPACE** — identical to v2.1.

## C000:0987 — RTC Check and Startup Display Init

; file 0xC0987

Called from C000:0224 during normal resume. Calls C000:08AA to check the
RTC state and the `[1439]` flag (set during power-down when the RTC is
abnormal). If the RTC is normal and `[1439]` is clear, renders the
startup display scripts (copyright/banner) and returns CF=0.

```asm
C000:0987  E8 20FF           call C000:08AA  ; RTC state gate
C000:098A  72 12             jc C000:099E    ; CF=1: RTC abnormal or flag set -> skip display
C000:098C  BB 3313           mov bx,1333     ;
C000:098F  43                inc bx          ; BX = 1334
C000:0990  8A 07             mov al,[bx]     ; AL = [1334]
C000:0992  E8 3004           call C000:0DC5  ; display helper
C000:0995  E8 B100           call C000:0A49  ; delay loop
C000:0998  E8 AE00           call C000:0A49  ; delay loop
C000:099B  E8 D6FF           call C000:0974  ; copy [9000..9FFF] -> [8000..8FFF]
C000:099E  C3                ret
```

### C000:08AA — RTC State Gate

Checks `[1439]` (RTC abnormal flag, persists across power cycles in
retained RAM). If set, waits for the RTC to stabilize. If clear, reads
RTC registers and checks whether the clock is in its reset state.

```asm
C000:08AA  80 3E 3914 00     cmp byte [1439],0
C000:08AF  74 03             jz C000:08B4    ; [1439]==0 -> check RTC now
C000:08B1  E9 9F00           jmp C000:0953   ; [1439]!=0 -> wait_for_rtc_stable
```

#### C000:08B4 — Check RTC State

```asm
C000:08B4  E8 8C05           call C000:0E43  ; read RTC ports D0..DC, compare pattern
C000:08B7  73 1A             jnc C000:08D3   ; RTC normal (CF=0) -> startup_display_init
C000:08B9  8B 1E 6714        mov bx,[1467]   ; RTC abnormal (CF=1):
C000:08BD  53                push bx
C000:08BE  06                push es
C000:08BF  9A 5FCD F0DE      call far DEF0:CD5F
C000:08C4  07                pop es
C000:08C5  5B                pop bx
C000:08C6  89 1E 6714        mov [1467],bx
C000:08CA  0B C0             or ax,ax
C000:08CC  74 03             jz C000:08D1    ; AX==0 -> return CF=1
C000:08CE  E9 BBFB           jmp C000:048C   ; AX!=0 -> power_down
C000:08D1  F9                stc
C000:08D2  C3                ret
```

#### C000:08D3 — Startup Display Init (RTC Normal)

Performs a secondary RTC check (`C000:0E2F`), then renders 9 display
script blocks from the C772 segment — the copyright and product banner
screens.

```asm
C000:08D3  E8 5905           call C000:0E2F  ; secondary RTC check (7 registers)
C000:08D6  73 03             jnc C000:08DB   ; normal -> continue
C000:08D8  E9 8000           jmp C000:095B   ; abnormal -> set [1439]=1, halt
C000:08DB  06                push es
C000:08DC  9A BCC5 F0DE      call far DEF0:C5BC
C000:08E1  07                pop es
C000:08E2  E8 8400           call C000:0969  ; save framebuffer [8000]->[9000]
```

Then renders startup text (WORD PROCESSOR copyright, CorrectSpell,
International spelling, reproduction notice, etc.):

```asm
C000:08E5  BE C8ED  mov si,EDC8  ; "WORD PROCESSOR (C) 1992..."
...9 blocks via C000:6557 (render display script)...
C000:0951  F8       clc
C000:0952  C3       ret          ; return CF=0
```

#### C000:0953 — Wait for RTC Stable

```asm
C000:0953  E8 0C05           call C000:0E62  ; check RTC registers [1484],[1485] == 0
C000:0956  73 8A             jnc C000:08E2   ; stable -> startup_display_init
C000:0958  E9 31FB           jmp C000:048C   ; still unstable -> power_down
```

#### C000:095B — Set RTC Flag and Halt

```asm
C000:095B  E8 8303           call C000:0CE1  ; advance RTC minute
C000:095E  C6 06 3914 01     mov byte [1439],1  ; set RTC abnormal flag
C000:0963  E8 59FB           call C000:04BF  ; enable RTC timer, restore port DD
C000:0966  E9 29FB           jmp C000:0492   ; halt
```

## C000:0E13 — Read RTC Registers

; file 0xC0E13

Reads 13 RTC registers from ports `0xD0..0xDC` into RAM `[1484..1490]`,
low nibble only. The RP5C01 RTC is mapped at ports `0xD0..0xDF` in
MAME.

```asm
C000:0E13  50                push ax
C000:0E14  53                push bx
C000:0E15  52                push dx
C000:0E16  BA DC00           mov dx,DC
C000:0E19  BB 9014           mov bx,1490
C000:0E1C  EC                in al,dx
C000:0E1D  24 0F             and al,0F
C000:0E1F  88 07             mov [bx],al
C000:0E21  81 FA D000        cmp dx,D0
C000:0E25  74 04             jz C000:0E2B
C000:0E27  4B                dec bx
C000:0E28  4A                dec dx
C000:0E29  EB F1             jmp short C000:0E1C
C000:0E2B  5A                pop dx
C000:0E2C  5B                pop bx
C000:0E2D  58                pop ax
C000:0E2E  C3                ret
```

## C000:0E43 — Check RTC State (11 Registers)

; file 0xC0E43

Reads RTC, compares 11 values from `[142C..1436]` against scan result
`[1490..1486]`. After `C000:03BB` clears RAM and `C000:0CA7` sets
sentinels, the expected pattern is `FF FF 00 00 00 00 00 00 00 FF FF`.
`0xFF` positions (year, minute) can never match a scan value (max `0x0F`)
so they are effectively ignored. The 7 zero positions must match for the
check to pass (CF=1).

Returns CF=1 when month, day, and hour registers all read zero — indicating
the RTC is uninitialized (coin battery dead or freshly replaced).

```asm
C000:0E43  E8 CDFF           call C000:0E13  ; read RTC -> [1484..1490]
C000:0E46  A0 3214           mov al,[1432]   ; force [148A] to match
C000:0E49  A2 8A14           mov [148A],al
C000:0E4C  BF 9014           mov di,1490
C000:0E4F  BE 2C14           mov si,142C
C000:0E52  B9 0B00           mov cx,B
C000:0E55  FC                cld
C000:0E56  AC                lodsb
C000:0E57  3A 05             cmp al,[di]
C000:0E59  75 05             jnz C000:0E60   ; mismatch -> CF=0
C000:0E5B  4F                dec di
C000:0E5C  E2 F8             loop C000:0E56
C000:0E5E  F9                stc             ; all matched -> CF=1
C000:0E5F  C3                ret
C000:0E60  F8                clc
C000:0E61  C3                ret
```

## C000:04D0 — NMI Handler (INT 02h / IRQ F8)

; file 0xC04D0

Saves full register context to `[1453..146D]`, computes context checksum,
saves state, then halts. Three early-exit paths based on `[1109]` (startup
state): if `[1109]==1` (early startup) or `[1109]==0x1995`, stores
`[1473]=0x4D0` and halts immediately without saving context.

```asm
C000:04D0  1E                push ds
C000:04D1  50                push ax
C000:04D2  55                push bp
C000:04D3  8C DD             mov bp,ds
C000:04D5  B8 0000           mov ax,0
C000:04D8  8E D8             mov ds,ax
C000:04DA  B0 80             mov al,80
C000:04DC  E6 90             out 90,al       ; LCD off
C000:04DE  A1 0911           mov ax,[1109]
C000:04E1  83 F8 01          cmp ax,1
C000:04E4  75 08             jnz C000:04EE
C000:04E6  C7 06 7314 D004   mov word [1473],4D0
C000:04EC  EB A4             jmp short C000:0492  ; -> halt
C000:04EE  3D 9519           cmp ax,1995
C000:04F1  75 08             jnz C000:04FB
C000:04F3  C7 06 7314 D004   mov word [1473],4D0
C000:04F9  EB 97             jmp short C000:0492  ; -> halt
C000:04FB  C7 06 7314 D004   mov word [1473],4D0
C000:0501  89 2E 6114        mov [1461],bp   ; save DS
C000:0505  89 1E 5514        mov [1455],bx
C000:0509  89 0E 5714        mov [1457],cx
C000:050D  89 16 5914        mov [1459],dx
C000:0511  89 36 5B14        mov [145B],si
C000:0515  89 3E 5D14        mov [145D],di
C000:0519  8C 06 6314        mov [1463],es
C000:051D  8C 16 6514        mov [1465],ss
C000:0521  8B EC             mov bp,sp
C000:0523  83 C5 06          add bp,6
C000:0526  8B 46 00          mov ax,[bp+0]   ; saved AX
C000:0529  A3 6714           mov [1467],ax
C000:052C  83 C5 02          add bp,2
C000:052F  8B 46 00          mov ax,[bp+0]   ; return IP
C000:0532  A3 6914           mov [1469],ax
C000:0535  A3 7514           mov [1475],ax
C000:0538  83 C5 02          add bp,2
C000:053B  8B 46 00          mov ax,[bp+0]   ; return CS
C000:053E  A3 6D14           mov [146D],ax
C000:0541  83 C5 02          add bp,2
C000:0544  89 2E 6B14        mov [146B],bp   ; saved SP (post-IRET frame)
C000:0548  5D                pop bp
C000:0549  89 2E 5F14        mov [145F],bp   ; original BP
C000:054D  58                pop ax
C000:054E  A3 5314           mov [1453],ax   ; original AX
C000:0551  E8 0A00           call C000:055E  ; context checksum
C000:0554  E8 4C00           call C000:05A3  ; save [1335]->[110B], mask shadow, call 0FB5/0E9F
C000:0557  B0 F8             mov al,F8
C000:0559  E6 DD             out DD,al       ; RTC control
C000:055B  E9 34FF           jmp C000:0492   ; -> halt
```

## C000:048C — Power Down

; file 0xC048C

Called when the machine needs to halt. Saves state, checks RTC registers
(not keyboard), sets `[1439]` based on RTC state, then enters infinite
halt loop with RTC alarm enabled.

```asm
C000:048C  E8 1401           call C000:05A3  ; save state
C000:048F  E8 0600           call C000:0498  ; RTC state check + set [1439]
C000:0492  B0 01             mov al,01
C000:0494  E6 70             out 70,al       ; RTC alarm enable
C000:0496  EB FE             jmp short C000:0496  ; INFINITE HALT
```

### C000:0498 — Power-Down RTC State Check

Reads RTC registers via `C000:0E43` and secondary `C000:0E2F`. If the
RTC is in its reset state (CF=1), sets `[1439]=1` and advances the RTC
minute via `C000:0CE1`. If RTC is normal, clears `[1439]` and restores
saved RTC time from `[1430..1436]` via `C000:0CB3`.

```asm
C000:0498  E4 DD             in al,DD
C000:049A  24 F7             and al,F7
C000:049C  E6 DD             out DD,al
C000:049E  06                push es
C000:049F  9A BCC5 F0DE      call far DEF0:C5BC
C000:04A4  07                pop es
C000:04A5  E8 9B09           call C000:0E43  ; check 11 RTC registers
C000:04A8  72 03             jc C000:04AD    ; abnormal -> check done (CF=1)
C000:04AA  E8 8209           call C000:0E2F  ; secondary check (7 registers)
C000:04AD  9C                pushf
C000:04AE  E4 DD             in al,DD
C000:04B0  0C 08             or al,08
C000:04B2  E6 DD             out DD,al
C000:04B4  9D                popf
C000:04B5  72 0F             jc C000:04C6    ; either check abnormal ->
C000:04B7  E8 F907           call C000:0CB3  ; RTC normal: write [1430..1436] -> ports D2..D8
C000:04BA  C6 06 3914 00     mov byte [1439],0  ; clear flag
C000:04BF  E4 DD             in al,DD
C000:04C1  0C 04             or al,04
C000:04C3  E6 DD             out DD,al
C000:04C5  C3                ret
C000:04C6  E8 1808           call C000:0CE1  ; RTC abnormal: advance RTC minute
C000:04C9  C6 06 3914 01     mov byte [1439],1  ; set flag
C000:04CE  EB EF             jmp short C000:04BF
```

## C000:0327 — Seed Bank Mirrors

; file 0xC0327

Writes default bank port values for the 1 MiB ROM into the mirror area
at `[147B..147F]`:

```asm
C000:0327  B4 0F             mov ah,0F       ; port 0x11
C000:0329  B0 1F             mov al,1F       ; port 0x12
C000:032B  A3 7B14           mov [147B],ax
C000:032E  B4 1E             mov ah,1E       ; port 0x13
C000:0330  B0 1D             mov al,1D       ; port 0x14
C000:0332  A3 7D14           mov [147D],ax
C000:0335  B0 1C             mov al,1C       ; port 0x15
C000:0337  A2 7F14           mov [147F],al
C000:033A  C3                ret
```

## C000:02A3 — Verify Saved Context Checksum

; file 0xC02A3

Recomputes checksum of 15 words at `[1453..1470]`, compares with stored
value at `[1471]`. On match, restores all saved registers and bank ports.
Returns CF=0 on success, CF=1 on failure.

```asm
C000:02A3  B8 0000           mov ax,0
C000:02A6  8E D8             mov ds,ax
C000:02A8  BE 5314           mov si,1453
C000:02AB  B9 0F00           mov cx,F
C000:02AE  FC                cld
C000:02AF  33 DB             xor bx,bx
C000:02B1  AD                lodsw
C000:02B2  03 D8             add bx,ax
C000:02B4  E2 FB             loop C000:02B1
C000:02B6  3B 1E 7114        cmp bx,[1471]
C000:02BA  74 02             jz C000:02BE
C000:02BC  F9                stc
C000:02BD  C3                ret             ; checksum mismatch
C000:02BE  A1 7B14           mov ax,[147B]   ; restore bank ports 11-15
C000:02C1  E6 12             out 12,al
C000:02C3  8A C4             mov al,ah
C000:02C5  E6 11             out 11,al
...
C000:02E5  8B 1E 5514        mov bx,[1455]   ; restore all registers
C000:02E9  8B 0E 5714        mov cx,[1457]
C000:02ED  8B 16 5914        mov dx,[1459]
C000:02F1  8B 36 5B14        mov si,[145B]
C000:02F5  8B 3E 5D14        mov di,[145D]
C000:02F9  8E 06 6314        mov es,[1463]
C000:02FD  8B 2E 5F14        mov bp,[145F]
C000:0301  F8                clc
C000:0302  C3                ret             ; success
```

## C000:0303 — Call DEF0:5B03 with Framebuffer Save/Restore

; file 0xC0303

```asm
C000:0303  C6 06 D816 01     mov byte [16D8],1
C000:0308  A1 6714           mov ax,[1467]
C000:030B  A3 D616           mov [16D6],ax
C000:030E  E8 5806           call C000:0969  ; save [8000..8FFF] -> [9000..9FFF]
C000:0311  06                push es
C000:0312  9A 035B F0DE      call far DEF0:5B03
C000:0317  07                pop es
C000:0318  E8 5906           call C000:0974  ; restore [9000..9FFF] -> [8000..8FFF]
C000:031B  A1 D616           mov ax,[16D6]
C000:031E  A3 6714           mov [1467],ax
C000:0321  C6 06 D816 00     mov byte [16D8],0
C000:0326  C3                ret
```

## C000:131D — Diagnostic Command Monitor

; file 0xC131D

Entered via banked thunk dispatch table slot 7 at `C000:1B38` (through
`C000:0025` -> `C000:1B28`). NOT reached by direct call or fall-through.

Sets `[15A2]=1`, renders the diagnostic terminal banner from `C000:76F5`
("Terminal mode   press CAN to stop"), then enters the command loop.

```asm
C000:131D  C6 06 A215 01     mov byte [15A2],1
C000:1322  E8 D000           call C000:13F5  ; render banner from C000:76F5
C000:1325  EB 1A             jmp short C000:1341 ; -> command_loop
```

### C000:1341 — Command Loop

Polls keyboard via `C000:3168`. Dispatches on key code:

- `0x0B`, `0x03`: exit diagnostic (-> C000:13C5)
- `0x14`, `0x15`, `0x17`, `0x16`: toggle bits in `[1446]`
- Table lookup at `C000:1378` for command keys
- Printable characters (`0x20..0xBF`): echo + aux output (INT 21h AH=04)
- `0xEC`: substitute from `[1498]`

Command table at `C000:1378`:

```text
08->08  11->08  09->09  12->0A  13->0B  10->0C  DA->0D  00(end)
```

Exit at `C000:13C5` clears `[15A2]` and returns.

## Boot Flow Summary

```text
FFFF:0000  CLI; JMP FAR F6E3:0000
F6E3:0000  set bank ports 16=01 17=00; JMP FAR C000:0000
C000:0000  JMP SHORT C000:0029
C000:0029  hardware port init, temp stack SP=6F00
  C000:1161  install IVT + far-call table
  compare [1000..1004] vs CS:7799 ("218")
  MISMATCH:                              MATCH:
    stamp sig -> RAM                       restore bank ports from [147B..147F]
    C000:09EA  timed delays                |
    C000:0327  seed bank mirrors           |
    restore bank ports from mirrors        |
    C000:03BB  clear RAM                   |
    C000:6523  init drive/file state       |
    C000:0327  seed mirrors again          |
    C000:4396  storage endpoint init       |
    C000:0571  RAM checksum                |
    C000:2E72  subsystem init chain        |
    DEF0:5C07  far call                    |
    C000:03A5  clear [AAFB..] area         |
    C000:5600  clear file handles          |
    set [143C] bit 0, [146F]=1995          |
    |                                      |
    +-------->-----------------------------+
              |
  C000:0107   clear volatile state, [1109]=1
              if [1473]==4D0: call C000:09CE (display helper)
  C000:2E2D   validate stored state
              CF=1 (fail) --------> C000:018A cold_reinit
              CF=0 (pass):
              [143C] bit 0 set? --> C000:01DF warm_resume
              [143C] bit 0 clear:
  C000:0148     check [1467] for known app states
                unknown state -----> C000:025E nmi_resume
  C000:016C     [1469] != CS? -----> C000:018A cold_reinit
                [146F] != 0? ------> C000:01DF warm_resume
                [146F] == 0:
  C000:0220       C000:12CC  clear keyboard state, IRQ setup
                  STI
                  C000:0987  RTC check + startup display init
                    C000:08AA  check [1439] (RTC abnormal flag)
                      [1439]!=0: wait for RTC stable, then display init
                      [1439]==0: C000:0E43 read RTC registers
                        RTC normal: render copyright screens, return CF=0
                        RTC abnormal: call DEF0:CD5F, may power down
                  C000:0AA0  KEYBOARD CHORD CHECK (F+J+SPACE)
                    C000:14D4  compare [1306..130F] vs CS:14FC
                      chord held: render diagnostic banner, enter C000:1523
                                  command loop; on exit set [146F]=1995
                      no chord: return CF=0
                  CF=1 (chord was held) -> C000:01DF warm_resume
                  CF=0 (no chord):
                  C000:02A3  verify context checksum [1453..1470]
                    fail -> C000:018A cold_reinit
                    pass:
                  C000:0303  save framebuffer, call DEF0:5B03, restore
                  [146F]==1997? -> C000:01C9 app entry
                  else: restore DS/SS/SP from [1461/1465/146B]
                        JMP FAR [SS:1467]  -- RESUME SAVED CONTEXT

  C000:018A cold_reinit:
    C000:09D4  render "INITIALIZING" banner, delay
    clear [146F], mask interrupts
    C000:0327/03BB/6523/2E72 reinit subsystems
    DEF0:5C07, C000:03A5, C000:5600
    C000:12CC  clear keyboard state
    STI
    DEF0:5B03  far call
    clear [146F], [1109]=0
    JMP FAR C772:0004  -- APPLICATION ENTRY (cold)

  C000:01DF warm_resume:
    C000:09B2  three timed delays
    C000:0327  seed bank mirrors
    SP=1000, ES=0CEF
    C000:12CC  clear keyboard state
    STI
    C000:03EA  clear framebuffer [8000..8FFF]
    C000:0AA0  KEYBOARD CHORD CHECK (F+J+SPACE)
    [146F]==1995? -> DEF0:5B03 + JMP FAR C772:0004
    C000:5600  clear file handles
    C000:0303  save framebuffer, call DEF0:5B03, restore
    [146F]==1997? -> JMP FAR C772:0004
    clear [146F], [1109]=0
    JMP FAR C772:0008  -- APPLICATION ENTRY (warm)
```

## Low-RAM State Map

| Address | Size | Purpose |
| --- | --- | --- |
| `[1000..1004]` | 5 | Warm-RAM signature (`"218"` + secondary byte) |
| `[1005]` | 1 | Set to `0x48` during init |
| `[1106]` | 1 | Storage endpoint type (checked by C000:2E2D) |
| `[1109]` | 2 | Startup state: `1`=early, `0`=complete, `0x1995`=battery/warning, `0x1999`=error |
| `[1306..130F]` | 10 | Keyboard matrix (populated by IRQ FB from port 0xB0 reads) |
| `[132D]` | 1 | Keyboard scan row counter (0..9) |
| `[1335]` | 2 | Saved by C000:05A3 to `[110B]` |
| `[1337]` | 2 | Validated against `0x7CE` by C000:2E2D |
| `[1439]` | 1 | RTC abnormal flag: set during power-down when RTC is in reset state |
| `[143A]` | 1 | Interrupt mask shadow (port 0x60) |
| `[143C]` | 1 | Bit 0 = warm-retry flag |
| `[142C..1436]` | 11 | RTC expected pattern (primary check, 0E43) |
| `[1430..1436]` | 7 | RTC expected pattern (secondary check, 0E2F) / saved RTC time (0CB3) |
| `[1446]` | 1 | Diagnostic mode flags (bits 0-1) |
| `[1453..1470]` | 30 | Saved register context (NMI handler) |
| `[1471]` | 2 | Context checksum |
| `[1473]` | 2 | NMI source marker (`0x4D0` if NMI, else `0`) |
| `[1467]` | 2 | Saved IP / application state word |
| `[1469]` | 2 | Saved CS |
| `[146B]` | 2 | Saved SP |
| `[146F]` | 2 | Resume state: `0`=normal, `0x1995`=battery/warning, `0x1997`=warm ok |
| `[147B..147F]` | 5 | Bank port mirrors (ports 11-15) |
| `[1482]` | 1 | Port 0x30 shadow |
| `[1484..1490]` | 13 | RTC register scan buffer (ports D0..DC, low nibble) |
| `[15A2]` | 1 | Diagnostic monitor active flag |
| `[6F5E..6F61]` | 4 | File handle state (cleared to `0xFF`) |
