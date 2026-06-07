# Storage Window Mapping

This slice follows the bank and subblock mapping roots reached from
[`int21-directory-core.md`](int21-directory-core.md),
[`int21-format.md`](int21-format.md), and
[`storage-geometry.md`](storage-geometry.md).

No image assets or string resources are reached in this slice.

## Dynamic Card/Common-Memory Bank Helper

`C000:0239` maps a logical paragraph offset in `DX` onto the CPU bank latches
for the two adjacent 8 KiB windows controlled by ports `0x14` and `0x15`. The
helper chooses descending bank values, stores mirrors in `6D8F..6D91`, writes
ports `0x15` and `0x14`, and returns with `DX` reduced to the residual offset
within the selected bank pair.

```asm
card_bank_helper_C000_0239:
; file 0x40239
C000:0239  81 FA 00 60       cmp  dx,0x6000
C000:023D  72 22             jc   bank_range_0000_5FFF_C000_0261
C000:023F  81 FA 00 80       cmp  dx,0x8000
C000:0243  72 22             jc   bank_range_6000_7FFF_C000_0267
C000:0245  81 FA 00 A0       cmp  dx,0xa000
C000:0249  72 26             jc   bank_range_8000_9FFF_C000_0271
C000:024B  81 FA 00 C0       cmp  dx,0xc000
C000:024F  72 2A             jc   bank_range_A000_BFFF_C000_027B
C000:0251  81 FA 00 E0       cmp  dx,0xe000
C000:0255  72 2E             jc   bank_range_C000_DFFF_C000_0285
C000:0257  B4 18             mov  ah,0x18
C000:0259  B0 18             mov  al,0x18
C000:025B  81 EA 00 A0       sub  dx,0xa000
```

The selected bank-pair table is:

| Input `DX` range | Port `0x14` value | Port `0x15` value | Residual adjustment |
| ---: | ---: | ---: | ---: |
| `0000..5FFF` | `0x1D` | `0x1C` | none |
| `6000..7FFF` | `0x1C` | `0x1B` | `DX -= 0x2000` |
| `8000..9FFF` | `0x1B` | `0x1A` | `DX -= 0x4000` |
| `A000..BFFF` | `0x1A` | `0x19` | `DX -= 0x6000` |
| `C000..DFFF` | `0x19` | `0x18` | `DX -= 0x8000` |
| `E000..FFFF` | `0x18` | `0x18` | `DX -= 0xA000` |

```asm
commit_bank_pair_C000_028D:
C000:028D  53                push bx
C000:028E  8B 1E 8F 6D       mov  bx,[0x6d8f]
C000:0292  8A DC             mov  bl,ah
C000:0294  89 1E 8F 6D       mov  [0x6d8f],bx
C000:0298  5B                pop  bx
C000:0299  A2 91 6D          mov  [0x6d91],al
C000:029C  E6 15             out  0x15,al
C000:029E  8A C4             mov  al,ah
C000:02A0  E6 14             out  0x14,al
C000:02A2  C3                ret
```

This helper never selects a separate attribute-memory window. In the storage
paths decoded so far, it is reached only after common-memory offsets have
already been computed.

## Logical Sector To CPU Window

`C000:2D44` maps the filesystem position `[6F54]` plus subblock `[6F56]` into
`[6FA6]:DI`. Each logical unit has 32 subblocks, and each subblock is
`0x80` bytes:

```text
byte_offset = (([6F54] * 0x20) + ([6F56] - 1)) * 0x80
DI          = byte_offset & 0x7FFF
DX          = byte_offset >> 15
```

The upper byte range in `DX` becomes a segment adjustment. Built-in storage
adds `0x1800`, PCMCIA SRAM card storage calls `C000:0239` and then adds
`0x4000`, and DreamLink's transfer window adds `0x0580`.

```asm
map_current_sector_C000_2D44:
; file 0x42D44
C000:2D44  A1 54 6F          mov  ax,[0x6f54]
C000:2D47  BB 20 00          mov  bx,0x0020
C000:2D4A  F7 E3             mul  bx
C000:2D4C  8A 1E 56 6F       mov  bl,[0x6f56]
C000:2D50  B7 00             mov  bh,0
C000:2D52  4B                dec  bx
C000:2D53  03 C3             add  ax,bx
C000:2D55  BB 80 00          mov  bx,0x0080
C000:2D58  F7 E3             mul  bx
C000:2D5A  8B F8             mov  di,ax
C000:2D5C  81 E7 FF 7F       and  di,0x7fff
C000:2D60  D1 E0             shl  ax,1
C000:2D62  D1 D2             rcl  dx,1
C000:2D64  B1 0B             mov  cl,0x0b
C000:2D66  D3 E2             shl  dx,cl
```

```asm
select_storage_segment_C000_2D68:
C000:2D68  80 3E A5 6F 0A    cmp  byte [0x6fa5],0x0a
C000:2D6D  74 19             jz   dreamlink_window_C000_2D88
C000:2D6F  F6 06 A5 6F 01    test byte [0x6fa5],0x01
C000:2D74  74 09             jz   built_in_window_C000_2D7F
C000:2D76  E8 C0 D4          call card_bank_helper_C000_0239
C000:2D79  81 C2 00 40       add  dx,0x4000
C000:2D7D  EB 04             jmp  store_window_segment_C000_2D83
C000:2D7F  81 C2 00 18       add  dx,0x1800
C000:2D83  89 16 A6 6F       mov  [0x6fa6],dx
C000:2D87  C3                ret
C000:2D88  81 C2 80 05       add  dx,0x0580
C000:2D8C  EB F5             jmp  store_window_segment_C000_2D83
```

The PCMCIA branch therefore accesses ordinary memory at `ES=[6FA6]`,
`DI=offset`; there is no CIS tuple walk, even-byte attribute addressing, or
port write that would switch to card attribute space.

## Format-Time Block Verify And Fill

`C000:2D02` is the low-level block clear used by the formatter. It maps
subblock `1`, then for 32 consecutive 128-byte blocks write-tests the first
word with `0x5EA6` and byte-swapped `0xA65E`. If both reads match, it fills the
block with `0xE5E5`; otherwise it reports status `0x13`.

```asm
format_clear_verify_block_C000_2D02:
; file 0x42D02
C000:2D02  C6 06 56 6F 01    mov  byte [0x6f56],1
C000:2D07  E8 3A 00          call map_current_sector_C000_2D44
C000:2D0A  B0 E5             mov  al,0xe5
C000:2D0C  8A E0             mov  ah,al
C000:2D0F  B9 20 00          mov  cx,0x0020
C000:2D12  BB A6 5E          mov  bx,0x5ea6
C000:2D16  8E 06 A6 6F       mov  es,[0x6fa6]
C000:2D1B  B9 40 00          mov  cx,0x0040
C000:2D1E  26 89 1D          mov  [es:di],bx
C000:2D21  26 39 1D          cmp  [es:di],bx
C000:2D26  86 DF             xchg bh,bl
C000:2D28  26 89 1D          mov  [es:di],bx
C000:2D2B  26 39 1D          cmp  [es:di],bx
C000:2D32  AB                stosw
...
C000:2D3D  C6 06 C1 6E 13    mov  byte [0x6ec1],0x13
```

## FAT And Root Initialization

`C000:2D8E` initializes the FAT area for the newly formatted store. It maps
`[6F54]=0`, `[6F56]=2`, writes the reserved FAT12-style leading entries
`FFF9 FF00`, then clears the remaining table based on `[6FAA]`.

```asm
init_fat_area_C000_2D8E:
; file 0x42D8E
C000:2D8E  06                push es
C000:2D8F  8E 06 A3 6F       mov  es,[0x6fa3]
C000:2D93  C7 06 54 6F 0000  mov  word [0x6f54],0
C000:2D99  C6 06 56 6F 02    mov  byte [0x6f56],2
C000:2D9E  E8 A3 FF          call map_current_sector_C000_2D44
C000:2DA2  B8 F9 FF          mov  ax,0xfff9
C000:2DA5  AB                stosw
C000:2DA6  B8 FF 00          mov  ax,0x00ff
C000:2DA9  AB                stosw
C000:2DAA  8B 0E AA 6F       mov  cx,[0x6faa]
C000:2DB8  33 C0             xor  ax,ax
C000:2DBA  F3 AB             rep  stosw
C000:2DBC  07                pop  es
C000:2DBD  C3                ret
```

`C000:2DBE` clears four root-directory entries at the mapped sector by writing
`0xE5` as the first byte and filling the rest of each 32-byte entry with
`0xE5E5`.

```asm
clear_root_entries_C000_2DBE:
; file 0x42DBE
C000:2DBE  06                push es
C000:2DBF  8E 06 A3 6F       mov  es,[0x6fa3]
C000:2DC3  E8 7E FF          call map_current_sector_C000_2D44
C000:2DC6  B9 04 00          mov  cx,0x0004
C000:2DCA  32 DB             xor  bl,bl
C000:2DCC  B7 E5             mov  bh,0xe5
C000:2DD2  26 89 1D          mov  [es:di],bx
C000:2DD5  47                inc  di
C000:2DD6  47                inc  di
C000:2DD8  B9 0F 00          mov  cx,0x000f
C000:2DDB  F3 AB             rep  stosw
```

## State Boundary

| RAM/Port | Meaning |
| ---: | --- |
| `6D8F..6D91` | Mirrors for bank ports `0x14` and `0x15`. |
| `6F54` | Logical sector/group index. |
| `6F56` | One-based 128-byte subblock within the 32-subblock group. |
| `6FA3` | Base segment for direct built-in/card/DreamLink window operations. |
| `6FA5` | Active endpoint: `0x08` built-in, `0x09` PCMCIA SRAM, `0x0A` DreamLink. |
| `6FA6` | Computed segment for the current mapped subblock. |
| `6FAA` | FAT/cluster count used while initializing or scanning the local filesystem. |
| `0x14`, `0x15` | Bank select ports adjusted by `C000:0239` for the card/common-memory window. |

Local read/write consumers are expanded in [`int21-file-io.md`](int21-file-io.md).
Formatter progress output is expanded in
[`format-status-output.md`](format-status-output.md).
