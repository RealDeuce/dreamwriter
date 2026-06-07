# INT 21h Private Format Service

This slice follows private `INT 21h AH=FF`, reached directly from
[`int21-dispatch.md`](int21-dispatch.md). The service requires `BL=A5` and uses
`DL` to select built-in RAM storage, PCMCIA SRAM card storage, or DreamLink.

No image assets are reached in this slice.

## Service Selector

```asm
private_format_C000_2C4A:
; file 0x42C4A
C000:2C4A  C6 06 36 70 01    mov  byte [0x7036],1
C000:2C4F  88 16 A5 6F       mov  [0x6fa5],dl
C000:2C53  80 FB A5          cmp  bl,0xa5
C000:2C56  75 38             jnz  format_return_C000_2C90
C000:2C58  80 FA 08          cmp  dl,0x08
C000:2C5B  74 36             jz   format_builtin_C000_2C93
C000:2C5D  80 FA 09          cmp  dl,0x09
C000:2C60  74 12             jz   format_card_C000_2C74
C000:2C62  80 FA 0A          cmp  dl,0x0a
C000:2C65  75 06             jnz  bad_format_drive_C000_2C6D
C000:2C67  E8 42 1B          call dreamlink_format_C000_47AC
C000:2C6A  E9 92 00          jmp  finish_format_C000_2CFF
```

| `DL` | Target | Effect |
| ---: | --- | --- |
| `08` | `C000:2C93` | Built-in RAM store at segment/window `0x1800`; forced geometry count `5`. |
| `09` | `C000:2C74` | PCMCIA SRAM card store at segment/window `0x4000`; card access/write checks and capacity probe. |
| `0A` | `C000:2C67` | DreamLink initialize/format command sender `C000:47AC`. |

Invalid selector or failed validation reports through `[6EC1]`, then returns
through shared status finalizer `C000:393D`.

## Card Path

```asm
format_card_C000_2C74:
C000:2C74  C7 06 A3 6F 0040  mov  word [0x6fa3],0x4000
C000:2C7A  E8 2A 10          call card_write_check_C000_3CA7
C000:2C7D  72 11             jc   format_return_C000_2C90
C000:2C7F  E8 86 0F          call card_capacity_probe_C000_3C08
C000:2C82  72 0C             jc   format_return_C000_2C90
C000:2C84  80 3E AD 6F 00    cmp  byte [0x6fad],0
C000:2C89  75 19             jnz  write_format_structures_C000_2CA4
C000:2C8B  C6 06 C1 6E 13    mov  byte [0x6ec1],0x13
```

The capacity probe `C000:3C08` uses common-memory card access. It calls the card
presence/access helper `C000:0AC4`, maps/test-writes successive 32 KiB card
windows, and records the detected count in the same geometry fields used by the
format path. It is not evidence of production attribute-space parsing.

## Built-In Path

```asm
format_builtin_C000_2C93:
C000:2C93  C6 06 36 6D 00    mov  byte [0x6d36],0
C000:2C98  C7 06 A3 6F 0018  mov  word [0x6fa3],0x1800
C000:2C9E  BB 05 00          mov  bx,0x0005
C000:2CA1  E8 D2 0F          call set_geometry_count_C000_3C76
```

The built-in store is forced to five 32 KiB units, i.e. 160 KiB.

## Structure Write Sequence

Both local storage paths converge at `C000:2CA4`.

```asm
write_format_structures_C000_2CA4:
C000:2CA4  E8 84 0E          call write_volume_header_C000_3B2B
C000:2CA7  E8 AF 0E          call clear_header_word0_C000_3B59
C000:2CAA  33 C0             xor  ax,ax
C000:2CAC  A3 54 6F          mov  [0x6f54],ax
C000:2CAF  E8 50 00          call clear_verify_data_block_C000_2D02
C000:2CB2  72 4B             jc   finish_format_C000_2CFF
C000:2CB4  FF 06 54 6F       inc  word [0x6f54]
C000:2CB8  E8 D5 0F          call C000:3C90
...
C000:2CD0  E8 BB 00          call init_fat_C000_2D8E
C000:2CD3  E8 2B 0E          call select_root_dir_C000_3B01
C000:2CD6  C7 06 5D 6F 2000  mov  word [0x6f5d],0x20
...
C000:2CF3  E8 C8 00          call clear_root_dir_sector_C000_2DBE
C000:2CFC  E8 2C 0E          call write_volume_header_C000_3B2B
C000:2CFF  E9 3B 0C          jmp  finish_int21_status_C000_393D
```

The header writer stores custom DreamWriter words, not an IBM/MS-DOS BPB:

```asm
write_volume_header_C000_3B2B:
; file 0x43B2B
C000:3B2B  A0 AD 6F          mov  al,[0x6fad]
C000:3B30  1E                push ds
C000:3B32  A1 A3 6F          mov  ax,[0x6fa3]
C000:3B3A  8E D8             mov  ds,ax
C000:3B3D  C7 06 00 00 9719  mov  word [0x0000],0x1997
C000:3B43  C7 06 02 00 2601  mov  word [0x0002],0x0126
C000:3B49  A3 04 00          mov  [0x0004],ax
C000:3B4C  75 06             jnz  C000:3B54
C000:3B4E  C7 06 04 00 0500  mov  word [0x0004],0x0005
```

## Block Mapping And Clear/Verify

`C000:2D44` converts logical block state `[6F54]` and `[6F56]` into a segment
window `[6FA6]` and offset `DI`. Built-in uses `0x1800+`, card uses `0x4000+`
after calling the card-bank helper `C000:0239`, and DreamLink-like paths use
`0x0580+`.

```asm
map_format_block_C000_2D44:
C000:2D44  A1 54 6F          mov  ax,[0x6f54]
C000:2D47  BB 20 00          mov  bx,0x20
C000:2D4A  F7 E3             mul  bx
C000:2D4C  8A 1E 56 6F       mov  bl,[0x6f56]
...
C000:2D5A  8B F8             mov  di,ax
C000:2D5C  81 E7 FF 7F       and  di,0x7fff
...
C000:2D6F  F6 06 A5 6F 01    test byte [0x6fa5],0x01
C000:2D74  74 09             jz   C000:2D7F
C000:2D76  E8 C0 D4          call card_bank_helper_C000_0239
C000:2D79  81 C2 00 40       add  dx,0x4000
C000:2D7F  81 C2 00 18       add  dx,0x1800
C000:2D83  89 16 A6 6F       mov  [0x6fa6],dx
```

`C000:2D02` write-tests each target block with `0x5EA6` and byte-swapped
`0xA65E`, then fills it with `0xE5`. Failure reports error `0x13`.

## FAT And Root Directory Initialization

`C000:2D8E` initializes the FAT12 table with the reserved entries and zeroes the
rest based on `[6FAA]`. `C000:2DBE` clears root directory sectors by writing
`0xE5`-filled entries.

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:3C08`, `C000:3C76`, `C000:3C90` | `storage-geometry.md` | Card capacity and geometry helpers. |
| `C000:3B01`, `3B2B`, `3B59`, `3B69`, `3BF2`, `3BF9` | `int21-directory-core.md` | Header mount/validation and root directory selection. |
| `C000:47AC` | `dreamlink-file-core.md` | DreamLink initialize/format command. |
