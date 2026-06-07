# Banked Compound Candidate Normalizer

This slice maps the compact helper immediately after
[`banked-suffix-extended.md`](banked-suffix-extended.md). It covers
`3000:78CE..7971`, the compound/alternate candidate normalizer reached from the
candidate record formatter's whitespace-aware fallback paths.

No image assets are reached in this slice.

## Separator Scan

`3000:78CE` receives a candidate string at `[bp+4]` and a caller string at
`[bp+6]`. It copies the candidate into a stack buffer at `[bp-0x36]` while
watching for separator byte `0x0E` or slash `/`. When either separator appears,
it appends the caller string at the current buffer cursor, then expands the
fragment accumulated since the previous separator through `3000:B116` with
mode/limit `0xFF`. If any fragment expansion fails, the whole helper returns
zero.

At the end of the scan it appends the caller string one more time and copies
the rebuilt stack buffer back over the original candidate. Candidates with no
separator are still validated once through `3000:B116`; candidates with at
least one separator skip that final whole-string expansion because each fragment
has already been expanded.

```asm
compound_candidate_normalizer_C3000_78CE:
; file 0x378CE
3000:78CE  55                push bp
3000:78CF  8B EC             mov bp,sp
3000:78D1  83 EC 68          sub sp,byte +0x68
3000:78D4  57                push di
3000:78D5  56                push si
3000:78D6  8B 7E 04          mov di,[bp+0x4]
3000:78D9  8D 46 CA          lea ax,[bp-0x36]
3000:78DC  89 46 FA          mov [bp-0x6],ax
3000:78DF  8B F0             mov si,ax
3000:78E1  C7 46 98 00 00    mov word [bp-0x68],0x0
3000:78E6  EB 40             jmp short 0x7928
3000:78E8  80 3D 0E          cmp byte [di],0xe
3000:78EB  74 05             jz 0x78f2
3000:78ED  80 3D 2F          cmp byte [di],0x2f
3000:78F0  75 2B             jnz 0x791d
3000:78F2  C7 46 98 01 00    mov word [bp-0x68],0x1
3000:78F7  FF 76 06          push word [bp+0x6]
3000:78FA  FF 76 FA          push word [bp-0x6]
3000:78FD  E8 0A 1D          call 0x960a
3000:7900  83 C4 04          add sp,byte +0x4
3000:7903  89 46 FA          mov [bp-0x6],ax
3000:7906  B8 FF 00          mov ax,0xff
3000:7909  50                push ax
3000:790A  8D 46 9A          lea ax,[bp-0x66]
3000:790D  50                push ax
3000:790E  56                push si
3000:790F  E8 04 38          call 0xb116
3000:7912  83 C4 06          add sp,byte +0x6
3000:7915  0B C0             or ax,ax
3000:7917  74 51             jz 0x796a
3000:7919  8B 76 FA          mov si,[bp-0x6]
3000:791C  46                inc si
3000:791D  8B 5E FA          mov bx,[bp-0x6]
3000:7920  FF 46 FA          inc word [bp-0x6]
3000:7923  8A 05             mov al,[di]
3000:7925  47                inc di
3000:7926  88 07             mov [bx],al
3000:7928  80 3D 00          cmp byte [di],0x0
3000:792B  75 BB             jnz 0x78e8
3000:792D  FF 76 06          push word [bp+0x6]
3000:7930  FF 76 FA          push word [bp-0x6]
3000:7933  E8 D4 1C          call 0x960a
3000:7936  83 C4 04          add sp,byte +0x4
3000:7939  8D 46 CA          lea ax,[bp-0x36]
3000:793C  50                push ax
3000:793D  FF 76 04          push word [bp+0x4]
3000:7940  E8 C7 1C          call 0x960a
3000:7943  83 C4 04          add sp,byte +0x4
3000:7946  83 7E 98 00       cmp word [bp-0x68],byte +0x0
3000:794A  75 15             jnz 0x7961
3000:794C  B8 FF 00          mov ax,0xff
3000:794F  50                push ax
3000:7950  8D 46 9A          lea ax,[bp-0x66]
3000:7953  50                push ax
3000:7954  FF 76 04          push word [bp+0x4]
3000:7957  E8 BC 37          call 0xb116
3000:795A  83 C4 06          add sp,byte +0x6
3000:795D  0B C0             or ax,ax
3000:795F  74 09             jz 0x796a
3000:7961  B8 01 00          mov ax,0x1
3000:7964  5E                pop si
3000:7965  5F                pop di
3000:7966  8B E5             mov sp,bp
3000:7968  5D                pop bp
3000:7969  C3                ret
3000:796A  2B C0             sub ax,ax
3000:796C  5E                pop si
3000:796D  5F                pop di
3000:796E  8B E5             mov sp,bp
3000:7970  5D                pop bp
3000:7971  C3                ret
```

## Boundary

The compound/alternate normalizer is now mapped. The next adjacent routine
starts at `3000:7972` and is documented in
[`banked-compressed-subheader-loader.md`](banked-compressed-subheader-loader.md).
