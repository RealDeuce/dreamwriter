# Banked Candidate Formatter

This slice maps the visible candidate-row formatter below the banked candidate
manager in [`banked-candidate-manager.md`](banked-candidate-manager.md). It
covers `3000:6964..6B40`, the helper that turns packed candidate record fields
into numbered display rows.

No image assets are reached in this slice.

## Call Site And Record Shape

`3000:A1AA` calls the formatter in the visible candidate-list path. The
arguments are a caller comparison string at `7767`, a destination scratch buffer,
the one-based row number, and a candidate record pointer.

```asm
candidate_formatter_callsite_C3000_A374:
; file 0x3A374
3000:A374  FF 76 08          push word [bp+0x8]
3000:A377  8B 46 06          mov  ax,[bp+0x6]
3000:A37A  40                inc  ax
3000:A37B  50                push ax
3000:A37C  8D 86 32 FF       lea  ax,[bp-0xce]
3000:A380  50                push ax
3000:A381  B8 67 77          mov  ax,0x7767
3000:A384  50                push ax
3000:A385  E8 DC C5          call 0x6964
3000:A388  83 C4 08          add  sp,byte +0x8
3000:A38B  8D 86 32 FF       lea  ax,[bp-0xce]
3000:A38F  50                push ax
3000:A390  FF 76 08          push word [bp+0x8]
3000:A393  E8 74 F2          call 0x960a
```

The formatter treats the candidate record as:

- byte `0`: selector, converted to zero-based `[bp-02]`;
- byte `1`: subtype/class selector in `DI`;
- following NUL-terminated text field;
- a second NUL-terminated text field after the first terminator when the subtype
  is nonzero.

The RAM/data pointers used by this code, such as `0x24F4`, `0x2508`, `0x2544`,
`0x256E`, `0x2584`, and `0x2589`, are `DS=3C00` runtime data pointers, not ROM
file offsets.

## Formatter Entry

`3000:6964` writes the row prefix as `"N) "`, reads the selector and subtype,
and splits into two high-level paths. A zero subtype is the simple path: resolve
the selector label through `3000:6B40`, pad to column `0x0E`, and append the
remaining record text. A nonzero subtype first skips the first NUL-terminated
field with `3000:9626`, then dispatches on the zero-based selector through the
inline table at `3000:6A1E`.

```asm
candidate_row_formatter_C3000_6964:
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
3000:697F  8B 5E 0A          mov  bx,[bp+0xa]
3000:6982  FF 46 0A          inc  word [bp+0xa]
3000:6985  8A 07             mov  al,[bx]
3000:6987  2A E4             sub  ah,ah
3000:6989  48                dec  ax
3000:698A  89 46 FE          mov  [bp-0x2],ax
3000:698D  8B 5E 0A          mov  bx,[bp+0xa]
3000:6990  FF 46 0A          inc  word [bp+0xa]
3000:6993  8A 07             mov  al,[bx]
3000:6995  2A E4             sub  ah,ah
3000:6997  8B F8             mov  di,ax
3000:6999  0B FF             or   di,di
3000:699B  75 2D             jnz  0x69ca
3000:699D  FF 76 FE          push word [bp-0x2]
3000:69A0  56                push si
3000:69A1  E8 9C 01          call 0x6b40
3000:69A4  83 C4 04          add  sp,byte +0x4
3000:69A7  8B F0             mov  si,ax
3000:69A9  EB 05             jmp  0x69b0
3000:69AB  90                nop
3000:69AC  C6 04 20          mov  byte [si],0x20
3000:69AF  46                inc  si
3000:69B0  8B C6             mov  ax,si
3000:69B2  2B 46 06          sub  ax,[bp+0x6]
3000:69B5  3D 0E 00          cmp  ax,0xe
3000:69B8  7C F2             jl   0x69ac
3000:69BA  FF 76 0A          push word [bp+0xa]
3000:69BD  56                push si
3000:69BE  E8 49 2C          call 0x960a
3000:69C1  83 C4 04          add  sp,byte +0x4
3000:69C4  5E                pop  si
3000:69C5  5F                pop  di
3000:69C6  8B E5             mov  sp,bp
3000:69C8  5D                pop  bp
3000:69C9  C3                ret
3000:69CA  8B 46 0A          mov  ax,[bp+0xa]
3000:69CD  89 46 F6          mov  [bp-0xa],ax
3000:69D0  50                push ax
3000:69D1  E8 52 2C          call 0x9626
3000:69D4  83 C4 02          add  sp,byte +0x2
3000:69D7  40                inc  ax
3000:69D8  89 46 0A          mov  [bp+0xa],ax
3000:69DB  C7 46 FA 00 00    mov  word [bp-0x6],0
3000:69E0  8B 46 FE          mov  ax,[bp-0x2]
3000:69E3  3D 0B 00          cmp  ax,0xb
3000:69E6  77 4E             ja   0x6a36
3000:69E8  03 C0             add  ax,ax
3000:69EA  93                xchg ax,bx
3000:69EB  2E FF A7 1E 6A    jmp  [cs:bx+0x6a1e]
```

The selector table is data, not code:

| Zero-based selector | Target |
| ---: | --- |
| `0`, `1` | `3000:6A12` |
| `2`, `3`, `4`, `6`, `8`, `9` | `3000:6A36` |
| `5`, `7` | `3000:69F0` |
| `10`, `11` | `3000:6A00` |

The selector pretests set `[bp-06]`, which chooses between the direct
`3000:6A36` row body and the alternate `3000:6AC4` row body.

```asm
candidate_formatter_selector_tests_C3000_69F0:
; file 0x369F0
3000:69F0  83 FF 07          cmp  di,byte +0x7
3000:69F3  74 15             jz   0x6a0a
3000:69F5  83 FF 1B          cmp  di,byte +0x1b
3000:69F8  74 10             jz   0x6a0a
3000:69FA  B8 01 00          mov  ax,0x1
3000:69FD  EB 0D             jmp  0x6a0c
3000:69FF  90                nop
3000:6A00  83 FF 0F          cmp  di,byte +0xf
3000:6A03  74 F5             jz   0x69fa
3000:6A05  83 FF 09          cmp  di,byte +0x9
3000:6A08  74 F0             jz   0x69fa
3000:6A0A  2B C0             sub  ax,ax
3000:6A0C  89 46 FA          mov  [bp-0x6],ax
3000:6A0F  EB 25             jmp  0x6a36
3000:6A11  90                nop
3000:6A12  83 FF 0B          cmp  di,byte +0xb
3000:6A15  74 F3             jz   0x6a0a
3000:6A17  83 FF 0D          cmp  di,byte +0xd
3000:6A1A  75 DE             jnz  0x69fa
3000:6A1C  EB EC             jmp  0x6a0a
```

## Row Bodies

The direct body resolves the selector label, pads the output to column `0x0E`,
and appends subtype-specific fragments from runtime tables. Subtype `7` with
selectors `10` or `11` has a special fragment path through `[256E]`; otherwise
the subtype label comes from `[2544 + 2 * subtype]`. All successful non-simple
paths converge at `3000:6B26`, which appends `": "` and the second candidate
text field.

The alternate body starts at `3000:6AC4`. It appends the subtype label first,
pads to column `0x0D`, appends runtime fragment `2584`, the first text field,
runtime fragment `24F4`, the selector label from `[2508 + 2 * selector]`, then
`") : "` and the second text field.

```asm
candidate_formatter_row_bodies_C3000_6A36:
; file 0x36A36
3000:6A36  83 7E FA 00       cmp  word [bp-0x6],byte +0x0
3000:6A3A  74 03             jz   0x6a3f
3000:6A3C  E9 85 00          jmp  0x6ac4
3000:6A3F  FF 76 FE          push word [bp-0x2]
3000:6A42  56                push si
3000:6A43  E8 FA 00          call 0x6b40
3000:6A46  83 C4 04          add  sp,byte +0x4
3000:6A49  8B F0             mov  si,ax
3000:6A4B  EB 05             jmp  0x6a52
3000:6A4D  90                nop
3000:6A4E  C6 04 20          mov  byte [si],0x20
3000:6A51  46                inc  si
3000:6A52  8B C6             mov  ax,si
3000:6A54  2B 46 06          sub  ax,[bp+0x6]
3000:6A57  3D 0E 00          cmp  ax,0xe
3000:6A5A  7C F2             jl   0x6a4e
3000:6A5C  83 FF 07          cmp  di,byte +0x7
3000:6A5F  75 35             jnz  0x6a96
3000:6A61  83 7E FE 0A       cmp  word [bp-0x2],byte +0xa
3000:6A65  74 06             jz   0x6a6d
3000:6A67  83 7E FE 0B       cmp  word [bp-0x2],byte +0xb
3000:6A6B  75 29             jnz  0x6a96
3000:6A6D  FF 36 6E 25       push word [0x256e]
3000:6A71  56                push si
3000:6A72  E8 95 2B          call 0x960a
3000:6A75  83 C4 04          add  sp,byte +0x4
3000:6A78  8B F0             mov  si,ax
3000:6A7A  B8 84 25          mov  ax,0x2584
3000:6A7D  50                push ax
3000:6A7E  56                push si
3000:6A7F  E8 88 2B          call 0x960a
3000:6A82  83 C4 04          add  sp,byte +0x4
3000:6A85  8B F0             mov  si,ax
3000:6A87  FF 76 F6          push word [bp-0xa]
3000:6A8A  56                push si
3000:6A8B  E8 7C 2B          call 0x960a
3000:6A8E  83 C4 04          add  sp,byte +0x4
3000:6A91  8B F0             mov  si,ax
3000:6A93  E9 90 00          jmp  0x6b26
3000:6A96  8B DF             mov  bx,di
3000:6A98  D1 E3             shl  bx,1
3000:6A9A  FF B7 44 25       push word [bx+0x2544]
3000:6A9E  56                push si
3000:6A9F  E8 68 2B          call 0x960a
3000:6AA2  83 C4 04          add  sp,byte +0x4
3000:6AA5  8B F0             mov  si,ax
3000:6AA7  FF 76 F6          push word [bp-0xa]
3000:6AAA  FF 76 04          push word [bp+0x4]
3000:6AAD  E8 EE 2B          call 0x969e
3000:6AB0  83 C4 04          add  sp,byte +0x4
3000:6AB3  0B C0             or   ax,ax
3000:6AB5  75 C3             jnz  0x6a7a
3000:6AB7  83 FF 07          cmp  di,byte +0x7
3000:6ABA  74 6A             jz   0x6b26
3000:6ABC  83 FF 1B          cmp  di,byte +0x1b
3000:6ABF  74 65             jz   0x6b26
3000:6AC1  EB B7             jmp  0x6a7a
3000:6AC3  90                nop
3000:6AC4  8B DF             mov  bx,di
3000:6AC6  D1 E3             shl  bx,1
3000:6AC8  FF B7 44 25       push word [bx+0x2544]
3000:6ACC  56                push si
3000:6ACD  E8 3A 2B          call 0x960a
3000:6AD0  83 C4 04          add  sp,byte +0x4
3000:6AD3  8B F0             mov  si,ax
3000:6AD5  EB 05             jmp  0x6adc
3000:6AD7  90                nop
3000:6AD8  C6 04 20          mov  byte [si],0x20
3000:6ADB  46                inc  si
3000:6ADC  8B C6             mov  ax,si
3000:6ADE  2B 46 06          sub  ax,[bp+0x6]
3000:6AE1  3D 0D 00          cmp  ax,0xd
3000:6AE4  7C F2             jl   0x6ad8
3000:6AE6  B8 84 25          mov  ax,0x2584
3000:6AE9  50                push ax
3000:6AEA  56                push si
3000:6AEB  E8 1C 2B          call 0x960a
3000:6AEE  83 C4 04          add  sp,byte +0x4
3000:6AF1  8B F0             mov  si,ax
3000:6AF3  FF 76 F6          push word [bp-0xa]
3000:6AF6  56                push si
3000:6AF7  E8 10 2B          call 0x960a
3000:6AFA  83 C4 04          add  sp,byte +0x4
3000:6AFD  8B F0             mov  si,ax
3000:6AFF  B8 F4 24          mov  ax,0x24f4
3000:6B02  50                push ax
3000:6B03  56                push si
3000:6B04  E8 03 2B          call 0x960a
3000:6B07  83 C4 04          add  sp,byte +0x4
3000:6B0A  8B F0             mov  si,ax
3000:6B0C  8B 5E FE          mov  bx,[bp-0x2]
3000:6B0F  D1 E3             shl  bx,1
3000:6B11  FF B7 08 25       push word [bx+0x2508]
3000:6B15  56                push si
3000:6B16  E8 F1 2A          call 0x960a
3000:6B19  83 C4 04          add  sp,byte +0x4
3000:6B1C  8B F0             mov  si,ax
3000:6B1E  C6 04 29          mov  byte [si],0x29
3000:6B21  46                inc  si
3000:6B22  C6 04 20          mov  byte [si],0x20
3000:6B25  46                inc  si
3000:6B26  C6 04 3A          mov  byte [si],0x3a
3000:6B29  46                inc  si
3000:6B2A  C6 04 20          mov  byte [si],0x20
3000:6B2D  46                inc  si
3000:6B2E  FF 76 0A          push word [bp+0xa]
3000:6B31  56                push si
3000:6B32  E8 D5 2A          call 0x960a
3000:6B35  83 C4 04          add  sp,byte +0x4
3000:6B38  8B F0             mov  si,ax
3000:6B3A  5E                pop  si
3000:6B3B  5F                pop  di
3000:6B3C  8B E5             mov  sp,bp
3000:6B3E  5D                pop  bp
3000:6B3F  C3                ret
```

## Selector Label Resolver

`3000:6B40` appends a selector label to the destination. Valid selectors are
bounded by runtime word `[2522]` and resolved through the pointer table at
`[2508 + 2 * selector]`. Out-of-range selectors append fallback string
`2589`.

```asm
candidate_selector_label_C3000_6B40:
; file 0x36B40
3000:6B40  55                push bp
3000:6B41  8B EC             mov  bp,sp
3000:6B43  83 7E 06 00       cmp  word [bp+0x6],byte +0x0
3000:6B47  7C 08             jl   0x6b51
3000:6B49  A1 22 25          mov  ax,[0x2522]
3000:6B4C  39 46 06          cmp  [bp+0x6],ax
3000:6B4F  7C 0F             jl   0x6b60
3000:6B51  B8 89 25          mov  ax,0x2589
3000:6B54  50                push ax
3000:6B55  FF 76 04          push word [bp+0x4]
3000:6B58  E8 AF 2A          call 0x960a
3000:6B5B  83 C4 04          add  sp,byte +0x4
3000:6B5E  5D                pop  bp
3000:6B5F  C3                ret
3000:6B60  8B 5E 06          mov  bx,[bp+0x6]
3000:6B63  D1 E3             shl  bx,1
3000:6B65  FF B7 08 25       push word [bx+0x2508]
3000:6B69  EB EA             jmp  0x6b55
```

## Bottom

The visible row formatter is now mapped through its selector table, row body
choices, and label resolver. The next record-aware formatter layer at
`3000:6B6C` is expanded in
[`banked-candidate-record-formatter.md`](banked-candidate-record-formatter.md).
