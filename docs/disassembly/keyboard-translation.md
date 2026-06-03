# Keyboard Translation Tables

This slice follows the event translation helper reached from
[`keyboard-services.md`](keyboard-services.md). It decodes the table selection
logic and the ROM tables copied into RAM during keyboard setup.

No image assets or string resources are reached in this slice.

## Event Translator

`C000:5915` receives the raw key index in `DL` and modifier/status bits in
`DH`. It returns the translated key code in `AL`.

```asm
translate_key_event_C000_5915:
; file 0x45915
C000:5915  32 FF             xor  bh,bh
C000:5917  F6 06 51 6D 01    test byte [0x6d51],0x01
C000:591C  75 6D             jnz  direct_table_C000_598B
C000:591E  F6 06 51 6D 08    test byte [0x6d51],0x08
C000:5923  75 70             jnz  ram_table_mode_C000_5995
C000:5925  F6 C6 80          test dh,0x80
C000:5928  75 30             jnz  high_modifier_C000_595A
```

In the ordinary path, the upper nibble of `DH` selects a class through
`C000:5A57`. That class is passed to `C000:5A07`, which indexes the ROM pointer
table rooted at `C000:53D7` and returns one byte for key index `DL`.

```asm
normal_table_mode_C000_5936:
C000:5936  B1 04             mov  cl,4
C000:5938  D2 EE             shr  dh,cl
C000:593A  8A DE             mov  bl,dh
C000:593C  2E 8A 87 57 5A    mov  al,[cs:bx+0x5a57]
C000:5941  E8 C3 00          call table_lookup_C000_5A07
C000:5944  3C 0C             cmp  al,0x0c
C000:5946  75 05             jnz  translated_C000_594D
C000:5948  80 36 73 76 40    xor  byte [0x7673],0x40
C000:594D  C3                ret
```

If `DH bit 0x40` is set and `[6EB4] != 0`, the same class selection is forced
through class `0x0E`; the translated byte is cached in `[6DAA]`, and `AL=EC`
is returned as the foreground event marker.

```asm
latched_special_C000_594E:
C000:594E  B0 0E             mov  al,0x0e
C000:5951  E8 B3 00          call table_lookup_C000_5A07
C000:5954  A2 AA 6D          mov  [0x6daa],al
C000:5957  B0 EC             mov  al,0xec
C000:5959  C3                ret
```

## Alternate Paths

When `DH bit 0x80` is set without `DH bit 0x40`, translation comes from the
RAM table at `[7055 + DL]`.

```asm
high_modifier_C000_595A:
C000:595A  8A DA             mov  bl,dl
C000:595C  F6 C6 40          test dh,0x40
C000:595F  75 05             jnz  rom_special_C000_5966
C000:5961  8A 87 55 70       mov  al,[bx+0x7055]
C000:5965  C3                ret
```

With both high modifier bits set, the code indexes a ROM table selected by the
word pointer at `C000:53D7`. Two table values receive special returns:
`0x64 -> AL=F5` and `0x76 -> AL=1A`. Any other value clears `[70E9]` and
returns `AL=FF`.

```asm
rom_special_C000_5966:
C000:5966  BB D7 53          mov  bx,0x53d7
C000:5969  2E 8B 07          mov  ax,[cs:bx]
C000:596C  8A DA             mov  bl,dl
C000:596E  32 FF             xor  bh,bh
C000:5970  03 D8             add  bx,ax
C000:5972  2E 8A 07          mov  al,[cs:bx]
C000:5975  3C 64             cmp  al,0x64
C000:5977  74 0C             jz   return_f5_C000_5985
C000:5979  3C 76             cmp  al,0x76
C000:597B  74 0B             jz   return_ctrl_z_C000_5988
C000:597D  C6 06 E9 70 00    mov  byte [0x70e9],0
C000:5982  B0 FF             mov  al,0xff
C000:5984  C3                ret
```

When `[6D51] bit 0` is set, the translator uses the direct 80-byte table at
`C000:59B7 + DL`. When `[6D51] bit 3` is set, it selects a RAM table through
the word pointers at `6814..681E`, unless the high-modifier path redirects to
the ROM special path above.

```asm
direct_table_C000_598B:
C000:598B  8A DA             mov  bl,dl
C000:598D  81 C3 B7 59       add  bx,0x59b7
C000:5991  2E 8A 07          mov  al,[cs:bx]
C000:5994  C3                ret

ram_table_mode_C000_5995:
C000:5995  F6 C6 40          test dh,0x40
C000:5998  74 05             jz   ram_select_C000_599F
C000:599A  F6 C6 80          test dh,0x80
C000:599D  75 C7             jnz  rom_special_C000_5966
C000:599F  B1 04             mov  cl,4
C000:59A1  D2 EE             shr  dh,cl
C000:59A3  8A DE             mov  bl,dh
C000:59A5  2E 8A 87 57 5A    mov  al,[cs:bx+0x5a57]
C000:59AA  8A D8             mov  bl,al
C000:59AC  8B 87 14 68       mov  ax,[bx+0x6814]
C000:59B0  8A DA             mov  bl,dl
C000:59B2  03 D8             add  bx,ax
C000:59B4  8A 07             mov  al,[bx]
C000:59B6  C3                ret
```

## Class Table

`C000:5A57` maps the upper nibble of `DH` to a table class. The class values
are byte offsets used by `C000:5A07` and by the RAM pointer table at
`6814..681E`.

```text
offset C000:5A57:
  00 02 06 08 0A 0A 0A 0A 04 04 04 04 04 04 04 04
format:
  class_index[16]
```

## ROM And RAM Tables

`C000:5A2F` copies `0x01E0` bytes from `C000:53E9` to `0000:6826`, then
initializes six word pointers at `6814..681E`. Each table is `0x50` bytes.

```text
RAM table pointers:
  [6814] = 6826
  [6816] = 6876
  [6818] = 68C6
  [681A] = 6916
  [681C] = 6966
  [681E] = 69B6
```

The first two ROM tables copied from `C000:53E9` are the lower-case and shifted
printable maps for the 80 key indexes:

```text
C000:53E9 table 0:
  FF FF FF 11 DA FF FF FF FF 60 03 20 FF FF 35 FF
  FF 0C 31 09 FF FF FF FF 33 32 71 77 65 FF 73 64
  34 FF 7A 78 61 FF 72 66 FF FF 62 76 74 79 67 63
  36 12 0D 10 5C 2F 68 6E 3D 37 02 13 0B 75 6D 6B
  38 2D 5D 5B 27 69 6A 2C 30 39 08 70 3B 6C 6F 2E

C000:5439 table 1:
  FF FF FF 11 DA FF FF FF FF 7E 03 20 FF FF 25 FF
  FF 0C 21 09 FF FF FF FF 23 40 51 57 45 FF 53 44
  24 FF 5A 58 41 FF 52 46 FF FF 42 56 54 59 47 43
  5E 12 0D 10 7C 3F 48 4E 2B 26 02 13 0B 55 4D 4B
  2A 5F 7D 7B 22 49 4A 3C 29 28 08 50 3A 4C 4F 3E
```

`C000:5A16` copies another 80-byte ROM table from `C000:5489` to RAM `7055`.
That is the table used by the `DH bit 0x80` path.

```text
C000:5489 -> RAM 7055:
  FF FF FF FD FF FF FF FF FF FF 03 D9 FF FF F6 FF
  FF FF 14 FF FF FF FF FF 17 15 A0 82 A1 FF 8A 8D
  16 FF 83 88 85 FF A2 95 FF FF 96 93 A3 84 97 8C
  F9 DD E4 FE FF FF 87 80 F3 F7 FF DE FF 81 A5 B1
  F8 E6 FF FF FF 8B A4 FF 1F F0 06 89 FF 9C 94 FF
```

The direct table used by `[6D51] bit 0` lives at `C000:59B7`:

```text
C000:59B7 direct table:
  2B 36 00 3E 1D 00 00 00 38 39 01 3B 00 00 06 00
  1E 3A 02 10 00 00 00 00 04 03 11 12 13 00 20 21
  05 00 2C 2D 1F 00 14 22 00 00 30 2F 15 16 23 2E
  07 40 0E 3F 2A 35 24 31 0D 08 3C 37 3D 17 32 26
  09 0C 1C 1B 29 18 25 33 0B 0A 0F 1A 28 27 19 34
```

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6814..681E` | Six word pointers to 80-byte RAM key tables at `6826..69B6`. |
| `6D51 bit 0` | Enables direct ROM table `C000:59B7`. |
| `6D51 bit 3` | Enables RAM-table mode through pointers at `6814..681E`. |
| `6DAA` | Cached translated byte for the `AL=EC` special path. |
| `6EB4` | Special translation-mode flag checked when `DH bit 0x40` is set. |
| `7055..70A4` | 80-byte RAM table copied from `C000:5489`. |
| `70E9` | Cleared when the high-modifier ROM-special path returns `AL=FF`. |
| `7673 bit 0x40` | Toggled when the normal path returns key code `0x0C`. |

