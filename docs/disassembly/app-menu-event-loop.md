# Application Menu Event Loop

This slice expands the shared `C688:EC9F` application menu/event loop reached
from [`menu-entry.md`](menu-entry.md). It covers the loop, its inline dispatch
tables, and the shallow menu-return targets. It intentionally stops at
application bodies such as editor commands, file/document flows, printer output,
and linguistic tools.

No image assets or direct string resources are reached in this slice. Several
targets load display/resource IDs, but the concrete string and bitmap resources
belong to the downstream app/UI handlers.

## Inline Dispatch Primitive

`C688:92DF` is a return-address-rewriting dispatch helper. Callers place a
byte/word table immediately after the call instruction.

Descriptor:

```text
<key-dispatch-table> := entry* terminator-or-default
entry                := u8 key, u16 target_offset
terminator           := u8 0x00
default              := u8 0xFF, u16 target_offset
```

`C688:92DF` first calls `C688:EE8C`, which normalizes `AL` from `[794A]` unless
the current event byte is `0xFF`. `C688:92E2` enters the same dispatcher body
without that pre-call.

```asm
inline_key_dispatch_C688_92DF:
; file 0x4FB5F
C688:92DF  E8 AA 5B          call C688:EE8C

inline_key_dispatch_body_C688_92E2:
C688:92E2  8B EC             mov  bp,sp
C688:92E4  87 76 00          xchg [bp+0],si      ; swap caller return address with SI
C688:92E7  52                push dx
C688:92E8  8A D0             mov  dl,al
C688:92EA  2E 8A 04          mov  al,[cs:si]
C688:92ED  46                inc  si
C688:92EE  3C 00             cmp  al,0
C688:92F0  74 0F             jz   C688:9301
C688:92F2  3C FF             cmp  al,0xff
C688:92F4  74 08             jz   C688:92FE
C688:92F6  3A C2             cmp  al,dl
C688:92F8  74 04             jz   C688:92FE
C688:92FA  46                inc  si
C688:92FB  46                inc  si
C688:92FC  EB EC             jmp  C688:92EA
C688:92FE  2E 8B 34          mov  si,[cs:si]
C688:9301  5A                pop  dx
C688:9302  8B EC             mov  bp,sp
C688:9304  87 76 00          xchg [bp+0],si      ; ret lands at selected target
C688:9307  A0 4A 79          mov  al,[0x794a]
C688:930A  C3                ret
```

## Loop Entry

`C688:EC9F` is reached from the first-menu branch path at
[`menu-entry.md`](menu-entry.md). The loop performs a refresh/poll sequence,
stores the event byte in `[794A]`, then dispatches it.

```asm
root_app_menu_event_loop_C688_EC9F:
; file 0x5551F
C688:EC9F  E8 3B 8B          call C688:77DD
C688:ECA2  B0 FF             mov  al,0xff
C688:ECA4  A2 E4 75          mov  [0x75e4],al

loop_refresh_and_poll_C688_ECA7:
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
C688:ECC3  E8 19 A6          call C688:92DF
```

The bytes after `C688:ECC3` are table data, not code. Linear disassembly will
show false instructions until the first real target at `C688:ECF6`.

Main event table at file `0x55546` / `C688:ECC6`:

```text
<key-dispatch-table>
0x01 -> C688:ECA7
0x02 -> C688:EF4F
0xE8 -> C688:EF59
0x0B -> C688:ECF6
0x0A -> C688:8319
0x1D -> C688:8CFB
0x1B -> C688:8D23
0x1C -> C688:8D0F
0xF6 -> C688:ED1F
0xEA -> C688:ED15
0xD2 -> C688:AD5C
0xF7 -> C688:D8AF
0xF5 -> C688:ED1A
0xF8 -> C688:E274
0x03 -> C688:ECF6
0xFF -> C688:EB15
```

## Top-Menu Return Paths

The default table target returns to the word-processor top icon menu. It clears
`[7520]`, far-calls `DC98:2807`, and returns to the shared loop when the top
menu returns `AX=0`.

```asm
wp_top_menu_default_C688_EB15:
; file 0x55395
C688:EB15  E8 92 8C          call C688:77AA
C688:EB18  32 C0             xor  al,al
C688:EB1A  A2 20 75          mov  [0x7520],al
C688:EB1D  06                push es
C688:EB1E  9A 07 28 98 DC    call DC98:2807
C688:EB23  07                pop  es
C688:EB24  0A C0             or   al,al
C688:EB26  74 03             jz   C688:EB2B
C688:EB28  E9 1A 04          jmp  C688:EF45
C688:EB2B  E9 71 01          jmp  C688:EC9F
```

If `DC98:2807` returns nonzero, the code enters `C688:EF45`, which opens the
organizer top menu and then returns to `C688:EB15`.

```asm
organizer_then_wp_menu_C688_EF45:
; file 0x557C5
C688:EF45  06                push es
C688:EF46  9A C3 53 98 DC    call DC98:53C3
C688:EF4B  07                pop  es
C688:EF4C  E9 C6 FB          jmp  C688:EB15
```

The explicit `0x02` event target also opens the organizer menu, but returns
directly to the shared loop:

```asm
organizer_menu_event_C688_EF4F:
; file 0x557CF
C688:EF4F  06                push es
C688:EF50  9A C3 53 98 DC    call DC98:53C3
C688:EF55  07                pop  es
C688:EF56  E9 46 FD          jmp  C688:EC9F
```

Event `0xE8` far-calls a `DC98` helper and stores a non-`FFFF` result byte in
`[7884]`, then returns to the loop. The helper body remains outside this slice.

```asm
dc98_menu_helper_event_C688_EF59:
; file 0x557D9
C688:EF59  06                push es
C688:EF5A  9A 08 4D 98 DC    call DC98:4D08
C688:EF5F  3D FF FF          cmp  ax,0xffff
C688:EF62  74 03             jz   C688:EF67
C688:EF64  A2 84 78          mov  [0x7884],al
C688:EF67  07                pop  es
C688:EF68  E9 34 FD          jmp  C688:EC9F
```

## Cancel And App Tool Events

Events `0x0B` and `0x03` share `C688:ECF6`. If bit 0 of `[8E3F]` is set, the
handler clears it and returns to the refresh/poll point. Otherwise it performs a
small reset/update sequence and returns through the default top-menu path.

```asm
cancel_or_escape_event_C688_ECF6:
; file 0x55576
C688:ECF6  F6 06 3F 8E 01    test byte [0x8e3f],0x01
C688:ECFB  74 07             jz   C688:ED04
C688:ECFD  80 26 3F 8E FE    and  byte [0x8e3f],0xfe
C688:ED02  EB A3             jmp  C688:ECA7
C688:ED04  E8 24 75          call C688:622B
C688:ED07  E8 07 1E          call C688:0B11
C688:ED0A  E8 B7 57          call C688:44C4
C688:ED0D  B0 02             mov  al,0x02
C688:ED0F  E8 91 8A          call C688:77A3
C688:ED12  E9 00 FE          jmp  C688:EB15
```

The following table targets are app/tool boundaries:

| Event | Target | File offset | Current boundary |
| ---: | --- | ---: | --- |
| `0x0A` | `C688:8319` | `0x4EB99` | First-menu/input re-entry path; see [`document-picker-ui.md`](document-picker-ui.md#first-menu-re-entry). |
| `0x1D` | `C688:8CFB` | `0x4F57B` | Document/list continuation after the `LIST OF DOC.` template; see [`document-picker-ui.md`](document-picker-ui.md#documentlist-continuation). |
| `0x1B` | `C688:8D23` | `0x4F5A3` | `SEARCH` prompt variant; see [`document-picker-ui.md`](document-picker-ui.md#prompt-entry-variants). |
| `0x1C` | `C688:8D0F` | `0x4F58F` | `REPLACE SEARCH` prompt variant; see [`document-picker-ui.md`](document-picker-ui.md#prompt-entry-variants). |
| `0xF6` | `C688:ED1F` | `0x5559F` | Spelling/grammar front end; see [`../spell-engine.md`](../spell-engine.md). |
| `0xEA` | `C688:ED15` | `0x55595` | Calls `C688:ACBC`, then returns to `C688:EC9F`; printer/merge-side boundary. |
| `0xD2` | `C688:AD5C` | `0x515DC` | Address-book print/merge reader boundary. |
| `0xF7` | `C688:D8AF` | `0x5412F` | Large document/linguistic flow with its own nested dispatch. |
| `0xF5` | `C688:ED1A` | `0x5559A` | Forced diagnostic-monitor entry through `C688:01B0`; see [`early-app-helper.md`](early-app-helper.md). |
| `0xF8` | `C688:E274` | `0x54AF4` | Thesaurus front end; see [`../spell-engine.md`](../spell-engine.md#editor-thesaurus-front-end). |

`C688:ED1F` is not expanded here because it enters the spelling/grammar UI and
the banked linguistic service path already tracked in the spell-engine notes.

## No-Event State Dispatch

When the poll result is `0xFF`, the loop dispatches on `[79A6]` through the
`C688:92E2` body. The table begins at file `0x5560A` / `C688:ED8A`.

```asm
no_event_dispatch_C688_ED84:
; file 0x55604
C688:ED84  A0 A6 79          mov  al,[0x79a6]
C688:ED87  E8 58 A5          call C688:92E2
```

No-event state table:

```text
<key-dispatch-table>
0x60 -> C688:ED9C
0x62 -> C688:EDE8
0x66 -> C688:EE34
0x6C -> C688:EE2F
0x64 -> C688:EDBC
0xFF -> C688:EDE8
```

The state targets are shared loop maintenance, not standalone apps:

| State | Target | Current read |
| ---: | --- | --- |
| `0x60` | `C688:ED9C` | Probes current mode with `C688:EEFE`, may update `[77DA]` through `C688:EE53`, then loops or displays resource `0x42`. |
| `0x62`, `0xFF` | `C688:EDE8` | Refreshes display/editor state, emits through `C688:5B83`, updates `[7994]` and `[75E4]`, then returns to `C688:ECA7`. |
| `0x66` | `C688:EE34` | Repeats a resource/list selection around resource `0x58` until a `y`-style response or zero result. |
| `0x6C` | `C688:EE2F` | Displays resource `0x57` through the same resource/error path as `0x42`. |
| `0x64` | `C688:EDBC` | Falls through to the `C688:EDE8` refresh path. |

Excerpt around the real state targets, with the inline table skipped:

```asm
C688:ED9C  F8                clc
C688:ED9D  E8 5D 01          call C688:EEFE
C688:EDA0  72 28             jc   C688:EDCB
...
C688:EDBE  BE 42 00          mov  si,0x0042
C688:EDC1  E8 26 A9          call C688:96EA
C688:EDC4  EB F3             jmp  C688:EDB9
...
C688:EDE8  E8 25 98          call C688:8610
C688:EDEB  E8 A2 6D          call C688:5B90
...
C688:EE20  E8 A1 56          call C688:44C4
C688:EE23  A0 C1 79          mov  al,[0x79c1]
C688:EE26  A2 E4 75          mov  [0x75e4],al
C688:EE29  E8 B1 89          call C688:77DD
C688:EE2C  E9 78 FE          jmp  C688:ECA7
C688:EE2F  BE 57 00          mov  si,0x0057
C688:EE32  EB 8D             jmp  C688:EDC1
C688:EE34  E8 61 00          call C688:EE98
C688:EE37  BE 58 00          mov  si,0x0058
C688:EE3A  E8 47 00          call C688:EE84
```

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C688:ED1F`, `C688:E274`, `C688:D8AF` | wp-linguistic-tools.md | Spelling/grammar, thesaurus, and related document/linguistic flows. |
| `C688:AD5C`, `C688:ED15` | print-merge-handlers.md | Printer/merge/address-book application-side handlers. |
