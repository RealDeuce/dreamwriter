# Boot Disassembly

Depth-first trace from reset through cold/warm startup to the application
entry point. Every branch and call target was disassembled at its actual
entry point; no labels are inferred from v2.1.

See [`../map.md`](../map.md) for the address model and banking layout.

## Reset Vector

; file 0xFFFF0

```asm
FFFF:0000  FA                cli
FFFF:0001  EA 0000 E3F6      jmp far F6E3:0000
```

Remainder of the 16-byte reset block is `0x3F` fill.

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

Followed by `0xFF` fill to the next boundary.

## C000:0000 — Entry and Jump Table

; file 0xC0000

```asm
C000:0000  EB 27             jmp short C000:0029
C000:0002  00 00             ;
C000:0004  00 00             ;
C000:0006  E9 6E62           jmp C000:6277      ; INT 21h dispatch
C000:0009  E9 C404           jmp C000:04D0      ; IRQ F8 — NMI / save context
C000:000C  E9 B105           jmp C000:05C0      ; IRQ F9
C000:000F  E9 C205           jmp C000:05D4      ; IRQ FA
C000:0012  E9 E205           jmp C000:05F7      ; IRQ FB
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
C000:003B  8E D8             mov ds,ax
C000:003D  8E C0             mov es,ax
C000:003F  B0 FF             mov al,FF
C000:0041  E6 90             out 90,al       ; LCD control
C000:0043  A2 3A14           mov [143A],al   ; LCD shadow
C000:0046  B0 00             mov al,00
C000:0048  E6 20             out 20,al       ; keyboard column select
C000:004A  B0 40             mov al,40
C000:004C  E6 00             out 00,al       ; LCD base address
C000:004E  B0 F0             mov al,F0
C000:0050  E6 DE             out DE,al       ; RTC register
C000:0052  B0 F8             mov al,F8
C000:0054  E6 DD             out DD,al       ; RTC register
C000:0056  B0 5F             mov al,5F
C000:0058  A2 8214           mov [1482],al   ; port 0x30 shadow
C000:005B  B0 FF             mov al,FF
C000:005D  E6 40             out 40,al       ; serial control
C000:005F  BC 006F           mov sp,6F00     ; temporary stack
C000:0062  E8 FC10           call C000:1161  ; -> install IVT + far-call table
```

## C000:0065 — Warm-RAM Signature Check

; file 0xC0065

After IVT install, checks 4 bytes at RAM `[1000..1003]` against the ROM
signature at `CS:7799`. The signature bytes are `32 31 38 20` = `"218 "`.

```asm
C000:0065  BE 9977           mov si,7799     ; ROM signature source
C000:0068  BF 0010           mov di,1000     ; RAM check location
C000:006B  B9 0400           mov cx,4
C000:006E  2E 8A04           mov al,[cs:si]
C000:0071  3A 05             cmp al,[di]
C000:0073  75 10             jnz C000:0085   ; -> cold_stamp
C000:0075  46                inc si
C000:0076  47                inc di
C000:0077  E2 F5             loop C000:006E
```

If all 4 bytes match, a 5th byte is checked:

```asm
C000:0079  BE CF64           mov si,64CF     ; secondary signature byte
C000:007C  2E 8A04           mov al,[cs:si]
C000:007F  3A 05             cmp al,[di]     ; RAM [1004]
C000:0081  75 0B             jnz C000:008E   ; -> cold_stamp_secondary
C000:0083  EB 67             jmp short C000:00EC ; -> warm_path
```

### C000:0085 — cold_stamp (signature mismatch)

Writes remaining signature bytes from ROM to RAM, then stamps the secondary
byte and falls through to cold init:

```asm
C000:0085  2E 8A04           mov al,[cs:si]
C000:0088  88 05             mov [di],al
C000:008A  46                inc si
C000:008B  47                inc di
C000:008C  E2 F7             loop C000:0085
C000:008E  BE CF64           mov si,64CF     ; secondary byte
C000:0091  2E 8A04           mov al,[cs:si]
C000:0094  88 05             mov [di],al     ; stamp RAM [1004]
```

Falls through to C000:0096.

### C000:0096 — Cold-Start Init

```asm
C000:0096  E8 5109           call C000:09EA  ; -> cold_early_init
C000:0099  E8 8B02           call C000:0327  ; -> seed_bank_mirrors
C000:009C  A1 7B14           mov ax,[147B]   ; restore ports 11/12
C000:009F  86 C4             xchg ah,al
C000:00A1  E6 11             out 11,al
C000:00A3  8A C4             mov al,ah
C000:00A5  E6 12             out 12,al
C000:00A7  A1 7D14           mov ax,[147D]   ; restore ports 13/14
C000:00AA  86 C4             xchg ah,al
C000:00AC  E6 13             out 13,al
C000:00AE  8A C4             mov al,ah
C000:00B0  E6 14             out 14,al
C000:00B2  A0 7F14           mov al,[147F]   ; restore port 15
C000:00B5  E6 15             out 15,al
C000:00B7  E8 0103           call C000:03BB  ; -> hardware_setup_2
C000:00BA  E8 6664           call C000:6523  ; -> int21_services_init
C000:00BD  E8 6702           call C000:0327  ; -> seed_bank_mirrors (again)
C000:00C0  C6 06 0510 48     mov byte [1005],48
C000:00C5  B3 A5             mov bl,A5
C000:00C7  B2 08             mov dl,08
C000:00C9  B4 FF             mov ah,FF
C000:00CB  E8 C842           call C000:4396  ; -> store_validate
C000:00CE  E8 A004           call C000:0571  ; -> ram_checksum_init
C000:00D1  E8 9E2D           call C000:2E72  ; -> subsystem_init
C000:00D4  9A 075C F0DE      call far DEF0:5C07  ; app subsystem init
C000:00D9  E8 C902           call C000:03A5  ; -> keyboard_scan_start
C000:00DC  E8 2155           call C000:5600  ; -> file_table_init
C000:00DF  80 0E 3C14 01     or byte [143C],01  ; set warm-retry flag
C000:00E4  C7 06 6F14 9519   mov word [146F],1995
C000:00EA  EB 1B             jmp short C000:0107 ; -> common_init_tail
```

### C000:00EC — warm_path (signature matched)

Restores bank ports from saved mirrors, no subsystem re-init:

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

## C000:0107 — common_init_tail

; file 0xC0107

Clears volatile state and enters the warm/cold decision tree:

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
C000:011F  A3 0911           mov [1109],ax   ; startup state = 1
C000:0122  C6 06 0510 48     mov byte [1005],48
C000:0127  81 3E 7314 D004   cmp word [1473],4D0
C000:012D  75 03             jnz C000:0132
C000:012F  E8 9C08           call C000:09CE  ; -> nmi_recovery_init
```

`C000:09CE` is only called if `[1473]==0x04D0`, meaning the previous session
ended via NMI handler (which stores `0x04D0` into `[1473]`).

```asm
C000:0132  E8 F82C           call C000:2E2D  ; -> warm_state_validate
C000:0135  72 53             jc C000:018A    ; CF=1 -> cold_reinit
C000:0137  F6 06 3C14 01     test byte [143C],01  ; warm-retry flag?
C000:013C  9C                pushf
C000:013D  80 26 3C14 FE     and byte [143C],FE   ; clear it
C000:0142  9D                popf
C000:0143  74 03             jz C000:0148    ; not set -> resume_check
C000:0145  E9 9700           jmp C000:01DF   ; set -> warm_resume
```

## C000:0148 — resume_check

; file 0xC0148

Checks `[1467]` for known application state values. If any match, or if
`[1467]` is zero, falls through to segment validation at C000:016C:

```asm
C000:0148  A1 6714           mov ax,[1467]
C000:014B  0B C0             or ax,ax
C000:014D  74 1D             jz C000:016C
C000:014F  3D 0D32           cmp ax,320D
C000:0152  74 18             jz C000:016C
C000:0154  3D E730           cmp ax,30E7
C000:0157  74 13             jz C000:016C
C000:0159  3D 6D31           cmp ax,316D
C000:015C  74 0E             jz C000:016C
C000:015E  81 3E 7314 D004   cmp word [1473],4D0
C000:0164  E9 F700           jmp C000:025E   ; -> resume_from_nmi
```

If `[1467]` doesn't match any known value and `[1473]!=0x4D0`, jumps to
C000:025E (NMI resume path).

### C000:016C — segment_validate

```asm
C000:016C  8B D8             mov bx,ax       ; BX = [1467]
C000:016E  8C C8             mov ax,cs
C000:0170  3B 06 6914        cmp ax,[1469]   ; saved CS == current CS?
C000:0174  75 14             jnz C000:018A   ; no -> cold_reinit
C000:0176  0B DB             or bx,bx
C000:0178  75 06             jnz C000:0180
C000:017A  C7 06 6F14 9519   mov word [146F],1995
C000:0180  A1 6F14           mov ax,[146F]
C000:0183  0B C0             or ax,ax
C000:0185  75 58             jnz C000:01DF   ; nonzero -> warm_resume
C000:0187  E9 9600           jmp C000:0220   ; zero -> diagnostic_gate
```

Three outcomes:
- `[1469] != CS` → C000:018A (cold reinit — context is from a different ROM)
- `[146F] != 0` → C000:01DF (warm resume)
- `[146F] == 0` → C000:0220 (diagnostic gate / normal resume)

## C000:018A — cold_reinit

; file 0xC018A

Full cold reinitialization when warm state validation fails:

```asm
C000:018A  E8 4708           call C000:09D4  ; -> cold_banner
C000:018D  C7 06 6F14 0000   mov word [146F],0
C000:0193  B0 FF             mov al,FF
C000:0195  E6 60             out 60,al       ; interrupt mask
C000:0197  A2 3A14           mov [143A],al
C000:019A  E8 8A01           call C000:0327  ; -> seed_bank_mirrors
C000:019D  E8 1B02           call C000:03BB  ; -> hardware_setup_2
C000:01A0  B0 FF             mov al,FF
C000:01A2  A2 3A14           mov [143A],al
C000:01A5  E8 7B63           call C000:6523  ; -> int21_services_init
C000:01A8  E8 C72C           call C000:2E72  ; -> subsystem_init
C000:01AB  9A 075C F0DE      call far DEF0:5C07  ; app subsystem init
C000:01B0  E8 F201           call C000:03A5  ; -> keyboard_scan_start
C000:01B3  BC 0010           mov sp,1000     ; final stack
C000:01B6  B8 EF0C           mov ax,0CEF
C000:01B9  8E C0             mov es,ax       ; ES = 0CEF
C000:01BB  E8 4254           call C000:5600  ; -> file_table_init
C000:01BE  E8 0B11           call C000:12CC  ; -> install_vectors_and_state
C000:01C1  FB                sti
C000:01C2  06                push es
C000:01C3  9A 035B F0DE      call far DEF0:5B03  ; app init
C000:01C8  07                pop es
C000:01C9  B8 EF0C           mov ax,0CEF
C000:01CC  8E C0             mov es,ax
C000:01CE  C7 06 6F14 0000   mov word [146F],0
C000:01D4  C7 06 0911 0000   mov word [1109],0
C000:01DA  EA 0400 72C7      jmp far C772:0004   ; -> APPLICATION ENTRY
```

## C000:01DF — warm_resume

; file 0xC01DF

Resume from warm state. Restores saved context and re-enters the
application:

```asm
C000:01DF  E8 D007           call C000:09B2  ; -> framebuffer_swap_restore
C000:01E2  E8 4201           call C000:0327  ; -> seed_bank_mirrors
C000:01E5  BC 0010           mov sp,1000
C000:01E8  B8 EF0C           mov ax,0CEF
C000:01EB  8E C0             mov es,ax
C000:01ED  E8 DC10           call C000:12CC  ; -> install_vectors_and_state
C000:01F0  FB                sti
C000:01F1  06                push es
C000:01F2  E8 F501           call C000:03EA  ; -> restore_saved_context
C000:01F5  07                pop es
C000:01F6  E8 A708           call C000:0AA0  ; -> battery_check
C000:01F9  81 3E 6F14 9519   cmp word [146F],1995
C000:01FF  74 C1             jz C000:01C2    ; battery warning -> app init
C000:0201  E8 FC53           call C000:5600  ; -> file_table_init
C000:0204  E8 FC00           call C000:0303  ; -> reinit_app_with_swap
C000:0207  81 3E 6F14 9719   cmp word [146F],1997
C000:020D  74 BA             jz C000:01C9    ; 1997 -> app init (skip DEF0:5B03)
C000:020F  C7 06 6F14 0000   mov word [146F],0
C000:0215  C7 06 0911 0000   mov word [1109],0
C000:021B  EA 0800 72C7      jmp far C772:0008   ; -> APPLICATION ENTRY (alt)
```

Note: warm resume uses `C772:0008` (offset 8), not `C772:0004` (offset 4)
like cold start.

## C000:0220 — diagnostic_gate

; file 0xC0220

Reached when `[146F]==0` in the resume check. Installs vectors, enables
interrupts, then calls C000:0987 which checks the keyboard chord:

```asm
C000:0220  E8 A910           call C000:12CC  ; -> install_vectors_and_state
C000:0223  FB                sti
C000:0224  E8 6007           call C000:0987  ; -> chord_check_and_init
C000:0227  E8 7608           call C000:0AA0  ; -> battery_check
C000:022A  72 B3             jc C000:01DF    ; battery issue -> warm_resume
C000:022C  FA                cli
C000:022D  E8 7300           call C000:02A3  ; -> context_checksum_verify
C000:0230  72 27             jc C000:0259    ; checksum bad -> cold_reinit
C000:0232  E8 CE00           call C000:0303  ; -> reinit_app_with_swap
C000:0235  81 3E 6F14 9719   cmp word [146F],1997
C000:023B  75 05             jnz C000:0242
C000:023D  BC 0010           mov sp,1000
C000:0240  EB 87             jmp short C000:01C9 ; -> app init
C000:0242  C7 06 0911 0000   mov word [1109],0
C000:0248  8E 1E 6114        mov ds,[1461]   ; restore saved segments
C000:024C  8E 16 6514        mov ss,[1465]
C000:0250  8B 26 6B14        mov sp,[146B]
C000:0254  36 FF2E 6714      jmp far [ss:1467] ; -> resume saved far pointer
```

## C000:0987 — chord_check_and_init

; file 0xC0987

Called from the diagnostic gate. Calls C000:08AA to check the keyboard
chord. If the chord was NOT held, falls through to display init. If held,
returns immediately with CF=1:

```asm
C000:0987  E8 20FF           call C000:08AA  ; -> chord_gate
C000:098A  72 12             jc C000:099E    ; chord matched -> return
C000:098C  BB 3313           mov bx,1333
C000:098F  43                inc bx          ; BX = 1334
C000:0990  8A 07             mov al,[bx]
C000:0992  E8 3004           call C000:0DC5  ; -> display helper
C000:0995  E8 B100           call C000:0A49  ; -> delay_loop
C000:0998  E8 AE00           call C000:0A49  ; -> delay_loop
C000:099B  E8 D6FF           call C000:0974  ; -> framebuffer_restore_9000_to_8000
C000:099E  C3                ret
```

## C000:08AA — chord_gate

; file 0xC08AA

The actual keyboard chord dispatcher. Checks `[1439]` (diagnostic flag set
by a previous power cycle's chord detection):

```asm
C000:08AA  80 3E 3914 00     cmp byte [1439],0
C000:08AF  74 03             jz C000:08B4    ; first boot -> check chord now
C000:08B1  E9 9F00           jmp C000:0953   ; flag set -> wait_for_release
```

### C000:08B4 — check_chord_now

```asm
C000:08B4  E8 8C05           call C000:0E43  ; -> scan_keyboard_chord_11
C000:08B7  73 1A             jnc C000:08D3   ; no chord -> normal_startup_init
C000:08B9  8B 1E 6714        mov bx,[1467]
C000:08BD  53                push bx
C000:08BE  06                push es
C000:08BF  9A 5FCD F0DE      call far DEF0:CD5F
C000:08C4  07                pop es
C000:08C5  5B                pop bx
C000:08C6  89 1E 6714        mov [1467],bx
C000:08CA  0B C0             or ax,ax
C000:08CC  74 03             jz C000:08D1    ; AX==0 -> return CF=1
C000:08CE  E9 BBFB           jmp C000:048C   ; AX!=0 -> power_down_with_chord
C000:08D1  F9                stc
C000:08D2  C3                ret             ; return to 0987 with CF=1
```

If the chord is held: calls `DEF0:CD5F`, then if AX!=0 goes to the
power-down path at C000:048C. The power-down path sets `[1439]=1` and
halts; on next boot, `[1439]` is nonzero so C000:0953 runs instead.

### C000:08D3 — normal_startup_init (no chord)

```asm
C000:08D3  E8 5905           call C000:0E2F  ; -> scan_keyboard_chord_7
C000:08D6  73 03             jnc C000:08DB   ; no secondary chord -> continue
C000:08D8  E9 8000           jmp C000:095B   ; secondary chord -> diag_flag_halt
```

If the secondary 7-byte chord also fails, proceeds to the full startup
display initialization:

```asm
C000:08DB  06                push es
C000:08DC  9A BCC5 F0DE      call far DEF0:C5BC
C000:08E1  07                pop es
C000:08E2  E8 8400           call C000:0969  ; -> framebuffer_save_8000_to_9000
C000:08E5  BE C8ED           mov si,EDC8
C000:08E8  B9 0600           mov cx,6
C000:08EB  BA 72C7           mov dx,C772     ; segment for display scripts
C000:08EE  E8 665C           call C000:6557  ; -> render_display_script
C000:08F1  BE CEED           mov si,EDCE
C000:08F4  B9 6300           mov cx,63
C000:08F7  BA 72C7           mov dx,C772
C000:08FA  E8 5A5C           call C000:6557
C000:08FD  BE 31EE           mov si,EE31
C000:0900  B9 0700           mov cx,7
C000:0903  BA 72C7           mov dx,C772
C000:0906  E8 4E5C           call C000:6557
C000:0909  BE 38EE           mov si,EE38
C000:090C  B9 4400           mov cx,44
C000:090F  BA 72C7           mov dx,C772
C000:0912  E8 425C           call C000:6557
C000:0915  BE 7CEE           mov si,EE7C
C000:0918  B9 3F00           mov cx,3F
C000:091B  BA 72C7           mov dx,C772
C000:091E  E8 365C           call C000:6557
C000:0921  BE BBEE           mov si,EEBB
C000:0924  B9 4400           mov cx,44
C000:0927  BA 72C7           mov dx,C772
C000:092A  E8 2A5C           call C000:6557
C000:092D  BE FFEE           mov si,EEFF
C000:0930  B9 3B00           mov cx,3B
C000:0933  BA 72C7           mov dx,C772
C000:0936  E8 1E5C           call C000:6557
C000:0939  BE 3AEF           mov si,EF3A
C000:093C  B9 5A00           mov cx,5A
C000:093F  BA 72C7           mov dx,C772
C000:0942  E8 125C           call C000:6557
C000:0945  BE 94EF           mov si,EF94
C000:0948  B9 0B00           mov cx,0B
C000:094B  BA 72C7           mov dx,C772
C000:094E  E8 065C           call C000:6557
C000:0951  F8                clc
C000:0952  C3                ret             ; return to 0987 with CF=0
```

Renders 9 display script blocks from the C772 segment. These are the
copyright/startup banner screens.

### C000:0953 — wait_for_release

Reached when `[1439]!=0` (chord was held on previous boot). Waits for the
keyboard to be released:

```asm
C000:0953  E8 0C05           call C000:0E62  ; -> check_keyboard_clear
C000:0956  73 8A             jnc C000:08E2   ; keys released -> startup_init
C000:0958  E9 31FB           jmp C000:048C   ; still held -> power_down
```

### C000:095B — diag_flag_halt

Secondary chord matched; sets the diagnostic flag and halts:

```asm
C000:095B  E8 8303           call C000:0CE1  ; -> diagnostic_display_init
C000:095E  C6 06 3914 01     mov byte [1439],1
C000:0963  E8 59FB           call C000:04BF  ; -> rtc_enable
C000:0966  E9 29FB           jmp C000:0492   ; -> halt_loop
```

## C000:048C — power_down_with_chord

; file 0xC048C

Saves final state, checks if chord is held, sets `[1439]`, then halts.
The RTC alarm will wake the machine later:

```asm
C000:048C  E8 1401           call C000:05A3  ; -> save_state
C000:048F  E8 0600           call C000:0498  ; -> warm_irq_chord_check
C000:0492  B0 01             mov al,01
C000:0494  E6 70             out 70,al       ; RTC alarm enable
C000:0496  EB FE             jmp short C000:0496 ; HALT (infinite loop)
```

### C000:0498 — warm_irq_chord_check

Scans the keyboard matrix and checks both chord patterns. Sets `[1439]`
accordingly:

```asm
C000:0498  E4 DD             in al,DD
C000:049A  24 F7             and al,F7
C000:049C  E6 DD             out DD,al
C000:049E  06                push es
C000:049F  9A BCC5 F0DE      call far DEF0:C5BC
C000:04A4  07                pop es
C000:04A5  E8 9B09           call C000:0E43  ; -> scan_keyboard_chord_11
C000:04A8  72 03             jc C000:04AD    ; chord matched
C000:04AA  E8 8209           call C000:0E2F  ; -> scan_keyboard_chord_7
C000:04AD  9C                pushf
C000:04AE  E4 DD             in al,DD
C000:04B0  0C 08             or al,08
C000:04B2  E6 DD             out DD,al
C000:04B4  9D                popf
C000:04B5  72 0F             jc C000:04C6    ; either chord matched
C000:04B7  E8 F907           call C000:0CB3  ; -> no chord: clear diag state
C000:04BA  C6 06 3914 00     mov byte [1439],0
C000:04BF  E4 DD             in al,DD
C000:04C1  0C 04             or al,04
C000:04C3  E6 DD             out DD,al
C000:04C5  C3                ret
C000:04C6  E8 1808           call C000:0CE1  ; -> chord: diagnostic_display_init
C000:04C9  C6 06 3914 01     mov byte [1439],1
C000:04CE  EB EF             jmp short C000:04BF
```

## C000:04D0 — NMI Handler (INT 02h / IRQ F8)

; file 0xC04D0

Saves full register context to low RAM `[1453..146D]`. Three early-exit
cases based on `[1109]` (startup state):

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
C000:04E1  83 F8 01          cmp ax,1        ; early startup?
C000:04E4  75 08             jnz C000:04EE
C000:04E6  C7 06 7314 D004   mov word [1473],4D0
C000:04EC  EB A4             jmp short C000:0492 ; -> halt
C000:04EE  3D 9519           cmp ax,1995     ; battery warning state?
C000:04F1  75 08             jnz C000:04FB
C000:04F3  C7 06 7314 D004   mov word [1473],4D0
C000:04F9  EB 97             jmp short C000:0492 ; -> halt
C000:04FB  C7 06 7314 D004   mov word [1473],4D0
C000:0501  89 2E 6114        mov [1461],bp   ; save DS (via BP)
C000:0505  89 1E 5514        mov [1455],bx
C000:0509  89 0E 5714        mov [1457],cx
C000:050D  89 16 5914        mov [1459],dx
C000:0511  89 36 5B14        mov [145B],si
C000:0515  89 3E 5D14        mov [145D],di
C000:0519  8C 06 6314        mov [1463],es
C000:051D  8C 16 6514        mov [1465],ss
C000:0521  8B EC             mov bp,sp
C000:0523  83 C5 06          add bp,6
C000:0526  8B 46 00          mov ax,[bp+0]   ; saved AX from stack
C000:0529  A3 6714           mov [1467],ax
C000:052C  83 C5 02          add bp,2
C000:052F  8B 46 00          mov ax,[bp+0]   ; return IP
C000:0532  A3 6914           mov [1469],ax
C000:0535  A3 7514           mov [1475],ax
C000:0538  83 C5 02          add bp,2
C000:053B  8B 46 00          mov ax,[bp+0]   ; return CS
C000:053E  A3 6D14           mov [146D],ax
C000:0541  83 C5 02          add bp,2
C000:0544  89 2E 6B14        mov [146B],bp   ; saved SP (after iret frame)
C000:0548  5D                pop bp
C000:0549  89 2E 5F14        mov [145F],bp   ; original BP
C000:054D  58                pop ax
C000:054E  A3 5314           mov [1453],ax   ; original AX
C000:0551  E8 0A00           call C000:055E  ; -> context_checksum
C000:0554  E8 4C00           call C000:05A3  ; -> save_state
C000:0557  B0 F8             mov al,F8
C000:0559  E6 DD             out DD,al
C000:055B  E9 34FF           jmp C000:0492   ; -> halt
```

### C000:055E — context_checksum

Checksums the 15-word saved context block at `[1453..1470]`:

```asm
C000:055E  BE 5314           mov si,1453
C000:0561  B9 0F00           mov cx,F
C000:0564  FC                cld
C000:0565  33 DB             xor bx,bx
C000:0567  AD                lodsw
C000:0568  03 D8             add bx,ax
C000:056A  E2 FB             loop C000:0567
C000:056C  89 1E 7114        mov [1471],bx   ; store checksum
C000:0570  C3                ret
```

## C000:02A3 — context_checksum_verify

; file 0xC02A3

Recomputes the context checksum and compares with stored value. On match,
restores all saved registers from `[1453..1465]`:

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
C000:02B6  3B 1E 7114        cmp bx,[1471]   ; matches saved checksum?
C000:02BA  74 02             jz C000:02BE
C000:02BC  F9                stc             ; mismatch -> CF=1
C000:02BD  C3                ret
C000:02BE  A1 7B14           mov ax,[147B]   ; restore bank ports
C000:02C1  E6 12             out 12,al
C000:02C3  8A C4             mov al,ah
C000:02C5  E6 11             out 11,al
C000:02C7  A1 7D14           mov ax,[147D]
C000:02CA  E6 14             out 14,al
C000:02CC  8A C4             mov al,ah
C000:02CE  E6 13             out 13,al
C000:02D0  A0 7F14           mov al,[147F]
C000:02D3  E6 15             out 15,al
C000:02D5  F6 06 3B14 10     test byte [143B],10
C000:02DA  75 04             jnz C000:02E0
C000:02DC  E8 2C0C           call C000:0F0B  ; -> additional_hw_restore
C000:02DF  FA                cli
C000:02E0  A0 3A14           mov al,[143A]
C000:02E3  E6 60             out 60,al       ; restore interrupt mask
C000:02E5  8B 1E 5514        mov bx,[1455]
C000:02E9  8B 0E 5714        mov cx,[1457]
C000:02ED  8B 16 5914        mov dx,[1459]
C000:02F1  8B 36 5B14        mov si,[145B]
C000:02F5  8B 3E 5D14        mov di,[145D]
C000:02F9  8E 06 6314        mov es,[1463]
C000:02FD  8B 2E 5F14        mov bp,[145F]
C000:0301  F8                clc             ; success -> CF=0
C000:0302  C3                ret
```

## C000:0327 — seed_bank_mirrors

; file 0xC0327

Writes the default bank port values for a 1 MiB ROM into the low-RAM
mirror used by the bank restore code:

```asm
C000:0327  B4 0F             mov ah,0F       ; port 0x11 = 0x0F
C000:0329  B0 1F             mov al,1F       ; port 0x12 = 0x1F
C000:032B  A3 7B14           mov [147B],ax
C000:032E  B4 1E             mov ah,1E       ; port 0x13 = 0x1E
C000:0330  B0 1D             mov al,1D       ; port 0x14 = 0x1D
C000:0332  A3 7D14           mov [147D],ax
C000:0335  B0 1C             mov al,1C       ; port 0x15 = 0x1C
C000:0337  A2 7F14           mov [147F],al
C000:033A  C3                ret
```

## C000:0E13 — scan_keyboard_matrix

; file 0xC0E13

Reads keyboard row registers from ports `0xD0..0xDC` (13 ports) into
RAM `[1484..1490]`, low nibble only:

```asm
C000:0E13  50                push ax
C000:0E14  53                push bx
C000:0E15  52                push dx
C000:0E16  BA DC00           mov dx,DC       ; start at port DC
C000:0E19  BB 9014           mov bx,1490     ; store at [1490] downward
C000:0E1C  EC                in al,dx
C000:0E1D  24 0F             and al,0F
C000:0E1F  88 07             mov [bx],al
C000:0E21  81 FA D000        cmp dx,D0       ; done?
C000:0E25  74 04             jz C000:0E2B
C000:0E27  4B                dec bx
C000:0E28  4A                dec dx
C000:0E29  EB F1             jmp short C000:0E1C
C000:0E2B  5A                pop dx
C000:0E2C  5B                pop bx
C000:0E2D  58                pop ax
C000:0E2E  C3                ret
```

## C000:0E43 — scan_keyboard_chord_11

; file 0xC0E43

Scans the keyboard matrix and compares 11 bytes from `[142C]` against
the scan result `[1490]` (descending). Returns CF=1 if all match:

```asm
C000:0E43  E8 CDFF           call C000:0E13  ; -> scan_keyboard_matrix
C000:0E46  A0 3214           mov al,[1432]
C000:0E49  A2 8A14           mov [148A],al
C000:0E4C  BF 9014           mov di,1490     ; scan result (descending)
C000:0E4F  BE 2C14           mov si,142C     ; expected pattern
C000:0E52  B9 0B00           mov cx,B        ; 11 bytes
C000:0E55  FC                cld
C000:0E56  AC                lodsb
C000:0E57  3A 05             cmp al,[di]
C000:0E59  75 05             jnz C000:0E60   ; mismatch -> CF=0
C000:0E5B  4F                dec di
C000:0E5C  E2 F8             loop C000:0E56
C000:0E5E  F9                stc             ; all matched -> CF=1
C000:0E5F  C3                ret
C000:0E60  F8                clc             ; mismatch -> CF=0
C000:0E61  C3                ret
```

## C000:0E2F — scan_keyboard_chord_7

; file 0xC0E2F

Secondary chord check — compares 7 bytes from `[1430]` against `[148C]`:

```asm
C000:0E2F  E8 E1FF           call C000:0E13  ; -> scan_keyboard_matrix
C000:0E32  A0 3214           mov al,[1432]
C000:0E35  A2 8A14           mov [148A],al
C000:0E38  BF 8C14           mov di,148C
C000:0E3B  BE 3014           mov si,1430
C000:0E3E  B9 0700           mov cx,7
C000:0E41  EB 12             jmp short C000:0E55 ; -> shared compare loop
```

## C000:0E62 — check_keyboard_clear

; file 0xC0E62

Checks that `[1484]` and `[1485]` are both zero (no keys pressed):

```asm
C000:0E62  E8 AEFF           call C000:0E13  ; -> scan_keyboard_matrix
C000:0E65  32 C0             xor al,al
C000:0E67  3A 06 8414        cmp al,[1484]
C000:0E6B  75 F3             jnz C000:0E60   ; key pressed -> CF=0
C000:0E6D  3A 06 8514        cmp al,[1485]
C000:0E71  75 ED             jnz C000:0E60   ; key pressed -> CF=0
C000:0E73  F9                stc             ; clear -> CF=1
C000:0E74  C3                ret
```

## C000:0303 — reinit_app_with_swap

; file 0xC0303

Saves and restores framebuffer around `DEF0:5B03` call:

```asm
C000:0303  C6 06 D816 01     mov byte [16D8],1
C000:0308  A1 6714           mov ax,[1467]
C000:030B  A3 D616           mov [16D6],ax
C000:030E  E8 5806           call C000:0969  ; -> framebuffer_save
C000:0311  06                push es
C000:0312  9A 035B F0DE      call far DEF0:5B03
C000:0317  07                pop es
C000:0318  E8 5906           call C000:0974  ; -> framebuffer_restore
C000:031B  A1 D616           mov ax,[16D6]
C000:031E  A3 6714           mov [1467],ax
C000:0321  C6 06 D816 00     mov byte [16D8],0
C000:0326  C3                ret
```

## C000:09D4 — cold_banner

; file 0xC09D4

Renders a display script from `C772:EDB0` (the "INITIALIZING" banner)
and delays:

```asm
C000:09D4  BE B0ED           mov si,EDB0
C000:09D7  B9 1800           mov cx,18
C000:09DA  BA 72C7           mov dx,C772
C000:09DD  E8 775B           call C000:6557  ; -> render_display_script
C000:09E0  BB 7405           mov bx,574
C000:09E3  B9 6400           mov cx,64
C000:09E6  E8 4701           call C000:0B30  ; -> timed_delay
C000:09E9  C3                ret
```

## C000:09EA — cold_early_init

; file 0xC09EA

Delays called during early cold start:

```asm
C000:09EA  BB 9806           mov bx,698
C000:09ED  B9 0C00           mov cx,C
C000:09F0  E8 3D01           call C000:0B30  ; -> timed_delay
C000:09F3  BB 2601           mov bx,126
C000:09F6  B9 0C00           mov cx,C
C000:09F9  E8 3401           call C000:0B30  ; -> timed_delay
C000:09FC  C3                ret
```

## C000:09CE — nmi_recovery_init

; file 0xC09CE

Called when `[1473]==0x4D0` (previous NMI):

```asm
C000:09CE  B0 04             mov al,4
C000:09D0  E8 F203           call C000:0DC5  ; -> display_helper
C000:09D3  C3                ret
```

## C000:0571 — ram_checksum_init

; file 0xC0571

Computes a checksum over 0x7FFC words starting at `1800:0008` and stores
the result at `1800:0006`:

```asm
C000:0571  1E                push ds
C000:0572  B8 0018           mov ax,1800
C000:0575  8E D8             mov ds,ax
C000:0577  E8 1A00           call C000:0594  ; -> ram_checksum_compute
C000:057A  89 1E 0600        mov [6],bx      ; store checksum
C000:057E  1F                pop ds
C000:057F  C3                ret
```

### C000:0594 — ram_checksum_compute

```asm
C000:0594  BE 0800           mov si,8
C000:0597  B9 FC7F           mov cx,7FFC
C000:059A  FC                cld
C000:059B  33 DB             xor bx,bx
C000:059D  AD                lodsw
C000:059E  03 D8             add bx,ax
C000:05A0  E2 FB             loop C000:059D
C000:05A2  C3                ret
```

## C000:0AA0 — battery_check

; file 0xC0AA0

Calls C000:14D4 and sets `[146F]=0x1995` on failure:

```asm
C000:0AA0  E8 310A           call C000:14D4
C000:0AA3  72 01             jc C000:0AA6
C000:0AA5  C3                ret             ; OK -> return CF=0
C000:0AA6  C7 06 6F14 9519   mov word [146F],1995
C000:0AAC  C3                ret             ; fail -> return CF=1 (from 14D4)
```

## C000:131D — diagnostic_monitor

; file 0xC131D

The diagnostic command loop. Reached via the banked spell thunk dispatch
table (slot 7 in the table at C000:1B38), not by direct call.

```asm
C000:131D  C6 06 A215 01     mov byte [15A2],1
C000:1322  E8 D000           call C000:13F5  ; -> diagnostic_banner_render
C000:1325  EB 1A             jmp short C000:1341 ; -> command_loop
```

### C000:1341 — command_loop

```asm
C000:1341  E8 241E           call C000:3168  ; -> poll_keyboard
C000:1344  0A C0             or al,al
C000:1346  74 5A             jz C000:13A2    ; no key -> idle_check
C000:1348  E8 1EF7           call C000:0A69  ; -> process_key
C000:134B  3C 0B             cmp al,0B       ; EXIT key?
C000:134D  74 76             jz C000:13C5    ; -> exit_diagnostic
C000:134F  3C 03             cmp al,03       ; CANCEL?
C000:0351  74 72             jz C000:13C5    ; -> exit_diagnostic
C000:1353  3C 14             cmp al,14
C000:1355  74 D0             jz C000:1327    ; -> set [1446] bit 0
C000:1357  3C 15             cmp al,15
C000:1359  74 D3             jz C000:132E    ; -> clear [1446] bit 0
C000:135B  3C 17             cmp al,17
C000:135D  74 D6             jz C000:1335    ; -> set [1446] bit 1
C000:135F  3C 16             cmp al,16
C000:1361  74 D9             jz C000:133C    ; -> clear [1446] bit 1
```

If not a control key, looks up the key in the command dispatch table at
C000:1378:

```asm
C000:1363  BE 7813           mov si,1378     ; command table
C000:1366  2E 8B14           mov dx,[cs:si]  ; DL=key, DH=handler_id
C000:1369  80 FA 00          cmp dl,0
C000:136C  74 1A             jz C000:1388    ; end of table -> check_address
C000:136E  46                inc si
C000:136F  46                inc si
C000:1370  3A C2             cmp al,dl
C000:1372  75 F2             jnz C000:1366   ; no match -> next entry
C000:1374  8A C6             mov al,dh       ; matched: AL = handler_id
C000:1376  EB 21             jmp short C000:1399 ; -> dispatch_handler
```

### Command Table at C000:1378

```text
C000:1378  08 08  11 08  09 09  12 0A  13 0B  10 0C  DA 0D  00
```

| Key code | Handler ID | Probable command |
| ---: | ---: | --- |
| `0x08` | `0x08` | |
| `0x11` | `0x08` | |
| `0x09` | `0x09` | |
| `0x12` | `0x0A` | |
| `0x13` | `0x0B` | |
| `0x10` | `0x0C` | |
| `0xDA` | `0x0D` | |

### C000:1388 — check_address_input

If no command matched, checks for address-entry characters:

```asm
C000:1388  3C EC             cmp al,EC
C000:138A  74 0A             jz C000:1396    ; -> use_saved_char
C000:138C  3C 20             cmp al,20       ; space?
C000:138E  72 12             jc C000:13A2    ; below space -> idle
C000:1390  3C C0             cmp al,C0
C000:1392  73 0E             jnc C000:13A2   ; >= C0 -> idle
C000:1394  EB 03             jmp short C000:1399 ; -> dispatch_handler
C000:1396  A0 9814           mov al,[1498]   ; load saved char
C000:1399  E8 3400           call C000:13D0  ; -> echo/process character
C000:139C  8A D0             mov dl,al
C000:139E  B4 04             mov ah,04
C000:13A0  CD 21             int 21h         ; AH=04 aux output
```

### C000:13A2 — idle_check

```asm
C000:13A2  E8 911F           call C000:3336  ; -> system_idle_tick
C000:13A5  F6 06 9316 02     test byte [1693],02
C000:13AA  75 95             jnz C000:1341   ; -> command_loop
C000:13AC  E8 2E00           call C000:13DD  ; -> serial_poll
C000:13AF  81 3E 0911 9219   cmp word [1109],1992
C000:13B5  74 8A             jz C000:1341    ; -> command_loop
C000:13B7  FA                cli
C000:13B8  A0 D016           mov al,[16D0]
C000:13BB  3A 06 D116        cmp al,[16D1]
C000:13BF  FB                sti
C000:13C0  74 E0             jz C000:13A2    ; no serial data -> idle
C000:13C2  E9 7CFF           jmp C000:1341   ; serial data -> command_loop
```

### C000:13C5 — exit_diagnostic

```asm
C000:13C5  50                push ax
C000:13C6  E8 E7FB           call C000:0FB0  ; -> cleanup
C000:13C9  58                pop ax
C000:13CA  C6 06 A215 00     mov byte [15A2],0
C000:13CF  C3                ret
```

## C000:13F5 — diagnostic_banner_render

; file 0xC13F5

Renders the diagnostic terminal banner from `C000:76F5`:

```asm
C000:13F5  9A 0B00 F0DE      call far DEF0:000B  ; display init
C000:13FA  E8 72FB           call C000:0F6F  ; -> lcd_clear
C000:13FD  C6 06 4514 01     mov byte [1445],1
C000:1402  BE F576           mov si,76F5     ; banner source
C000:1405  B9 2F00           mov cx,2F       ; 47 bytes
C000:1408  E8 7305           call C000:197E  ; -> copy_and_render
C000:140B  B8 0000           mov ax,0
C000:140E  BB 0100           mov bx,1
C000:1411  9A 2700 F0DE      call far DEF0:0027
C000:1416  B8 0100           mov ax,1
C000:1419  9A 1900 F0DE      call far DEF0:0019
C000:141E  C3                ret
```

The banner at `C000:76F5` (file `0xC76F5`) begins with display-script
control bytes followed by `"Terminal mode   press "` etc.

## C000:1420 — software_error_halt

; file 0xC1420

NOT the diagnostic monitor. This is an unrecoverable error handler that
displays "Internal software error. Please reset this computer and contact
NTS." and halts:

```asm
C000:1420  8C C8             mov ax,cs
C000:1422  A3 6914           mov [1469],ax
C000:1425  A3 7914           mov [1479],ax
C000:1428  A1 6714           mov ax,[1467]
C000:142B  A3 7714           mov [1477],ax
C000:142E  C7 06 0911 9919   mov word [1109],1999
C000:1434  E8 3AF1           call C000:0571  ; -> ram_checksum_init
C000:1437  BE 5014           mov si,1450
C000:143A  BA 00C0           mov dx,C000
C000:143D  B9 5F00           mov cx,5F
C000:1440  90                nop
C000:1441  E8 1351           call C000:6557  ; -> render_display_script
C000:1444  80 0E 3C14 01     or byte [143C],01
C000:1449  B0 7E             mov al,7E
C000:144B  E6 60             out 60,al
C000:144D  FB                sti
C000:144E  EB FE             jmp short C000:144E ; HALT
```

Display script at C000:1450 (file 0xC1450) reads:
`"Internal software error. Please reset this computer and contact NTS."`

## Low-RAM State Map

| Address | Size | Purpose |
| --- | --- | --- |
| `[1000..1004]` | 5 | Warm-RAM signature (`"218"` + secondary byte) |
| `[1005]` | 1 | Store type marker (set to `0x48`) |
| `[1109]` | 2 | Startup state: `0x0001` early, `0x0000` normal, `0x1995` battery, `0x1992` diagnostic, `0x1999` error |
| `[1439]` | 1 | Diagnostic flag: set by chord detection, persists across power cycles |
| `[143A]` | 1 | Interrupt mask shadow (port 0x60) |
| `[143C]` | 1 | Bit 0 = warm-retry flag |
| `[1446]` | 1 | Diagnostic mode flags (bits 0-1) |
| `[1453..1470]` | 30 | Saved register context (AX,BX,CX,DX,SI,DI,BP,DS,ES,SS,IP,CS,FLAGS,SP) |
| `[1471]` | 2 | Context checksum |
| `[1473]` | 2 | NMI source marker (`0x04D0` if NMI, `0x0000` otherwise) |
| `[1467]` | 2 | Saved IP / application state word |
| `[1469]` | 2 | Saved CS |
| `[146B]` | 2 | Saved SP |
| `[146F]` | 2 | Warm-resume state: `0x0000` normal, `0x1995` battery, `0x1997` warm ok |
| `[147B..147F]` | 5 | Bank port mirror (ports 0x11-0x15 defaults) |
| `[1482]` | 1 | Port 0x30 shadow |
| `[1484..1490]` | 13 | Keyboard matrix scan buffer (ports 0xD0-0xDC) |
| `[142C..1436]` | 11 | Primary chord pattern (compared against scan) |
| `[1430..1436]` | 7 | Secondary chord pattern |
| `[15A2]` | 1 | Diagnostic monitor active flag |

## Boot Flow Summary

```text
FFFF:0000 reset
  -> F6E3:0000 trampoline (set bank ports)
    -> C000:0000 entry
      -> C000:0029 hardware init
        -> C000:1161 install IVT + far-call table
        -> signature check [1000..1004] vs CS:7799
          MATCH:
            -> C000:00EC restore bank ports from mirrors
            -> C000:0107 common init tail
              -> C000:2E2D warm state validate
                FAIL (CF=1):
                  -> C000:018A cold reinit
                    -> ... subsystem init ...
                    -> C000:12CC install vectors
                    -> DEF0:5B03 app init
                    -> JMP FAR C772:0004 (APPLICATION)
                PASS (CF=0):
                  warm-retry flag set?
                    YES: -> C000:01DF warm resume
                      -> C000:03EA restore context
                      -> C000:0AA0 battery check
                      -> ... -> JMP FAR C772:0008 (APPLICATION)
                    NO: -> C000:0148 resume check
                      [146F] nonzero? -> C000:01DF warm resume
                      [146F] zero? -> C000:0220 diagnostic gate
                        -> C000:12CC install vectors
                        -> C000:0987 chord check and init
                          -> C000:08AA chord gate
                            [1439] set? -> C000:0953 wait for release
                            chord held? -> C000:048C power down + set [1439]
                            no chord? -> C000:08D3 normal startup init
                              -> render 9 display script blocks (copyright/banner)
                        -> C000:0AA0 battery check
                        -> C000:02A3 context checksum verify
                        -> restore context + JMP FAR [ss:1467] (RESUME)
          NO MATCH:
            -> C000:0085 stamp signature into RAM
            -> C000:0096 cold start init
              -> C000:09EA early delays
              -> C000:0327 seed bank mirrors
              -> C000:03BB hardware setup
              -> C000:6523 INT 21h services init
              -> C000:4396 store validate
              -> C000:0571 RAM checksum init
              -> C000:2E72 subsystem init
              -> DEF0:5C07 app subsystem init
              -> C000:03A5 keyboard scan start
              -> C000:5600 file table init
              -> [146F] = 0x1995, warm-retry = 1
              -> C000:0107 common init tail (continues above)
```
