# INT 21h Filesystem Front-End

This slice follows the front-end handlers reached from
[`int21-dispatch.md`](int21-dispatch.md): drive selection, DTA handling, free
space, create/open/close, find-first/find-next, rename, delete, attributes, and
file date/time metadata.

No image assets are reached in this slice.

## Drive And DTA Services

```asm
service_0E_select_drive_C000_28A7:
; file 0x428A7
C000:28A7  FE C2             inc  dl              ; external DL -> internal 1-based
C000:28A9  80 FA 0B          cmp  dl,0x0b
C000:28AC  73 04             jnc  C000:28B2
C000:28AE  88 16 35 6D       mov  [0x6d35],dl
C000:28B2  C7 46 00 0900     mov  word [bp+0x00],0x0009
C000:28B7  F8                clc
C000:28B8  C3                ret

service_19_get_drive_C000_28B9:
C000:28B9  A0 35 6D          mov  al,[0x6d35]
C000:28BC  32 E4             xor  ah,ah
C000:28BE  89 46 00          mov  [bp+0x00],ax
C000:28C1  F8                clc
C000:28C2  C3                ret

service_1A_set_dta_C000_28C3:
C000:28C3  89 16 6A 6F       mov  [0x6f6a],dx
C000:28C7  8B 56 08          mov  dx,[bp+0x08]   ; caller DS
C000:28CA  89 16 6C 6F       mov  [0x6f6c],dx
C000:28CE  F8                clc
C000:28CF  C3                ret

service_2F_get_dta_C000_28D0:
C000:28D0  8B 1E 6C 6F       mov  bx,[0x6f6c]
C000:28D4  89 5E 0A          mov  [bp+0x0a],bx   ; ES
C000:28D7  8B 1E 6A 6F       mov  bx,[0x6f6a]
C000:28DB  89 5E 02          mov  [bp+0x02],bx   ; BX
C000:28DE  F8                clc
C000:28DF  C3                ret
```

## Free Space

`AH=36` selects the requested drive, mounts/probes the endpoint, and for local
storage scans FAT entries looking for zero entries. The returned shape is
DOS-like: `AX`, `BX`, `CX`, and `DX` are written back through the dispatcher
frame. `AX=FFFF` is returned on error.

```asm
service_36_free_space_C000_28E0:
; file 0x428E0
C000:28E0  0A D2             or   dl,dl
C000:28E2  75 04             jnz  C000:28E8
C000:28E4  8A 16 35 6D       mov  dl,[0x6d35]
C000:28E8  88 16 35 6D       mov  [0x6d35],dl
C000:28EC  88 16 A5 6F       mov  [0x6fa5],dl
C000:28F0  C7 06 A3 6F 0018  mov  word [0x6fa3],0x1800
...
C000:295D  E8 09 12          call mount_current_endpoint_C000_3B69
C000:2968  C7 06 60 6F 0100  mov  word [0x6f60],1
C000:296E  E8 11 10          call C000:3982
C000:297B  89 0E 57 6F       mov  [0x6f57],cx
C000:297F  E8 4C 10          call C000:39CE      ; read FAT12 entry
C000:2982  0B C0             or   ax,ax
C000:2984  75 04             jnz  C000:298A
C000:2986  FF 06 5B 6F       inc  word [0x6f5b]  ; free cluster count
...
C000:2991  8B 1E 5B 6F       mov  bx,[0x6f5b]
C000:2995  8B 16 AA 6F       mov  dx,[0x6faa]
C000:2999  4A                dec  dx
C000:299A  B9 80 00          mov  cx,0x0080
C000:299D  A1 60 6F          mov  ax,[0x6f60]
C000:29A0  89 46 00          mov  [bp+0x00],ax
C000:29A3  89 5E 02          mov  [bp+0x02],bx
C000:29A6  89 4E 04          mov  [bp+0x04],cx
C000:29A9  89 56 06          mov  [bp+0x06],dx
C000:29AC  C3                ret
```

DreamLink endpoint `0x0A` is treated specially: it probes the serial peer and
returns zeroed free-space registers when the peer responds.

## Create And Open

Create/truncate (`AH=3C`) and create-new (`AH=5B`) share the same local path
after filename parsing. They branch to DreamLink command sender `C000:4384` when
the selected endpoint is `0x0A`.

```asm
service_3C_create_truncate_C000_29AD:
; file 0x429AD
C000:29AD  89 0E 70 6F       mov  [0x6f70],cx    ; attributes
C000:29B1  8B F2             mov  si,dx
C000:29B8  E8 3C 10          call parse_filename_C000_39F7
...
C000:29BF  A0 A5 6F          mov  al,[0x6fa5]
C000:29C2  3C 0A             cmp  al,0x0a
C000:29C4  75 0C             jnz  local_create_C000_29D2
C000:29CC  E8 B5 19          call dreamlink_create_C000_4384
C000:29CF  E9 81 0F          jmp  finish_int21_status_C000_3953
```

Local create opens/mounts the endpoint, searches the directory, allocates a
cluster when needed, writes a 32-byte directory entry, and updates the FAT.

Open (`AH=3D`) parses the filename, branches to DreamLink open `C000:4459` for
endpoint `0x0A`, otherwise mounts the local store, scans the directory, reads
the directory entry fields, and opens a handle.

```asm
service_3D_open_C000_2B84:
; file 0x42B84
C000:2B84  8B 46 00          mov  ax,[bp+0x00]
C000:2B87  A2 86 6F          mov  [0x6f86],al    ; open mode
C000:2B8A  8B F2             mov  si,dx
C000:2B91  E8 63 0E          call parse_filename_C000_39F7
...
C000:2B98  A0 A5 6F          mov  al,[0x6fa5]
C000:2B9B  3C 0A             cmp  al,0x0a
C000:2B9D  75 1E             jnz  local_open_C000_2BBD
C000:2BB1  8B 46 08          mov  ax,[bp+0x08]
C000:2BB4  A3 3D 70          mov  [0x703d],ax
C000:2BB7  E8 9F 18          call dreamlink_open_C000_4459
C000:2BBA  E9 96 0D          jmp  finish_int21_status_C000_3953
```

If open mode bit `0x01` is set for DreamLink, the path turns into
create/truncate by forcing service byte `[6F5F]=3C` and jumping to create.

## Directory Entry Fields

The local directory entry format is DOS-shaped:

| Offset | Use seen here |
| ---: | --- |
| `+0x00..0x0A` | 8.3 filename copied from `6F87`. |
| `+0x0B` | Attribute byte. Bit `0x01` blocks write/delete-like paths. |
| `+0x16..0x17` | Packed time. |
| `+0x18..0x19` | Packed date. |
| `+0x1A..0x1B` | First cluster. |
| `+0x1C..0x1F` | File size. |

The create helper seeds time/date from the existing `INT 21h` date/time
services:

```asm
pack_time_C000_2B44:
C000:2B44  06                push es
C000:2B45  57                push di
C000:2B46  E8 CA 26          call C000:5213      ; get decoded time
...

pack_date_C000_2B5C:
C000:2B5C  06                push es
C000:2B5D  57                push di
C000:2B5E  E8 1B 26          call C000:517C      ; get decoded date
...
```

## Find First / Find Next

Find-first (`AH=4E`) parses the caller pattern, records the selected endpoint in
the DTA at `+0x10`, copies the normalized pattern into `6F87`, mounts the local
store, and starts scanning directory entries. Find-next (`AH=4F`) restores scan
state from the DTA and continues.

```asm
service_4E_find_first_C000_2DE2:
; file 0x42DE2
C000:2DE2  89 0E 70 6F       mov  [0x6f70],cx
C000:2DE6  8B F2             mov  si,dx
C000:2DEC  E8 08 0C          call parse_filename_C000_39F7
...
C000:2DF2  8B 3E 6A 6F       mov  di,[0x6f6a]    ; DTA
C000:2DF6  A0 A5 6F          mov  al,[0x6fa5]
C000:2DF9  88 45 10          mov  [di+0x10],al
...
C000:2E53  C6 06 C1 6E 12    mov  byte [0x6ec1],0x12
C000:2E58  E8 30 0A          call scan_next_dir_entry_C000_388B
```

Find-next uses DTA offsets `+0x10`, `+0x11..0x13`, and the normalized pattern to
restore endpoint and directory scan state.

## Delete, Rename, Attributes, File Date/Time

Delete (`AH=41`) parses the filename, branches to DreamLink delete `C000:4416`
for endpoint `0x0A`, otherwise mounts/scans the local directory and marks the
entry deleted with `0xE5`.

Attributes (`AH=43`) uses `AL=0` to read and `AL!=0` to write the directory
entry attribute byte at `+0x0B`.

File date/time (`AH=57`) uses `AL=0` to return directory entry words at
`+0x16/+0x14` through `CX/DX`, and `AL=1` to write them. The write path sets
dirty flag `[7036]=1`.

Rename (`AH=56`) parses both names, finds the source, checks for collisions, and
updates the 8.3 directory entry name. The local details are queued with the
directory manipulation helpers because the decoded window crosses the shared
directory scan/compare routines.

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:3868`, `388B`, `39F7`, `3B69`, `3CA7`, `3CCD`, `3CFF` | `int21-directory-core.md` | Shared filename parser, mount check, directory scan, and status return helpers. |
| `C000:3194`, `32B1`, `356F`, `37A7` | `int21-file-io.md` | Read/write/seek/attributes internals. |
| `C000:4384`, `4459`, `4416` | `dreamlink-file-core.md` | DreamLink create/open/delete command senders. |
