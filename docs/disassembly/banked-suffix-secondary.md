# Banked Secondary Suffix Handlers

This slice maps the suffix-handler family after
[`banked-suffix-dispatch.md`](banked-suffix-dispatch.md). It covers
`3000:7164..742E`, including the `3000:7164` helper reached from the candidate
record formatter and the larger `3000:721C` final-letter dispatcher.

No image assets are reached in this slice.

## C/E/L/Y Helper

`3000:7164` receives the same three suffix arguments as `3000:6ECE`: dictionary
check string, output cursor, and a runtime suffix/string pointer. It handles
final `c`, `e`, `l`, and `y` cases directly:

- final `y`: change final `y` to `i`, append the runtime suffix, and check with
  `3000:B0E6`; if that fails, restore `y` and check the unmodified suffix form;
- final `ll`: shorten to one `l`, append the runtime suffix, and check;
- final `ble`: rewrite final `e` to `y`, check, then fall back to the generic
  append/check path;
- final `c`: append the runtime suffix and check; if that fails and the
  preceding letter is `i` or `a`, append runtime string `25B3` instead.

```asm
suffix_cely_helper_C3000_7164:
; file 0x37164
3000:7164  55                push bp
3000:7165  8B EC             mov  bp,sp
3000:7167  57                push di
3000:7168  56                push si
3000:7169  8B 76 04          mov  si,[bp+0x4]
3000:716C  8B 7E 06          mov  di,[bp+0x6]
3000:716F  8A 45 FF          mov  al,[di-0x1]
3000:7172  2A E4             sub  ah,ah
3000:7174  3D 63 00          cmp  ax,0x63
3000:7177  74 75             jz   0x71ee
3000:7179  3D 65 00          cmp  ax,0x65
3000:717C  74 50             jz   0x71ce
3000:717E  3D 6C 00          cmp  ax,0x6c
3000:7181  74 37             jz   0x71ba
3000:7183  3D 79 00          cmp  ax,0x79
3000:7186  75 39             jnz  0x71c1
3000:7188  C6 45 FF 69       mov  byte [di-0x1],0x69
3000:718C  FF 76 08          push word [bp+0x8]
3000:718F  57                push di
3000:7190  E8 77 24          call 0x960a
3000:7193  83 C4 04          add  sp,byte +0x4
3000:7196  56                push si
3000:7197  E8 4C 3F          call 0xb0e6
3000:719A  83 C4 02          add  sp,byte +0x2
3000:719D  0B C0             or   ax,ax
3000:719F  74 09             jz   0x71aa
3000:71A1  B8 01 00          mov  ax,0x1
3000:71A4  5E                pop  si
3000:71A5  5F                pop  di
3000:71A6  5D                pop  bp
3000:71A7  C3                ret
3000:71A8  90                nop
3000:71A9  90                nop
3000:71AA  C6 45 FF 79       mov  byte [di-0x1],0x79
3000:71AE  56                push si
3000:71AF  E8 34 3F          call 0xb0e6
3000:71B2  83 C4 02          add  sp,byte +0x2
3000:71B5  5E                pop  si
3000:71B6  5F                pop  di
3000:71B7  5D                pop  bp
3000:71B8  C3                ret
3000:71B9  90                nop
3000:71BA  80 7D FE 6C       cmp  byte [di-0x2],0x6c
3000:71BE  75 01             jnz  0x71c1
3000:71C0  4F                dec  di
3000:71C1  FF 76 08          push word [bp+0x8]
3000:71C4  57                push di
3000:71C5  E8 42 24          call 0x960a
3000:71C8  83 C4 04          add  sp,byte +0x4
3000:71CB  EB E1             jmp  0x71ae
3000:71CD  90                nop
3000:71CE  80 7D FE 6C       cmp  byte [di-0x2],0x6c
3000:71D2  75 ED             jnz  0x71c1
3000:71D4  80 7D FD 62       cmp  byte [di-0x3],0x62
3000:71D8  75 E7             jnz  0x71c1
3000:71DA  C6 45 FF 79       mov  byte [di-0x1],0x79
3000:71DE  C6 05 00          mov  byte [di],0
3000:71E1  56                push si
3000:71E2  E8 01 3F          call 0xb0e6
3000:71E5  83 C4 02          add  sp,byte +0x2
3000:71E8  0B C0             or   ax,ax
3000:71EA  75 B5             jnz  0x71a1
3000:71EC  EB D3             jmp  0x71c1
3000:71EE  FF 76 08          push word [bp+0x8]
3000:71F1  57                push di
3000:71F2  E8 15 24          call 0x960a
3000:71F5  83 C4 04          add  sp,byte +0x4
3000:71F8  56                push si
3000:71F9  E8 EA 3E          call 0xb0e6
3000:71FC  83 C4 02          add  sp,byte +0x2
3000:71FF  0B C0             or   ax,ax
3000:7201  75 9E             jnz  0x71a1
3000:7203  80 7D FE 69       cmp  byte [di-0x2],0x69
3000:7207  74 06             jz   0x720f
3000:7209  80 7D FE 61       cmp  byte [di-0x2],0x61
3000:720D  75 07             jnz  0x7216
3000:720F  B8 B3 25          mov  ax,0x25b3
3000:7212  50                push ax
3000:7213  EB AF             jmp  0x71c4
3000:7215  90                nop
3000:7216  2B C0             sub  ax,ax
3000:7218  5E                pop  si
3000:7219  5F                pop  di
3000:721A  5D                pop  bp
3000:721B  C3                ret
```

## A-Y Dispatcher

`3000:721C` handles another suffix family. If the active record type at
`[7134+6]` is `0x13`, it only appends the runtime suffix and optionally retries
`y -> i`. Other record types dispatch on the final output letter in the range
`a..y` through the inline table at `3000:73F2`.

```asm
suffix_ay_dispatch_C3000_721C:
; file 0x3721C
3000:721C  55                push bp
3000:721D  8B EC             mov  bp,sp
3000:721F  83 EC 30          sub  sp,byte +0x30
3000:7222  57                push di
3000:7223  56                push si
3000:7224  8B 76 04          mov  si,[bp+0x4]
3000:7227  8B 7E 06          mov  di,[bp+0x6]
3000:722A  8B 1E 34 71       mov  bx,[0x7134]
3000:722E  83 7F 06 13       cmp  word [bx+0x6],byte +0x13
3000:7232  75 3E             jnz  0x7272
3000:7234  FF 76 08          push word [bp+0x8]
3000:7237  57                push di
3000:7238  E8 CF 23          call 0x960a
3000:723B  83 C4 04          add  sp,byte +0x4
3000:723E  56                push si
3000:723F  E8 A4 3E          call 0xb0e6
3000:7242  83 C4 02          add  sp,byte +0x2
3000:7245  0B C0             or   ax,ax
3000:7247  74 09             jz   0x7252
3000:7249  B8 01 00          mov  ax,0x1
3000:724C  5E                pop  si
3000:724D  5F                pop  di
3000:724E  8B E5             mov  sp,bp
3000:7250  5D                pop  bp
3000:7251  C3                ret
3000:7252  80 7D FF 79       cmp  byte [di-0x1],0x79
3000:7256  75 12             jnz  0x726a
3000:7258  C6 45 FF 69       mov  byte [di-0x1],0x69
3000:725C  56                push si
3000:725D  E8 86 3E          call 0xb0e6
3000:7260  83 C4 02          add  sp,byte +0x2
3000:7263  5E                pop  si
3000:7264  5F                pop  di
3000:7265  8B E5             mov  sp,bp
3000:7267  5D                pop  bp
3000:7268  C3                ret
3000:7269  90                nop
3000:726A  2B C0             sub  ax,ax
3000:726C  5E                pop  si
3000:726D  5F                pop  di
3000:726E  8B E5             mov  sp,bp
3000:7270  5D                pop  bp
3000:7271  C3                ret
3000:7272  8A 45 FF          mov  al,[di-0x1]
3000:7275  2A E4             sub  ah,ah
3000:7277  2D 61 00          sub  ax,0x61
3000:727A  3D 18 00          cmp  ax,0x18
3000:727D  76 03             jna  0x7282
3000:727F  E9 52 01          jmp  0x73d4
3000:7282  03 C0             add  ax,ax
3000:7284  93                xchg ax,bx
3000:7285  2E FF A7 F2 73    jmp  [cs:bx+0x73f2]
```

The `3000:73F2` table is data:

| Final letter | Target |
| --- | --- |
| `a`, `i`, `o`, `u` | `3000:7424` |
| `c` | `3000:735A` |
| `e` | `3000:72AA` |
| `h` | `3000:733E` |
| `l` | `3000:7386` |
| `s` | `3000:73BC` |
| `y` | `3000:728A` |
| other `a..y` letters | `3000:73D4` |

## Dispatcher Handlers

The `y` handler rewrites final `y` to `i`, appends the runtime suffix, checks
the candidate, and falls through to generic duplication when that fails. The
`e` handler has an extra record-type `0x17` path that tries a compound
candidate through `3000:7686` when the preceding character is `i`; otherwise it
tries appending the runtime suffix, then removing the final character, and then
adding `e`.

```asm
suffix_ay_handlers_C3000_728A:
; file 0x3728A
3000:728A  C6 45 FF 69       mov  byte [di-0x1],0x69
3000:728E  FF 76 08          push word [bp+0x8]
3000:7291  57                push di
3000:7292  E8 75 23          call 0x960a
3000:7295  83 C4 04          add  sp,byte +0x4
3000:7298  56                push si
3000:7299  E8 4A 3E          call 0xb0e6
3000:729C  83 C4 02          add  sp,byte +0x2
3000:729F  0B C0             or   ax,ax
3000:72A1  75 A6             jnz  0x7249
3000:72A3  C6 45 FF 79       mov  byte [di-0x1],0x79
3000:72A7  E9 7A 01          jmp  0x7424
3000:72AA  8B 1E 34 71       mov  bx,[0x7134]
3000:72AE  83 7F 06 17       cmp  word [bx+0x6],byte +0x17
3000:72B2  75 6A             jnz  0x731e
3000:72B4  80 7D FE 69       cmp  byte [di-0x2],0x69
3000:72B8  75 46             jnz  0x7300
3000:72BA  83 EF 02          sub  di,byte +0x2
3000:72BD  FF 76 08          push word [bp+0x8]
3000:72C0  57                push di
3000:72C1  8D 46 D0          lea  ax,[bp-0x30]
3000:72C4  50                push ax
3000:72C5  E8 42 23          call 0x960a
3000:72C8  83 C4 04          add  sp,byte +0x4
3000:72CB  50                push ax
3000:72CC  E8 3B 23          call 0x960a
3000:72CF  83 C4 04          add  sp,byte +0x4
3000:72D2  C6 46 E8 79       mov  byte [bp-0x18],0x79
3000:72D6  FF 76 08          push word [bp+0x8]
3000:72D9  8D 46 E9          lea  ax,[bp-0x17]
3000:72DC  50                push ax
3000:72DD  E8 2A 23          call 0x960a
3000:72E0  83 C4 04          add  sp,byte +0x4
3000:72E3  8D 46 D0          lea  ax,[bp-0x30]
3000:72E6  50                push ax
3000:72E7  8D 46 E8          lea  ax,[bp-0x18]
3000:72EA  50                push ax
3000:72EB  57                push di
3000:72EC  56                push si
3000:72ED  E8 96 03          call 0x7686
3000:72F0  83 C4 08          add  sp,byte +0x8
3000:72F3  0B C0             or   ax,ax
3000:72F5  74 03             jz   0x72fa
3000:72F7  E9 4F FF          jmp  0x7249
3000:72FA  83 C7 02          add  di,byte +0x2
3000:72FD  EB 1F             jmp  0x731e
3000:72FF  90                nop
3000:7300  80 7D FE 79       cmp  byte [di-0x2],0x79
3000:7304  75 18             jnz  0x731e
3000:7306  FF 76 08          push word [bp+0x8]
3000:7309  57                push di
3000:730A  E8 FD 22          call 0x960a
3000:730D  83 C4 04          add  sp,byte +0x4
3000:7310  56                push si
3000:7311  E8 D2 3D          call 0xb0e6
3000:7314  83 C4 02          add  sp,byte +0x2
3000:7317  0B C0             or   ax,ax
3000:7319  74 03             jz   0x731e
3000:731B  E9 2B FF          jmp  0x7249
3000:731E  4F                dec  di
3000:731F  FF 76 08          push word [bp+0x8]
3000:7322  57                push di
3000:7323  E8 E4 22          call 0x960a
3000:7326  83 C4 04          add  sp,byte +0x4
3000:7329  56                push si
3000:732A  E8 B9 3D          call 0xb0e6
3000:732D  83 C4 02          add  sp,byte +0x2
3000:7330  0B C0             or   ax,ax
3000:7332  74 03             jz   0x7337
3000:7334  E9 12 FF          jmp  0x7249
3000:7337  C6 05 65          mov  byte [di],0x65
3000:733A  47                inc  di
3000:733B  E9 E6 00          jmp  0x7424
```

Other handlers are small variants: `h` performs a direct append/check; `c`
tries adding `k` after `a` or `i`; `l` goes through `3000:7686`; `s` uses a
direct append/check; and the generic path duplicates the final character before
appending the runtime suffix.

```asm
suffix_ay_small_handlers_C3000_733E:
; file 0x3733E
3000:733E  FF 76 08          push word [bp+0x8]
3000:7341  57                push di
3000:7342  E8 C5 22          call 0x960a
3000:7345  83 C4 04          add  sp,byte +0x4
3000:7348  56                push si
3000:7349  E8 9A 3D          call 0xb0e6
3000:734C  83 C4 02          add  sp,byte +0x2
3000:734F  0B C0             or   ax,ax
3000:7351  75 03             jnz  0x7356
3000:7353  E9 CE 00          jmp  0x7424
3000:7356  E9 F0 FE          jmp  0x7249
3000:7359  90                nop
3000:735A  80 7D FE 61       cmp  byte [di-0x2],0x61
3000:735E  74 06             jz   0x7366
3000:7360  80 7D FE 69       cmp  byte [di-0x2],0x69
3000:7364  75 1C             jnz  0x7382
3000:7366  C6 05 6B          mov  byte [di],0x6b
3000:7369  47                inc  di
3000:736A  FF 76 08          push word [bp+0x8]
3000:736D  57                push di
3000:736E  E8 99 22          call 0x960a
3000:7371  83 C4 04          add  sp,byte +0x4
3000:7374  56                push si
3000:7375  E8 6E 3D          call 0xb0e6
3000:7378  83 C4 02          add  sp,byte +0x2
3000:737B  0B C0             or   ax,ax
3000:737D  74 03             jz   0x7382
3000:737F  E9 C7 FE          jmp  0x7249
3000:7382  4F                dec  di
3000:7383  E9 9E 00          jmp  0x7424
3000:7386  FF 76 08          push word [bp+0x8]
3000:7389  8D 46 E8          lea  ax,[bp-0x18]
3000:738C  50                push ax
3000:738D  E8 7A 22          call 0x960a
3000:7390  83 C4 04          add  sp,byte +0x4
3000:7393  8A 45 FF          mov  al,[di-0x1]
3000:7396  88 46 D0          mov  [bp-0x30],al
3000:7399  FF 76 08          push word [bp+0x8]
3000:739C  8D 46 D1          lea  ax,[bp-0x2f]
3000:739F  50                push ax
3000:73A0  E8 67 22          call 0x960a
3000:73A3  83 C4 04          add  sp,byte +0x4
3000:73A6  8D 46 D0          lea  ax,[bp-0x30]
3000:73A9  50                push ax
3000:73AA  8D 46 E8          lea  ax,[bp-0x18]
3000:73AD  50                push ax
3000:73AE  57                push di
3000:73AF  56                push si
3000:73B0  E8 D3 02          call 0x7686
3000:73B3  83 C4 08          add  sp,byte +0x8
3000:73B6  5E                pop  si
3000:73B7  5F                pop  di
3000:73B8  8B E5             mov  sp,bp
3000:73BA  5D                pop  bp
3000:73BB  C3                ret
3000:73BC  FF 76 08          push word [bp+0x8]
3000:73BF  57                push di
3000:73C0  E8 47 22          call 0x960a
3000:73C3  83 C4 04          add  sp,byte +0x4
3000:73C6  56                push si
3000:73C7  E8 1C 3D          call 0xb0e6
3000:73CA  83 C4 02          add  sp,byte +0x2
3000:73CD  0B C0             or   ax,ax
3000:73CF  74 03             jz   0x73d4
3000:73D1  E9 75 FE          jmp  0x7249
3000:73D4  8A 45 FF          mov  al,[di-0x1]
3000:73D7  88 05             mov  [di],al
3000:73D9  47                inc  di
3000:73DA  FF 76 08          push word [bp+0x8]
3000:73DD  57                push di
3000:73DE  E8 29 22          call 0x960a
3000:73E1  83 C4 04          add  sp,byte +0x4
3000:73E4  56                push si
3000:73E5  E8 FE 3C          call 0xb0e6
3000:73E8  83 C4 02          add  sp,byte +0x2
3000:73EB  0B C0             or   ax,ax
3000:73ED  74 93             jz   0x7382
3000:73EF  E9 57 FE          jmp  0x7249
```

`3000:7424` is a common retry that appends the runtime suffix and then reuses
the `y -> i` check at `3000:725C`.

```asm
suffix_ay_common_retry_C3000_7424:
; file 0x37424
3000:7424  FF 76 08          push word [bp+0x8]
3000:7427  57                push di
3000:7428  E8 DF 21          call 0x960a
3000:742B  83 C4 04          add  sp,byte +0x4
3000:742E  E9 2B FE          jmp  0x725c
```

## Bottom

The `3000:7164` and `3000:721C` suffix helpers are now mapped through their
local final-letter dispatch, direct dictionary checks, and `3000:7686`
combination handoffs. The `3000:7432`/`3000:748E` helpers and shared compound
builder are expanded in [`banked-suffix-tertiary.md`](banked-suffix-tertiary.md).
