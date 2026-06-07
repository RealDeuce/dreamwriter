# Banked Dictionary Stream Init

This slice maps the dictionary stream setup helpers after
[`banked-multiword-expansion.md`](banked-multiword-expansion.md). It covers
`3000:8854..8A0D`: little-endian word reads from the compressed bitstream,
dictionary structure initialization at `3000:88A0`, pointer-table construction
at `3000:89B6`, and the dictionary page loader at `3000:89E2`.

No image assets are reached in this slice.

## Stream Setup

`3000:8854` reads `[bp+6]` 16-bit words into the caller buffer at `[bp+4]` by
calling the arbitrary-width bit reader `3000:ADBE` twice per word. The first
8-bit read becomes the low byte and the second read becomes the high byte.

`3000:88A0` initializes the dictionary structure at `3C00:7502`. It seeds
fixed table destinations, resets/seeks the active dictionary stream to logical
offset `0x100`, reads the 16-byte dictionary header, converts it into eight
little-endian words, and loads the variable tables that follow it. It then
builds two pointer tables into the loaded string data, derives the first
compressed 1 KiB page index at `[dict+0x22]`, and rebases the local table
pointers so later routines can index them relative to compressed token ranges.

`3000:89B6` builds a table of string pointers by walking `count` NUL-terminated
strings. Each destination word receives the start of the next string, and the
return value is the first byte after the last copied string.

`3000:89E2` loads the current compressed dictionary page. It adds global page
index `[8A5A]` to `[7524]` (`dict+0x22`), multiplies by `0x400`, seeks through
`3000:66AE`, and reads one 1 KiB page into `0x864E`.

```asm
dictionary_stream_init_C3000_8854:
; file 0x38854
3000:8854  55                push bp
3000:8855  8B EC             mov bp,sp
3000:8857  83 EC 06          sub sp,byte +0x6
3000:885A  57                push di
3000:885B  56                push si
3000:885C  8B 76 04          mov si,[bp+0x4]
3000:885F  8B 46 06          mov ax,[bp+0x6]
3000:8862  89 46 FC          mov [bp-0x4],ax
3000:8865  EB 26             jmp short 0x888d
3000:8867  90                nop
3000:8868  B8 08 00          mov ax,0x8
3000:886B  50                push ax
3000:886C  E8 4F 25          call 0xadbe
3000:886F  83 C4 02          add sp,byte +0x2
3000:8872  8B F8             mov di,ax
3000:8874  B8 08 00          mov ax,0x8
3000:8877  50                push ax
3000:8878  E8 43 25          call 0xadbe
3000:887B  83 C4 02          add sp,byte +0x2
3000:887E  89 46 FE          mov [bp-0x2],ax
3000:8881  8A 66 FE          mov ah,[bp-0x2]
3000:8884  2A C0             sub al,al
3000:8886  0B C7             or ax,di
3000:8888  89 04             mov [si],ax
3000:888A  83 C6 02          add si,byte +0x2
3000:888D  8B 46 FC          mov ax,[bp-0x4]
3000:8890  FF 4E FC          dec word [bp-0x4]
3000:8893  0B C0             or ax,ax
3000:8895  7F D1             jg 0x8868
3000:8897  2B C0             sub ax,ax
3000:8899  5E                pop si
3000:889A  5F                pop di
3000:889B  8B E5             mov sp,bp
3000:889D  5D                pop bp
3000:889E  C3                ret
3000:889F  90                nop
3000:88A0  55                push bp
3000:88A1  8B EC             mov bp,sp
3000:88A3  83 EC 14          sub sp,byte +0x14
3000:88A6  56                push si
3000:88A7  C7 06 50 8A BC 29 mov word [0x8a50],0x29bc
3000:88AD  BE 02 75          mov si,0x7502
3000:88B0  C7 44 24 4E 86    mov word [si+0x24],0x864e
3000:88B5  C7 44 12 22 76    mov word [si+0x12],0x7622
3000:88BA  C7 44 16 2A 75    mov word [si+0x16],0x752a
3000:88BF  C7 44 10 36 72    mov word [si+0x10],0x7236
3000:88C4  E8 37 DD          call 0x65fe
3000:88C7  0B C0             or ax,ax
3000:88C9  7E 22             jng 0x88ed
3000:88CB  B8 00 01          mov ax,0x100
3000:88CE  99                cwd
3000:88CF  52                push dx
3000:88D0  50                push ax
3000:88D1  E8 DA DD          call 0x66ae
3000:88D4  83 C4 04          add sp,byte +0x4
3000:88D7  0B C0             or ax,ax
3000:88D9  75 12             jnz 0x88ed
3000:88DB  B8 10 00          mov ax,0x10
3000:88DE  50                push ax
3000:88DF  8D 46 EC          lea ax,[bp-0x14]
3000:88E2  50                push ax
3000:88E3  E8 D0 0C          call 0x95b6
3000:88E6  83 C4 04          add sp,byte +0x4
3000:88E9  0B C0             or ax,ax
3000:88EB  74 07             jz 0x88f4
3000:88ED  2B C0             sub ax,ax
3000:88EF  5E                pop si
3000:88F0  8B E5             mov sp,bp
3000:88F2  5D                pop bp
3000:88F3  C3                ret
3000:88F4  B8 08 00          mov ax,0x8
3000:88F7  50                push ax
3000:88F8  56                push si
3000:88F9  8D 46 EC          lea ax,[bp-0x14]
3000:88FC  50                push ax
3000:88FD  E8 D4 0C          call 0x95d4
3000:8900  83 C4 06          add sp,byte +0x6
3000:8903  FF 74 08          push word [si+0x8]
3000:8906  FF 74 12          push word [si+0x12]
3000:8909  E8 AA 0C          call 0x95b6
3000:890C  83 C4 04          add sp,byte +0x4
3000:890F  0B C0             or ax,ax
3000:8911  75 DA             jnz 0x88ed
3000:8913  8B 44 0A          mov ax,[si+0xa]
3000:8916  D1 E0             shl ax,1
3000:8918  50                push ax
3000:8919  FF 74 16          push word [si+0x16]
3000:891C  E8 97 0C          call 0x95b6
3000:891F  83 C4 04          add sp,byte +0x4
3000:8922  0B C0             or ax,ax
3000:8924  75 C7             jnz 0x88ed
3000:8926  FF 74 0E          push word [si+0xe]
3000:8929  FF 74 10          push word [si+0x10]
3000:892C  E8 87 0C          call 0x95b6
3000:892F  83 C4 04          add sp,byte +0x4
3000:8932  0B C0             or ax,ax
3000:8934  75 B7             jnz 0x88ed
3000:8936  C7 44 14 82 71    mov word [si+0x14],0x7182
3000:893B  C7 44 18 E0 75    mov word [si+0x18],0x75e0
3000:8940  FF 74 08          push word [si+0x8]
3000:8943  FF 74 14          push word [si+0x14]
3000:8946  FF 74 10          push word [si+0x10]
3000:8949  E8 6A 00          call 0x89b6
3000:894C  83 C4 06          add sp,byte +0x6
3000:894F  89 46 FE          mov [bp-0x2],ax
3000:8952  FF 74 0C          push word [si+0xc]
3000:8955  FF 74 18          push word [si+0x18]
3000:8958  50                push ax
3000:8959  E8 5A 00          call 0x89b6
3000:895C  83 C4 06          add sp,byte +0x6
3000:895F  8B 44 0A          mov ax,[si+0xa]
3000:8962  D1 E0             shl ax,1
3000:8964  03 44 08          add ax,[si+0x8]
3000:8967  03 44 0E          add ax,[si+0xe]
3000:896A  05 0F 01          add ax,0x10f
3000:896D  25 00 FC          and ax,0xfc00
3000:8970  99                cwd
3000:8971  33 C2             xor ax,dx
3000:8973  2B C2             sub ax,dx
3000:8975  B9 0A 00          mov cx,0xa
3000:8978  D3 F8             sar ax,cl
3000:897A  33 C2             xor ax,dx
3000:897C  2B C2             sub ax,dx
3000:897E  40                inc ax
3000:897F  89 44 22          mov [si+0x22],ax
3000:8982  8B 1E 50 8A       mov bx,[0x8a50]
3000:8986  8B 47 04          mov ax,[bx+0x4]
3000:8989  05 10 00          add ax,0x10
3000:898C  89 44 1A          mov [si+0x1a],ax
3000:898F  03 44 08          add ax,[si+0x8]
3000:8992  89 44 1C          mov [si+0x1c],ax
3000:8995  C6 44 20 01       mov byte [si+0x20],0x1
3000:8999  8B 44 1A          mov ax,[si+0x1a]
3000:899C  29 44 12          sub [si+0x12],ax
3000:899F  8B 44 1A          mov ax,[si+0x1a]
3000:89A2  D1 E0             shl ax,1
3000:89A4  29 44 14          sub [si+0x14],ax
3000:89A7  8B 44 1C          mov ax,[si+0x1c]
3000:89AA  D1 E0             shl ax,1
3000:89AC  29 44 16          sub [si+0x16],ax
3000:89AF  8B C6             mov ax,si
3000:89B1  5E                pop si
3000:89B2  8B E5             mov sp,bp
3000:89B4  5D                pop bp
3000:89B5  C3                ret
3000:89B6  55                push bp
3000:89B7  8B EC             mov bp,sp
3000:89B9  57                push di
3000:89BA  56                push si
3000:89BB  8B 76 04          mov si,[bp+0x4]
3000:89BE  8B 7E 06          mov di,[bp+0x6]
3000:89C1  EB 0E             jmp short 0x89d1
3000:89C3  90                nop
3000:89C4  83 C7 02          add di,byte +0x2
3000:89C7  89 75 FE          mov [di-0x2],si
3000:89CA  46                inc si
3000:89CB  80 7C FF 00       cmp byte [si-0x1],0x0
3000:89CF  75 F9             jnz 0x89ca
3000:89D1  8B 46 08          mov ax,[bp+0x8]
3000:89D4  FF 4E 08          dec word [bp+0x8]
3000:89D7  0B C0             or ax,ax
3000:89D9  7F E9             jg 0x89c4
3000:89DB  8B C6             mov ax,si
3000:89DD  5E                pop si
3000:89DE  5F                pop di
3000:89DF  5D                pop bp
3000:89E0  C3                ret
3000:89E1  90                nop
3000:89E2  A1 5A 8A          mov ax,[0x8a5a]
3000:89E5  03 06 24 75       add ax,[0x7524]
3000:89E9  99                cwd
3000:89EA  B1 0A             mov cl,0xa
3000:89EC  D1 E0             shl ax,1
3000:89EE  D1 D2             rcl dx,1
3000:89F0  FE C9             dec cl
3000:89F2  75 F8             jnz 0x89ec
3000:89F4  52                push dx
3000:89F5  50                push ax
3000:89F6  E8 B5 DC          call 0x66ae
3000:89F9  83 C4 04          add sp,byte +0x4
3000:89FC  B8 00 04          mov ax,0x400
3000:89FF  50                push ax
3000:8A00  B8 4E 86          mov ax,0x864e
3000:8A03  50                push ax
3000:8A04  E8 08 DC          call 0x660f
3000:8A07  83 C4 04          add sp,byte +0x4
3000:8A0A  B8 01 00          mov ax,0x1
3000:8A0D  C3                ret
```

## Boundary

The dictionary structure initializer and page loader are now mapped through
`3000:8A0D`. The next adjacent routine starts at `3000:8A0E` and
post-processes the staged decoded word buffer at `8AB2`.
