# Banked Inflection Helper Tail

This slice maps the helper tail after
[`banked-suffix-final-letter-extended.md`](banked-suffix-final-letter-extended.md).
It covers the `3000:8232` `a..y` table used by `3000:8056` and the code at
`3000:8264..84A7`, including helpers `3000:8290`, `3000:82C6`, `3000:83E4`,
and `3000:8438`.

No image assets are reached in this slice.

## A-Y Table

The `3000:8232` bytes are a word table indexed by the final letter after
subtracting `a`. They are not executable code:

| Letter | Target |
| --- | --- |
| `a` | `3000:80EB` |
| `c`, `j`, `q`, `r`, `s`, `v`, `w`, `x` | `3000:8264` |
| `e` | `3000:80F8` |
| `h` | `3000:81A0` |
| `i` | `3000:80C8` |
| `k` | `3000:81D4` |
| `o` | `3000:8190` |
| `u` | `3000:8116` |
| `y` | `3000:812E` |
| other `a..y` letters | `3000:81E0` |

`3000:8264` handles the common fallback for repeated final letters and default
`e` suffix construction. The rest of this slice contains small suffix helpers
and two shared candidate-array helpers.

## Helper Tail

`3000:8290` rejects final `a`, optionally tries adding `e` after `dg`, and then
falls back to direct dictionary membership. `3000:82C6` is a broader
double-letter/ending helper: it checks doubled endings, tests character classes
from strings in the `3C00:2B03` and `3C00:2B12` pools, tries `i -> y`, `ns ->
nd`, and appended `e` forms, and finally may call the compound rewriter at
`3000:84A8`.

`3000:83E4` maps a record type to a suffix-pattern record in the `3C00:2A1E`
table. `3000:8438` appends candidate output pointers and type words into the
caller arrays, preserving internal `0x0E` separators by splitting the visible
candidate string into multiple array entries.

```asm
inflection_helper_tail_C3000_8264:
; file 0x38264
3000:8264  8A 45 FE          mov al,[di-0x2]
3000:8267  38 45 FF          cmp [di-0x1],al
3000:826A  75 14             jnz 0x8280
3000:826C  8A 45 FF          mov al,[di-0x1]
3000:826F  88 46 E8          mov [bp-0x18],al
3000:8272  2A C0             sub al,al
3000:8274  88 46 E9          mov [bp-0x17],al
3000:8277  88 46 D0          mov [bp-0x30],al
3000:827A  4F                dec di
3000:827B  88 05             mov [di],al
3000:827D  E9 F9 FE          jmp 0x8179
3000:8280  C6 46 E8 65       mov byte [bp-0x18],0x65
3000:8284  2A C0             sub al,al
3000:8286  88 46 D0          mov [bp-0x30],al
3000:8289  88 46 E9          mov [bp-0x17],al
3000:828C  E9 EA FE          jmp 0x8179
3000:828F  90                nop
3000:8290  55                push bp
3000:8291  8B EC             mov bp,sp
3000:8293  57                push di
3000:8294  56                push si
3000:8295  8B 76 04          mov si,[bp+0x4]
3000:8298  8B 7E 06          mov di,[bp+0x6]
3000:829B  80 7D FF 61       cmp byte [di-0x1],0x61
3000:829F  74 1F             jz 0x82c0
3000:82A1  80 7D FF 67       cmp byte [di-0x1],0x67
3000:82A5  75 0D             jnz 0x82b4
3000:82A7  80 7D FE 64       cmp byte [di-0x2],0x64
3000:82AB  75 07             jnz 0x82b4
3000:82AD  C6 05 65          mov byte [di],0x65
3000:82B0  47                inc di
3000:82B1  C6 05 00          mov byte [di],0x0
3000:82B4  56                push si
3000:82B5  E8 2E 2E          call 0xb0e6
3000:82B8  83 C4 02          add sp,byte +0x2
3000:82BB  5E                pop si
3000:82BC  5F                pop di
3000:82BD  5D                pop bp
3000:82BE  C3                ret
3000:82BF  90                nop
3000:82C0  2B C0             sub ax,ax
3000:82C2  5E                pop si
3000:82C3  5F                pop di
3000:82C4  5D                pop bp
3000:82C5  C3                ret
3000:82C6  55                push bp
3000:82C7  8B EC             mov bp,sp
3000:82C9  57                push di
3000:82CA  56                push si
3000:82CB  8B 76 04          mov si,[bp+0x4]
3000:82CE  8B 7E 06          mov di,[bp+0x6]
3000:82D1  8A 45 FE          mov al,[di-0x2]
3000:82D4  38 45 FF          cmp [di-0x1],al
3000:82D7  75 57             jnz 0x8330
3000:82D9  56                push si
3000:82DA  E8 09 2E          call 0xb0e6
3000:82DD  83 C4 02          add sp,byte +0x2
3000:82E0  0B C0             or ax,ax
3000:82E2  74 08             jz 0x82ec
3000:82E4  B8 01 00          mov ax,0x1
3000:82E7  5E                pop si
3000:82E8  5F                pop di
3000:82E9  5D                pop bp
3000:82EA  C3                ret
3000:82EB  90                nop
3000:82EC  8A 45 FF          mov al,[di-0x1]
3000:82EF  2A E4             sub ah,ah
3000:82F1  50                push ax
3000:82F2  B8 03 2B          mov ax,0x2b03
3000:82F5  50                push ax
3000:82F6  E8 41 13          call 0x963a
3000:82F9  83 C4 04          add sp,byte +0x4
3000:82FC  0B C0             or ax,ax
3000:82FE  74 10             jz 0x8310
3000:8300  C6 45 FF 00       mov byte [di-0x1],0x0
3000:8304  56                push si
3000:8305  E8 DE 2D          call 0xb0e6
3000:8308  83 C4 02          add sp,byte +0x2
3000:830B  5E                pop si
3000:830C  5F                pop di
3000:830D  5D                pop bp
3000:830E  C3                ret
3000:830F  90                nop
3000:8310  80 7D FE 73       cmp byte [di-0x2],0x73
3000:8314  75 13             jnz 0x8329
3000:8316  C6 45 FE 74       mov byte [di-0x2],0x74
3000:831A  C6 45 FF 00       mov byte [di-0x1],0x0
3000:831E  56                push si
3000:831F  E8 C4 2D          call 0xb0e6
3000:8322  83 C4 02          add sp,byte +0x2
3000:8325  0B C0             or ax,ax
3000:8327  75 BB             jnz 0x82e4
3000:8329  2B C0             sub ax,ax
3000:832B  5E                pop si
3000:832C  5F                pop di
3000:832D  5D                pop bp
3000:832E  C3                ret
3000:832F  90                nop
3000:8330  80 7D FF 69       cmp byte [di-0x1],0x69
3000:8334  75 20             jnz 0x8356
3000:8336  B8 0E 2B          mov ax,0x2b0e
3000:8339  50                push ax
3000:833A  57                push di
3000:833B  E8 CC 12          call 0x960a
3000:833E  83 C4 04          add sp,byte +0x4
3000:8341  56                push si
3000:8342  E8 A1 2D          call 0xb0e6
3000:8345  83 C4 02          add sp,byte +0x2
3000:8348  0B C0             or ax,ax
3000:834A  75 98             jnz 0x82e4
3000:834C  C6 45 FF 79       mov byte [di-0x1],0x79
3000:8350  C6 05 00          mov byte [di],0x0
3000:8353  EB AF             jmp short 0x8304
3000:8355  90                nop
3000:8356  80 7D FF 73       cmp byte [di-0x1],0x73
3000:835A  75 2A             jnz 0x8386
3000:835C  80 7D FE 6E       cmp byte [di-0x2],0x6e
3000:8360  75 19             jnz 0x837b
3000:8362  C6 45 FF 64       mov byte [di-0x1],0x64
3000:8366  C6 05 00          mov byte [di],0x0
3000:8369  56                push si
3000:836A  E8 79 2D          call 0xb0e6
3000:836D  83 C4 02          add sp,byte +0x2
3000:8370  0B C0             or ax,ax
3000:8372  74 03             jz 0x8377
3000:8374  E9 6D FF          jmp 0x82e4
3000:8377  C6 45 FF 73       mov byte [di-0x1],0x73
3000:837B  C6 05 65          mov byte [di],0x65
3000:837E  C6 45 01 00       mov byte [di+0x1],0x0
3000:8382  E9 7F FF          jmp 0x8304
3000:8385  90                nop
3000:8386  8A 45 FF          mov al,[di-0x1]
3000:8389  2A E4             sub ah,ah
3000:838B  50                push ax
3000:838C  B8 12 2B          mov ax,0x2b12
3000:838F  50                push ax
3000:8390  E8 A7 12          call 0x963a
3000:8393  83 C4 04          add sp,byte +0x4
3000:8396  0B C0             or ax,ax
3000:8398  74 2A             jz 0x83c4
3000:839A  B8 19 2B          mov ax,0x2b19
3000:839D  50                push ax
3000:839E  57                push di
3000:839F  E8 68 12          call 0x960a
3000:83A2  83 C4 04          add sp,byte +0x4
3000:83A5  56                push si
3000:83A6  E8 3D 2D          call 0xb0e6
3000:83A9  83 C4 02          add sp,byte +0x2
3000:83AC  0B C0             or ax,ax
3000:83AE  74 03             jz 0x83b3
3000:83B0  E9 31 FF          jmp 0x82e4
3000:83B3  C6 05 00          mov byte [di],0x0
3000:83B6  56                push si
3000:83B7  E8 2C 2D          call 0xb0e6
3000:83BA  83 C4 02          add sp,byte +0x2
3000:83BD  0B C0             or ax,ax
3000:83BF  74 03             jz 0x83c4
3000:83C1  E9 20 FF          jmp 0x82e4
3000:83C4  8B C7             mov ax,di
3000:83C6  2B C6             sub ax,si
3000:83C8  3D 03 00          cmp ax,0x3
3000:83CB  7D 03             jnl 0x83d0
3000:83CD  E9 34 FF          jmp 0x8304
3000:83D0  B8 1D 2B          mov ax,0x2b1d
3000:83D3  50                push ax
3000:83D4  B8 1E 2B          mov ax,0x2b1e
3000:83D7  50                push ax
3000:83D8  57                push di
3000:83D9  56                push si
3000:83DA  E8 CB 00          call 0x84a8
3000:83DD  83 C4 08          add sp,byte +0x8
3000:83E0  5E                pop si
3000:83E1  5F                pop di
3000:83E2  5D                pop bp
3000:83E3  C3                ret
3000:83E4  55                push bp
3000:83E5  8B EC             mov bp,sp
3000:83E7  83 EC 04          sub sp,byte +0x4
3000:83EA  57                push di
3000:83EB  56                push si
3000:83EC  8B 76 04          mov si,[bp+0x4]
3000:83EF  4E                dec si
3000:83F0  2B FF             sub di,di
3000:83F2  EB 11             jmp short 0x8405
3000:83F4  8B C7             mov ax,di
3000:83F6  B1 03             mov cl,0x3
3000:83F8  D3 E0             shl ax,cl
3000:83FA  05 1E 2A          add ax,0x2a1e
3000:83FD  5E                pop si
3000:83FE  5F                pop di
3000:83FF  8B E5             mov sp,bp
3000:8401  5D                pop bp
3000:8402  C3                ret
3000:8403  90                nop
3000:8404  47                inc di
3000:8405  8B C7             mov ax,di
3000:8407  B1 03             mov cl,0x3
3000:8409  D3 E0             shl ax,cl
3000:840B  89 46 FC          mov [bp-0x4],ax
3000:840E  8B D8             mov bx,ax
3000:8410  83 BF 1E 2A 00    cmp word [bx+0x2a1e],byte +0x0
3000:8415  74 19             jz 0x8430
3000:8417  39 B7 24 2A       cmp [bx+0x2a24],si
3000:841B  75 E7             jnz 0x8404
3000:841D  83 FE 07          cmp si,byte +0x7
3000:8420  75 D2             jnz 0x83f4
3000:8422  8B C7             mov ax,di
3000:8424  D3 E0             shl ax,cl
3000:8426  05 26 2A          add ax,0x2a26
3000:8429  5E                pop si
3000:842A  5F                pop di
3000:842B  8B E5             mov sp,bp
3000:842D  5D                pop bp
3000:842E  C3                ret
3000:842F  90                nop
3000:8430  2B C0             sub ax,ax
3000:8432  5E                pop si
3000:8433  5F                pop di
3000:8434  8B E5             mov sp,bp
3000:8436  5D                pop bp
3000:8437  C3                ret
3000:8438  55                push bp
3000:8439  8B EC             mov bp,sp
3000:843B  83 EC 04          sub sp,byte +0x4
3000:843E  57                push di
3000:843F  56                push si
3000:8440  8B 76 0A          mov si,[bp+0xa]
3000:8443  8B 7E 04          mov di,[bp+0x4]
3000:8446  80 3D 00          cmp byte [di],0x0
3000:8449  75 09             jnz 0x8454
3000:844B  2B C0             sub ax,ax
3000:844D  5E                pop si
3000:844E  5F                pop di
3000:844F  8B E5             mov sp,bp
3000:8451  5D                pop bp
3000:8452  C3                ret
3000:8453  90                nop
3000:8454  8B 5E 06          mov bx,[bp+0x6]
3000:8457  8B C6             mov ax,si
3000:8459  D1 E0             shl ax,1
3000:845B  03 D8             add bx,ax
3000:845D  A1 80 71          mov ax,[0x7180]
3000:8460  EB 2A             jmp short 0x848c
3000:8462  47                inc di
3000:8463  80 7D FF 0E       cmp byte [di-0x1],0xe
3000:8467  75 31             jnz 0x849a
3000:8469  C6 45 FF 00       mov byte [di-0x1],0x0
3000:846D  57                push di
3000:846E  FF 76 04          push word [bp+0x4]
3000:8471  E8 2A 12          call 0x969e
3000:8474  83 C4 04          add sp,byte +0x4
3000:8477  0B C0             or ax,ax
3000:8479  74 1F             jz 0x849a
3000:847B  8B 46 06          mov ax,[bp+0x6]
3000:847E  8B CE             mov cx,si
3000:8480  D1 E1             shl cx,1
3000:8482  03 C1             add ax,cx
3000:8484  89 46 FC          mov [bp-0x4],ax
3000:8487  8B D8             mov bx,ax
3000:8489  8B 47 FE          mov ax,[bx-0x2]
3000:848C  89 07             mov [bx],ax
3000:848E  8B 5E 08          mov bx,[bp+0x8]
3000:8491  8B C6             mov ax,si
3000:8493  46                inc si
3000:8494  D1 E0             shl ax,1
3000:8496  03 D8             add bx,ax
3000:8498  89 3F             mov [bx],di
3000:849A  80 3D 00          cmp byte [di],0x0
3000:849D  75 C3             jnz 0x8462
3000:849F  8B C6             mov ax,si
3000:84A1  5E                pop si
3000:84A2  5F                pop di
3000:84A3  8B E5             mov sp,bp
3000:84A5  5D                pop bp
3000:84A6  C3                ret
3000:84A7  90                nop
```

## Boundary

The `3000:8232` table and helper tail through `3000:84A7` are now mapped. The
next adjacent routine starts at `3000:84A8` and is documented in
[`banked-multiword-expansion.md`](banked-multiword-expansion.md).
