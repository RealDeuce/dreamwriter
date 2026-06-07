# Banked Suffix Pattern Records

This slice maps the candidate-expansion fallback after
[`banked-candidate-expansion-dispatcher.md`](banked-candidate-expansion-dispatcher.md).
It covers the record-kind jump table at `3000:7D0E`, the suffix-pattern success
tail at `3000:7D24`, the pattern scanner at `3000:7DCA`, and the first part of
the final-`e` helper at `3000:7E12..7F65`.

No image assets are reached in this slice.

## Record-Kind Table

The `3000:7D0E` bytes are a word jump table indexed by `[pattern+3]`, not code:

| Record kind | Target |
| ---: | --- |
| `0x00` | `3000:7B7E` |
| `0x01` | `3000:7BB6` |
| `0x02` | `3000:7BC8` |
| `0x03` | `3000:7BD0` |
| `0x04` | `3000:7BD8` |
| `0x05` | `3000:7CC2` |
| `0x06` | `3000:7CCA` |
| `0x07` | `3000:7CE0` |
| `0x08` | `3000:7CE6` |
| `0x09` | `3000:7CEC` |
| `0x0A` | `3000:7CF8` |

The pattern records searched by `3000:7DCA` are eight bytes each at
`3C00:2A1E`. The fields proven in this slice are:

| Offset | Meaning |
| ---: | --- |
| `+0` | Pointer to a suffix string in the `3C00:2AD6` pool. |
| `+2` | Suffix length; also used to back up the candidate cursor. |
| `+3` | Record-kind selector for the table above. |
| `+6` | Expansion mode/type retried by the success tail at `3000:7D4A`. |

## Success Tail And Pattern Search

`3000:7D24` is the common success tail for several record-kind handlers. It
appends the current candidate through `3000:8438`, terminates the output pointer
array, and may re-check previous output candidates using the matched pattern's
field at `+6`. Positive re-expansion deletes an earlier candidate through
`3000:87D6`; otherwise the iterator advances. This keeps the returned parallel
candidate/type arrays de-duplicated against forms implied by the active suffix
pattern.

`3000:7DCA` walks the `3C00:2A1E` pattern table until a zero word terminator. A
record is selected when the caller's candidate is long enough for `[pattern+2]`
and the suffix at the end of the candidate matches the record's string pointer
through `3000:969E`.

```asm
suffix_pattern_tail_and_lookup_C3000_7D24:
; file 0x37D24
3000:7D24  FF 76 C6          push word [bp-0x3a]
3000:7D27  FF 76 06          push word [bp+0x6]
3000:7D2A  FF 76 08          push word [bp+0x8]
3000:7D2D  56                push si
3000:7D2E  E8 07 07          call 0x8438
3000:7D31  83 C4 08          add sp,byte +0x8
3000:7D34  89 46 CA          mov [bp-0x36],ax
3000:7D37  8B D8             mov bx,ax
3000:7D39  D1 E3             shl bx,1
3000:7D3B  03 5E 06          add bx,[bp+0x6]
3000:7D3E  C7 07 00 00       mov word [bx],0x0
3000:7D42  83 7E C6 00       cmp word [bp-0x3a],byte +0x0
3000:7D46  75 79             jnz 0x7dc1
3000:7D48  EB 6F             jmp short 0x7db9
3000:7D4A  8B 1E 80 71       mov bx,[0x7180]
3000:7D4E  FF 77 06          push word [bx+0x6]
3000:7D51  8D 46 E4          lea ax,[bp-0x1c]
3000:7D54  50                push ax
3000:7D55  8B 5E C6          mov bx,[bp-0x3a]
3000:7D58  D1 E3             shl bx,1
3000:7D5A  03 5E 06          add bx,[bp+0x6]
3000:7D5D  FF 37             push word [bx]
3000:7D5F  E8 B4 33          call 0xb116
3000:7D62  83 C4 06          add sp,byte +0x6
3000:7D65  89 46 FE          mov [bp-0x2],ax
3000:7D68  3D FF FF          cmp ax,0xffff
3000:7D6B  75 25             jnz 0x7d92
3000:7D6D  8B 1E 80 71       mov bx,[0x7180]
3000:7D71  83 7F 06 01       cmp word [bx+0x6],byte +0x1
3000:7D75  75 1B             jnz 0x7d92
3000:7D77  B8 03 00          mov ax,0x3
3000:7D7A  50                push ax
3000:7D7B  8D 46 E4          lea ax,[bp-0x1c]
3000:7D7E  50                push ax
3000:7D7F  8B 5E C6          mov bx,[bp-0x3a]
3000:7D82  D1 E3             shl bx,1
3000:7D84  03 5E 06          add bx,[bp+0x6]
3000:7D87  FF 37             push word [bx]
3000:7D89  E8 8A 33          call 0xb116
3000:7D8C  83 C4 06          add sp,byte +0x6
3000:7D8F  89 46 FE          mov [bp-0x2],ax
3000:7D92  83 7E FE 00       cmp word [bp-0x2],byte +0x0
3000:7D96  7E 1E             jng 0x7db6
3000:7D98  FF 4E CA          dec word [bp-0x36]
3000:7D9B  8B 46 C6          mov ax,[bp-0x3a]
3000:7D9E  D1 E0             shl ax,1
3000:7DA0  89 46 C4          mov [bp-0x3c],ax
3000:7DA3  03 46 08          add ax,[bp+0x8]
3000:7DA6  50                push ax
3000:7DA7  8B 46 C4          mov ax,[bp-0x3c]
3000:7DAA  03 46 06          add ax,[bp+0x6]
3000:7DAD  50                push ax
3000:7DAE  E8 25 0A          call 0x87d6
3000:7DB1  83 C4 04          add sp,byte +0x4
3000:7DB4  EB 03             jmp short 0x7db9
3000:7DB6  FF 46 C6          inc word [bp-0x3a]
3000:7DB9  8B 46 CA          mov ax,[bp-0x36]
3000:7DBC  39 46 C6          cmp [bp-0x3a],ax
3000:7DBF  7C 89             jl 0x7d4a
3000:7DC1  8B 5E 06          mov bx,[bp+0x6]
3000:7DC4  83 3F 01          cmp word [bx],byte +0x1
3000:7DC7  E9 EE FE          jmp 0x7cb8
3000:7DCA  55                push bp
3000:7DCB  8B EC             mov bp,sp
3000:7DCD  83 EC 04          sub sp,byte +0x4
3000:7DD0  57                push di
3000:7DD1  56                push si
3000:7DD2  8B 76 04          mov si,[bp+0x4]
3000:7DD5  BF 1E 2A          mov di,0x2a1e
3000:7DD8  EB 2B             jmp short 0x7e05
3000:7DDA  8A 45 02          mov al,[di+0x2]
3000:7DDD  2A E4             sub ah,ah
3000:7DDF  89 46 FC          mov [bp-0x4],ax
3000:7DE2  39 46 06          cmp [bp+0x6],ax
3000:7DE5  72 1B             jc 0x7e02
3000:7DE7  FF 35             push word [di]
3000:7DE9  8B C6             mov ax,si
3000:7DEB  2B 46 FC          sub ax,[bp-0x4]
3000:7DEE  50                push ax
3000:7DEF  E8 AC 18          call 0x969e
3000:7DF2  83 C4 04          add sp,byte +0x4
3000:7DF5  0B C0             or ax,ax
3000:7DF7  75 09             jnz 0x7e02
3000:7DF9  8B C7             mov ax,di
3000:7DFB  5E                pop si
3000:7DFC  5F                pop di
3000:7DFD  8B E5             mov sp,bp
3000:7DFF  5D                pop bp
3000:7E00  C3                ret
3000:7E01  90                nop
3000:7E02  83 C7 08          add di,byte +0x8
3000:7E05  83 3D 00          cmp word [di],byte +0x0
3000:7E08  75 D0             jnz 0x7dda
3000:7E0A  2B C0             sub ax,ax
3000:7E0C  5E                pop si
3000:7E0D  5F                pop di
3000:7E0E  8B E5             mov sp,bp
3000:7E10  5D                pop bp
3000:7E11  C3                ret
```

## Final-E Helper Start

`3000:7E12` is one of the suffix handlers reached by the record-kind path and
also by the direct candidate expansion plural retry. If the candidate ends in
`s`, it appends another `s` and returns failure (`0`) without probing. If the
candidate ends in `e`, it dispatches on the preceding letter `c..z` through the
inline table at `3000:7F66`. Other endings fall through to a direct dictionary
membership check through `3000:B0E6`.

The code below maps the local handlers before the `3000:7F66` table. The full
final-letter table is the next boundary.

```asm
suffix_pattern_final_e_start_C3000_7E12:
; file 0x37E12
3000:7E12  55                push bp
3000:7E13  8B EC             mov bp,sp
3000:7E15  57                push di
3000:7E16  56                push si
3000:7E17  8B 76 04          mov si,[bp+0x4]
3000:7E1A  8B 7E 06          mov di,[bp+0x6]
3000:7E1D  80 7D FF 65       cmp byte [di-0x1],0x65
3000:7E21  74 13             jz 0x7e36
3000:7E23  80 7D FF 73       cmp byte [di-0x1],0x73
3000:7E27  75 4B             jnz 0x7e74
3000:7E29  C6 05 73          mov byte [di],0x73
3000:7E2C  47                inc di
3000:7E2D  C6 05 00          mov byte [di],0x0
3000:7E30  2B C0             sub ax,ax
3000:7E32  5E                pop si
3000:7E33  5F                pop di
3000:7E34  5D                pop bp
3000:7E35  C3                ret
3000:7E36  8A 45 FE          mov al,[di-0x2]
3000:7E39  2A E4             sub ah,ah
3000:7E3B  2D 63 00          sub ax,0x63
3000:7E3E  3D 17 00          cmp ax,0x17
3000:7E41  76 03             jna 0x7e46
3000:7E43  E9 50 01          jmp 0x7f96
3000:7E46  03 C0             add ax,ax
3000:7E48  93                xchg ax,bx
3000:7E49  2E FF A7 66 7F    jmp [cs:bx+0x7f66]
3000:7E4E  C6 45 FF 65       mov byte [di-0x1],0x65
3000:7E52  E9 41 01          jmp 0x7f96
3000:7E55  90                nop
3000:7E56  C6 45 FE 79       mov byte [di-0x2],0x79
3000:7E5A  C6 45 FF 00       mov byte [di-0x1],0x0
3000:7E5E  56                push si
3000:7E5F  E8 84 32          call 0xb0e6
3000:7E62  83 C4 02          add sp,byte +0x2
3000:7E65  0B C0             or ax,ax
3000:7E67  74 03             jz 0x7e6c
3000:7E69  E9 CD 00          jmp 0x7f39
3000:7E6C  C6 45 FE 69       mov byte [di-0x2],0x69
3000:7E70  C6 45 FF 65       mov byte [di-0x1],0x65
3000:7E74  56                push si
3000:7E75  E8 6E 32          call 0xb0e6
3000:7E78  83 C4 02          add sp,byte +0x2
3000:7E7B  5E                pop si
3000:7E7C  5F                pop di
3000:7E7D  5D                pop bp
3000:7E7E  C3                ret
3000:7E7F  90                nop
3000:7E80  80 7D FD 74       cmp byte [di-0x3],0x74
3000:7E84  74 EE             jz 0x7e74
3000:7E86  C6 45 FF 00       mov byte [di-0x1],0x0
3000:7E8A  56                push si
3000:7E8B  E8 58 32          call 0xb0e6
3000:7E8E  83 C4 02          add sp,byte +0x2
3000:7E91  0B C0             or ax,ax
3000:7E93  74 03             jz 0x7e98
3000:7E95  E9 A1 00          jmp 0x7f39
3000:7E98  EB D6             jmp short 0x7e70
3000:7E9A  8A 45 FE          mov al,[di-0x2]
3000:7E9D  38 45 FD          cmp [di-0x3],al
3000:7EA0  75 28             jnz 0x7eca
3000:7EA2  C6 45 FF 00       mov byte [di-0x1],0x0
3000:7EA6  56                push si
3000:7EA7  E8 3C 32          call 0xb0e6
3000:7EAA  83 C4 02          add sp,byte +0x2
3000:7EAD  0B C0             or ax,ax
3000:7EAF  74 03             jz 0x7eb4
3000:7EB1  E9 85 00          jmp 0x7f39
3000:7EB4  C6 45 FE 00       mov byte [di-0x2],0x0
3000:7EB8  56                push si
3000:7EB9  E8 2A 32          call 0xb0e6
3000:7EBC  83 C4 02          add sp,byte +0x2
3000:7EBF  0B C0             or ax,ax
3000:7EC1  75 76             jnz 0x7f39
3000:7EC3  C6 45 FE 73       mov byte [di-0x2],0x73
3000:7EC7  EB A7             jmp short 0x7e70
3000:7EC9  90                nop
3000:7ECA  C6 05 00          mov byte [di],0x0
3000:7ECD  56                push si
3000:7ECE  E8 15 32          call 0xb0e6
3000:7ED1  83 C4 02          add sp,byte +0x2
3000:7ED4  0B C0             or ax,ax
3000:7ED6  75 61             jnz 0x7f39
3000:7ED8  C6 45 FF 69       mov byte [di-0x1],0x69
3000:7EDC  C6 05 73          mov byte [di],0x73
3000:7EDF  C6 45 01 00       mov byte [di+0x1],0x0
3000:7EE3  56                push si
3000:7EE4  E8 FF 31          call 0xb0e6
3000:7EE7  83 C4 02          add sp,byte +0x2
3000:7EEA  0B C0             or ax,ax
3000:7EEC  75 4B             jnz 0x7f39
3000:7EEE  C6 45 FF 00       mov byte [di-0x1],0x0
3000:7EF2  E9 7F FF          jmp 0x7e74
3000:7EF5  90                nop
3000:7EF6  8A 45 FE          mov al,[di-0x2]
3000:7EF9  38 45 FD          cmp [di-0x3],al
3000:7EFC  75 29             jnz 0x7f27
3000:7EFE  83 EF 02          sub di,byte +0x2
3000:7F01  C6 05 00          mov byte [di],0x0
3000:7F04  B8 EB 2A          mov ax,0x2aeb
3000:7F07  50                push ax
3000:7F08  B8 EC 2A          mov ax,0x2aec
3000:7F0B  50                push ax
3000:7F0C  57                push di
3000:7F0D  56                push si
3000:7F0E  E8 97 05          call 0x84a8
3000:7F11  83 C4 08          add sp,byte +0x8
3000:7F14  5E                pop si
3000:7F15  5F                pop di
3000:7F16  5D                pop bp
3000:7F17  C3                ret
3000:7F18  56                push si
3000:7F19  E8 CA 31          call 0xb0e6
3000:7F1C  83 C4 02          add sp,byte +0x2
3000:7F1F  0B C0             or ax,ax
3000:7F21  75 16             jnz 0x7f39
3000:7F23  C6 45 FE 66       mov byte [di-0x2],0x66
3000:7F27  C6 45 FF 00       mov byte [di-0x1],0x0
3000:7F2B  56                push si
3000:7F2C  E8 B7 31          call 0xb0e6
3000:7F2F  83 C4 02          add sp,byte +0x2
3000:7F32  0B C0             or ax,ax
3000:7F34  75 03             jnz 0x7f39
3000:7F36  E9 15 FF          jmp 0x7e4e
3000:7F39  B8 01 00          mov ax,0x1
3000:7F3C  5E                pop si
3000:7F3D  5F                pop di
3000:7F3E  5D                pop bp
3000:7F3F  C3                ret
3000:7F40  56                push si
3000:7F41  E8 A2 31          call 0xb0e6
3000:7F44  83 C4 02          add sp,byte +0x2
3000:7F47  0B C0             or ax,ax
3000:7F49  75 EE             jnz 0x7f39
3000:7F4B  C6 45 FE 78       mov byte [di-0x2],0x78
3000:7F4F  C6 45 FF 00       mov byte [di-0x1],0x0
3000:7F53  56                push si
3000:7F54  E8 8F 31          call 0xb0e6
3000:7F57  83 C4 02          add sp,byte +0x2
3000:7F5A  0B C0             or ax,ax
3000:7F5C  75 DB             jnz 0x7f39
3000:7F5E  C6 45 FD 65       mov byte [di-0x3],0x65
3000:7F62  E9 0F FF          jmp 0x7e74
3000:7F65  90                nop
```

## Boundary

The record-kind table, suffix-pattern scanner, and first final-`e` helper body
are now mapped. The next adjacent final-letter table and helper bodies are
documented in
[`banked-suffix-final-letter-extended.md`](banked-suffix-final-letter-extended.md).
