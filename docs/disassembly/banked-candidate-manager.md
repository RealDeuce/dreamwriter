# Banked Candidate Manager

This slice maps the candidate-list manager used by the banked linguistic
services in [`banked-linguistic-services.md`](banked-linguistic-services.md).
It covers the service-facing helpers under `3000:66D4..690A` that initialize,
populate, navigate, and expose spelling/dictionary/thesaurus candidate rows.

No image assets are reached in this slice.

## Candidate State Initialization

`3000:66D4` initializes the high-level candidate/suggestion state. It clears the
active candidate index `[712E]`, clears the candidate count `[6E48]`, loads the
dictionary header/stream tables through `3000:88A0`, opens the compressed word
stream through `3000:96D6`, and builds nine candidate-buffer pointers at
`[6E4A..6E5B]`. Each buffer is `0x50` bytes, starting at `6E5E`.

```asm
candidate_state_init_C3000_66D4:
; file 0x366D4
3000:66D4  55                push bp
3000:66D5  8B EC             mov  bp,sp
3000:66D7  83 EC 02          sub  sp,byte +0x2
3000:66DA  C7 06 2E 71 FF FF mov  word [0x712e],0xffff
3000:66E0  C7 06 48 6E 00 00 mov  word [0x6e48],0
3000:66E6  E8 B7 21          call 0x88a0
3000:66E9  A3 32 71          mov  [0x7132],ax
3000:66EC  0B C0             or   ax,ax
3000:66EE  75 08             jnz  0x66f8
3000:66F0  B8 FF FF          mov  ax,0xffff
3000:66F3  8B E5             mov  sp,bp
3000:66F5  5D                pop  bp
3000:66F6  C3                ret
3000:66F8  FF 36 32 71       push word [0x7132]
3000:66FC  E8 D7 2F          call 0x96d6
3000:66FF  83 C4 02          add  sp,byte +0x2
3000:6702  0B C0             or   ax,ax
3000:6704  75 08             jnz  0x670e
3000:6706  C7 06 32 71 00 00 mov  word [0x7132],0
3000:670C  EB E2             jmp  0x66f0
3000:670E  C7 46 FE 00 00    mov  word [bp-0x2],0
3000:6713  B8 50 00          mov  ax,0x50
3000:6716  F7 6E FE          imul word [bp-0x2]
3000:6719  05 5E 6E          add  ax,0x6e5e
3000:671C  8B 5E FE          mov  bx,[bp-0x2]
3000:671F  D1 E3             shl  bx,1
3000:6721  89 87 4A 6E       mov  [bx+0x6e4a],ax
3000:6725  FF 46 FE          inc  word [bp-0x2]
3000:6728  83 7E FE 09       cmp  word [bp-0x2],byte +0x9
3000:672C  7C E5             jl   0x6713
3000:672E  C7 06 30 71 00 00 mov  word [0x7130],0
3000:6734  2B C0             sub  ax,ax
3000:6736  8B E5             mov  sp,bp
3000:6738  5D                pop  bp
3000:6739  C3                ret
```

## Result List Build

`3000:673A` builds a visible candidate list from a caller query/context pointer.
It clears the related-word list pointer `[7130]`, sets the secondary related
word index `[6E5C]` to `FFFF`, starts the active candidate index `[712E]` at
zero, and calls `3000:9848` with:

- output pointer table `6E4A`,
- maximum row count `9`,
- starting selector `1`,
- caller query/context pointer from `[bp+04]`.

The returned count is stored in `[6E48]`. A nonpositive count marks `[712E]` as
inactive and returns `FFFF`; otherwise the count is returned in `AX`.

```asm
candidate_result_list_build_C3000_673A:
; file 0x3673A
3000:673A  55                push bp
3000:673B  8B EC             mov  bp,sp
3000:673D  C7 06 30 71 00 00 mov  word [0x7130],0
3000:6743  C7 06 5C 6E FF FF mov  word [0x6e5c],0xffff
3000:6749  C7 06 2E 71 00 00 mov  word [0x712e],0
3000:674F  B8 4A 6E          mov  ax,0x6e4a
3000:6752  50                push ax
3000:6753  B8 09 00          mov  ax,0x9
3000:6756  50                push ax
3000:6757  B8 01 00          mov  ax,0x1
3000:675A  50                push ax
3000:675B  FF 76 04          push word [bp+0x4]
3000:675E  E8 E7 30          call 0x9848
3000:6761  83 C4 08          add  sp,byte +0x8
3000:6764  A3 48 6E          mov  [0x6e48],ax
3000:6767  0B C0             or   ax,ax
3000:6769  7F 09             jg   0x6774
3000:676B  B8 FF FF          mov  ax,0xffff
3000:676E  A3 2E 71          mov  [0x712e],ax
3000:6771  5D                pop  bp
3000:6772  C3                ret
3000:6774  A1 48 6E          mov  ax,[0x6e48]
3000:6777  5D                pop  bp
3000:6778  C3                ret
```

`3000:9848` is the deeper dictionary/candidate search entry. This slice treats
it as a boundary: it receives the pointer table and row limit, populates the
candidate buffers, and returns the count.

## Candidate Text Access

`3000:677A` copies the first display field from the current candidate row.
The current row is selected by `[712E]`; the row pointer comes from
`[6E4A + 2 * [712E]]`. The helper skips the first space-separated field, skips
additional spaces, copies the next field up to a space or NUL, terminates the
caller buffer, and returns the copied length.

```asm
candidate_copy_primary_field_C3000_677A:
; file 0x3677A
3000:677A  55                push bp
3000:677B  8B EC             mov  bp,sp
3000:677D  83 EC 04          sub  sp,byte +0x4
3000:6780  57                push di
3000:6781  56                push si
3000:6782  83 3E 2E 71 00    cmp  word [0x712e],byte +0x0
3000:6787  7C 09             jl   0x6792
3000:6789  A1 48 6E          mov  ax,[0x6e48]
3000:678C  39 06 2E 71       cmp  [0x712e],ax
3000:6790  7C 12             jl   0x67a4
3000:6792  8B 5E 04          mov  bx,[bp+0x4]
3000:6795  C6 07 00          mov  byte [bx],0
3000:6798  B8 FF FF          mov  ax,0xffff
3000:679B  A3 2E 71          mov  [0x712e],ax
3000:679E  5E                pop  si
3000:679F  5F                pop  di
3000:67A0  8B E5             mov  sp,bp
3000:67A2  5D                pop  bp
3000:67A3  C3                ret
3000:67A4  8B 1E 2E 71       mov  bx,[0x712e]
3000:67A8  D1 E3             shl  bx,1
3000:67AA  8B B7 4A 6E       mov  si,[bx+0x6e4a]
3000:67AE  80 3C 00          cmp  byte [si],0
3000:67B1  74 0F             jz   0x67c2
3000:67B3  46                inc  si
3000:67B4  80 7C FF 20       cmp  byte [si-0x1],0x20
3000:67B8  75 F4             jnz  0x67ae
3000:67BA  EB 06             jmp  0x67c2
3000:67BC  80 3C 20          cmp  byte [si],0x20
3000:67BF  75 06             jnz  0x67c7
3000:67C1  46                inc  si
3000:67C2  80 3C 00          cmp  byte [si],0
3000:67C5  75 F5             jnz  0x67bc
3000:67C7  8B 7E 04          mov  di,[bp+0x4]
3000:67CA  EB 09             jmp  0x67d5
3000:67CC  80 3C 20          cmp  byte [si],0x20
3000:67CF  74 09             jz   0x67da
3000:67D1  AC                lodsb
3000:67D2  88 05             mov  [di],al
3000:67D4  47                inc  di
3000:67D5  80 3C 00          cmp  byte [si],0
3000:67D8  75 F2             jnz  0x67cc
3000:67DA  C6 05 00          mov  byte [di],0
3000:67DD  8B C7             mov  ax,di
3000:67DF  2B 46 04          sub  ax,[bp+0x4]
3000:67E2  5E                pop  si
3000:67E3  5F                pop  di
3000:67E4  8B E5             mov  sp,bp
3000:67E6  5D                pop  bp
3000:67E7  C3                ret
```

`3000:67E8` copies the later candidate text. It skips two space-separated
fields and then copies the remaining NUL-terminated tail into the caller buffer.

```asm
candidate_copy_secondary_tail_C3000_67E8:
; file 0x367E8
3000:67E8  55                push bp
3000:67E9  8B EC             mov  bp,sp
3000:67EB  83 EC 06          sub  sp,byte +0x6
3000:67EE  57                push di
3000:67EF  56                push si
3000:67F0  8B 5E 04          mov  bx,[bp+0x4]
3000:67F3  C6 07 00          mov  byte [bx],0
3000:67F6  83 3E 2E 71 00    cmp  word [0x712e],byte +0x0
3000:67FB  7C 09             jl   0x6806
3000:67FD  A1 48 6E          mov  ax,[0x6e48]
3000:6800  39 06 2E 71       cmp  [0x712e],ax
3000:6804  7C 0C             jl   0x6812
3000:6806  B8 FF FF          mov  ax,0xffff
3000:6809  A3 2E 71          mov  [0x712e],ax
3000:680C  5E                pop  si
3000:680D  5F                pop  di
3000:680E  8B E5             mov  sp,bp
3000:6810  5D                pop  bp
3000:6811  C3                ret
3000:6812  8B 1E 2E 71       mov  bx,[0x712e]
3000:6816  D1 E3             shl  bx,1
3000:6818  8B B7 4A 6E       mov  si,[bx+0x6e4a]
3000:681C  C7 46 FA 00 00    mov  word [bp-0x6],0
3000:6824  FF 46 FA          inc  word [bp-0x6]
3000:6827  83 7E FA 02       cmp  word [bp-0x6],byte +0x2
3000:682B  7D 19             jnl  0x6846
3000:682D  80 3C 00          cmp  byte [si],0
3000:6830  74 07             jz   0x6839
3000:6832  46                inc  si
3000:6833  80 7C FF 20       cmp  byte [si-0x1],0x20
3000:6837  75 F4             jnz  0x682d
3000:6839  80 3C 00          cmp  byte [si],0
3000:683C  74 E6             jz   0x6824
3000:683E  80 3C 20          cmp  byte [si],0x20
3000:6841  75 E1             jnz  0x6824
3000:6843  46                inc  si
3000:6844  EB F3             jmp  0x6839
3000:6846  8B 7E 04          mov  di,[bp+0x4]
3000:6849  AC                lodsb
3000:684A  88 05             mov  [di],al
3000:684C  47                inc  di
3000:684D  0A C0             or   al,al
3000:684F  75 F8             jnz  0x6849
3000:6851  8B C7             mov  ax,di
3000:6853  2B 46 04          sub  ax,[bp+0x4]
3000:6856  48                dec  ax
3000:6857  5E                pop  si
3000:6858  5F                pop  di
3000:6859  8B E5             mov  sp,bp
3000:685B  5D                pop  bp
3000:685C  C3                ret
```

## Candidate Cursor

`3000:685E` advances `[712E]`. If the increment would move past `[6E48]`, it
backs up and returns `0`. On a successful move it clears `[7130]`, invalidating
any related-word list cached for the previous candidate, and returns `1`.
`3000:687C` is the reverse companion.

```asm
candidate_next_C3000_685E:
; file 0x3685E
3000:685E  FF 06 2E 71       inc  word [0x712e]
3000:6862  A1 48 6E          mov  ax,[0x6e48]
3000:6865  39 06 2E 71       cmp  [0x712e],ax
3000:6869  7C 07             jl   0x6872
3000:686B  FF 0E 2E 71       dec  word [0x712e]
3000:686F  2B C0             sub  ax,ax
3000:6871  C3                ret
3000:6872  C7 06 30 71 00 00 mov  word [0x7130],0
3000:6878  B8 01 00          mov  ax,0x1
3000:687B  C3                ret

candidate_previous_C3000_687C:
3000:687C  FF 0E 2E 71       dec  word [0x712e]
3000:6880  79 06             jns  0x6888
3000:6882  2B C0             sub  ax,ax
3000:6884  A3 2E 71          mov  [0x712e],ax
3000:6887  C3                ret
3000:6888  C7 06 30 71 00 00 mov  word [0x7130],0
3000:688E  B8 01 00          mov  ax,0x1
3000:6891  C3                ret
```

## Related-Word List Access

`3000:6892` is the forward related-word iterator used by selected-result
expansion in [`banked-linguistic-services.md`](banked-linguistic-services.md).
If `[7130]` is zero, it lazily builds the related-word pointer list by calling
`3000:A45C([712E] + 1, &7130)`. The helper then walks the word-pointer array,
skipping from `[6E5C]` to the next nonzero pointer, copies that NUL-terminated
string through `3000:960A`, and returns the copied length.

```asm
related_word_next_C3000_6892:
; file 0x36892
3000:6892  55                push bp
3000:6893  8B EC             mov  bp,sp
3000:6895  83 EC 02          sub  sp,byte +0x2
3000:6898  56                push si
3000:6899  8B 5E 04          mov  bx,[bp+0x4]
3000:689C  C6 07 00          mov  byte [bx],0
3000:689F  83 3E 30 71 00    cmp  word [0x7130],byte +0x0
3000:68A4  75 22             jnz  0x68c8
3000:68A6  B8 30 71          mov  ax,0x7130
3000:68A9  50                push ax
3000:68AA  A1 2E 71          mov  ax,[0x712e]
3000:68AD  40                inc  ax
3000:68AE  50                push ax
3000:68AF  E8 AA 3B          call 0xa45c
3000:68B2  83 C4 04          add  sp,byte +0x4
3000:68B5  0B C0             or   ax,ax
3000:68B7  75 09             jnz  0x68c2
3000:68B9  B8 FF FF          mov  ax,0xffff
3000:68BC  5E                pop  si
3000:68BD  8B E5             mov  sp,bp
3000:68BF  5D                pop  bp
3000:68C0  C3                ret
3000:68C2  C7 06 5C 6E FF FF mov  word [0x6e5c],0xffff
3000:68C8  83 3E 5C 6E 00    cmp  word [0x6e5c],byte +0x0
3000:68CD  7C 0F             jl   0x68de
3000:68CF  8B 1E 5C 6E       mov  bx,[0x6e5c]
3000:68D3  D1 E3             shl  bx,1
3000:68D5  8B 36 30 71       mov  si,[0x7130]
3000:68D9  83 38 00          cmp  word [bx+si],byte +0x0
3000:68DC  74 04             jz   0x68e2
3000:68DE  FF 06 5C 6E       inc  word [0x6e5c]
3000:68E2  8B 1E 5C 6E       mov  bx,[0x6e5c]
3000:68E6  D1 E3             shl  bx,1
3000:68E8  8B 36 30 71       mov  si,[0x7130]
3000:68EC  8B 00             mov  ax,[bx+si]
3000:68EE  89 46 FE          mov  [bp-0x2],ax
3000:68F1  0B C0             or   ax,ax
3000:68F3  74 C4             jz   0x68b9
3000:68F5  50                push ax
3000:68F6  FF 76 04          push word [bp+0x4]
3000:68F9  E8 0E 2D          call 0x960a
3000:68FC  83 C4 04          add  sp,byte +0x4
3000:68FF  89 46 FE          mov  [bp-0x2],ax
3000:6902  2B 46 04          sub  ax,[bp+0x4]
3000:6905  5E                pop  si
3000:6906  8B E5             mov  sp,bp
3000:6908  5D                pop  bp
3000:6909  C3                ret
```

`3000:690A` is the reverse iterator. If no related-word list exists, it builds
one and leaves `[6E5C]=FFFF`; otherwise it decrements `[6E5C]`, copies the
selected pointer through `3000:960A`, and returns the copied length.

```asm
related_word_previous_C3000_690A:
; file 0x3690A
3000:690A  55                push bp
3000:690B  8B EC             mov  bp,sp
3000:690D  83 EC 02          sub  sp,byte +0x2
3000:6910  56                push si
3000:6911  8B 5E 04          mov  bx,[bp+0x4]
3000:6914  C6 07 00          mov  byte [bx],0
3000:6917  83 3E 30 71 00    cmp  word [0x7130],byte +0x0
3000:691C  75 1A             jnz  0x6938
3000:691E  B8 30 71          mov  ax,0x7130
3000:6921  50                push ax
3000:6922  A1 2E 71          mov  ax,[0x712e]
3000:6925  40                inc  ax
3000:6926  50                push ax
3000:6927  E8 32 3B          call 0xa45c
3000:692A  83 C4 04          add  sp,byte +0x4
3000:692D  B8 FF FF          mov  ax,0xffff
3000:6930  A3 5C 6E          mov  [0x6e5c],ax
3000:6933  5E                pop  si
3000:6934  8B E5             mov  sp,bp
3000:6936  5D                pop  bp
3000:6937  C3                ret
3000:6938  83 3E 5C 6E 00    cmp  word [0x6e5c],byte +0x0
3000:693D  7E EE             jng  0x692d
3000:693F  FF 0E 5C 6E       dec  word [0x6e5c]
3000:6943  8B 1E 5C 6E       mov  bx,[0x6e5c]
3000:6947  D1 E3             shl  bx,1
3000:6949  8B 36 30 71       mov  si,[0x7130]
3000:694D  FF 30             push word [bx+si]
3000:694F  FF 76 04          push word [bp+0x4]
3000:6952  E8 B5 2C          call 0x960a
3000:6955  83 C4 04          add  sp,byte +0x4
3000:6958  89 46 FE          mov  [bp-0x2],ax
3000:695B  2B 46 04          sub  ax,[bp+0x4]
3000:695E  5E                pop  si
3000:695F  8B E5             mov  sp,bp
3000:6961  5D                pop  bp
3000:6962  C3                ret
```

## Boundary: Candidate Search And Formatting

The manager calls deeper helpers that remain outside this slice:

| Helper | Boundary role |
| --- | --- |
| `3000:9848` | Populates the nine candidate buffers and returns the count used by `3000:673A`. |
| `3000:6964` | Formats numbered suggestion rows from packed record fields; expanded in [`banked-candidate-formatter.md`](banked-candidate-formatter.md). |
| `3000:A45C` | Builds the selected candidate's related-word pointer list and string pool, stored through `[7130]`. |
| `3000:960A` | Copies a NUL-terminated string to the caller buffer and returns the end pointer. |

`3000:6964` begins with the visible row prefix:

```asm
candidate_numbered_row_prefix_C3000_6964:
; file 0x36964
3000:6964  55                push bp
3000:6965  8B EC             mov  bp,sp
3000:6967  83 EC 0A          sub  sp,byte +0xa
3000:696A  57                push di
3000:696B  56                push si
3000:696C  8B 76 06          mov  si,[bp+0x6]
3000:696F  8A 46 08          mov  al,[bp+0x8]
3000:6972  04 30             add  al,0x30
3000:6974  88 04             mov  [si],al
3000:6976  46                inc  si
3000:6977  C6 04 29          mov  byte [si],0x29
3000:697A  46                inc  si
3000:697B  C6 04 20          mov  byte [si],0x20
3000:697E  46                inc  si
```

## State Boundary

| Address | Role in this slice |
| ---: | --- |
| `[6E48]` | Candidate count returned by `3000:9848`. |
| `[6E4A..6E5B]` | Nine word pointers to `0x50`-byte candidate buffers. |
| `[6E5C]` | Related-word cursor into the pointer list at `[7130]`; `FFFF` means before the first item. |
| `[6E5E..712D]` | Nine `0x50`-byte candidate text buffers. |
| `[712E]` | Active candidate index; `FFFF` means inactive/no candidate. |
| `[7130]` | Pointer to the lazily built related-word pointer list. |
| `[7132]` | Dictionary structure pointer returned by `3000:88A0`. |

## Bottom

The candidate-list manager is now mapped from initialization through
service-facing count/row/related-word helpers, and the numbered row formatter is
expanded in [`banked-candidate-formatter.md`](banked-candidate-formatter.md).
Remaining depth is the dictionary candidate search at `3000:9848` and the
packed related-word builder at `3000:A45C`.
