# INT 21h Handle Core

This slice follows handle resolution and open-file state used by
[`int21-file-io.md`](int21-file-io.md), [`int21-endpoints.md`](int21-endpoints.md),
and [`int21-directory-core.md`](int21-directory-core.md).

No image assets or string resources are reached in this slice.

## Resolve Endpoint From Handle

`C000:4064` records the caller handle in `[6F19]` and resolves the active
endpoint into `[6FA5]`. Handles `>= 0x0A` are treated as the built-in endpoint
`0x08`; handles below `0x0A` index the active handle-to-endpoint table at
`703F`.

```asm
resolve_endpoint_C000_4064:
; file 0x44064
C000:4064  89 1E 19 6F       mov  [0x6f19],bx
C000:4068  83 FB 0A          cmp  bx,0x0a
C000:406B  72 06             jc   lookup_handle_endpoint_C000_4073
C000:406D  C6 06 A5 6F 08    mov  byte [0x6fa5],0x08
C000:4072  C3                ret

lookup_handle_endpoint_C000_4073:
C000:4073  BF 3F 70          mov  di,0x703f
C000:4076  03 FB             add  di,bx
C000:4078  8A 05             mov  al,[di]
C000:407C  24 0F             and  al,0x0f
C000:407E  A2 A5 6F          mov  [0x6fa5],al
C000:4081  C3                ret
```

## Handle Validation

`C000:3DB3` validates DOS-ish handles `5..8` against the four-entry open-file
slot table. A valid slot sets `[6FAF]`, points `[6FB0]` at the 32-byte state
record, then falls into `C000:3DDE` to hydrate shared current-file state.

```asm
resolve_open_file_C000_3DB3:
; file 0x43DB3
C000:3DB3  83 EB 05          sub  bx,0x05
C000:3DB6  83 FB 04          cmp  bx,0x04
C000:3DB9  72 07             jc   slot_index_ok_C000_3DC2
C000:3DBB  C6 06 C1 6E 06    mov  byte [0x6ec1],0x06
C000:3DC0  F9                stc
C000:3DC1  C3                ret

slot_index_ok_C000_3DC2:
C000:3DC2  8A 87 B2 6F       mov  al,[bx+0x6fb2]
C000:3DC6  3C FF             cmp  al,0xff
C000:3DC8  74 F1             jz   invalid_handle_C000_3DBB
C000:3DCE  A2 AF 6F          mov  [0x6faf],al
C000:3DD1  B4 20             mov  ah,0x20
C000:3DD3  F6 E4             mul  ah             ; AL * 0x20
C000:3DD8  03 D8             add  bx,ax
C000:3DDA  89 1E B0 6F       mov  [0x6fb0],bx
```

## Hydrate Current File State

`C000:3DDE` copies fields from the selected 32-byte open-file record into the
shared working variables used by read, write, seek, and metadata operations.
It also verifies that the backing directory entry still contains the cached
time/date words; if not, it marks storage error `0x13`.

```asm
hydrate_handle_state_C000_3DDE:
; file 0x43DDE
C000:3DE1  8B 47 0C          mov  ax,[bx+0x0c]   ; file size low
C000:3DE4  8B 57 0E          mov  dx,[bx+0x0e]   ; file size high
C000:3DE7  8B 4F 10          mov  cx,[bx+0x10]   ; current position low
C000:3DEA  8B 6F 12          mov  bp,[bx+0x12]   ; current position high
...
C000:3E19  8A 07             mov  al,[bx]
C000:3E1B  A2 A5 6F          mov  [0x6fa5],al
...
C000:3E3A  8E 06 A3 6F       mov  es,[0x6fa3]
C000:3E3E  8B 7F 1E          mov  di,[bx+0x1e]   ; directory entry offset
C000:3E41  83 C7 16          add  di,0x16
C000:3E44  26 8B 05          mov  ax,[es:di]
C000:3E47  3B 47 16          cmp  ax,[bx+0x16]
```

The endpoint byte in the slot selects the storage window:

| Endpoint | Segment/window |
| ---: | ---: |
| `0x08` | `0x1800` built-in store. |
| `0x09` | `0x4000` PCMCIA SRAM card store. |
| `0x0A` | `0x0580` DreamLink transfer endpoint. |

## Close And Writeback

`C000:3D52` is the close path. For DreamLink endpoint `0x0A`, it dispatches to
the serial close routine at `C000:4707`. For local open slots, it clears the
slot byte and, if the file has dirty size/date state, writes the updated
directory-entry words at offsets `+0x16..+0x1F`.

```asm
close_handle_C000_3D52:
; file 0x43D52
C000:3D52  80 3E A5 6F 0A    cmp  byte [0x6fa5],0x0a
C000:3D57  75 04             jnz  local_close_C000_3D5D
C000:3D59  E8 AB 09          call dreamlink_close_C000_4707
C000:3D5C  C3                ret
...
C000:3D71  C6 87 B2 6F FF    mov  byte [bx+0x6fb2],0xff
C000:3D86  8B 7F 1E          mov  di,[bx+0x1e]
C000:3D89  83 C7 16          add  di,0x16
C000:3D8C  8B 47 16          mov  ax,[bx+0x16]
C000:3D8F  26 89 05          mov  [es:di],ax
```

`C000:3EE5` is the shared directory-entry writeback helper used after extending
or seeking a file. It writes packed time/date and file size back through
`ES:DI`.

## Position Update

`C000:3E91` writes the current directory-entry offset/cluster position from the
shared variables back into the open-file record and advances the current file
position by the transfer size `[6F95:6F97]`.

`C000:3EC2` calls that updater, then extends the cached file size if the new
position exceeds the previous size and commits the directory-entry update
through `C000:3EE5`.

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `703F..` | Handle-to-endpoint table used by `AX=4400` and endpoint resolution. |
| `6FB2..6FB5` | Four open-file slot bytes; `0xFF` means free. |
| `6FB6..` | Four 32-byte open-file state records. |
| `6FB0` | Pointer to the active open-file state record. |
| `6FAF` | Active slot index returned to callers. |
| `6F19` | Original caller handle. |
| `6F93`, `6F95`, `6F97` | Current transfer/position helper fields. |

DreamLink file commands are expanded in
[`dreamlink-file-core.md`](dreamlink-file-core.md). Directory-entry timestamp
packing is expanded in [`int21-time-pack.md`](int21-time-pack.md).
