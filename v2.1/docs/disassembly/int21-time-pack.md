# INT 21h Time And Date Packing

This slice follows the small DOS date/time packing helpers reached from
directory-entry writeback and DreamLink create/truncate paths.

No image assets or string resources are reached in this slice.

## Directory Timestamp Pair

`C000:2B35` writes a FAT-style time word followed by a FAT-style date word. The
words are cached in RAM and also written to the caller's `ES:DI` buffer through
`STOSW`.

```asm
pack_timestamp_pair_C000_2B35:
; file 0x42B35
C000:2B35  E8 0C 00          call pack_time_C000_2B44
C000:2B38  A3 9B 6F          mov  [0x6f9b],ax
C000:2B3B  AB                stosw
C000:2B3C  E8 1D 00          call pack_date_C000_2B5C
C000:2B3F  A3 99 6F          mov  [0x6f99],ax
C000:2B42  AB                stosw
C000:2B43  C3                ret
```

## Time Word

`C000:2B44` calls the current-time service at `C000:5213`, preserving the
caller's `ES:DI` around that call. The return convention matches DOS `AH=2C`:
`CH=hour`, `CL=minute`, `DH=second`.

```asm
pack_time_C000_2B44:
; file 0x42B44
C000:2B44  06                push es
C000:2B45  57                push di
C000:2B46  E8 CA 26          call current_time_C000_5213
C000:2B49  5F                pop  di
C000:2B4A  07                pop  es
C000:2B4B  D0 E1             shl  cl,1
C000:2B4D  D0 E1             shl  cl,1
C000:2B4F  D1 E1             shl  cx,1
C000:2B51  D1 E1             shl  cx,1
C000:2B53  D1 E1             shl  cx,1
C000:2B55  D0 EE             shr  dh,1
C000:2B57  0A CE             or   cl,dh
C000:2B59  8B C1             mov  ax,cx
C000:2B5B  C3                ret
```

Packed format:

```text
u16le fat_time = (hour << 11) | (minute << 5) | (second / 2)
```

## Date Word

`C000:2B5C` calls the current-date service at `C000:517C`, preserving
`ES:DI`. The return convention matches DOS `AH=2A`: `CX=year`, `DH=month`,
`DL=day`.

```asm
pack_date_C000_2B5C:
; file 0x42B5C
C000:2B5C  06                push es
C000:2B5D  57                push di
C000:2B5E  E8 1B 26          call current_date_C000_517C
C000:2B61  5F                pop  di
C000:2B62  07                pop  es
C000:2B63  81 E9 BC 07       sub  cx,0x07bc
C000:2B67  83 F9 64          cmp  cx,0x0064
C000:2B6A  72 03             jc   year_offset_ok_C000_2B6F
C000:2B6C  83 E9 64          sub  cx,0x0064
C000:2B6F  8A E1             mov  ah,cl
C000:2B71  32 C0             xor  al,al
C000:2B73  D1 E0             shl  ax,1
C000:2B75  8A EA             mov  ch,dl
C000:2B77  B2 00             mov  dl,0
C000:2B79  D1 EA             shr  dx,1
C000:2B7B  D1 EA             shr  dx,1
C000:2B7D  D1 EA             shr  dx,1
C000:2B7F  0A D5             or   dl,ch
C000:2B81  0B C2             or   ax,dx
C000:2B83  C3                ret
```

Packed format:

```text
year_offset = year - 1980
if year_offset >= 100: year_offset -= 100
u16le fat_date = (year_offset << 9) | (month << 5) | day
```

The extra `-100` branch makes years `>= 2080` wrap into the FAT 7-bit year
field instead of overflowing into the month bits.

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6F99` | Last packed FAT date word. |
| `6F9B` | Last packed FAT time word. |

