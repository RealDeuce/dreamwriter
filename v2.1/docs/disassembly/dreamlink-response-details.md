# DreamLink Response Details

This slice expands the DreamLink response helpers referenced by
[`dreamlink-file-core.md`](dreamlink-file-core.md). It stays in protocol and
directory-entry translation code; no menu or application handler is entered.

No image assets or string resources are reached in this slice. Inline byte
records are protocol templates, not display resources.

## Scratch Clearing

`C000:3F58` clears the nine response scratch bytes `704C..7054` and preserves
`AX`.

```asm
clear_response_scratch_C000_3F58:
; file 0x43F58
C000:3F58  50                push ax
C000:3F59  32 C0             xor  al,al
C000:3F5B  A2 4C 70          mov  [0x704c],al
C000:3F5E  A2 4D 70          mov  [0x704d],al
C000:3F61  A2 4E 70          mov  [0x704e],al
C000:3F64  A2 4F 70          mov  [0x704f],al
C000:3F67  A2 50 70          mov  [0x7050],al
C000:3F6A  A2 51 70          mov  [0x7051],al
C000:3F6D  A2 52 70          mov  [0x7052],al
C000:3F70  A2 53 70          mov  [0x7053],al
C000:3F73  A2 54 70          mov  [0x7054],al
C000:3F76  58                pop  ax
C000:3F77  C3                ret
```

## Strict Handshake

`C000:3F8C` is the strict startup handshake used before command `47`. It clears
scratch, sends `13 18 11`, then requires the exact host response
`13 18 06 11`.

```asm
strict_handshake_C000_3F8C:
; file 0x43F8C
C000:3F8C  E8 C9 FF          call clear_response_scratch_C000_3F58
C000:3F8F  E8 E6 FF          call send_dreamlink_prefix_C000_3F78
C000:3F92  56                push si
C000:3F93  BE 89 3F          mov  si,0x3f89
C000:3F96  E8 1E CF          call send_inline_bytes_C000_0EB7
C000:3F99  5E                pop  si
...
C000:3FA7  A2 4F 70          mov  [0x704f],al
C000:3FAA  3C 13             cmp  al,0x13
...
C000:3FB3  A2 50 70          mov  [0x7050],al
C000:3FB6  3C 18             cmp  al,0x18
...
C000:3FBF  A2 52 70          mov  [0x7052],al
C000:3FC2  3C 06             cmp  al,0x06
...
C000:3FCB  A2 54 70          mov  [0x7054],al
C000:3FCE  3C 11             cmp  al,0x11
```

Protocol template:

```text
offset C000:3F89: 02 18 11
format: count=2, bytes=18 11
final frame after prefix: 13 18 11
expected response: 13 18 06 11
```

Any mismatch stores filesystem/protocol status `0x18` in `[6EC1]` and returns
carry set. Serial timeout/read failure returns carry set without overwriting
the mismatch code path.

## Shared Response Parser

`C000:4082` clears scratch, receives a prefix byte, and returns success if the
byte is not `0x13`. A real DreamLink response must be `13 <command> ...`, where
`<command>` matches `[7037]`.

```asm
dreamlink_response_C000_4082:
; file 0x44082
C000:4082  E8 D3 FE          call clear_response_scratch_C000_3F58
C000:4085  E8 B6 CD          call serial_recv_byte_C000_0E3E
C000:408A  A2 4F 70          mov  [0x704f],al
C000:408D  3C 13             cmp  al,0x13
C000:408F  74 02             jz   response_prefix_ok_C000_4093
C000:4091  F8                clc
C000:4092  C3                ret
C000:4093  E8 A8 CD          call serial_recv_byte_C000_0E3E
C000:4098  A2 50 70          mov  [0x7050],al
C000:409B  3A 06 37 70       cmp  al,[0x7037]
```

Unexpected command byte `06` or `0F` is treated as an ACK/status shortcut:
`C000:411C` reads one more byte into `[7054]` and the parser returns carry
clear. Other unexpected command bytes also return carry clear after storing the
byte in `[7050]`.

For the expected command, the next byte is status `[7051]`.

```asm
expected_response_C000_40BB:
C000:40BB  E8 80 CD          call serial_recv_byte_C000_0E3E
C000:40C0  A2 51 70          mov  [0x7051],al
C000:40C3  C7 06 3B 70 0000  mov  word [0x703b],0
C000:40C9  3C 00             cmp  al,0
C000:40CB  74 16             jz   parse_success_payload_C000_40E3
C000:40CD  E8 6E CD          call serial_recv_byte_C000_0E3E
C000:40D4  A3 3B 70          mov  [0x703b],ax
C000:40D7  A2 52 70          mov  [0x7052],al
C000:40DA  E8 3F 00          call recv_response_trailer_C000_411C
```

Nonzero status stores the detail byte in `[7052]` and `[703B]`, reads the
trailer into `[7054]`, then returns carry set with `AX=0`.

On zero status, `C000:412D` dispatches command-specific payload parsing. After
the payload, commands other than `3F` read one trailer byte into `[7054]`. For
commands outside the known file/probe set, the firmware sends ACK frame
`06 11`.

```text
offset C000:3FE3: 02 06 11
format: count=2, bytes=06 11
final frame: 06 11
```

## Payload Dispatch

`C000:412D` selects success-payload parsing by expected command byte `[7037]`.

| Command | Parser | Effect |
| ---: | --- | --- |
| `13` | return | Delete response has no success payload. |
| `17` | return | Rename response has no success payload. |
| `47` | `C000:4217` | Receive NUL-terminated DreamLink directory/display name into `6F34`, then one extra byte into `7053`. |
| `4E` | `C000:4296` with `[7038]=0` | Parse first compact directory listing page. |
| `4F` | increment `[7038]`, `C000:4296` | Parse next compact directory listing page. |
| `3D` | `C000:44A9` | Receive two-byte handle/return word into `[703B]`. |
| `3E` | return | Close response has no success payload. |
| `3C` | `C000:44A9` | Receive two-byte create return word into `[703B]`. |
| `3F` | return | Read-start success has no parser payload here; stream data is handled separately. |
| `40` | return | Write-start success has no parser payload here. |
| `44` | return | Initialize/format response has no success payload. |

Unknown command sets `AL=1B`, returns carry set, and is converted by the caller
to filesystem/protocol status.

## Directory Name Payload

The command `47` payload parser stores up to 31 bytes of a NUL-terminated name
at `6F34`, then reads one extra byte into `[7053]`.

```asm
dreamlink_name_payload_C000_4217:
; file 0x44217
C000:4217  BA 1F 00          mov  dx,0x001f
C000:421A  BF 34 6F          mov  di,0x6f34
receive_name_byte_C000_421D:
C000:421D  52                push dx
C000:421E  57                push di
C000:421F  E8 1C CC          call serial_recv_byte_C000_0E3E
C000:4224  72 18             jc   name_payload_error_C000_423E
C000:4226  0B D2             or   dx,dx
C000:4228  74 04             jz   name_capacity_full_C000_422E
C000:422A  4A                dec  dx
C000:422B  88 05             mov  [di],al
C000:422D  47                inc  di
C000:422E  0A C0             or   al,al
C000:4230  75 EB             jnz  receive_name_byte_C000_421D
C000:4232  E8 09 CC          call serial_recv_byte_C000_0E3E
C000:4237  A2 53 70          mov  [0x7053],al
```

Payload format:

```text
char name[1..31] NUL
u8 extra -> [7053]
```

## Compact Directory Listing Expansion

`C000:4296` expands a compact host record into a 32-byte directory entry at
`[6FA3]:(page_index << 5)`. `C000:4365` pre-fills the destination before
parsing: offsets `00..0A` are spaces, offset `0B` is left untouched for the
later attribute/status byte, and offsets `0C..0F` are zeroed.

```asm
dreamlink_listing_payload_C000_4296:
; file 0x44296
C000:4296  BA 00 00          mov  dx,0
C000:4299  C6 06 39 70 00    mov  byte [0x7039],0
C000:429E  A0 38 70          mov  al,[0x7038]
C000:42A3  B1 05             mov  cl,5
C000:42A5  D3 E0             shl  ax,cl
C000:42A7  8B D8             mov  bx,ax
C000:42A9  E8 B9 00          call prefill_listing_entry_C000_4365
```

Each received byte is handled by `C000:42CC`, which maps compact positions to
expanded offsets. The parser stops when `42CC` returns zero flag set. It then
reads one extra byte into `[7053]`.

```asm
C000:42AE  E8 8D CB          call serial_recv_byte_C000_0E3E
C000:42B5  E8 14 00          call expand_listing_byte_C000_42CC
C000:42B8  72 0E             jc   listing_payload_parser_error_C000_42C8
C000:42BA  75 F0             jnz  receive_listing_byte_C000_42AC
C000:42BC  E8 7F CB          call serial_recv_byte_C000_0E3E
C000:42C1  A2 53 70          mov  [0x7053],al
```

Compact position mapping:

| Compact position | Expanded offset | Meaning |
| ---: | ---: | --- |
| `0` | `0B` | Attribute/status byte. |
| `1` | `16` | Time/date metadata byte. |
| `2` | `17` | Time/date metadata byte. |
| `3` | `18` | Time/date metadata byte. |
| `4` | `19` | Time/date metadata byte. |
| `5` | `1C` | File size byte. |
| `6` | `1D` | File size byte. |
| `7` | `1E` | File size byte. |
| `8` | `1F` | File size byte. |
| `9..16` | `00..07` | Base filename bytes. |
| `17..20` | `0C..0F` | DreamLink suffix/format bytes. |

Behavior by compact position:

| Position/state | Behavior |
| --- | --- |
| `DX >= 255` | Parser error, carry set. |
| `DX < 9` | Store byte using the fixed metadata mapping above; NUL is stored as data. |
| `DX >= 9`, byte is NUL | End of compact record; return zero flag set. |
| `9 <= DX < 17` | Store byte at expanded offset `DX - 9`. |
| `17 <= DX < 21` | Store byte at expanded offset `DX - 5`. |
| `DX >= 21` | Ignore byte, advance compact position. |

Writes are suppressed if `BX >= 0x1000`, which bounds the directory page window.

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6EC1` | Filesystem/protocol error status. |
| `6F34..` | Command `47` DreamLink name buffer. |
| `6FA3` | Segment for expanded DreamLink directory entries. |
| `7037` | Expected DreamLink response command. |
| `7038` | Listing page index used as `entry_offset >> 5`. |
| `7039` | Cleared before listing expansion; no consumer in this slice. |
| `703B` | Response return/detail word. |
| `704C..7054` | Response scratch bytes cleared by `C000:3F58`. |
| `7051` | Response status byte. |
| `7052` | Response detail byte for nonzero status. |
| `7053` | Command-specific extra byte after `47`, `4E`, or `4F` payload. |
| `7054` | Trailer or ACK shortcut byte. |
