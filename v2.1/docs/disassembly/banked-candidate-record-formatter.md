# Banked Candidate Record Formatter

This slice maps the parser/search-record formatter immediately below
[`banked-candidate-formatter.md`](banked-candidate-formatter.md). It covers
`3000:6B6C..6ECD`, which formats active candidate records through dictionary
field expansion, compound-field handling, and suffix-handler dispatch.

No image assets are reached in this slice.

## Entry Gate

`3000:6B6C` receives an output pointer, a base string pointer, a selector/mode,
and an active record pointer. It stores the record pointer in `[7134]`, copies
the base string into the output, and reads `[record+6]` as the field/type code.
Types `0x1D` and `0x1F` return success immediately after the base copy.

For other types it searches the base output for a space through `3000:963A`.
When a space is present, most field types call the whitespace-aware formatter at
`3000:6BF0`; types `0x09`, `0x0F`, `0x11`, and `0x13` fail immediately. When no
space is present, the no-space formatter at `3000:6CEC` is used.

```asm
candidate_record_formatter_entry_C3000_6B6C:
; file 0x36B6C
3000:6B6C  55                push bp
3000:6B6D  8B EC             mov  bp,sp
3000:6B6F  83 EC 02          sub  sp,byte +0x2
3000:6B72  8B 46 0A          mov  ax,[bp+0xa]
3000:6B75  A3 34 71          mov  [0x7134],ax
3000:6B78  0B C0             or   ax,ax
3000:6B7A  75 06             jnz  0x6b82
3000:6B7C  2B C0             sub  ax,ax
3000:6B7E  8B E5             mov  sp,bp
3000:6B80  5D                pop  bp
3000:6B81  C3                ret
3000:6B82  FF 76 04          push word [bp+0x4]
3000:6B85  FF 76 06          push word [bp+0x6]
3000:6B88  E8 7F 2A          call 0x960a
3000:6B8B  83 C4 04          add  sp,byte +0x4
3000:6B8E  8B 1E 34 71       mov  bx,[0x7134]
3000:6B92  8B 47 06          mov  ax,[bx+0x6]
3000:6B95  89 46 FE          mov  [bp-0x2],ax
3000:6B98  3D 1D 00          cmp  ax,0x1d
3000:6B9B  74 05             jz   0x6ba2
3000:6B9D  3D 1F 00          cmp  ax,0x1f
3000:6BA0  75 08             jnz  0x6baa
3000:6BA2  B8 01 00          mov  ax,0x1
3000:6BA5  8B E5             mov  sp,bp
3000:6BA7  5D                pop  bp
3000:6BA8  C3                ret
3000:6BA9  90                nop
3000:6BAA  B8 20 00          mov  ax,0x20
3000:6BAD  50                push ax
3000:6BAE  FF 76 06          push word [bp+0x6]
3000:6BB1  E8 86 2A          call 0x963a
3000:6BB4  83 C4 04          add  sp,byte +0x4
3000:6BB7  0B C0             or   ax,ax
3000:6BB9  74 29             jz   0x6be4
3000:6BBB  83 7E FE 13       cmp  word [bp-0x2],byte +0x13
3000:6BBF  74 BB             jz   0x6b7c
3000:6BC1  83 7E FE 0F       cmp  word [bp-0x2],byte +0xf
3000:6BC5  74 B5             jz   0x6b7c
3000:6BC7  83 7E FE 11       cmp  word [bp-0x2],byte +0x11
3000:6BCB  74 AF             jz   0x6b7c
3000:6BCD  83 7E FE 09       cmp  word [bp-0x2],byte +0x9
3000:6BD1  74 A9             jz   0x6b7c
3000:6BD3  FF 76 08          push word [bp+0x8]
3000:6BD6  FF 76 06          push word [bp+0x6]
3000:6BD9  E8 14 00          call 0x6bf0
3000:6BDC  83 C4 04          add  sp,byte +0x4
3000:6BDF  8B E5             mov  sp,bp
3000:6BE1  5D                pop  bp
3000:6BE2  C3                ret
3000:6BE3  90                nop
3000:6BE4  FF 76 08          push word [bp+0x8]
3000:6BE7  FF 76 06          push word [bp+0x6]
3000:6BEA  E8 FF 00          call 0x6cec
3000:6BED  EB ED             jmp  0x6bdc
```

## Whitespace-Aware Expansion

`3000:6BF0` is used after the copied output already contains a space. It asks
`3000:B116` to expand the current record type into a stack buffer. Positive
returns copy that expansion directly. `FFFF` opens special fallbacks:

- type `0x01`: try fields `3` and `5`, joining the two results with `/`;
- selector/mode `0x0A`: split at the first space, run `3000:6CEC` on the tail,
  then post-process the original output with `3000:78CE`;
- selector/mode `0x05`: split at the last space, run `3000:6CEC` on the tail,
  then post-process with `3000:78CE`.

The `3000:78CE` post-processor is documented in
[`banked-compound-normalizer.md`](banked-compound-normalizer.md).

```asm
candidate_record_space_formatter_C3000_6BF0:
; file 0x36BF0
3000:6BF0  55                push bp
3000:6BF1  8B EC             mov  bp,sp
3000:6BF3  83 EC 7E          sub  sp,byte +0x7e
3000:6BF6  56                push si
3000:6BF7  8B 1E 34 71       mov  bx,[0x7134]
3000:6BFB  8B 47 06          mov  ax,[bx+0x6]
3000:6BFE  89 46 9A          mov  [bp-0x66],ax
3000:6C01  50                push ax
3000:6C02  8D 46 9C          lea  ax,[bp-0x64]
3000:6C05  50                push ax
3000:6C06  FF 76 04          push word [bp+0x4]
3000:6C09  E8 0A 45          call 0xb116
3000:6C0C  83 C4 06          add  sp,byte +0x6
3000:6C0F  89 46 E4          mov  [bp-0x1c],ax
3000:6C12  40                inc  ax
3000:6C13  74 1F             jz   0x6c34
3000:6C15  83 7E E4 00       cmp  word [bp-0x1c],byte +0x0
3000:6C19  75 03             jnz  0x6c1e
3000:6C1B  E9 C6 00          jmp  0x6ce4
3000:6C1E  8D 46 9C          lea  ax,[bp-0x64]
3000:6C21  50                push ax
3000:6C22  FF 76 04          push word [bp+0x4]
3000:6C25  E8 E2 29          call 0x960a
3000:6C28  83 C4 04          add  sp,byte +0x4
3000:6C2B  B8 01 00          mov  ax,0x1
3000:6C2E  5E                pop  si
3000:6C2F  8B E5             mov  sp,bp
3000:6C31  5D                pop  bp
3000:6C32  C3                ret
3000:6C33  90                nop
3000:6C34  83 7E 9A 01       cmp  word [bp-0x66],byte +0x1
3000:6C38  75 48             jnz  0x6c82
3000:6C3A  B8 03 00          mov  ax,0x3
3000:6C3D  50                push ax
3000:6C3E  8D 46 B4          lea  ax,[bp-0x4c]
3000:6C41  50                push ax
3000:6C42  FF 76 04          push word [bp+0x4]
3000:6C45  E8 CE 44          call 0xb116
3000:6C48  83 C4 06          add  sp,byte +0x6
3000:6C4B  0B C0             or   ax,ax
3000:6C4D  7E 33             jng  0x6c82
3000:6C4F  B8 05 00          mov  ax,0x5
3000:6C52  50                push ax
3000:6C53  8D 46 E8          lea  ax,[bp-0x18]
3000:6C56  50                push ax
3000:6C57  FF 76 04          push word [bp+0x4]
3000:6C5A  E8 B9 44          call 0xb116
3000:6C5D  83 C4 06          add  sp,byte +0x6
3000:6C60  0B C0             or   ax,ax
3000:6C62  7E 1E             jng  0x6c82
3000:6C64  8D 46 B4          lea  ax,[bp-0x4c]
3000:6C67  50                push ax
3000:6C68  FF 76 04          push word [bp+0x4]
3000:6C6B  E8 9C 29          call 0x960a
3000:6C6E  83 C4 04          add  sp,byte +0x4
3000:6C71  89 46 04          mov  [bp+0x4],ax
3000:6C74  8B D8             mov  bx,ax
3000:6C76  FF 46 04          inc  word [bp+0x4]
3000:6C79  C6 07 2F          mov  byte [bx],0x2f
3000:6C7C  8D 46 E8          lea  ax,[bp-0x18]
3000:6C7F  EB A0             jmp  0x6c21
3000:6C81  90                nop
3000:6C82  83 7E 06 0A       cmp  word [bp+0x6],byte +0xa
3000:6C86  75 22             jnz  0x6caa
3000:6C88  B8 20 00          mov  ax,0x20
3000:6C8B  50                push ax
3000:6C8C  FF 76 04          push word [bp+0x4]
3000:6C8F  E8 A8 29          call 0x963a
3000:6C92  83 C4 04          add  sp,byte +0x4
3000:6C95  8B F0             mov  si,ax
3000:6C97  56                push si
3000:6C98  8D 46 82          lea  ax,[bp-0x7e]
3000:6C9B  50                push ax
3000:6C9C  E8 6B 29          call 0x960a
3000:6C9F  83 C4 04          add  sp,byte +0x4
3000:6CA2  C6 04 00          mov  byte [si],0
3000:6CA5  8B 76 04          mov  si,[bp+0x4]
3000:6CA8  EB 1A             jmp  0x6cc4
3000:6CAA  83 7E 06 05       cmp  word [bp+0x6],byte +0x5
3000:6CAE  75 34             jnz  0x6ce4
3000:6CB0  C6 46 82 00       mov  byte [bp-0x7e],0
3000:6CB4  B8 20 00          mov  ax,0x20
3000:6CB7  50                push ax
3000:6CB8  FF 76 04          push word [bp+0x4]
3000:6CBB  E8 A8 29          call 0x9666
3000:6CBE  83 C4 04          add  sp,byte +0x4
3000:6CC1  8B F0             mov  si,ax
3000:6CC3  46                inc  si
3000:6CC4  FF 76 06          push word [bp+0x6]
3000:6CC7  56                push si
3000:6CC8  E8 21 00          call 0x6cec
3000:6CCB  83 C4 04          add  sp,byte +0x4
3000:6CCE  0B C0             or   ax,ax
3000:6CD0  74 12             jz   0x6ce4
3000:6CD2  8D 46 82          lea  ax,[bp-0x7e]
3000:6CD5  50                push ax
3000:6CD6  FF 76 04          push word [bp+0x4]
3000:6CD9  E8 F2 0B          call 0x78ce
3000:6CDC  83 C4 04          add  sp,byte +0x4
3000:6CDF  5E                pop  si
3000:6CE0  8B E5             mov  sp,bp
3000:6CE2  5D                pop  bp
3000:6CE3  C3                ret
3000:6CE4  2B C0             sub  ax,ax
3000:6CE6  5E                pop  si
3000:6CE7  8B E5             mov  sp,bp
3000:6CE9  5D                pop  bp
3000:6CEA  C3                ret
```

## No-Space Expansion

`3000:6CEC` handles records whose copied base output has no space. It first
tries direct `3000:B116` expansions using the active type code and several
special substitutes:

- types `0x03` and `0x05` retry field `1` first;
- type `0x19` retries field `1` after the direct type expansion returns
  `FFFF`;
- type `0x1B` retries field `7`;
- type `0x01` tries fields `3` and `5`, joins them with `/`, and copies the
  joined string back to the output.

If those paths fail, `[record+3]` selects one of the suffix/variant handlers.
The handler table at `3000:6E9C` is data with ten one-word targets:

| `[record+3]` | Target |
| ---: | --- |
| `0` | `3000:6E84` |
| `1` | `3000:6E1E` |
| `2`, `3` | `3000:6E2A` |
| `4` | `3000:6E56` |
| `5` | `3000:6E62` |
| `6..9` | `3000:6E84` |

`3000:6E84` calls the final-letter suffix dispatcher at `3000:6ECE`, expanded
in [`banked-suffix-dispatch.md`](banked-suffix-dispatch.md).

```asm
candidate_record_no_space_formatter_C3000_6CEC:
; file 0x36CEC
3000:6CEC  55                push bp
3000:6CED  8B EC             mov  bp,sp
3000:6CEF  81 EC 80 00       sub  sp,0x80
3000:6CF3  56                push si
3000:6CF4  FF 76 04          push word [bp+0x4]
3000:6CF7  8D 46 80          lea  ax,[bp-0x80]
3000:6CFA  50                push ax
3000:6CFB  E8 0C 29          call 0x960a
3000:6CFE  83 C4 04          add  sp,byte +0x4
3000:6D01  8B 1E 34 71       mov  bx,[0x7134]
3000:6D05  8B 07             mov  ax,[bx]
3000:6D07  89 46 E6          mov  [bp-0x1a],ax
3000:6D0A  FF 76 04          push word [bp+0x4]
3000:6D0D  E8 16 29          call 0x9626
3000:6D10  83 C4 02          add  sp,byte +0x2
3000:6D13  8B F0             mov  si,ax
3000:6D15  8B 1E 34 71       mov  bx,[0x7134]
3000:6D19  8B 47 06          mov  ax,[bx+0x6]
3000:6D1C  89 46 9A          mov  [bp-0x66],ax
3000:6D1F  3D 03 00          cmp  ax,0x3
3000:6D22  74 05             jz   0x6d29
3000:6D24  3D 05 00          cmp  ax,0x5
3000:6D27  75 1F             jnz  0x6d48
3000:6D29  B8 01 00          mov  ax,0x1
3000:6D2C  50                push ax
3000:6D2D  FF 76 04          push word [bp+0x4]
3000:6D30  FF 76 04          push word [bp+0x4]
3000:6D33  E8 E0 43          call 0xb116
3000:6D36  83 C4 06          add  sp,byte +0x6
3000:6D39  89 46 E4          mov  [bp-0x1c],ax
3000:6D3C  0B C0             or   ax,ax
3000:6D3E  7E 08             jng  0x6d48
3000:6D40  B8 01 00          mov  ax,0x1
3000:6D43  5E                pop  si
3000:6D44  8B E5             mov  sp,bp
3000:6D46  5D                pop  bp
3000:6D47  C3                ret
3000:6D48  FF 76 9A          push word [bp-0x66]
3000:6D4B  FF 76 04          push word [bp+0x4]
3000:6D4E  FF 76 04          push word [bp+0x4]
3000:6D51  E8 C2 43          call 0xb116
3000:6D54  83 C4 06          add  sp,byte +0x6
3000:6D57  89 46 E4          mov  [bp-0x1c],ax
3000:6D5A  40                inc  ax
3000:6D5B  74 09             jz   0x6d66
3000:6D5D  8B 46 E4          mov  ax,[bp-0x1c]
3000:6D60  5E                pop  si
3000:6D61  8B E5             mov  sp,bp
3000:6D63  5D                pop  bp
3000:6D64  C3                ret
3000:6D65  90                nop
3000:6D66  83 7E 9A 19       cmp  word [bp-0x66],byte +0x19
3000:6D6A  75 1A             jnz  0x6d86
3000:6D6C  B8 01 00          mov  ax,0x1
3000:6D6F  50                push ax
3000:6D70  FF 76 04          push word [bp+0x4]
3000:6D73  FF 76 04          push word [bp+0x4]
3000:6D76  E8 9D 43          call 0xb116
3000:6D79  83 C4 06          add  sp,byte +0x6
3000:6D7C  89 46 E4          mov  [bp-0x1c],ax
3000:6D7F  0B C0             or   ax,ax
3000:6D81  7E 20             jng  0x6da3
3000:6D83  EB BB             jmp  0x6d40
3000:6D85  90                nop
3000:6D86  83 7E 9A 1B       cmp  word [bp-0x66],byte +0x1b
3000:6D8A  75 17             jnz  0x6da3
3000:6D8C  B8 07 00          mov  ax,0x7
3000:6D8F  50                push ax
3000:6D90  FF 76 04          push word [bp+0x4]
3000:6D93  FF 76 04          push word [bp+0x4]
3000:6D96  E8 7D 43          call 0xb116
3000:6D99  83 C4 06          add  sp,byte +0x6
3000:6D9C  89 46 E4          mov  [bp-0x1c],ax
3000:6D9F  0B C0             or   ax,ax
3000:6DA1  7F 9D             jg   0x6d40
3000:6DA3  83 7E 9A 01       cmp  word [bp-0x66],byte +0x1
3000:6DA7  75 5B             jnz  0x6e04
3000:6DA9  B8 03 00          mov  ax,0x3
3000:6DAC  50                push ax
3000:6DAD  8D 46 B4          lea  ax,[bp-0x4c]
3000:6DB0  50                push ax
3000:6DB1  FF 76 04          push word [bp+0x4]
3000:6DB4  E8 5F 43          call 0xb116
3000:6DB7  83 C4 06          add  sp,byte +0x6
3000:6DBA  89 46 E4          mov  [bp-0x1c],ax
3000:6DBD  0B C0             or   ax,ax
3000:6DBF  7E 43             jng  0x6e04
3000:6DC1  8D 46 B4          lea  ax,[bp-0x4c]
3000:6DC4  50                push ax
3000:6DC5  E8 5E 28          call 0x9626
3000:6DC8  83 C4 02          add  sp,byte +0x2
3000:6DCB  8B F0             mov  si,ax
3000:6DCD  B8 05 00          mov  ax,0x5
3000:6DD0  50                push ax
3000:6DD1  8D 46 E8          lea  ax,[bp-0x18]
3000:6DD4  50                push ax
3000:6DD5  FF 76 04          push word [bp+0x4]
3000:6DD8  E8 3B 43          call 0xb116
3000:6DDB  83 C4 06          add  sp,byte +0x6
3000:6DDE  89 46 E4          mov  [bp-0x1c],ax
3000:6DE1  0B C0             or   ax,ax
3000:6DE3  7E 0F             jng  0x6df4
3000:6DE5  C6 04 2F          mov  byte [si],0x2f
3000:6DE8  46                inc  si
3000:6DE9  8D 46 E8          lea  ax,[bp-0x18]
3000:6DEC  50                push ax
3000:6DED  56                push si
3000:6DEE  E8 19 28          call 0x960a
3000:6DF1  83 C4 04          add  sp,byte +0x4
3000:6DF4  8D 46 B4          lea  ax,[bp-0x4c]
3000:6DF7  50                push ax
3000:6DF8  FF 76 04          push word [bp+0x4]
3000:6DFB  E8 0C 28          call 0x960a
3000:6DFE  83 C4 04          add  sp,byte +0x4
3000:6E01  E9 3C FF          jmp  0x6d40
```

## Variant Dispatch

The suffix/variant dispatch uses `[record+3]`. Some classes call named
suffix-handler islands directly; others call `3000:6ECE`, which dispatches on
the last output character. All successful handlers converge at `3000:6EB0`,
where a final field `0xFF` expansion confirms the result before returning
success.

```asm
candidate_record_variant_dispatch_C3000_6E04:
; file 0x36E04
3000:6E04  8B 1E 34 71       mov  bx,[0x7134]
3000:6E08  8A 47 03          mov  al,[bx+0x3]
3000:6E0B  2A E4             sub  ah,ah
3000:6E0D  3D 09 00          cmp  ax,0x9
3000:6E10  76 03             jna  0x6e15
3000:6E12  E9 80 00          jmp  0x6e95
3000:6E15  03 C0             add  ax,ax
3000:6E17  93                xchg ax,bx
3000:6E18  2E FF A7 9C 6E    jmp  [cs:bx+0x6e9c]
3000:6E1D  90                nop
3000:6E1E  FF 76 E6          push word [bp-0x1a]
3000:6E21  56                push si
3000:6E22  FF 76 04          push word [bp+0x4]
3000:6E25  E8 3C 03          call 0x7164
3000:6E28  EB 64             jmp  0x6e8e
3000:6E2A  83 7E 9A 0B       cmp  word [bp-0x66],byte +0xb
3000:6E2E  74 06             jz   0x6e36
3000:6E30  83 7E 9A 0D       cmp  word [bp-0x66],byte +0xd
3000:6E34  75 0C             jnz  0x6e42
3000:6E36  FF 76 E6          push word [bp-0x1a]
3000:6E39  56                push si
3000:6E3A  FF 76 04          push word [bp+0x4]
3000:6E3D  E8 E4 08          call 0x7724
3000:6E40  EB 4C             jmp  0x6e8e
3000:6E42  FF 76 E6          push word [bp-0x1a]
3000:6E45  56                push si
3000:6E46  FF 76 04          push word [bp+0x4]
3000:6E49  E8 D0 03          call 0x721c
3000:6E4C  83 C4 06          add  sp,byte +0x6
3000:6E4F  0B C0             or   ax,ax
3000:6E51  74 42             jz   0x6e95
3000:6E53  EB 5B             jmp  0x6eb0
3000:6E55  90                nop
3000:6E56  FF 76 E6          push word [bp-0x1a]
3000:6E59  56                push si
3000:6E5A  FF 76 04          push word [bp+0x4]
3000:6E5D  E8 D2 05          call 0x7432
3000:6E60  EB 2C             jmp  0x6e8e
3000:6E62  B8 A2 25          mov  ax,0x25a2
3000:6E65  50                push ax
3000:6E66  56                push si
3000:6E67  FF 76 04          push word [bp+0x4]
3000:6E6A  E8 21 06          call 0x748e
3000:6E6D  83 C4 06          add  sp,byte +0x6
3000:6E70  0B C0             or   ax,ax
3000:6E72  74 21             jz   0x6e95
3000:6E74  FF 76 04          push word [bp+0x4]
3000:6E77  E8 E6 E3          call 0x5260
3000:6E7A  83 C4 02          add  sp,byte +0x2
3000:6E7D  3D 06 00          cmp  ax,0x6
3000:6E80  7D 2E             jnl  0x6eb0
3000:6E82  EB 11             jmp  0x6e95
3000:6E84  FF 76 06          push word [bp+0x6]
3000:6E87  56                push si
3000:6E88  FF 76 04          push word [bp+0x4]
3000:6E8B  E8 40 00          call 0x6ece
3000:6E8E  83 C4 06          add  sp,byte +0x6
3000:6E91  0B C0             or   ax,ax
3000:6E93  75 1B             jnz  0x6eb0
3000:6E95  2B C0             sub  ax,ax
3000:6E97  5E                pop  si
3000:6E98  8B E5             mov  sp,bp
3000:6E9A  5D                pop  bp
3000:6E9B  C3                ret
```

```asm
candidate_record_final_confirm_C3000_6EB0:
; file 0x36EB0
3000:6EB0  B8 FF 00          mov  ax,0xff
3000:6EB3  50                push ax
3000:6EB4  8D 46 9C          lea  ax,[bp-0x64]
3000:6EB7  50                push ax
3000:6EB8  FF 76 04          push word [bp+0x4]
3000:6EBB  E8 58 42          call 0xb116
3000:6EBE  83 C4 06          add  sp,byte +0x6
3000:6EC1  89 46 E4          mov  [bp-0x1c],ax
3000:6EC4  0B C0             or   ax,ax
3000:6EC6  74 03             jz   0x6ecb
3000:6EC8  E9 75 FE          jmp  0x6d40
3000:6ECB  EB C8             jmp  0x6e95
```

## State Boundary

| Address | Role in this slice |
| ---: | --- |
| `[7134]` | Active candidate/search record pointer set by `3000:6B6C`. |
| `[record+0]` | Record word passed as the suffix-handler context argument. |
| `[record+3]` | Variant class used by the `3000:6E9C` table. |
| `[record+6]` | Field/type code used for direct `3000:B116` expansion and special-case routing. |

## Bottom

The record formatter is now mapped through its whitespace split, direct field
expansion attempts, compound field joins, variant dispatch table, and final
`0xFF` confirmation expansion. The first suffix/word-form island at
`3000:6ECE` is expanded in
[`banked-suffix-dispatch.md`](banked-suffix-dispatch.md). Remaining depth is
the next suffix-handler family at `3000:7164`, helper `3000:7686`, and the
deeper dictionary field expander `3000:B116`.
