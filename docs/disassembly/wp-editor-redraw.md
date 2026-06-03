# WP Editor Redraw State

This slice expands `C688:18AC`, the span/delta state emitter reached from
[`wp-editor-viewport.md`](wp-editor-viewport.md). The important address lesson
from this layer is that `ndisasm` prints near-call targets as raw 16-bit offsets
from its current origin; the active application segment is still `C688`, so the
viewport call bytes `E8 7A D3` target `C688:18AC`, not `C688:812C`.

No image assets or direct string resources are reached here. The code updates
editor redraw state and scratch-buffer pointers, then branches to deeper
rendering helpers.

## Span Emitter Entry

`C688:18AC` is called by the viewport clamp with different `CL` values. Calls
observed so far use `CL=0`, `CL=4`, and `CL=0x14`. Bit `0x04` selects the longer
redraw-state path; if it is clear, the routine jumps to the state restore path at
`C688:19B2`.

```asm
root_editor_span_emitter_C688_18AC:
; file 0x4812C
C688:18AC  F6 C1 04          test cl,0x04
C688:18AF  75 03             jnz  C688:18B4
C688:18B1  E9 FE 00          jmp  C688:19B2
C688:18B4  56                push si
C688:18B5  E8 97 00          call C688:194F
C688:18B8  80 C9 20          or   cl,0x20
C688:18BB  F6 C1 10          test cl,0x10
C688:18BE  75 03             jnz  C688:18C3
C688:18C0  E9 E1 00          jmp  C688:19A4
```

The `0x10` branch primes several range/sentinel fields and chooses between two
ways to seed `[7967]`, `[7969]`, and `[7963]` from the live editor state.

```asm
span_emitter_long_path_C688_18C3:
C688:18C3  80 C9 10          or   cl,0x10
C688:18C6  BE 7E 00          mov  si,0x007e
C688:18C9  89 36 D9 79       mov  [0x79d9],si
C688:18CD  BE 7B 00          mov  si,0x007b
C688:18D0  89 36 D7 79       mov  [0x79d7],si
C688:18D4  BE FF FF          mov  si,0xffff
C688:18D7  89 36 5C 79       mov  [0x795c],si
C688:18DB  89 36 D5 79       mov  [0x79d5],si
C688:18DF  8B 16 EB 78       mov  dx,[0x78eb]
C688:18E3  F6 C2 40          test dl,0x40
C688:18E6  74 28             jz   C688:1910
C688:18E8  E8 03 00          call C688:18EE
C688:18EB  E9 1F 05          jmp  C688:208D
```

The bit-`0x40` subpath treats `[78F1]` as a signed low byte and adds it to the
current `DX`; the non-`0x40` subpath uses `[78E7]` and `[78EF]`, then jumps to a
deeper renderer at `C688:1DFD`.

```asm
signed_delta_seed_C688_18EE:
C688:18EE  E8 19 01          call C688:1A0A
C688:18F1  89 16 67 79       mov  [0x7967],dx
C688:18F5  8B 36 E9 78       mov  si,[0x78e9]
C688:18F9  89 36 69 79       mov  [0x7969],si
C688:18FD  8B 36 F1 78       mov  si,[0x78f1]
C688:1901  F7 C6 80 00       test si,0x0080
C688:1905  74 04             jz   C688:190B
C688:1907  81 CE 00 FF       or   si,0xff00
C688:190B  03 F2             add  si,dx
C688:190D  87 D6             xchg si,dx
C688:190F  C3                ret

plain_delta_seed_C688_1910:
C688:1910  89 16 67 79       mov  [0x7967],dx
C688:1914  8B 36 E7 78       mov  si,[0x78e7]
C688:1918  89 36 69 79       mov  [0x7969],si
C688:191C  8B 36 EF 78       mov  si,[0x78ef]
C688:1920  03 F2             add  si,dx
C688:1922  87 D6             xchg si,dx
C688:1924  4E                dec  si
C688:1925  89 36 63 79       mov  [0x7963],si
C688:1929  E9 51 04          jmp  C688:1DFD
```

## State Primer

`C688:194F` is the common primer used before the long path. It resets `[79F6]`,
copies mode bytes into `[795F]`, points `[75ED]` at `[795C]`, and snapshots the
current baseline range fields.

```asm
redraw_state_primer_C688_194F:
C688:194F  56                push si
C688:1950  C7 06 F6 79 0000  mov  word [0x79f6],0
C688:1956  8B 36 3E 79       mov  si,[0x793e]
C688:195A  89 36 5F 79       mov  [0x795f],si
C688:195E  C7 06 ED 75 5C79  mov  word [0x75ed],0x795c
C688:1964  8B 36 E5 78       mov  si,[0x78e5]
C688:1968  8B 16 A1 79       mov  dx,[0x79a1]
C688:196C  F6 C2 01          test dl,0x01
C688:196F  74 03             jz   C688:1974
C688:1971  BE 02 00          mov  si,0x0002
C688:1974  89 36 15 7A       mov  [0x7a15],si
C688:1978  89 36 6B 79       mov  [0x796b],si
C688:197C  8B 36 7B 79       mov  si,[0x797b]
C688:1980  89 36 6D 79       mov  [0x796d],si
C688:1984  8B 36 12 79       mov  si,[0x7912]
C688:1988  89 36 61 79       mov  [0x7961],si
C688:198C  5E                pop  si
C688:198D  C3                ret
```

The short continuation at `C688:192C` seeds a simple default state used by the
non-`0x40` path and the `C688:19A4` path.

```asm
default_span_fields_C688_192C:
C688:192C  C7 06 D9 79 7C00  mov  word [0x79d9],0x007c
C688:1932  8B 36 15 7A       mov  si,[0x7a15]
C688:1936  89 36 6B 79       mov  [0x796b],si
C688:193A  BE 00 00          mov  si,0
C688:193D  89 36 D7 79       mov  [0x79d7],si
C688:1941  C7 06 D5 79 7C00  mov  word [0x79d5],0x007c
C688:1947  BE 01 00          mov  si,0x0001
C688:194A  89 36 5C 79       mov  [0x795c],si
C688:194E  C3                ret
```

## Restore Path

When bit `0x04` is not set, `C688:19B2` restores the saved redraw state from
`796*` fields into the active `79*` fields. If `CL bit 0` is set, it first runs
the alternate primer at `C688:198E`.

```asm
restore_redraw_state_C688_19B2:
C688:19B2  32 C0             xor  al,al
C688:19B4  56                push si
C688:19B5  BE EC 79          mov  si,0x79ec
C688:19B8  80 24 BF          and  byte [si],0xbf
C688:19BB  A2 2B 77          mov  [0x772b],al
C688:19BE  F6 C1 01          test cl,0x01
C688:19C1  75 CB             jnz  C688:198E
C688:19C3  8B 16 69 79       mov  dx,[0x7969]
C688:19C7  F6 C2 40          test dl,0x40
C688:19CA  75 03             jnz  C688:19CF
C688:19CC  E8 EF 1F          call C688:39BE
C688:19CF  A0 5E 79          mov  al,[0x795e]
C688:19D2  A2 88 79          mov  [0x7988],al
C688:19D5  8B 36 6B 79       mov  si,[0x796b]
C688:19D9  89 36 F6 79       mov  [0x79f6],si
C688:19DD  8B 36 15 7A       mov  si,[0x7a15]
C688:19E1  89 36 6B 79       mov  [0x796b],si
C688:19E5  8B 36 6D 79       mov  si,[0x796d]
C688:19E9  89 36 41 7A       mov  [0x7a41],si
C688:19ED  8B 36 61 79       mov  si,[0x7961]
C688:19F1  89 36 DB 79       mov  [0x79db],si
C688:19F5  89 36 79 79       mov  [0x7979],si
C688:19F9  A0 67 79          mov  al,[0x7967]
C688:19FC  A8 40             test al,0x40
C688:19FE  74 03             jz   C688:1A03
C688:1A00  E9 50 05          jmp  C688:1FD3
C688:1A03  8B 16 6F 79       mov  dx,[0x796f]
C688:1A07  E9 73 03          jmp  C688:1DFD
```

## Small Helpers

`C688:1A51` appends a small `FF 04` record to the scratch stream at `SI`, stores
`DX`, and mirrors `DX` to `[7713]`. It is called by the viewport code when
`[771B]` indicates a negative delta.

```asm
append_redraw_position_record_C688_1A51:
C688:1A51  56                push si
C688:1A52  A2 4E 79          mov  [0x794e],al
C688:1A55  E8 83 47          call C688:61DB
C688:1A58  5E                pop  si
C688:1A59  C7 04 FF 04       mov  word [si],0x04ff
C688:1A5D  83 C6 02          add  si,byte +0x02
C688:1A60  89 14             mov  [si],dx
C688:1A62  83 C6 02          add  si,byte +0x02
C688:1A65  89 16 13 77       mov  [0x7713],dx
C688:1A69  C3                ret
```

`C688:1A7B` is the simple repaint kick reached at the end of the viewport
routine. It clears `AL`, reloads `DX` from `[78E7]`, calls a lower helper, and
returns.

```asm
finish_redraw_kick_C688_1A7B:
C688:1A7B  32 C0             xor  al,al
C688:1A7D  8B 16 E7 78       mov  dx,[0x78e7]
C688:1A81  E8 31 1F          call C688:39B5
C688:1A84  C3                ret
```

## State Fields

| Field | Use in this slice |
| --- | --- |
| `[75ED]` | Points at `[795C]` while redraw state is being rebuilt. |
| `[78E5]`, `[78E7]`, `[78E9]`, `[78EB]`, `[78ED]`, `[78EF]`, `[78F1]`, `[78F3]` | Live editor/window fields consumed while computing redraw deltas. |
| `[793D]`, `[793E]`, `[795E]`, `[795F]`, `[7988]` | Mode bytes copied into active/saved redraw state. |
| `[7961]`, `[7963]`, `[7967]`, `[7969]`, `[796B]`, `[796D]`, `[796F]` | Saved redraw/window state restored by `C688:19B2`. |
| `[7979]`, `[79DB]`, `[79DF]`, `[79F6]`, `[7A15]`, `[7A41]` | Active redraw/window fields updated from the saved state. |
| `[772B]`, `[7713]` | Scratch-stream state used by lower drawing helpers. |

## Current Bottom

This slice stops at the lower drawing and editor-state helpers:

| Root | Current boundary |
| --- | --- |
| `C688:1A85` | Range/output clamp helper adjacent to this slice. |
| `C688:1B12`, `C688:1B41`, `C688:1B6F`, `C688:1D75` | Redraw mode/buffer helpers around `7F28`, `[79E2]`, and active editor state. |
| `C688:1DFD`, `C688:1FD3`, `C688:208D` | Deeper redraw/rendering exits selected by state bits. |
| `C688:39B5`, `C688:39BE`, `C688:61DB` | Lower utility calls used by this slice. |
