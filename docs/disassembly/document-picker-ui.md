# Shared Document/List UI Roots

This slice expands the four shared application-loop targets selected by
[`app-menu-event-loop.md`](app-menu-event-loop.md):

```text
0x0A -> C688:8319
0x1D -> C688:8CFB
0x1B -> C688:8D23
0x1C -> C688:8D0F
```

These are internal event returns, not top-level menu items. They are reached
when the shared app loop stores a poll/menu result in `[794A]` and dispatches
through `C688:92DF`. To invoke one in a debugger, stop after
`C688:12D6`, set `AL` to one of the event bytes above, and continue through
`C688:ECB3`.

No bitmap assets are reached here. The reached resources are display/text
resources from the `D59C` table and one inline `LIST OF DOC.` template.

## Root Summary

| Event | Root | File offset | Role |
| ---: | --- | ---: | --- |
| `0x0A` | `C688:8319` | `0x4EB99` | First-menu/app re-entry path already reached by startup. |
| `0x1D` | `C688:8CFB` | `0x4F57B` | Document/list continuation after the `LIST OF DOC.` template. |
| `0x1B` | `C688:8D23` | `0x4F5A3` | `SEARCH` prompt variant. |
| `0x1C` | `C688:8D0F` | `0x4F58F` | `REPLACE SEARCH` prompt variant. |

The `0x1B` and `0x1C` roots are prompt variants in a shared find/replace-style
UI layer. They draw resource `0x38` first, then either `0x37` (`SEARCH`) or
`0x19` (`REPLACE SEARCH`), edit a 16-byte buffer, and return through the same
application event loop. They do not execute an application body by themselves.

## First-Menu Re-Entry

`C688:8319` is the same re-entry target already shown in
[`menu-entry.md`](menu-entry.md). The app loop can return to it with event
`0x0A`.

```asm
first_menu_reentry_C688_8319:
; file 0x4EB99
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
```

The bytes at `C688:8337..834E` are local table data used by the first-screen
input dispatcher. The path eventually returns to `C688:EC9F`.

## LIST OF DOC. Template

Before `C688:8CFB` runs, `C688:9541` copies a fixed template from
`C688:8C9C` / file `0x4F51C` to low RAM at `0x78E3`.

Resource descriptor:

```text
file 0x4F51C:
u16 payload_length = 0x005D
payload includes fixed fields and ASCII run:
20 20 4C 49 53 54 20 4F 46 20 44 4F 43 2E 20 20
```

Final formatted text:

```text
LIST OF DOC.
```

Linear disassembly through this area is false code until the real continuation
at `C688:8CFB`.

## Document/List Continuation

`C688:8CFB` uses `[7520]` as a small state bitfield. If no state is set, it
returns to the app loop. If bit `0x02` is set it skips into the selected-name
path at `C688:8DBF`; otherwise it enters the refresh path at `C688:8D7A`.

```asm
document_list_continuation_C688_8CFB:
; file 0x4F57B
C688:8CFB  A0 20 75          mov  al,[0x7520]
C688:8CFE  0A C0             or   al,al
C688:8D00  74 0A             jz   C688:8D0C
C688:8D02  A8 02             test al,0x02
C688:8D04  75 03             jnz  C688:8D09
C688:8D06  EB 72             jmp  C688:8D7A
C688:8D09  E9 B3 00          jmp  C688:8DBF
C688:8D0C  E9 90 5F          jmp  C688:EC9F
```

`C688:8D7A` snapshots the current display/menu byte and asks the local UI
updater to refresh the list, then returns to the shared loop.

```asm
document_list_refresh_C688_8D72:
C688:8D72  A0 20 75          mov  al,[0x7520]
C688:8D75  0C 01             or   al,0x01
C688:8D77  A2 20 75          mov  [0x7520],al

document_list_refresh_C688_8D7A:
C688:8D7A  E8 C3 01          call C688:8F40
C688:8D7D  E8 88 C3          call C688:5108
C688:8D80  E8 41 B7          call C688:44C4
C688:8D83  E9 19 5F          jmp  C688:EC9F
```

## Prompt Entry Variants

`C688:8D0F` and `C688:8D23` both set `[757D]` to their own root, draw a shared
layout resource `0x38`, draw a prompt-specific resource, then enter the same
one-field input path.

```asm
replace_search_prompt_root_C688_8D0F:
; file 0x4F58F
C688:8D0F  C7 06 7D 75 0F 8D mov  word [0x757d],0x8d0f
C688:8D15  BE 38 00          mov  si,0x0038
C688:8D18  E8 6E E9          call C688:7689
C688:8D1B  BE 19 00          mov  si,0x0019
C688:8D1E  E8 68 E9          call C688:7689
C688:8D21  EB 12             jmp  C688:8D35

search_prompt_root_C688_8D23:
; file 0x4F5A3
C688:8D23  C7 06 7D 75 23 8D mov  word [0x757d],0x8d23
C688:8D29  BE 38 00          mov  si,0x0038
C688:8D2C  E8 5A E9          call C688:7689
C688:8D2F  BE 37 00          mov  si,0x0037
C688:8D32  E8 54 E9          call C688:7689
```

The common tail clears `[7520]`, runs a one-field editor over `7A30`, trims the
16-byte result, and records whether the first significant character looks like
a blank or uppercase letter.

```asm
prompt_common_input_C688_8D35:
C688:8D35  32 C0             xor  al,al
C688:8D37  A2 20 75          mov  [0x7520],al
C688:8D3A  B5 06             mov  ch,0x06
C688:8D3C  B1 01             mov  cl,0x01
C688:8D3E  BA 30 7A          mov  dx,0x7a30
C688:8D41  E8 82 E4          call C688:71C6      ; edit field at 7A30
C688:8D44  BE 30 7A          mov  si,0x7a30
C688:8D47  B1 10             mov  cl,0x10
C688:8D49  E8 82 06          call C688:93CE      ; trim trailing spaces to NUL
C688:8D4C  80 26 EC 79 EF    and  byte [0x79ec],0xef
C688:8D51  B5 10             mov  ch,0x10
C688:8D53  BE 30 7A          mov  si,0x7a30
C688:8D56  E8 2D 62          call C688:EF86      ; classify field
C688:8D59  73 05             jnc  C688:8D60
C688:8D5B  80 0E EC 79 10    or   byte [0x79ec],0x10
C688:8D60  E8 7C 05          call C688:92DF
```

Inline dispatch table at `C688:8D63`:

```text
DA -> C688:8D86
03 -> C688:EC9F
FF -> C688:8D6C
```

The default entry reloads `[757D]` and jumps back to the active prompt root.

```asm
prompt_default_restart_C688_8D6C:
C688:8D6C  8B 36 7D 75       mov  si,[0x757d]
C688:8D70  FF E6             jmp  si
```

## Secondary REPLACE Prompt

Selecting from the `REPLACE SEARCH` prompt can enter a second field at `7A1F`.
The plain `SEARCH` variant skips this stage and goes directly to the refresh
path.

```asm
replace_second_prompt_or_search_refresh_C688_8D86:
C688:8D86  81 3E 7D 75 23 8D cmp  word [0x757d],0x8d23
C688:8D8C  74 E4             jz   C688:8D72
C688:8D8E  BE 18 00          mov  si,0x0018
C688:8D91  E8 F5 E8          call C688:7689
C688:8D94  32 C0             xor  al,al
C688:8D96  B5 06             mov  ch,0x06
C688:8D98  B1 01             mov  cl,0x01
C688:8D9A  BA 1F 7A          mov  dx,0x7a1f
C688:8D9D  E8 26 E4          call C688:71C6
C688:8DA0  BE 1F 7A          mov  si,0x7a1f
C688:8DA3  B1 10             mov  cl,0x10
C688:8DA5  E8 26 06          call C688:93CE
C688:8DA8  B5 10             mov  ch,0x10
C688:8DAA  BE 1F 7A          mov  si,0x7a1f
C688:8DAD  E8 D6 61          call C688:EF86
C688:8DB0  E8 2C 05          call C688:92DF
```

Inline dispatch table at `C688:8DB3`:

```text
1D -> C688:8DBF
DA -> C688:8DC4
03 -> C688:EC9F
FF -> C688:8D8E
```

`C688:8DBF` and `C688:8DC4` differ only in whether `[757D]` is preserved or
cleared before the selected-search state is committed.

```asm
replace_commit_preserve_prompt_C688_8DBF:
C688:8DBF  8B 36 7D 75       mov  si,[0x757d]
C688:8DC3  EB 03             jmp  C688:8DC7

replace_commit_clear_prompt_C688_8DC4:
C688:8DC4  BE 00 00          mov  si,0x0000

replace_commit_common_C688_8DC7:
C688:8DC7  89 36 7D 75       mov  [0x757d],si
C688:8DCB  BE 01 00          mov  si,0x0001
C688:8DCE  89 36 81 77       mov  [0x7781],si
C688:8DD2  A0 20 75          mov  al,[0x7520]
C688:8DD5  0C 02             or   al,0x02
C688:8DD7  A2 20 75          mov  [0x7520],al
C688:8DDA  E8 63 01          call C688:8F40
C688:8DDD  E8 1C C3          call C688:50FC
C688:8DE0  EB 06             jmp  C688:8DE8

replace_reselect_C688_8DE2:
C688:8DE2  E8 5B 01          call C688:8F40
C688:8DE5  E8 20 C3          call C688:5108
C688:8DE8  50                push ax
C688:8DE9  E8 D8 B6          call C688:44C4
C688:8DEC  58                pop  ax
C688:8DED  A8 10             test al,0x10
C688:8DEF  75 92             jnz  C688:8D83
```

If `[757D]` is still nonzero, the path refreshes editor/list state, sets
`[79A6]=0x04`, configures the keyboard/event wrapper through `C688:9347`, and
polls via `C688:93B5`. Event `0x1D` repeats the selected-item path; event
`0xDA` continues to the final compare/apply stage; anything else returns to the
shared application loop.

```asm
C688:8DF1  A0 7D 75          mov  al,[0x757d]
C688:8DF4  0A C0             or   al,al
C688:8DF6  74 24             jz   C688:8E1C
C688:8DF8  E8 95 9C          call C688:2A90
C688:8DFB  E8 FC 9E          call C688:2CFA
C688:8DFE  E8 C3 B6          call C688:44C4
C688:8E01  B0 04             mov  al,0x04
C688:8E03  A2 A6 79          mov  [0x79a6],al
C688:8E06  E8 3E 05          call C688:9347
C688:8E09  E8 A9 05          call C688:93B5
C688:8E0C  A0 4A 79          mov  al,[0x794a]
C688:8E0F  3C 1D             cmp  al,0x1d
C688:8E11  75 02             jnz  C688:8E15
C688:8E13  EB CD             jmp  C688:8DE2
C688:8E15  3C DA             cmp  al,0xda
C688:8E17  74 03             jz   C688:8E1C
C688:8E19  E9 83 5E          jmp  C688:EC9F
```

## Final Compare/Apply Stage

The final stage copies the second field from `7A1F` to `75A0`, emits two small
inline display-control scripts through `C688:0240`, builds a comparison mask in
`7F28`, normalizes `7A1F` when the match mode allows it, and then calls the
shared updater at `C688:5102`.

```asm
replace_final_stage_C688_8E1C:
C688:8E1C  BE 01 00          mov  si,0x0001
C688:8E1F  89 36 81 77       mov  [0x7781],si
C688:8E23  E8 1A 01          call C688:8F40
C688:8E26  BE 1F 7A          mov  si,0x7a1f
C688:8E29  BF A0 75          mov  di,0x75a0
C688:8E2C  BB 10 00          mov  bx,0x0010
C688:8E2F  06                push es
C688:8E30  BD 00 00          mov  bp,0x0000
C688:8E33  8E C5             mov  es,bp
C688:8E35  FC                cld
C688:8E36  F3 A4             rep  movsb
C688:8E38  07                pop  es
C688:8E39  E8 04 74          call C688:0240
; inline display/control bytes: A8 C7 0A 3A 18 00
C688:8E42  B0 FF             mov  al,0xff
C688:8E44  A2 7A 75          mov  [0x757a],al
C688:8E47  E8 C3 00          call C688:8F0D
C688:8E4A  32 C0             xor  al,al
C688:8E4C  A2 7A 75          mov  [0x757a],al
C688:8E4F  E8 EE 73          call C688:0240
; inline display/control bytes: 1E 38 00
```

`C688:8EE9` scans the generated mask in `7F28` and the typed replacement field
for spaces or letters. Depending on what it finds, the path uppercases lowercase
letters in `7A1F` before calling `C688:5102`.

```asm
C688:8E55  A0 20 75          mov  al,[0x7520]
C688:8E58  3C 08             cmp  al,0x08
C688:8E5A  73 5B             jnc  C688:8EB7
C688:8E5C  BE 28 7F          mov  si,0x7f28
C688:8E5F  B5 10             mov  ch,0x10
C688:8E61  E8 85 00          call C688:8EE9
...
C688:8E95  B5 10             mov  ch,0x10
C688:8E97  BE 1F 7A          mov  si,0x7a1f
C688:8E9A  8A 04             mov  al,[si]
C688:8EA0  3C 61             cmp  al,0x61
C688:8EA4  3C 7B             cmp  al,0x7b
C688:8EA8  24 DF             and  al,0xdf       ; lowercase to uppercase
C688:8EAA  88 04             mov  [si],al
...
C688:8EB7  E8 48 C2          call C688:5102
```

If `[79A6] == 0x6A`, the path reports a memory-full condition and returns to
the application loop. Otherwise it restores the saved field from `75A0` back to
`7A1F` and repeats the selected-search commit path at `C688:8DDD`.

```asm
C688:8EBA  A0 A6 79          mov  al,[0x79a6]
C688:8EBD  3C 6A             cmp  al,0x6a
C688:8EBF  74 19             jz   C688:8EDA
C688:8EC1  E8 00 B6          call C688:44C4
C688:8EC4  BE A0 75          mov  si,0x75a0
C688:8EC7  BF 1F 7A          mov  di,0x7a1f
C688:8ECA  BB 10 00          mov  bx,0x0010
C688:8ECD  06                push es
C688:8ECE  BD 00 00          mov  bp,0x0000
C688:8ED1  8E C5             mov  es,bp
C688:8ED3  FC                cld
C688:8ED4  F3 A4             rep  movsb
C688:8ED6  07                pop  es
C688:8ED7  E9 03 FF          jmp  C688:8DDD

work_memory_full_exit_C688_8EDA:
C688:8EDA  E8 E7 B5          call C688:44C4
C688:8EDD  E8 B8 5F          call C688:EE98
C688:8EE0  BE 55 00          mov  si,0x0055
C688:8EE3  E8 04 08          call C688:96EA
C688:8EE6  E9 B6 5D          jmp  C688:EC9F
```

## Local Helpers

`C688:8EE9` scans up to `CH` bytes and returns as soon as it sees a NUL, a
space, or an ASCII letter. The caller uses the returned flags: NUL returns
zero, a letter returns carry, and a space returns nonzero/noncarry.

```asm
scan_space_or_letter_C688_8EE9:
C688:8EE9  FE CD             dec  ch
C688:8EEB  8A 04             mov  al,[si]
C688:8EED  46                inc  si
C688:8EEE  0A C0             or   al,al
C688:8EF0  75 01             jnz  C688:8EF3
C688:8EF2  C3                ret
C688:8EF3  3C 20             cmp  al,0x20
C688:8EF5  74 11             jz   C688:8F08
C688:8EF7  3C 41             cmp  al,0x41
C688:8EF9  72 EE             jc   C688:8EE9
C688:8EFB  3C 5B             cmp  al,0x5b
C688:8EFD  72 09             jc   C688:8F08
C688:8EFF  3C 61             cmp  al,0x61
C688:8F01  72 E6             jc   C688:8EE9
C688:8F03  3C 7B             cmp  al,0x7b
C688:8F05  73 E2             jnc  C688:8EE9
C688:8F07  C3                ret
C688:8F08  32 C0             xor  al,al
C688:8F0A  FE C0             inc  al
C688:8F0C  C3                ret
```

`C688:8F0D` builds a 16-byte mask at `7F28` from the search string at `7A30`.
It calls `C688:97E7` for each source byte. When the helper accepts the byte and
the class is not `0x07`, it stores `[7576]` into the mask.

```asm
build_search_mask_C688_8F0D:
C688:8F0D  B5 10             mov  ch,0x10
C688:8F0F  BA 30 7A          mov  dx,0x7a30
C688:8F12  BE 28 7F          mov  si,0x7f28
C688:8F15  32 C0             xor  al,al
C688:8F17  88 04             mov  [si],al
C688:8F19  8B FA             mov  di,dx
C688:8F1B  8A 05             mov  al,[di]
C688:8F1D  42                inc  dx
C688:8F1E  0A C0             or   al,al
C688:8F20  75 01             jnz  C688:8F23
C688:8F22  C3                ret
C688:8F23  51                push cx
C688:8F24  52                push dx
C688:8F25  56                push si
C688:8F26  E8 BE 08          call C688:97E7
C688:8F29  5E                pop  si
C688:8F2A  5A                pop  dx
C688:8F2B  59                pop  cx
C688:8F2C  74 01             jz   C688:8F2F
C688:8F2E  C3                ret
C688:8F2F  24 0F             and  al,0x0f
C688:8F31  3C 07             cmp  al,0x07
C688:8F33  74 06             jz   C688:8F3B
C688:8F35  A0 76 75          mov  al,[0x7576]
C688:8F38  88 04             mov  [si],al
C688:8F3A  46                inc  si
C688:8F3B  FE CD             dec  ch
C688:8F3D  75 D6             jnz  C688:8F15
C688:8F3F  C3                ret
```

`C688:8F40` is a tiny display-state snapshot used throughout this slice.

```asm
snapshot_display_state_C688_8F40:
C688:8F40  A0 48 79          mov  al,[0x7948]
C688:8F43  A2 48 79          mov  [0x7948],al
C688:8F46  A2 9C 79          mov  [0x799c],al
C688:8F49  C3                ret
```

`C688:93CE` trims a fixed-length field by replacing trailing spaces with NULs.
If the last byte is neither space nor `0xFF`, it leaves only that final byte
eligible for trimming.

```asm
trim_trailing_spaces_C688_93CE:
C688:93CE  FF 36 EF 75       push word [0x75ef]
C688:93D2  50                push ax
C688:93D3  51                push cx
C688:93D4  52                push dx
C688:93D5  56                push si
C688:93D6  B6 00             mov  dh,0x00
C688:93D8  8A D1             mov  dl,cl
C688:93DA  03 F2             add  si,dx
C688:93DC  8A E9             mov  ch,cl
C688:93DE  4E                dec  si
C688:93DF  8A 04             mov  al,[si]
C688:93E1  3C 20             cmp  al,0x20
C688:93E3  74 06             jz   C688:93EB
C688:93E5  B5 01             mov  ch,0x01
C688:93E7  3C FF             cmp  al,0xff
C688:93E9  75 63             jnz  C688:944E
C688:93EB  32 C0             xor  al,al
C688:93ED  88 04             mov  [si],al
C688:93EF  FE CD             dec  ch
C688:93F1  75 EB             jnz  C688:93DE
...
C688:944E  5E                pop  si
C688:944F  5A                pop  dx
C688:9450  59                pop  cx
C688:9451  58                pop  ax
C688:9452  8F 06 EF 75       pop  word [0x75ef]
C688:9456  C3                ret
```

`C688:EF86` classifies a 16-byte field for this UI. It sets `[7520]=0x08` and
returns carry set if it sees a space or uppercase `A..Z` before the end. A NUL
returns immediately without carry.

```asm
classify_prompt_field_C688_EF86:
C688:EF86  8A 04             mov  al,[si]
C688:EF88  0A C0             or   al,al
C688:EF8A  75 01             jnz  C688:EF8D
C688:EF8C  C3                ret
C688:EF8D  3C 20             cmp  al,0x20
C688:EF8F  74 08             jz   C688:EF99
C688:EF91  3C 41             cmp  al,0x41
C688:EF93  72 0B             jc   C688:EFA0
C688:EF95  3C 5B             cmp  al,0x5b
C688:EF97  73 07             jnc  C688:EFA0
C688:EF99  B0 08             mov  al,0x08
C688:EF9B  A2 20 75          mov  [0x7520],al
C688:EF9E  F9                stc
C688:EF9F  C3                ret
C688:EFA0  46                inc  si
C688:EFA1  FE CD             dec  ch
C688:EFA3  75 E1             jnz  C688:EF86
C688:EFA5  32 C0             xor  al,al
C688:EFA7  C3                ret
```

## Prompt Resources

Resources are looked up through the `D59C` resource table at file `0x559C0`.
Table entry `n` is the word at `0x559C4 + n * 2`; payload starts two bytes
after the selected target.

| ID | Table word | Payload | Length | Final formatted text |
| ---: | ---: | ---: | ---: | --- |
| `0x38` | `0x056A` | `0x55F2C` | `0x0005` | Layout/control descriptor only; no printable text. |
| `0x37` | `0x0571` | `0x55F33` | `0x004F` | `SEARCH`; `SEARCH : <input>`; `Press <DA> to execute`; `Press CAN to cancel`. |
| `0x19` | `0x0612` | `0x55FD4` | `0x0050` | `REPLACE`; `SEARCH : <input>`; `Press <DA> to execute`; `Press CAN to cancel`. |
| `0x18` | `0x05C2` | `0x55F84` | `0x004E` | `REPLACE: <input>`; `Press <DA> to replace all,`; `NEXT to replace single`. |
| `0x55` | `0x1591` | `0x56F53` | `0x0020` | `Work memory is full`. |

Resource `0x37` descriptor and printable text:

```text
D59C table[0x37] = 0x0571
file 0x55F31:
u16 payload_length = 0x004F
display payload at file 0x55F33
C4 2C 09 D6 31 19 "SEARCH"
0C 0C " SEARCH : " E9 1C 32 00 E9 1F E9 1C 7A 00 E9
0C 0C 11 "Press " DA " to execute"
0C 11 "Press " F8 "CAN" F9 " to cancel"
```

Final formatted text:

```text
SEARCH

SEARCH : <input>

Press <DA> to execute
Press CAN to cancel
```

Resource `0x19`:

```text
D59C table[0x19] = 0x0612
file 0x55FD2:
u16 payload_length = 0x0050
display payload at file 0x55FD4
C4 2C 09 D6 31 19 "REPLACE"
0C " SEARCH : " E9 1C 32 00 E9 1F E9 1C 7A 00 E9
0C 0C 0C 11 "Press " DA " to execute"
0C 11 "Press " F8 "CAN" F9 " to cancel"
```

Final formatted text:

```text
REPLACE
SEARCH : <input>

Press <DA> to execute
Press CAN to cancel
```

Resource `0x18`:

```text
D59C table[0x18] = 0x05C2
file 0x55F82:
u16 payload_length = 0x004E
display payload at file 0x55F84
C0 2C 19 D6 31 20 "REPLACE: " E9 1C 32 00 E9 1F E9 1C 7A 00 E9
0C 0C 11 "Press " DA " to replace all,"
0C 11 F8 "NEXT" F9 " to replace single"
```

Final formatted text:

```text
REPLACE: <input>

Press <DA> to replace all,
NEXT to replace single
```

Resource `0x55`:

```text
D59C table[0x55] = 0x1591
file 0x56F51:
u16 payload_length = 0x0020
display payload at file 0x56F53
40 20 08 DF 39 0C 0C 1F 16 "Work memory is full "
```

Final formatted text:

```text
Work memory is full
```

## Bottom

This slice bottoms out at the shared editor/list/display helpers:

| Target | Boundary |
| --- | --- |
| `C688:50FC`, `C688:5102`, `C688:5108` | Shared editor/list update helpers used by the document UI. |
| `C688:0240`, `C688:44C4`, `C688:5B83`, `C688:5B94`, `C688:93B5` | Already-known display and input wrappers. |
| `C688:97E7` | Character-class helper used while building the search mask. |

The code here does not enter the top-level application handlers. It manages the
shared search/replace/list prompt state and then returns to `C688:EC9F`.
