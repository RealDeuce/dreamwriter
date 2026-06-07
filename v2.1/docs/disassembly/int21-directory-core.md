# INT 21h Directory Core

This slice follows the shared directory, filename, FAT12, and volume-header
helpers reached from [`int21-filesystem-front.md`](int21-filesystem-front.md),
[`int21-file-io.md`](int21-file-io.md), and [`int21-format.md`](int21-format.md).

No image assets or string resources are reached in this slice.

## Directory Scan

`C000:3868` initializes a root-directory scan. It seeds status `[6EC1]=2`,
starts with four entries per sector, calls the root-position helper at
`C000:3B01`, maps the current sector through `C000:2D44`, and then walks
32-byte directory entries.

```asm
directory_scan_init_C000_3868:
; file 0x43868
C000:3868  C6 06 C1 6E 02    mov  byte [0x6ec1],0x02
C000:386D  C7 06 5D 6F 20 00 mov  word [0x6f5d],0x0020
C000:3873  E8 8B 02          call root_position_C000_3B01
C000:3880  C7 06 5B 6F 04 00 mov  word [0x6f5b],0x0004
C000:3886  E8 BB F4          call map_current_sector_C000_2D44

directory_scan_next_C000_388B:
C000:388B  83 3E 5D 6F 00    cmp  word [0x6f5d],0
C000:3892  89 36 6E 6F       mov  [0x6f6e],si
C000:3897  8E 06 A3 6F       mov  es,[0x6fa3]
C000:389B  26 8A 04          mov  al,[es:si]
C000:389F  0A C0             or   al,al
C000:38A1  74 7F             jz   directory_end_C000_3922
C000:38A3  3C E5             cmp  al,0xe5
C000:38A5  75 20             jnz  compare_entry_name_C000_38C7
```

The scan treats first byte `0x00` as end-of-directory and `0xE5` as deleted.
When create mode (`[6F5F] == 0x3C`) sees the first deleted slot, it records the
slot location in `[6F7B]`, `[6F7D]`, and `[6F80]` so create/truncate can reuse
it.

The scan advances by `0x20` bytes and rolls to the next mapped sector every four
entries:

```asm
C000:38F6  83 C6 20          add  si,0x20
C000:38F9  FF 0E 5B 6F       dec  word [0x6f5b]
C000:3905  FF 0E 5D 6F       dec  word [0x6f5d]
C000:391F  E9 64 FF          jmp  C000:3886
```

## Status Returns

`C000:393D` and `C000:3953` are the common DOS-style status finishers used by
front-end services. If `[6EC1]` is nonzero, they copy it to caller `AX` and set
carry. Otherwise they return the logical handle/index byte `[6FAF]`.

```asm
finish_status_plain_C000_393D:
; file 0x4393D
C000:393D  A1 C1 6E          mov  ax,[0x6ec1]
C000:3942  74 05             jz   success_C000_3949
C000:3944  89 46 00          mov  [bp+0],ax
C000:3947  F9                stc
C000:3948  C3                ret

success_C000_3949:
C000:3949  A0 AF 6F          mov  al,[0x6faf]
C000:394E  89 46 00          mov  [bp+0],ax
C000:3951  F8                clc
C000:3952  C3                ret
```

`C000:3953` is the same pattern with an extra handle-to-endpoint bookkeeping
write into the table at `703F + returned_index`.

## FAT12 Helpers

The file I/O slice reaches the FAT12 helpers here. `C000:3994` maps a file
cluster number to a sector and sub-entry position; `C000:39BA` computes the
FAT12 byte offset `cluster * 3 / 2`; `C000:39C9` reads the 12-bit FAT entry and
stores the next cluster in `[6F57]`.

```asm
cluster_to_sector_C000_3994:
; file 0x43994
C000:3994  A1 57 6F          mov  ax,[0x6f57]
C000:3997  48                dec  ax
C000:3998  48                dec  ax
...
C000:39A9  BB 20 00          mov  bx,0x0020
C000:39AC  F7 F3             div  bx
C000:39B6  E8 8B F3          call map_current_sector_C000_2D44

fat12_offset_C000_39BA:
C000:39BA  A1 57 6F          mov  ax,[0x6f57]
C000:39BD  BA 03 00          mov  dx,0x0003
C000:39C0  F7 E2             mul  dx
C000:39C2  D1 E8             shr  ax,1
C000:39C4  03 06 84 6F       add  ax,[0x6f84]
C000:39C8  C3                ret

fat12_read_next_C000_39C9:
C000:39C9  E8 EE FF          call fat12_offset_C000_39BA
...
C000:39DD  73 09             jnc  even_cluster_C000_39E8
C000:39DF  D1 E8             shr  ax,1
C000:39E1  D1 E8             shr  ax,1
C000:39E3  D1 E8             shr  ax,1
C000:39E5  D1 E8             shr  ax,1
C000:39E9  25 FF 0F          and  ax,0x0fff
C000:39EC  A3 57 6F          mov  [0x6f57],ax
```

## Filename Parser

`C000:39F7` parses a caller filename at `ES:SI` into the internal 8.3-ish
buffer at `6F87`. For local stores it treats `.` as the extension separator and
pads the name field to eight bytes. For DreamLink endpoint `0x0A`, it accepts
up to twelve characters without the same dot-as-extension behavior, matching
the serial transfer notes in `dreamlink-file-core.md`.

Wildcard `*` fills the remaining name or extension field with `?`. A leading
drive prefix updates `[6FA5]` from the digit before `:`.

```asm
parse_filename_C000_39F7:
; file 0x439F7
C000:39F7  A0 35 6D          mov  al,[0x6d35]
C000:39FA  A2 A5 6F          mov  [0x6fa5],al
...
C000:3A2E  3C 3A             cmp  al,':'         ; drive prefix
C000:3A30  74 6E             jz   set_drive_from_prefix_C000_3AA0
C000:3A32  3C 2A             cmp  al,'*'
C000:3A34  75 03             jnz  normal_char_C000_3A39
...
C000:3A40  3C 2E             cmp  al,'.'
C000:3A42  74 66             jz   extension_separator_C000_3AAA
```

## Volume Header

`C000:3B2B` writes the custom DreamWriter volume header. `C000:3B69` validates
and derives geometry from that header. This is not a stock DOS BPB; the checked
words are:

| Header offset | Meaning |
| ---: | --- |
| `+0x00` | Signature word `0x1997`. |
| `+0x02` | Signature/version word `0x0126`. |
| `+0x04` | Geometry count. Built-in storage forces `5`; card storage stores detected `[6FAD]`. |

```asm
write_volume_header_C000_3B2B:
; file 0x43B2B
C000:3B31  50                push ax
C000:3B32  A1 A3 6F          mov  ax,[0x6fa3]
C000:3B3D  C7 06 00 00 97 19 mov  word [0],0x1997
C000:3B43  C7 06 02 00 26 01 mov  word [2],0x0126
C000:3B49  A3 04 00          mov  [4],ax
...
C000:3B4E  C7 06 04 00 05 00 mov  word [4],0x0005 ; built-in case

mount_check_C000_3B69:
C000:3B69  50                push ax
...
C000:3BBD  A1 04 00          mov  ax,[0x0004]
C000:3BC3  A2 AD 6F          mov  [0x6fad],al
C000:3BC6  D1 E0             shl  ax,1
C000:3BCC  A3 A8 6F          mov  [0x6fa8],ax
```

`C000:3BF2` and `C000:3BF9` are the short header predicates: built-in storage
requires header count `5`; all local stores require `0x1997` and `0x0126`.

## Open-Slot Boundary

`C000:3CBB`, `C000:3CCD`, and `C000:3CFF` initialize, allocate, and populate
the four-entry open-file slot table at `6FB2` and `6FB6`. The handle-specific
logic continues in [`int21-handle-core.md`](int21-handle-core.md).

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6EC1` | Current filesystem status/error byte. |
| `6F54`, `6F56` | Current sector/subsector position for directory/FAT scanning. |
| `6F57` | Current FAT cluster. |
| `6F5B`, `6F5D` | Per-sector entry countdown and directory-sector countdown. |
| `6F87..` | Parsed filename buffer. |
| `6FA3` | Current endpoint segment/window: `1800`, `4000`, or `0580`. |
| `6FA5` | Current endpoint/drive byte: `08`, `09`, or `0A`. |
| `6FAD` | Header/card geometry count. |

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:2D44`, `C000:0239` | `storage-window-mapping.md` | Sector/window bank mapping used by local storage and card access. |
| `C000:3D52..3F27`, `C000:4064` | [`int21-handle-core.md`](int21-handle-core.md) | Handle resolution, close, position, and directory-entry writeback. |
