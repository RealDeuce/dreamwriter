# Banked Compressed Subheader Loader

This slice maps the loader immediately after
[`banked-compound-normalizer.md`](banked-compound-normalizer.md). It covers
`3000:7972..79E7`, the compressed-word subheader loader called after
`3000:96D6` opens the compressed dictionary stream and loads the first page.

No image assets are reached in this slice.

## Loader Flow

`3000:7972` consumes the current bitstream through the bit readers documented in
[`../spell-engine.md`](../spell-engine.md): `3000:8854` reads little-endian
16-bit words by calling the arbitrary-width bit reader at `3000:ADBE`.

The routine performs four setup steps:

| Step | Runtime state |
| --- | --- |
| Read eight words | Loads `3C00:9650..965F` from the bitstream and seeds the return byte count at `0x10`. |
| Load symbol bytes | Sets `[9662] = 0x7166`, then reads `[9652]` bytes into `3C00:7166` with `3000:ADBE(8)`. |
| Load word-offset words | Sets `[9660] = 0x7136`, then reads `[9658]` words into `3C00:7136` with `3000:8854`. |
| Skip page payload | Sets `[9664] = 0x2B30`, skips `[965C] * 8` bits with `3000:AFB4`, and returns `0x10 + [9652] + ([9658] * 2) + [965C]`. |

That return value is added to the logical stream offset by the caller
`3000:96D6`, before the caller continues loading more small tables.

```asm
compressed_subheader_loader_C3000_7972:
; file 0x37972
3000:7972  55                push bp
3000:7973  8B EC             mov bp,sp
3000:7975  83 EC 06          sub sp,byte +0x6
3000:7978  57                push di
3000:7979  56                push si
3000:797A  B8 08 00          mov ax,0x8
3000:797D  50                push ax
3000:797E  B8 50 96          mov ax,0x9650
3000:7981  50                push ax
3000:7982  E8 CF 0E          call 0x8854
3000:7985  83 C4 04          add sp,byte +0x4
3000:7988  C7 46 FE 10 00    mov word [bp-0x2],0x10
3000:798D  BE 66 71          mov si,0x7166
3000:7990  89 36 62 96       mov [0x9662],si
3000:7994  8B 3E 52 96       mov di,[0x9652]
3000:7998  01 7E FE          add [bp-0x2],di
3000:799B  B8 08 00          mov ax,0x8
3000:799E  50                push ax
3000:799F  E8 1C 34          call 0xadbe
3000:79A2  83 C4 02          add sp,byte +0x2
3000:79A5  88 04             mov [si],al
3000:79A7  46                inc si
3000:79A8  4F                dec di
3000:79A9  0B FF             or di,di
3000:79AB  7F EE             jg 0x799b
3000:79AD  FF 36 58 96       push word [0x9658]
3000:79B1  B8 36 71          mov ax,0x7136
3000:79B4  A3 60 96          mov [0x9660],ax
3000:79B7  50                push ax
3000:79B8  E8 99 0E          call 0x8854
3000:79BB  83 C4 04          add sp,byte +0x4
3000:79BE  A1 58 96          mov ax,[0x9658]
3000:79C1  D1 E0             shl ax,1
3000:79C3  01 46 FE          add [bp-0x2],ax
3000:79C6  C7 06 64 96 30 2B mov word [0x9664],0x2b30
3000:79CC  A1 5C 96          mov ax,[0x965c]
3000:79CF  B1 03             mov cl,0x3
3000:79D1  D3 E0             shl ax,cl
3000:79D3  50                push ax
3000:79D4  E8 DD 35          call 0xafb4
3000:79D7  83 C4 02          add sp,byte +0x2
3000:79DA  8B 46 FE          mov ax,[bp-0x2]
3000:79DD  03 06 5C 96       add ax,[0x965c]
3000:79E1  5E                pop si
3000:79E2  5F                pop di
3000:79E3  8B E5             mov sp,bp
3000:79E5  5D                pop bp
3000:79E6  C3                ret
3000:79E7  90                nop
```

## Boundary

The compressed-word subheader loader is now mapped. The next adjacent routine
starts at `3000:79E8` and is documented in
[`banked-candidate-expansion-dispatcher.md`](banked-candidate-expansion-dispatcher.md).
