# Banked Extended Suffix Handler

This slice maps the suffix-handler family after
[`banked-suffix-tertiary.md`](banked-suffix-tertiary.md). It covers
`3000:7724..78CD`, the record-type-sensitive helper reached by the candidate
record formatter when the local record class is `0x0B` or `0x0D`.

No image assets are reached in this slice.

## Handler Shape

`3000:7724` receives the same three arguments as the other suffix helpers:
dictionary-check string, output cursor, and runtime suffix/string pointer. It
first reads active record pointer `[7134]` and checks `[record+6]`. Record type
`0x0B` seeds two stack buffers with data strings `25BC` (`est`) and `25C0`
(`more `); the other path uses `25C6` (`er`) and `25C9` (`most `). The rest of
the routine mutates the current output word, appends those local/runtime
suffixes, and validates each candidate through `3000:B0E6`.

The final-letter cases are:

| Final letter | Behavior |
| --- | --- |
| `y` | Rewrite final `y` to `i`, append/check the local suffix, then append/check the caller suffix; restore `y` if both fail. |
| `e` | Drop final `e`, try the local suffix and caller suffix, then restore `e` and fall back. |
| `l` | Try the local suffix directly; if accepted, build a compound form through `3000:7686` using caller suffix variants. |
| other | Duplicate the final byte before the local suffix, then append/check the caller suffix. |

Failures fall into `3000:78AA`, which clears the output cursor, appends the
second local string after the original check string length, copies the first
local string back onto the check string, and returns success.

```asm
suffix_extended_C3000_7724:
; file 0x37724
3000:7724  55                push bp
3000:7725  8B EC             mov bp,sp
3000:7727  83 EC 60          sub sp,byte +0x60
3000:772A  57                push di
3000:772B  56                push si
3000:772C  8B 76 04          mov si,[bp+0x4]
3000:772F  8B 7E 06          mov di,[bp+0x6]
3000:7732  8B 1E 34 71       mov bx,[0x7134]
3000:7736  83 7F 06 0B       cmp word [bx+0x6],byte +0xb
3000:773A  75 14             jnz 0x7750
3000:773C  B8 BC 25          mov ax,0x25bc
3000:773F  50                push ax
3000:7740  8D 46 E8          lea ax,[bp-0x18]
3000:7743  50                push ax
3000:7744  E8 C3 1E          call 0x960a
3000:7747  83 C4 04          add sp,byte +0x4
3000:774A  B8 C0 25          mov ax,0x25c0
3000:774D  EB 12             jmp short 0x7761
3000:774F  90                nop
3000:7750  B8 C6 25          mov ax,0x25c6
3000:7753  50                push ax
3000:7754  8D 46 E8          lea ax,[bp-0x18]
3000:7757  50                push ax
3000:7758  E8 AF 1E          call 0x960a
3000:775B  83 C4 04          add sp,byte +0x4
3000:775E  B8 C9 25          mov ax,0x25c9
3000:7761  50                push ax
3000:7762  8D 46 A0          lea ax,[bp-0x60]
3000:7765  50                push ax
3000:7766  E8 A1 1E          call 0x960a
3000:7769  83 C4 04          add sp,byte +0x4
3000:776C  8A 45 FF          mov al,[di-0x1]
3000:776F  2A E4             sub ah,ah
3000:7771  3D 65 00          cmp ax,0x65
3000:7774  75 03             jnz 0x7779
3000:7776  E9 B1 00          jmp 0x782a
3000:7779  3D 6C 00          cmp ax,0x6c
3000:777C  75 03             jnz 0x7781
3000:777E  E9 DB 00          jmp 0x785c
3000:7781  3D 79 00          cmp ax,0x79
3000:7784  74 34             jz 0x77ba
3000:7786  88 05             mov [di],al
3000:7788  47                inc di
3000:7789  8D 46 E8          lea ax,[bp-0x18]
3000:778C  50                push ax
3000:778D  57                push di
3000:778E  E8 79 1E          call 0x960a
3000:7791  83 C4 04          add sp,byte +0x4
3000:7794  56                push si
3000:7795  E8 4E 39          call 0xb0e6
3000:7798  83 C4 02          add sp,byte +0x2
3000:779B  0B C0             or ax,ax
3000:779D  74 15             jz 0x77b4
3000:779F  FF 76 08          push word [bp+0x8]
3000:77A2  57                push di
3000:77A3  E8 64 1E          call 0x960a
3000:77A6  83 C4 04          add sp,byte +0x4
3000:77A9  56                push si
3000:77AA  E8 39 39          call 0xb0e6
3000:77AD  83 C4 02          add sp,byte +0x2
3000:77B0  0B C0             or ax,ax
3000:77B2  75 35             jnz 0x77e9
3000:77B4  4F                dec di
3000:77B5  C6 05 00          mov byte [di],0x0
3000:77B8  EB 3C             jmp short 0x77f6
3000:77BA  C6 45 FF 69       mov byte [di-0x1],0x69
3000:77BE  8D 46 E8          lea ax,[bp-0x18]
3000:77C1  50                push ax
3000:77C2  57                push di
3000:77C3  E8 44 1E          call 0x960a
3000:77C6  83 C4 04          add sp,byte +0x4
3000:77C9  56                push si
3000:77CA  E8 19 39          call 0xb0e6
3000:77CD  83 C4 02          add sp,byte +0x2
3000:77D0  0B C0             or ax,ax
3000:77D2  74 1E             jz 0x77f2
3000:77D4  FF 76 08          push word [bp+0x8]
3000:77D7  57                push di
3000:77D8  E8 2F 1E          call 0x960a
3000:77DB  83 C4 04          add sp,byte +0x4
3000:77DE  56                push si
3000:77DF  E8 04 39          call 0xb0e6
3000:77E2  83 C4 02          add sp,byte +0x2
3000:77E5  0B C0             or ax,ax
3000:77E7  74 09             jz 0x77f2
3000:77E9  B8 01 00          mov ax,0x1
3000:77EC  5E                pop si
3000:77ED  5F                pop di
3000:77EE  8B E5             mov sp,bp
3000:77F0  5D                pop bp
3000:77F1  C3                ret
3000:77F2  C6 45 FF 79       mov byte [di-0x1],0x79
3000:77F6  8D 46 E8          lea ax,[bp-0x18]
3000:77F9  50                push ax
3000:77FA  57                push di
3000:77FB  E8 0C 1E          call 0x960a
3000:77FE  83 C4 04          add sp,byte +0x4
3000:7801  56                push si
3000:7802  E8 E1 38          call 0xb0e6
3000:7805  83 C4 02          add sp,byte +0x2
3000:7808  0B C0             or ax,ax
3000:780A  75 03             jnz 0x780f
3000:780C  E9 9B 00          jmp 0x78aa
3000:780F  FF 76 08          push word [bp+0x8]
3000:7812  57                push di
3000:7813  E8 F4 1D          call 0x960a
3000:7816  83 C4 04          add sp,byte +0x4
3000:7819  56                push si
3000:781A  E8 C9 38          call 0xb0e6
3000:781D  83 C4 02          add sp,byte +0x2
3000:7820  0B C0             or ax,ax
3000:7822  75 03             jnz 0x7827
3000:7824  E9 83 00          jmp 0x78aa
3000:7827  EB C0             jmp short 0x77e9
3000:7829  90                nop
3000:782A  4F                dec di
3000:782B  8D 46 E8          lea ax,[bp-0x18]
3000:782E  50                push ax
3000:782F  57                push di
3000:7830  E8 D7 1D          call 0x960a
3000:7833  83 C4 04          add sp,byte +0x4
3000:7836  56                push si
3000:7837  E8 AC 38          call 0xb0e6
3000:783A  83 C4 02          add sp,byte +0x2
3000:783D  0B C0             or ax,ax
3000:783F  74 15             jz 0x7856
3000:7841  FF 76 08          push word [bp+0x8]
3000:7844  57                push di
3000:7845  E8 C2 1D          call 0x960a
3000:7848  83 C4 04          add sp,byte +0x4
3000:784B  56                push si
3000:784C  E8 97 38          call 0xb0e6
3000:784F  83 C4 02          add sp,byte +0x2
3000:7852  0B C0             or ax,ax
3000:7854  75 93             jnz 0x77e9
3000:7856  C6 05 65          mov byte [di],0x65
3000:7859  47                inc di
3000:785A  EB 9A             jmp short 0x77f6
3000:785C  8D 46 E8          lea ax,[bp-0x18]
3000:785F  50                push ax
3000:7860  57                push di
3000:7861  E8 A6 1D          call 0x960a
3000:7864  83 C4 04          add sp,byte +0x4
3000:7867  56                push si
3000:7868  E8 7B 38          call 0xb0e6
3000:786B  83 C4 02          add sp,byte +0x2
3000:786E  0B C0             or ax,ax
3000:7870  74 84             jz 0x77f6
3000:7872  FF 76 08          push word [bp+0x8]
3000:7875  8D 46 D0          lea ax,[bp-0x30]
3000:7878  50                push ax
3000:7879  E8 8E 1D          call 0x960a
3000:787C  83 C4 04          add sp,byte +0x4
3000:787F  C6 46 B8 6C       mov byte [bp-0x48],0x6c
3000:7883  FF 76 08          push word [bp+0x8]
3000:7886  8D 46 B9          lea ax,[bp-0x47]
3000:7889  50                push ax
3000:788A  E8 7D 1D          call 0x960a
3000:788D  83 C4 04          add sp,byte +0x4
3000:7890  8D 46 B8          lea ax,[bp-0x48]
3000:7893  50                push ax
3000:7894  8D 46 D0          lea ax,[bp-0x30]
3000:7897  50                push ax
3000:7898  57                push di
3000:7899  56                push si
3000:789A  E8 E9 FD          call 0x7686
3000:789D  83 C4 08          add sp,byte +0x8
3000:78A0  0B C0             or ax,ax
3000:78A2  74 03             jz 0x78a7
3000:78A4  E9 42 FF          jmp 0x77e9
3000:78A7  E9 4C FF          jmp 0x77f6
3000:78AA  C6 05 00          mov byte [di],0x0
3000:78AD  56                push si
3000:78AE  8D 46 A0          lea ax,[bp-0x60]
3000:78B1  50                push ax
3000:78B2  E8 71 1D          call 0x9626
3000:78B5  83 C4 02          add sp,byte +0x2
3000:78B8  50                push ax
3000:78B9  E8 4E 1D          call 0x960a
3000:78BC  83 C4 04          add sp,byte +0x4
3000:78BF  8D 46 A0          lea ax,[bp-0x60]
3000:78C2  50                push ax
3000:78C3  56                push si
3000:78C4  E8 43 1D          call 0x960a
3000:78C7  83 C4 04          add sp,byte +0x4
3000:78CA  E9 1C FF          jmp 0x77e9
3000:78CD  90                nop
```

## Bottom

The extended `est`/`more ` and `er`/`most ` suffix path is now mapped through
its final fallback rewrite. The next adjacent routine begins at `3000:78CE` and
is documented in
[`banked-compound-normalizer.md`](banked-compound-normalizer.md).
