# Banked Tertiary Suffix Handlers

This slice maps the suffix-handler family after
[`banked-suffix-secondary.md`](banked-suffix-secondary.md). It covers
`3000:7432..7723`, including the compact `3000:7432` helper, the `3000:748E`
`b..y` dispatcher, and the shared compound builder at `3000:7686`.

No image assets are reached in this slice.

## Compact Suffix Helper

`3000:7432` appends the caller suffix/string pointer to the current output,
checks the candidate through `3000:B0E6`, and returns `1` on success. On
failure it temporarily truncates at `DI`, checks whether the three bytes before
`DI` match runtime string `25B8` through `3000:969E`, and, if not, retries by
appending the suffix at `DI-1`.

```asm
suffix_compact_helper_C3000_7432:
; file 0x37432
3000:7432  55                push bp
3000:7433  8B EC             mov  bp,sp
3000:7435  57                push di
3000:7436  56                push si
3000:7437  8B 76 04          mov  si,[bp+0x4]
3000:743A  8B 7E 06          mov  di,[bp+0x6]
3000:743D  FF 76 08          push word [bp+0x8]
3000:7440  57                push di
3000:7441  E8 C6 21          call 0x960a
3000:7444  83 C4 04          add  sp,byte +0x4
3000:7447  56                push si
3000:7448  E8 9B 3C          call 0xb0e6
3000:744B  83 C4 02          add  sp,byte +0x2
3000:744E  0B C0             or   ax,ax
3000:7450  74 08             jz   0x745a
3000:7452  B8 01 00          mov  ax,0x1
3000:7455  5E                pop  si
3000:7456  5F                pop  di
3000:7457  5D                pop  bp
3000:7458  C3                ret
3000:7459  90                nop
3000:745A  C6 05 00          mov  byte [di],0
3000:745D  B8 B8 25          mov  ax,0x25b8
3000:7460  50                push ax
3000:7461  8D 45 FD          lea  ax,[di-0x3]
3000:7464  50                push ax
3000:7465  E8 36 22          call 0x969e
3000:7468  83 C4 04          add  sp,byte +0x4
3000:746B  0B C0             or   ax,ax
3000:746D  75 19             jnz  0x7488
3000:746F  FF 76 08          push word [bp+0x8]
3000:7472  8D 45 FF          lea  ax,[di-0x1]
3000:7475  50                push ax
3000:7476  E8 91 21          call 0x960a
3000:7479  83 C4 04          add  sp,byte +0x4
3000:747C  56                push si
3000:747D  E8 66 3C          call 0xb0e6
3000:7480  83 C4 02          add  sp,byte +0x2
3000:7483  5E                pop  si
3000:7484  5F                pop  di
3000:7485  5D                pop  bp
3000:7486  C3                ret
3000:7487  90                nop
3000:7488  2B C0             sub  ax,ax
3000:748A  5E                pop  si
3000:748B  5F                pop  di
3000:748C  5D                pop  bp
3000:748D  C3                ret
```

## B-Y Dispatcher

`3000:748E` copies the caller suffix into a local buffer at `[bp-18]`, then
changes its first byte to `i`. If the last two output characters already match,
it appends the caller suffix and checks the candidate immediately. Otherwise it
dispatches on final letters `b..y` through the inline table at `3000:7636`.

```asm
suffix_by_dispatch_C3000_748E:
; file 0x3748E
3000:748E  55                push bp
3000:748F  8B EC             mov  bp,sp
3000:7491  83 EC 18          sub  sp,byte +0x18
3000:7494  57                push di
3000:7495  56                push si
3000:7496  8B 76 04          mov  si,[bp+0x4]
3000:7499  8B 7E 06          mov  di,[bp+0x6]
3000:749C  FF 76 08          push word [bp+0x8]
3000:749F  8D 46 E8          lea  ax,[bp-0x18]
3000:74A2  50                push ax
3000:74A3  E8 64 21          call 0x960a
3000:74A6  83 C4 04          add  sp,byte +0x4
3000:74A9  C6 46 E8 69       mov  byte [bp-0x18],0x69
3000:74AD  8A 45 FE          mov  al,[di-0x2]
3000:74B0  38 45 FF          cmp  [di-0x1],al
3000:74B3  75 17             jnz  0x74cc
3000:74B5  FF 76 08          push word [bp+0x8]
3000:74B8  57                push di
3000:74B9  E8 4E 21          call 0x960a
3000:74BC  83 C4 04          add  sp,byte +0x4
3000:74BF  56                push si
3000:74C0  E8 23 3C          call 0xb0e6
3000:74C3  83 C4 02          add  sp,byte +0x2
3000:74C6  5E                pop  si
3000:74C7  5F                pop  di
3000:74C8  8B E5             mov  sp,bp
3000:74CA  5D                pop  bp
3000:74CB  C3                ret
3000:74CC  8A 45 FF          mov  al,[di-0x1]
3000:74CF  2A E4             sub  ah,ah
3000:74D1  2D 62 00          sub  ax,0x62
3000:74D4  3D 17 00          cmp  ax,0x17
3000:74D7  76 03             jna  0x74dc
3000:74D9  E9 8A 01          jmp  0x7666
3000:74DC  03 C0             add  ax,ax
3000:74DE  93                xchg ax,bx
3000:74DF  2E FF A7 36 76    jmp  [cs:bx+0x7636]
```

The `3000:7636` table is data:

| Final letter | Target |
| --- | --- |
| `b`, `f`, `g`, `l`, `m`, `n`, `p`, `r` | `3000:75BE` |
| `d` | `3000:750E` |
| `e` | `3000:75CC` |
| `t` | `3000:7558` |
| `y` | `3000:74E4` |
| other `b..y` letters | `3000:7666` |

## Local Handlers

The final-`y` handler changes `y` to `i`, appends the caller suffix, and checks.
The final-`d` and final-`t` handlers try doubled-last-letter forms, the local
`i...` suffix buffer, and selected one-byte rewrites before falling back to the
common append/check path.

```asm
suffix_by_local_handlers_C3000_74E4:
; file 0x374E4
3000:74E4  C6 45 FF 69       mov  byte [di-0x1],0x69
3000:74E8  FF 76 08          push word [bp+0x8]
3000:74EB  57                push di
3000:74EC  E8 1B 21          call 0x960a
3000:74EF  83 C4 04          add  sp,byte +0x4
3000:74F2  56                push si
3000:74F3  E8 F0 3B          call 0xb0e6
3000:74F6  83 C4 02          add  sp,byte +0x2
3000:74F9  0B C0             or   ax,ax
3000:74FB  74 09             jz   0x7506
3000:74FD  B8 01 00          mov  ax,0x1
3000:7500  5E                pop  si
3000:7501  5F                pop  di
3000:7502  8B E5             mov  sp,bp
3000:7504  5D                pop  bp
3000:7505  C3                ret
3000:7506  C6 45 FF 79       mov  byte [di-0x1],0x79
3000:750A  E9 59 01          jmp  0x7666
3000:750D  90                nop
3000:750E  8A 45 FF          mov  al,[di-0x1]
3000:7511  88 05             mov  [di],al
3000:7513  FF 76 08          push word [bp+0x8]
3000:7516  8D 45 01          lea  ax,[di+0x1]
3000:7519  50                push ax
3000:751A  E8 ED 20          call 0x960a
3000:751D  83 C4 04          add  sp,byte +0x4
3000:7520  56                push si
3000:7521  E8 C2 3B          call 0xb0e6
3000:7524  83 C4 02          add  sp,byte +0x2
3000:7527  0B C0             or   ax,ax
3000:7529  75 D2             jnz  0x74fd
3000:752B  8D 46 E8          lea  ax,[bp-0x18]
3000:752E  50                push ax
3000:752F  57                push di
3000:7530  E8 D7 20          call 0x960a
3000:7533  83 C4 04          add  sp,byte +0x4
3000:7536  56                push si
3000:7537  E8 AC 3B          call 0xb0e6
3000:753A  83 C4 02          add  sp,byte +0x2
3000:753D  0B C0             or   ax,ax
3000:753F  75 BC             jnz  0x74fd
3000:7541  C6 45 FF 73       mov  byte [di-0x1],0x73
3000:7545  56                push si
3000:7546  E8 9D 3B          call 0xb0e6
3000:7549  83 C4 02          add  sp,byte +0x2
3000:754C  0B C0             or   ax,ax
3000:754E  75 AD             jnz  0x74fd
3000:7550  C6 45 FF 64       mov  byte [di-0x1],0x64
3000:7554  E9 5E FF          jmp  0x74b5
```

```asm
suffix_by_t_e_handlers_C3000_7558:
; file 0x37558
3000:7558  8A 45 FF          mov  al,[di-0x1]
3000:755B  88 05             mov  [di],al
3000:755D  FF 76 08          push word [bp+0x8]
3000:7560  8D 45 01          lea  ax,[di+0x1]
3000:7563  50                push ax
3000:7564  E8 A3 20          call 0x960a
3000:7567  83 C4 04          add  sp,byte +0x4
3000:756A  56                push si
3000:756B  E8 78 3B          call 0xb0e6
3000:756E  83 C4 02          add  sp,byte +0x2
3000:7571  0B C0             or   ax,ax
3000:7573  75 88             jnz  0x74fd
3000:7575  80 7D FE 69       cmp  byte [di-0x2],0x69
3000:7579  75 27             jnz  0x75a2
3000:757B  C6 45 FF 73       mov  byte [di-0x1],0x73
3000:757F  C6 05 73          mov  byte [di],0x73
3000:7582  8D 46 E8          lea  ax,[bp-0x18]
3000:7585  50                push ax
3000:7586  8D 45 01          lea  ax,[di+0x1]
3000:7589  50                push ax
3000:758A  E8 7D 20          call 0x960a
3000:758D  83 C4 04          add  sp,byte +0x4
3000:7590  56                push si
3000:7591  E8 52 3B          call 0xb0e6
3000:7594  83 C4 02          add  sp,byte +0x2
3000:7597  0B C0             or   ax,ax
3000:7599  74 03             jz   0x759e
3000:759B  E9 5F FF          jmp  0x74fd
3000:759E  C6 45 FF 74       mov  byte [di-0x1],0x74
3000:75A2  8D 46 E8          lea  ax,[bp-0x18]
3000:75A5  50                push ax
3000:75A6  57                push di
3000:75A7  E8 60 20          call 0x960a
3000:75AA  83 C4 04          add  sp,byte +0x4
3000:75AD  56                push si
3000:75AE  E8 35 3B          call 0xb0e6
3000:75B1  83 C4 02          add  sp,byte +0x2
3000:75B4  0B C0             or   ax,ax
3000:75B6  74 03             jz   0x75bb
3000:75B8  E9 42 FF          jmp  0x74fd
3000:75BB  E9 F7 FE          jmp  0x74b5
3000:75BE  8A 45 FF          mov  al,[di-0x1]
3000:75C1  88 05             mov  [di],al
3000:75C3  FF 76 08          push word [bp+0x8]
3000:75C6  8D 45 01          lea  ax,[di+0x1]
3000:75C9  50                push ax
3000:75CA  EB DB             jmp  0x75a7
3000:75CC  FF 76 08          push word [bp+0x8]
3000:75CF  8D 45 FF          lea  ax,[di-0x1]
3000:75D2  50                push ax
3000:75D3  E8 34 20          call 0x960a
3000:75D6  83 C4 04          add  sp,byte +0x4
3000:75D9  56                push si
3000:75DA  E8 09 3B          call 0xb0e6
3000:75DD  83 C4 02          add  sp,byte +0x2
3000:75E0  0B C0             or   ax,ax
3000:75E2  74 03             jz   0x75e7
3000:75E4  E9 16 FF          jmp  0x74fd
3000:75E7  8D 46 E8          lea  ax,[bp-0x18]
3000:75EA  50                push ax
3000:75EB  8D 45 FF          lea  ax,[di-0x1]
3000:75EE  50                push ax
3000:75EF  E8 18 20          call 0x960a
3000:75F2  83 C4 04          add  sp,byte +0x4
3000:75F5  56                push si
3000:75F6  E8 ED 3A          call 0xb0e6
3000:75F9  83 C4 02          add  sp,byte +0x2
3000:75FC  0B C0             or   ax,ax
3000:75FE  74 03             jz   0x7603
3000:7600  E9 FA FE          jmp  0x74fd
3000:7603  80 7D FD 61       cmp  byte [di-0x3],0x61
3000:7607  75 25             jnz  0x762e
3000:7609  80 7D FE 74       cmp  byte [di-0x2],0x74
3000:760D  75 1F             jnz  0x762e
3000:760F  FF 76 08          push word [bp+0x8]
3000:7612  8D 45 FD          lea  ax,[di-0x3]
3000:7615  50                push ax
3000:7616  E8 F1 1F          call 0x960a
3000:7619  83 C4 04          add  sp,byte +0x4
3000:761C  56                push si
3000:761D  E8 C6 3A          call 0xb0e6
3000:7620  83 C4 02          add  sp,byte +0x2
3000:7623  0B C0             or   ax,ax
3000:7625  74 03             jz   0x762a
3000:7627  E9 D3 FE          jmp  0x74fd
3000:762A  C6 45 FE 74       mov  byte [di-0x2],0x74
3000:762E  C6 45 FF 65       mov  byte [di-0x1],0x65
3000:7632  E9 80 FE          jmp  0x74b5
```

`3000:7666` is the common table fallback: append the caller suffix and check;
if that fails, retry with the local `i...` suffix buffer.

```asm
suffix_by_common_fallback_C3000_7666:
; file 0x37666
3000:7666  FF 76 08          push word [bp+0x8]
3000:7669  57                push di
3000:766A  E8 9D 1F          call 0x960a
3000:766D  83 C4 04          add  sp,byte +0x4
3000:7670  56                push si
3000:7671  E8 72 3A          call 0xb0e6
3000:7674  83 C4 02          add  sp,byte +0x2
3000:7677  0B C0             or   ax,ax
3000:7679  74 03             jz   0x767e
3000:767B  E9 7F FE          jmp  0x74fd
3000:767E  8D 46 E8          lea  ax,[bp-0x18]
3000:7681  50                push ax
3000:7682  E9 33 FE          jmp  0x74b8
```

## Compound Builder

`3000:7686` is the shared compound/alternate candidate builder used by several
suffix handlers. It receives an output string, a destination cursor, and two
fragments. It builds two candidate strings in a stack buffer, checks each side
through `3000:B0E6`, and copies the surviving side back to the output. If both
sides survive, it inserts internal separator byte `0x0E` between them before
copying the combined string.

```asm
suffix_compound_builder_C3000_7686:
; file 0x37686
3000:7686  55                push bp
3000:7687  8B EC             mov  bp,sp
3000:7689  83 EC 34          sub  sp,byte +0x34
3000:768C  57                push di
3000:768D  56                push si
3000:768E  8B 76 04          mov  si,[bp+0x4]
3000:7691  8B 7E 06          mov  di,[bp+0x6]
3000:7694  C6 05 00          mov  byte [di],0
3000:7697  8D 46 CC          lea  ax,[bp-0x34]
3000:769A  89 46 FE          mov  [bp-0x2],ax
3000:769D  FF 76 08          push word [bp+0x8]
3000:76A0  56                push si
3000:76A1  8D 46 CC          lea  ax,[bp-0x34]
3000:76A4  50                push ax
3000:76A5  E8 62 1F          call 0x960a
3000:76A8  83 C4 04          add  sp,byte +0x4
3000:76AB  50                push ax
3000:76AC  E8 5B 1F          call 0x960a
3000:76AF  83 C4 04          add  sp,byte +0x4
3000:76B2  40                inc  ax
3000:76B3  89 46 FC          mov  [bp-0x4],ax
3000:76B6  FF 76 0A          push word [bp+0xa]
3000:76B9  56                push si
3000:76BA  50                push ax
3000:76BB  E8 4C 1F          call 0x960a
3000:76BE  83 C4 04          add  sp,byte +0x4
3000:76C1  50                push ax
3000:76C2  E8 45 1F          call 0x960a
3000:76C5  83 C4 04          add  sp,byte +0x4
3000:76C8  FF 76 FE          push word [bp-0x2]
3000:76CB  E8 18 3A          call 0xb0e6
3000:76CE  83 C4 02          add  sp,byte +0x2
3000:76D1  0B C0             or   ax,ax
3000:76D3  75 06             jnz  0x76db
3000:76D5  8B 46 FC          mov  ax,[bp-0x4]
3000:76D8  89 46 FE          mov  [bp-0x2],ax
3000:76DB  FF 76 FC          push word [bp-0x4]
3000:76DE  E8 05 3A          call 0xb0e6
3000:76E1  83 C4 02          add  sp,byte +0x2
3000:76E4  0B C0             or   ax,ax
3000:76E6  75 06             jnz  0x76ee
3000:76E8  8B 5E FC          mov  bx,[bp-0x4]
3000:76EB  C6 07 00          mov  byte [bx],0
3000:76EE  8B 5E FE          mov  bx,[bp-0x2]
3000:76F1  80 3F 00          cmp  byte [bx],0
3000:76F4  74 26             jz   0x771c
3000:76F6  8B 46 FC          mov  ax,[bp-0x4]
3000:76F9  3B D8             cmp  bx,ax
3000:76FB  74 0B             jz   0x7708
3000:76FD  8B D8             mov  bx,ax
3000:76FF  80 3F 00          cmp  byte [bx],0
3000:7702  74 04             jz   0x7708
3000:7704  C6 47 FF 0E       mov  byte [bx-0x1],0xe
3000:7708  FF 76 FE          push word [bp-0x2]
3000:770B  56                push si
3000:770C  E8 FB 1E          call 0x960a
3000:770F  83 C4 04          add  sp,byte +0x4
3000:7712  B8 01 00          mov  ax,0x1
3000:7715  5E                pop  si
3000:7716  5F                pop  di
3000:7717  8B E5             mov  sp,bp
3000:7719  5D                pop  bp
3000:771A  C3                ret
3000:771B  90                nop
3000:771C  2B C0             sub  ax,ax
3000:771E  5E                pop  si
3000:771F  5F                pop  di
3000:7720  8B E5             mov  sp,bp
3000:7722  5D                pop  bp
3000:7723  C3                ret
```

## Bottom

The compact helper, `b..y` dispatcher, and shared compound builder are now
mapped. The next suffix depth at `3000:7724` is documented in
[`banked-suffix-extended.md`](banked-suffix-extended.md).
