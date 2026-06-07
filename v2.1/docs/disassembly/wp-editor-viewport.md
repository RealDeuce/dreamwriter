# WP Editor Viewport State

This slice expands the editor helper queued from
[`wp-edit-text.md`](wp-edit-text.md). It covers the `C688:44DB`/`C688:44E2`
entry pair, the shared viewport/window-state updates, and the dirty redraw
handoff. It intentionally stops at lower rendering/input helpers such as
`C688:18AC`, `C688:1A85`, `C688:1B12`, `C688:1B6F`, `C688:1D75`,
`C688:6B8C`, and `C688:6BAA`.

No image assets or string resources are directly reached in this slice. The code
builds and bounds editor/UI state in low RAM, then delegates rendering.

## Entry Pair

`C688:44DB` and `C688:44E2` enter the same body at `C688:44F4`. The shorter
entry computes and pushes `DX + CX`. The longer entry also records a range/count
triple in `[7946]`, `[7958]`, and `[795A]` before joining the shared body.

```asm
root_editor_viewport_update_C688_44DB:
; file 0x4AD5B
C688:44DB  87 D6             xchg si,dx
C688:44DD  03 F1             add  si,cx
C688:44DF  56                push si
C688:44E0  EB 12             jmp  C688:44F4

range_editor_viewport_update_C688_44E2:
C688:44E2  89 0E 58 79       mov  [0x7958],cx
C688:44E6  89 36 46 79       mov  [0x7946],si
C688:44EA  87 D6             xchg si,dx
C688:44EC  03 F1             add  si,cx
C688:44EE  56                push si
C688:44EF  4E                dec  si
C688:44F0  89 36 5A 79       mov  [0x795a],si
```

The common body stores the current count/window value in `[772C]` and exits
early if `[7A56] bit 0` is set. Otherwise it calls `C688:1B41`, clears bit
`0x40` in `[790D]`, and resets the two boundary flags `[7730]` and `[7731]`.

```asm
shared_editor_viewport_body_C688_44F4:
C688:44F4  89 0E 2C 77       mov  [0x772c],cx
C688:44F8  52                push dx
C688:44F9  A0 56 7A          mov  al,[0x7a56]
C688:44FC  A8 01             test al,0x01
C688:44FE  74 03             jz   C688:4503
C688:4500  5E                pop  si
C688:4501  5E                pop  si
C688:4502  C3                ret
C688:4503  E8 3B D6          call C688:1B41
C688:4506  BE 0D 79          mov  si,0x790d
C688:4509  80 24 BF          and  byte [si],0xbf
C688:450C  5E                pop  si
C688:450D  8B 16 F5 78       mov  dx,[0x78f5]
C688:4511  32 C0             xor  al,al
C688:4513  A2 30 77          mov  [0x7730],al
C688:4516  A2 31 77          mov  [0x7731],al
```

## Initial Clamp

The first clamp compares the pushed endpoint against `[78F5]`. A positive span
larger than one byte is sent to `C688:18AC` with `CL=4`; a zero/negative span is
converted to the opposite delta and sent with `CL=0x14`. If `[79F6]` is positive,
the current `[772C]` value is also emitted through `C688:1A85`.

```asm
initial_viewport_delta_C688_4519:
C688:4519  2B F2             sub  si,dx
C688:451B  B1 04             mov  cl,0x04
C688:451D  74 15             jz   C688:4534
C688:451F  78 13             js   C688:4534
C688:4521  8B DE             mov  bx,si
C688:4523  8A C7             mov  al,bh
C688:4525  0A C0             or   al,al
C688:4527  75 06             jnz  C688:452F
C688:4529  8A C3             mov  al,bl
C688:452B  FE C8             dec  al
C688:452D  74 05             jz   C688:4534
C688:452F  E8 7A D3          call C688:18AC
C688:4532  EB 25             jmp  C688:4559
C688:4534  B1 14             mov  cl,0x14
C688:4536  87 D6             xchg si,dx
C688:4538  BE 00 00          mov  si,0
C688:453B  32 C0             xor  al,al
C688:453D  2B F2             sub  si,dx
C688:453F  E8 6A D3          call C688:18AC
...
C688:4552  8B 16 2C 77       mov  dx,[0x772c]
C688:4556  E8 2C D5          call C688:1A85
```

After the initial clamp, the routine folds `[79F6]` into `[772C]`, stores the old
`[79F6]` in `[771B]`, derives `[7952] = [7950] + [7954]`, and primes the redraw
buffer at `7F28`.

```asm
viewport_state_seed_C688_4559:
C688:4559  8B 16 F6 79       mov  dx,[0x79f6]
C688:455D  8B 36 2C 77       mov  si,[0x772c]
C688:4561  03 F2             add  si,dx
C688:4563  89 16 1B 77       mov  [0x771b],dx
C688:4567  89 36 2C 77       mov  [0x772c],si
C688:456B  8B 16 54 79       mov  dx,[0x7954]
C688:456F  8B 36 50 79       mov  si,[0x7950]
C688:4573  03 F2             add  si,dx
C688:4575  89 36 52 79       mov  [0x7952],si
C688:4579  BE 00 00          mov  si,0
C688:457C  89 36 6B 79       mov  [0x796b],si
C688:4580  32 C0             xor  al,al
C688:4582  A2 1D 77          mov  [0x771d],al
C688:4585  BE 28 7F          mov  si,0x7f28
C688:4588  89 36 E2 79       mov  [0x79e2],si
C688:458C  A0 5E 79          mov  al,[0x795e]
C688:458F  A2 9A 79          mov  [0x799a],al
C688:4592  B1 00             mov  cl,0
C688:4594  E8 15 D3          call C688:18AC
```

## Range Bounds

If `[771D]` becomes nonzero, the routine checks `[7973] + [79F6]` against the
`[78FD]` limit. Carry/negative cases reset `[7971]` from `[7907]`; a later path
resets `[7973]` from `[78FB]` and adjusts `[772C]`. This looks like the editor
window's visible high/low bounds rather than document heap traversal.

```asm
viewport_range_bounds_C688_4597:
C688:4597  A0 1D 77          mov  al,[0x771d]
C688:459A  0A C0             or   al,al
C688:459C  74 64             jz   C688:4602
C688:459E  8B 16 F6 79       mov  dx,[0x79f6]
C688:45A2  8B 36 73 79       mov  si,[0x7973]
C688:45A6  03 F2             add  si,dx
C688:45A8  72 0E             jc   C688:45B8
C688:45AA  87 D6             xchg si,dx
C688:45AC  8B 36 FD 78       mov  si,[0x78fd]
C688:45B0  2B F2             sub  si,dx
C688:45B2  8B 36 F6 79       mov  si,[0x79f6]
C688:45B6  79 23             jns  C688:45DB
C688:45B8  8B 36 07 79       mov  si,[0x7907]
C688:45BC  89 36 71 79       mov  [0x7971],si
...
C688:45D7  8B 16 FB 78       mov  dx,[0x78fb]
C688:45DB  89 16 73 79       mov  [0x7973],dx
C688:45DF  A0 A1 79          mov  al,[0x79a1]
C688:45E2  A8 01             test al,0x01
C688:45E4  74 03             jz   C688:45E9
C688:45E6  BE 02 00          mov  si,0x0002
C688:45E9  8B 16 2C 77       mov  dx,[0x772c]
C688:45ED  03 F2             add  si,dx
C688:45EF  89 36 2C 77       mov  [0x772c],si
```

The zero-`[771D]` branch can force `[771D]=1` if `[771B]` is negative, then emits
from the `7F28` scratch buffer with a mode byte from `[795F]`.

```asm
negative_delta_emit_seed_C688_4602:
C688:4602  8B 36 1B 77       mov  si,[0x771b]
C688:4606  F7 C6 00 80       test si,0x8000
C688:460A  74 1A             jz   C688:4626
C688:460C  C6 06 1D 77 01    mov  byte [0x771d],0x01
C688:4611  8B DE             mov  bx,si
C688:4613  8A C3             mov  al,bl
C688:4615  FE C0             inc  al
C688:4617  74 0D             jz   C688:4626
C688:4619  A0 5F 79          mov  al,[0x795f]
C688:461C  BE 28 7F          mov  si,0x7f28
C688:461F  E8 2F D4          call C688:1A51
C688:4622  89 36 E2 79       mov  [0x79e2],si
C688:4626  E8 E9 D4          call C688:1B12
```

## Final Clamp And Redraw Handoff

The final section keeps `[772C]` within the recorded `[7958]`/end span, sets
`[7730]` or `[7731]` when it clips at either side, and calls `C688:6B8C` before
checking `[790D] bit 0x40`. If that bit is set, the routine clears it, measures
the dirty output length from `7F28`, stores the result in `[7727]`, and loops
back through the lower redraw path.

```asm
final_viewport_clamp_C688_465A:
C688:465A  8B 36 01 79       mov  si,[0x7901]
C688:465E  8B 0E FD 78       mov  cx,[0x78fd]
C688:4662  2B F1             sub  si,cx
C688:4664  03 F2             add  si,dx
C688:4666  8B 16 71 79       mov  dx,[0x7971]
C688:466A  03 F2             add  si,dx
C688:466C  EB 30             jmp  C688:469E
...
C688:46A0  8B 36 2C 77       mov  si,[0x772c]
C688:46A4  03 F2             add  si,dx
C688:46A6  89 36 2C 77       mov  [0x772c],si
C688:46AA  8B 36 71 79       mov  si,[0x7971]
C688:46AE  89 36 73 79       mov  [0x7973],si

redraw_handoff_C688_46B2:
C688:46B2  8B 36 2C 77       mov  si,[0x772c]
C688:46B6  8B 16 58 79       mov  dx,[0x7958]
C688:46BA  2B F2             sub  si,dx
C688:46BC  F7 C6 00 80       test si,0x8000
C688:46C0  74 0B             jz   C688:46CD
C688:46C2  46                inc  si
C688:46C3  83 FE 00          cmp  si,0
C688:46C6  75 77             jnz  C688:473F
C688:46C8  C6 06 30 77 01    mov  byte [0x7730],0x01
...
C688:46E4  A2 31 77          mov  [0x7731],al
C688:46E7  E8 A2 24          call C688:6B8C
C688:46EA  32 C0             xor  al,al
C688:46EC  BE 0D 79          mov  si,0x790d
C688:46EF  F6 04 40          test byte [si],0x40
C688:46F2  74 55             jz   C688:4749
C688:46F4  80 24 BF          and  byte [si],0xbf
C688:46F7  0A C0             or   al,al
C688:46F9  9F                lahf
C688:46FA  50                push ax
C688:46FB  BE 28 7F          mov  si,0x7f28
C688:46FE  89 36 E2 79       mov  [0x79e2],si
C688:4702  75 03             jnz  C688:4707
C688:4704  E8 68 D4          call C688:1B6F
C688:4707  89 36 E2 79       mov  [0x79e2],si
C688:470B  8B 0E 60 7A       mov  cx,[0x7a60]
C688:470F  E8 63 D6          call C688:1D75
C688:4712  8B 36 E2 79       mov  si,[0x79e2]
C688:4716  BA 28 7F          mov  dx,0x7f28
C688:4719  32 C0             xor  al,al
C688:471B  A2 2B 77          mov  [0x772b],al
C688:471E  2B F2             sub  si,dx
C688:4720  89 36 27 77       mov  [0x7727],si
```

The terminal paths either set `[794E]`/`[771D]` to `0xFF` and loop, or complete
with an optional final `C688:1A85` call and jump to `C688:1A7B`.

```asm
redraw_loop_or_return_C688_4724:
C688:4724  B0 05             mov  al,0x05
C688:4726  A2 1D 77          mov  [0x771d],al
C688:4729  BE 24 77          mov  si,0x7724
C688:472C  89 36 1B 77       mov  [0x771b],si
...
C688:473F  B0 FF             mov  al,0xff
C688:4741  A2 4E 79          mov  [0x794e],al
C688:4744  A2 1D 77          mov  [0x771d],al
C688:4747  EB A3             jmp  C688:46EC
C688:4749  8B 36 6B 79       mov  si,[0x796b]
C688:474D  8B 16 2C 77       mov  dx,[0x772c]
C688:4751  03 F2             add  si,dx
...
C688:476D  A0 5E 79          mov  al,[0x795e]
C688:4770  A2 9A 79          mov  [0x799a],al
C688:4773  74 03             jz   C688:4778
C688:4775  E8 0D D3          call C688:1A85
C688:4778  E9 00 D3          jmp  C688:1A7B
```

## State Fields

| Field | Use in this slice |
| --- | --- |
| `[7946]`, `[7958]`, `[795A]` | Range start, count, and inclusive end recorded by the longer `C688:44E2` entry. |
| `[772C]` | Current viewport/window position or delta accumulator, repeatedly clamped and written back. |
| `[78F5]`, `[78FB]`, `[78FD]` | Existing editor window limits used by the clamp paths. |
| `[7971]`, `[7973]` | Lower/upper visible-range bounds updated during the clamp. |
| `[771B]`, `[771D]` | Redraw delta/state pair; negative deltas and dirty output set `[771D]` nonzero. |
| `[7730]`, `[7731]` | Boundary flags set when the final clamp clips at the left/top or right/bottom side. |
| `[79E2]`, `7F28`, `[7727]`, `[772B]` | Scratch-output pointer, scratch buffer, measured output length, and small output flag. |
| `[790D] bit 0x40` | Dirty/redraw flag consumed by the handoff section. |
| `[799A]`, `[795E]`, `[795F]`, `[7A60]` | Mode/format bytes and count passed to lower rendering helpers. |

## Current Bottom

This pass bottoms at the lower helpers called from the viewport routine. The
first redraw/input helper layer is now expanded in
[`wp-editor-redraw.md`](wp-editor-redraw.md).

| Root | Current boundary |
| --- | --- |
| `C688:18AC` | Repeated span/delta emitter called with `CL=0`, `4`, or `0x14`; expanded in [`wp-editor-redraw.md`](wp-editor-redraw.md). |
| `C688:1A51`, `C688:1A85`, `C688:1B12`, `C688:1B41`, `C688:1B6F`, `C688:1D75`, `C688:6B8C`, `C688:6BAA` | Lower redraw-buffer helpers around `7F28`, `[79E2]`, and renderer handoff; expanded in [`wp-editor-redraw.md`](wp-editor-redraw.md). |
| `C688:1E27`, `C688:1F45`, `C688:1F53`, `C688:1F7E` | Redraw byte dispatcher, state-save tail, and first compact marker families; expanded in [`wp-editor-redraw.md`](wp-editor-redraw.md). |
| `C688:21F4`, `C688:2254`, `C688:22F0`, `C688:2310`, `C688:231C`, `C688:24C9`, `C688:24CE`, `C688:24F0` | Classifier-specific and final-render exits; expanded in [`wp-editor-redraw.md`](wp-editor-redraw.md). |
| `C688:1A17`, `C688:1A24`, `C688:1BA9`, `C688:1C39`, `C688:1C5F`, `C688:1CA7`, `C688:1CD7`, `C688:1D4D` | Local redraw span, bound, and final-output utility helpers; expanded in [`wp-editor-redraw.md`](wp-editor-redraw.md). |
| `C688:2574`, `C688:626D`, `C688:A355` | Classifier table lookup, marker-mask merge, and synthetic-stream gate; expanded in [`wp-editor-redraw.md`](wp-editor-redraw.md). |
| `C688:A378`, `C688:A37F`, `C688:A494` | High synthetic-stream builders around scratch stream `0x8029`; expanded in [`wp-editor-redraw.md`](wp-editor-redraw.md). |
| `C688:0EF2`, `C688:0F49` | Decimal formatter and synthetic-stream handoff wrapper; expanded in [`wp-editor-redraw.md`](wp-editor-redraw.md). |
| `C688:1286`, `C688:4239`, `C688:66FC` | No-op marker hook, width scaler, and state-record width helper; expanded in [`wp-editor-redraw.md`](wp-editor-redraw.md). |
| `C688:3C2B`, `C688:3C68` | Renderer descriptor setup and flush helpers; expanded in [`wp-editor-redraw.md`](wp-editor-redraw.md). |
