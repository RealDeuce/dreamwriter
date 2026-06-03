# Banked Candidate Expansion Dispatcher

This slice maps the candidate-expansion dispatcher after
[`banked-compressed-subheader-loader.md`](banked-compressed-subheader-loader.md).
It covers `3000:79E8..7D0D`: the space-aware entry wrapper, the single-word
front end at `3000:7A1E`, and the local record-kind handlers before the
`3000:7D0E` jump table.

No image assets are reached in this slice.

## Entry Wrapper

`3000:79E8` receives a candidate string plus caller output/type arrays. It scans
the candidate for a space with `3000:963A`. Candidates containing a space route
to the multiword builder at `3000:8528`; all others route to the single-word
dispatcher at `3000:7A1E`.

`3000:7A1E` first copies the input into a stack buffer, asks `3000:B116` to
expand it, and stores the translated record pointer/type in `3C00:7180`. Direct
expansion appends entries through `3000:8438`; direct failure falls back to
suffix-pattern lookup through `3000:7DCA`, then dispatches on `[pattern+3]`
through the adjacent table at `3000:7D0E`.

The direct path has one special plural-like retry: translated types `0x08` and
`0x1C` with final `s` temporarily remove the final `s`, adjust `[7180]` by
`0x10`, and probe `3000:7E12`.

```asm
candidate_expansion_dispatch_C3000_79E8:
; file 0x379E8
3000:79E8  55                push bp
3000:79E9  8B EC             mov bp,sp
3000:79EB  83 EC 02          sub sp,byte +0x2
3000:79EE  56                push si
3000:79EF  8B 76 04          mov si,[bp+0x4]
3000:79F2  B8 20 00          mov ax,0x20
3000:79F5  50                push ax
3000:79F6  56                push si
3000:79F7  E8 40 1C          call 0x963a
3000:79FA  83 C4 04          add sp,byte +0x4
3000:79FD  0B C0             or ax,ax
3000:79FF  74 05             jz 0x7a06
3000:7A01  B8 28 85          mov ax,0x8528
3000:7A04  EB 03             jmp short 0x7a09
3000:7A06  B8 1E 7A          mov ax,0x7a1e
3000:7A09  89 46 FE          mov [bp-0x2],ax
3000:7A0C  FF 76 08          push word [bp+0x8]
3000:7A0F  FF 76 06          push word [bp+0x6]
3000:7A12  56                push si
3000:7A13  FF 56 FE          call [bp-0x2]
3000:7A16  83 C4 06          add sp,byte +0x6
3000:7A19  5E                pop si
3000:7A1A  8B E5             mov sp,bp
3000:7A1C  5D                pop bp
3000:7A1D  C3                ret
3000:7A1E  55                push bp
3000:7A1F  8B EC             mov bp,sp
3000:7A21  83 EC 3C          sub sp,byte +0x3c
3000:7A24  57                push di
3000:7A25  56                push si
3000:7A26  8B 76 04          mov si,[bp+0x4]
3000:7A29  56                push si
3000:7A2A  8D 46 E4          lea ax,[bp-0x1c]
3000:7A2D  50                push ax
3000:7A2E  E8 D9 1B          call 0x960a
3000:7A31  83 C4 04          add sp,byte +0x4
3000:7A34  C7 46 C6 00 00    mov word [bp-0x3a],0x0
3000:7A39  8B FE             mov di,si
3000:7A3B  B8 FF 00          mov ax,0xff
3000:7A3E  50                push ax
3000:7A3F  8D 46 CC          lea ax,[bp-0x34]
3000:7A42  50                push ax
3000:7A43  56                push si
3000:7A44  E8 CF 36          call 0xb116
3000:7A47  83 C4 06          add sp,byte +0x6
3000:7A4A  89 46 FE          mov [bp-0x2],ax
3000:7A4D  40                inc ax
3000:7A4E  75 03             jnz 0x7a53
3000:7A50  E9 EB 00          jmp 0x7b3e
3000:7A53  83 7E FE 00       cmp word [bp-0x2],byte +0x0
3000:7A57  75 09             jnz 0x7a62
3000:7A59  2B C0             sub ax,ax
3000:7A5B  5E                pop si
3000:7A5C  5F                pop di
3000:7A5D  8B E5             mov sp,bp
3000:7A5F  5D                pop bp
3000:7A60  C3                ret
3000:7A61  90                nop
3000:7A62  8D 46 CC          lea ax,[bp-0x34]
3000:7A65  50                push ax
3000:7A66  56                push si
3000:7A67  E8 A0 1B          call 0x960a
3000:7A6A  83 C4 04          add sp,byte +0x4
3000:7A6D  83 7E FE 04       cmp word [bp-0x2],byte +0x4
3000:7A71  75 1B             jnz 0x7a8e
3000:7A73  B8 06 00          mov ax,0x6
3000:7A76  50                push ax
3000:7A77  8D 46 E4          lea ax,[bp-0x1c]
3000:7A7A  50                push ax
3000:7A7B  8D 46 E4          lea ax,[bp-0x1c]
3000:7A7E  50                push ax
3000:7A7F  E8 94 36          call 0xb116
3000:7A82  83 C4 06          add sp,byte +0x6
3000:7A85  0B C0             or ax,ax
3000:7A87  7E 05             jng 0x7a8e
3000:7A89  C7 46 FE 02 00    mov word [bp-0x2],0x2
3000:7A8E  FF 76 FE          push word [bp-0x2]
3000:7A91  E8 50 09          call 0x83e4
3000:7A94  83 C4 02          add sp,byte +0x2
3000:7A97  A3 80 71          mov [0x7180],ax
3000:7A9A  0B C0             or ax,ax
3000:7A9C  74 BB             jz 0x7a59
3000:7A9E  56                push si
3000:7A9F  E8 84 1B          call 0x9626
3000:7AA2  83 C4 02          add sp,byte +0x2
3000:7AA5  8B F8             mov di,ax
3000:7AA7  FF 76 C6          push word [bp-0x3a]
3000:7AAA  FF 76 06          push word [bp+0x6]
3000:7AAD  FF 76 08          push word [bp+0x8]
3000:7AB0  56                push si
3000:7AB1  E8 84 09          call 0x8438
3000:7AB4  83 C4 08          add sp,byte +0x8
3000:7AB7  89 46 C6          mov [bp-0x3a],ax
3000:7ABA  8D 46 E4          lea ax,[bp-0x1c]
3000:7ABD  50                push ax
3000:7ABE  E8 65 1B          call 0x9626
3000:7AC1  83 C4 02          add sp,byte +0x2
3000:7AC4  48                dec ax
3000:7AC5  89 46 FC          mov [bp-0x4],ax
3000:7AC8  83 7E FE 08       cmp word [bp-0x2],byte +0x8
3000:7ACC  74 06             jz 0x7ad4
3000:7ACE  83 7E FE 1C       cmp word [bp-0x2],byte +0x1c
3000:7AD2  75 54             jnz 0x7b28
3000:7AD4  8B 5E FC          mov bx,[bp-0x4]
3000:7AD7  80 3F 73          cmp byte [bx],0x73
3000:7ADA  75 4C             jnz 0x7b28
3000:7ADC  C6 07 00          mov byte [bx],0x0
3000:7ADF  83 7E FE 08       cmp word [bp-0x2],byte +0x8
3000:7AE3  75 07             jnz 0x7aec
3000:7AE5  83 06 80 71 10    add word [0x7180],byte +0x10
3000:7AEA  EB 05             jmp short 0x7af1
3000:7AEC  83 2E 80 71 10    sub word [0x7180],byte +0x10
3000:7AF1  FF 76 FC          push word [bp-0x4]
3000:7AF4  8D 46 E4          lea ax,[bp-0x1c]
3000:7AF7  50                push ax
3000:7AF8  E8 17 03          call 0x7e12
3000:7AFB  83 C4 04          add sp,byte +0x4
3000:7AFE  0B C0             or ax,ax
3000:7B00  74 26             jz 0x7b28
3000:7B02  47                inc di
3000:7B03  8D 46 E4          lea ax,[bp-0x1c]
3000:7B06  50                push ax
3000:7B07  57                push di
3000:7B08  E8 FF 1A          call 0x960a
3000:7B0B  83 C4 04          add sp,byte +0x4
3000:7B0E  8B 5E C6          mov bx,[bp-0x3a]
3000:7B11  D1 E3             shl bx,1
3000:7B13  03 5E 06          add bx,[bp+0x6]
3000:7B16  89 3F             mov [bx],di
3000:7B18  8B 5E C6          mov bx,[bp-0x3a]
3000:7B1B  FF 46 C6          inc word [bp-0x3a]
3000:7B1E  D1 E3             shl bx,1
3000:7B20  03 5E 08          add bx,[bp+0x8]
3000:7B23  A1 80 71          mov ax,[0x7180]
3000:7B26  89 07             mov [bx],ax
3000:7B28  8B 5E C6          mov bx,[bp-0x3a]
3000:7B2B  D1 E3             shl bx,1
3000:7B2D  03 5E 08          add bx,[bp+0x8]
3000:7B30  C7 07 00 00       mov word [bx],0x0
3000:7B34  B8 01 00          mov ax,0x1
3000:7B37  5E                pop si
3000:7B38  5F                pop di
3000:7B39  8B E5             mov sp,bp
3000:7B3B  5D                pop bp
3000:7B3C  C3                ret
```

## Pattern Fallback

When `3000:B116` returns `FFFF`, the dispatcher searches suffix pattern records
with `3000:7DCA`. The matched record pointer is stored in `[7180]`; `[pattern+2]`
backs up the candidate cursor, and `[pattern+3]` selects a local handler through
the adjacent table at `3000:7D0E`.

Local handlers before the table include direct calls into the later suffix
helpers (`3000:7E12`, `3000:7FD4`, `3000:7F9C`, `3000:8056`, `3000:8290`, and
`3000:82C6`) plus short fixed-string checks against the `3C00:2AD6` suffix
string pool.

```asm
candidate_expansion_pattern_fallback_C3000_7B3E:
; file 0x37B3E
3000:7B3E  56                push si
3000:7B3F  E8 E4 1A          call 0x9626
3000:7B42  83 C4 02          add sp,byte +0x2
3000:7B45  8B F8             mov di,ax
3000:7B47  2B C6             sub ax,si
3000:7B49  50                push ax
3000:7B4A  57                push di
3000:7B4B  E8 7C 02          call 0x7dca
3000:7B4E  83 C4 04          add sp,byte +0x4
3000:7B51  A3 80 71          mov [0x7180],ax
3000:7B54  0B C0             or ax,ax
3000:7B56  75 03             jnz 0x7b5b
3000:7B58  E9 FE FE          jmp 0x7a59
3000:7B5B  8B D8             mov bx,ax
3000:7B5D  8A 47 02          mov al,[bx+0x2]
3000:7B60  2A E4             sub ah,ah
3000:7B62  2B F8             sub di,ax
3000:7B64  88 25             mov [di],ah
3000:7B66  8B 1E 80 71       mov bx,[0x7180]
3000:7B6A  8A 47 03          mov al,[bx+0x3]
3000:7B6D  3D 0A 00          cmp ax,0xa
3000:7B70  76 03             jna 0x7b75
3000:7B72  E9 E4 FE          jmp 0x7a59
3000:7B75  03 C0             add ax,ax
3000:7B77  93                xchg ax,bx
3000:7B78  2E FF A7 0E 7D    jmp [cs:bx+0x7d0e]
3000:7B7D  90                nop
3000:7B7E  57                push di
3000:7B7F  56                push si
3000:7B80  E8 8F 02          call 0x7e12
3000:7B83  83 C4 04          add sp,byte +0x4
3000:7B86  0B C0             or ax,ax
3000:7B88  75 03             jnz 0x7b8d
3000:7B8A  E9 CC FE          jmp 0x7a59
3000:7B8D  B8 07 00          mov ax,0x7
3000:7B90  50                push ax
3000:7B91  8D 46 CC          lea ax,[bp-0x34]
3000:7B94  50                push ax
3000:7B95  56                push si
3000:7B96  E8 7D 35          call 0xb116
3000:7B99  83 C4 06          add sp,byte +0x6
3000:7B9C  89 46 FE          mov [bp-0x2],ax
3000:7B9F  0B C0             or ax,ax
3000:7BA1  7F 03             jg 0x7ba6
3000:7BA3  E9 7E 01          jmp 0x7d24
3000:7BA6  B8 16 00          mov ax,0x16
3000:7BA9  50                push ax
3000:7BAA  E8 37 08          call 0x83e4
3000:7BAD  83 C4 02          add sp,byte +0x2
3000:7BB0  A3 80 71          mov [0x7180],ax
3000:7BB3  E9 6E 01          jmp 0x7d24
3000:7BB6  57                push di
3000:7BB7  56                push si
3000:7BB8  E8 19 04          call 0x7fd4
3000:7BBB  83 C4 04          add sp,byte +0x4
3000:7BBE  0B C0             or ax,ax
3000:7BC0  74 03             jz 0x7bc5
3000:7BC2  E9 5F 01          jmp 0x7d24
3000:7BC5  E9 91 FE          jmp 0x7a59
3000:7BC8  57                push di
3000:7BC9  56                push si
3000:7BCA  E8 CF 03          call 0x7f9c
3000:7BCD  EB EC             jmp short 0x7bbb
3000:7BCF  90                nop
3000:7BD0  57                push di
3000:7BD1  56                push si
3000:7BD2  E8 81 04          call 0x8056
3000:7BD5  EB E4             jmp short 0x7bbb
3000:7BD7  90                nop
3000:7BD8  8B 1E 80 71       mov bx,[0x7180]
3000:7BDC  FF 37             push word [bx]
3000:7BDE  E8 45 1A          call 0x9626
3000:7BE1  83 C4 02          add sp,byte +0x2
3000:7BE4  8B D8             mov bx,ax
3000:7BE6  80 7F FF 73       cmp byte [bx-0x1],0x73
3000:7BEA  74 08             jz 0x7bf4
3000:7BEC  57                push di
3000:7BED  56                push si
3000:7BEE  E8 9F 06          call 0x8290
3000:7BF1  EB C8             jmp short 0x7bbb
3000:7BF3  90                nop
3000:7BF4  56                push si
3000:7BF5  8D 46 CC          lea ax,[bp-0x34]
3000:7BF8  50                push ax
3000:7BF9  E8 0E 1A          call 0x960a
3000:7BFC  83 C4 04          add sp,byte +0x4
3000:7BFF  8D 46 E4          lea ax,[bp-0x1c]
3000:7C02  50                push ax
3000:7C03  56                push si
3000:7C04  E8 03 1A          call 0x960a
3000:7C07  83 C4 04          add sp,byte +0x4
3000:7C0A  8B F8             mov di,ax
3000:7C0C  4F                dec di
3000:7C0D  C6 05 00          mov byte [di],0x0
3000:7C10  8D 46 CC          lea ax,[bp-0x34]
3000:7C13  50                push ax
3000:7C14  8D 46 E4          lea ax,[bp-0x1c]
3000:7C17  50                push ax
3000:7C18  E8 EF 19          call 0x960a
3000:7C1B  83 C4 04          add sp,byte +0x4
3000:7C1E  56                push si
3000:7C1F  E8 C4 34          call 0xb0e6
3000:7C22  83 C4 02          add sp,byte +0x2
3000:7C25  0B C0             or ax,ax
3000:7C27  74 31             jz 0x7c5a
3000:7C29  B8 08 00          mov ax,0x8
3000:7C2C  50                push ax
3000:7C2D  E8 B4 07          call 0x83e4
3000:7C30  83 C4 02          add sp,byte +0x2
3000:7C33  2D 08 00          sub ax,0x8
3000:7C36  8B 5E C6          mov bx,[bp-0x3a]
3000:7C39  D1 E3             shl bx,1
3000:7C3B  03 5E 08          add bx,[bp+0x8]
3000:7C3E  89 07             mov [bx],ax
3000:7C40  8B 5E C6          mov bx,[bp-0x3a]
3000:7C43  FF 46 C6          inc word [bp-0x3a]
3000:7C46  D1 E3             shl bx,1
3000:7C48  03 5E 06          add bx,[bp+0x6]
3000:7C4B  89 37             mov [bx],si
3000:7C4D  57                push di
3000:7C4E  E8 D5 19          call 0x9626
3000:7C51  83 C4 02          add sp,byte +0x2
3000:7C54  40                inc ax
3000:7C55  8B F8             mov di,ax
3000:7C57  EB 03             jmp short 0x7c5c
3000:7C59  90                nop
3000:7C5A  8B FE             mov di,si
3000:7C5C  8D 46 E4          lea ax,[bp-0x1c]
3000:7C5F  50                push ax
3000:7C60  E8 C3 19          call 0x9626
3000:7C63  83 C4 02          add sp,byte +0x2
3000:7C66  89 46 FC          mov [bp-0x4],ax
3000:7C69  50                push ax
3000:7C6A  8D 46 E4          lea ax,[bp-0x1c]
3000:7C6D  50                push ax
3000:7C6E  E8 1F 06          call 0x8290
3000:7C71  83 C4 04          add sp,byte +0x4
3000:7C74  0B C0             or ax,ax
3000:7C76  74 2E             jz 0x7ca6
3000:7C78  8D 46 E4          lea ax,[bp-0x1c]
3000:7C7B  50                push ax
3000:7C7C  57                push di
3000:7C7D  E8 8A 19          call 0x960a
3000:7C80  83 C4 04          add sp,byte +0x4
3000:7C83  8B 5E C6          mov bx,[bp-0x3a]
3000:7C86  D1 E3             shl bx,1
3000:7C88  03 5E 06          add bx,[bp+0x6]
3000:7C8B  89 3F             mov [bx],di
3000:7C8D  8B 5E C6          mov bx,[bp-0x3a]
3000:7C90  FF 46 C6          inc word [bp-0x3a]
3000:7C93  D1 E3             shl bx,1
3000:7C95  03 5E 08          add bx,[bp+0x8]
3000:7C98  A1 80 71          mov ax,[0x7180]
3000:7C9B  89 07             mov [bx],ax
3000:7C9D  57                push di
3000:7C9E  E8 85 19          call 0x9626
3000:7CA1  83 C4 02          add sp,byte +0x2
3000:7CA4  8B F8             mov di,ax
3000:7CA6  C6 05 00          mov byte [di],0x0
3000:7CA9  8B 5E C6          mov bx,[bp-0x3a]
3000:7CAC  D1 E3             shl bx,1
3000:7CAE  03 5E 06          add bx,[bp+0x6]
3000:7CB1  C7 07 00 00       mov word [bx],0x0
3000:7CB5  80 3C 01          cmp byte [si],0x1
3000:7CB8  1B C0             sbb ax,ax
3000:7CBA  40                inc ax
3000:7CBB  5E                pop si
3000:7CBC  5F                pop di
3000:7CBD  8B E5             mov sp,bp
3000:7CBF  5D                pop bp
3000:7CC0  C3                ret
3000:7CC1  90                nop
3000:7CC2  57                push di
3000:7CC3  56                push si
3000:7CC4  E8 FF 05          call 0x82c6
3000:7CC7  E9 F1 FE          jmp 0x7bbb
3000:7CCA  B8 DE 2A          mov ax,0x2ade
3000:7CCD  50                push ax
3000:7CCE  57                push di
3000:7CCF  E8 38 19          call 0x960a
3000:7CD2  83 C4 04          add sp,byte +0x4
3000:7CD5  56                push si
3000:7CD6  E8 0D 34          call 0xb0e6
3000:7CD9  83 C4 02          add sp,byte +0x2
3000:7CDC  E9 DF FE          jmp 0x7bbe
3000:7CDF  90                nop
3000:7CE0  B8 E2 2A          mov ax,0x2ae2
3000:7CE3  EB E8             jmp short 0x7ccd
3000:7CE5  90                nop
3000:7CE6  B8 E5 2A          mov ax,0x2ae5
3000:7CE9  EB E2             jmp short 0x7ccd
3000:7CEB  90                nop
3000:7CEC  80 7D FF 75       cmp byte [di-0x1],0x75
3000:7CF0  74 03             jz 0x7cf5
3000:7CF2  E9 64 FD          jmp 0x7a59
3000:7CF5  EB DE             jmp short 0x7cd5
3000:7CF7  90                nop
3000:7CF8  80 3C 00          cmp byte [si],0x0
3000:7CFB  74 03             jz 0x7d00
3000:7CFD  E9 59 FD          jmp 0x7a59
3000:7D00  B8 E8 2A          mov ax,0x2ae8
3000:7D03  50                push ax
3000:7D04  56                push si
3000:7D05  E8 02 19          call 0x960a
3000:7D08  83 C4 04          add sp,byte +0x4
3000:7D0B  E9 26 FE          jmp 0x7b34
```

## Boundary

The front-end candidate expansion dispatcher is now mapped through the local
handlers before the jump table. The next adjacent record-kind table and
suffix-pattern lookup path are documented in
[`banked-suffix-pattern-records.md`](banked-suffix-pattern-records.md).
