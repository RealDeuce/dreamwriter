# Banked Extended Final-Letter Suffix Helpers

This slice maps the final-letter table after
[`banked-suffix-pattern-records.md`](banked-suffix-pattern-records.md). It
covers the `3000:7F66` `c..z` table used by `3000:7E12` and the following code
at `3000:7F96..8231`, including helper entries `3000:7F9C`, `3000:7FD4`, and
`3000:8056`.

No image assets are reached in this slice.

## C-Z Table

The `3000:7F66` bytes are a word table indexed by the letter before a final
`e`, after subtracting `c`. They are not executable code:

| Letter | Target |
| --- | --- |
| `c` | `3000:7F40` |
| `h` | `3000:7E80` |
| `i` | `3000:7E56` |
| `o` | `3000:7F27` |
| `s` | `3000:7E9A` |
| `v` | `3000:7F18` |
| `x` | `3000:7EEE` |
| `z` | `3000:7EF6` |
| other `c..z` letters | `3000:7F96` |

`3000:7F96` clears the current cursor byte and falls back into the direct
dictionary check path at `3000:7E74`.

## Helper Bodies

`3000:7F9C` is a small `i -> y` retry helper. `3000:7FD4` handles final
`b/i/l` cases, including `cal` and final `b` suffix strings from the
`3C00:2AD6` pool. `3000:8056` is a larger helper with record-type gates:
record type `0x0B` first tries string `2AF5`, record type `0x0D` first tries
`2AF9`, and then the routine dispatches on final letters `a..y` through the
next inline table at `3000:8232`.

```asm
suffix_extended_final_letter_C3000_7F96:
; file 0x37F96
3000:7F96  C6 05 00          mov byte [di],0x0
3000:7F99  E9 D8 FE          jmp 0x7e74
3000:7F9C  55                push bp
3000:7F9D  8B EC             mov bp,sp
3000:7F9F  57                push di
3000:7FA0  56                push si
3000:7FA1  8B 76 04          mov si,[bp+0x4]
3000:7FA4  8B 7E 06          mov di,[bp+0x6]
3000:7FA7  80 7D FF 69       cmp byte [di-0x1],0x69
3000:7FAB  75 1B             jnz 0x7fc8
3000:7FAD  C6 45 FF 79       mov byte [di-0x1],0x79
3000:7FB1  56                push si
3000:7FB2  E8 31 31          call 0xb0e6
3000:7FB5  83 C4 02          add sp,byte +0x2
3000:7FB8  0B C0             or ax,ax
3000:7FBA  74 08             jz 0x7fc4
3000:7FBC  B8 01 00          mov ax,0x1
3000:7FBF  5E                pop si
3000:7FC0  5F                pop di
3000:7FC1  5D                pop bp
3000:7FC2  C3                ret
3000:7FC3  90                nop
3000:7FC4  C6 45 FF 69       mov byte [di-0x1],0x69
3000:7FC8  56                push si
3000:7FC9  E8 1A 31          call 0xb0e6
3000:7FCC  83 C4 02          add sp,byte +0x2
3000:7FCF  5E                pop si
3000:7FD0  5F                pop di
3000:7FD1  5D                pop bp
3000:7FD2  C3                ret
3000:7FD3  90                nop
3000:7FD4  55                push bp
3000:7FD5  8B EC             mov bp,sp
3000:7FD7  57                push di
3000:7FD8  56                push si
3000:7FD9  8B 76 04          mov si,[bp+0x4]
3000:7FDC  8B 7E 06          mov di,[bp+0x6]
3000:7FDF  8A 45 FF          mov al,[di-0x1]
3000:7FE2  2A E4             sub ah,ah
3000:7FE4  3D 62 00          cmp ax,0x62
3000:7FE7  74 5F             jz 0x8048
3000:7FE9  3D 69 00          cmp ax,0x69
3000:7FEC  74 0A             jz 0x7ff8
3000:7FEE  3D 6C 00          cmp ax,0x6c
3000:7FF1  74 15             jz 0x8008
3000:7FF3  C6 05 00          mov byte [di],0x0
3000:7FF6  EB 04             jmp short 0x7ffc
3000:7FF8  C6 45 FF 79       mov byte [di-0x1],0x79
3000:7FFC  56                push si
3000:7FFD  E8 E6 30          call 0xb0e6
3000:8000  83 C4 02          add sp,byte +0x2
3000:8003  5E                pop si
3000:8004  5F                pop di
3000:8005  5D                pop bp
3000:8006  C3                ret
3000:8007  90                nop
3000:8008  80 7D FE 61       cmp byte [di-0x2],0x61
3000:800C  75 20             jnz 0x802e
3000:800E  80 7D FD 63       cmp byte [di-0x3],0x63
3000:8012  75 1A             jnz 0x802e
3000:8014  83 EF 02          sub di,byte +0x2
3000:8017  C6 05 00          mov byte [di],0x0
3000:801A  B8 EE 2A          mov ax,0x2aee
3000:801D  50                push ax
3000:801E  B8 EF 2A          mov ax,0x2aef
3000:8021  50                push ax
3000:8022  57                push di
3000:8023  56                push si
3000:8024  E8 81 04          call 0x84a8
3000:8027  83 C4 08          add sp,byte +0x8
3000:802A  5E                pop si
3000:802B  5F                pop di
3000:802C  5D                pop bp
3000:802D  C3                ret
3000:802E  C6 05 6C          mov byte [di],0x6c
3000:8031  C6 45 01 00       mov byte [di+0x1],0x0
3000:8035  56                push si
3000:8036  E8 AD 30          call 0xb0e6
3000:8039  83 C4 02          add sp,byte +0x2
3000:803C  0B C0             or ax,ax
3000:803E  74 B3             jz 0x7ff3
3000:8040  B8 01 00          mov ax,0x1
3000:8043  5E                pop si
3000:8044  5F                pop di
3000:8045  5D                pop bp
3000:8046  C3                ret
3000:8047  90                nop
3000:8048  B8 F2 2A          mov ax,0x2af2
3000:804B  50                push ax
3000:804C  57                push di
3000:804D  E8 BA 15          call 0x960a
3000:8050  83 C4 04          add sp,byte +0x4
3000:8053  EB E0             jmp short 0x8035
3000:8055  90                nop
3000:8056  55                push bp
3000:8057  8B EC             mov bp,sp
3000:8059  83 EC 30          sub sp,byte +0x30
3000:805C  57                push di
3000:805D  56                push si
3000:805E  8B 76 04          mov si,[bp+0x4]
3000:8061  8B 7E 06          mov di,[bp+0x6]
3000:8064  8B 1E 80 71       mov bx,[0x7180]
3000:8068  83 7F 06 0B       cmp word [bx+0x6],byte +0xb
3000:806C  75 1E             jnz 0x808c
3000:806E  B8 F5 2A          mov ax,0x2af5
3000:8071  50                push ax
3000:8072  57                push di
3000:8073  E8 94 15          call 0x960a
3000:8076  83 C4 04          add sp,byte +0x4
3000:8079  56                push si
3000:807A  E8 69 30          call 0xb0e6
3000:807D  83 C4 02          add sp,byte +0x2
3000:8080  0B C0             or ax,ax
3000:8082  75 28             jnz 0x80ac
3000:8084  2B C0             sub ax,ax
3000:8086  5E                pop si
3000:8087  5F                pop di
3000:8088  8B E5             mov sp,bp
3000:808A  5D                pop bp
3000:808B  C3                ret
3000:808C  8B 1E 80 71       mov bx,[0x7180]
3000:8090  83 7F 06 0D       cmp word [bx+0x6],byte +0xd
3000:8094  75 16             jnz 0x80ac
3000:8096  B8 F9 2A          mov ax,0x2af9
3000:8099  50                push ax
3000:809A  57                push di
3000:809B  E8 6C 15          call 0x960a
3000:809E  83 C4 04          add sp,byte +0x4
3000:80A1  56                push si
3000:80A2  E8 41 30          call 0xb0e6
3000:80A5  83 C4 02          add sp,byte +0x2
3000:80A8  0B C0             or ax,ax
3000:80AA  74 D8             jz 0x8084
3000:80AC  C6 05 00          mov byte [di],0x0
3000:80AF  8A 45 FF          mov al,[di-0x1]
3000:80B2  2A E4             sub ah,ah
3000:80B4  2D 61 00          sub ax,0x61
3000:80B7  3D 18 00          cmp ax,0x18
3000:80BA  76 03             jna 0x80bf
3000:80BC  E9 A5 01          jmp 0x8264
3000:80BF  03 C0             add ax,ax
3000:80C1  93                xchg ax,bx
3000:80C2  2E FF A7 32 82    jmp [cs:bx-0x7dce]
3000:80C7  90                nop
3000:80C8  C6 45 FF 79       mov byte [di-0x1],0x79
3000:80CC  56                push si
3000:80CD  E8 16 30          call 0xb0e6
3000:80D0  83 C4 02          add sp,byte +0x2
3000:80D3  0B C0             or ax,ax
3000:80D5  74 09             jz 0x80e0
3000:80D7  B8 01 00          mov ax,0x1
3000:80DA  5E                pop si
3000:80DB  5F                pop di
3000:80DC  8B E5             mov sp,bp
3000:80DE  5D                pop bp
3000:80DF  C3                ret
3000:80E0  C6 45 FF 69       mov byte [di-0x1],0x69
3000:80E4  C6 05 65          mov byte [di],0x65
3000:80E7  47                inc di
3000:80E8  C6 05 00          mov byte [di],0x0
3000:80EB  56                push si
3000:80EC  E8 F7 2F          call 0xb0e6
3000:80EF  83 C4 02          add sp,byte +0x2
3000:80F2  5E                pop si
3000:80F3  5F                pop di
3000:80F4  8B E5             mov sp,bp
3000:80F6  5D                pop bp
3000:80F7  C3                ret
3000:80F8  80 7D FE 65       cmp byte [di-0x2],0x65
3000:80FC  74 ED             jz 0x80eb
3000:80FE  8B 1E 80 71       mov bx,[0x7180]
3000:8102  F6 47 04 01       test byte [bx+0x4],0x1
3000:8106  75 DC             jnz 0x80e4
3000:8108  56                push si
3000:8109  E8 DA 2F          call 0xb0e6
3000:810C  83 C4 02          add sp,byte +0x2
3000:810F  0B C0             or ax,ax
3000:8111  75 C4             jnz 0x80d7
3000:8113  EB CF             jmp short 0x80e4
3000:8115  90                nop
3000:8116  C6 05 65          mov byte [di],0x65
3000:8119  47                inc di
3000:811A  C6 05 00          mov byte [di],0x0
3000:811D  56                push si
3000:811E  E8 C5 2F          call 0xb0e6
3000:8121  83 C4 02          add sp,byte +0x2
3000:8124  0B C0             or ax,ax
3000:8126  75 AF             jnz 0x80d7
3000:8128  C6 45 FF 00       mov byte [di-0x1],0x0
3000:812C  EB BD             jmp short 0x80eb
3000:812E  8B 1E 80 71       mov bx,[0x7180]
3000:8132  83 7F 06 17       cmp word [bx+0x6],byte +0x17
3000:8136  75 35             jnz 0x816d
3000:8138  B8 FC 2A          mov ax,0x2afc
3000:813B  50                push ax
3000:813C  8D 46 E8          lea ax,[bp-0x18]
3000:813F  50                push ax
3000:8140  E8 C7 14          call 0x960a
3000:8143  83 C4 04          add sp,byte +0x4
3000:8146  C6 46 D0 79       mov byte [bp-0x30],0x79
3000:814A  C6 46 D1 00       mov byte [bp-0x2f],0x0
3000:814E  4F                dec di
3000:814F  C6 05 00          mov byte [di],0x0
3000:8152  8D 46 D0          lea ax,[bp-0x30]
3000:8155  50                push ax
3000:8156  8D 46 E8          lea ax,[bp-0x18]
3000:8159  50                push ax
3000:815A  57                push di
3000:815B  56                push si
3000:815C  E8 49 03          call 0x84a8
3000:815F  83 C4 08          add sp,byte +0x8
3000:8162  0B C0             or ax,ax
3000:8164  74 03             jz 0x8169
3000:8166  E9 6E FF          jmp 0x80d7
3000:8169  C6 05 79          mov byte [di],0x79
3000:816C  47                inc di
3000:816D  C6 46 D0 65       mov byte [bp-0x30],0x65
3000:8171  2A C0             sub al,al
3000:8173  88 46 D1          mov [bp-0x2f],al
3000:8176  88 46 E8          mov [bp-0x18],al
3000:8179  8D 46 D0          lea ax,[bp-0x30]
3000:817C  50                push ax
3000:817D  8D 46 E8          lea ax,[bp-0x18]
3000:8180  50                push ax
3000:8181  57                push di
3000:8182  56                push si
3000:8183  E8 22 03          call 0x84a8
3000:8186  83 C4 08          add sp,byte +0x8
3000:8189  5E                pop si
3000:818A  5F                pop di
3000:818B  8B E5             mov sp,bp
3000:818D  5D                pop bp
3000:818E  C3                ret
3000:818F  90                nop
3000:8190  8B 1E 80 71       mov bx,[0x7180]
3000:8194  F7 47 04 00 0C    test word [bx+0x4],0xc00
3000:8199  75 03             jnz 0x819e
3000:819B  E9 4D FF          jmp 0x80eb
3000:819E  EB CD             jmp short 0x816d
3000:81A0  80 7D FE 74       cmp byte [di-0x2],0x74
3000:81A4  74 03             jz 0x81a9
3000:81A6  E9 5F FF          jmp 0x8108
3000:81A9  8B 1E 80 71       mov bx,[0x7180]
3000:81AD  F7 47 04 00 0C    test word [bx+0x4],0xc00
3000:81B2  75 03             jnz 0x81b7
3000:81B4  E9 51 FF          jmp 0x8108
3000:81B7  C6 05 65          mov byte [di],0x65
3000:81BA  47                inc di
3000:81BB  C6 05 00          mov byte [di],0x0
3000:81BE  56                push si
3000:81BF  E8 24 2F          call 0xb0e6
3000:81C2  83 C4 02          add sp,byte +0x2
3000:81C5  0B C0             or ax,ax
3000:81C7  74 03             jz 0x81cc
3000:81C9  E9 0B FF          jmp 0x80d7
3000:81CC  4F                dec di
3000:81CD  C6 05 00          mov byte [di],0x0
3000:81D0  E9 35 FF          jmp 0x8108
3000:81D3  90                nop
3000:81D4  80 7D FE 63       cmp byte [di-0x2],0x63
3000:81D8  74 03             jz 0x81dd
3000:81DA  E9 87 00          jmp 0x8264
3000:81DD  E9 3D FF          jmp 0x811d
3000:81E0  B8 01 00          mov ax,0x1
3000:81E3  8A 4D FE          mov cl,[di-0x2]
3000:81E6  80 E9 61          sub cl,0x61
3000:81E9  D3 E0             shl ax,cl
3000:81EB  99                cwd
3000:81EC  25 11 41          and ax,0x4111
3000:81EF  81 E2 10 01       and dx,0x110
3000:81F3  0B D0             or dx,ax
3000:81F5  74 6D             jz 0x8264
3000:81F7  56                push si
3000:81F8  E8 65 D0          call 0x5260
3000:81FB  83 C4 02          add sp,byte +0x2
3000:81FE  3D 04 00          cmp ax,0x4
3000:8201  7D 61             jnl 0x8264
3000:8203  8A 45 FF          mov al,[di-0x1]
3000:8206  88 05             mov [di],al
3000:8208  B8 FF 2A          mov ax,0x2aff
3000:820B  50                push ax
3000:820C  8D 45 01          lea ax,[di+0x1]
3000:820F  50                push ax
3000:8210  E8 F7 13          call 0x960a
3000:8213  83 C4 04          add sp,byte +0x4
3000:8216  56                push si
3000:8217  E8 CC 2E          call 0xb0e6
3000:821A  83 C4 02          add sp,byte +0x2
3000:821D  0B C0             or ax,ax
3000:821F  74 0B             jz 0x822c
3000:8221  C6 05 65          mov byte [di],0x65
3000:8224  C6 45 01 00       mov byte [di+0x1],0x0
3000:8228  E9 C0 FE          jmp 0x80eb
3000:822B  90                nop
3000:822C  C6 05 00          mov byte [di],0x0
3000:822F  EB 33             jmp short 0x8264
3000:8231  90                nop
```

## Boundary

The `3000:7F66` table and extended helper bodies through `3000:8231` are now
mapped. The next adjacent bytes at `3000:8232..8263` are the `a..y` dispatch
table used by `3000:8056`; code resumes at `3000:8264` in
[`banked-inflection-helper-tail.md`](banked-inflection-helper-tail.md).
