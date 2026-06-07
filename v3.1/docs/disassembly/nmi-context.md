# NMI Handler and Context Save/Restore

## C000:04D0 — NMI Handler (INT 02h / IRQ F8)

Entered via hardware NMI (power button on drwrt400). Saves full register
context to `[1453..146D]`, computes a checksum, saves additional state,
then halts via `C000:0492`.

Three early-exit paths based on `[1109]` (startup state): if the machine
is still in early startup (`[1109]==1`) or battery-warning state
(`[1109]==0x1995`), stores `[1473]=0x4D0` and halts immediately without
saving the full context.

```asm
; file 0xC04D0
C000:04D0  1E                push ds
C000:04D1  50                push ax
C000:04D2  55                push bp
C000:04D3  8C DD             mov bp,ds       ; save DS in BP
C000:04D5  B8 0000           mov ax,0
C000:04D8  8E D8             mov ds,ax       ; DS = 0
C000:04DA  B0 80             mov al,80
C000:04DC  E6 90             out 90,al       ; LCD off
C000:04DE  A1 0911           mov ax,[1109]   ; startup state
C000:04E1  83 F8 01          cmp ax,1        ; early startup?
C000:04E4  75 08             jnz C000:04EE
C000:04E6  C7 06 7314 D004   mov word [1473],4D0
C000:04EC  EB A4             jmp short C000:0492  ; -> halt
C000:04EE  3D 9519           cmp ax,1995     ; battery warning?
C000:04F1  75 08             jnz C000:04FB
C000:04F3  C7 06 7314 D004   mov word [1473],4D0
C000:04F9  EB 97             jmp short C000:0492  ; -> halt
```

Full context save (reached when `[1109]` is not 1 or 0x1995):

```asm
C000:04FB  C7 06 7314 D004   mov word [1473],4D0  ; mark NMI source
C000:0501  89 2E 6114        mov [1461],bp   ; save DS (was in BP)
C000:0505  89 1E 5514        mov [1455],bx
C000:0509  89 0E 5714        mov [1457],cx
C000:050D  89 16 5914        mov [1459],dx
C000:0511  89 36 5B14        mov [145B],si
C000:0515  89 3E 5D14        mov [145D],di
C000:0519  8C 06 6314        mov [1463],es
C000:051D  8C 16 6514        mov [1465],ss
C000:0521  8B EC             mov bp,sp       ; walk the IRET frame
C000:0523  83 C5 06          add bp,6        ; skip pushed DS/AX/BP
C000:0526  8B 46 00          mov ax,[bp+0]   ; saved AX from caller
C000:0529  A3 6714           mov [1467],ax
C000:052C  83 C5 02          add bp,2
C000:052F  8B 46 00          mov ax,[bp+0]   ; return IP
C000:0532  A3 6914           mov [1469],ax
C000:0535  A3 7514           mov [1475],ax   ; duplicate
C000:0538  83 C5 02          add bp,2
C000:053B  8B 46 00          mov ax,[bp+0]   ; return CS
C000:053E  A3 6D14           mov [146D],ax
C000:0541  83 C5 02          add bp,2
C000:0544  89 2E 6B14        mov [146B],bp   ; saved SP (post-IRET frame)
C000:0548  5D                pop bp
C000:0549  89 2E 5F14        mov [145F],bp   ; original BP
C000:054D  58                pop ax
C000:054E  A3 5314           mov [1453],ax   ; original AX (from push at 04D1)
C000:0551  E8 0A00           call C000:055E  ; context checksum
C000:0554  E8 4C00           call C000:05A3  ; save additional state
C000:0557  B0 F8             mov al,F8
C000:0559  E6 DD             out DD,al       ; RTC control
C000:055B  E9 34FF           jmp C000:0492   ; -> halt
```

### Context block layout at `[1453..1470]`

| Offset | Size | Register |
| --- | ---: | --- |
| `[1453]` | 2 | AX |
| `[1455]` | 2 | BX |
| `[1457]` | 2 | CX |
| `[1459]` | 2 | DX |
| `[145B]` | 2 | SI |
| `[145D]` | 2 | DI |
| `[145F]` | 2 | BP |
| `[1461]` | 2 | DS |
| `[1463]` | 2 | ES |
| `[1465]` | 2 | SS |
| `[1467]` | 2 | AX (caller's, from IRET frame) |
| `[1469]` | 2 | IP (return address) |
| `[146B]` | 2 | SP (post-IRET) |
| `[146D]` | 2 | CS (return segment) |

## C000:055E — Context Checksum Compute

Sums 15 words at `[1453..1470]`, stores the result at `[1471]`.

```asm
; file 0xC055E
C000:055E  BE 5314           mov si,1453
C000:0561  B9 0F00           mov cx,F        ; 15 words
C000:0564  FC                cld
C000:0565  33 DB             xor bx,bx
C000:0567  AD                lodsw
C000:0568  03 D8             add bx,ax
C000:056A  E2 FB             loop C000:0567
C000:056C  89 1E 7114        mov [1471],bx
C000:0570  C3                ret
```

## C000:02A3 — Context Checksum Verify and Register Restore

Recomputes the checksum of `[1453..1470]` and compares with `[1471]`.
On match: restores bank ports 11-15 from `[147B..147F]`, restores all
saved registers, returns CF=0. On mismatch: returns CF=1 immediately.

```asm
; file 0xC02A3
C000:02A3  B8 0000           mov ax,0
C000:02A6  8E D8             mov ds,ax
C000:02A8  BE 5314           mov si,1453
C000:02AB  B9 0F00           mov cx,F
C000:02AE  FC                cld
C000:02AF  33 DB             xor bx,bx
C000:02B1  AD                lodsw
C000:02B2  03 D8             add bx,ax
C000:02B4  E2 FB             loop C000:02B1
C000:02B6  3B 1E 7114        cmp bx,[1471]   ; compare checksum
C000:02BA  74 02             jz C000:02BE
C000:02BC  F9                stc             ; mismatch
C000:02BD  C3                ret
```

Checksum matched — restore bank ports and registers:

```asm
C000:02BE  A1 7B14           mov ax,[147B]
C000:02C1  E6 12             out 12,al       ; port 12
C000:02C3  8A C4             mov al,ah
C000:02C5  E6 11             out 11,al       ; port 11
C000:02C7  A1 7D14           mov ax,[147D]
C000:02CA  E6 14             out 14,al       ; port 14
C000:02CC  8A C4             mov al,ah
C000:02CE  E6 13             out 13,al       ; port 13
C000:02D0  A0 7F14           mov al,[147F]
C000:02D3  E6 15             out 15,al       ; port 15
C000:02D5  F6 06 3B14 10     test byte [143B],10
C000:02DA  75 04             jnz C000:02E0
C000:02DC  E8 2C0C           call C000:0F0B  ; additional restore (if bit 4 clear)
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
C000:0301  F8                clc             ; success
C000:0302  C3                ret
```

## C000:05A3 — Save Additional State

Copies `[1335]` to `[110B]`, copies interrupt mask shadow `[143A]` to
`[143B]`, then calls `C000:0FB5` and `C000:0E9F` unless bit 4 of `[143A]`
is set.

```asm
; file 0xC05A3
C000:05A3  E8 5908           call C000:0DFF
C000:05A6  A1 3513           mov ax,[1335]
C000:05A9  A3 0B11           mov [110B],ax
C000:05AC  A0 3A14           mov al,[143A]
C000:05AF  A2 3B14           mov [143B],al
C000:05B2  F6 06 3A14 10     test byte [143A],10
C000:05B7  75 06             jnz C000:05BF   ; bit 4 set -> skip
C000:05B9  E8 F909           call C000:0FB5
C000:05BC  E8 E008           call C000:0E9F
C000:05BF  C3                ret
```
