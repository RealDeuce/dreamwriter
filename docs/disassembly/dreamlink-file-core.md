# DreamLink File Core

This slice follows the DreamLink endpoint code reached from
[`int21-filesystem-front.md`](int21-filesystem-front.md),
[`int21-file-io.md`](int21-file-io.md),
[`int21-handle-core.md`](int21-handle-core.md), and
[`int21-endpoints.md`](int21-endpoints.md). It annotates reachable ROM code;
[`../dreamlink-protocol.md`](../dreamlink-protocol.md) remains the compact
host-protocol reference.

No image assets or string resources are reached in this slice. The inline
records here are binary command templates, not display resources.

## Shared Frame Helpers

`C000:3F78` is the common command-frame prefix sender. It delays briefly, then
sends byte `0x13` through serial byte sender `C000:0DC4`.

```asm
send_dreamlink_prefix_C000_3F78:
; file 0x43F78
C000:3F78  B9 FA 16          mov  cx,0x16fa
C000:3F7B  E2 FE             loop C000:3F7B
C000:3F7D  B2 13             mov  dl,0x13
C000:3F7F  E8 42 CE          call serial_send_byte_C000_0DC4
C000:3F82  C3                ret
```

`C000:400F` sends a filename from `[703D]:DX`. Callers pass a pointer already
advanced past the local endpoint prefix bytes. The helper sends at most 12
non-NUL bytes, adds each non-NUL byte to checksum `[7049]` through `C000:4125`,
then sends the final NUL without adding it.

```asm
send_dreamlink_filename_C000_400F:
; file 0x4400F
C000:400F  8B F2             mov  si,dx
C000:4011  B9 0C 00          mov  cx,0x000c
C000:4015  8E 06 3D 70       mov  es,[0x703d]
C000:4019  26 8A 14          mov  dl,[es:si]
C000:401D  80 FA 00          cmp  dl,0
C000:4022  8A C2             mov  al,dl
C000:4026  E8 FC 00          call checksum_add_C000_4125
C000:402B  E8 96 CD          call serial_send_byte_C000_0DC4
...
C000:4035  B2 00             mov  dl,0
C000:4037  E8 8A CD          call serial_send_byte_C000_0DC4
```

`C000:4040` sends the current DreamLink handle word `[6F19]`, high byte first,
and includes both bytes in checksum `[7049]`.

`C000:4082` is the shared response parser. It expects `[7037]` to contain the
command byte being answered. A response beginning with any byte other than
`0x13` is treated as a successful no-op. For a matching command, it reads status
into `[7051]`, clears return word `[703B]`, dispatches command-specific payload
parsing through `C000:412D`, then reads the normal trailing byte into `[7054]`
unless the command is `0x3F`.

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
...
C000:409B  3A 06 37 70       cmp  al,[0x7037]
C000:409F  74 1A             jz   expected_response_C000_40BB
```

Nonzero status stores the detail byte in `[7052]` and return word `[703B]`,
then reads the trailer:

```asm
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

Successful responses to commands other than `13`, `17`, `3C`, `3D`, `3E`,
`3F`, `40`, and `44` get firmware ACK `06 11` via `C000:3FE6`. Its inline
binary template is:

```text
offset C000:3FE3: 02 06 11
format: count=2, bytes=06 11
```

## Probe And Directory Listing

`C000:41A8` probes DreamLink. It temporarily forces serial setup bytes
`06 01 00 00 00`, initializes the USART, restores the visible setup bytes in
RAM, sends the strict `0x18` handshake through `C000:3F8C`, then sends command
`0x47` with inline template `02 47 11`.

```asm
dreamlink_probe_C000_41A8:
; file 0x441A8
C000:41B4  C6 06 2A 6D 06    mov  byte [0x6d2a],0x06
C000:41B9  C6 06 2B 6D 01    mov  byte [0x6d2b],0x01
C000:41BE  C6 06 2C 6D 00    mov  byte [0x6d2c],0
C000:41C3  C6 06 2D 6D 00    mov  byte [0x6d2d],0
C000:41C8  C6 06 2E 6D 00    mov  byte [0x6d2e],0
C000:41CD  E8 EC CA          call validate_and_init_serial_C000_0CBC
...
C000:41E8  E8 A1 FD          call strict_handshake_C000_3F8C
C000:41F8  E8 7D FD          call send_dreamlink_prefix_C000_3F78
C000:41FB  BE A5 41          mov  si,0x41a5 ; 02 47 11
C000:41FE  E8 97 CC          call send_inline_bytes_C000_0E98
C000:4203  C6 06 37 70 47    mov  byte [0x7037],0x47
C000:4208  E8 77 FE          call dreamlink_response_C000_4082
```

The `0x47` payload parser at `C000:4217` receives a NUL-terminated directory
name into `6F34`, up to 31 stored bytes, then stores one extra byte in `[7053]`.

`C000:4246` requests a directory listing with `4E` followed by up to 127 `4F`
requests. `C000:4296` expands each compact host listing record into the
DreamLink directory window at `[6FA3]:(page_index << 5)`. `C000:4365` pre-fills
each 32-byte local entry with 11 spaces plus four zero bytes.

```asm
dreamlink_fetch_directory_C000_4246:
; file 0x44246
C000:4246  E8 2F FD          call send_dreamlink_prefix_C000_3F78
C000:4249  BE 40 42          mov  si,0x4240 ; 02 4E 11
C000:424C  E8 49 CC          call send_inline_bytes_C000_0E98
C000:4251  C6 06 37 70 4E    mov  byte [0x7037],0x4e
C000:4256  E8 29 FE          call dreamlink_response_C000_4082
...
C000:426C  C6 06 37 70 4F    mov  byte [0x7037],0x4f
C000:4271  E8 0E FE          call dreamlink_response_C000_4082
```

If the listing response fails with detail `[7052] == 0x12`, the code treats it
as end-of-list and clears `[7051]` and `[7052]`.

## Create, Delete, Open, Close

The file command senders all begin with `0x13`, send a command byte, send any
handle/name/payload fields, store the command in `[7037]`, and call
`C000:4082`.

`C000:4384` sends create/truncate command `0x3C`. It adds two to the filename
pointer, sends four packed time/date bytes from `C000:2B5C` and `C000:2B44`,
sends the filename through `C000:400F`, then sends checksum `[7049]` and trailer
`0x11`. The low byte of returned word `[703B]` becomes slot/index `[6FAF]`.

```asm
dreamlink_create_C000_4384:
; file 0x44384
C000:4384  83 C2 02          add  dx,2
C000:4388  E8 ED FB          call send_dreamlink_prefix_C000_3F78
C000:438B  B2 3C             mov  dl,0x3c
C000:438D  E8 34 CA          call serial_send_byte_C000_0DC4
C000:4392  C6 06 49 70 3C    mov  byte [0x7049],0x3c
...
C000:43E4  E8 28 FC          call send_dreamlink_filename_C000_400F
C000:43E9  8A 16 49 70       mov  dl,[0x7049]
C000:43ED  E8 D4 C9          call serial_send_byte_C000_0DC4
C000:43F2  B2 11             mov  dl,0x11
C000:43F4  E8 CD C9          call serial_send_byte_C000_0DC4
C000:43F9  C6 06 37 70 3C    mov  byte [0x7037],0x3c
C000:43FE  E8 81 FC          call dreamlink_response_C000_4082
```

`C000:4416` sends delete command `0x13` with filename/checksum/trailer.
`C000:4459` sends open command `0x3D`, an always-zero mode byte, filename,
checksum, and trailer. `C000:4707` sends close command `0x3E`, handle bytes via
`C000:4040`, and trailer `0x11`.

## Read Stream

`C000:44C0` starts a read with command `0x3F`, handle bytes, and trailer
`0x11`. On success, it sets `[7049]=0x3F`, `[704A]=3`, `[6F13]=1`, clears
filesystem status, and returns the response word from `[703B]`.

```asm
dreamlink_read_start_C000_44C0:
; file 0x444C0
C000:44C0  C7 06 13 6F 0100  mov  word [0x6f13],1
C000:44CC  E8 A9 FA          call send_dreamlink_prefix_C000_3F78
C000:44CF  B2 3F             mov  dl,0x3f
C000:44D1  E8 F0 C8          call serial_send_byte_C000_0DC4
C000:44D6  E8 67 FB          call send_dreamlink_handle_C000_4040
C000:44DB  B2 11             mov  dl,0x11
C000:44DD  E8 E4 C8          call serial_send_byte_C000_0DC4
C000:44E2  C6 06 37 70 3F    mov  byte [0x7037],0x3f
C000:44E7  E8 98 FB          call dreamlink_response_C000_4082
```

`C000:4511` receives raw file bytes. Bytes below `0x20` are escaped as
`08 <byte + 0x60>`; an unescaped `0x1A` ends the stream. At block boundary
`0x01FE`, it consumes check/trailer bytes into `[7053]` and `[7054]`, sends
ACK `06 11`, receives the next prefix byte into `[704F]`, and resets the block
position.

## Write Stream

`C000:4622` starts write command `0x40` by sending prefix, command, and handle
bytes. Unlike most commands, there is no immediate `0x11` trailer; the stream
continues as raw escaped data. The initial block position is `[704A]=4`,
matching `13 40 <handle-hi> <handle-lo>`.

`C000:4647` sends data. Bytes below `0x20` are escaped as `08 <byte + 0x60>`,
and both transmitted bytes are included in `[7049]`. Near block boundary
`0x01FE`, it sends checksum `[7049]`, trailer `0x11`, then calls `C000:3FF3`
to receive three host bytes into `704C..704E`.

```asm
dreamlink_write_data_C000_4647:
; file 0x44647
C000:4647  89 0E 95 6F       mov  [0x6f95],cx
C000:465B  8B 1E 4A 70       mov  bx,[0x704a]
...
C000:4671  80 FA 20          cmp  dl,0x20
C000:4674  73 16             jnc  send_plain_byte_C000_468C
C000:4677  B2 08             mov  dl,0x08
C000:467B  E8 46 C7          call serial_send_byte_C000_0DC4
C000:4683  8B C1             mov  ax,cx
C000:4685  E8 9D FA          call checksum_add_C000_4125
C000:4689  80 C2 60          add  dl,0x60
```

## Rename And Initialize

`C000:473A` sends rename command `0x17`. It temporarily swaps `[703D]` to send
the old name from `6F73:6F75`, then the new name from `6F77:6F79`, each through
`C000:400F`, and finishes with checksum plus trailer.

`C000:47AC` sends DreamLink initialize/format command `0x44` using inline
binary template:

```text
offset C000:47A7: 04 44 05 00 11
format: count=4, bytes=44 05 00 11
```

It then expects a normal `0x44` response through `C000:4082`.

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6EC1` | Filesystem/protocol error status returned through `INT 21h`. |
| `6F13` | Read-stream active flag; cleared at unescaped EOF `0x1A`. |
| `6F19` | Current DreamLink handle word. |
| `6F21` | Transfer progress count used by progress/status output. |
| `6FAF` | Low byte of returned create/open handle word. |
| `7037` | Expected response command byte. |
| `7038` | Directory listing page index for `4E`/`4F`. |
| `703B` | Response return word or detail word. |
| `703D` | Segment pointer used by filename senders. |
| `7049` | Additive checksum/accumulator. |
| `704A` | Raw stream block position. |
| `704C..7054` | Response and raw-block scratch bytes. |

Response scratch handling, strict handshake, payload dispatch, and compact
directory-entry expansion are expanded in
[`dreamlink-response-details.md`](dreamlink-response-details.md).
