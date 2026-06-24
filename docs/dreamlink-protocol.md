# DreamLink Protocol

This note documents the DreamWriter-side DreamLink protocol as decoded from the
T400 ROM 2.1 image. It is intended as a host-implementation reference. Fields
marked "unknown" or "needs capture" are read or written by the firmware, but
their PC-side meaning has not been confirmed from a real DreamLink trace yet.
The most important DreamWriter-side caveat is that several received check/status
bytes are stored in low RAM but never interpreted by the decoded code.

The local PC software manual is in
[`reference/dreamlink-manual.pdf`](reference/dreamlink-manual.pdf). It confirms
the user-visible model: DreamLink appears to the DreamWriter as a third FILE
menu storage endpoint, alongside Built-in RAM and Card storage. The PC side
chooses whether outbound data is saved to a file or printed, and it chooses the
host file format (`RTF` or `TEXT`).

All byte values below are hexadecimal unless stated otherwise.

## ROM 3.1 Comparison

The T400 3.1-family ROMs keep the same DreamLink wire protocol and command
set, but the implementation moved and the response parser changed one important
error case. The checked `v3.1/t4_ir_3.1_e588.ic303` image has the shared
DreamLink parser at `C000:5A0B`; `v3.1.260/t4_ir_3.1_8c8f.ic303` has the same
logic shifted by nine bytes; `../roms/t4_ir_35ba308.ic303` has the same parser
shape at `C000:5C2E` with a different low-RAM scratch block.

Wire-level behavior that matches the 2.1 extraction:

| Behavior | 3.1 evidence |
| --- | --- |
| `18` startup handshake | Still sends `13 18 11` and strictly expects `13 18 06 11`. |
| directory probe/listing | Still sends `47`, then `4E`, then up to 127 `4F` requests. |
| file command bytes | Still uses `13`, `17`, `3C`, `3D`, `3E`, `3F`, `40`, and `44` for the same operations. |
| ACK policy | The no-ACK list is still `13 17 3C 3D 3E 3F 40 44`; successful `47`, `4E`, and `4F` responses still get `06 11`. |
| alternate second byte handling | `06` and `0F` as the response's second byte still read one following byte and return success. Other unexpected second bytes still return success/no-op. |
| escaped file streams | The `08 <byte+60>` escape and unescaped `1A` EOF model remains unchanged. |

The parser difference is the first response byte. In 2.1, a first byte other
than `13` is treated as success/no-op. In 3.1, the parser records error `31`,
shows an error path, records error `15`, and returns failure. The later
`35ba308` build also displays both the expected command byte and the actual bad
prefix byte on that path, but this is diagnostic/UI behavior rather than a
different wire protocol.

3.1 moved the DreamLink scratch state:

| Meaning | 2.1 | 3.1 e588 / 8c8f | 35ba308 |
| --- | ---: | ---: | ---: |
| expected response command | `7037` | `6FEE` | `6EEE` |
| directory page index | `7038` | `6FEF` | `6EEF` |
| returned handle/word | `703B` | `6FF2` | `6EF2` |
| additive accumulator/check byte | `7049` | `6FF6` | `6EF6` |
| data block position | `704A` | `6FF7` | `6EF7` |
| response scratch bytes | `704C..7054` | `6FF9..7001` | `6EF9..6F01` |
| status byte | `7051` | `6FFE` | `6EFE` |
| error/detail byte | `7052` | `6FFF` | `6EFF` |
| command extra/check byte | `7053` | `7000` | `6F00` |
| trailer byte, normally `11` | `7054` | `7001` | `6F01` |

3.1 also moved the temporary serial settings used by the DreamLink probe. The
e588 and 8c8f builds save and rewrite `132E..1332`; the `35ba308` build uses
`1332..1336`. Both write the same effective probe settings: `06 01 00 00 00`,
matching 9600 bps, 8 data bits, no parity, 1 stop bit, and XON/XOFF disabled.

The e588 command senders are:

| File API / operation | 3.1 e588 routine | DreamLink command |
| --- | --- | ---: |
| create/truncate, `AH=3C` | `C000:5D25` | `3C` |
| delete, likely `AH=41` | `C000:5DB7` | `13` |
| open, `AH=3D` | `C000:5DFA` | `3D` |
| read setup/data, `AH=3F` | `C000:5E61`, `C000:5EB2` | `3F` |
| write setup/data/finish, `AH=40` | `C000:5FC2`, `C000:5FE7`, `C000:60A7` | `40` |
| close, `AH=3E` | `C000:6116` | `3E` |
| rename, likely `AH=56` | `C000:6149` | `17` |
| initialize/format, private `AH=FF BL=A5 DL=0A` | `C000:61BB` | `44` |

## Serial Setup

The DreamLink endpoint probe is `C000:41A8`. It temporarily rewrites the serial
configuration bytes, initializes the USART, then restores the visible settings
in RAM without reinitializing the USART:

| RAM byte | Probe value | Meaning |
| ---: | ---: | --- |
| `6D2A` | `06` | baud selection, decoded in MAME as 9600 bps |
| `6D2B` | `01` | 8 data bits |
| `6D2C` | `00` | no parity |
| `6D2D` | `00` | 1 stop bit |
| `6D2E` | `00` | XON/XOFF disabled |

The file command senders do not reprogram the USART after the probe. For a
host, the practical first target is therefore:

```text
9600 bps, 8 data bits, no parity, 1 stop bit, no XON/XOFF
```

Hardware RTS/CTS may still matter at the USART/RS-232 level, but the DreamLink
protocol itself does not carry a software-flow-control negotiation.

## Endpoint Model

The DOS-like file layer resolves file handles to endpoint IDs:

| Endpoint | Meaning |
| ---: | --- |
| `08` | Built-in RAM storage |
| `09` | PCMCIA SRAM card storage |
| `0A` | DreamLink peer over RS-232 |

When endpoint `0A` is active, normal file services branch to DreamLink-specific
senders:

| File API | ROM routine | DreamLink command |
| --- | --- | ---: |
| create/truncate, `AH=3C` | `C000:4384` | `3C` |
| delete, likely `AH=41` | `C000:4416` | `13` |
| open, `AH=3D` | `C000:4459` | `3D` |
| read setup/data, `AH=3F` | `C000:44C0`, `C000:4511` | `3F` |
| write setup/data, `AH=40` | `C000:4622`, `C000:4647` | `40` |
| close, `AH=3E` | `C000:4707` | `3E` |
| rename, likely `AH=56` | `C000:473A` | `17` |
| initialize/format, private `AH=FF BL=A5 DL=0A` | `C000:47AC` | `44` |

The FILE menu flows in the PC manual map onto those services:

| User operation | DreamWriter-side behavior |
| --- | --- |
| STORE to DreamLink | Create/open an endpoint `0A` file, send document bytes with command `40`, finish with the private flush helper. |
| RECALL from DreamLink | List the DreamLink directory, open an endpoint `0A` file, read document bytes with command `3F`. |
| Print Through PC | Same DreamWriter-side STORE flow. The PC software's destination setting decides whether the received stream is saved or printed. |

## Frame Bytes

These byte values are structural in the firmware:

| Byte | Use |
| ---: | --- |
| `13` | Command/response prefix. Also the first byte sent by `C000:3F78`. |
| `11` | Command/response terminator or trailer marker in most frames. |
| `06 11` | DreamWriter acknowledgement sequence sent by `C000:3FE6`. |
| `15 11` | DreamWriter block-status prompt sent after outbound data blocks. The firmware then reads three host bytes into `704C..704E`; the decoded code does not inspect them after storage. |
| `08` | Data-stream escape marker. |
| `1A` | Unescaped end-of-file marker in file data streams. |

`C000:4125` maintains byte `7049` as an 8-bit additive accumulator. Command
senders initialize it to the command byte for commands that carry a checksum
byte, then add selected transmitted payload bytes. File data blocks also use
this accumulator. The ROM clearly transmits accumulator/check bytes on outbound
commands and data blocks. On inbound command responses and file-read blocks, it
stores the received extra/check bytes but no DreamWriter-side comparison against
`7049` has been found. This does not appear to be a hidden flags check after the
store either: `mov [7053],al` does not set flags, and each decoded `7053` store
is followed by either `xor/clc` before return or another receive/helper call
before any conditional branch.

## Response Parser

`C000:4082` is the shared response parser. Before calling it, the sender stores
the expected command byte in `[7037]`.

Normal command response shape:

```text
host -> DreamWriter: 13 <cmd> <status> [payload] <trailer>
```

Rules observed in the parser:

| Condition | Parser behavior |
| --- | --- |
| first byte is not `13` | Treats the transaction as success/no-op. |
| second byte equals expected command | Reads status and dispatches any command-specific payload. |
| second byte is `06` or `0F` | Reads one byte into `7054`, returns success. Meaning unknown. |
| second byte is anything else | Returns success/no-op. This may be host synchronization tolerance. |
| status is nonzero | Reads detail byte into `7052`, reads trailer into `7054`, returns failure. The trailer is expected to be `11` but is not compared. |
| status is zero | Parses command-specific payload, reads trailer unless command is `3F`, then may send `06 11`. The trailer is expected to be `11` but is not compared. |

On successful responses, the firmware sends a trailing DreamWriter ACK (`06 11`)
only for commands not in this no-ACK list:

```text
13 17 3C 3D 3E 3F 40 44
```

So `47`, `4E`, and `4F` successful responses are followed by a DreamWriter
`06 11` ACK.

Nonzero status responses carry a separate detail byte:

```text
host -> DreamWriter: 13 <cmd> <nonzero-status> <detail> 11
```

The command parser stores `<detail>` in `7052`. One later FILE-menu error path
checks `7052`: detail `12` is special-cased by the directory-listing helper as
end-of-list/no-more-files, while other nonzero details can reach the DreamLink
error screen resource at file `0x57E84` (`Error    received from DreamLink
Host.`). The exact PC-side status/detail table is still not known.

The parser stores response scratch state in low RAM:

| Address | Meaning |
| ---: | --- |
| `7037` | expected response command |
| `7038` | DreamLink directory page index for `4E`/`4F` |
| `703B` | word return value, used by open/create |
| `7049` | additive accumulator/check byte |
| `704A` | file data block position |
| `704C..7054` | response scratch bytes |
| `7051` | status byte |
| `7052` | error/detail byte |
| `7053` | command-specific extra byte or file-read block check byte |
| `7054` | trailing byte, normally `11` |

## Session Startup

The probe sequence is:

```text
DreamWriter -> host: 13 18 11
host -> DreamWriter: 13 18 06 11

DreamWriter -> host: 13 47 11
host -> DreamWriter: 13 47 00 <directory-name NUL> <extra> 11
DreamWriter -> host: 06 11
```

The `18` handshake is strict: `C000:3F8C` expects the exact four-byte response
`13 18 06 11`. Any mismatch records error `18`.

The `47` response parser reads a NUL-terminated display/directory name into
`6F34`, up to 31 stored characters, then reads one extra byte into `7053`. The
shared parser then reads another byte into `7054` and sends `06 11`. The
decoded code does not inspect either byte after storage. Use `extra=00` and
trailer `11` unless a PC-side trace says otherwise.

## Directory Listing

The directory-listing helper sends one `4E` request followed by up to 127 `4F`
requests:

```text
DreamWriter -> host: 13 4E 11
host -> DreamWriter: 13 4E 00 <compact-entry> 00 <extra> 11
DreamWriter -> host: 06 11

DreamWriter -> host: 13 4F 11
host -> DreamWriter: 13 4F 00 <compact-entry> 00 <extra> 11
DreamWriter -> host: 06 11
```

`4E` resets page index `7038` to zero. Each `4F` increments it. The parser
expands each compact host record into one 32-byte local directory entry at
`[6FA3]:(page_index << 5)`. For DreamLink listings, the filename parser selects
segment/window `0580`.

The compact record is position-based. Positions `0..20` are meaningful:

| Compact position | Expanded directory-entry offset | Current interpretation |
| ---: | ---: | --- |
| `0` | `0B` | attribute/status byte |
| `1` | `16` | time/date or metadata byte |
| `2` | `17` | time/date or metadata byte |
| `3` | `18` | time/date or metadata byte |
| `4` | `19` | time/date or metadata byte |
| `5` | `1C` | size byte |
| `6` | `1D` | size byte |
| `7` | `1E` | size byte |
| `8` | `1F` | size byte |
| `9..16` | `00..07` | 8-character base name |
| `17..20` | `0C..0F` | 4-character DreamLink suffix/format field |

Important details:

| Behavior | Note |
| --- | --- |
| entry slots are prefilled | Offsets `00..0A` are spaces; offsets `0C..0F` are zero. |
| NUL before compact position `9` | Stored as data and parsing continues. |
| NUL at compact position `9` or later | Terminates the compact record/page. |
| compact positions `21..254` | Ignored, except they advance the position counter. |
| compact position `255` | Treated as parser error. |

DreamLink names are not parsed as ordinary DOS 8.3 names. For endpoint `0A`,
`C000:39F7` accepts up to 12 characters without treating `.` as an extension
separator. When logical character index 8 is reached, it skips four bytes in the
expanded entry, matching the host listing layout above (`0C..0F` rather than
plain DOS offsets `08..0B`).

End-of-list handling needs a capture. The ROM treats a failed `4E`/`4F`
response with detail byte `7052 == 12` as a successful end/empty listing. The
status byte only needs to be nonzero for the parser to enter this path:

```text
host -> DreamWriter: 13 4E <nonzero-status> 12 11
```

The exact status byte used by the PC software should be confirmed, but the
DreamWriter-side branch keys on detail byte `12`, not on the status value.

## Command Details

### `13`: Delete

```text
DreamWriter -> host: 13 13 <filename NUL> <sum> 11
host -> DreamWriter: 13 13 00 11
```

The filename pointer is advanced by two bytes before transmission, which strips
the drive prefix used by the internal file layer. The filename sender transmits
up to 12 non-NUL bytes and a final NUL. The final NUL is not added to `sum`.

### `17`: Rename

```text
DreamWriter -> host: 13 17 <old-name NUL> <new-name NUL> <sum> 11
host -> DreamWriter: 13 17 00 11
```

Both names are sent through the same 12-byte maximum filename sender. The final
NUL bytes are transmitted but are not included in `sum`.

### `3C`: Create Or Truncate

```text
DreamWriter -> host: 13 3C <t0> <t1> <t2> <t3> <filename NUL> <sum> 11
host -> DreamWriter: 13 3C 00 <handle-hi> <handle-lo> 11
```

The four timestamp/date bytes come from `C000:2B5C` and `C000:2B44` and are sent
in this order: `DL`, `DH`, `CL`, `CH`. The accumulator starts at `3C` and adds
those four bytes plus each non-NUL filename byte. On success, the parser stores
the two-byte returned word in `703B`, and the low byte becomes `6FAF`.

### `3D`: Open

```text
DreamWriter -> host: 13 3D 00 <filename NUL> <sum> 11
host -> DreamWriter: 13 3D 00 <handle-hi> <handle-lo> 11
```

The byte after `3D` is an open-mode byte and is always sent as `00` by the
decoded path. The accumulator is set to `3D` after that mode byte, so the mode
byte is not included in `sum`. The two-byte returned word is handled like the
`3C` create response.

### `3E`: Close

```text
DreamWriter -> host: 13 3E <handle-hi> <handle-lo> 11
host -> DreamWriter: 13 3E 00 11
```

The handle bytes are sent by `C000:4040`, high byte first. No explicit checksum
byte is transmitted by this command.

### `3F`: Start Read

```text
DreamWriter -> host: 13 3F <handle-hi> <handle-lo> 11
host -> DreamWriter: 13 3F 00
```

Command `3F` is special in the shared parser: on success it does not read the
normal trailing byte and does not send `06 11`. After success, the ROM sets
`7049=3F`, `704A=0003`, and receives raw file data with `C000:4511`.

### `40`: Start/Finish Write

Write setup sends a prefix, command byte, and handle bytes, then immediately
enters raw data transmission:

```text
DreamWriter -> host: 13 40 <handle-hi> <handle-lo> <escaped data...>
```

There is no `11` terminator after the setup bytes. The accumulator starts at
`40` and includes the two handle bytes. The initial block position is `0004`,
matching the four bytes already sent (`13 40 handle-hi handle-lo`).

At EOF, the private finish helper sends the final block trailer and then expects
a normal `40` response:

```text
DreamWriter -> host: 1A <zero padding> <sum> 11
DreamWriter -> host: 15 11
host -> DreamWriter: 13 06 11
host -> DreamWriter: 13 40 00 11
```

The three-byte response shown after `15 11` is inferred from the protocol's
generic ACK shape. The decoded DreamWriter code only requires that three bytes
are received; it stores them at `704C..704E` and does not compare them.

### `44`: Initialize/Format

```text
DreamWriter -> host: 13 44 05 00 11
host -> DreamWriter: 13 44 00 11
```

This is reached by the private format path `AH=FF`, `BL=A5`, `DL=0A`.

### `47`: Probe Directory Name

See [Session Startup](#session-startup). This command returns the display name
shown for the DreamLink directory.

### `4E` / `4F`: Directory Listing

See [Directory Listing](#directory-listing).

## File Data Streams

File data is not sent as independent command frames. After `3F` read setup or
`40` write setup, both sides exchange a raw escaped data stream with block
trailers near offset `01FE`.

### Escaping

Bytes below `20` are escaped:

```text
encoded: 08 <byte + 60>
decoded: <second byte - 60>
```

Because of this rule, a literal data byte `1A` is sent as `08 7A`. An unescaped
`1A` is EOF.

### Host To DreamWriter Read Data

After a successful `3F` response, the host sends escaped file bytes. The
DreamWriter receiver starts with block position `0003`. For each received byte,
it increments the position and then processes escapes/EOF.

At block boundary `01FE`, the byte just read is not delivered to the file
buffer. In the symmetric framing used by the DreamWriter's sender, that byte is
zero padding. The receiver then reads a check byte into `7053`, reads the
expected `11` trailer into `7054`, sends `06 11`, then immediately reads and
processes the next stream byte with the new block position set to `0001`.
Unlike DreamWriter-to-host continuation blocks, host-to-DreamWriter continuation
data should not include a fresh `13` prefix unless that byte is intended to
become file data.

EOF handling:

```text
host -> DreamWriter: 1A <zero padding to boundary> <sum/check> 11
DreamWriter -> host: 06 11
```

The receiver consumes zero padding up to the boundary. If a nonzero byte appears
while padding is expected, that byte is treated as the check byte and stored in
`7053`; the next byte is stored as `7054`. The ROM stores these bytes but does
not compare them against the accumulated value. For best compatibility, send a
reasonable check byte and `11`.

### DreamWriter To Host Write Data

After `40` setup, the DreamWriter sends escaped file bytes. When block position
reaches `01FC`, it pads with zeros until `01FE`, sends the accumulator byte,
sends `11`, then prompts the host:

```text
DreamWriter -> host: <data/padding> <sum> 11
DreamWriter -> host: 15 11
host -> DreamWriter: 13 06 11
```

After that prompt, the ROM resets block position to zero and accumulator to
zero. If more data follows, the next write call sends a fresh `13` prefix before
continuing the raw stream. The three-byte host response is stored but not
compared; `13 06 11` is the best inferred ACK value.

The final write block is closed by the private finish helper:

```text
DreamWriter -> host: 1A <zero padding to 01FE> <sum> 11
DreamWriter -> host: 15 11
host -> DreamWriter: 13 06 11
host -> DreamWriter: 13 40 00 11
```

## Minimal Host Implementation Skeleton

A first test host can implement the following pieces:

1. Open the serial port as `9600 8N1` with software flow control disabled.
2. Answer `13 18 11` with `13 18 06 11`.
3. Answer `13 47 11` with a short NUL-terminated directory name, `00`, `11`,
   and accept the following DreamWriter `06 11`.
4. For listing, answer `4E` with either one compact entry or an end-of-list
   status using detail `12`; answer following `4F` requests the same way until
   the exact end protocol is confirmed.
5. For RECALL, answer `3D` with a handle word, answer `3F` with success, then
   send escaped file data and EOF.
6. For STORE, answer `3C` with a handle word, consume `40` setup plus escaped
   data blocks, answer each `15 11` prompt with `13 06 11`, and
   finally answer the `40` finish response.

The remaining host-side values most worth confirming are the exact nonzero
status byte used with directory-list detail `12`, and whether the original PC
software sends meaningful values in the ignored `extra` bytes.

## Open Protocol Questions

| Question | Best current evidence |
| --- | --- |
| What do the `7053` bytes mean for `47`, `4E`, and `4F`? | The ROM stores them but no later reader was found. `7054` is the normal `11` trailer. |
| What exact three host bytes follow `15 11` in the PC software? | `13 06 11` is the best inferred ACK. The ROM stores the three bytes at `704C..704E` but does not compare them. |
| Is the accumulator/check byte validated on reads? | No DreamWriter-side compare was found. The ROM accumulates decoded read data in `7049`, stores received check/trailer bytes, and continues. |
| How is PC-side `RTF` versus `TEXT` represented? | No DreamWriter-side selector or `RTF` string was found. The manual's format choice appears to be PC-side conversion around the same DreamLink byte stream. |
| What is the full error-code table? | `12` ends directory listing; `18` is bad handshake; abort paths map ESC to `15` and TAB to `17`. More codes need traces. |
