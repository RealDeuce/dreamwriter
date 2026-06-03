# INT 21h File I/O Internals

This slice follows the local file read/write/seek paths reached from
[`int21-dispatch.md`](int21-dispatch.md) and
[`int21-filesystem-front.md`](int21-filesystem-front.md).

No image assets are reached in this slice.

## Read

`AH=3F` first resolves the handle through `C000:4064`. DreamLink handles branch
to `C000:44C0` on first use and then receive data through `C000:4511`.

```asm
service_3F_read_C000_3194:
; file 0x43194
C000:3194  E8 CD 0E          call resolve_handle_C000_4064
C000:3197  80 3E A5 6F 0A    cmp  byte [0x6fa5],0x0a
C000:319C  75 1F             jnz  local_read_C000_31BD
C000:319E  F6 C4 80          test ah,0x80
C000:31A1  75 13             jnz  dreamlink_read_continue_C000_31B6
C000:31A3  80 CC 80          or   ah,0x80
C000:31A6  88 25             mov  [di],ah
C000:31AB  E8 12 13          call dreamlink_read_start_C000_44C0
C000:31B6  E8 58 13          call dreamlink_read_data_C000_4511
C000:31B9  89 46 00          mov  [bp+0x00],ax
C000:31BC  C3                ret
```

The local read path keeps the caller buffer at `6F62:6F64`, requested count at
`6F66`, current block offset at `6F93`, and returned byte count at `6F95`.
It reads 128-byte sectors/clusters through `C000:3994`, copies to the caller
buffer, advances the FAT12 chain through `C000:39C9`, and stops at `0xFFF`.

```asm
local_read_C000_31BD:
C000:31BD  89 16 62 6F       mov  [0x6f62],dx
C000:31C1  8B 56 08          mov  dx,[bp+0x08]
C000:31C4  89 16 64 6F       mov  [0x6f64],dx
C000:31C8  89 0E 66 6F       mov  [0x6f66],cx
...
C000:31FD  8B 0E 66 6F       mov  cx,[0x6f66]
C000:3201  8B 1E 93 6F       mov  bx,[0x6f93]
C000:3205  B8 80 00          mov  ax,0x80
C000:3208  2B C3             sub  ax,bx
...
C000:3227  8E 06 64 6F       mov  es,[0x6f64]
C000:322B  8E 1E A6 6F       mov  ds,[0x6fa6]
C000:3230  F3 A4             rep  movsb
...
C000:3240  E8 88 07          call next_fat_cluster_C000_39C9
C000:3241  3D FF 0F          cmp  ax,0x0fff
```

On success, the dispatcher frame receives the byte count from `[6F95]`.

## Write

`AH=40` also resolves the handle first. DreamLink handles start with
`C000:4622` and continue through `C000:4647`.

```asm
service_40_write_C000_32B1:
; file 0x432B1
C000:32B1  E8 B0 0D          call resolve_handle_C000_4064
C000:32B4  80 3E A5 6F 0A    cmp  byte [0x6fa5],0x0a
C000:32B9  75 1C             jnz  local_write_C000_32D7
C000:32BB  F6 C4 80          test ah,0x80
C000:32BE  75 10             jnz  dreamlink_write_continue_C000_32D0
C000:32C0  80 CC 80          or   ah,0x80
C000:32C3  88 25             mov  [di],ah
C000:32C8  E8 57 13          call dreamlink_write_start_C000_4622
C000:32D0  E8 74 13          call dreamlink_write_data_C000_4647
C000:32D3  89 46 00          mov  [bp+0x00],ax
C000:32D6  C3                ret
```

Local write sets dirty flag `[7036]=1`, stages the caller buffer/count, checks
write access, and writes partial or full 128-byte chunks into the current data
window. If the chain must grow, it allocates a new FAT12 cluster.

```asm
local_write_C000_32D7:
C000:32D7  C6 06 36 70 01    mov  byte [0x7036],1
C000:32DC  89 16 62 6F       mov  [0x6f62],dx
C000:32E0  8B 56 08          mov  dx,[bp+0x08]
C000:32E3  89 16 64 6F       mov  [0x6f64],dx
C000:32E7  89 0E 66 6F       mov  [0x6f66],cx
...
C000:3340  E8 51 06          call map_current_data_block_C000_3994
C000:3361  8E 06 A6 6F       mov  es,[0x6fa6]
C000:3365  8E 1E 64 6F       mov  ds,[0x6f64]
C000:3369  8A 04             mov  al,[si]
C000:336B  26 88 05          mov  [es:di],al
C000:3372  F3 A4             rep  movsb
```

The write path verifies at least the first byte before bulk copy, and reports
error `0x13` on write/verify failure.

## Cluster Allocation And FAT12

`C000:34A3` finds/allocates the next cluster. If the current FAT chain has
ended at `0xFFF`, it scans from cluster `2` for a zero FAT entry, then links the
previous cluster to the new one. `C000:3538` writes an end-of-chain marker.

```asm
find_or_extend_cluster_C000_34A3:
C000:34A3  E8 23 05          call next_fat_cluster_C000_39C9
C000:34A6  3D FF 0F          cmp  ax,0x0fff
C000:34A9  74 05             jz   allocate_new_cluster_C000_34B0
C000:34AB  A3 59 6F          mov  [0x6f59],ax
C000:34AE  F8                clc
C000:34AF  C3                ret
...
C000:34DC  FF 06 57 6F       inc  word [0x6f57]
C000:34E0  A1 AA 6F          mov  ax,[0x6faa]
C000:34E3  39 06 57 6F       cmp  [0x6f57],ax
C000:34E7  72 D2             jc   C000:34BB
C000:34E9  C6 06 C1 6E 0A    mov  byte [0x6ec1],0x0a
C000:34EE  F9                stc
C000:34EF  C3                ret
```

The FAT math uses the standard FAT12 `cluster * 3 / 2` packing pattern in the
shared helpers around `C000:39BA..39D7`.

## Seek

`AH=42` resolves the handle, records the caller offset in `6F66:6F68`, records
the origin byte in `6FAE`, and computes the new file pointer against the current
position and file size. Invalid origins report error `0x01`.

```asm
service_42_seek_C000_356F:
; file 0x4356F
C000:356F  E8 F2 0A          call resolve_handle_C000_4064
C000:3572  33 C0             xor  ax,ax
C000:3574  A3 95 6F          mov  [0x6f95],ax
C000:3577  A3 97 6F          mov  [0x6f97],ax
C000:357A  89 16 66 6F       mov  [0x6f66],dx
C000:357E  89 0E 68 6F       mov  [0x6f68],cx
C000:3582  8B 46 00          mov  ax,[bp+0x00]
C000:3585  A2 AE 6F          mov  [0x6fae],al
```

Origin `0` is absolute, origin `1` is current position plus offset, and origin
`2` is file size plus offset. The path returns the resulting low/high offset in
`DX:AX` through the dispatcher frame.

## Delete And Attributes Boundary

Delete (`C000:3730`) and attributes (`C000:37A7`) share directory-entry helpers.
The delete path marks the first byte of the entry as `0xE5`, frees the FAT
chain, and sets dirty state. Attribute get/set reads or writes entry byte
`+0x0B`.

Those directory-entry mutation helpers are queued as
`int21-directory-core.md`, because the same routines are used by create, open,
find, rename, and date/time.

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:3868`, `388B`, `39BA`, `39C9`, `39F7`, `3B69` | `int21-directory-core.md` | Shared directory scan, FAT12 read/write, filename parser, and mount validation. |
| `C000:4064`, `3DB3`, `3DDE`, `3E91`, `3EC2` | `int21-handle-core.md` | Handle resolution and open-file state updates. |
| `C000:44C0`, `4511`, `4622`, `4647` | `dreamlink-file-core.md` | DreamLink read/write command senders. |
