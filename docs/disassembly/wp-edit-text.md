# WP EDIT TEXT Entry

This slice documents the first layer of the word-processor EDIT TEXT path. It
stops at the shared app/editor loop and redraw/update helpers; the actual editor
commands remain downstream branches.

The local manual OCR text in
[`../reference/dreamwriter-t400-manual.txt`](../reference/dreamwriter-t400-manual.txt)
is a split-left/right extraction of a messy two-up scan. It is useful for
user-facing names such as `EDIT TEXT`, `WORDL`, `REFORMAT`, `SELECT`, `SEARCH`,
and `UNDELETE`, but ROM control flow is still the source of truth.

## Top-Menu Entry Shape

The word-processor icon table labels item 1 as `EDIT TEXT`. The matching top
menu dispatch does not far-call a separate application body. Instead, key `1`
returns `AX=0` from `DC98:2807`; the caller at `C688:EB15` interprets that as
"return to the shared app/editor loop."

```asm
wp_top_menu_edit_text_return_DC98_2821:
; file 0x5F1A1
DC98:2821  3D 31 00          cmp  ax,0x31
DC98:2824  75 04             jnz  DC98:282A
DC98:2826  33 C0             xor  ax,ax
DC98:2828  EB 5B             jmp  DC98:2885
```

This explains why `CLEAR TEXT` has a direct wrapper at `C688:EB46`, while
`EDIT TEXT` is the default editor state exposed by the application loop.

```asm
wp_top_menu_default_return_C688_EB15:
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

## Editor Loop Boundary

`C688:EC9F` is the root reached after EDIT TEXT selection and after several
editor/display re-entry paths. It performs an initialization helper, refreshes
display state, polls for a key/event byte, stores it in `[794A]`, snapshots the
active editor state, and then dispatches through an inline key table.

```asm
root_edit_text_shared_loop_C688_EC9F:
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
C688:ECC3  E8 19 A6          call C688:92DF
```

The bytes after `C688:ECC3` are the inline dispatch table documented in
[`app-menu-event-loop.md`](app-menu-event-loop.md), not linear code. The table
already separates app/tool branches from shared loop maintenance. For this EDIT
TEXT slice, the important boundary is that ordinary editing remains in the
`C688:EC9F`/`C688:ECA7` loop while non-editor tools branch to their own roots.

## Boot And Redraw Sequence

The menu-entry path and the `CLEAR TEXT` worker both reach `C688:7766` to rebuild
or redraw the live editor surface. This is not a top-level EDIT TEXT selector;
it is the fixed update sequence used to bring the editor display/state back to a
known screen.

```asm
editor_boot_update_sequence_C688_7766:
; file 0x4DFE6
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

`C688:77A3` is the small per-update helper. It calls the same lower display/state
helpers for each update ID in `AL`.

```asm
editor_update_id_helper_C688_77A3:
; file 0x4E023
C688:77A3  E8 CD CC          call C688:4473
C688:77A6  E8 5C 95          call C688:0D05
C688:77A9  C3                ret
```

## Active State Snapshot

The repeated `C688:44C4` calls copy the current active editor state block into a
fixed low-RAM/UI buffer. `[7965]` holds the source pointer, `78D5..793F` receives
`0x6B` bytes, and `DX` returns the post-copy source pointer.

```asm
snapshot_active_editor_state_C688_44C4:
; file 0x4AD44
C688:44C4  8B 3E 65 79       mov  di,[0x7965]
C688:44C8  BE D5 78          mov  si,0x78d5
C688:44CB  B9 6B 00          mov  cx,0x006b
C688:44CE  06                push es
C688:44CF  BD 00 00          mov  bp,0
C688:44D2  8E C5             mov  es,bp
C688:44D4  FC                cld
C688:44D5  F3 A4             rep movsb
C688:44D7  07                pop  es
C688:44D8  8B D7             mov  dx,di
C688:44DA  C3                ret
```

The helper body after `C688:44DB` adjusts viewport/window state and is expanded
in [`wp-editor-viewport.md`](wp-editor-viewport.md). It touches editor pointers
and flags such as `[7946]`, `[7958]`, `[795A]`, `[772C]`, and `[78F5]`.

## Manual-Named Key Families

The manual gives user-facing names for several editor key families that should be
used when the ROM event paths are followed later:

| Manual name | User-visible behavior |
| --- | --- |
| `WORDL`, `WORDR`, `PREVP`, `NEXTP`, `BEGIN`, end-of-document | Quick cursor movement from the EDIT TEXT screen. |
| `WORD WRAP`, `INDENT`, `INDCLR`, `CENTER`, `R-FLUSH`, `PITCH`, `FORMAT` | Typing/layout functions. |
| `REFORMAT`, `JUSTIFY`, `SELECT`, `COPY/PASTE`, `CUT/PASTE`, `DELETE`, `SEARCH`, `REPLACE`, `NEXT`, `UNDELETE` | Editing functions. |
| `SPELL CHECK`, `AUTO SPELL`, `DICTIONARY`, `THESAURUS` | Linguistic tools; Spell/Grammar, Dictionary, and Thesaurus app-loop roots are mapped in [`wp-linguistic-tools.md`](wp-linguistic-tools.md). |

These names come from the manual's EDIT TEXT and quick-reference sections. The
ROM event bytes still need to be tied back through
[`keyboard-translation.md`](keyboard-translation.md) before assigning exact key
codes to every editor command.

## Current Bottom

This first EDIT TEXT pass bottoms at:

| Root | Current boundary |
| --- | --- |
| `C688:EC9F` | Shared app/editor loop entry and top-level event dispatch. |
| `C688:7766` | Editor redraw/update sequence used by boot and CLEAR TEXT. |
| `C688:44C4` | Active editor state snapshot into the fixed UI buffer. |
| `C688:44DB` | Viewport/window-state helper, expanded in [`wp-editor-viewport.md`](wp-editor-viewport.md). |
| App-loop printer/merge targets `C688:AD5C`, `C688:ED15` | Mapped in [`print-merge-handlers.md`](print-merge-handlers.md). |
| App-loop linguistic targets `C688:ED1F`, `C688:D8AF`, `C688:E274` | Mapped in [`wp-linguistic-tools.md`](wp-linguistic-tools.md). |
