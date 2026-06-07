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
C688:18EB  E9 1F 05          jmp  C688:1E0D
```

The bit-`0x40` subpath treats `[78F1]` as a signed low byte and adds it to the
current `DX`; the non-`0x40` subpath uses `[78E7]` and `[78EF]`, then jumps to
the common redraw stream walker at `C688:1D7D`.

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
C688:1929  E9 51 04          jmp  C688:1D7D
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
C688:1A00  E9 50 05          jmp  C688:1F53
C688:1A03  8B 16 6F 79       mov  dx,[0x796f]
C688:1A07  E9 73 03          jmp  C688:1D7D
```

## Small Helpers

`C688:1A85` is the range/output clamp helper reached from the viewport code
when a positive `[79F6]` value needs to be emitted. It compares the live `DX`
position with `[7958]`, limits the span against `[78E1]` and, when `[7990]` is
set, folds in an additional width from `C688:4239` and `[772E]`. The accepted
range is then emitted through lower output helpers at `C688:3C2B` and
`C688:3C68`.

```asm
emit_clamped_redraw_range_C688_1A85:
; file 0x48305
C688:1A85  32 C0             xor  al,al
C688:1A87  A2 FF 79          mov  [0x79ff],al
C688:1A8A  8B 0E 58 79       mov  cx,[0x7958]
C688:1A8E  2B CA             sub  cx,dx
C688:1A90  78 0E             js   C688:1AA0
C688:1A92  74 0C             jz   C688:1AA0
C688:1A94  2B F1             sub  si,cx
C688:1A96  79 01             jns  C688:1A99
C688:1A98  C3                ret
C688:1A99  75 01             jnz  C688:1A9C
C688:1A9B  C3                ret
C688:1A9C  8B 16 58 79       mov  dx,[0x7958]
C688:1AA0  8B 0E 54 79       mov  cx,[0x7954]
C688:1AA4  A0 90 79          mov  al,[0x7990]
C688:1AA7  0A C0             or   al,al
C688:1AA9  74 27             jz   C688:1AD2
C688:1AAB  56                push si
C688:1AAC  52                push dx
C688:1AAD  8B 36 16 79       mov  si,[0x7916]
C688:1AB1  03 F1             add  si,cx
C688:1AB3  E8 83 27          call C688:4239
...
C688:1AD2  51                push cx
C688:1AD3  56                push si
C688:1AD4  03 F2             add  si,dx
C688:1AD6  4E                dec  si
C688:1AD7  8B CE             mov  cx,si
C688:1AD9  8B 36 E1 78       mov  si,[0x78e1]
C688:1ADD  46                inc  si
C688:1ADE  2B F1             sub  si,cx
C688:1AE0  73 14             jnc  C688:1AF6
...
C688:1AFC  A0 FF 79          mov  al,[0x79ff]
C688:1AFF  E8 29 21          call C688:3C2B
C688:1B02  A0 9A 79          mov  al,[0x799a]
C688:1B05  A8 02             test al,0x02
C688:1B07  74 08             jz   C688:1B11
C688:1B09  B0 0A             mov  al,0x0a
C688:1B0B  A2 45 77          mov  [0x7745],al
C688:1B0E  E8 57 21          call C688:3C68
C688:1B11  C3                ret
```

`C688:1B12` is a tiny predicate used by both viewport and redraw range paths. It
returns with flags from `[7717] bit 0` only when `[78D5] bit 0` is set; otherwise
it falls through to the shared zero return at `C688:1B11`.

```asm
editor_mode_bit_predicate_C688_1B12:
C688:1B12  A0 D5 78          mov  al,[0x78d5]
C688:1B15  A8 01             test al,0x01
C688:1B17  74 F8             jz   C688:1B11
C688:1B19  A0 17 77          mov  al,[0x7717]
C688:1B1C  A8 01             test al,0x01
C688:1B1E  C3                ret
```

`C688:1B41` snapshots the active editor-window bounds into the redraw state. It
also routes the current `[793E]` mode byte through `C688:61DB`, using `[75ED]`
as the destination state pointer.

```asm
snapshot_redraw_window_bounds_C688_1B41:
C688:1B41  A0 3E 79          mov  al,[0x793e]
C688:1B44  C7 06 ED 75 5C79  mov  word [0x75ed],0x795c
C688:1B4A  E8 8E 46          call C688:61DB
C688:1B4D  8B 36 FF 78       mov  si,[0x78ff]
C688:1B51  89 36 75 79       mov  [0x7975],si
C688:1B55  8B 36 FB 78       mov  si,[0x78fb]
C688:1B59  89 36 71 79       mov  [0x7971],si
C688:1B5D  8B 36 F5 78       mov  si,[0x78f5]
C688:1B61  89 36 73 79       mov  [0x7973],si
C688:1B65  A0 3D 79          mov  al,[0x793d]
C688:1B68  A2 5E 79          mov  [0x795e],al
C688:1B6B  A2 9A 79          mov  [0x799a],al
C688:1B6E  C3                ret
```

`C688:1B6F` appends one-byte `0xF0`, `0xF2`, ... mode markers into the scratch
buffer at `[79E2]` for each set bit in `[795E]`. Once all bits are consumed, it
compares `[795F]` with the last emitted mode in `[794E]`; a change appends the
`FF 04` position record through `C688:1A51`.

```asm
append_redraw_mode_markers_C688_1B6F:
C688:1B6F  A0 5E 79          mov  al,[0x795e]
C688:1B72  8B 36 E2 79       mov  si,[0x79e2]
C688:1B76  BA 28 7F          mov  dx,0x7f28
C688:1B79  2B F2             sub  si,dx
C688:1B7B  8B D6             mov  dx,si
C688:1B7D  8B 36 E2 79       mov  si,[0x79e2]
C688:1B81  B6 F0             mov  dh,0xf0
C688:1B83  0A C0             or   al,al
C688:1B85  74 13             jz   C688:1B9A
C688:1B87  A8 01             test al,0x01
C688:1B89  74 08             jz   C688:1B93
C688:1B8B  88 34             mov  [si],dh
C688:1B8D  FE C2             inc  dl
C688:1B8F  75 01             jnz  C688:1B92
C688:1B91  C3                ret
C688:1B92  46                inc  si
C688:1B93  D0 E8             shr  al,1
C688:1B95  80 C6 02          add  dh,0x02
C688:1B98  EB E9             jmp  C688:1B83
C688:1B9A  8B 16 4E 79       mov  dx,[0x794e]
C688:1B9E  A0 5F 79          mov  al,[0x795f]
C688:1BA1  3A C2             cmp  al,dl
C688:1BA3  74 03             jz   C688:1BA8
C688:1BA5  E8 A9 FE          call C688:1A51
C688:1BA8  C3                ret
```

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

`C688:39B5` and `C688:39BE` normalize `DL` redraw flag bits. The first helper
leaves values with bit `0x40` intact and otherwise masks `DL` down to the high
two bits. The second stores the unmasked `DX` in `[7969]`, primes `SI=79E0`,
and joins the same mask path.

```asm
normalize_redraw_flag_bits_C688_39B5:
; file 0x4A235
C688:39B5  F6 C2 40          test dl,0x40
C688:39B8  75 03             jnz  C688:39BD
C688:39BA  80 E2 C0          and  dl,0xc0
C688:39BD  C3                ret

save_and_normalize_redraw_flags_C688_39BE:
C688:39BE  BE E0 79          mov  si,0x79e0
C688:39C1  89 16 69 79       mov  [0x7969],dx
C688:39C5  EB F3             jmp  C688:39BA
```

`C688:61DB` is the mode-table helper shared by the redraw state code. It writes
the caller's `AL` to `[75ED]+3`, uses it as a byte index into the word table at
`C688:7118`, and stores the table high byte at `[75ED]+4`.

```asm
write_redraw_mode_table_byte_C688_61DB:
; file 0x4CA5B
C688:61DB  8B 1E ED 75       mov  bx,[0x75ed]
C688:61DF  88 87 0300        mov  [bx+0x0003],al
C688:61E3  8A D0             mov  dl,al
C688:61E5  B6 00             mov  dh,0
C688:61E7  8B F2             mov  si,dx
C688:61E9  81 C6 18 71       add  si,0x7118
C688:61ED  2E 8B 14          mov  dx,[cs:si]
C688:61F0  46                inc  si
C688:61F1  8A C6             mov  al,dh
C688:61F3  88 87 0400        mov  [bx+0x0004],al
C688:61F7  C3                ret
```

`C688:6B8C` measures the `7F28` scratch output and returns immediately if no
bytes were appended. Non-empty output is wrapped in the status fields consumed by
the `AH=06` renderer service at `C000:170E` through `C688:9364`. `C688:6BAA` is
the shared tail also reached by callers that have already prepared `[7727]`,
`[771D]`, and `[771B]`.

```asm
flush_redraw_scratch_to_renderer_C688_6B8C:
; file 0x4D40C
C688:6B8C  8B 36 E2 79       mov  si,[0x79e2]
C688:6B90  BA 28 7F          mov  dx,0x7f28
C688:6B93  32 C0             xor  al,al
C688:6B95  2B F2             sub  si,dx
C688:6B97  75 01             jnz  C688:6B9A
C688:6B99  C3                ret
C688:6B9A  89 36 27 77       mov  [0x7727],si
C688:6B9E  B0 0A             mov  al,0x0a
C688:6BA0  A2 1D 77          mov  [0x771d],al
C688:6BA3  BE 1F 77          mov  si,0x771f
C688:6BA6  89 36 1B 77       mov  [0x771b],si

renderer_service_tail_C688_6BAA:
C688:6BAA  BE 19 77          mov  si,0x7719
C688:6BAD  C7 06 EF 75 7977  mov  word [0x75ef],0x7779
C688:6BB3  8C DB             mov  bx,ds
C688:6BB5  B4 06             mov  ah,0x06
C688:6BB7  E8 AA 27          call C688:9364
C688:6BBA  C3                ret
```

## Redraw Span Utility Helpers

`C688:1A17` and `C688:1A24` are the stream-bound helpers used when the walker
loads the next source word. `C688:1A17` substitutes `[78ED]` when `DX` reaches
the `[78E9]` boundary. `C688:1A24` saves the source pointer in `[7967]`, derives
the active end in `[7963]` from `[79D5]`, and has a special `[78E7]`/`[78EF]`
case for extending the range before returning with `DX = [7969]`.

```asm
redraw_stream_boundary_compare_C688_1A17:
; file 0x48297
C688:1A17  8B 36 E9 78       mov  si,[0x78e9]
C688:1A1B  2B F2             sub  si,dx
C688:1A1D  75 04             jnz  C688:1A23
C688:1A1F  8B 16 ED 78       mov  dx,[0x78ed]
C688:1A23  C3                ret

redraw_stream_range_save_C688_1A24:
C688:1A24  89 16 67 79       mov  [0x7967],dx
C688:1A28  8B 36 D5 79       mov  si,[0x79d5]
C688:1A2C  03 F2             add  si,dx
C688:1A2E  89 36 63 79       mov  [0x7963],si
C688:1A32  8B 16 69 79       mov  dx,[0x7969]
C688:1A36  8B 36 E7 78       mov  si,[0x78e7]
C688:1A3A  2B F2             sub  si,dx
C688:1A3C  75 12             jnz  C688:1A50
C688:1A3E  8B 36 EF 78       mov  si,[0x78ef]
C688:1A42  8B 16 67 79       mov  dx,[0x7967]
C688:1A46  03 F2             add  si,dx
C688:1A48  89 36 63 79       mov  [0x7963],si
C688:1A4C  8B 16 69 79       mov  dx,[0x7969]
C688:1A50  C3                ret
```

`C688:1BA9` appends pending mode/span metadata around the scratch stream. In
wide-output mode (`[7990] != 0`) it first computes a width-adjusted span through
`C688:4239` and `C688:1C39`. It then mirrors mode bits from `[7988]` and
`[795E]` into marker bytes, emits an `FF 0E` span record for the distance
between `[7950]`, `[7952]`, and `[7979]`, and keeps `[79E2]` pointing at the
next scratch byte.

```asm
append_final_mode_span_markers_C688_1BA9:
; file 0x48429
C688:1BA9  A0 90 79          mov  al,[0x7990]
C688:1BAC  0A C0             or   al,al
C688:1BAE  74 22             jz   C688:1BD2
C688:1BB0  8B 36 16 79       mov  si,[0x7916]
C688:1BB4  E8 82 26          call C688:4239
C688:1BB7  8B 36 DB 78       mov  si,[0x78db]
C688:1BBB  03 F2             add  si,dx
C688:1BBD  8B 16 DD 78       mov  dx,[0x78dd]
C688:1BC1  2B F2             sub  si,dx
C688:1BC3  8B 36 16 79       mov  si,[0x7916]
C688:1BC7  72 06             jc   C688:1BCF
C688:1BC9  8B 16 DB 78       mov  dx,[0x78db]
C688:1BCD  2B F2             sub  si,dx
C688:1BCF  E8 67 00          call C688:1C39
C688:1BD2  B2 00             mov  dl,0
C688:1BD4  80 CA 02          or   dl,0x02
C688:1BD7  A0 88 79          mov  al,[0x7988]
C688:1BDA  22 C2             and  al,dl
C688:1BDC  9F                lahf
C688:1BDD  50                push ax
C688:1BDE  74 07             jz   C688:1BE7
C688:1BE0  E8 8F FF          call C688:1B72
C688:1BE3  89 36 E2 79       mov  [0x79e2],si
C688:1BE7  8B 36 52 79       mov  si,[0x7952]
C688:1BEB  8B 16 79 79       mov  dx,[0x7979]
C688:1BEF  2B F2             sub  si,dx
C688:1BF1  87 D6             xchg si,dx
C688:1BF3  73 02             jnc  C688:1BF7
C688:1BF5  03 F2             add  si,dx
C688:1BF7  8B 16 50 79       mov  dx,[0x7950]
C688:1BFB  2B F2             sub  si,dx
C688:1BFD  B6 0E             mov  dh,0x0e
C688:1BFF  E8 39 00          call C688:1C3B
C688:1C02  58                pop  ax
C688:1C03  9E                sahf
C688:1C04  A0 5E 79          mov  al,[0x795e]
C688:1C07  74 13             jz   C688:1C1C
C688:1C09  A8 02             test al,0x02
C688:1C0B  75 0D             jnz  C688:1C1A
C688:1C0D  8B 36 E2 79       mov  si,[0x79e2]
C688:1C11  C7 04 F300        mov  word [si],0x00f3
C688:1C15  46                inc  si
C688:1C16  89 36 E2 79       mov  [0x79e2],si
C688:1C1A  24 FD             and  al,0xfd
C688:1C1C  E8 53 FF          call C688:1B72
C688:1C1F  C3                ret
```

`C688:1C20` and `C688:1C39` are the generic `FF type lo hi` record writers.
`C688:1C20` skips zero-length spans and selects the record type from editor mode
bits. `C688:1C39` is the direct `0x0E` span entry used by final-output paths,
and `C688:1C47` is the shared append tail.

```asm
append_mode_dependent_span_record_C688_1C20:
C688:1C20  83 FE 00          cmp  si,0
C688:1C23  74 13             jz   C688:1C38
C688:1C25  A0 D5 78          mov  al,[0x78d5]
C688:1C28  A8 01             test al,0x01
C688:1C2A  B0 0E             mov  al,0x0e
C688:1C2C  74 07             jz   C688:1C35
C688:1C2E  A0 17 77          mov  al,[0x7717]
C688:1C31  24 02             and  al,0x02
C688:1C33  04 0E             add  al,0x0e
C688:1C35  E8 0F 00          call C688:1C47
C688:1C38  C3                ret

append_span_record_C688_1C39:
C688:1C39  B6 0E             mov  dh,0x0e
C688:1C3B  8B C6             mov  ax,si
C688:1C3D  0A E4             or   ah,ah
C688:1C3F  78 F7             js   C688:1C38
C688:1C41  0A E0             or   ah,al
C688:1C43  74 F3             jz   C688:1C38
C688:1C45  8A C6             mov  al,dh

append_span_record_tail_C688_1C47:
C688:1C47  87 D6             xchg si,dx
C688:1C49  8B 36 E2 79       mov  si,[0x79e2]
C688:1C4D  C6 04 FF          mov  byte [si],0xff
C688:1C50  46                inc  si
C688:1C51  88 04             mov  [si],al
C688:1C53  46                inc  si
C688:1C54  88 14             mov  [si],dl
C688:1C56  46                inc  si
C688:1C57  88 34             mov  [si],dh
C688:1C59  46                inc  si
C688:1C5A  89 36 E2 79       mov  [0x79e2],si
C688:1C5E  C3                ret
```

`C688:1C5F` derives a redraw distance from `[79F9]` and the active viewport
bounds. With `CL bit 0x10` set it also decrements `[7975]`, may reset `[7971]`
to `[7903]`, and chooses between `[78FD]+4` and `[7901]+[7907]` according to
the `C688:1B12` editor-mode predicate. `C688:1CA7` is the companion bound
normalizer used when no `CL bit 0x10` adjustment is needed.

```asm
redraw_cl10_distance_adjust_C688_1C5F:
; file 0x484DF
C688:1C5F  8B 16 F9 79       mov  dx,[0x79f9]
C688:1C63  F6 C1 10          test cl,0x10
C688:1C66  74 3F             jz   C688:1CA7
C688:1C68  8B 36 75 79       mov  si,[0x7975]
C688:1C6C  4E                dec  si
C688:1C6D  89 36 75 79       mov  [0x7975],si
C688:1C71  4E                dec  si
C688:1C72  83 FE 00          cmp  si,0
C688:1C75  75 0F             jnz  C688:1C86
C688:1C77  A0 2E 79          mov  al,[0x792e]
C688:1C7A  A8 80             test al,0x80
C688:1C7C  75 08             jnz  C688:1C86
C688:1C7E  8B 36 03 79       mov  si,[0x7903]
C688:1C82  89 36 71 79       mov  [0x7971],si
C688:1C86  A0 F8 79          mov  al,[0x79f8]
C688:1C89  8A F0             mov  dh,al
C688:1C8B  8B 36 01 79       mov  si,[0x7901]
C688:1C8F  E8 80 FE          call C688:1B12
C688:1C92  75 0A             jnz  C688:1C9E
C688:1C94  8B 36 FD 78       mov  si,[0x78fd]
C688:1C98  83 C6 04          add  si,0x04
C688:1C9B  2B F2             sub  si,dx
C688:1C9D  C3                ret
C688:1C9E  2B F2             sub  si,dx
C688:1CA0  8B 16 07 79       mov  dx,[0x7907]
C688:1CA4  03 F2             add  si,dx
C688:1CA6  C3                ret

normalize_redraw_bound_C688_1CA7:
C688:1CA7  E8 68 FE          call C688:1B12
C688:1CAA  75 19             jnz  C688:1CC5
C688:1CAC  8B 36 FD 78       mov  si,[0x78fd]
C688:1CB0  83 C6 02          add  si,0x02
C688:1CB3  2B F2             sub  si,dx
C688:1CB5  78 02             js   C688:1CB9
C688:1CB7  75 0B             jnz  C688:1CC4
C688:1CB9  87 D6             xchg si,dx
C688:1CBB  8B 36 FD 78       mov  si,[0x78fd]
C688:1CBF  83 C6 02          add  si,0x02
C688:1CC2  03 F2             add  si,dx
C688:1CC4  C3                ret
C688:1CC5  8B 36 01 79       mov  si,[0x7901]
C688:1CC9  2B F2             sub  si,dx
C688:1CCB  78 02             js   C688:1CCF
C688:1CCD  75 D1             jnz  C688:1CA0
C688:1CCF  8B 16 01 79       mov  dx,[0x7901]
C688:1CD3  03 F2             add  si,dx
C688:1CD5  EB C9             jmp  C688:1CA0
```

`C688:1CD7` advances `[79DB]`, optionally adjusts `[7979]` when the active
output cursor crosses `[7A41]`, and emits a final mode/span record when
`[79DF]` says the final-output path is active. `C688:1D4D` is a short final
return helper: it stores the current marker in `[793B]`, derives `[797F]` from
`[79F8]`/`[79F9]`, and, for `CL bit 0x08`, restores flags and jumps to the
direct final-span return at `C688:2310`.

```asm
redraw_active_cursor_advance_C688_1CD7:
; file 0x48557
C688:1CD7  8B 36 52 79       mov  si,[0x7952]
C688:1CDB  2B F2             sub  si,dx
C688:1CDD  87 D6             xchg si,dx
C688:1CDF  73 02             jnc  C688:1CE3
C688:1CE1  03 F2             add  si,dx
C688:1CE3  56                push si
C688:1CE4  8B 16 DB 79       mov  dx,[0x79db]
C688:1CE8  2B F2             sub  si,dx
C688:1CEA  5A                pop  dx
C688:1CEB  72 D7             jc   C688:1CC4
C688:1CED  74 D5             jz   C688:1CC4
C688:1CEF  56                push si
C688:1CF0  52                push dx
C688:1CF1  8B 36 DB 79       mov  si,[0x79db]
C688:1CF5  8B 16 41 7A       mov  dx,[0x7a41]
C688:1CF9  2B F2             sub  si,dx
C688:1CFB  5A                pop  dx
C688:1CFC  73 16             jnc  C688:1D14
C688:1CFE  8B 36 41 7A       mov  si,[0x7a41]
C688:1D02  2B F2             sub  si,dx
C688:1D04  72 0E             jc   C688:1D14
C688:1D06  5E                pop  si
C688:1D07  56                push si
C688:1D08  52                push dx
C688:1D09  8B 16 79 79       mov  dx,[0x7979]
C688:1D0D  03 F2             add  si,dx
C688:1D0F  89 36 79 79       mov  [0x7979],si
C688:1D13  5A                pop  dx
C688:1D14  5E                pop  si
C688:1D15  89 16 DB 79       mov  [0x79db],dx
C688:1D19  A0 DF 79          mov  al,[0x79df]
C688:1D1C  24 03             and  al,0x03
C688:1D1E  74 05             jz   C688:1D25
C688:1D20  FE C8             dec  al
C688:1D22  74 25             jz   C688:1D49
C688:1D24  C3                ret
C688:1D25  87 D6             xchg si,dx
C688:1D27  8B 16 50 79       mov  dx,[0x7950]
C688:1D2B  2B F2             sub  si,dx
C688:1D2D  72 1D             jc   C688:1D4C
C688:1D2F  8B 1E 79 79       mov  bx,[0x7979]
C688:1D33  2B DA             sub  bx,dx
C688:1D35  8B D3             mov  dx,bx
C688:1D37  72 02             jc   C688:1D3B
C688:1D39  2B F2             sub  si,dx
C688:1D3B  56                push si
C688:1D3C  E8 6A FE          call C688:1BA9
C688:1D3F  89 36 E2 79       mov  [0x79e2],si
C688:1D43  5E                pop  si
C688:1D44  B0 01             mov  al,0x01
C688:1D46  A2 DF 79          mov  [0x79df],al
C688:1D49  E8 D4 FE          call C688:1C20
C688:1D4C  C3                ret

redraw_final_marker_return_C688_1D4D:
C688:1D4D  BA 00 00          mov  dx,0
C688:1D50  A2 3B 79          mov  [0x793b],al
C688:1D53  A0 F8 79          mov  al,[0x79f8]
C688:1D56  3C 04             cmp  al,0x04
C688:1D58  75 0E             jnz  C688:1D68
C688:1D5A  8B 36 F9 79       mov  si,[0x79f9]
C688:1D5E  A8 80             test al,0x80
C688:1D60  75 06             jnz  C688:1D68
C688:1D62  B0 00             mov  al,0
C688:1D64  03 C6             add  ax,si
C688:1D66  03 C6             add  ax,si
C688:1D68  A2 7F 79          mov  [0x797f],al
C688:1D6B  F6 C1 08          test cl,0x08
C688:1D6E  74 DC             jz   C688:1D4C
C688:1D70  58                pop  ax
C688:1D71  9E                sahf
C688:1D72  E9 9B 05          jmp  C688:2310
```

## Redraw Stream Walker

`C688:1D75` is the viewport-facing wrapper around the common stream walker at
`C688:1D7D`. The wrapper saves the caller's `SI` and starts from saved
`DX = [796F]`; the internal loop can pop a replacement `DX` at `C688:1D7C`.

```asm
redraw_stream_wrapper_C688_1D75:
; file 0x485F5
C688:1D75  56                push si
C688:1D76  8B 16 6F 79       mov  dx,[0x796f]
C688:1D7A  EB 01             jmp  C688:1D7D
C688:1D7C  5A                pop  dx
```

The stream walker has two source modes. With `CL bit 0x40` set, `DX` is treated
as a pointer and a byte is read through `DS` or `ES` depending on `[824F] bit 0`.
Otherwise the byte comes from `ES:[795C + DX]`. When the cursor reaches
`[7963]`, the code pulls a new `DX` word from `ES:[7967 + 79D9]`, normalizes it
with `C688:39BE`, and loops through comparison helpers at `C688:1A24` and
`C688:1A17`.

```asm
redraw_stream_next_byte_C688_1D7D:
C688:1D7D  F6 C1 40          test cl,0x40
C688:1D80  74 17             jz   C688:1D99
C688:1D82  8B DA             mov  bx,dx
C688:1D84  1E                push ds
C688:1D85  56                push si
C688:1D86  F6 06 4F 82 01    test byte [0x824f],0x01
C688:1D8B  75 04             jnz  C688:1D91
C688:1D8D  8C C6             mov  si,es
C688:1D8F  8E DE             mov  ds,si
C688:1D91  8A 07             mov  al,[bx]
C688:1D93  5E                pop  si
C688:1D94  1F                pop  ds
C688:1D95  42                inc  dx
C688:1D96  E9 8E 00          jmp  C688:1E27
C688:1D99  8B 36 5C 79       mov  si,[0x795c]
C688:1D9D  03 F2             add  si,dx
C688:1D9F  26 8A 04          mov  al,[es:si]
C688:1DA2  87 D6             xchg si,dx
C688:1DA4  8B 36 63 79       mov  si,[0x7963]
C688:1DA8  2B F2             sub  si,dx
C688:1DAA  75 3F             jnz  C688:1DEB
C688:1DAC  8B 36 67 79       mov  si,[0x7967]
C688:1DB0  8B 16 D9 79       mov  dx,[0x79d9]
C688:1DB4  03 F2             add  si,dx
C688:1DB6  26 8B 14          mov  dx,[es:si]
C688:1DB9  46                inc  si
C688:1DBA  F6 C2 40          test dl,0x40
C688:1DBD  75 2E             jnz  C688:1DED
C688:1DBF  E8 FC 1B          call C688:39BE
C688:1DC2  8B 36 D7 79       mov  si,[0x79d7]
C688:1DC6  03 F2             add  si,dx
C688:1DC8  56                push si
C688:1DC9  E8 58 FC          call C688:1A24
C688:1DCC  E8 48 FC          call C688:1A17
C688:1DCF  5E                pop  si
C688:1DD0  75 CD             jnz  C688:1D9F
C688:1DD2  8B 36 F1 78       mov  si,[0x78f1]
C688:1DD6  F7 C6 8000        test si,0x0080
C688:1DDA  74 04             jz   C688:1DE0
C688:1DDC  81 CE 00FF        or   si,0xff00
C688:1DE0  03 F2             add  si,dx
C688:1DE2  87 D6             xchg si,dx
C688:1DE4  E8 6E 85          call C688:A355
C688:1DE7  74 94             jz   C688:1D7D
C688:1DE9  B0 40             mov  al,0x40
C688:1DEB  EB 3A             jmp  C688:1E27
```

The sentinel subpath records `0x1F` in `[793B]`, updates `DX` according to
`[795C]` and `CL bit 0x10`, and either exits to the common state-save tail at
`C688:1F45` or continues the long redraw path at `C688:1E0D`.

```asm
redraw_stream_sentinel_C688_1DED:
C688:1DED  B0 1F             mov  al,0x1f
C688:1DEF  A2 3B 79          mov  [0x793b],al
C688:1DF2  8B 36 63 79       mov  si,[0x7963]
C688:1DF6  8B 16 5C 79       mov  dx,[0x795c]
C688:1DFA  32 C0             xor  al,al
C688:1DFC  F6 C1 10          test cl,0x10
C688:1DFF  75 02             jnz  C688:1E03
C688:1E01  2B F2             sub  si,dx
C688:1E03  87 D6             xchg si,dx
C688:1E05  F6 C1 04          test cl,0x04
C688:1E08  75 03             jnz  C688:1E0D
C688:1E0A  E9 38 01          jmp  C688:1F45
C688:1E0D  F6 C1 10          test cl,0x10
C688:1E10  75 03             jnz  C688:1E15
C688:1E12  E9 30 01          jmp  C688:1F45
C688:1E15  5E                pop  si
C688:1E16  56                push si
C688:1E17  80 E1 FD          and  cl,0xfd
C688:1E1A  F7 C6 0080        test si,0x8000
C688:1E1E  89 36 F6 79       mov  [0x79f6],si
C688:1E22  75 65             jnz  C688:1E89
C688:1E24  E9 1E 01          jmp  C688:1F45
```

## Stream Byte Dispatch

`C688:1E27` is the common per-byte dispatcher reached after the stream walker has
loaded a byte into `AL` or synthesized one from a boundary condition. It saves the
current `DX`, mirrors the byte into `CH`, and routes three major cases:

- `CL bit 0x80` is the buffered-marker mode; it appends `CH` through
  `C688:1F7E`.
- `AL=0xFF` resets the stream source through `[7A13]` and `[824F]`.
- Other bytes are classified through `C688:2574`; nonzero classifier results
  leave this slice at `C688:21F4`.

```asm
redraw_stream_byte_dispatch_C688_1E27:
C688:1E27  52                push dx
C688:1E28  8A E8             mov  ch,al
C688:1E2A  F6 C1 80          test cl,0x80
C688:1E2D  74 03             jz   C688:1E32
C688:1E2F  E9 4C 01          jmp  C688:1F7E
C688:1E32  80 E1 FD          and  cl,0xfd
C688:1E35  3C FF             cmp  al,0xff
C688:1E37  75 1E             jnz  C688:1E57
C688:1E39  8B 16 13 7A       mov  dx,[0x7a13]
C688:1E3D  80 26 4F 82 FE    and  byte [0x824f],0xfe
C688:1E42  F6 C1 40          test cl,0x40
C688:1E45  75 09             jnz  C688:1E50
C688:1E47  C7 06 79 6D 321E  mov  word [0x6d79],0x1e32
C688:1E4D  E9 66 E3          jmp  C688:01B6
C688:1E50  80 E1 BF          and  cl,0xbf
C688:1E53  5E                pop  si
C688:1E54  E9 26 FF          jmp  C688:1D7D
C688:1E57  E8 1A 07          call C688:2574
C688:1E5A  0A C0             or   al,al
C688:1E5C  74 03             jz   C688:1E61
C688:1E5E  E9 93 03          jmp  C688:21F4
```

If the classifier returns zero, `[793B]` supplies the current stream marker
state. Without `CL bit 0x04`, the path leaves this slice at `C688:231C`. With
bit `0x04` set, marker bit `0x02` decides whether the stream loops immediately
or rebases the visible range.

```asm
redraw_classifier_zero_C688_1E61:
C688:1E61  A0 3B 79          mov  al,[0x793b]
C688:1E64  F6 C1 04          test cl,0x04
C688:1E67  75 03             jnz  C688:1E6C
C688:1E69  E9 B0 04          jmp  C688:231C
C688:1E6C  5A                pop  dx
C688:1E6D  A8 02             test al,0x02
C688:1E6F  75 03             jnz  C688:1E74
C688:1E71  E9 09 FF          jmp  C688:1D7D
C688:1E74  F6 C1 10          test cl,0x10
C688:1E77  75 03             jnz  C688:1E7C
C688:1E79  E9 92 00          jmp  C688:1F0E
```

The `CL bit 0x10` branch inspects the caller's saved `SI` on the stack. Negative
or zero ranges update `[79F6]` and fall through to the state-save tail; when
`CL bit 0x02` is set, the range source is switched to the `[7A19]`/`[7A17]`
snapshot and `[79FE]`.

```asm
redraw_positive_range_rebase_C688_1E7C:
C688:1E7C  5E                pop  si
C688:1E7D  56                push si
C688:1E7E  83 FE 00          cmp  si,0
C688:1E81  74 0A             jz   C688:1E8D
C688:1E83  F7 C6 0080        test si,0x8000
C688:1E87  74 23             jz   C688:1EAC
C688:1E89  89 36 F6 79       mov  [0x79f6],si
C688:1E8D  F6 C1 02          test cl,0x02
C688:1E90  75 03             jnz  C688:1E95
C688:1E92  E9 B0 00          jmp  C688:1F45
C688:1E95  8B 16 19 7A       mov  dx,[0x7a19]
C688:1E99  89 16 67 79       mov  [0x7967],dx
C688:1E9D  8B 16 17 7A       mov  dx,[0x7a17]
C688:1EA1  89 16 69 79       mov  [0x7969],dx
C688:1EA5  8B 16 FE 79       mov  dx,[0x79fe]
C688:1EA9  E9 99 00          jmp  C688:1F45
```

Positive ranges rebase `[7973]` using `[796B]`, `[7971]`, and either the
document/window limits `[78FD]` or `[7901]` depending on the `C688:1B12`
predicate. The path swaps the saved stack `SI` with the computed delta and
loops back to the stream walker.

```asm
redraw_visible_bound_rebase_C688_1EAC:
C688:1EAC  52                push dx
C688:1EAD  8B 36 73 79       mov  si,[0x7973]
C688:1EB1  8B 16 6B 79       mov  dx,[0x796b]
C688:1EB5  E8 5A FC          call C688:1B12
C688:1EB8  75 28             jnz  C688:1EE2
C688:1EBA  2B F2             sub  si,dx
C688:1EBC  79 0D             jns  C688:1ECB
C688:1EBE  8B 36 FD 78       mov  si,[0x78fd]
C688:1EC2  83 C6 04          add  si,0x04
C688:1EC5  2B F2             sub  si,dx
C688:1EC7  8B 16 6B 79       mov  dx,[0x796b]
C688:1ECB  8B 16 71 79       mov  dx,[0x7971]
C688:1ECF  2B F2             sub  si,dx
C688:1ED1  79 07             jns  C688:1EDA
C688:1ED3  8B 16 FD 78       mov  dx,[0x78fd]
C688:1ED7  83 C2 04          add  dx,0x04
C688:1EDA  03 F2             add  si,dx
C688:1EDC  8B 16 6B 79       mov  dx,[0x796b]
C688:1EE0  EB 0E             jmp  C688:1EF0
C688:1EE2  2B F2             sub  si,dx
C688:1EE4  79 0A             jns  C688:1EF0
C688:1EE6  8B 16 01 79       mov  dx,[0x7901]
C688:1EEA  03 F2             add  si,dx
C688:1EEC  8B 16 6B 79       mov  dx,[0x796b]
C688:1EF0  89 36 73 79       mov  [0x7973],si
C688:1EF4  5E                pop  si
C688:1EF5  8B EC             mov  bp,sp
C688:1EF7  87 76 00          xchg [bp+0x00],si
C688:1EFA  2B F2             sub  si,dx
C688:1EFC  8B EC             mov  bp,sp
C688:1EFE  87 76 00          xchg [bp+0x00],si
C688:1F01  87 D6             xchg si,dx
C688:1F03  8B 36 15 7A       mov  si,[0x7a15]
C688:1F07  89 36 6B 79       mov  [0x796b],si
C688:1F0B  E9 6F FE          jmp  C688:1D7D
```

The non-`CL bit 0x10` rebase is shorter. It adds `[796B]` to `[7973]`, rejects
zero/one-byte spans, and otherwise uses the same stack-swap loop. A zero or
one-byte span resets `[79F6]` before returning to the state-save tail.

```asm
redraw_short_range_rebase_C688_1F0E:
C688:1F0E  52                push dx
C688:1F0F  8B 36 73 79       mov  si,[0x7973]
C688:1F13  8B 16 6B 79       mov  dx,[0x796b]
C688:1F17  03 F2             add  si,dx
C688:1F19  89 36 73 79       mov  [0x7973],si
C688:1F1D  5E                pop  si
C688:1F1E  8B EC             mov  bp,sp
C688:1F20  87 76 00          xchg [bp+0x00],si
C688:1F23  2B F2             sub  si,dx
C688:1F25  74 0C             jz   C688:1F33
C688:1F27  72 0A             jc   C688:1F33
C688:1F29  8B C6             mov  ax,si
C688:1F2B  0A E4             or   ah,ah
C688:1F2D  75 CD             jnz  C688:1EFC
C688:1F2F  FE C8             dec  al
C688:1F31  75 C9             jnz  C688:1EFC
C688:1F33  BA 00 00          mov  dx,0
C688:1F36  87 D6             xchg si,dx
C688:1F38  2B F2             sub  si,dx
C688:1F3A  89 36 F6 79       mov  [0x79f6],si
C688:1F3E  8B EC             mov  bp,sp
C688:1F40  87 76 00          xchg [bp+0x00],si
C688:1F43  87 D6             xchg si,dx
```

`C688:1F45` is the common state-save exit. It records the current stream offset
in `[796F]`, reinitializes default span fields, lets `C688:1A24` compare or
normalize the saved `[7967]` source, then dispatches by `CL bit 0x20` and the
small state in `[79DF]`. The actual rendering exits at `C688:24C9`,
`C688:24CE`, and `C688:24F0` are documented later in this slice.

```asm
redraw_state_save_tail_C688_1F45:
C688:1F45  89 16 6F 79       mov  [0x796f],dx
C688:1F49  E8 E0 F9          call C688:192C
C688:1F4C  8B 16 67 79       mov  dx,[0x7967]
C688:1F50  E8 D1 FA          call C688:1A24
C688:1F53  32 C0             xor  al,al
C688:1F55  F6 C1 20          test cl,0x20
C688:1F58  74 03             jz   C688:1F5D
C688:1F5A  E9 6C 05          jmp  C688:24C9
C688:1F5D  A0 DF 79          mov  al,[0x79df]
C688:1F60  3C 02             cmp  al,0x02
C688:1F62  74 15             jz   C688:1F79
C688:1F64  0A C0             or   al,al
C688:1F66  75 08             jnz  C688:1F70
C688:1F68  8B 36 6F 79       mov  si,[0x796f]
C688:1F6C  56                push si
C688:1F6D  E9 5E 05          jmp  C688:24CE
C688:1F70  FE C8             dec  al
C688:1F72  75 05             jnz  C688:1F79
C688:1F74  32 C0             xor  al,al
C688:1F76  E9 77 05          jmp  C688:24F0
C688:1F79  32 C0             xor  al,al
C688:1F7B  E9 4B 05          jmp  C688:24C9
```

## Buffered Marker Dispatch

`C688:1F7E` is entered when `CL bit 0x80` is set. It appends `CH` to the buffer
at `[75EF]`, decrements `[7956]`, and loops until the count reaches zero. The
next byte from `C688:A378` selects compact marker handlers for `0xEE`, `0xE8`,
`0xEF`, `0xED`, `0xE9`, `0xEC`, and `0xE7`.

```asm
buffered_marker_dispatch_C688_1F7E:
C688:1F7E  8B 1E EF 75       mov  bx,[0x75ef]
C688:1F82  88 2F             mov  [bx],ch
C688:1F84  FF 06 EF 75       inc  word [0x75ef]
C688:1F88  BE 56 79          mov  si,0x7956
C688:1F8B  FE 0C             dec  byte [si]
C688:1F8D  74 03             jz   C688:1F92
C688:1F8F  E9 EA FD          jmp  C688:1D7C
C688:1F92  80 E1 7F          and  cl,0x7f
C688:1F95  E8 E0 83          call C688:A378
C688:1F98  3C EE             cmp  al,0xee
C688:1F9A  75 03             jnz  C688:1F9F
C688:1F9C  E9 38 02          jmp  C688:21D7
C688:1F9F  3C E8             cmp  al,0xe8
C688:1FA1  75 03             jnz  C688:1FA6
C688:1FA3  E9 F5 00          jmp  C688:209B
C688:1FA6  3C EF             cmp  al,0xef
C688:1FA8  74 03             jz   C688:1FAD
C688:1FAA  E9 D2 00          jmp  C688:207F
```

Marker `0xEF` either resumes scanning, copies `[79FA]` into `[79F8]` and
recomputes a range via `C688:1C5F`, or falls into the marker-`0x04` width clamp.
The marker-`0x04` path sets `[793B]=0xCB`, marks `[797F]=0xFF`, and derives
`[796B]` from `[7973]`, `[79F6]`, `[78FD]`, `[7907]`, and `[79F9]`.

```asm
marker_ef_or_width_clamp_C688_1FAD:
C688:1FAD  A0 F8 79          mov  al,[0x79f8]
C688:1FB0  F6 C1 10          test cl,0x10
C688:1FB3  74 03             jz   C688:1FB8
C688:1FB5  A0 FC 79          mov  al,[0x79fc]
C688:1FB8  3C 06             cmp  al,0x06
C688:1FBA  75 2A             jnz  C688:1FE6
C688:1FBC  A0 A1 79          mov  al,[0x79a1]
C688:1FBF  A8 01             test al,0x01
C688:1FC1  74 03             jz   C688:1FC6
C688:1FC3  E9 B6 FD          jmp  C688:1D7C
C688:1FC6  F6 C1 10          test cl,0x10
C688:1FC9  75 03             jnz  C688:1FCE
C688:1FCB  E9 AE FD          jmp  C688:1D7C
C688:1FCE  8B 36 FA 79       mov  si,[0x79fa]
C688:1FD2  89 36 F8 79       mov  [0x79f8],si
C688:1FD6  E8 86 FC          call C688:1C5F
C688:1FD9  8B 16 6B 79       mov  dx,[0x796b]
C688:1FDD  03 F2             add  si,dx
C688:1FDF  89 36 6B 79       mov  [0x796b],si
C688:1FE3  E9 96 FD          jmp  C688:1D7C
C688:1FE6  F6 C1 10          test cl,0x10
C688:1FE9  75 63             jnz  C688:204E
C688:1FEB  3C 04             cmp  al,0x04
C688:1FED  75 79             jnz  C688:2068
C688:1FEF  C6 06 3B 79 CB    mov  byte [0x793b],0xcb
C688:1FF4  B0 FF             mov  al,0xff
C688:1FF6  A2 7F 79          mov  [0x797f],al
C688:1FF9  BA 00 00          mov  dx,0
C688:1FFC  F6 C1 08          test cl,0x08
C688:1FFF  74 03             jz   C688:2004
C688:2001  E9 0C 03          jmp  C688:2310
C688:2004  A0 A1 79          mov  al,[0x79a1]
C688:2007  A8 01             test al,0x01
C688:2009  74 03             jz   C688:200E
C688:200B  EB 36             jmp  C688:2043
C688:200E  8B 16 73 79       mov  dx,[0x7973]
C688:2012  8B 36 F6 79       mov  si,[0x79f6]
C688:2016  03 F2             add  si,dx
C688:2018  8B 16 FD 78       mov  dx,[0x78fd]
C688:201C  2B F2             sub  si,dx
C688:201E  78 06             js   C688:2026
C688:2020  8B 36 07 79       mov  si,[0x7907]
C688:2024  EB 02             jmp  C688:2028
C688:2026  03 F2             add  si,dx
C688:2028  87 D6             xchg si,dx
C688:202A  8B 36 F9 79       mov  si,[0x79f9]
C688:202E  2B F2             sub  si,dx
C688:2030  BA 02 00          mov  dx,0x0002
C688:2033  2B F2             sub  si,dx
C688:2035  79 03             jns  C688:203A
C688:2037  BE 00 00          mov  si,0
C688:203A  03 F2             add  si,dx
C688:203C  89 36 6B 79       mov  [0x796b],si
C688:2040  80 C9 02          or   cl,0x02
C688:2043  B0 CB             mov  al,0xcb
C688:2045  A2 3B 79          mov  [0x793b],al
C688:2048  BA 00 00          mov  dx,0
C688:204B  E9 13 FE          jmp  C688:1E61
```

The `CL bit 0x10` variant of the same marker-`0x04` path byte-swaps `[79FA]`
and `[79F8]` before entering the shared width clamp. Non-`0x04` values are saved
as `[796D]`, with `[79F8]` byte-swapped when `CL bit 0x10` is set.

```asm
marker_width_clamp_alt_C688_204E:
C688:204E  3C 04             cmp  al,0x04
C688:2050  75 16             jnz  C688:2068
C688:2052  A0 A1 79          mov  al,[0x79a1]
C688:2055  A8 01             test al,0x01
C688:2057  75 EA             jnz  C688:2043
C688:2059  A1 FA 79          mov  ax,[0x79fa]
C688:205C  8B 16 F8 79       mov  dx,[0x79f8]
C688:2060  86 E0             xchg al,ah
C688:2062  8B F0             mov  si,ax
C688:2064  86 F2             xchg dl,dh
C688:2066  EB C6             jmp  C688:202E

marker_saved_span_C688_2068:
C688:2068  8B 36 F9 79       mov  si,[0x79f9]
C688:206C  F6 C1 10          test cl,0x10
C688:206F  74 07             jz   C688:2078
C688:2071  A1 F8 79          mov  ax,[0x79f8]
C688:2074  86 E0             xchg al,ah
C688:2076  8B F0             mov  si,ax
C688:2078  89 36 6D 79       mov  [0x796d],si
C688:207C  E9 FD FC          jmp  C688:1D7C
```

The remaining compact markers update saved span fields and loop. `0xED` selects
`[796B]`/`[7A15]`, `0xE8` updates `[7961]`, `0xE9` dispatches through a small
inline jump table, and `0xEC` either writes mode-table state through `C688:61DB`
or appends a position record through `C688:1A51`. Marker `0xEE` enters the next
larger path at `C688:21D7`.

```asm
marker_misc_dispatch_C688_207F:
C688:207F  3C ED             cmp  al,0xed
C688:2081  75 53             jnz  C688:20D6
C688:2083  A0 F8 79          mov  al,[0x79f8]
C688:2086  8B 36 A1 79       mov  si,[0x79a1]
C688:208A  F7 C6 0100        test si,0x0001
C688:208E  74 02             jz   C688:2092
C688:2090  B0 02             mov  al,0x02
C688:2092  A2 6B 79          mov  [0x796b],al
C688:2095  A2 15 7A          mov  [0x7a15],al
C688:2098  E9 E1 FC          jmp  C688:1D7C

marker_e8_saved_start_C688_209B:
C688:209B  8B 36 F8 79       mov  si,[0x79f8]
C688:209F  F6 C1 10          test cl,0x10
C688:20A2  74 06             jz   C688:20AA
C688:20A4  8B C6             mov  ax,si
C688:20A6  86 E0             xchg al,ah
C688:20A8  8B F0             mov  si,ax
C688:20AA  89 36 61 79       mov  [0x7961],si
C688:20AE  E9 CB FC          jmp  C688:1D7C

marker_e9_jump_table_C688_20D6:
C688:20D6  3C E9             cmp  al,0xe9
C688:20D8  74 03             jz   C688:20DD
C688:20DA  E9 CD 00          jmp  C688:21AA
C688:20DD  8B 36 F8 79       mov  si,[0x79f8]
C688:20E1  F6 C1 10          test cl,0x10
C688:20E4  74 04             jz   C688:20EA
C688:20E6  8B 36 FA 79       mov  si,[0x79fa]
C688:20EA  81 E6 FF00        and  si,0x00ff
C688:20EE  BA F5 20          mov  dx,0x20f5
C688:20F1  03 F2             add  si,dx
C688:20F3  FF E6             jmp  si
C688:20F5  EB 59             jmp  C688:2150
C688:20F7  EB 5F             jmp  C688:2158
C688:20F9  EB 1F             jmp  C688:211A
C688:20FB  EB 16             jmp  C688:2113
...
C688:210F  EB A0             jmp  C688:20B1
C688:2111  EB 3D             jmp  C688:2150
C688:2113  B0 DF             mov  al,0xdf
C688:2115  8A E8             mov  ch,al
C688:2117  E9 3D FD          jmp  C688:1E57
```

Two jump-table cases either redraw a mode-dependent range with `[75ED]`
temporarily pointing at `[7A0F]`, or synthesize marker `0xD6` after recalculating
a span. Both return to the stream loop unless `CL bit 0x08` requests the deeper
exit at `C688:2310`.

```asm
marker_e9_table_cases_C688_211A:
C688:211A  A0 D5 78          mov  al,[0x78d5]
C688:211D  A8 10             test al,0x10
C688:211F  74 2F             jz   C688:2150
C688:2121  A0 9C 79          mov  al,[0x799c]
C688:2124  3C 04             cmp  al,0x04
C688:2126  74 28             jz   C688:2150
C688:2128  F6 C1 10          test cl,0x10
C688:212B  75 28             jnz  C688:2155
C688:212D  C7 06 ED 75 0F7A  mov  word [0x75ed],0x7a0f
C688:2133  8B 36 77 79       mov  si,[0x7977]
C688:2137  8B 16 F9 79       mov  dx,[0x79f9]
C688:213B  03 F2             add  si,dx
C688:213D  8B 16 0F 79       mov  dx,[0x790f]
C688:2141  4A                dec  dx
C688:2142  03 F2             add  si,dx
C688:2144  E8 02 EE          call C688:0F49
C688:2147  C7 06 ED 75 5C79  mov  word [0x75ed],0x795c
C688:214D  E9 2D FC          jmp  C688:1D7D
C688:2150  32 C0             xor  al,al
C688:2152  E8 F8 FB          call C688:1D4D
C688:2155  E9 24 FC          jmp  C688:1D7C

marker_e9_span_case_C688_2158:
C688:2158  F6 C1 10          test cl,0x10
C688:215B  75 1D             jnz  C688:217A
C688:215D  8B 16 73 79       mov  dx,[0x7973]
C688:2161  8B 36 F6 79       mov  si,[0x79f6]
C688:2165  03 F2             add  si,dx
C688:2167  87 D6             xchg si,dx
C688:2169  8B 36 FD 78       mov  si,[0x78fd]
C688:216D  2B F2             sub  si,dx
C688:216F  79 04             jns  C688:2175
C688:2171  8B 16 01 79       mov  dx,[0x7901]
C688:2175  E8 2F FB          call C688:1CA7
C688:2178  EB 03             jmp  C688:217D
C688:217A  E8 E2 FA          call C688:1C5F
C688:217D  80 C9 02          or   cl,0x02
C688:2180  B5 D6             mov  ch,0xd6
C688:2182  A0 A1 79          mov  al,[0x79a1]
C688:2185  A8 01             test al,0x01
C688:2187  74 03             jz   C688:218C
C688:2189  EB 0A             jmp  C688:2195
C688:218C  F6 C1 08          test cl,0x08
C688:218F  75 04             jnz  C688:2195
C688:2191  89 36 6B 79       mov  [0x796b],si
C688:2195  8A C5             mov  al,ch
C688:2197  E8 DA 03          call C688:2574
C688:219A  B0 CB             mov  al,0xcb
C688:219C  A2 3B 79          mov  [0x793b],al
C688:219F  F6 C1 08          test cl,0x08
C688:21A2  75 03             jnz  C688:21A7
C688:21A4  E9 BA FC          jmp  C688:1E61
C688:21A7  E9 66 01          jmp  C688:2310
```

The late marker pair handles `0xE7` and `0xEC`. `0xE7` calls `C688:1286` and
loops; `0xEC` either updates the current mode table through `C688:61DB` when
`CL bit 0x20` is set, or appends a scratch-stream position record and stores the
new pointer back to `[79E2]`.

```asm
marker_ec_e7_dispatch_C688_21AA:
C688:21AA  3C EC             cmp  al,0xec
C688:21AC  74 0D             jz   C688:21BB
C688:21AE  3C E7             cmp  al,0xe7
C688:21B0  74 03             jz   C688:21B5
C688:21B2  E9 C7 FB          jmp  C688:1D7C
C688:21B5  E8 CE F0          call C688:1286
C688:21B8  E9 C1 FB          jmp  C688:1D7C
C688:21BB  A0 F8 79          mov  al,[0x79f8]
C688:21BE  F6 C1 20          test cl,0x20
C688:21C1  74 06             jz   C688:21C9
C688:21C3  E8 15 40          call C688:61DB
C688:21C6  E9 B3 FB          jmp  C688:1D7C
C688:21C9  8B 36 E2 79       mov  si,[0x79e2]
C688:21CD  E8 81 F8          call C688:1A51
C688:21D0  89 36 E2 79       mov  [0x79e2],si
C688:21D4  E9 A5 FB          jmp  C688:1D7C

marker_ee_boundary_C688_21D7:
C688:21D7  E8 22 45          call C688:66FC
C688:21DA  F6 C1 08          test cl,0x08
C688:21DD  74 03             jz   C688:21E2
C688:21DF  E9 2E 01          jmp  C688:2310
C688:21E2  F6 C1 04          test cl,0x04
C688:21E5  74 03             jz   C688:21EA
C688:21E7  E9 92 FB          jmp  C688:1D7C
C688:21EA  8B 16 F8 79       mov  dx,[0x79f8]
C688:21EE  E8 E6 FA          call C688:1CD7
C688:21F1  E9 88 FB          jmp  C688:1D7C
```

## Classifier-Specific Paths

`C688:21F4` is reached when `C688:2574` returns a nonzero classifier value. The
special classifier value `0x70` either starts a buffered read into `[79F8]` or
handles a small marker set (`0x1F`, `0x1E`, `0xD1`). The buffered-read setup
stores the remaining count in `[7956]`, points `[75EF]` at `[79F8]`, sets
`CL bit 0x80`, snapshots `[7967]`/`[7969]` into `[7A19]`/`[7A17]`, saves the
current stream position in `[79FE]`, and loops to the stream walker.

```asm
classifier_70_buffer_setup_C688_21F4:
; file 0x48A74
C688:21F4  3C 70             cmp  al,0x70
C688:21F6  75 5C             jnz  C688:2254
C688:21F8  89 16 56 79       mov  [0x7956],dx
C688:21FC  83 FA 00          cmp  dx,0
C688:21FF  74 03             jz   C688:2204
C688:2201  EB 30             jmp  C688:2233
C688:2204  B0 1F             mov  al,0x1f
C688:2206  3A C5             cmp  al,ch
C688:2208  74 06             jz   C688:2210
C688:220A  B0 1E             mov  al,0x1e
C688:220C  3A C5             cmp  al,ch
C688:220E  75 0B             jnz  C688:221B
C688:2210  F6 C1 10          test cl,0x10
C688:2213  75 03             jnz  C688:2218
C688:2215  E9 67 81          jmp  C688:A37F
C688:2218  E9 61 FB          jmp  C688:1D7C
C688:221B  B0 D1             mov  al,0xd1
C688:221D  3A C5             cmp  al,ch
C688:221F  74 03             jz   C688:2224
C688:2221  E9 58 FB          jmp  C688:1D7C
C688:2224  E8 2E 81          call C688:A355
C688:2227  75 03             jnz  C688:222C
C688:2229  E9 50 FB          jmp  C688:1D7C
C688:222C  B0 D7             mov  al,0xd7
C688:222E  8A E8             mov  ch,al
C688:2230  E9 24 FC          jmp  C688:1E57
C688:2233  C7 06 EF 75 F879  mov  word [0x75ef],0x79f8
C688:2239  80 C9 80          or   cl,0x80
C688:223C  8B 16 67 79       mov  dx,[0x7967]
C688:2240  89 16 19 7A       mov  [0x7a19],dx
C688:2244  8B 16 69 79       mov  dx,[0x7969]
C688:2248  89 16 17 7A       mov  [0x7a17],dx
C688:224C  5A                pop  dx
C688:224D  89 16 FE 79       mov  [0x79fe],dx
C688:2251  E9 29 FB          jmp  C688:1D7D
```

`C688:2254` is the larger classifier path. It calls `C688:A494`, optionally
marks `[79EC] bit 0x40` when an `0xEA`/`0xEB`-class byte matches `[7999]` but
the current position differs from `[78F3]`, then refreshes the mode byte at
`[795E]` through `C688:626D`. If mode bit `0x04` changed, it clears the
`[7909]`/`[790A]` span cache.

```asm
classifier_general_path_C688_2254:
C688:2254  E8 3D 82          call C688:A494
C688:2257  9F                lahf
C688:2258  50                push ax
C688:2259  8A C5             mov  al,ch
C688:225B  24 FE             and  al,0xfe
C688:225D  3C EA             cmp  al,0xea
C688:225F  75 27             jnz  C688:2288
C688:2261  A0 0E 79          mov  al,[0x790e]
C688:2264  3C 01             cmp  al,0x01
C688:2266  8A C5             mov  al,ch
C688:2268  75 1E             jnz  C688:2288
C688:226A  A0 99 79          mov  al,[0x7999]
C688:226D  3A C5             cmp  al,ch
C688:226F  8A C5             mov  al,ch
C688:2271  75 15             jnz  C688:2288
C688:2273  8B 16 F3 78       mov  dx,[0x78f3]
C688:2277  8B 36 DB 79       mov  si,[0x79db]
C688:227B  2B F2             sub  si,dx
C688:227D  74 06             jz   C688:2285
C688:227F  BE EC 79          mov  si,0x79ec
C688:2282  80 0C 40          or   byte [si],0x40
C688:2285  E8 4F FA          call C688:1CD7
C688:2288  58                pop  ax
C688:2289  9E                sahf
C688:228A  BE 5E 79          mov  si,0x795e
C688:228D  8A 14             mov  dl,[si]
C688:228F  52                push dx
C688:2290  E8 DA 3F          call C688:626D
C688:2293  5A                pop  dx
C688:2294  8A C2             mov  al,dl
C688:2296  F6 D0             not  al
C688:2298  22 04             and  al,[si]
C688:229A  A8 04             test al,0x04
C688:229C  74 08             jz   C688:22A6
C688:229E  32 C0             xor  al,al
C688:22A0  A2 09 79          mov  [0x7909],al
C688:22A3  A2 0A 79          mov  [0x790a],al
```

After the mode refresh, the path only proceeds when `[79DF] == 1`. With
`CL bit 0x08` set, a newly set mode bit `0x04` exits through `C688:2314`.
Otherwise, if `CL bit 0x20` is clear and `[793B]` is nonzero, the byte in `CH`
is converted into a compact `0xF2`/`0xF3`-class marker before entering the
final-output path at `C688:23FF`.

```asm
classifier_mode_gate_C688_22A6:
C688:22A6  A0 DF 79          mov  al,[0x79df]
C688:22A9  FE C8             dec  al
C688:22AB  74 03             jz   C688:22B0
C688:22AD  E9 CC FA          jmp  C688:1D7C
C688:22B0  F6 C1 08          test cl,0x08
C688:22B3  74 0A             jz   C688:22BF
C688:22B5  8A 04             mov  al,[si]
C688:22B7  32 C2             xor  al,dl
C688:22B9  22 C2             and  al,dl
C688:22BB  A8 04             test al,0x04
C688:22BD  75 55             jnz  C688:2314
C688:22BF  F6 C1 20          test cl,0x20
C688:22C2  74 03             jz   C688:22C7
C688:22C4  E9 B5 FA          jmp  C688:1D7C
C688:22C7  BE 3B 79          mov  si,0x793b
C688:22CA  8A 04             mov  al,[si]
C688:22CC  C6 04 00          mov  byte [si],0
C688:22CF  0A C0             or   al,al
C688:22D1  75 03             jnz  C688:22D6
C688:22D3  E9 A6 FA          jmp  C688:1D7C
C688:22D6  8A C5             mov  al,ch
C688:22D8  24 FE             and  al,0xfe
C688:22DA  3C EA             cmp  al,0xea
C688:22DC  8A C5             mov  al,ch
C688:22DE  74 07             jz   C688:22E7
C688:22E0  72 03             jc   C688:22E5
C688:22E2  E9 1A 01          jmp  C688:23FF
C688:22E5  D0 D8             rcr  al,1
C688:22E7  24 01             and  al,0x01
C688:22E9  04 F2             add  al,0xf2
C688:22EB  8A E8             mov  ch,al
C688:22ED  E9 0F 01          jmp  C688:23FF
```

## Final Span And Output Paths

`C688:22F0`, `C688:2310`, and `C688:231C` are the final span/return gates. The
`CL bit 0x08` detour compares the cached span in `[7909]` against `DX`; if it
can advance cleanly it falls back into the stream loop through `C688:1D7C`,
otherwise it uses the direct `C688:2310` return. The direct `C688:2310` path
records `DX` in `[7909]`, unwinds the saved `SI` frames, stores the current
output byte in `[7F25]`, and returns. The `C688:231C` path updates `[7909]`,
adjusts `[7988]` when needed, and either loops, emits through the final-output
path, or exits through the final render tails.

```asm
redraw_cl08_span_cache_C688_22F0:
; file 0x48B70
C688:22F0  A0 5E 79          mov  al,[0x795e]
C688:22F3  A8 04             test al,0x04
C688:22F5  75 03             jnz  C688:22FA
C688:22F7  EB 17             jmp  C688:2310
C688:22F9  90                nop
C688:22FA  8B 36 09 79       mov  si,[0x7909]
C688:22FE  87 D6             xchg si,dx
C688:2300  2B F2             sub  si,dx
C688:2302  73 03             jnc  C688:2307
C688:2304  E9 75 FA          jmp  C688:1D7C
C688:2307  03 F2             add  si,dx
C688:2309  89 36 09 79       mov  [0x7909],si
C688:230D  E9 6C FA          jmp  C688:1D7C

redraw_direct_span_return_C688_2310:
C688:2310  89 16 09 79       mov  [0x7909],dx
C688:2314  5E                pop  si
C688:2315  5E                pop  si
C688:2316  8A C5             mov  al,ch
C688:2318  A2 25 7F          mov  [0x7f25],al
C688:231B  C3                ret

redraw_final_span_gate_C688_231C:
C688:231C  F6 C1 08          test cl,0x08
C688:231F  75 CF             jnz  C688:22F0
C688:2321  A0 5E 79          mov  al,[0x795e]
C688:2324  A8 04             test al,0x04
C688:2326  74 17             jz   C688:233F
C688:2328  8B 36 09 79       mov  si,[0x7909]
C688:232C  87 D6             xchg si,dx
C688:232E  2B F2             sub  si,dx
C688:2330  72 0A             jc   C688:233C
C688:2332  87 D6             xchg si,dx
C688:2334  03 F2             add  si,dx
C688:2336  89 36 09 79       mov  [0x7909],si
C688:233A  EB 03             jmp  C688:233F
C688:233C  BA 00 00          mov  dx,0
C688:233F  8B 36 3B 79       mov  si,[0x793b]
C688:2343  F7 C6 0200        test si,0x0002
C688:2347  74 0D             jz   C688:2356
C688:2349  A0 DF 79          mov  al,[0x79df]
C688:234C  0A C0             or   al,al
C688:234E  74 42             jz   C688:2392
C688:2350  A0 5E 79          mov  al,[0x795e]
C688:2353  A2 88 79          mov  [0x7988],al
```

If `CH >= 0xE0` and `[79A1] bit 0x10` is set, the byte is rewritten to `0xC0`
and reclassified. Otherwise `[79DF]` controls whether the path loops, clears
`[79DF]`, or enters the active-output builder.

```asm
redraw_final_state_gate_C688_2356:
C688:2356  8A C5             mov  al,ch
C688:2358  3C E0             cmp  al,0xe0
C688:235A  72 0E             jc   C688:236A
C688:235C  A0 A1 79          mov  al,[0x79a1]
C688:235F  A8 10             test al,0x10
C688:2361  74 07             jz   C688:236A
C688:2363  B5 C0             mov  ch,0xc0
C688:2365  8A C5             mov  al,ch
C688:2367  E9 ED FA          jmp  C688:1E57
C688:236A  A0 DF 79          mov  al,[0x79df]
C688:236D  3C 02             cmp  al,0x02
C688:236F  74 16             jz   C688:2387
C688:2371  0A C0             or   al,al
C688:2373  74 1D             jz   C688:2392
C688:2375  79 7E             jns  C688:23F5
C688:2377  F7 C6 0200        test si,0x0002
C688:237B  75 02             jnz  C688:237F
C688:237D  EB 05             jmp  C688:2384
C688:237F  32 C0             xor  al,al
C688:2381  A2 DF 79          mov  [0x79df],al
C688:2384  E9 F5 F9          jmp  C688:1D7C
C688:2387  F7 C6 0200        test si,0x0002
C688:238B  74 F7             jz   C688:2384
C688:238D  32 C0             xor  al,al
C688:238F  E9 32 01          jmp  C688:24C4
```

The active-output builder advances `[79DB]`, clamps it against `[7950]` and
`[7952]`, and uses `C688:1BA9` to append mode markers. It writes `CH` to the
scratch stream unless marker bits redirect to the final tails.

```asm
redraw_active_output_builder_C688_2392:
C688:2392  8B C6             mov  ax,si
C688:2394  8B 36 DB 79       mov  si,[0x79db]
C688:2398  56                push si
C688:2399  03 F2             add  si,dx
C688:239B  89 36 DB 79       mov  [0x79db],si
C688:239F  4E                dec  si
C688:23A0  8B 16 50 79       mov  dx,[0x7950]
C688:23A4  2B F2             sub  si,dx
C688:23A6  5E                pop  si
C688:23A7  79 07             jns  C688:23B0
C688:23A9  A8 02             test al,0x02
C688:23AB  74 D7             jz   C688:2384
C688:23AD  E9 1E 01          jmp  C688:24CE
C688:23B0  A8 02             test al,0x02
C688:23B2  74 0D             jz   C688:23C1
C688:23B4  8A C5             mov  al,ch
C688:23B6  3C DB             cmp  al,0xdb
C688:23B8  74 07             jz   C688:23C1
C688:23BA  3C D6             cmp  al,0xd6
C688:23BC  74 03             jz   C688:23C1
C688:23BE  E9 0D 01          jmp  C688:24CE
C688:23C1  87 D6             xchg si,dx
C688:23C3  32 C0             xor  al,al
C688:23C5  2B F2             sub  si,dx
C688:23C7  72 02             jc   C688:23CB
C688:23C9  8B C6             mov  ax,si
C688:23CB  A2 2B 77          mov  [0x772b],al
C688:23CE  8B 36 52 79       mov  si,[0x7952]
C688:23D2  2B F2             sub  si,dx
C688:23D4  9F                lahf
C688:23D5  50                push ax
C688:23D6  B0 01             mov  al,0x01
C688:23D8  A2 DF 79          mov  [0x79df],al
C688:23DB  E8 CB F7          call C688:1BA9
C688:23DE  58                pop  ax
C688:23DF  9E                sahf
C688:23E0  73 21             jnc  C688:2403
C688:23E2  B0 02             mov  al,0x02
C688:23E4  89 36 E2 79       mov  [0x79e2],si
C688:23E8  8B 36 3B 79       mov  si,[0x793b]
C688:23EC  F7 C6 0200        test si,0x0002
C688:23F0  74 8F             jz   C688:2381
C688:23F2  E9 F4 00          jmp  C688:24E9
C688:23F5  8B 36 DB 79       mov  si,[0x79db]
C688:23F9  03 F2             add  si,dx
C688:23FB  89 36 DB 79       mov  [0x79db],si
C688:23FF  8B 36 E2 79       mov  si,[0x79e2]
C688:2403  A0 3B 79          mov  al,[0x793b]
C688:2406  A8 08             test al,0x08
C688:2408  74 0B             jz   C688:2415
C688:240A  A0 EC 79          mov  al,[0x79ec]
C688:240D  A8 40             test al,0x40
C688:240F  74 0B             jz   C688:241C
C688:2411  B5 20             mov  ch,0x20
C688:2413  EB 07             jmp  C688:241C
C688:2415  A8 02             test al,0x02
C688:2417  74 03             jz   C688:241C
C688:2419  E9 C9 00          jmp  C688:24E5
C688:241C  88 2C             mov  [si],ch
C688:241E  46                inc  si
C688:241F  89 36 E2 79       mov  [0x79e2],si
```

After writing `CH`, the code may append an `FE len byte` record if `[79DB]`
crossed `[7952]`. Small scratch streams can continue looping; larger or
ambiguous streams set `[790D] bit 0x40`, save `CL` in `[7A60]`, and return to
the viewport caller for a redraw pass.

```asm
redraw_output_length_gate_C688_2423:
C688:2423  8B 36 DB 79       mov  si,[0x79db]
C688:2427  8B 16 52 79       mov  dx,[0x7952]
C688:242B  32 C0             xor  al,al
C688:242D  2B F2             sub  si,dx
C688:242F  74 28             jz   C688:2459
C688:2431  72 28             jc   C688:245B
C688:2433  8B DE             mov  bx,si
C688:2435  8A D3             mov  dl,bl
C688:2437  8B 36 E2 79       mov  si,[0x79e2]
C688:243B  4E                dec  si
C688:243C  A0 5E 79          mov  al,[0x795e]
C688:243F  A8 04             test al,0x04
C688:2441  74 08             jz   C688:244B
C688:2443  4E                dec  si
C688:2444  8A 04             mov  al,[si]
C688:2446  3C F4             cmp  al,0xf4
C688:2448  75 0F             jnz  C688:2459
C688:244A  46                inc  si
C688:244B  C6 04 FE          mov  byte [si],0xfe
C688:244E  46                inc  si
C688:244F  88 14             mov  [si],dl
C688:2451  46                inc  si
C688:2452  88 2C             mov  [si],ch
C688:2454  46                inc  si
C688:2455  89 36 E2 79       mov  [0x79e2],si
C688:2459  B0 01             mov  al,0x01
C688:245B  8A E8             mov  ch,al
C688:245D  A0 3B 79          mov  al,[0x793b]
C688:2460  A8 02             test al,0x02
C688:2462  74 03             jz   C688:2467
C688:2464  E9 82 00          jmp  C688:24E9
C688:2467  8B 36 E2 79       mov  si,[0x79e2]
C688:246B  BA 28 7F          mov  dx,0x7f28
C688:246E  32 C0             xor  al,al
C688:2470  2B F2             sub  si,dx
C688:2472  8B C6             mov  ax,si
C688:2474  0A E4             or   ah,ah
C688:2476  75 1D             jnz  C688:2495
C688:2478  3C F0             cmp  al,0xf0
C688:247A  73 03             jnc  C688:247F
C688:247C  EB 29             jmp  C688:24A7
C688:247F  3C F6             cmp  al,0xf6
C688:2481  73 12             jnc  C688:2495
C688:2483  A0 5E 79          mov  al,[0x795e]
C688:2486  A8 04             test al,0x04
C688:2488  74 03             jz   C688:248D
C688:248A  E9 EF F8          jmp  C688:1D7C
C688:248D  F6 C1 40          test cl,0x40
C688:2490  74 03             jz   C688:2495
C688:2492  E9 E7 F8          jmp  C688:1D7C
C688:2495  5E                pop  si
C688:2496  89 36 6F 79       mov  [0x796f],si
C688:249A  5E                pop  si
C688:249B  BE 0D 79          mov  si,0x790d
C688:249E  80 0C 40          or   byte [si],0x40
C688:24A1  8A C1             mov  al,cl
C688:24A3  A2 60 7A          mov  [0x7a60],al
C688:24A6  C3                ret
```

The small-output fallback loops unless mode bit `0x04` is set or the synthesized
`CH` is zero. A nonzero `CH` sets `[79DF]=2` before returning to the stream
walker. `C688:24C4` and `C688:24C9` are the shortest return tails: they restore
`[796F]`, update `[79DF]`, and return to the caller.

```asm
redraw_small_output_fallback_C688_24A7:
C688:24A7  8B 16 5E 79       mov  dx,[0x795e]
C688:24AB  F6 C2 04          test dl,0x04
C688:24AE  74 03             jz   C688:24B3
C688:24B0  E9 C9 F8          jmp  C688:1D7C
C688:24B3  8A C5             mov  al,ch
C688:24B5  0A C0             or   al,al
C688:24B7  75 03             jnz  C688:24BC
C688:24B9  E9 C0 F8          jmp  C688:1D7C
C688:24BC  B0 02             mov  al,0x02
C688:24BE  A2 DF 79          mov  [0x79df],al
C688:24C1  E9 B8 F8          jmp  C688:1D7C

redraw_return_tail_C688_24C4:
C688:24C4  5A                pop  dx
C688:24C5  89 16 6F 79       mov  [0x796f],dx
C688:24C9  5E                pop  si
C688:24CA  A2 DF 79          mov  [0x79df],al
C688:24CD  C3                ret
```

`C688:24CE` clamps `[79DB]` to `[7950]` before appending final mode markers via
`C688:1BA9`. `C688:24F0` optionally appends marker `0xF1` for mode bit `0x01`,
emits a span through `C688:1C39`, restores flags, and returns through
`C688:24C9`.

```asm
redraw_final_clamp_C688_24CE:
; file 0x48D4E
C688:24CE  8B 36 DB 79       mov  si,[0x79db]
C688:24D2  8B 16 50 79       mov  dx,[0x7950]
C688:24D6  2B F2             sub  si,dx
C688:24D8  73 08             jnc  C688:24E2
C688:24DA  8B 36 50 79       mov  si,[0x7950]
C688:24DE  89 36 DB 79       mov  [0x79db],si
C688:24E2  E8 C4 F6          call C688:1BA9
C688:24E5  89 36 E2 79       mov  [0x79e2],si
C688:24E9  32 C0             xor  al,al
C688:24EB  5A                pop  dx
C688:24EC  89 16 6F 79       mov  [0x796f],dx

redraw_final_mode_span_C688_24F0:
C688:24F0  F6 C1 20          test cl,0x20
C688:24F3  75 D4             jnz  C688:24C9
C688:24F5  9F                lahf
C688:24F6  50                push ax
C688:24F7  A0 5E 79          mov  al,[0x795e]
C688:24FA  A8 01             test al,0x01
C688:24FC  74 0C             jz   C688:250A
C688:24FE  8B 36 E2 79       mov  si,[0x79e2]
C688:2502  C6 04 F1          mov  byte [si],0xf1
C688:2505  46                inc  si
C688:2506  89 36 E2 79       mov  [0x79e2],si
C688:250A  8B 16 DB 79       mov  dx,[0x79db]
C688:250E  8B 36 52 79       mov  si,[0x7952]
C688:2512  2B F2             sub  si,dx
C688:2514  E8 22 F7          call C688:1C39
C688:2517  58                pop  ax
C688:2518  9E                sahf
C688:2519  EB AE             jmp  C688:24C9
```

## Classifier Utility Helpers

`C688:2574` classifies the byte in `AL` through the `CS:6EC4` table and stores
the low table byte in `[793B]`. Positive high-table classes may be filtered by
the current state record at `[75ED]`; if the record does not already carry a
class byte at offset `+4`, the helper reads the active layout table in segment
`D7EF` using `[6D59]` and the original byte index. Negative high-table classes
return the low nibble in `DL` and the masked class bits in `AL`.

```asm
classify_redraw_stream_byte_C688_2574:
; file 0x48DF4
C688:2574  8A D8             mov  bl,al
C688:2576  32 FF             xor  bh,bh
C688:2578  8B EB             mov  bp,bx
C688:257A  33 D2             xor  dx,dx
C688:257C  03 DB             add  bx,bx
C688:257E  2E 8B 87 C46E     mov  ax,[cs:bx+0x6ec4]
C688:2583  A2 3B 79          mov  [0x793b],al
C688:2586  8A C4             mov  al,ah
C688:2588  24 F0             and  al,0xf0
C688:258A  78 43             js   C688:25CF
C688:258C  8B 1E ED 75       mov  bx,[0x75ed]
C688:2590  0A 97 0400        or   dl,[bx+0x0004]
C688:2594  74 0B             jz   C688:25A1
C688:2596  F6 87 0200 08     test byte [bx+0x0002],0x08
C688:259B  75 01             jnz  C688:259E
C688:259D  C3                ret
C688:259E  D0 C2             rol  dl,1
C688:25A0  C3                ret
C688:25A1  83 ED 20          sub  bp,0x20
C688:25A4  06                push es
C688:25A5  56                push si
C688:25A6  BA EF D7          mov  dx,0xd7ef
C688:25A9  8E C2             mov  es,dx
C688:25AB  8A 16 59 6D       mov  dl,[0x6d59]
C688:25AF  32 F6             xor  dh,dh
C688:25B1  03 D2             add  dx,dx
C688:25B3  BE 38 00          mov  si,0x0038
C688:25B6  03 F2             add  si,dx
C688:25B8  26 8B 34          mov  si,[es:si]
C688:25BB  26 8A 12          mov  dl,[es:bp+si]
C688:25BE  5E                pop  si
C688:25BF  07                pop  es
C688:25C0  8B 1E ED 75       mov  bx,[0x75ed]
C688:25C4  F6 87 0200 08     test byte [bx+0x0002],0x08
C688:25C9  75 01             jnz  C688:25CC
C688:25CB  C3                ret
C688:25CC  02 D2             add  dl,dl
C688:25CE  C3                ret
C688:25CF  8A D4             mov  dl,ah
C688:25D1  80 E2 0F          and  dl,0x0f
C688:25D4  8A C4             mov  al,ah
C688:25D6  24 70             and  al,0x70
C688:25D8  C3                ret
```

`C688:626D` merges the current marker mask in `[793B]` into the byte pointed to
by `SI`. It preserves the caller's flags in `[75F1]`, clears bits already owned
by the marker mask, and only re-applies the marker bits when the saved flags and
`CL` disagree on bit `0x10`.

```asm
merge_redraw_marker_mask_C688_626D:
; file 0x4CAED
C688:626D  87 06 F1 75       xchg [0x75f1],ax
C688:6271  A0 3B 79          mov  al,[0x793b]
C688:6274  8A F0             mov  dh,al
C688:6276  F6 D0             not  al
C688:6278  8A D0             mov  dl,al
C688:627A  8A 04             mov  al,[si]
C688:627C  22 C2             and  al,dl
C688:627E  8A D0             mov  dl,al
C688:6280  87 06 F1 75       xchg [0x75f1],ax
C688:6284  32 C1             xor  al,cl
C688:6286  A8 10             test al,0x10
C688:6288  8A C2             mov  al,dl
C688:628A  74 02             jz   C688:628E
C688:628C  0A C6             or   al,dh
C688:628E  88 04             mov  [si],al
C688:6290  C3                ret
```

`C688:A355` is a predicate used before synthetic-stream builders. It returns
zero unless `[79A1] bit 0x10` is set. When that mode is active, `CL bit 0x40`
or `CL bit 0x04` forces a nonzero return; otherwise the predicate mirrors
`[78D5] bit 0`.

```asm
synthetic_stream_allowed_predicate_C688_A355:
; file 0x50BD5
C688:A355  8B 36 A1 79       mov  si,[0x79a1]
C688:A359  8B DE             mov  bx,si
C688:A35B  F6 C3 10          test bl,0x10
C688:A35E  75 01             jnz  C688:A361
C688:A360  C3                ret
C688:A361  F6 C1 40          test cl,0x40
C688:A364  75 0F             jnz  C688:A375
C688:A366  F6 C1 04          test cl,0x04
C688:A369  75 0A             jnz  C688:A375
C688:A36B  8B 36 D5 78       mov  si,[0x78d5]
C688:A36F  8B DE             mov  bx,si
C688:A371  F6 C3 01          test bl,0x01
C688:A374  C3                ret
C688:A375  3A C0             cmp  al,al
C688:A377  C3                ret
```

## Synthetic Stream Builders

`C688:A378` is the predicated wrapper used by the compact-marker path. It calls
`C688:A355`; when synthetic output is not allowed it returns normally. When
allowed, it discards the caller's return address and falls into `C688:A37F`.
`C688:A37F` builds a temporary stream at `0x8029` for special marker classes,
then points `[7A13]` at the interrupted source position, enables `[824F] bit 0`,
sets `CL bit 0x40`, and rejoins the normal stream walker at `C688:1D7D`.

```asm
predicated_synthetic_stream_builder_C688_A378:
; file 0x50BF8
C688:A378  E8 DA FF          call C688:A355
C688:A37B  75 01             jnz  C688:A37E
C688:A37D  C3                ret
C688:A37E  5A                pop  dx

synthetic_stream_builder_C688_A37F:
C688:A37F  BE 29 80          mov  si,0x8029
C688:A382  C7 04 F200        mov  word [si],0x00f2
C688:A386  3C 1F             cmp  al,0x1f
C688:A388  74 30             jz   C688:A3BA
C688:A38A  3C 1E             cmp  al,0x1e
C688:A38C  74 26             jz   C688:A3B4
C688:A38E  3C EE             cmp  al,0xee
C688:A390  75 03             jnz  C688:A395
C688:A392  E9 FB 00          jmp  C688:A490
C688:A395  3C ED             cmp  al,0xed
C688:A397  75 28             jnz  C688:A3C1
C688:A399  B0 0C             mov  al,0x0c
C688:A39B  E8 E1 00          call C688:A47F
C688:A39E  A0 F9 79          mov  al,[0x79f9]
C688:A3A1  04 30             add  al,0x30
C688:A3A3  88 04             mov  [si],al
C688:A3A5  46                inc  si
C688:A3A6  C6 04 DC          mov  byte [si],0xdc
C688:A3A9  46                inc  si
C688:A3AA  A0 F8 79          mov  al,[0x79f8]
C688:A3AD  04 30             add  al,0x30
C688:A3AF  88 04             mov  [si],al
C688:A3B1  46                inc  si
C688:A3B2  EB 44             jmp  C688:A3F8
C688:A3B4  46                inc  si
C688:A3B5  C6 04 52          mov  byte [si],0x52
C688:A3B8  EB 04             jmp  C688:A3BE
C688:A3BA  46                inc  si
C688:A3BB  C6 04 72          mov  byte [si],0x72
C688:A3BE  46                inc  si
C688:A3BF  EB 37             jmp  C688:A3F8
C688:A3C1  3C E9             cmp  al,0xe9
C688:A3C3  75 36             jnz  C688:A3FB
C688:A3C5  A0 F8 79          mov  al,[0x79f8]
C688:A3C8  3C 1C             cmp  al,0x1c
C688:A3CA  75 11             jnz  C688:A3DD
C688:A3CC  C6 04 BB          mov  byte [si],0xbb
C688:A3CF  46                inc  si
C688:A3D0  A0 F9 79          mov  al,[0x79f9]
C688:A3D3  88 04             mov  [si],al
C688:A3D5  46                inc  si
C688:A3D6  C6 04 BB          mov  byte [si],0xbb
C688:A3D9  46                inc  si
C688:A3DA  E9 00 01          jmp  C688:A4DD
C688:A3DD  3C 1A             cmp  al,0x1a
C688:A3DF  9F                lahf
C688:A3E0  50                push ax
C688:A3E1  04 10             add  al,0x10
C688:A3E3  E8 99 00          call C688:A47F
C688:A3E6  58                pop  ax
C688:A3E7  9E                sahf
C688:A3E8  75 0E             jnz  C688:A3F8
C688:A3EA  A0 FA 79          mov  al,[0x79fa]
C688:A3ED  3C 00             cmp  al,0
C688:A3EF  B0 DD             mov  al,0xdd
C688:A3F1  79 02             jns  C688:A3F5
C688:A3F3  B0 DE             mov  al,0xde
C688:A3F5  88 04             mov  [si],al
C688:A3F7  46                inc  si
C688:A3F8  E9 D7 00          jmp  C688:A4D2
```

Markers `0xEF` and `0xE8` pull two adjacent word operands from `[79FC]` or
`[79FB]`, temporarily route output through `[75ED]`, and call `C688:0EF2` for
each word with a `0xDC` separator. Other marker classes emit table-coded bytes
from `C688:774D`. The `0xEE` subpath joins the same word-output case with
record type `0x08`.

```asm
synthetic_stream_extended_markers_C688_A3FB:
C688:A3FB  3C EF             cmp  al,0xef
C688:A3FD  75 19             jnz  C688:A418
C688:A3FF  A0 F8 79          mov  al,[0x79f8]
C688:A402  3C 06             cmp  al,0x06
C688:A404  75 04             jnz  C688:A40A
C688:A406  32 C0             xor  al,al
C688:A408  EB D3             jmp  C688:A3DD
C688:A40A  46                inc  si
C688:A40B  C6 04 56          mov  byte [si],0x56
C688:A40E  46                inc  si
C688:A40F  C6 04 54          mov  byte [si],0x54
C688:A412  46                inc  si
C688:A413  BA FC 79          mov  dx,0x79fc
C688:A416  EB 0C             jmp  C688:A424
C688:A418  3C E8             cmp  al,0xe8
C688:A41A  75 4D             jnz  C688:A469
C688:A41C  B0 0E             mov  al,0x0e
C688:A41E  E8 5E 00          call C688:A47F
C688:A421  BA FB 79          mov  dx,0x79fb
C688:A424  51                push cx
C688:A425  FF 36 ED 75       push word [0x75ed]
C688:A429  56                push si
C688:A42A  8F 06 ED 75       pop  word [0x75ed]
C688:A42E  8B EA             mov  bp,dx
C688:A430  8A 7E 00          mov  bh,[bp+0x00]
C688:A433  4D                dec  bp
C688:A434  8A 5E 00          mov  bl,[bp+0x00]
C688:A437  4D                dec  bp
C688:A438  8B D5             mov  dx,bp
C688:A43A  8B F3             mov  si,bx
C688:A43C  52                push dx
C688:A43D  E8 B2 6A          call C688:0EF2
C688:A440  5A                pop  dx
C688:A441  8B 1E ED 75       mov  bx,[0x75ed]
C688:A445  C6 07 DC          mov  byte [bx],0xdc
C688:A448  43                inc  bx
C688:A449  89 1E ED 75       mov  [0x75ed],bx
C688:A44D  8B EA             mov  bp,dx
C688:A44F  8A 7E 00          mov  bh,[bp+0x00]
C688:A452  4D                dec  bp
C688:A453  8A 5E 00          mov  bl,[bp+0x00]
C688:A456  8B F3             mov  si,bx
C688:A458  8B D5             mov  dx,bp
C688:A45A  E8 95 6A          call C688:0EF2
C688:A45D  FF 36 ED 75       push word [0x75ed]
C688:A461  5E                pop  si
C688:A462  8F 06 ED 75       pop  word [0x75ed]
C688:A466  59                pop  cx
C688:A467  EB 69             jmp  C688:A4D2
C688:A469  B0 0A             mov  al,0x0a
C688:A46B  E8 11 00          call C688:A47F
C688:A46E  A0 F9 79          mov  al,[0x79f9]
C688:A471  E8 0C 00          call C688:A480
C688:A474  C6 04 DC          mov  byte [si],0xdc
C688:A477  A0 F8 79          mov  al,[0x79f8]
C688:A47A  E8 02 00          call C688:A47F
C688:A47D  EB 53             jmp  C688:A4D2
C688:A47F  46                inc  si
C688:A480  8A D8             mov  bl,al
C688:A482  B7 00             mov  bh,0
C688:A484  BA 4D 77          mov  dx,0x774d
C688:A487  03 DA             add  bx,dx
C688:A489  8B 17             mov  dx,[bx]
C688:A48B  89 14             mov  [si],dx
C688:A48D  46                inc  si
C688:A48E  46                inc  si
C688:A48F  C3                ret
C688:A490  B0 08             mov  al,0x08
C688:A492  EB 8A             jmp  C688:A41E
```

`C688:A494` is the classifier-pair synthetic builder reached from the larger
classifier path. It uses `CH` to index the compact table rooted at `C688:7746`,
emits `F2 table-byte digit`, and then shares the same final handoff tail as
`C688:A37F`.

```asm
classifier_pair_synthetic_stream_C688_A494:
C688:A494  E8 BE FE          call C688:A355
C688:A497  75 01             jnz  C688:A49A
C688:A499  C3                ret
C688:A49A  5A                pop  dx
C688:A49B  8A C5             mov  al,ch
C688:A49D  24 FE             and  al,0xfe
C688:A49F  3C EA             cmp  al,0xea
C688:A4A1  75 08             jnz  C688:A4AB
C688:A4A3  8A C5             mov  al,ch
C688:A4A5  24 01             and  al,0x01
C688:A4A7  04 F2             add  al,0xf2
C688:A4A9  8A E8             mov  ch,al
C688:A4AB  8A DD             mov  bl,ch
C688:A4AD  D0 EB             shr  bl,1
C688:A4AF  BA 46 77          mov  dx,0x7746
C688:A4B2  83 EA 78          sub  dx,0x78
C688:A4B5  B7 00             mov  bh,0
C688:A4B7  8B F3             mov  si,bx
C688:A4B9  03 F2             add  si,dx
C688:A4BB  8A 04             mov  al,[si]
C688:A4BD  BE 29 80          mov  si,0x8029
C688:A4C0  C6 04 F2          mov  byte [si],0xf2
C688:A4C3  46                inc  si
C688:A4C4  88 04             mov  [si],al
C688:A4C6  46                inc  si
C688:A4C7  8A C5             mov  al,ch
C688:A4C9  24 01             and  al,0x01
C688:A4CB  34 01             xor  al,0x01
C688:A4CD  04 30             add  al,0x30
C688:A4CF  88 04             mov  [si],al
C688:A4D1  46                inc  si

synthetic_stream_handoff_tail_C688_A4D2:
C688:A4D2  A0 5E 79          mov  al,[0x795e]
C688:A4D5  A8 02             test al,0x02
C688:A4D7  75 04             jnz  C688:A4DD
C688:A4D9  C6 04 F3          mov  byte [si],0xf3
C688:A4DC  46                inc  si
C688:A4DD  C6 04 FF          mov  byte [si],0xff
C688:A4E0  5E                pop  si
C688:A4E1  89 36 13 7A       mov  [0x7a13],si
C688:A4E5  BA 29 80          mov  dx,0x8029
C688:A4E8  80 0E 4F 82 01    or   byte [0x824f],0x01
C688:A4ED  80 C9 40          or   cl,0x40
C688:A4F0  E9 8A 78          jmp  C688:1D7D
```

## Formatting And Handoff Helpers

`C688:0EF2` formats the word in `SI` as decimal digits into the output cursor
at `[75ED]`. It seeds `[75EF]` with a small divisor table in the local code
segment, then joins the shared decimal-emitter tail at `C688:0EA3`. The sibling
entrypoints at `C688:0EFD` and `C688:0F0A` use longer divisor tables for four-
and five-digit output. `C688:0F17` is the inverse helper: it consumes up to
three non-space digits from `[75ED]` and accumulates the numeric value in `SI`.

```asm
decimal_emit_tail_C688_0EA3:
; file 0x47723
C688:0EA3  B5 03             mov  ch,0x03
C688:0EA5  8B 1E EF 75       mov  bx,[0x75ef]
C688:0EA9  1E                push ds
C688:0EAA  8E DF             mov  ds,di
C688:0EAC  8B 17             mov  dx,[bx]
C688:0EAE  1F                pop  ds
C688:0EAF  FF 06 EF 75       inc  word [0x75ef]
C688:0EB3  FF 06 EF 75       inc  word [0x75ef]
C688:0EB7  B1 2F             mov  cl,0x2f
C688:0EB9  FE C1             inc  cl
C688:0EBB  2B F2             sub  si,dx
C688:0EBD  73 FA             jnc  C688:0EB9
C688:0EBF  03 F2             add  si,dx
C688:0EC1  8B 1E ED 75       mov  bx,[0x75ed]
C688:0EC5  88 0F             mov  [bx],cl
C688:0EC7  FF 06 ED 75       inc  word [0x75ed]
C688:0ECB  FE CD             dec  ch
C688:0ECD  75 D6             jnz  C688:0EA5
C688:0ECF  8B 1E ED 75       mov  bx,[0x75ed]
C688:0ED3  8A 47 FD          mov  al,[bx-0x03]
C688:0ED6  3C 3A             cmp  al,0x3a
C688:0ED8  79 01             jns  C688:0EDB
C688:0EDA  C3                ret
C688:0EDB  C6 47 FD 78       mov  byte [bx-0x03],0x78
C688:0EDF  C3                ret

decimal_emit_3_digit_C688_0EF2:
C688:0EF2  BB 7B 0E          mov  bx,0x0e7b
C688:0EF5  89 1E EF 75       mov  [0x75ef],bx
C688:0EF9  8C CF             mov  di,cs
C688:0EFB  EB A6             jmp  C688:0EA3

decimal_emit_4_digit_C688_0EFD:
C688:0EFD  BB 79 0E          mov  bx,0x0e79
C688:0F00  89 1E EF 75       mov  [0x75ef],bx
C688:0F04  B5 04             mov  ch,0x04
C688:0F06  8C CF             mov  di,cs
C688:0F08  EB 9B             jmp  C688:0EA5

decimal_emit_5_digit_C688_0F0A:
C688:0F0A  BB 77 0E          mov  bx,0x0e77
C688:0F0D  89 1E EF 75       mov  [0x75ef],bx
C688:0F11  B5 05             mov  ch,0x05
C688:0F13  8C CF             mov  di,cs
C688:0F15  EB 8E             jmp  C688:0EA5

decimal_parse_3_digit_C688_0F17:
C688:0F17  B5 03             mov  ch,0x03
C688:0F19  B6 00             mov  dh,0
C688:0F1B  BE 00 00          mov  si,0
C688:0F1E  8B 1E ED 75       mov  bx,[0x75ed]
C688:0F22  8A 07             mov  al,[bx]
C688:0F24  0A C0             or   al,al
C688:0F26  75 01             jnz  C688:0F29
C688:0F28  C3                ret
C688:0F29  3C 20             cmp  al,0x20
C688:0F2B  75 01             jnz  C688:0F2E
C688:0F2D  C3                ret
C688:0F2E  8B D6             mov  dx,si
C688:0F30  03 F6             add  si,si
C688:0F32  03 F6             add  si,si
C688:0F34  03 F2             add  si,dx
C688:0F36  03 F6             add  si,si
C688:0F38  24 0F             and  al,0x0f
C688:0F3A  B6 00             mov  dh,0
C688:0F3C  8A D0             mov  dl,al
C688:0F3E  03 F2             add  si,dx
C688:0F40  FF 06 ED 75       inc  word [0x75ed]
C688:0F44  FE CD             dec  ch
C688:0F46  75 D6             jnz  C688:0F1E
C688:0F48  C3                ret
```

`C688:0F49` is a synthetic-stream handoff wrapper. It preserves the caller's
`[75ED]`, `[75EF]`, and `CX` while using `C688:0EF2` to format a word, then
marks the current state record as stream-backed, skips one or two leading ASCII
zeroes, and returns the adjusted synthetic-stream pointer in `DX`.

```asm
format_word_and_prepare_stream_C688_0F49:
C688:0F49  51                push cx
C688:0F4A  FF 36 ED 75       push word [0x75ed]
C688:0F4E  FF 36 EF 75       push word [0x75ef]
C688:0F52  E8 9D FF          call C688:0EF2
C688:0F55  8F 06 EF 75       pop  word [0x75ef]
C688:0F59  8F 06 ED 75       pop  word [0x75ed]
C688:0F5D  59                pop  cx
C688:0F5E  80 0E 4F 82 01    or   byte [0x824f],0x01
C688:0F63  80 C9 40          or   cl,0x40
C688:0F66  5E                pop  si
C688:0F67  8B EC             mov  bp,sp
C688:0F69  87 76 00          xchg [bp+0x00],si
C688:0F6C  8B 1E ED 75       mov  bx,[0x75ed]
C688:0F70  89 77 04          mov  [bx+0x04],si
C688:0F73  C6 47 03 FF       mov  byte [bx+0x03],0xff
C688:0F77  FF 36 ED 75       push word [0x75ed]
C688:0F7B  5E                pop  si
C688:0F7C  8A 04             mov  al,[si]
C688:0F7E  3C 30             cmp  al,0x30
C688:0F80  75 08             jnz  C688:0F8A
C688:0F82  46                inc  si
C688:0F83  8A 04             mov  al,[si]
C688:0F85  3C 30             cmp  al,0x30
C688:0F87  75 01             jnz  C688:0F8A
C688:0F89  46                inc  si
C688:0F8A  87 D6             xchg si,dx
C688:0F8C  C3                ret
```

## Small Utility Hooks

`C688:1286` is the live target of the `0xE7` marker hook, but in this ROM it is
a one-byte no-op return. The caller immediately loops back into the redraw stream
walker, so the hook preserves all state.

```asm
marker_e7_noop_hook_C688_1286:
; file 0x47B06
C688:1286  C3                ret
```

`C688:4239` is the width scaler used before wide-output span calculations. It
divides `SI` by four in place and returns.

```asm
quarter_width_helper_C688_4239:
; file 0x4AAB9
C688:4239  D1 EE             shr  si,1
C688:423B  D1 EE             shr  si,1
C688:423D  C3                ret
```

`C688:66FC` reads the current state record width byte at `[75ED]+4`, defaults a
zero value to `5`, and returns it in `DX`.

```asm
state_record_width_or_default_C688_66FC:
; file 0x4CF7C
C688:66FC  8B 1E ED 75       mov  bx,[0x75ed]
C688:6700  8A 87 0400        mov  al,[bx+0x0004]
C688:6704  0A C0             or   al,al
C688:6706  75 02             jnz  C688:670A
C688:6708  B0 05             mov  al,0x05
C688:670A  8A D0             mov  dl,al
C688:670C  B6 00             mov  dh,0
C688:670E  C3                ret
```

## Renderer Descriptor Helpers

`C688:3C2B` is the descriptor-pop entry used by `C688:1A85` after the caller
has pushed the range and renderer fields. The nearby `C688:3C29` entry first
selects renderer type `0x0A`; the `C688:3C35` sibling selects type `0x03` and
preserves an additional caller-supplied `[7741]` field. The common tail fills
the renderer descriptor fields at `7739` through `7745`, rejects negative or
zero spans, and falls through to `C688:3C68`.

`C688:3C68` skips output when `[7A56] bit 0` is set. Otherwise it sets service
type `0x05`, points `[771B]` at the descriptor rooted at `7732`, and flushes it
through the already mapped renderer-service tail at `C688:6BAA`.

```asm
renderer_descriptor_type0a_C688_3C29:
; file 0x4A4A9
C688:3C29  B0 0A             mov  al,0x0a

renderer_descriptor_from_stack_C688_3C2B:
C688:3C2B  59                pop  cx
C688:3C2C  BE 00 00          mov  si,0
C688:3C2F  89 36 41 77       mov  [0x7741],si
C688:3C33  EB 09             jmp  C688:3C3E

renderer_descriptor_type03_C688_3C35:
C688:3C35  B0 03             mov  al,0x03
C688:3C37  59                pop  cx
C688:3C38  5E                pop  si
C688:3C39  89 36 41 77       mov  [0x7741],si
C688:3C3D  5E                pop  si
C688:3C3E  89 36 43 77       mov  [0x7743],si
C688:3C42  A2 45 77          mov  [0x7745],al
C688:3C45  5E                pop  si
C688:3C46  89 36 39 77       mov  [0x7739],si
C688:3C4A  5E                pop  si
C688:3C4B  89 36 3B 77       mov  [0x773b],si
C688:3C4F  5E                pop  si
C688:3C50  89 36 3D 77       mov  [0x773d],si
C688:3C54  5E                pop  si
C688:3C55  89 36 3F 77       mov  [0x773f],si
C688:3C59  51                push cx
C688:3C5A  8B C6             mov  ax,si
C688:3C5C  F6 C4 80          test ah,0x80
C688:3C5F  74 01             jz   C688:3C62
C688:3C61  C3                ret
C688:3C62  83 FE 00          cmp  si,0
C688:3C65  75 01             jnz  C688:3C68
C688:3C67  C3                ret

renderer_descriptor_flush_C688_3C68:
C688:3C68  A0 56 7A          mov  al,[0x7a56]
C688:3C6B  A8 01             test al,0x01
C688:3C6D  74 01             jz   C688:3C70
C688:3C6F  C3                ret
C688:3C70  B0 05             mov  al,0x05
C688:3C72  A2 1D 77          mov  [0x771d],al
C688:3C75  BE 32 77          mov  si,0x7732
C688:3C78  89 36 1B 77       mov  [0x771b],si
C688:3C7C  E8 2B 2F          call C688:6BAA
C688:3C7F  C3                ret
```

## State Fields

| Field | Use in this slice |
| --- | --- |
| `[75ED]`, `[75EF]`, `[75F1]` | State/output pointers and saved flags. `[75ED]` points at `[795C]` or `[7A0F]` while state bytes are written; `[75EF]` is the buffered marker output cursor. |
| `[78D5]`, `[78DB]`, `[78DD]`, `[78E5]`, `[78E7]`, `[78E9]`, `[78EB]`, `[78ED]`, `[78EF]`, `[78F1]`, `[78F3]`, `[78F5]`, `[78FD]`, `[78FF]` | Live editor/window fields consumed while computing redraw deltas, bounds, and final-output spans. |
| `[7901]`, `[7903]`, `[7907]`, `[7909]`, `[790A]`, `[790D]`, `[790F]`, `[7916]`, `[792E]`, `[7971]`, `[7973]`, `[7975]`, `[7977]` | Window bounds, dirty flags, and span/cache inputs copied, clamped, or temporarily adjusted by the redraw dispatcher. |
| `[793B]`, `[793D]`, `[793E]`, `[7950]`, `[7952]`, `[7954]`, `[7956]`, `[7958]`, `[795A]`, `[795E]`, `[795F]`, `[7988]`, `[7990]`, `[7999]`, `[799A]`, `[799C]`, `[79A1]` | Mode bytes, active viewport limits, stream marker state, classifier byte cache, synthetic-stream gates, and marker-buffer count. |
| `[7961]`, `[7963]`, `[7967]`, `[7969]`, `[796B]`, `[796D]`, `[796F]`, `[797F]`, `[79D5]` | Saved redraw/window state restored by `C688:19B2` or updated by compact stream markers and stream-bound helpers. |
| `[7979]`, `[79DB]`, `[79DF]`, `[79E2]`, `[79EC]`, `[79F6]`, `[79F8]`, `[79F9]`, `[79FA]`, `[79FB]`, `[79FC]`, `[79FE]`, `[79FF]`, `[7A0A]`, `[7A13]`, `[7A15]`, `[7A17]`, `[7A19]`, `[7A41]`, `[7A60]`, `[7F25]` | Active redraw/window fields, compact marker operands, final-output scratch state, and the `7F28` scratch-output pointer. |
| `[7713]`, `[7717]`, `[771B]`, `[771D]`, `[7727]`, `[772B]`, `[772E]`, `[7732]`, `[7739]`, `[773B]`, `[773D]`, `[773F]`, `[7741]`, `[7743]`, `[7745]`, `[7746]`, `[774D]`, `[8029]` | Scratch-stream state, renderer descriptor fields, synthetic-stream lookup tables, and renderer service wrapper state. |
| `[7A56]` | Renderer suppress flag checked before flushing descriptor output. |
| `[6D59]`, `D7EF:0038` | External layout-table selector and base pointer table used by the classifier fallback path. |
| `[824F]` | Stream source selector for the redraw walker; bit 0 decides whether the `CL bit 0x40` byte load temporarily uses `ES` as `DS`. |

## Current Bottom

This slice now covers the lower redraw/input helpers, redraw byte dispatcher,
compact marker families, classifier-specific paths, final render exits, and the
redraw-local utility calls exposed by those paths.

| Root | Current boundary |
| --- | --- |
| Further renderer-service internals | Reached through mapped renderer wrappers such as `C688:6BAA`. |
