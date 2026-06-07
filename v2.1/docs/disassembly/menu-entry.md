# Menu Entry Disassembly

This slice continues from the boot handoff in [`boot.md`](boot.md). It follows
the cold and warm `C688` application entries until the first two-button menu
has been drawn and control reaches the shared application menu/event loop.

The assembly below is an annotated listing, not NASM input. Inline display
scripts and key-dispatch tables are marked as data instead of force-disassembled
as code.

String and display resources in this slice use the descriptor notation from
[`display-resource-format.md`](display-resource-format.md).

## Entry Wrappers

`C000` reaches the application segment through two far jumps:

```asm
; cold path from C000:011A
C688:000B  E8 CB 29          call C688:29D9
C688:000E  CB                retf

; warm path from C000:015C
C688:000F  E8 40 77          call C688:7752
C688:0012  CB                retf
```

`C688:0053` is the app-side retained-RAM signature check called before the cold
or warm path is selected:

```asm
; file 0x468D3
C688:0053  BE 9D 00          mov  si,0x009d      ; expected bytes in CS
C688:0056  BF 00 68          mov  di,0x6800      ; retained RAM signature
C688:0059  B9 04 00          mov  cx,0x0004
C688:005C  2E 8A 04          mov  al,[cs:si]
C688:005F  3A 05             cmp  al,[di]
C688:0061  75 10             jnz  C688:0073
C688:0063  46                inc  si
C688:0064  47                inc  di
C688:0065  E2 F5             loop C688:005C
C688:0067  BE 05 D0          mov  si,0xd005
C688:006A  2E 8A 04          mov  al,[cs:si]
C688:006D  3A 05             cmp  al,[di]
C688:006F  75 0B             jnz  C688:007C
C688:0071  F8                clc
C688:0072  CB                retf

; mismatch path rewrites the expected signature and returns carry set
C688:0073  2E 8A 04          mov  al,[cs:si]
C688:0076  88 05             mov  [di],al
C688:0078  46                inc  si
C688:0079  47                inc  di
C688:007A  E2 F7             loop C688:0073
C688:007C  BE 05 D0          mov  si,0xd005
C688:007F  2E 8A 04          mov  al,[cs:si]
C688:0082  88 05             mov  [di],al
C688:0084  F9                stc
C688:0085  CB                retf
```

The expected four-byte text at `C688:009D` is `32 31 42 41` (`21BA`), and
the fifth byte at `C688:D005` is `55`.

## Cold Application Startup

`C688:29D9` clears the UI work area and initializes display/document state. The
important boundary is `call C688:0240`: the bytes immediately after it are an
inline display script, not instructions.

```asm
; file 0x49259
C688:29D9  BF B8 77          mov  di,0x77b8
C688:29DC  B9 29 7F          mov  cx,0x7f29
C688:29DF  81 E9 B8 77       sub  cx,0x77b8
C688:29E3  32 C0             xor  al,al
C688:29E5  06                push es
C688:29E6  8C DD             mov  bp,ds
C688:29E8  8E C5             mov  es,bp
C688:29EA  FC                cld
C688:29EB  F3 AA             rep  stosb          ; clear 77B8..7F28
C688:29ED  07                pop  es
C688:29EE  2E 8B 36 63 2A    mov  si,[cs:0x2a63]
C688:29F3  89 36 71 76       mov  [0x7671],si
C688:29F7  C6 06 73 76 00    mov  byte [0x7673],0
C688:29FC  C6 06 3F 8E 00    mov  byte [0x8e3f],0
C688:2A01  E8 47 FF          call C688:294B      ; WP editor heap RAM probe
C688:2A04  E8 6E 03          call C688:2D75
C688:2A07  B0 02             mov  al,0x02
C688:2A09  C7 06 ED 75 3B 79 mov  word [0x75ed],0x793b
C688:2A0F  E8 C9 37          call C688:61DB
C688:2A12  E8 2B D8          call C688:0240      ; inline script interpreter
```

```text
C688:2A15..2A34  inline display/script bytes consumed by C688:0240
```

The currently decoded inline script here is a compact setup/control stream. It
does not contain printable text, so no final string block is emitted for this
inline resource yet.

Execution resumes after the script at `C688:2A35`:

```asm
C688:2A35  B0 FF             mov  al,0xff
C688:2A37  A2 1B 78          mov  [0x781b],al
C688:2A3A  A2 10 78          mov  [0x7810],al
C688:2A3D  A2 94 79          mov  [0x7994],al
C688:2A46  BE 30 30          mov  si,0x3030
C688:2A49  89 36 7E 78       mov  [0x787e],si
C688:2A4D  B0 08             mov  al,0x08
C688:2A4F  A2 8F 79          mov  [0x798f],al
C688:2A52  B0 03             mov  al,0x03
C688:2A54  BE 04 00          mov  si,0x0004
C688:2A57  E8 E7 6A          call C688:9541      ; resource loader
C688:2A5A  E8 9E 73          call C688:9DFB
C688:2A5D  E8 BA 19          call C688:441A
C688:2A60  E9 C6 4C          jmp  C688:7729
```

## First Menu Boundary

`C688:7729` is the cold path's first tight UI boundary. The warm entry wrapper
bypasses this setup and calls `C688:7752` directly.

```asm
; file 0x4DFA9
C688:7729  E8 3A 00          call C688:7766      ; boot/update sequence
C688:772C  BE 01 00          mov  si,0x0001
C688:772F  E8 8D FF          call C688:76BF
C688:7732  BF 46 77          mov  di,0x7746
C688:7735  06                push es
C688:7736  BD 00 00          mov  bp,0
C688:7739  8E C5             mov  es,bp
C688:773B  FC                cld
C688:773C  F3 A4             rep  movsb
C688:773E  07                pop  es
C688:773F  32 C0             xor  al,al
C688:7741  A2 4D 7A          mov  [0x7a4d],al
C688:7744  C6 06 7C 78 0C    mov  byte [0x787c],0x0c
C688:7749  C7 06 7E 78 30 30 mov  word [0x787e],0x3030
C688:774F  E8 58 00          call C688:77AA

; warm entry lands here through C688:000F
C688:7752  E8 5F 00          call C688:77B4
C688:7755  3C 02             cmp  al,0x02
C688:7757  74 03             jz   C688:775C
C688:7759  E9 B9 73          jmp  C688:EB15      ; shared default/menu loop path
C688:775C  06                push es
C688:775D  9A C3 53 98 DC    call DC98:53C3      ; organizer top menu
C688:7762  07                pop  es
C688:7763  E9 AF 73          jmp  C688:EB15
```

The boot/update helper writes a fixed sequence of small update IDs:

```asm
C688:7766  B0 0A             mov  al,0x0a
C688:7768  E8 D8 17          call C688:8F43
C688:776B  BE 03 00          mov  si,0x0003
C688:776E  E8 D0 1D          call C688:9541
C688:7771  E8 28 E2          call C688:599C
C688:7774  E8 4D CD          call C688:44C4
C688:7777  B0 04             mov  al,0x04
C688:7779  E8 27 00          call C688:77A3
C688:777C  B0 09             mov  al,0x09
C688:777E  E8 22 00          call C688:77A3
C688:7781  B0 02             mov  al,0x02
C688:7783  E8 1D 00          call C688:77A3
C688:7786  B0 03             mov  al,0x03
C688:7788  E8 18 00          call C688:77A3
C688:778B  B0 03             mov  al,0x03
C688:778D  E8 13 00          call C688:77A3
C688:7790  B0 03             mov  al,0x03
C688:7792  E8 0E 00          call C688:77A3
C688:7795  B0 05             mov  al,0x05
C688:7797  E8 09 00          call C688:77A3
C688:779A  B0 00             mov  al,0x00
C688:779C  E8 04 00          call C688:77A3
C688:779F  E8 3F 1F          call C688:96E1
C688:77A2  C3                ret
```

## Startup Banner Resource

The cold-start banner at `C688:D008` / file `0x53888` is a `C000:5AD6`
display script. It uses `FF 00` to clear the framebuffer, `FF 04 00 06` as a
currently unnamed low-number layout/control descriptor, then `FF 02` positioned
text runs.

| Offset | Descriptor | Decoded text |
| ---: | --- | --- |
| `0x53888` | `FF 00`; `FF 04 00 06`; `FF 02 00 00 00 00` | `INITIALIZING` |
| `0x538A1` | `FF 00`; `FF 04 00 06`; `FF 02 02 00 0C 00` | `WORD PROCESSOR ... LINGUISTIC TECHNOLOGY` |
| `0x538DF` | `FF 02 06 00 0C 00` | `(C) 1992 NER Inc. Ver. 3.00 ... (C) 1983 Proximity Technology Inc.` |
| `0x5392F` | `FF 02 08 00 0C 00` | `(C) 1992 mikrolab Ver. 5.00 ... (C) 1983 Merriam-Webster Inc.` |
| `0x53976` | `FF 02 0C 00 0C 00` | `All Rights Reserved ... All Rights Reserved` |

Final formatted text, preserving the stored spacing:

```text
INITIALIZING

WORD PROCESSOR                         LINGUISTIC TECHNOLOGY
(C) 1992 NER Inc. Ver. 3.00         (C) 1983 Proximity Technology Inc.
(C) 1992 mikrolab Ver. 5.00         (C) 1983 Merriam-Webster Inc.
All Rights Reserved                   All Rights Reserved
```

## First Menu Resource And Images

`C688:77B4` copies the first two-button menu script from `C688:D133` to the
work buffer at `0x7F28`, then enters the first-menu input dispatcher:

```asm
; file 0x4E034
C688:77B4  BE 33 D1          mov  si,0xd133      ; first-menu script source
C688:77B7  B9 7C 00          mov  cx,0x007c
C688:77BA  E8 04 00          call C688:77C1
C688:77BD  E8 52 0B          call C688:8312
C688:77C0  C3                ret

C688:77C1  1E                push ds
C688:77C2  B8 88 C6          mov  ax,0xc688
C688:77C5  8E D8             mov  ds,ax
C688:77C7  BF 28 7F          mov  di,0x7f28
C688:77CA  06                push es
C688:77CB  BD 00 00          mov  bp,0
C688:77CE  8E C5             mov  es,bp
C688:77D0  FC                cld
C688:77D1  F3 A4             rep  movsb
C688:77D3  07                pop  es
C688:77D4  1F                pop  ds
C688:77D5  89 3E E2 79       mov  [0x79e2],di
C688:77D9  E8 B0 F3          call C688:6B8C      ; hand copied script to renderer
C688:77DC  C3                ret
```

The first-menu resource begins with an `FF 06` low-number descriptor, then two
button rows. Each row has an `FF 40` bitmap position, an `FF 42` bitmap blit,
and an `FF 02` positioned text run:

| Offset | Descriptor | Decoded final string |
| ---: | --- | --- |
| `0x539B3` | `FF 06 00 00 00 00 10 00 E0 01 00 00 00 00 00` | Layout/control descriptor, no printable text. |
| `0x539C3` | `FF 40 06 00 82 00`; `FF 42 22 00 24 00 AF D1 88 C6` | Button outline at pixel `6,130`. |
| `0x539D3` | `FF 40 0B 00 87 00`; `FF 42 07 00 18 00 59 D2 88 C6` | Bitmap label at pixel `11,135`. |
| `0x539E3` | `FF 02 0C 00 6A 00`; ASCII run | `ORGANIZER MENU` |
| `0x539F7` | `FF 40 06 00 3A 01`; `FF 42 22 00 24 00 AF D1 88 C6` | Button outline at pixel `6,314`. |
| `0x53A07` | `FF 40 0B 00 3F 01`; `FF 42 07 00 18 00 6E D2 88 C6` | Bitmap label at pixel `11,319`. |
| `0x53A17` | `FF 02 0C 00 13 01`; ASCII run | `WORD PROCESSOR MENU` |

Final formatted text:

```text
ORGANIZER MENU

WORD PROCESSOR MENU
```

The resource embeds three source-backed bitmap records. The PNGs below were
generated with `tools/render_rom_bitmap_png.py` and are checked in next to this
disassembly.

| Resource record and disassembly context | Rendered PNG |
| --- | --- |
| `file 0x539C8`: `FF 40 06 00 82 00` position `6,130`; `FF 42 22 00 24 00 AF D1 88 C6` blits `C688:D1AF` / file `0x53A2F`, `36x34` button outline. The same bitmap is used again by record `0x539FC` at position `6,314`. | ![startup button outline](images/startup-button-0x53a2f.png) |
| `file 0x539D8`: `FF 40 0B 00 87 00`; `FF 42 07 00 18 00 59 D2 88 C6` blits `C688:D259` / file `0x53AD9`, `24x7` label. | ![ORGN label](images/startup-label-0x53ad9.png) |
| `file 0x53A0C`: `FF 40 0B 00 3F 01`; `FF 42 07 00 18 00 6E D2 88 C6` blits `C688:D26E` / file `0x53AEE`, `24x7` label. | ![WP label](images/startup-label-0x53aee.png) |

## First Input Dispatcher

`C688:8312` is entered after the menu script is copied and rendered. The first
three instructions are a small wrapper; `C688:8319` is the re-entry target used
by the later shared menu loop.

```asm
; file 0x4EB92
C688:8312  E8 11 AA          call C688:2D26
C688:8315  E8 30 C5          call C688:4848
C688:8318  C3                ret

C688:8319  E8 0A 06          call C688:8926
C688:831C  E8 21 6E          call C688:F140
C688:831F  80 26 B4 8D F7    and  byte [0x8db4],0xf7
C688:8324  BE 5A 00          mov  si,0x005a
C688:8327  B5 03             mov  ch,0x03
C688:8329  E8 72 6B          call C688:EE9E
C688:832C  E8 85 02          call C688:85B4
C688:832F  E8 E5 02          call C688:8617
C688:8332  E8 B7 0D          call C688:90EC
C688:8335  EB 18             jmp  C688:834F

; C688:8337..834E is table/data, not linear code.
; [75EF] is initialized to the first word-table entry below.

C688:834F  C7 06 EF 75 3B 83 mov  word [0x75ef],0x833b
C688:8355  BE 5B 00          mov  si,0x005b
```

The loop around `C688:837E` consumes the current key/event byte from `[794A]`
and routes the first screen:

```asm
C688:837E  5E                pop  si
C688:837F  8F 06 EF 75       pop  word [0x75ef]
C688:8383  A0 4A 79          mov  al,[0x794a]
C688:8386  3C 03             cmp  al,0x03
C688:8388  74 4E             jz   C688:83D8
C688:838A  3C DA             cmp  al,0xda
C688:838C  74 4F             jz   C688:83DD
C688:838E  3C 13             cmp  al,0x13
C688:8390  74 07             jz   C688:8399
C688:8392  3C 12             cmp  al,0x12
C688:8394  74 03             jz   C688:8399
C688:8396  E9 07 0F          jmp  C688:92A0
C688:8399  E9 F1 0E          jmp  C688:928D
```

`0xDA` is the observed `ORGN` route. Ordinary non-`ORGN` input falls through
the first-menu/default path and reaches the word-processor side.

Both first-screen branches converge on the shared menu/event loop:

```asm
C688:83D8  E8 AF 05          call C688:898A
C688:83DB  EB 3C             jmp  C688:8419

C688:83DD  A0 4A 79          mov  al,[0x794a]
C688:83E0  3C DA             cmp  al,0xda
C688:83E2  74 08             jz   C688:83EC
C688:83E4  C7 06 EF 75 47 83 mov  word [0x75ef],0x8347
C688:83EA  EB BF             jmp  C688:83AB

C688:83EC  BE 53 00          mov  si,0x0053
C688:83EF  E8 97 F2          call C688:7689
C688:83F2  E8 1B 02          call C688:8610
C688:83F5  E8 FE 05          call C688:89F6
C688:83F8  74 08             jz   C688:8402
C688:83FA  E8 80 D7          call C688:5B7D
C688:83FD  E8 C9 02          call C688:86C9
C688:8400  EB 11             jmp  C688:8413
C688:8402  BE D1 78          mov  si,0x78d1
C688:8405  8B 1C             mov  bx,[si]
C688:8407  89 1E F5 78       mov  [0x78f5],bx
C688:840B  46                inc  si
C688:840C  46                inc  si
C688:840D  8B 1C             mov  bx,[si]
C688:840F  89 1E D9 78       mov  [0x78d9],bx
C688:8413  E8 AE C0          call C688:44C4
C688:8416  E8 E3 04          call C688:88FC
C688:8419  E9 83 68          jmp  C688:EC9F
```

## Shared Menu Event Loop Boundary

`C688:EC9F` is the stable application menu/event loop reached after first-menu
branch setup. It is expanded in
[`app-menu-event-loop.md`](app-menu-event-loop.md).

```asm
; file 0x5551F
C688:EC9F  E8 3B 8B          call C688:77DD
C688:ECA2  B0 FF             mov  al,0xff
C688:ECA4  A2 E4 75          mov  [0x75e4],al
C688:ECA7  E8 EB 8A          call C688:7795
C688:ECAA  E8 8D 04          call C688:F13A
C688:ECAD  E8 90 A2          call C688:8F40
C688:ECB0  E8 23 26          call C688:12D6
C688:ECB3  A2 4A 79          mov  [0x794a],al
C688:ECB6  E8 0B 58          call C688:44C4
C688:ECB9  A0 4A 79          mov  al,[0x794a]
C688:ECBC  3C FF             cmp  al,0xff
C688:ECBE  75 03             jnz  C688:ECC3
C688:ECC0  E9 C1 00          jmp  C688:ED84
C688:ECC3  E8 19 A6          call C688:92DF      ; inline key dispatch
```

The bytes after `C688:ECC3` are an inline key dispatch table consumed by
`C688:92DF`. The table starts at file `0x55546` / `C688:ECC6`:

```text
01 -> C688:ECA7
02 -> C688:EF4F
E8 -> C688:EF59
0B -> C688:ECF6
0A -> C688:8319
1D -> C688:8CFB
1B -> C688:8D23
1C -> C688:8D0F
F6 -> C688:ED1F
EA -> C688:ED15
D2 -> C688:AD5C
F7 -> C688:D8AF
F5 -> C688:ED1A
F8 -> C688:E274
03 -> C688:ECF6
FF -> C688:EB15
```

The default handler at `C688:EB15` far-calls the word-processor top menu
wrapper `DC98:2807`; the organizer route uses `C688:EF4F` to far-call
`DC98:53C3`.
