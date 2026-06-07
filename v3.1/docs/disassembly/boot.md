# Boot Disassembly

Depth-first annotation from reset through cold/warm startup paths.
See [`../map.md`](../map.md) for the address model and banking layout.

Differences from the v2.1 boot path are noted inline.

## Reset Vector

; file 0xFFFF0 (v2.1: file 0x7FFF0)

```asm
FFFF:0000  FA                cli
FFFF:0001  EA 0000 E3F6      jmp far F6E3:0000
```

Identical structure to v2.1; only the trampoline segment differs
(v2.1 jumps to `F8DC:0000`).

## Reset Trampoline

; file 0xF6E30 (v2.1: file 0x78DC0)

```asm
F6E3:0000  FA                cli
F6E3:0001  B0 01             mov al,01
F6E3:0003  E6 16             out 16,al       ; CPU C0000..DFFFF -> ROM bank 14
F6E3:0005  B0 00             mov al,00
F6E3:0007  E6 17             out 17,al       ; CPU E0000..FFFFF -> ROM bank 15
F6E3:0009  EA 0000 00C0      jmp far C000:0000
```

Port values are identical to v2.1. For the 1 MiB ROM, bank 14 maps to file
`0xC0000` and bank 15 to file `0xE0000`. Followed by `0xFF` padding to the
next boundary.

## C000:0000 — Entry and Jump Table

; file 0xC0000

```asm
C000:0000  EB 27             jmp short C000:0029
C000:0002  00 00             ; padding
C000:0004  00 00             ; padding
C000:0006  E9 6E62           jmp C000:6277      ; INT 21h dispatch
C000:0009  E9 C404           jmp C000:04D0      ; IRQ stub (F8)
C000:000C  E9 B105           jmp C000:05C0      ; IRQ stub (F9)
C000:000F  E9 C205           jmp C000:05D4      ; IRQ stub (FA)
C000:0012  E9 E205           jmp C000:05F7      ; IRQ stub (FB)
C000:0015  E9 5E06           jmp C000:0676      ; IRQ stub (FC)
C000:0018  E9 2F08           jmp C000:084A      ; IRQ stub (FD)
C000:001B  E9 4008           jmp C000:085E      ; IRQ stub (FE)
C000:001E  E9 DB03           jmp C000:03FC      ; IRQ stub (FF)
C000:0021  E8 A719           call C000:19CB      ; banked spell thunk entry
C000:0024  CB                retf
C000:0025  E8 001B           call C000:1B28      ; banked spell thunk entry (alt)
C000:0028  CB                retf
```

Same structure as v2.1. The INT 21h dispatch target differs
(v2.1: `C000:5098`, v3.1: `C000:6277`).

## C000:0029 — Hardware Init and Bank Setup

; file 0xC0029

```asm
C000:0029  FA                cli
C000:002A  B0 17             mov al,17
C000:002C  E6 10             out 10,al       ; window 0 -> RAM
C000:002E  B0 01             mov al,01
C000:0030  E6 16             out 16,al       ; window 6 -> ROM file C0000
C000:0032  B0 00             mov al,00
C000:0034  E6 17             out 17,al       ; window 7 -> ROM file E0000
C000:0036  B8 0000           mov ax,0000
C000:0039  8E D0             mov ss,ax
C000:003B  8E D8             mov ds,ax
C000:003D  8E C0             mov es,ax
C000:003F  B0 FF             mov al,ff
C000:0041  E6 90             out 90,al       ; LCD-related
C000:0043  A2 3A14           mov [143A],al
C000:0046  B0 00             mov al,00
C000:0048  E6 20             out 20,al       ; keyboard
C000:004A  B0 40             mov al,40
C000:004C  E6 00             out 00,al       ; LCD base
C000:004E  B0 F0             mov al,f0
C000:0050  E6 DE             out de,al       ; RTC
C000:0052  B0 F8             mov al,f8
C000:0054  E6 DD             out dd,al       ; RTC
C000:0056  B0 5F             mov al,5f
C000:0058  A2 8214           mov [1482],al
C000:005B  B0 FF             mov al,ff
C000:005D  E6 40             out 40,al       ; serial
C000:005F  BC 006F           mov sp,6F00     ; temporary stack
```

Nearly identical to v2.1's `C000:0029` sequence. The port writes are the same;
low-RAM addresses differ slightly (`[143A]` vs v2.1's `[6818]` etc.).

## C000:0062 — Warm-RAM Signature Check

; file 0xC0062

```asm
C000:0062  E8 FC10           call C000:1161      ; early hardware init
C000:0065  BE 9977           mov si,7799         ; signature source in ROM
C000:0068  BF 0010           mov di,1000         ; check location in RAM
C000:006B  B9 0400           mov cx,4            ; 4 bytes
C000:006E  2E 8A04           mov al,[cs:si]      ; read ROM byte
C000:0071  3A 05             cmp al,[di]          ; compare with RAM
C000:0073  75 10             jnz C000:0085        ; mismatch -> cold path
C000:0075  46                inc si
C000:0076  47                inc di
C000:0077  E2 F5             loop C000:006E
```

Checks 4 bytes at RAM `[1000]` against the ROM signature at `C000:7799`. The
signature bytes are `32 31 38 20` = ASCII `"218 "` (v2.1 uses `"047 "` at
`C000:6963`).

If the signature matches, a secondary single-byte check follows:

```asm
C000:0079  BE CF64           mov si,64CF
C000:007C  2E 8A04           mov al,[cs:si]
C000:007F  3A 05             cmp al,[di]          ; [1004]
C000:0081  75 0B             jnz C000:008E        ; -> cold (with secondary stamp)
C000:0083  EB 67             jmp short C000:00EC  ; -> warm path
```

### Cold Path (signature mismatch)

```asm
C000:0085  2E 8A04           mov al,[cs:si]      ; stamp remaining sig bytes
C000:0088  88 05             mov [di],al
C000:008A  46                inc si
C000:008B  47                inc di
C000:008C  E2 F7             loop C000:0085
C000:008E  BE CF64           mov si,64CF         ; stamp secondary byte
C000:0091  2E 8A04           mov al,[cs:si]
C000:0094  88 05             mov [di],al
C000:0096  E8 5109           call C000:09EA      ; cold-start init
C000:0099  E8 8B02           call C000:0327      ; seed bank mirrors
C000:009C  A1 7B14           mov ax,[147B]       ; restore ports 11/12
C000:009F  86 C4             xchg ah,al
C000:00A1  E6 11             out 11,al
C000:00A3  8A C4             mov al,ah
C000:00A5  E6 12             out 12,al
C000:00A7  A1 7D14           mov ax,[147D]       ; restore ports 13/14
C000:00AA  86 C4             xchg ah,al
C000:00AC  E6 13             out 13,al
C000:00AE  8A C4             mov al,ah
C000:00B0  E6 14             out 14,al
C000:00B2  A0 7F14           mov al,[147F]       ; restore port 15
C000:00B5  E6 15             out 15,al
C000:00B7  E8 0103           call C000:03BB      ; hardware setup
C000:00BA  E8 6664           call C000:6523      ; INT 21h services init
C000:00BD  E8 6702           call C000:0327      ; seed bank mirrors (again)
C000:00C0  C6 06 0510 48     mov byte [1005],48  ; store type marker
C000:00C5  B3 A5             mov bl,A5
C000:00C7  B2 08             mov dl,08
C000:00C9  B4 FF             mov ah,FF
C000:00CB  E8 C842           call C000:4396      ; built-in store validate
C000:00CE  E8 A004           call C000:0571      ; subsystem init
C000:00D1  E8 9E2D           call C000:2E72      ; organizer/menu init
C000:00D4  9A 075C F0DE      call DEF0:5C07      ; far: app subsystem init
C000:00D9  E8 C902           call C000:03A5      ; keyboard scan start
C000:00DC  E8 2155           call C000:5600      ; file table init
C000:00DF  80 0E 3C14 01     or byte [143C],01   ; set warm-retry flag
C000:00E4  C7 06 6F14 9519   mov word [146F],1995 ; state = battery warning
C000:00EA  EB 1B             jmp short C000:0107  ; -> common init tail
```

### Warm Path (signature matched)

```asm
C000:00EC  A1 7B14           mov ax,[147B]       ; restore ports 11-15
C000:00EF  86 C4             xchg ah,al          ; from saved bank mirrors
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

Falls through to common init tail at `C000:0107`.

## C000:0107 — Common Init Tail

; file 0xC0107

```asm
C000:0107  33 C0             xor ax,ax
C000:0109  A2 D516           mov [16D5],al       ; clear state bytes
C000:010C  A2 3E14           mov [143E],al
C000:010F  A2 3F14           mov [143F],al
C000:0112  A2 4014           mov [1440],al
C000:0115  A2 E26F           mov [6FE2],al
C000:0118  A3 9314           mov [1493],ax
C000:011B  A2 D816           mov [16D8],al
C000:011E  40                inc ax
C000:011F  A3 0911           mov [1109],ax       ; startup state = 1
C000:0122  C6 06 0510 48     mov byte [1005],48
C000:0127  81 3E 7314 D004   cmp word [1473],04D0
C000:012D  75 03             jnz C000:0132
C000:012F  E8 9C08           call C000:09CE
C000:0132  E8 F82C           call C000:2E2D      ; warm-state validation
C000:0135  72 53             jc C000:018A         ; CF=1 -> cold reinit
```

## C000:0137 — Warm/Cold Decision

; file 0xC0137

```asm
C000:0137  F6 06 3C14 01     test byte [143C],01  ; warm-retry flag?
C000:013C  9C                pushf
C000:013D  80 26 3C14 FE     and byte [143C],FE   ; clear flag
C000:0142  9D                popf
C000:0143  74 03             jz C000:0148          ; not set -> check resume
C000:0145  E9 9700           jmp C000:01DF         ; -> warm resume path
```

If not a warm retry, checks `[1467]` for known application states:

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
```

Known state values: `0x0000`, `0x320D`, `0x30E7`, `0x316D`.

## C000:016C — Resume Validation

```asm
C000:016C  8B D8             mov bx,ax
C000:016E  8C C8             mov ax,cs
C000:0170  3B 06 6914        cmp ax,[1469]        ; saved segment == CS?
C000:0174  75 14             jnz C000:018A         ; no -> cold reinit
C000:0176  0B DB             or bx,bx
C000:0178  75 06             jnz C000:0180
C000:017A  C7 06 6F14 9519   mov word [146F],1995  ; mark battery warning
C000:0180  A1 6F14           mov ax,[146F]
C000:0183  0B C0             or ax,ax
C000:0185  75 58             jnz C000:01DF         ; nonzero -> warm resume
C000:0187  E9 9600           jmp C000:0220         ; -> diagnostic gate?
```

## C000:018A — Cold Reinit

; file 0xC018A

```asm
C000:018A  E8 4708           call C000:09D4
C000:018D  C7 06 6F14 0000   mov word [146F],0000  ; clear state marker
C000:0193  B0 FF             mov al,FF
C000:0195  E6 60             out 60,al
C000:0197  A2 3A14           mov [143A],al
C000:019A  E8 8A01           call C000:0327        ; seed bank mirrors
C000:019D  E8 1B02           call C000:03BB        ; hardware setup
C000:01A0  B0 FF             mov al,FF
C000:01A2  A2 3A14           mov [143A],al
C000:01A5  E8 7B63           call C000:6523        ; INT 21h init
C000:01A8  E8 C72C           call C000:2E72        ; organizer/menu init
C000:01AB  9A 075C F0DE      call DEF0:5C07        ; far: app subsystem init
C000:01B0  E8 F201           call C000:03A5        ; keyboard scan start
C000:01B3  BC 0010           mov sp,1000           ; final stack pointer
C000:01B6  B8 EF0C           mov ax,0CEF
C000:01B9  8E C0             mov es,ax
C000:01BB  E8 4254           call C000:5600        ; file table init
C000:01BE  E8 0B11           call C000:12CC        ; install interrupt vectors
C000:01C1  FB                sti
C000:01C2  06                push es
C000:01C3  9A 035B F0DE      call DEF0:5B03        ; far: app init
C000:01C8  07                pop es
C000:01C9  B8 EF0C           mov ax,0CEF
C000:01CC  8E C0             mov es,ax
C000:01CE  C7 06 6F14 0000   mov word [146F],0000
C000:01D4  C7 06 0911 0000   mov word [1109],0000
C000:01DA  EA 0400 72C7      jmp far C772:0004     ; -> application entry
```

The cold path ends with `JMP FAR C772:0004`, entering the application runtime
(v2.1 uses `C688:000B`).

## C000:01DF — Warm Resume

```asm
C000:01DF  E8 D007           call C000:09B2
C000:01E2  E8 4201           call C000:0327        ; seed bank mirrors
C000:01E5  BC 0010           mov sp,1000
C000:01E8  B8 EF0C           mov ax,0CEF
C000:01EB  8E C0             mov es,ax
C000:01ED  E8 DC10           call C000:12CC        ; install vectors
C000:01F0  FB                sti
C000:01F1  06                push es
C000:01F2  E8 F501           call C000:03EA        ; resume context
C000:01F5  07                pop es
C000:01F6  E8 A708           call C000:0AA0        ; post-resume check
C000:01F9  81 3E 6F14 9519   cmp word [146F],1995
C000:01FF  74 C1             jz C000:01C2          ; battery warning -> app init
C000:0201  E8 FC53           call C000:5600
C000:0204  E8 FC00           call C000:0303
C000:0207  81 3E 6F14 9719   cmp word [146F],1997
C000:020D  74 BA             jz C000:01C9          ; 1997 marker -> app init
C000:020F  C7 06 6F14 0000   mov word [146F],0000
C000:0215  C7 06 0911 0000   mov word [1109],0000
C000:021B  EA 0400 72C7      jmp far C772:0004     ; -> application entry
```

Both the warm resume and cold paths eventually reach `C772:0004`.

## Key Differences From v2.1

| Element | v2.1 | v3.1 |
| --- | --- | --- |
| Trampoline segment | `F8DC` | `F6E3` |
| C000 file base | `0x40000` | `0xC0000` |
| INT 21h dispatch | `C000:5098` | `C000:6277` |
| Bank seed routine | `C000:0225` | `C000:0327` |
| Port 0x11 default | `0x0E` | `0x0F` |
| Early hw init call | `C000:0F94` | `C000:1161` |
| Warm-RAM signature | `"047"` at `C000:6963` | `"218"` at `C000:7799` |
| Secondary sig byte | at `C000:5AB2` | at `C000:64CF` |
| Cold-start init | `C000:09EA` (approx) | `C000:09EA` |
| INT 21h services | `C000:50C2` | `C000:6523` |
| Vector install | `C000:0ED6` | `C000:12CC` |
| Store validate | `C000:4811` | `C000:4396` |
| App subsystem far | `DEF0:5C07` | `DEF0:5C07` (same!) |
| App init far | `DEF0:5B03` | `DEF0:5B03` (same!) |
| File table init | `C000:4CEF` | `C000:5600` |
| App entry | `C688:000B` | `C772:0004` |
| State marker | `[6809]` | `[146F]` |
| Startup state word | `[6809]` | `[1109]` |
| Warm-retry flag | `[6D51] bit 0` | `[143C] bit 0` |
| Stack pointer | `0x1000` | `0x1000` (same) |
| ES segment | `0x0CEF` | `0x0CEF` (same!) |
| Diagnostic banner | `"21BAB047"` | `"31BAB218"` |

The far-call targets `DEF0:5C07` and `DEF0:5B03` are identical between
versions. The `ES` segment `0x0CEF` is also shared. These suggest the
`DEF0` code segment may be at the same ROM file location in both images,
or at least occupies the same CPU window position.
