# Banked Suffix Dispatch

This slice maps the first suffix/word-form dispatcher reached from
[`banked-candidate-record-formatter.md`](banked-candidate-record-formatter.md).
It covers `3000:6ECE..7163`, where candidate text is mutated according to the
final character and each proposed form is checked through `3000:B0E6`.

No image assets are reached in this slice.

## Final-Letter Dispatcher

`3000:6ECE` receives the dictionary-check string in `[bp+04]`, an output cursor
in `[bp+06]`, and the caller selector/mode in `[bp+08]`. It reads the last
current output character from `[DI-1]`, subtracts `'e'`, and jumps through the
inline table at `3000:7124` for final letters `e..z`. Letters outside that
range fall to the default `3000:7150` path.

```asm
suffix_final_letter_dispatch_C3000_6ECE:
; file 0x36ECE
3000:6ECE  55                push bp
3000:6ECF  8B EC             mov  bp,sp
3000:6ED1  83 EC 30          sub  sp,byte +0x30
3000:6ED4  57                push di
3000:6ED5  56                push si
3000:6ED6  8B 76 04          mov  si,[bp+0x4]
3000:6ED9  8B 7E 06          mov  di,[bp+0x6]
3000:6EDC  8A 45 FF          mov  al,[di-0x1]
3000:6EDF  2A E4             sub  ah,ah
3000:6EE1  2D 65 00          sub  ax,0x65
3000:6EE4  3D 15 00          cmp  ax,0x15
3000:6EE7  76 03             jna  0x6eec
3000:6EE9  E9 64 02          jmp  0x7150
3000:6EEC  03 C0             add  ax,ax
3000:6EEE  93                xchg ax,bx
3000:6EEF  2E FF A7 24 71    jmp  [cs:bx+0x7124]
```

The jump table is data, not code:

| Final letter | Target | Notes |
| --- | --- | --- |
| `e` | `3000:7042` | Try appending `s`; special `f -> v` retry. |
| `f` | `3000:701A` | Avoid `ff`, otherwise try `s`, then `f -> ve`. |
| `h` | `3000:6F1C` | Try `s`, then fall back to `ie`. |
| `m` | `3000:70FC` | Mode `5` only; try `um -> ums` / `as` combination. |
| `n` | `3000:70D8` | Special `man -> men` style retry. |
| `o` | `3000:7086` | Mode `0x0A` has an `es` trial before combination fallback. |
| `s` | `3000:6F30` | Handles `is`, `us`, and appends runtime suffix `25A7`. |
| `u` | `3000:6FF8` | Combination helper path. |
| `x` | `3000:6F86` | Handles `ix`/`ex` style replacements and `es`. |
| `y` | `3000:6EF4` | Try `ys`; then `y -> ie` fallback. |
| `z` | `3000:7014` | Append runtime suffix `25AF`, then common `s` check. |
| other `e..z` letters | `3000:7150` | Append `s` and check. |

## Simple Mutations

Most paths mutate the output buffer in place, NUL-terminate it, and call
`3000:B0E6` with the original check string. A nonzero `B0E6` return means the
candidate exists and the helper returns `1`; otherwise the code restores or
tries another suffix.

```asm
suffix_simple_mutations_C3000_6EF4:
; file 0x36EF4
3000:6EF4  C6 05 73          mov  byte [di],0x73
3000:6EF7  C6 45 01 00       mov  byte [di+0x1],0
3000:6EFB  56                push si
3000:6EFC  E8 E7 41          call 0xb0e6
3000:6EFF  83 C4 02          add  sp,byte +0x2
3000:6F02  0B C0             or   ax,ax
3000:6F04  74 0A             jz   0x6f10
3000:6F06  B8 01 00          mov  ax,0x1
3000:6F09  5E                pop  si
3000:6F0A  5F                pop  di
3000:6F0B  8B E5             mov  sp,bp
3000:6F0D  5D                pop  bp
3000:6F0E  C3                ret
3000:6F0F  90                nop
3000:6F10  C6 45 FF 69       mov  byte [di-0x1],0x69
3000:6F14  C6 05 65          mov  byte [di],0x65
3000:6F17  47                inc  di
3000:6F18  E9 35 02          jmp  0x7150
3000:6F1B  90                nop
3000:6F1C  C6 05 73          mov  byte [di],0x73
3000:6F1F  C6 45 01 00       mov  byte [di+0x1],0
3000:6F23  56                push si
3000:6F24  E8 BF 41          call 0xb0e6
3000:6F27  83 C4 02          add  sp,byte +0x2
3000:6F2A  0B C0             or   ax,ax
3000:6F2C  74 E6             jz   0x6f14
3000:6F2E  EB D6             jmp  0x6f06
```

Final `s` first tests special endings. `is` is rewritten to `es` and checked;
in mode `5`, `us` is rewritten to `i` and checked. If both fail, the handler
appends runtime string `25A7` and reuses the common `s` check.

```asm
suffix_s_handler_C3000_6F30:
; file 0x36F30
3000:6F30  80 7D FE 69       cmp  byte [di-0x2],0x69
3000:6F34  75 1C             jnz  0x6f52
3000:6F36  80 7D FD 73       cmp  byte [di-0x3],0x73
3000:6F3A  75 16             jnz  0x6f52
3000:6F3C  C6 45 FE 65       mov  byte [di-0x2],0x65
3000:6F40  C6 05 00          mov  byte [di],0
3000:6F43  56                push si
3000:6F44  E8 9F 41          call 0xb0e6
3000:6F47  83 C4 02          add  sp,byte +0x2
3000:6F4A  0B C0             or   ax,ax
3000:6F4C  75 B8             jnz  0x6f06
3000:6F4E  C6 45 FE 69       mov  byte [di-0x2],0x69
3000:6F52  80 7D FE 75       cmp  byte [di-0x2],0x75
3000:6F56  75 21             jnz  0x6f79
3000:6F58  83 7E 08 05       cmp  word [bp+0x8],byte +0x5
3000:6F5C  75 1B             jnz  0x6f79
3000:6F5E  C6 45 FE 69       mov  byte [di-0x2],0x69
3000:6F62  C6 45 FF 00       mov  byte [di-0x1],0
3000:6F66  56                push si
3000:6F67  E8 7C 41          call 0xb0e6
3000:6F6A  83 C4 02          add  sp,byte +0x2
3000:6F6D  0B C0             or   ax,ax
3000:6F6F  75 95             jnz  0x6f06
3000:6F71  C6 45 FE 75       mov  byte [di-0x2],0x75
3000:6F75  C6 45 FF 73       mov  byte [di-0x1],0x73
3000:6F79  B8 A7 25          mov  ax,0x25a7
3000:6F7C  50                push ax
3000:6F7D  57                push di
3000:6F7E  E8 89 26          call 0x960a
3000:6F81  83 C4 04          add  sp,byte +0x4
3000:6F84  EB 9D             jmp  0x6f23
```

## Combination Paths

Several handlers build two temporary fragments at `[bp-30]` and `[bp-18]` and
then call `3000:7686`. That helper tries a compound/alternate candidate made
from the original output tail, the two fragments, and the dictionary-check
string. This slice treats `3000:7686` as a boundary; it is summarized in
[`../spell-engine.md`](../spell-engine.md).

```asm
suffix_x_u_combination_C3000_6F86:
; file 0x36F86
3000:6F86  80 7D FE 69       cmp  byte [di-0x2],0x69
3000:6F8A  74 06             jz   0x6f92
3000:6F8C  80 7D FE 65       cmp  byte [di-0x2],0x65
3000:6F90  75 4A             jnz  0x6fdc
3000:6F92  83 7E 08 05       cmp  word [bp+0x8],byte +0x5
3000:6F96  75 44             jnz  0x6fdc
3000:6F98  8A 45 FE          mov  al,[di-0x2]
3000:6F9B  88 46 E8          mov  [bp-0x18],al
3000:6F9E  B8 AB 25          mov  ax,0x25ab
3000:6FA1  50                push ax
3000:6FA2  8D 46 E9          lea  ax,[bp-0x17]
3000:6FA5  50                push ax
3000:6FA6  E8 61 26          call 0x960a
3000:6FA9  83 C4 04          add  sp,byte +0x4
3000:6FAC  8D 46 E8          lea  ax,[bp-0x18]
3000:6FAF  50                push ax
3000:6FB0  8D 46 D0          lea  ax,[bp-0x30]
3000:6FB3  50                push ax
3000:6FB4  E8 53 26          call 0x960a
3000:6FB7  83 C4 04          add  sp,byte +0x4
3000:6FBA  C6 46 D0 69       mov  byte [bp-0x30],0x69
3000:6FBE  C6 46 D1 63       mov  byte [bp-0x2f],0x63
3000:6FC2  8D 46 D0          lea  ax,[bp-0x30]
3000:6FC5  50                push ax
3000:6FC6  8D 46 E8          lea  ax,[bp-0x18]
3000:6FC9  50                push ax
3000:6FCA  8D 45 FE          lea  ax,[di-0x2]
3000:6FCD  50                push ax
3000:6FCE  56                push si
3000:6FCF  E8 B4 06          call 0x7686
3000:6FD2  83 C4 08          add  sp,byte +0x8
3000:6FD5  5E                pop  si
3000:6FD6  5F                pop  di
3000:6FD7  8B E5             mov  sp,bp
3000:6FD9  5D                pop  bp
3000:6FDA  C3                ret
3000:6FDB  90                nop
3000:6FDC  C6 05 65          mov  byte [di],0x65
3000:6FDF  47                inc  di
3000:6FE0  C6 05 73          mov  byte [di],0x73
3000:6FE3  47                inc  di
3000:6FE4  C6 05 00          mov  byte [di],0
3000:6FE7  56                push si
3000:6FE8  E8 FB 40          call 0xb0e6
3000:6FEB  83 C4 02          add  sp,byte +0x2
3000:6FEE  0B C0             or   ax,ax
3000:6FF0  74 03             jz   0x6ff5
3000:6FF2  E9 11 FF          jmp  0x6f06
3000:6FF5  C6 04 00          mov  byte [si],0
3000:6FF8  C6 46 E8 73       mov  byte [bp-0x18],0x73
3000:6FFC  C6 46 D0 78       mov  byte [bp-0x30],0x78
3000:7000  2A C0             sub  al,al
3000:7002  88 46 D1          mov  [bp-0x2f],al
3000:7005  88 46 E9          mov  [bp-0x17],al
3000:7008  8D 46 D0          lea  ax,[bp-0x30]
3000:700B  50                push ax
3000:700C  8D 46 E8          lea  ax,[bp-0x18]
3000:700F  50                push ax
3000:7010  57                push di
3000:7011  EB BB             jmp  0x6fce
3000:7013  90                nop
3000:7014  B8 AF 25          mov  ax,0x25af
3000:7017  E9 62 FF          jmp  0x6f7c
```

## Remaining Handlers

Final `f`, `e`, `o`, `n`, and `m` have small special cases before falling back
to `3000:7150` or a combination path. The `o` handler tests a bit mask of
preceding letters in mode `0x0A` before trying `es`.

```asm
suffix_remaining_handlers_C3000_701A:
; file 0x3701A
3000:701A  80 7D FE 66       cmp  byte [di-0x2],0x66
3000:701E  75 03             jnz  0x7023
3000:7020  E9 2D 01          jmp  0x7150
3000:7023  C6 05 73          mov  byte [di],0x73
3000:7026  47                inc  di
3000:7027  C6 05 00          mov  byte [di],0
3000:702A  56                push si
3000:702B  E8 B8 40          call 0xb0e6
3000:702E  83 C4 02          add  sp,byte +0x2
3000:7031  0B C0             or   ax,ax
3000:7033  74 03             jz   0x7038
3000:7035  E9 CE FE          jmp  0x6f06
3000:7038  83 EF 02          sub  di,byte +0x2
3000:703B  C6 05 76          mov  byte [di],0x76
3000:703E  47                inc  di
3000:703F  E9 D2 FE          jmp  0x6f14
3000:7042  80 7D FD 65       cmp  byte [di-0x3],0x65
3000:7046  75 09             jnz  0x7051
3000:7048  80 7D FE 73       cmp  byte [di-0x2],0x73
3000:704C  75 03             jnz  0x7051
3000:704E  E9 B5 FE          jmp  0x6f06
3000:7051  C6 05 73          mov  byte [di],0x73
3000:7054  C6 45 01 00       mov  byte [di+0x1],0
3000:7058  56                push si
3000:7059  E8 8A 40          call 0xb0e6
3000:705C  83 C4 02          add  sp,byte +0x2
3000:705F  0B C0             or   ax,ax
3000:7061  74 03             jz   0x7066
3000:7063  E9 A0 FE          jmp  0x6f06
3000:7066  80 7D FE 66       cmp  byte [di-0x2],0x66
3000:706A  75 12             jnz  0x707e
3000:706C  C6 45 FE 76       mov  byte [di-0x2],0x76
3000:7070  56                push si
3000:7071  E8 72 40          call 0xb0e6
3000:7074  83 C4 02          add  sp,byte +0x2
3000:7077  0B C0             or   ax,ax
3000:7079  74 03             jz   0x707e
3000:707B  E9 88 FE          jmp  0x6f06
3000:707E  2B C0             sub  ax,ax
3000:7080  5E                pop  si
3000:7081  5F                pop  di
3000:7082  8B E5             mov  sp,bp
3000:7084  5D                pop  bp
3000:7085  C3                ret
3000:7086  83 7E 08 0A       cmp  word [bp+0x8],byte +0xa
3000:708A  75 34             jnz  0x70c0
3000:708C  B8 01 00          mov  ax,0x1
3000:708F  8A 4D FE          mov  cl,[di-0x2]
3000:7092  80 E9 61          sub  cl,0x61
3000:7095  D3 E0             shl  ax,cl
3000:7097  99                cwd
3000:7098  25 11 41          and  ax,0x4111
3000:709B  81 E2 10 01       and  dx,0x110
3000:709F  0B D0             or   dx,ax
3000:70A1  75 1D             jnz  0x70c0
3000:70A3  C6 05 65          mov  byte [di],0x65
3000:70A6  C6 45 01 73       mov  byte [di+0x1],0x73
3000:70AA  C6 45 02 00       mov  byte [di+0x2],0
3000:70AE  56                push si
3000:70AF  E8 34 40          call 0xb0e6
3000:70B2  83 C4 02          add  sp,byte +0x2
3000:70B5  0B C0             or   ax,ax
3000:70B7  75 03             jnz  0x70bc
3000:70B9  E9 94 00          jmp  0x7150
3000:70BC  E9 47 FE          jmp  0x6f06
3000:70BF  90                nop
3000:70C0  C6 46 E8 65       mov  byte [bp-0x18],0x65
3000:70C4  C6 46 E9 73       mov  byte [bp-0x17],0x73
3000:70C8  C6 46 D0 73       mov  byte [bp-0x30],0x73
3000:70CC  2A C0             sub  al,al
3000:70CE  88 46 D1          mov  [bp-0x2f],al
3000:70D1  88 46 EA          mov  [bp-0x16],al
3000:70D4  E9 31 FF          jmp  0x7008
3000:70D7  90                nop
3000:70D8  80 7D FE 61       cmp  byte [di-0x2],0x61
3000:70DC  75 72             jnz  0x7150
3000:70DE  80 7D FD 6D       cmp  byte [di-0x3],0x6d
3000:70E2  75 6C             jnz  0x7150
3000:70E4  C6 45 FE 65       mov  byte [di-0x2],0x65
3000:70E8  56                push si
3000:70E9  E8 FA 3F          call 0xb0e6
3000:70EC  83 C4 02          add  sp,byte +0x2
3000:70EF  0B C0             or   ax,ax
3000:70F1  74 03             jz   0x70f6
3000:70F3  E9 10 FE          jmp  0x6f06
3000:70F6  C6 45 FE 61       mov  byte [di-0x2],0x61
3000:70FA  EB 54             jmp  0x7150
3000:70FC  80 7D FE 75       cmp  byte [di-0x2],0x75
3000:7100  75 4E             jnz  0x7150
3000:7102  83 7E 08 05       cmp  word [bp+0x8],byte +0x5
3000:7106  75 48             jnz  0x7150
3000:7108  C6 46 E8 75       mov  byte [bp-0x18],0x75
3000:710C  C6 46 E9 6D       mov  byte [bp-0x17],0x6d
3000:7110  C6 46 EA 73       mov  byte [bp-0x16],0x73
3000:7114  C6 46 D0 61       mov  byte [bp-0x30],0x61
3000:7118  2A C0             sub  al,al
3000:711A  88 46 D1          mov  [bp-0x2f],al
3000:711D  88 46 EB          mov  [bp-0x15],al
3000:7120  E9 9F FE          jmp  0x6fc2
```

## Default Check

The default path appends `s`, terminates the output, calls `3000:B0E6`, and
returns that result directly. This is also the target for unsupported final
letters and many failed special cases.

```asm
suffix_default_s_check_C3000_7150:
; file 0x37150
3000:7150  C6 05 73          mov  byte [di],0x73
3000:7153  47                inc  di
3000:7154  C6 05 00          mov  byte [di],0
3000:7157  56                push si
3000:7158  E8 8B 3F          call 0xb0e6
3000:715B  83 C4 02          add  sp,byte +0x2
3000:715E  5E                pop  si
3000:715F  5F                pop  di
3000:7160  8B E5             mov  sp,bp
3000:7162  5D                pop  bp
3000:7163  C3                ret
```

## Bottom

The first suffix dispatcher is now mapped through its final-letter table and
all local mutation handlers. The next handler family at `3000:7164` is expanded
in [`banked-suffix-secondary.md`](banked-suffix-secondary.md). Remaining suffix
depth starts at `3000:7432`/`3000:748E` and at helper `3000:7686`, which builds
compound/alternate candidates before checking them.
