# Banked Multiword Expansion

This slice maps the compound and multiword candidate expansion helpers after
[`banked-inflection-helper-tail.md`](banked-inflection-helper-tail.md). It
covers `3000:84A8..8853`: the compound rewriter, the space-separated multiword
builder reached from `3000:79E8`, the parallel-array compactor, and the
`0x0E` marker rewriter.

No image assets are reached in this slice.

## Compound Rewrite

`3000:84A8` receives four string pointers. It copies the first and third
fragments into a stack buffer with `3000:960A`, validates the partially rebuilt
candidate through `3000:B0E6`, and only preserves the first fragment when that
validation succeeds. It then appends the second fragment, validates the original
candidate at `[bp+4]`, and, when valid, inserts separator byte `0x0E` before
appending `[bp+4]` into the rebuilt string. The result is copied back over
`[bp+4]`; the return value is one when the rebuilt candidate's first byte is at
least `0x01`.

## Multiword Path

`3000:8528` is the space-aware expansion path selected by `3000:79E8`. If
`3000:B116` expands the whole candidate directly, it appends a single
candidate/type pair and returns. Otherwise it splits the input around the first
space into first and second word buffers, recursively expands each side through
`3000:7A1E`, filters the returned record classes, and stitches valid entries
back into the caller's parallel pointer/type arrays.

The accepted first-side record classes are `1`, `3`, `5`, `0x15`, and `0x17`;
other classes are removed through `3000:87D6`. Record class `7` is normalized
to class `0x16` through `3000:83E4` on the first-side pass. On the second-side
pass, only class `7` survives. If the second-side record has flag bit `0x0400`,
the stored record pointer is advanced by eight bytes before the merged output
string is appended.

`3000:87D6` shifts both output arrays left together until a zero terminator or
four entries have been processed. `3000:8808` copies a candidate to a scratch
buffer and expands every internal `0x0E` marker by inserting the caller-provided
string.

```asm
multiword_expansion_C3000_84A8:
; file 0x384A8
3000:84A8  55                push bp
3000:84A9  8B EC             mov bp,sp
3000:84AB  83 EC 1A          sub sp,byte +0x1a
3000:84AE  56                push si
3000:84AF  FF 76 08          push word [bp+0x8]
3000:84B2  FF 76 04          push word [bp+0x4]
3000:84B5  8D 46 E6          lea ax,[bp-0x1a]
3000:84B8  50                push ax
3000:84B9  E8 4E 11          call 0x960a
3000:84BC  83 C4 04          add sp,byte +0x4
3000:84BF  50                push ax
3000:84C0  E8 47 11          call 0x960a
3000:84C3  83 C4 04          add sp,byte +0x4
3000:84C6  8B F0             mov si,ax
3000:84C8  8D 46 E6          lea ax,[bp-0x1a]
3000:84CB  50                push ax
3000:84CC  E8 17 2C          call 0xb0e6
3000:84CF  83 C4 02          add sp,byte +0x2
3000:84D2  0B C0             or ax,ax
3000:84D4  75 08             jnz 0x84de
3000:84D6  8D 46 E6          lea ax,[bp-0x1a]
3000:84D9  8B F0             mov si,ax
3000:84DB  C6 04 00          mov byte [si],0x0
3000:84DE  FF 76 0A          push word [bp+0xa]
3000:84E1  FF 76 06          push word [bp+0x6]
3000:84E4  E8 23 11          call 0x960a
3000:84E7  83 C4 04          add sp,byte +0x4
3000:84EA  FF 76 04          push word [bp+0x4]
3000:84ED  E8 F6 2B          call 0xb0e6
3000:84F0  83 C4 02          add sp,byte +0x2
3000:84F3  0B C0             or ax,ax
3000:84F5  74 15             jz 0x850c
3000:84F7  8D 46 E6          lea ax,[bp-0x1a]
3000:84FA  3B C6             cmp ax,si
3000:84FC  74 04             jz 0x8502
3000:84FE  C6 04 0E          mov byte [si],0xe
3000:8501  46                inc si
3000:8502  FF 76 04          push word [bp+0x4]
3000:8505  56                push si
3000:8506  E8 01 11          call 0x960a
3000:8509  83 C4 04          add sp,byte +0x4
3000:850C  8D 46 E6          lea ax,[bp-0x1a]
3000:850F  50                push ax
3000:8510  FF 76 04          push word [bp+0x4]
3000:8513  E8 F4 10          call 0x960a
3000:8516  83 C4 04          add sp,byte +0x4
3000:8519  8B 5E 04          mov bx,[bp+0x4]
3000:851C  80 3F 01          cmp byte [bx],0x1
3000:851F  1B C0             sbb ax,ax
3000:8521  40                inc ax
3000:8522  5E                pop si
3000:8523  8B E5             mov sp,bp
3000:8525  5D                pop bp
3000:8526  C3                ret
3000:8527  90                nop
3000:8528  55                push bp
3000:8529  8B EC             mov bp,sp
3000:852B  81 EC 88 00       sub sp,0x88
3000:852F  57                push di
3000:8530  56                push si
3000:8531  8B 76 04          mov si,[bp+0x4]
3000:8534  C7 46 B0 00 00    mov word [bp-0x50],0x0
3000:8539  C7 86 7E FF 00 00 mov word [bp-0x82],0x0
3000:853F  B8 FF 00          mov ax,0xff
3000:8542  50                push ax
3000:8543  8D 46 B4          lea ax,[bp-0x4c]
3000:8546  50                push ax
3000:8547  56                push si
3000:8548  E8 CB 2B          call 0xb116
3000:854B  83 C4 06          add sp,byte +0x6
3000:854E  89 46 E6          mov [bp-0x1a],ax
3000:8551  40                inc ax
3000:8552  74 5C             jz 0x85b0
3000:8554  83 7E E6 00       cmp word [bp-0x1a],byte +0x0
3000:8558  75 08             jnz 0x8562
3000:855A  2B C0             sub ax,ax
3000:855C  5E                pop si
3000:855D  5F                pop di
3000:855E  8B E5             mov sp,bp
3000:8560  5D                pop bp
3000:8561  C3                ret
3000:8562  FF 76 E6          push word [bp-0x1a]
3000:8565  E8 7C FE          call 0x83e4
3000:8568  83 C4 02          add sp,byte +0x2
3000:856B  A3 80 71          mov [0x7180],ax
3000:856E  0B C0             or ax,ax
3000:8570  74 E8             jz 0x855a
3000:8572  8D 46 B4          lea ax,[bp-0x4c]
3000:8575  50                push ax
3000:8576  56                push si
3000:8577  E8 90 10          call 0x960a
3000:857A  83 C4 04          add sp,byte +0x4
3000:857D  8B 9E 7E FF       mov bx,[bp-0x82]
3000:8581  D1 E3             shl bx,1
3000:8583  03 5E 08          add bx,[bp+0x8]
3000:8586  A1 80 71          mov ax,[0x7180]
3000:8589  89 07             mov [bx],ax
3000:858B  8B 9E 7E FF       mov bx,[bp-0x82]
3000:858F  FF 86 7E FF       inc word [bp-0x82]
3000:8593  D1 E3             shl bx,1
3000:8595  03 5E 06          add bx,[bp+0x6]
3000:8598  89 37             mov [bx],si
3000:859A  8B 9E 7E FF       mov bx,[bp-0x82]
3000:859E  D1 E3             shl bx,1
3000:85A0  03 5E 06          add bx,[bp+0x6]
3000:85A3  C7 07 00 00       mov word [bx],0x0
3000:85A7  B8 01 00          mov ax,0x1
3000:85AA  5E                pop si
3000:85AB  5F                pop di
3000:85AC  8B E5             mov sp,bp
3000:85AE  5D                pop bp
3000:85AF  C3                ret
3000:85B0  56                push si
3000:85B1  8D 46 CC          lea ax,[bp-0x34]
3000:85B4  50                push ax
3000:85B5  E8 52 10          call 0x960a
3000:85B8  83 C4 04          add sp,byte +0x4
3000:85BB  B8 20 00          mov ax,0x20
3000:85BE  50                push ax
3000:85BF  8D 46 CC          lea ax,[bp-0x34]
3000:85C2  50                push ax
3000:85C3  E8 A0 10          call 0x9666
3000:85C6  83 C4 04          add sp,byte +0x4
3000:85C9  8B F8             mov di,ax
3000:85CB  47                inc di
3000:85CC  B8 20 00          mov ax,0x20
3000:85CF  50                push ax
3000:85D0  56                push si
3000:85D1  E8 66 10          call 0x963a
3000:85D4  83 C4 04          add sp,byte +0x4
3000:85D7  89 46 B2          mov [bp-0x4e],ax
3000:85DA  57                push di
3000:85DB  8D 46 80          lea ax,[bp-0x80]
3000:85DE  50                push ax
3000:85DF  E8 28 10          call 0x960a
3000:85E2  83 C4 04          add sp,byte +0x4
3000:85E5  FF 76 B2          push word [bp-0x4e]
3000:85E8  8D 46 E8          lea ax,[bp-0x18]
3000:85EB  50                push ax
3000:85EC  E8 1B 10          call 0x960a
3000:85EF  83 C4 04          add sp,byte +0x4
3000:85F2  C6 05 00          mov byte [di],0x0
3000:85F5  8B 5E B2          mov bx,[bp-0x4e]
3000:85F8  C6 07 00          mov byte [bx],0x0
3000:85FB  56                push si
3000:85FC  8D 46 B4          lea ax,[bp-0x4c]
3000:85FF  50                push ax
3000:8600  E8 07 10          call 0x960a
3000:8603  83 C4 04          add sp,byte +0x4
3000:8606  C7 86 7E FF 00 00 mov word [bp-0x82],0x0
3000:860C  FF 76 08          push word [bp+0x8]
3000:860F  FF 76 06          push word [bp+0x6]
3000:8612  8D 46 B4          lea ax,[bp-0x4c]
3000:8615  50                push ax
3000:8616  E8 05 F4          call 0x7a1e
3000:8619  83 C4 06          add sp,byte +0x6
3000:861C  0B C0             or ax,ax
3000:861E  75 03             jnz 0x8623
3000:8620  E9 E8 00          jmp 0x870b
3000:8623  E9 AD 00          jmp 0x86d3
3000:8626  03 46 08          add ax,[bp+0x8]
3000:8629  89 86 7A FF       mov [bp-0x86],ax
3000:862D  8B D8             mov bx,ax
3000:862F  8B 1F             mov bx,[bx]
3000:8631  83 7F 06 07       cmp word [bx+0x6],byte +0x7
3000:8635  75 10             jnz 0x8647
3000:8637  B8 16 00          mov ax,0x16
3000:863A  50                push ax
3000:863B  E8 A6 FD          call 0x83e4
3000:863E  83 C4 02          add sp,byte +0x2
3000:8641  8B 9E 7A FF       mov bx,[bp-0x86]
3000:8645  89 07             mov [bx],ax
3000:8647  8B 9E 7E FF       mov bx,[bp-0x82]
3000:864B  D1 E3             shl bx,1
3000:864D  03 5E 08          add bx,[bp+0x8]
3000:8650  8B 1F             mov bx,[bx]
3000:8652  8B 47 06          mov ax,[bx+0x6]
3000:8655  3D 01 00          cmp ax,0x1
3000:8658  74 38             jz 0x8692
3000:865A  3D 03 00          cmp ax,0x3
3000:865D  74 33             jz 0x8692
3000:865F  3D 05 00          cmp ax,0x5
3000:8662  74 2E             jz 0x8692
3000:8664  3D 15 00          cmp ax,0x15
3000:8667  74 29             jz 0x8692
3000:8669  3D 17 00          cmp ax,0x17
3000:866C  74 24             jz 0x8692
3000:866E  8B 86 7E FF       mov ax,[bp-0x82]
3000:8672  D1 E0             shl ax,1
3000:8674  89 86 7A FF       mov [bp-0x86],ax
3000:8678  03 46 08          add ax,[bp+0x8]
3000:867B  50                push ax
3000:867C  8B 86 7A FF       mov ax,[bp-0x86]
3000:8680  03 46 06          add ax,[bp+0x6]
3000:8683  50                push ax
3000:8684  E8 4F 01          call 0x87d6
3000:8687  83 C4 04          add sp,byte +0x4
3000:868A  C7 06 80 71 00 00 mov word [0x7180],0x0
3000:8690  EB 41             jmp short 0x86d3
3000:8692  8B 9E 7E FF       mov bx,[bp-0x82]
3000:8696  D1 E3             shl bx,1
3000:8698  03 5E 06          add bx,[bp+0x6]
3000:869B  FF 37             push word [bx]
3000:869D  56                push si
3000:869E  E8 69 0F          call 0x960a
3000:86A1  83 C4 04          add sp,byte +0x4
3000:86A4  8D 46 E8          lea ax,[bp-0x18]
3000:86A7  50                push ax
3000:86A8  56                push si
3000:86A9  E8 5C 01          call 0x8808
3000:86AC  83 C4 04          add sp,byte +0x4
3000:86AF  8B 9E 7E FF       mov bx,[bp-0x82]
3000:86B3  FF 86 7E FF       inc word [bp-0x82]
3000:86B7  D1 E3             shl bx,1
3000:86B9  03 5E 06          add bx,[bp+0x6]
3000:86BC  89 37             mov [bx],si
3000:86BE  8B 9E 7E FF       mov bx,[bp-0x82]
3000:86C2  D1 E3             shl bx,1
3000:86C4  03 5E 06          add bx,[bp+0x6]
3000:86C7  FF 77 FE          push word [bx-0x2]
3000:86CA  E8 59 0F          call 0x9626
3000:86CD  83 C4 02          add sp,byte +0x2
3000:86D0  8B F0             mov si,ax
3000:86D2  46                inc si
3000:86D3  8B 86 7E FF       mov ax,[bp-0x82]
3000:86D7  D1 E0             shl ax,1
3000:86D9  89 86 7C FF       mov [bp-0x84],ax
3000:86DD  8B D8             mov bx,ax
3000:86DF  03 5E 06          add bx,[bp+0x6]
3000:86E2  83 3F 00          cmp word [bx],byte +0x0
3000:86E5  74 03             jz 0x86ea
3000:86E7  E9 3C FF          jmp 0x8626
3000:86EA  83 BE 7E FF 00    cmp word [bp-0x82],byte +0x0
3000:86EF  74 1A             jz 0x870b
3000:86F1  8B 9E 7E FF       mov bx,[bp-0x82]
3000:86F5  D1 E3             shl bx,1
3000:86F7  03 5E 06          add bx,[bp+0x6]
3000:86FA  FF 77 FE          push word [bx-0x2]
3000:86FD  E8 26 0F          call 0x9626
3000:8700  83 C4 02          add sp,byte +0x2
3000:8703  8B F0             mov si,ax
3000:8705  46                inc si
3000:8706  C7 46 B0 01 00    mov word [bp-0x50],0x1
3000:870B  8B 86 7E FF       mov ax,[bp-0x82]
3000:870F  D1 E0             shl ax,1
3000:8711  89 86 7A FF       mov [bp-0x86],ax
3000:8715  03 46 08          add ax,[bp+0x8]
3000:8718  50                push ax
3000:8719  8B 86 7A FF       mov ax,[bp-0x86]
3000:871D  03 46 06          add ax,[bp+0x6]
3000:8720  50                push ax
3000:8721  8D 46 80          lea ax,[bp-0x80]
3000:8724  50                push ax
3000:8725  E8 F6 F2          call 0x7a1e
3000:8728  83 C4 06          add sp,byte +0x6
3000:872B  0B C0             or ax,ax
3000:872D  75 03             jnz 0x8732
3000:872F  E9 9A 00          jmp 0x87cc
3000:8732  EB 78             jmp short 0x87ac
3000:8734  8B 9E 78 FF       mov bx,[bp-0x88]
3000:8738  83 7F 06 07       cmp word [bx+0x6],byte +0x7
3000:873C  74 14             jz 0x8752
3000:873E  FF B6 7C FF       push word [bp-0x84]
3000:8742  8B 86 7A FF       mov ax,[bp-0x86]
3000:8746  03 46 06          add ax,[bp+0x6]
3000:8749  50                push ax
3000:874A  E8 89 00          call 0x87d6
3000:874D  83 C4 04          add sp,byte +0x4
3000:8750  EB 5A             jmp short 0x87ac
3000:8752  8B 86 7E FF       mov ax,[bp-0x82]
3000:8756  D1 E0             shl ax,1
3000:8758  03 46 08          add ax,[bp+0x8]
3000:875B  89 86 78 FF       mov [bp-0x88],ax
3000:875F  8B D8             mov bx,ax
3000:8761  8B 1F             mov bx,[bx]
3000:8763  F7 47 04 00 04    test word [bx+0x4],0x400
3000:8768  74 05             jz 0x876f
3000:876A  8B D8             mov bx,ax
3000:876C  83 07 08          add word [bx],byte +0x8
3000:876F  8D 46 CC          lea ax,[bp-0x34]
3000:8772  50                push ax
3000:8773  56                push si
3000:8774  E8 93 0E          call 0x960a
3000:8777  83 C4 04          add sp,byte +0x4
3000:877A  8B F8             mov di,ax
3000:877C  8B 9E 7E FF       mov bx,[bp-0x82]
3000:8780  D1 E3             shl bx,1
3000:8782  03 5E 06          add bx,[bp+0x6]
3000:8785  FF 37             push word [bx]
3000:8787  57                push di
3000:8788  E8 7F 0E          call 0x960a
3000:878B  83 C4 04          add sp,byte +0x4
3000:878E  8B 9E 7E FF       mov bx,[bp-0x82]
3000:8792  FF 86 7E FF       inc word [bp-0x82]
3000:8796  D1 E3             shl bx,1
3000:8798  03 5E 06          add bx,[bp+0x6]
3000:879B  89 37             mov [bx],si
3000:879D  56                push si
3000:879E  E8 85 0E          call 0x9626
3000:87A1  83 C4 02          add sp,byte +0x2
3000:87A4  40                inc ax
3000:87A5  8B F0             mov si,ax
3000:87A7  C7 46 B0 01 00    mov word [bp-0x50],0x1
3000:87AC  8B 86 7E FF       mov ax,[bp-0x82]
3000:87B0  D1 E0             shl ax,1
3000:87B2  89 86 7A FF       mov [bp-0x86],ax
3000:87B6  03 46 08          add ax,[bp+0x8]
3000:87B9  89 86 7C FF       mov [bp-0x84],ax
3000:87BD  8B D8             mov bx,ax
3000:87BF  8B 07             mov ax,[bx]
3000:87C1  89 86 78 FF       mov [bp-0x88],ax
3000:87C5  0B C0             or ax,ax
3000:87C7  74 03             jz 0x87cc
3000:87C9  E9 68 FF          jmp 0x8734
3000:87CC  8B 46 B0          mov ax,[bp-0x50]
3000:87CF  5E                pop si
3000:87D0  5F                pop di
3000:87D1  8B E5             mov sp,bp
3000:87D3  5D                pop bp
3000:87D4  C3                ret
3000:87D5  90                nop
3000:87D6  55                push bp
3000:87D7  8B EC             mov bp,sp
3000:87D9  83 EC 02          sub sp,byte +0x2
3000:87DC  57                push di
3000:87DD  56                push si
3000:87DE  2B F6             sub si,si
3000:87E0  EB 13             jmp short 0x87f5
3000:87E2  83 FE 04          cmp si,byte +0x4
3000:87E5  7D 1A             jnl 0x8801
3000:87E7  8B 41 02          mov ax,[bx+di+0x2]
3000:87EA  89 01             mov [bx+di],ax
3000:87EC  8B 5E 06          mov bx,[bp+0x6]
3000:87EF  8B 41 02          mov ax,[bx+di+0x2]
3000:87F2  89 01             mov [bx+di],ax
3000:87F4  46                inc si
3000:87F5  8B FE             mov di,si
3000:87F7  D1 E7             shl di,1
3000:87F9  8B 5E 04          mov bx,[bp+0x4]
3000:87FC  83 39 00          cmp word [bx+di],byte +0x0
3000:87FF  75 E1             jnz 0x87e2
3000:8801  5E                pop si
3000:8802  5F                pop di
3000:8803  8B E5             mov sp,bp
3000:8805  5D                pop bp
3000:8806  C3                ret
3000:8807  90                nop
3000:8808  55                push bp
3000:8809  8B EC             mov bp,sp
3000:880B  83 EC 34          sub sp,byte +0x34
3000:880E  57                push di
3000:880F  56                push si
3000:8810  8B 7E 04          mov di,[bp+0x4]
3000:8813  8D 46 CE          lea ax,[bp-0x32]
3000:8816  8B F0             mov si,ax
3000:8818  EB 17             jmp short 0x8831
3000:881A  80 3D 0E          cmp byte [di],0xe
3000:881D  75 0C             jnz 0x882b
3000:881F  FF 76 06          push word [bp+0x6]
3000:8822  56                push si
3000:8823  E8 E4 0D          call 0x960a
3000:8826  83 C4 04          add sp,byte +0x4
3000:8829  8B F0             mov si,ax
3000:882B  8A 05             mov al,[di]
3000:882D  47                inc di
3000:882E  88 04             mov [si],al
3000:8830  46                inc si
3000:8831  80 3D 00          cmp byte [di],0x0
3000:8834  75 E4             jnz 0x881a
3000:8836  FF 76 06          push word [bp+0x6]
3000:8839  56                push si
3000:883A  E8 CD 0D          call 0x960a
3000:883D  83 C4 04          add sp,byte +0x4
3000:8840  8D 46 CE          lea ax,[bp-0x32]
3000:8843  50                push ax
3000:8844  FF 76 04          push word [bp+0x4]
3000:8847  E8 C0 0D          call 0x960a
3000:884A  83 C4 04          add sp,byte +0x4
3000:884D  5E                pop si
3000:884E  5F                pop di
3000:884F  8B E5             mov sp,bp
3000:8851  5D                pop bp
3000:8852  C3                ret
3000:8853  90                nop
```

## Boundary

The compound rewrite, multiword builder, array compactor, and `0x0E` marker
rewriter are now mapped through `3000:8853`. The next adjacent routine starts at
`3000:8854` and is documented in
[`banked-dictionary-stream-init.md`](banked-dictionary-stream-init.md).
