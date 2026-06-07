# Banked Linguistic Services

This slice maps the service-call boundary used by the spelling, grammar,
dictionary, and thesaurus UI front ends. It complements
[`wp-linguistic-tools.md`](wp-linguistic-tools.md), which maps the C688 editor
screens, and [`../spell-engine.md`](../spell-engine.md), which tracks the deep
banked parser, candidate, and dictionary data structures.

No image assets are reached in this slice.

## Call Path

The C688 applications call `C688:936A`, a far wrapper to `C000:1712`:

```asm
linguistic_far_wrapper_C688_936A:
; file 0x4FBEA
C688:936A  9A 12 17 00 C0    call 0xc000:0x1712
C688:936F  C3                ret
```

`C000:1712` calls the `AH` subdispatcher at `C000:1873` and returns far to the
application. The editor-facing linguistic calls use two paths:

| Caller-side `AH` | C000 path | Effective service ID |
| ---: | --- | --- |
| `0x04` | direct `C000:18A1` | `DL` unchanged |
| `0x05` | `C000:189E`, then `C000:18A1` | `DL + 0x3C` |

The `AH=05` adjustment is tiny but important: it maps C688 UI selections
`DL=1..9`, `0x0A`, and `0x0B` to banked services `0x3D..0x45`, `0x46`, and
`0x47`.

```asm
linguistic_ah05_adjust_C000_189E:
; file 0x4189E
C000:189E  80 C2 3C          add  dl,0x3c

banked_linguistic_mapper_C000_18A1:
C000:18A1  32 F6             xor  dh,dh
C000:18A3  E8 A3 00          call 0x1949
C000:18A6  FA                cli
C000:18A7  B0 02             mov  al,0x2
C000:18A9  E6 11             out  0x11,al
C000:18AB  8A E0             mov  ah,al
C000:18AD  B0 17             mov  al,0x17
C000:18AF  E6 12             out  0x12,al
C000:18B1  A3 8D 6D          mov  [0x6d8d],ax
C000:18B4  B0 03             mov  al,0x3
C000:18B6  E6 13             out  0x13,al
C000:18B8  8A E0             mov  ah,al
C000:18BA  B0 02             mov  al,0x2
C000:18BC  E6 14             out  0x14,al
C000:18BE  A3 8F 6D          mov  [0x6d8f],ax
C000:18C1  2E FF 1E 9A 18    call far [cs:0x189a]
C000:18C6  50                push ax
C000:18C7  B0 0E             mov  al,0xe
C000:18C9  E6 11             out  0x11,al
```

`C000:18A1` maps the banked engine, calls the far pointer at `C000:189A`
(`3000:0000` while mapped), restores the normal banks, stores returned `AL` in
`[8DA7]`, and returns to the C688 caller.

## Banked Dispatcher

Inside the mapped engine, `3000:4AA6` dispatches services `0x00..0x59`. Values
above `0x59` and many table entries fall to the common error return
`3000:4C02`, which returns `AX=FFFF`.

```asm
banked_linguistic_dispatch_C3000_4AA6:
; file 0x34AA6
3000:4AA6  55                push bp
3000:4AA7  8B EC             mov  bp,sp
3000:4AA9  83 EC 02          sub  sp,byte +0x2
3000:4AAC  C7 06 D8 6B 00 00 mov  word [0x6bd8],0
3000:4AB2  8B 46 04          mov  ax,[bp+0x4]
3000:4AB5  3D 59 00          cmp  ax,0x59
3000:4AB8  76 03             jna  0x4abd
3000:4ABA  E9 45 01          jmp  0x4c02
3000:4ABD  03 C0             add  ax,ax
3000:4ABF  93                xchg ax,bx
3000:4AC0  2E FF A7 0A 4C    jmp  [cs:bx+0x4c0a]
```

The jump table lives at file `0x34C0A` / `3000:4C0A`. It is table data, not
code. Grouped by target:

| Target | Service IDs |
| --- | --- |
| `3000:4AC6` | `0x00` |
| `3000:4ACC` | `0x01` |
| `3000:4AD2` | `0x02` |
| `3000:4AD8` | `0x03` |
| `3000:4AE8` | `0x04` |
| `3000:4AEC` | `0x07` |
| `3000:4AF8` | `0x08` |
| `3000:4AFC` | `0x09` |
| `3000:4B0A` | `0x0A` |
| `3000:4B0E` | `0x0F` |
| `3000:4B14` | `0x10` |
| `3000:4B20` | `0x11` |
| `3000:4B24` | `0x12` |
| `3000:4B30` | `0x13` |
| `3000:4B34` | `0x14` |
| `3000:4B40` | `0x15` |
| `3000:4B4C` | `0x16` |
| `3000:4B3A` | `0x17` |
| `3000:4B50` | `0x18` |
| `3000:4B58` | `0x19` |
| `3000:4B60` | `0x1B` |
| `3000:4B66` | `0x1C` |
| `3000:4B6C` | `0x1D` |
| `3000:4B74` | `0x1E` |
| `3000:4B7A` | `0x1F` |
| `3000:4B80` | `0x23` |
| `3000:4B88` | `0x24` |
| `3000:4B92` | `0x25` |
| `3000:4B98` | `0x28` |
| `3000:4B9E` | `0x29` |
| `3000:4BA4` | `0x2A` |
| `3000:4BAE` | `0x30` |
| `3000:4BB4` | `0x31` |
| `3000:4BBA` | `0x32` |
| `3000:4BC2` | `0x3C` |
| `3000:4BCA` | `0x3D..0x45` |
| `3000:4BDE` | `0x46` |
| `3000:4BE8` | `0x47` |
| `3000:4BF2` | `0x58` |
| `3000:4BFA` | `0x59` |
| `3000:4C02` | `0x05..0x06`, `0x0B..0x0E`, `0x1A`, `0x20..0x22`, `0x26..0x27`, `0x2B..0x2F`, `0x33..0x3B`, `0x48..0x57` |

## Editor-Facing Service Stubs

The compact service stubs around `3000:4B80` match the C688 linguistic tools:

```asm
service_query_active_slot_C3000_4B80:
; file 0x34B80
3000:4B80  A1 04 60          mov  ax,[0x6004]
3000:4B83  40                inc  ax
3000:4B84  E9 37 01          jmp  0x4cbe

service_select_slot0_C3000_4B88:
3000:4B88  2B C0             sub  ax,ax
3000:4B8A  50                push ax
3000:4B8B  E8 EE 06          call 0x527c
3000:4B8E  E9 72 FF          jmp  0x4b03

service_select_slot1_C3000_4B92:
3000:4B92  B8 01 00          mov  ax,0x1
3000:4B95  EB F3             jmp  0x4b8a

service_reset_parser_C3000_4B98:
3000:4B98  E8 9D 03          call 0x4f38
3000:4B9B  E9 20 01          jmp  0x4cbe

service_grammar_word_C3000_4BA4:
3000:4BA4  FF 76 06          push word [bp+0x6]
3000:4BA7  E8 9A 03          call 0x4f44
3000:4BAA  E9 56 FF          jmp  0x4b03
```

`0x23` is the Spell/Grammar front-end state query used before the C688 code
decides whether to run the grammar pass. `0x24` and `0x25` rebuild slot page
descriptors through `3000:527C`. `0x28` resets parser/tokenizer state, and
`0x2A` is the grammar-mode word feed/check.

The C688 Thesaurus and suggestion-browser paths use `AH=05`, so their caller
`DL` values are shifted into services `0x3D..0x47`:

```asm
service_selected_result_C3000_4BCA:
; file 0x34BCA
3000:4BCA  8B 46 04          mov  ax,[bp+0x4]
3000:4BCD  2D 3C 00          sub  ax,0x3c
3000:4BD0  89 46 FE          mov  [bp-0x2],ax
3000:4BD3  50                push ax
3000:4BD4  FF 76 06          push word [bp+0x6]
3000:4BD7  E8 4C 04          call 0x5026
3000:4BDA  E9 05 FF          jmp  0x4ae2

service_result_count_C3000_4BDE:
3000:4BDE  FF 76 06          push word [bp+0x6]
3000:4BE1  E8 E0 04          call 0x50c4
3000:4BE4  E9 1C FF          jmp  0x4b03

service_result_row_C3000_4BE8:
3000:4BE8  FF 76 06          push word [bp+0x6]
3000:4BEB  E8 06 05          call 0x50f4
3000:4BEE  E9 12 FF          jmp  0x4b03
```

Diagnostic services `0x58` and `0x59` are expanded in
[`diagnostic-spell-services.md`](diagnostic-spell-services.md).

## Candidate Service Front End

`3000:5016` initializes the candidate-list manager through `3000:66D4`.
`3000:5026` expands a selected one-based result into comma-separated related
words by walking the active candidate list and repeatedly calling `3000:6892`.
The manager internals are expanded in
[`banked-candidate-manager.md`](banked-candidate-manager.md).

```asm
candidate_manager_init_C3000_5016:
; file 0x35016
3000:5016  E8 BB 16          call 0x66d4
3000:5019  0B C0             or   ax,ax
3000:501B  7D 05             jnl  0x5022
3000:501D  B8 FF FF          mov  ax,0xffff
3000:5020  C3                ret
3000:5022  2B C0             sub  ax,ax
3000:5024  C3                ret

selected_result_expand_C3000_5026:
3000:5026  55                push bp
3000:5027  8B EC             mov  bp,sp
3000:5029  83 EC 06          sub  sp,byte +0x6
3000:502C  56                push si
3000:502D  FF 4E 06          dec  word [bp+0x6]
3000:5030  E8 2B 18          call 0x685e
3000:5033  C7 46 FC 00 00    mov  word [bp-0x4],0
...
3000:50A8  B8 66 93          mov  ax,0x9366
3000:50AB  50                push ax
3000:50AC  E8 E3 17          call 0x6892
3000:50AF  83 C4 02          add  sp,byte +0x2
3000:50B2  0B C0             or   ax,ax
3000:50B4  7D B6             jnl  0x506c
3000:50B6  8B 5E 04          mov  bx,[bp+0x4]
3000:50B9  C6 07 00          mov  byte [bx],0
3000:50BC  2B C0             sub  ax,ax
3000:50BE  5E                pop  si
3000:50BF  8B E5             mov  sp,bp
3000:50C1  5D                pop  bp
3000:50C2  C3                ret
```

`3000:50C4` returns the visible result count. It calls `3000:673A`, stores the
raw count in `[8454]`, and caps the count at nine before returning it in `AX`.

```asm
result_count_C3000_50C4:
; file 0x350C4
3000:50C4  55                push bp
3000:50C5  8B EC             mov  bp,sp
3000:50C7  C7 06 24 8F 00 00 mov  word [0x8f24],0
3000:50CD  FF 76 04          push word [bp+0x4]
3000:50D0  E8 67 16          call 0x673a
3000:50D3  83 C4 02          add  sp,byte +0x2
3000:50D6  A3 54 84          mov  [0x8454],ax
3000:50D9  0B C0             or   ax,ax
3000:50DB  7D 05             jnl  0x50e2
3000:50DD  B8 FF FF          mov  ax,0xffff
3000:50E0  5D                pop  bp
3000:50E1  C3                ret
3000:50E2  83 3E 54 84 09    cmp  word [0x8454],byte +0x9
3000:50E7  7E 06             jng  0x50ef
3000:50E9  C7 06 54 84 09 00 mov  word [0x8454],0x9
3000:50EF  A1 54 84          mov  ax,[0x8454]
3000:50F2  5D                pop  bp
3000:50F3  C3                ret
```

`3000:50F4` formats the next result row into the caller buffer. It writes
`"N) "`, copies the primary candidate text through `3000:677A`, pads short
primary text to at least four characters, then appends secondary text through
`3000:67E8`.

```asm
result_row_C3000_50F4:
; file 0x350F4
3000:50F4  55                push bp
3000:50F5  8B EC             mov  bp,sp
3000:50F7  83 EC 04          sub  sp,byte +0x4
3000:50FA  56                push si
3000:50FB  A1 54 84          mov  ax,[0x8454]
3000:50FE  39 06 24 8F       cmp  [0x8f24],ax
3000:5102  7C 08             jl   0x510c
3000:5104  B8 FF FF          mov  ax,0xffff
3000:5107  5E                pop  si
3000:5108  8B E5             mov  sp,bp
3000:510A  5D                pop  bp
3000:510B  C3                ret
3000:510C  8B 5E 04          mov  bx,[bp+0x4]
3000:510F  FF 46 04          inc  word [bp+0x4]
3000:5112  A0 24 8F          mov  al,[0x8f24]
3000:5115  04 31             add  al,0x31
3000:5117  88 07             mov  [bx],al
3000:5119  8B 5E 04          mov  bx,[bp+0x4]
3000:511C  FF 46 04          inc  word [bp+0x4]
3000:511F  C6 07 29          mov  byte [bx],0x29
3000:5122  8B 5E 04          mov  bx,[bp+0x4]
3000:5125  FF 46 04          inc  word [bp+0x4]
3000:5128  C6 07 20          mov  byte [bx],0x20
3000:512B  C7 06 EE 8E 66 93 mov  word [0x8eee],0x9366
3000:5131  B8 66 93          mov  ax,0x9366
3000:5134  50                push ax
3000:5135  E8 42 16          call 0x677a
```

## Text Translation Helpers

The grammar and spelling service wrappers translate caller text into the
engine alphabet at `8F00` before feeding parser/checker helpers. `3000:4FDA`
is the byte translation loop: it reads caller bytes, indexes table `0x1504`,
writes translated bytes to `8F00`, and terminates with NUL.

```asm
translate_caller_text_C3000_4FDA:
; file 0x34FDA
3000:4FDA  55                push bp
3000:4FDB  8B EC             mov  bp,sp
3000:4FDD  83 EC 04          sub  sp,byte +0x4
3000:4FE0  56                push si
3000:4FE1  C7 46 FE 00 8F    mov  word [bp-0x2],0x8f00
3000:4FE6  EB 16             jmp  0x4ffe
3000:4FE8  8B 5E FE          mov  bx,[bp-0x2]
3000:4FEB  8B 76 FC          mov  si,[bp-0x4]
3000:4FEE  81 E6 FF 00       and  si,0xff
3000:4FF2  8A 84 04 15       mov  al,[si+0x1504]
3000:4FF6  88 07             mov  [bx],al
3000:4FF8  FF 46 04          inc  word [bp+0x4]
3000:4FFB  FF 46 FE          inc  word [bp-0x2]
3000:4FFE  8B 5E 04          mov  bx,[bp+0x4]
3000:5001  8A 07             mov  al,[bx]
3000:5003  88 46 FC          mov  [bp-0x4],al
3000:5006  0A C0             or   al,al
3000:5008  75 DE             jnz  0x4fe8
3000:500A  8B 5E FE          mov  bx,[bp-0x2]
3000:500D  C6 07 00          mov  byte [bx],0
3000:5010  5E                pop  si
3000:5011  8B E5             mov  sp,bp
3000:5013  5D                pop  bp
3000:5014  C3                ret
```

## State Boundary

| Address | Role in this slice |
| ---: | --- |
| `[6000]` | Engine mode/state flag toggled by service `0x02` and tested by text-check wrappers. |
| `[6002]` | Mode flag set by service `0x18`, cleared by service `0x19` and initialization. |
| `[6004]` | Active slot number; service `0x23` returns `[6004] + 1`. |
| `[6006]` | Initialization flag cleared by `3000:4F76`. |
| `[6BD8]` | Dispatcher status return cell cleared before dispatch; copied back by the banked thunk. |
| `[8454]` | Raw/capped result count used by services `0x46` and `0x47`. |
| `[8F00]` | Translated caller text buffer for parser/checker services. |
| `[8F24]` | Result-row cursor incremented by `3000:50F4`. |
| `[8EEE]`, `[8EEA]` | Pointers into primary and secondary candidate strings during result-row formatting. |
| `[9366]` | Temporary candidate/related-word string buffer used by selected-result expansion and row formatting. |

## Bottom

The C000/C688 wrapper boundary and banked service front-end table are now
mapped. The candidate-list manager behind `3000:66D4`, `3000:673A`, and
`3000:6892` is expanded in
[`banked-candidate-manager.md`](banked-candidate-manager.md). Remaining
linguistic depth is in the compressed dictionary/candidate-search and
related-word record formats tracked in [`../spell-engine.md`](../spell-engine.md).
