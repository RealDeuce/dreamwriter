# INT 21h Dispatch

The INT 21h handler at `C000:6277` (file `0xC6277`) provides DOS-like file and
system services. The IVT entry at `[0084]` points to the jump stub at
`C000:0006`, which jumps to `C000:6277`.

## Dispatcher

```asm
int21_dispatch_C000_6277:
; file 0xC6277
C000:6277  55                push bp
C000:6278  56                push si
C000:6279  57                push di
C000:627A  83 EC 0E          sub sp,0E          ; 14-byte local frame
C000:627D  8B EC             mov bp,sp
C000:627F  89 46 00          mov [bp+00],ax     ; save all regs
C000:6282  89 5E 02          mov [bp+02],bx
C000:6285  89 4E 04          mov [bp+04],cx
C000:6288  89 56 06          mov [bp+06],dx
C000:628B  8C 5E 08          mov [bp+08],ds
C000:628E  8C 46 0A          mov [bp+0A],es
C000:6291  BE 0000           mov si,0
C000:6294  8E DE             mov ds,si           ; DS = 0 for state access
C000:6296  88 26 0B6F        mov [6F0B],ah        ; store function number
C000:629A  C7 06 AF15 0000   mov word [15AF],0000
C000:62A0  80 FC FF          cmp ah,FF
C000:62A3  74 4C             jz C000:62F1         ; AH=FF -> store validate
C000:62A5  80 FC 60          cmp ah,60
C000:62A8  73 45             jnc C000:62EF        ; AH >= 60h -> hang
C000:62AA  32 C0             xor al,al
C000:62AC  86 C4             xchg ah,al           ; AX = function number
C000:62AE  8B F0             mov si,ax
C000:62B0  2E 8A 84 DF61     mov al,[cs:si+61DF]  ; validity table lookup
C000:62B5  3C FF             cmp al,FF
C000:62B7  74 36             jz C000:62EF         ; invalid -> hang
C000:62B9  D1 E0             shl ax,1             ; slot * 2
C000:62BB  8B F0             mov si,ax
C000:62BD  2E 8B 84 3F62     mov ax,[cs:si+623F]  ; dispatch table lookup
C000:62C2  FB                sti
C000:62C3  FF D0             call ax              ; call handler
C000:62C5  FA                cli
```

After the handler returns, registers are restored from the stack frame and
the carry flag is propagated to the caller's flags word:

```asm
C000:62C6  9F                lahf
C000:62C7  83 C4 0E          add sp,0E
C000:62CA  9E                sahf
C000:62CB  8B 46 00          mov ax,[bp+00]      ; restore regs
...
C000:62E1  72 06             jc C000:62E9
C000:62E3  80 66 06 FE       and byte [bp+06],FE  ; clear CF in flags
C000:62E7  5D                pop bp
C000:62E8  CF                iret
C000:62E9  80 4E 06 01       or byte [bp+06],01   ; set CF in flags
C000:62ED  5D                pop bp
C000:62EE  CF                iret
```

Invalid function numbers land at `C000:62EF` (`JMP SHORT $` — infinite loop).
This matches v2.1 behavior.

## Function Table

The validity table at `C000:61DF` maps `AH` values `00h..5Fh` to dispatch
slots. Slot `0xFF` means unsupported. The dispatch table at `C000:623F`
converts slots to handler offsets.

| AH | DOS meaning | Handler | Notes |
| ---: | --- | --- | --- |
| `03h` | Aux input | `C000:62F6` | |
| `04h` | Aux output | `C000:0FFC` | |
| `05h` | Printer output | `C000:6325` | |
| `08h` | Char input (no echo) | `C000:6334` | |
| `0Bh` | Check input status | `C000:633B` | |
| `0Eh` | Select disk | `C000:6342` | |
| `19h` | Get current disk | `C000:6346` | |
| `1Ah` | Set DTA address | `C000:634A` | |
| `2Ah` | Get date | `C000:634E` | |
| `2Bh` | Set date | `C000:635B` | |
| `2Ch` | Get time | `C000:6362` | |
| `2Dh` | Set time | `C000:636C` | |
| `2Fh` | Get DTA address | `C000:6373` | |
| `36h` | Get disk free space | `C000:6377` | |
| `3Ch` | Create file | `C000:637B` | |
| `3Dh` | Open file | `C000:637F` | |
| `3Eh` | Close file | `C000:6383` | |
| `3Fh` | Read file | `C000:6387` | |
| `40h` | Write file | `C000:638B` | |
| `41h` | Delete file | `C000:638F` | |
| `42h` | Seek | `C000:6393` | |
| `43h` | Get/set attributes | `C000:6397` | |
| `44h` | IOCTL | `C000:639B` | |
| `4Eh` | Find first | `C000:6405` | |
| `4Fh` | Find next | `C000:6409` | |
| `56h` | Rename file | `C000:640D` | |
| `57h` | Get/set file date/time | `C000:6411` | |
| `5Bh` | Create new file | `C000:6415` | |
| `FFh` | (private) store validate | `C000:4396` | via special case, not table |

The supported function set is identical to v2.1.

## Comparison With v2.1

| Element | v2.1 | v3.1 |
| --- | --- | --- |
| Dispatcher | `C000:5098` | `C000:6277` |
| Validity table | `C000:5000` | `C000:61DF` |
| Dispatch table | `C000:5060` | `C000:623F` |
| AH=FF handler | `C000:4811` | `C000:4396` |
| Supported functions | 28 | 28 (same set) |
