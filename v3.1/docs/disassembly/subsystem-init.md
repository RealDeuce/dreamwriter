# Subsystem Init Routines

Low-level init routines called from the boot path. Each was traced from
the full recursive boot disassembly.

## C000:0327 — Seed Bank Mirrors

Writes default bank port values for the 1 MiB ROM into `[147B..147F]`.
These are restored to ports `0x11..0x15` after context resume or cold
init. See [`../map.md`](../map.md) for the banking model.

```asm
; file 0xC0327
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

## C000:03A5 — Clear High-RAM Area

Clears 0x400 bytes at `[AAFB..AEFA]` to zero. This region is in
the application state area above the file handle table `[A022..A342]`
— it holds display subsystem workspace used by `DEF0:A718` and the
display configuration routines.

```asm
; file 0xC03A5
C000:03A5  B9 6400           mov cx,64
C000:03A8  D1 E1             shl cx,1        ; CX = 0xC8
C000:03AA  81 C1 3603        add cx,336      ; CX = 0x3FE
C000:03AE  83 C1 02          add cx,2        ; CX = 0x400
C000:03B1  BF FBAA           mov di,AAFB
C000:03B4  C6 05 00          mov byte [di],0
C000:03B7  47                inc di
C000:03B8  E2 FA             loop C000:03B4
C000:03BA  C3                ret
```

## C000:03BB — Clear RAM

Clears `[1006..CEEE]` to zero, deliberately skipping `[6D00..6F00]`
(which contains keyboard state, power state, and other retained data
populated by MAME's `sample_keyboard_rows()` at `[6D06..6D0F]`). Then
fills `[0400..0FFE]` with `0x73`.

```asm
; file 0xC03BB
C000:03BB  32 C0             xor al,al       ; AL = 0
C000:03BD  B9 EFCE           mov cx,CEEF
C000:03C0  BF 0610           mov di,1006     ; start
C000:03C3  2B CF             sub cx,di       ; CX = CEEF - 1006 = BEE9
C000:03C5  BB 006D           mov bx,6D00     ; skip range start
C000:03C8  BA 006F           mov dx,6F00     ; skip range end
C000:03CB  3B FB             cmp di,bx
C000:03CD  72 06             jc C000:03D5    ; below skip range -> clear
C000:03CF  3B FA             cmp di,dx
C000:03D1  77 02             ja C000:03D5    ; above skip range -> clear
C000:03D3  EB 02             jmp short C000:03D7 ; in skip range -> skip
C000:03D5  88 05             mov [di],al     ; store zero
C000:03D7  47                inc di
C000:03D8  E2 F1             loop C000:03CB
C000:03DA  50                push ax
C000:03DB  B0 73             mov al,73       ; fill value
C000:03DD  BF 0004           mov di,400
C000:03E0  B9 000C           mov cx,C00      ; (overwritten next)
C000:03E3  B9 FF0B           mov cx,BFF      ; CX = 0xBFF
C000:03E6  F3 AA             rep stosb       ; fill [0400..0FFE] with 0x73
```

The `0x73` fill pattern at `[0400..0FFE]` fills the low-RAM area
below the signature check region `[1000..1004]`. This is the
far-call table area (`[0200..029C]`) and surrounding workspace.
The non-zero fill value `0x73` serves as a sentinel — any entry
that still contains `0x73` after IVT installation was never
written, allowing detection of uninitialized table slots.

## C000:03EA — Clear Framebuffer

Fills `[8000..8FFF]` with zero via `REP STOSW`. Called from the warm
resume path at `C000:01F2`.

```asm
; file 0xC03EA
C000:03EA  B8 0000           mov ax,0
C000:03ED  8E C0             mov es,ax
C000:03EF  B9 0008           mov cx,800      ; 2048 words = 4 KiB
C000:03F2  BF 0080           mov di,8000
C000:03F5  B8 0000           mov ax,0
C000:03F8  FC                cld
C000:03F9  F3 AB             rep stosw
C000:03FB  C3                ret
```

## C000:0303 — Call DEF0:5B03 With Framebuffer Save/Restore

Saves the framebuffer to `[9000]`, calls `DEF0:5B03`, restores the
framebuffer, and preserves `[1467]` across the call.

```asm
; file 0xC0303
C000:0303  C6 06 D816 01     mov byte [16D8],1
C000:0308  A1 6714           mov ax,[1467]
C000:030B  A3 D616           mov [16D6],ax
C000:030E  E8 5806           call C000:0969  ; save [8000]->[9000]
C000:0311  06                push es
C000:0312  9A 035B F0DE      call far DEF0:5B03
C000:0317  07                pop es
C000:0318  E8 5906           call C000:0974  ; restore [9000]->[8000]
C000:031B  A1 D616           mov ax,[16D6]
C000:031E  A3 6714           mov [1467],ax
C000:0321  C6 06 D816 00     mov byte [16D8],0
C000:0326  C3                ret
```

## C000:0571 — RAM Checksum Init

Checksums 0x7FFC words at `1800:0008` and stores the result at
`1800:0006`.

```asm
; file 0xC0571
C000:0571  1E                push ds
C000:0572  B8 0018           mov ax,1800
C000:0575  8E D8             mov ds,ax
C000:0577  E8 1A00           call C000:0594
C000:057A  89 1E 0600        mov [6],bx      ; store checksum
C000:057E  1F                pop ds
C000:057F  C3                ret
```

### C000:0594 — RAM Checksum Compute

```asm
; file 0xC0594
C000:0594  BE 0800           mov si,8
C000:0597  B9 FC7F           mov cx,7FFC     ; ~32K words
C000:059A  FC                cld
C000:059B  33 DB             xor bx,bx
C000:059D  AD                lodsw
C000:059E  03 D8             add bx,ax
C000:05A0  E2 FB             loop C000:059D
C000:05A2  C3                ret
```

## C000:5600 — Clear File Handles

Fills `[6F5E..6F61]` with `0xFF` (4 bytes). Marks file handles as
unused.

```asm
; file 0xC5600
C000:5600  06                push es
C000:5601  8C D9             mov cx,ds
C000:5603  8E C1             mov es,cx
C000:5605  BF 5E6F           mov di,6F5E
C000:5608  B9 0400           mov cx,4
C000:560B  B0 FF             mov al,FF
C000:560D  FC                cld
C000:560E  F3 AA             rep stosb
C000:5610  07                pop es
C000:5611  C3                ret
```

## C000:6523 — Init Drive/File State

Sets up drive/file state words. Called during cold init and cold reinit.

```asm
; file 0xC6523
C000:6523  06                push es
C000:6524  BD 0000           mov bp,0
C000:6527  8E C5             mov es,bp
C000:6529  B0 06             mov al,6
C000:652B  A2 E616           mov [16E6],al   ; default drive = 6
C000:652E  A2 E516           mov [16E5],al
C000:6531  E8 7307           call C000:6CA7
C000:6534  E8 BF06           call C000:6BF6
C000:6537  C6 06 3B17 00     mov byte [173B],0
C000:653C  C6 06 2817 00     mov byte [1728],0
C000:6541  C7 06 DF16 0800   mov word [16DF],8
C000:6547  C7 06 DD16 0700   mov word [16DD],7
C000:654D  C7 06 9F18 0080   mov word [189F],8000
C000:6553  07                pop es
C000:6554  C3                ret
```

## C000:4396 — Storage Endpoint Dispatch

Dispatches on BL and DL. During boot, called with BL=`0xA5` and
DL=`0x08` (built-in storage endpoint).

```asm
; file 0xC4396
C000:4396  C6 06 E26F 01     mov byte [6FE2],1
C000:439B  88 16 516F        mov [6F51],dl   ; store endpoint number
C000:439F  80 FB A5          cmp bl,A5
C000:43A2  75 45             jnz C000:43E9   ; BL != A5 -> alternate path
C000:43A4  80 FA 08          cmp dl,8
C000:43A7  74 43             jz C000:43EC    ; DL=8 -> built-in storage
C000:43A9  80 FA 09          cmp dl,9
C000:43AC  74 1F             jz C000:43CD    ; DL=9 -> PCMCIA storage
C000:43AE  80 FA 0B          cmp dl,B
C000:43B1  74 C2             jz C000:4375    ; DL=B
C000:43B3  80 FA 0A          cmp dl,A
C000:43B6  75 0E             jnz C000:43C6   ; DL=A -> DreamLink?
                                              ; other DL values -> ...
```

(Remainder of dispatch follows; only the entry point and initial
dispatch are shown here.)

## C000:2E2D — Validate Stored State

Checks `[1337]` against `0x7CE` and `[1106]` against values 8/9/A/B.
Calls four subroutines. Returns CF=1 if validation fails, CF=0 if
the stored state is valid for a warm resume.

```asm
; file 0xC2E2D
C000:2E2D  81 3E 3713 CE07   cmp word [1337],7CE
C000:2E33  75 21             jnz C000:2E56   ; mismatch -> set fail flag
C000:2E35  C6 06 4114 00     mov byte [1441],0
C000:2E3A  80 3E 0611 08     cmp byte [1106],8
C000:2E3F  74 1A             jz C000:2E5B    ; endpoint 8 -> validate
C000:2E41  80 3E 0611 09     cmp byte [1106],9
C000:2E46  74 13             jz C000:2E5B    ; endpoint 9 -> validate
C000:2E48  80 3E 0611 0A     cmp byte [1106],A
C000:2E4D  74 0C             jz C000:2E5B
C000:2E4F  80 3E 0611 0B     cmp byte [1106],B
C000:2E54  74 05             jz C000:2E5B
C000:2E56  80 0E 4114 01     or byte [1441],1  ; set fail flag
C000:2E5B  E8 9A00           call C000:2EF8
C000:2E5E  E8 F300           call C000:2F54
C000:2E61  E8 3201           call C000:2F96
C000:2E64  E8 5901           call C000:2FC0
C000:2E67  80 3E 4114 00     cmp byte [1441],0
C000:2E6C  74 02             jz C000:2E70
C000:2E6E  F9                stc             ; fail
C000:2E6F  C3                ret
C000:2E70  F8                clc             ; pass
C000:2E71  C3                ret
```

## C000:2E72 — Subsystem Init Chain

Master init routine called during cold start and cold reinit. Sets
`[1106]=8` and `[1339]=8`, verifies the RAM checksum (via `C000:0580`),
seeds bank mirrors, then calls a chain of init subroutines.

```asm
; file 0xC2E72
C000:2E72  C6 06 0611 08     mov byte [1106],8   ; storage endpoint = 8
C000:2E77  C6 06 3913 08     mov byte [1339],8
C000:2E7C  E8 01D7           call C000:0580  ; verify RAM checksum (1800 segment)
C000:2E7F  74 0B             jz C000:2E8C    ; checksum OK -> skip store reinit
C000:2E81  B3 A5             mov bl,A5
C000:2E83  B2 08             mov dl,8
C000:2E85  B4 FF             mov ah,FF
C000:2E87  9A 2A2E 00C0      call far C000:2E2A  ; storage reinit
C000:2E8C  E8 98D4           call C000:0327  ; seed bank mirrors
C000:2E8F  E8 2910           call C000:3EBB
C000:2E92  E8 3F10           call C000:3ED4
C000:2E95  E8 EEFC           call C000:2B86
C000:2E98  E8 9700           call C000:2F32
C000:2E9B  E8 DE00           call C000:2F7C
C000:2E9E  E8 0F01           call C000:2FB0
C000:2EA1  E8 3101           call C000:2FD5
C000:2EA4  E8 0100           call C000:2EA8
C000:2EA7  C3                ret
```

### C000:2E72 Init Chain Subroutines

Each subroutine called from `C000:2E72`, in call order:

**`C000:3EBB` — Copy keyboard translation table to RAM.** Copies 0x50
bytes from `CS:3927` to `[1643..1692]`.

```asm
; file 0xC3EBB
C000:3EBB  1E                push ds
C000:3EBC  06                push es
C000:3EBD  8C D9             mov cx,ds
C000:3EBF  8E C1             mov es,cx
C000:3EC1  8C C9             mov cx,cs
C000:3EC3  8E D9             mov ds,cx       ; DS = CS (ROM)
C000:3EC5  B9 5000           mov cx,50       ; 80 bytes
C000:3EC8  BE 2739           mov si,3927     ; source: CS:3927
C000:3ECB  BF 4316           mov di,1643     ; dest: [1643]
C000:3ECE  FC                cld
C000:3ECF  F3 A4             rep movsb
C000:3ED1  07                pop es
C000:3ED2  1F                pop ds
C000:3ED3  C3                ret
```

**`C000:3ED4` — Copy keyboard handler pointer table to RAM.** Copies
0x1E0 bytes from `CS:3887` to `[1126..1305]`, then builds a 6-entry
pointer table at `[1114..111F]` with 0x50-byte spacing starting at
`0x1126`.

```asm
; file 0xC3ED4
C000:3ED4  1E                push ds
C000:3ED5  06                push es
C000:3ED6  8C D9             mov cx,ds
C000:3ED8  8E C1             mov es,cx
C000:3EDA  8C C9             mov cx,cs
C000:3EDC  8E D9             mov ds,cx       ; DS = CS
C000:3EDE  B9 E001           mov cx,1E0      ; 480 bytes
C000:3EE1  BE 8738           mov si,3887     ; source: CS:3887
C000:3EE4  BF 2611           mov di,1126     ; dest: [1126]
C000:3EE7  FC                cld
C000:3EE8  F3 A4             rep movsb
C000:3EEA  B9 0600           mov cx,6        ; 6 pointers
C000:3EED  B8 2611           mov ax,1126     ; first entry
C000:3EF0  BF 1411           mov di,1114
C000:3EF3  AB                stosw           ; store pointer
C000:3EF4  05 5000           add ax,50       ; next entry += 0x50
C000:3EF7  E2 FA             loop C000:3EF3
C000:3EF9  07                pop es
C000:3EFA  1F                pop ds
C000:3EFB  C3                ret
```

**`C000:2B86` — Set DTA address.** Calls INT 21h AH=1Ah to set the
Disk Transfer Area to `[1008]`.

```asm
; file 0xC2B86
C000:2B86  BA 0810           mov dx,1008     ; DTA address
C000:2B89  1E                push ds
C000:2B8A  B4 1A             mov ah,1A       ; INT 21h: set DTA
C000:2B8C  CD 21             int 21h
C000:2B8E  1F                pop ds
C000:2B8F  C3                ret
```

**`C000:2F32` — Init RTC date and clear time.** Sets date to
year=0x7CE (1998), month=1, day=1 via INT 21h AH=2Bh, clears time via
INT 21h AH=2Dh, then calls `C000:0CA7` to init the RTC check sentinels
and sets `[1337]=0x7CE`, `[1335]=0x1770`.

```asm
; file 0xC2F32
C000:2F32  B9 CE07           mov cx,7CE      ; year 1998 (BCD)
C000:2F35  BA 0101           mov dx,101      ; month=1, day=1
C000:2F38  B4 2B             mov ah,2B       ; INT 21h: set date
C000:2F3A  CD 21             int 21h
C000:2F3C  33 C9             xor cx,cx       ; hour=0, minute=0
C000:2F3E  33 D2             xor dx,dx       ; second=0, centisec=0
C000:2F40  B4 2D             mov ah,2D       ; INT 21h: set time
C000:2F42  CD 21             int 21h
C000:2F44  E8 60DD           call C000:0CA7  ; init RTC check sentinels
C000:2F47  C7 06 3713 CE07   mov word [1337],7CE
C000:2F4D  C7 06 3513 7017   mov word [1335],1770
C000:2F53  C3                ret
```

**`C000:2F7C` — Init keyboard scan parameters.** Sets `[132E..1332]`
to defaults: `[132E]=6, [132F]=1, [1330..1332]=0`.

```asm
; file 0xC2F7C
C000:2F7C  B0 06             mov al,6
C000:2F7E  A2 2E13           mov [132E],al
C000:2F81  B0 01             mov al,1
C000:2F83  A2 2F13           mov [132F],al
C000:2F86  B0 00             mov al,0
C000:2F88  A2 3013           mov [1330],al
C000:2F8B  B0 00             mov al,0
C000:2F8D  A2 3113           mov [1331],al
C000:2F90  B0 00             mov al,0
C000:2F92  A2 3213           mov [1332],al
C000:2F95  C3                ret
```

**`C000:2FB0` — Init auto-save timer parameters.** Sets `[1447]=3`,
`[1448..1449]=0`.

```asm
; file 0xC2FB0
C000:2FB0  B0 03             mov al,3
C000:2FB2  A2 4714           mov [1447],al
C000:2FB5  32 C0             xor al,al
C000:2FB7  A2 4814           mov [1448],al
C000:2FBA  32 C0             xor al,al
C000:2FBC  A2 4914           mov [1449],al
C000:2FBF  C3                ret
```

**`C000:2FD5` — Init sound slot selector.** Sets `[1333]=3` and
`[1334]=0` (sound slot 0, used by
[`sound-lowlevel.md`](sound-lowlevel.md) during normal resume).

```asm
; file 0xC2FD5
C000:2FD5  B0 03             mov al,3
C000:2FD7  A2 3313           mov [1333],al
C000:2FDA  32 C0             xor al,al
C000:2FDC  A2 3413           mov [1334],al   ; sound slot = 0
C000:2FDF  C3                ret
```

**`C000:2EA8` — Clear boot/resume state variables.** Clears `[146F]`
(resume state), `[1443]`, `[15A2]` (diagnostic active), `[1439]` (RTC
flag), `[143C]` (warm-retry), `[143D]`, `[1107]`, `[110D]`, `[1446]`,
`[1442]`, `[1445]`, `[7195]`, `[7D75..7D79]`. Sets `[1324]=1`,
`[7D79]=1`, `[1112]=0x723A`.

```asm
; file 0xC2EA8
C000:2EA8  C7 06 1211 3A72   mov word [1112],723A
C000:2EAE  33 C0             xor ax,ax
C000:2EB0  A3 6F14           mov [146F],ax   ; clear resume state
C000:2EB3  A3 4314           mov [1443],ax
C000:2EB6  A2 A215           mov [15A2],al   ; clear diagnostic flag
C000:2EB9  A2 3914           mov [1439],al   ; clear RTC abnormal flag
C000:2EBC  A2 3C14           mov [143C],al   ; clear warm-retry
C000:2EBF  A2 3D14           mov [143D],al
C000:2EC2  A2 0711           mov [1107],al
C000:2EC5  A3 0D11           mov [110D],ax
C000:2EC8  A2 4614           mov [1446],al
C000:2ECB  A2 4214           mov [1442],al
C000:2ECE  A2 4514           mov [1445],al
C000:2ED1  A2 9571           mov [7195],al
C000:2ED4  A2 767D           mov [7D76],al
C000:2ED7  A2 757D           mov [7D75],al
C000:2EDA  A2 787D           mov [7D78],al
C000:2EDD  FE C0             inc al          ; AL = 1
C000:2EDF  A2 2413           mov [1324],al
C000:2EE2  A2 797D           mov [7D79],al
```

Continues with additional state initialization through `C000:2EF7`
before returning.

### C000:2E2D Validation Subroutines

Called by `C000:2E2D` to validate stored state for warm resume:

**`C000:2EF8` — Validate RTC date/time.** Reads the RTC via
`C000:0B74` (which calls `C000:0E13` to scan RTC registers, then
extracts year, month, day, hour, minute, second from the scan buffer).
Checks year is `0x7BC..0x832`, month is `1..12`, day is nonzero,
hour `<24`, minute `<60`, second `<60`. Calls `C000:0BFA` for the time
portion. Sets `[1441]` fail flag on any range error.

**`C000:2F54` — Validate keyboard scan parameters.** Checks 5 bytes
at `[132E..1332]` are within valid ranges (3..7, 0..1, 0..1, 0..2,
0..1). Sets `[1441]` fail flag if out of range.

**`C000:2F96` — Validate auto-save timer parameters.** Checks 3 bytes
at `[1447..1449]` are within valid ranges (0..6, 0..1, 0..1). Sets
`[1441]` fail flag if out of range.

**`C000:2FC0` — Validate sound parameters.** Checks 2 bytes at
`[1333..1334]` are within valid ranges (0..6, 0..3). Sets `[1441]`
fail flag if out of range.

### C000:6523 Init Subroutines

**`C000:6BF6` — Clear framebuffer.** Fills `[8000..8FFF]` with zero
(2048 words). Returns AL=1.

```asm
; file 0xC6BF6
C000:6BF6  33 C0             xor ax,ax
C000:6BF8  8A E0             mov ah,al
C000:6BFA  BF 0080           mov di,8000
C000:6BFD  B9 0008           mov cx,800
C000:6C00  FC                cld
C000:6C01  F3 AB             rep stosw
C000:6C03  B0 01             mov al,1
C000:6C05  C3                ret
```

**`C000:6CA7` — Init display page table.** Computes page table
entries based on `[1728]` (display page count) and writes them starting
at `DEF0:D8C6` (via ES).

## C000:12CC — Clear Keyboard State and IRQ Setup

Clears 20 bytes at `[1310..1323]`, clears state bytes, masks IRQ port
`0x60`, pulses keyboard scan edge on port `0x61` (`FE` -> `FF`),
clears `[132D]` (row counter).

```asm
; file 0xC12CC
C000:12CC  BB 1013           mov bx,1310
C000:12CF  B9 1400           mov cx,14       ; 20 bytes
C000:12D2  C6 07 00          mov byte [bx],0
C000:12D5  43                inc bx
C000:12D6  E2 FA             loop C000:12D2
C000:12D8  B8 0000           mov ax,0
C000:12DB  A2 9C15           mov [159C],al
C000:12DE  A2 9D15           mov [159D],al
C000:12E1  80 26 9571 40     and byte [7195],40
C000:12E6  A3 9E15           mov [159E],ax
C000:12E9  A2 A015           mov [15A0],al
C000:12EC  A2 A115           mov [15A1],al
C000:12EF  A2 D016           mov [16D0],al
C000:12F2  A2 D116           mov [16D1],al
C000:12F5  A2 2513           mov [1325],al
C000:12F8  A2 2613           mov [1326],al
C000:12FB  A2 2713           mov [1327],al
C000:12FE  80 26 3A14 7E     and byte [143A],7E  ; clear bits 0,7
C000:1303  80 26 3A14 F7     and byte [143A],F7  ; clear bit 3
C000:1308  A0 3A14           mov al,[143A]
C000:130B  E6 60             out 60,al       ; update IRQ mask
C000:130D  E4 B0             in al,B0        ; dummy keyboard read
C000:130F  B0 FE             mov al,FE
C000:1311  E6 61             out 61,al       ; scan edge: FE
C000:1313  B0 FF             mov al,FF
C000:1315  E6 61             out 61,al       ; scan edge: FF
C000:1317  C6 06 2D13 00     mov byte [132D],0  ; reset row counter
C000:131C  C3                ret
```
