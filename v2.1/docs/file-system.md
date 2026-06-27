# File System And Storage

## FILE Menu

The word-processor `FILE` submenu is reached through `DC98:275A` / file
`0x5F0DA`, using the horizontal icon menu table at effective base `0x6FAEC`.
Its six options dispatch through short `C688:EBxx` far wrappers:

| Menu item | Wrapper | Inner handler | Current read |
| --- | --- | --- | --- |
| `RECALL` | `C688:EB2E` | `C688:7B41` | Select and load a document from storage. |
| `STORE` | `C688:EBD9` | `C688:7C1D` | Select/confirm name and store the current document. |
| `DELETE` | `C688:EBA9` | `C688:790E` | Select a document and delete it after confirmation. |
| `RENAME` | `C688:EBC1` | `C688:7A1B` | Select a document and edit its name. |
| `COPY` | `DC98:455F` | `DC98:455F` | Direction selector for Built-in, Card, and DreamLink copy paths. |
| `INITIALIZE` | `C688:EB91` | `C688:7993` | Initialize/format storage after confirmation. |

`COPY` confirms that the file manager is not card-only. It presents directions
between `Built-in`, `Card`, and `DreamLink`, with strings for `No files`, `No
card is in the slot`, `Card memory read error`, `Directory is full of files`,
`Card is write-protected`, and related copy/status prompts around
`0x6FF03..0x70469`.

The copy list uses a mark-and-commit UI: pressing Enter while the cursor is on
a file does not copy that file. Space toggles a file's selected mark, and Enter
then copies all selected files in the current direction. This makes it easy to
misread a test as a failed copy when no files have been marked yet.

Current ROM evidence does not make `COPY` look like a source-unlinking move.
The normal delete wrapper, `DC98:EE40`, has no direct call sites in the
`0x5F000..0x62000` FILE/COPY transfer area. The nearest transfer-helper delete
call at file `0x6B2BA` closes and deletes the destination path after a failed
copy/open/write path, which reads as cleanup of a partial destination rather
than removal of the source. The copy direction selector at file
`0x60F3F..0x60FC9` updates `[6806]`, the active storage target byte, after
deriving it from `[6805]` and the selected Built-in/Card/DreamLink direction.

## RECALL And The Working Document

`RECALL` is part of the word-processor file workflow rather than a global
system shell. The handler at `C688:7B41` draws the `RECALL` resource
(`SI=0x62`), enters the shared document picker at `C688:9187`, and only then
loads the selected file into the editor.

The picker path passes the active storage target byte, `[6806] | 0x40`, to the
common file-list routine at `DC98:52E5`:

```asm
C688:9187  call C688:910F
C688:918C  call C688:91BB
C688:9190  mov  al,[6806]
C688:9193  or   al,40
C688:9197  mov  bx,7555
C688:919A  call DC98:52E5
```

The surrounding ROM range is now bounded in the region map as
`0x4F57B..0x50310`: it starts immediately after the `LIST OF DOC.` template,
contains the shared document picker at `C688:9187`, and continues through the
inline key-dispatch/resource-loader helpers before the accented-character table
at `C688:9A90`.

So the user-visible storage choice controls the source/destination endpoint for
file operations. `TAB` is still treated specially by these handlers (`AL=0x09`)
and returns to the change-directory/current-target path.

Once a directory entry is selected, `RECALL` checks its flags at `[BX+4]`,
rejects flag bit `0x01`, prompts for the flag-`0x04` case, then calls the
actual load/parser entry:

```asm
C688:7B5D  call C688:7841     ; resolve selected entry
C688:7B64  mov  al,[bx+04]    ; selected entry flags
C688:7B69  test bl,01
C688:7B70  test bl,04
C688:7B83  call C688:8610
C688:7B86  call C688:4F63     ; load selected document into editor state
```

After the load flow, `C688:7BC6` copies the selected filename/current document
name from `0x778A` to `0x8DFC`:

```asm
C688:7BC6  mov  si,778A
C688:7BC9  mov  di,8DFC
C688:7BCC  mov  cx,0011
C688:7BD3  mov  es,0000
C688:7BD6  rep  movsb
```

The `STORE` path performs the inverse copy, `0x8DFC -> 0x778A`, before entering
its save/name-confirmation flow. That makes `0x8DFC` look like the current
document name slot, while `0x778A` is the file-picker/name-entry buffer.

The recalled document itself does not appear to be copied to a single fixed
RAM address like the ROM CARD loader does with `0xA4F0`. `C688:4F63` first
calls `C688:1A71`, which resets editor state, then enters the inline
word-processor stream interpreter through `C688:0240`. The editor insertion and
stream routines (`C688:5B83`, `C688:5B9A`, `C688:3B2F`, `C688:3B62`, and
related helpers) update pointer/state fields such as `[78E7]`, `[78EB]`,
`[78ED]`, `[78F3]`, `[78F5]`, `[7928]`, `[792A]`, and `[793B..793E]`.

Current read: the working copy is editor-internal dynamic state in RAM. The
FILE menu can choose where documents are recalled from or stored to, but there
is no evidence yet that it lets the user place the live editing buffer on the
card or in any other storage window. The editor heap and block allocator are
tracked in [`wp-editor-heap.md`](wp-editor-heap.md).

## Edited Document File Format Status

The edited word-processor document payload is not fully documented yet. The
filesystem container is reasonably well understood: a custom DreamWriter volume
header, FAT12-style allocation, 32-byte directory entries, standard attribute
bits, packed DOS/FAT timestamps, and file sizes. The document bytes inside a
stored WP file are a separate editor stream consumed by `C688:4F63` and produced
by the STORE path through `C688:7308`.

Current confirmed payload evidence is limited:

| Evidence | Current read |
| --- | --- |
| `RECALL` loader | `C688:4F63` resets editor state through `C688:1A71`, then feeds bytes into the word-processor stream interpreter at `C688:0240`. |
| `STORE` writer | The FILE handler reaches `C688:7308` after filename/overwrite/secret prompts; that routine has not been fully decoded as a byte-format writer. |
| Stored editor marker | Test files seen so far begin with `0xFF`, a one-byte header length, then an editor/document header. The v3.1 native serializer confirms this `FF length` shape. |
| Header length | A saved `Test.txt` and the BASIC-card test both use `0x10`, i.e. a 16-byte editor header. This is a length byte, not a fixed file type. |
| Text body | Plain text bytes are accepted after the header; observed examples use `0x0C` as the editor line separator. |
| Live representation | The imported document is converted into the private editor block heap documented in [`wp-editor-heap.md`](wp-editor-heap.md), not kept as a flat file image. |

Unknowns include the 16-byte header field meanings, the complete control-byte
grammar for formatting and document state, the exact STORE serialization rules,
and the interaction with the secret/password file flags. Treat any generated
document file using only `FF 10 <16-byte header> <plain text with 0C line
separators>` as a compatibility subset, not a full native format specification.

The v3.1-family ROM gives a more complete native WP payload read in
[`../../docs/wp-edited-file-format.md`](../../docs/wp-edited-file-format.md):
the leading bytes are `FF <header-length>`, followed by seven serialized editor
state words and a variable table. A `0x10` length means a 14-byte fixed header
plus two bytes of variable-table data.

The later v3.1-family ROM also contains an indexed ODB database container used
by Scheduler and Address Book. That format is documented from the v3.1.260
storage code in
[`../../v3.1/docs/disassembly/def0-storage-subsystem.md`](../../v3.1/docs/disassembly/def0-storage-subsystem.md#indexed-organizer-database-format).
Do not treat that ODB evidence as the WP edited-file format until the C772
document STORE/RECALL path is tied to it.

## DOS-Like API Surface

The storage layer uses a DOS-like `int 21h` API. The wrappers around
`DC98:EE08..F07C` cover the same functions expected from an MS-DOS-style file
system interface:

| Wrapper | Function |
| --- | --- |
| `DC98:EED2` | `AH=3C` create/truncate file. |
| `DC98:EF32` | `AH=3D` open file. |
| `DC98:EE2E` | `AH=3E` close file. |
| `DC98:EE08` | `AH=3F` read file. |
| `DC98:EE1B` | `AH=40` write file. |
| `DC98:EE40` | `AH=41` delete file. |
| `DC98:EE72` | `AH=42` seek file. |
| `DC98:EEE7`, `DC98:F000`, `DC98:F03A` | `AH=43` get/set file attributes. |
| `DC98:EF7B` | `AH=1A` set DTA, then `AH=4E` find first. |
| `DC98:EF9A` | `AH=1A` set DTA, then `AH=4F` find next. |
| `DC98:EE56` | `AH=56` rename file. |
| `DC98:EF59`, `DC98:F018`, `DC98:F052` | `AH=57` get/set file date/time. |
| `DC98:EFD6` | `AH=36` get disk free space. |
| `DC98:EF45`, `DC98:F06E`, `DC98:F074` | `AH=44` IOCTL/status helpers, including `AX=4428` and `AX=4429`. |

The error mapper at `DC98:EDCB` translates returned DOS-style error values into
the firmware status word at `[680F]`.

## INT 21h Dispatcher

Startup calls `C000:0ED6`, which installs the interrupt table. The `INT 21h`
vector is written as `C000:0006`, and `C000:0006` is a near jump to the
dispatcher at `C000:5098`:

```asm
C000:0F66  mov ax,0006
C000:0F69  mov di,0084       ; IVT entry for int 21h
C000:0F6C  stosw
C000:0F6D  mov ax,C000
C000:0F6F  stosw

C000:0006  jmp C000:5098
```

`C000:5098` saves caller registers into a small stack frame, switches `DS` to
zero, stores the original `AH` at `[6F5F]`, clears `[6EC1]`, maps `AH` through
the byte table at `C000:5000`, then calls a near handler pointer from the word
table at `C000:5060`. The dispatcher updates the caller's saved flags before
`iret` so handlers can report DOS-style carry/error status.

This table is exhaustive for `AH < 0x60`: byte-table entries with value `FF`
fall into the tight loop at `C000:5110`, and `AH >= 0x60` does the same.
`AH=FF` bypasses the table and calls the private formatter at `C000:2C4A`
directly.

Confirmed service map:

| `AH` | Handler | Meaning |
| ---: | --- | --- |
| `03` | `C000:5117` | Serial/input status path. Calls the serial receive helper `C000:4B8D`; if `[70A5]` bit `0x02` is clear it returns immediately with high status clear, otherwise it waits through the keyboard/cancel path at `C000:49F8`. |
| `04` | `C000:0D71` | Serial/device character output using `DL`. Waits for port `0xC1` readiness, sends through port `0xC0`, and returns `AL=FF` if the wait is cancelled by input. |
| `05` | `C000:5146` | Parallel printer character output. Calls the Centronics byte writer at `C000:0920`. |
| `08` | `C000:5155` | Blocking keyboard/event read through `C000:4A8D`; used by application wrappers as console input. |
| `0B` | `C000:515C` | Nonblocking keyboard/event status through `C000:4977`; returns `AL=FF` when input is pending, otherwise `AL=00`. |
| `0E` | `C000:5163` | Select current drive. Calls `C000:28A7`, stores internal drive byte `DL+1` when caller `DL <= 9`, and returns `AL=09`. |
| `19` | `C000:5167` | Get current internal drive byte from `[6D35]`. |
| `1A` | `C000:516B` | Set DTA pointer from caller `DS:DX` into `[6F6C]:[6F6A]`. |
| `2A` | `C000:516F` | Get date. |
| `2B` | `C000:51C7` | Set date. |
| `2C` | `C000:5209` | Get time. |
| `2D` | `C000:523D` | Set time. |
| `2F` | `C000:5270` | Get DTA, returning `ES:BX` from `[6F6C]:[6F6A]`. |
| `36` | `C000:5274` | Get free disk space. Uses `DL` or the current drive when `DL=0`; returns DOS-style `AX/BX/CX/DX`, with `AX=FFFF` on error. |
| `3C` | `C000:5278` -> `C000:29AD` | Create/truncate file. |
| `3D` | `C000:527C` -> `C000:2B84` | Open file. |
| `3E` | `C000:5280` -> `C000:2C41` | Close file. |
| `3F` | `C000:5284` -> `C000:3194` | Read file. |
| `40` | `C000:5288` -> `C000:32B1` | Write file. |
| `41` | `C000:528C` -> `C000:3730` | Delete file. |
| `42` | `C000:5290` -> `C000:356F` | Seek file. |
| `43` | `C000:5294` -> `C000:37A7` | Get/set file attributes. |
| `44` | `C000:5298` | IOCTL/status subdispatcher. |
| `4E` | `C000:52F4` -> `C000:2DE2` | Find first. |
| `4F` | `C000:52F8` -> `C000:2E27` | Find next. |
| `56` | `C000:52FC` -> `C000:2FE5` | Rename file. |
| `57` | `C000:5300` -> `C000:30DA` | Get/set file date/time. |
| `5B` | `C000:5304` -> `C000:2A1B` | Create new file, failing if the file already exists. |
| `FF` | `C000:2C4A` | Private format/initialize service; requires `BL=A5` and uses `DL=08/09/0A` for built-in RAM, PCMCIA SRAM, or DreamLink. |

The date/time services are backed by the RTC port block, not the storage layer:
`C000:516F`/`5209` decode BCD shadow bytes read from ports `0xD0..0xDC`, while
`C000:51C7`/`523D` convert binary date/time values back to BCD and write the
RTC. These services still follow the DOS register convention closely enough for
application code to use normal-looking `AH=2A`/`2B`/`2C`/`2D` calls.

A direct `CD 21` byte scan of `t4_ir_2.1.ic303` matches this map: code-shaped
call sites use the service numbers above, including the `AX=442x` private IOCTL
range. Early low-ROM/resource-looking `CD 21` byte hits do not set up an
`INT 21h` call and are treated as data until proven otherwise.

## IOCTL And Endpoint Status

The `AH=44` dispatcher at `C000:5298` is not a broad DOS IOCTL
implementation. It recognizes standard-looking `AX=4400`, then a private range
`AX=4420..4429`; every other `AH=44` subfunction returns with carry set:

| `AX` | Handler | Current read |
| ---: | --- | --- |
| `4400` | `C000:30B0` | Get handle/device info. Calls `C000:4064` to resolve `BX` to the active endpoint, then returns a DOS-ish device/drive word in `DX`. |
| `4420` | `C000:086C` | Plays a short tone sequence. |
| `4421` | inline at `C000:52C9` | Returns byte `[70E6]` in `AX`. |
| `4422` | `C000:0CBC` | Private low-level device/control helper. |
| `4423` | `C000:0D25` | Private low-level device/control helper. |
| `4424` | `C000:5A2F` | Initializes/copies renderer table data into low RAM. |
| `4425` | `C000:5948` | Key/renderer table helper. |
| `4426` | inline at `C000:52E0` | Sets bit `0x08` in `[6D51]`. |
| `4427` | inline at `C000:52E6` | Clears bit `0x08` in `[6D51]`. |
| `4428` | `C000:3064` | Probe available copy endpoints. |
| `4429` | `C000:311E` | DreamLink-only finish/flush helper. |

`DC98:F06E` is the application wrapper for `AX=4428`. The handler probes:

| Returned bit | Probe | Current endpoint read |
| ---: | --- | --- |
| `0x01` | Sets drive `0x08`, segment/window `0x1800`, calls the native mount check at `C000:3B69`. | Built-in RAM filesystem. |
| `0x02` | Sets drive `0x09`, segment/window `0x4000`, calls the native mount check at `C000:3B69`. | PCMCIA SRAM card filesystem. |
| `0x04` | Calls `C000:41A8`, which uses the serial command/response path. | DreamLink transfer peer. |

The FILE/COPY flow calls this wrapper at `DC98:36B5` and branches on exact
bitmask values `0..7` to adjust which source/destination combinations are
available.

This is an availability/mount probe, not the SRAM sizing pass. For built-in and
card endpoints it calls `C000:3B69`, which validates the existing volume header
and derives geometry from header word `+4`.

`DC98:F074` wraps `AX=4429`, passing the file handle in `BX`. `C000:311E`
resolves the handle with `C000:4064`; if the active endpoint is not drive
`0x0A`, it returns success with `AX=0`. For drive `0x0A`, it sends a DreamLink
protocol finish sequence: `0x1A`, zero padding up to the current transfer block
length, byte `[7049]`, `0x11`, then a `0x40` command/response transaction via
`C000:4082`. The FILE/COPY path calls this after closing a destination handle
when the selected destination is endpoint index `2`, matching DreamLink as the
RS-232 transfer target.

## DreamLink File Protocol

DreamLink file transfer is exposed as a third storage endpoint rather than a
separate application-level transport. Endpoint `0x08` is built-in RAM storage,
endpoint `0x09` is PCMCIA card storage, and endpoint `0x0A` is the RS-232
DreamLink peer.

The protocol details are now tracked in
[`dreamlink-protocol.md`](../../docs/dreamlink-protocol.md). In short, the normal DOS-like
handlers branch to DreamLink-specific command senders when `C000:4064` resolves
a handle to endpoint `0x0A`:

| File API | DreamLink routine | Current read |
| --- | --- | --- |
| `AH=3C` create/truncate | `C000:4384` | Sends command `0x3C`, timestamp fields, filename, accumulator byte, then terminator `0x11`. |
| `AH=3D` open | `C000:4459` | Sends command `0x3D`, open mode byte `0x00`, filename, accumulator byte, then `0x11`. |
| `AH=3F` read | `C000:44C0`, `C000:4511` | Sends command `0x3F` to start a read, then receives escaped file data blocks. |
| `AH=40` write | `C000:4622`, `C000:4647` | Sends command `0x40` to start a write, then sends escaped file data blocks. |
| `AH=3E` close | `C000:4707` | Sends command `0x3E` with the resolved handle/index. |
| `AH=FF`, `BL=A5`, `DL=0A` | `C000:47AC` | Sends command `0x44 0x05 0x00`; used by the initialize/format path. |

The local DreamLink PC manual at
[`reference/dreamlink-manual.pdf`](../../docs/reference/dreamlink-manual.pdf) matches this
model. From the DreamWriter's perspective, the file-transfer and
print-through operations map onto ordinary FILE menu actions:

| User-visible operation | Firmware view |
| --- | --- |
| Send file from DreamWriter to PC | DreamLink is the destination. The user selects FILE -> STORE, tabs to the DreamLink directory, and the firmware creates/opens a file on endpoint `0x0A` and writes data through command `0x40`. |
| Send file from PC to DreamWriter | DreamLink is the source. The user selects FILE -> RECALL, tabs to the DreamLink directory, and the firmware opens a file on endpoint `0x0A` and reads data through command `0x3F`. |
| Print through PC | The PC-side software selects `PRINTER` as its destination, but the DreamWriter-side manual flow is still FILE -> STORE to the DreamLink directory. This is probably the same outbound DreamLink write path as "send file to PC", with the PC deciding whether to save or print the received document. |

The endpoint probe at `C000:41A8` is the only DreamLink path seen so far that
programs the serial hardware. It saves the user's bytes at `6D2A..6D2E`, writes
`6D2A=6`, `6D2B=1`, `6D2C=0`, `6D2D=0`, and `6D2E=0`, calls `C000:0CBC` to
initialize the USART, then restores the saved bytes in RAM. There is no second
`C000:0CBC` call after the restore, and the create/open/read/write/close
senders above only call the byte send/receive helpers. That means the active
DreamLink transport appears to be forced to the probe's line discipline
(`9600 8N1`, software flow control disabled), even though the user-visible
configuration bytes are restored after discovery.

## Initialize / Format Path

The FILE `INITIALIZE` menu item enters `C688:EB91`, which wraps the UI handler
at `C688:7993`. That handler is mostly prompts and confirmation:

```asm
C688:7993  mov si,0016
C688:7996  call C688:7689     ; draw initialize prompt/resource
C688:799C  call C688:9131     ; select/list current storage target
...
C688:79CC  call C688:EF6B     ; compare selected target against current drive
C688:79DC  call C688:EE98
C688:79DF  mov si,0060
C688:79E2  call C688:EE84     ; confirmation prompt
...
C688:79EF  call C688:7DE1     ; seed default name/label buffer
C688:79F2  call C688:754A     ; run the format/write path
C688:79F5  call C688:7D1F
```

The lower format operation is the private `INT 21h AH=FF` path. The helper at
`C000:1F17` chooses the target drive from `[6806]`, sets `BL=A5`, and calls
`INT 21h`:

```asm
C000:1F17  mov dl,09          ; card target candidate
...
C000:1F20  mov dl,08          ; built-in target candidate
...
C000:1F29  mov dl,0A          ; DreamLink target candidate
...
C000:1F35  mov bl,A5
C000:1F37  mov ah,FF
C000:1F39  int 21h
```

`AH=FF` bypasses the normal `AH` translation table and calls `C000:2C4A`
directly. With `BL=A5`:

| `DL` | Branch | Effect |
| ---: | --- | --- |
| `08` | `C000:2C93` | Formats the built-in store at segment/window `0x1800`; forces geometry count `5`. |
| `09` | `C000:2C74` | Formats the card store at segment/window `0x4000`; first runs card write/access checks and the banked-window capacity probe at `C000:3C08`. |
| `0A` | `C000:2C67` | Jumps to the DreamLink-specific path at `C000:47AC`. |

For built-in and card storage, the format sequence then writes the DreamWriter
header, clears/validates storage blocks, initializes the FAT, clears root
directory sectors, and writes the header again:

```asm
C000:2CA4  call C000:3B2B     ; write header 1997/0126/+4 geometry
C000:2CA7  call C000:3B59     ; temporarily clear header word 0
C000:2CAF  call C000:2D02     ; clear/verify data blocks
...
C000:2CD0  call C000:2D8E     ; initialize FAT12 table
C000:2CD3  call C000:3B01     ; select root directory start
C000:2CF3  call C000:2DBE     ; clear root directory sectors
C000:2CFC  call C000:3B2B     ; rewrite final header
```

The built-in path forces geometry count `5`, i.e. five 32 KiB units or 160 KiB.
The clear/verify loop at `C000:2D02` computes segment/offset pairs through
`C000:2D44`, starting at `1800:0000` and stepping through `2000:0000`,
`2800:0000`, `3000:0000`, and `3800:0000`. In MAME, this requires the startup
`0x11 = 0x0E` mapping to expose RAM at CPU `0x20000..0x3FFFF`; treating `0x0E`
as a ROM bank mirror produces the observed FILE -> INITIALIZE store-memory read
error during the early format progress count.

## ROM CARD Loader

The WP OTHERS -> ROM CARD path at `DC98:2B75` uses the same DOS-like file API
instead of a separate ROM-card directory format. It constructs
`([0x6805] + 1):EROMCARD.X`, probes it with `DC98:EF7B` (`AH=1A` set DTA plus
`AH=4E` find first), and falls back to `[0x6805]:EROMCARD.X` through the same
wrapper. There is no direct card-type or ROM/CIS check in this routine; a card
is accepted only to the extent that the normal file layer can find and open
`EROMCARD.X`.

Combined with the endpoint map above, the usual built-in-storage state gives a
PCMCIA-to-built-in fallback: if `[0x6805]` is drive/endpoint `0x08`, the first
candidate is `0x09:EROMCARD.X` on PCMCIA SRAM storage, and the fallback is
`0x08:EROMCARD.X` in built-in RAM storage. This is why a payload downloaded into
the in-memory filesystem can still be launched through the menu item named
`ROM CARD`.

On a successful find-first result, the loader takes the file size from the DTA
size fields at offsets `+0x1A/+0x1C`, calls `C688:01E6` to prepare the
execution context, and compares the 32-bit file size against the returned work
memory limit. `C688:01E6` sets `ES=0x0A4F`, calls three C688 helpers, marks
`[6D54]=1`, and returns `[7A54] * 0x80` in `AX`. The loader keeps this value in
`DI` as the byte limit and rejects larger files with `Inadequate work memory`.

After the size check, it opens the same path with `DC98:E946`, reads the whole
file to linear address `0xA4F0` with `DC98:EE08`, and closes it with
`DC98:EE2E`. The wrappers ultimately use the standard-looking file calls:

| Wrapper | Service | ROM CARD use |
| --- | --- | --- |
| `DC98:EF7B` | `AH=1A`, then `AH=4E` | Set caller DTA and find `EROMCARD.X`. |
| `DC98:E946` | open path, eventually `AH=3D` | Open `EROMCARD.X`; mode is pushed as zero. |
| `DC98:EE08` | `AH=3F` | Read `CX = file_size_low` bytes to `0xA4F0`. |
| `DC98:EE2E` | `AH=3E` | Close the handle. |

Only after the file is loaded does the ROM-card-specific check happen:

```asm
DC98:2CE2  mov bx,[0A4F0]
DC98:2CE6  mov ax,[0A4F2]
DC98:2CE9  cmp ax,1997
DC98:2CEE  cmp bx,0A4F0
DC98:2D15  call C688:022B      ; calls far [0xA4F4]
```

The minimum loaded-file header is therefore:

| File offset | Meaning |
| ---: | --- |
| `+0x00` | Word `0xA4F0`, matching the load address. |
| `+0x02` | Word `0x1997`, the ROM-card executable ID. |
| `+0x04` | Far entry pointer called through `C688:022B`, in normal x86 `offset,segment` memory order. |

This does not match CP/M `.COM` or PC DOS `.COM`. Both are raw memory images
with no executable header and a fixed transient-program entry convention, rather
than an explicit entry pointer inside the file. CP/M enters at `0100h` in the
TPA; DOS inherited the same offset after its PSP. Here the firmware requires
four non-code signature bytes, does not create a CP/M zero page or DOS PSP, and
transfers control through the far pointer at file offset `+0x04` rather than
jumping to the beginning of the loaded image. It also does not match an MZ
`.EXE`: there is no `MZ`/`ZM` signature, relocation table, or DOS loader path.
The `0x1997` word is also used by the DreamWriter volume header at `C000:3B2B`,
so it reads more like a local signature convention than a known external
executable format. The `.X` extension therefore looks like a
DreamWriter-specific load-and-call format layered on the device's DOS-like file
services.

`C688:022B` saves `CX`, `DX`, `SI`, `DI`, and `BP`, then executes
`call far [0xA4F4]`. It does not save `AX`, so the loaded program sees
`AX = [7A54] * 0x80`, the same work-memory limit used for the size check.
`C688:020C` runs after the loaded entry returns, sets `ES=0x0A4F`, calls the
cleanup helpers, sends `AH=0x04, DL=0x59` through the resource/service path, and
clears `[6D54]`.

The loaded file is resident at physical address `0x0A4F0`. A file whose entry
code starts immediately after the eight-byte header could point at that code as
either `0000:A4F8` or `0A4F:0008`; the firmware only validates the two header
words, not the far pointer target.

Failure paths are specific enough to identify which phase failed:

| Failure | Displayed string |
| --- | --- |
| Neither candidate path exists | `No ROM card is in the slot` |
| File size exceeds `[7A54] * 0x80` | `Inadequate work memory` |
| Open fails | `Can not open EROMCARD.X` |
| Read returns fewer bytes than the DTA size | `Not enough memory` |
| Header words are not `0xA4F0, 0x1997` | `ROM Card ID error` |

The important implication is that `ROM CARD` is not execute-in-place from the
card by itself. It loads an ordinary file through the same storage layer into
RAM and calls its far pointer. A small SRAM-card stub still looks viable, but
any second-stage execution from the PCMCIA memory window would have to be done
by the loaded program after handoff. Remaining questions are the exact
candidate-drive mapping from `[0x6805]`, the intended ABI beyond `AX`, and
whether official ROM cards used the same filesystem or a ROM image arranged so
the file API could see `EROMCARD.X`.

For the separate idea of repackaging the DreamWriter 325 BASIC interpreter as a
T400 `EROMCARD.X`, see [`basic-eromcard.md`](../../docs/basic-eromcard.md).

## Directory Format Evidence

`DC98:4D67` / file `0x616E7` is the directory-list builder used by
`DC98:52E5`, the document picker. It builds a drive-qualified wildcard path:

```asm
DC98:4D78  mov [bx],al
DC98:4D7B  mov byte [bx],':'
DC98:4D7F  mov byte [bx],'*'
DC98:4D83  mov byte [bx],'.'
DC98:4D87  mov byte [bx],'*'
DC98:4DA4  call DC98:EF7B      ; find first X:*.*
DC98:4DB7  call DC98:EF9A      ; find next
```

The DTA buffer is read using standard DOS find-first/find-next offsets:

| DTA offset | Use in `DC98:4D67` | Meaning |
| ---: | --- | --- |
| `+0x15` | `[bp-0x1C]` | File attributes. |
| `+0x18` | `[bp-0x19]` | Packed file date. |
| `+0x1A` | `[bp-0x17]` | File size low word. |
| `+0x1C` | `[bp-0x15]` | File size high word. |
| `+0x1E` | `[bp-0x13]` | NUL-terminated 8.3 filename, up to 13 bytes. |

The picker stores each listed item as a 19-byte record, sorts entries by name,
and caps the listing at `0x80` entries. The displayed fields are the 8.3 name,
attribute flags, size, and packed date. Files at 64 KiB or larger are displayed
in KiB by dividing size by `0x400` and appending `K`.

The full T400 user manual's error-message appendix says the user-visible
directory-full condition occurs when built-in or card memory already has 64
files. That is lower than the picker display cap and is likely a store-layer
limit rather than a UI-list limit.

## Scheduler Database

The Organizer SCHEDULER entry point is `DC98:990D` / file `0x6628D`. It first
draws the resource at file `0x70E0A`, which contains `*** WAIT ***`, then builds
a path from the active drive byte `[6805]` and `SCHEDULE.ODB` at file `0x71010`.
The expected database header is `ORGAN[SCHEDULE]` at file `0x71021`.

If `SCHEDULE.ODB` is missing, the handler creates it with a 16-byte header and a
200-entry 4-byte index table. Existing files are validated by comparing the
header and scanning the 200 index entries; nonzero offsets below the file size
increment the entry count at `[82AE]`. The same ODB validator/creator is used by
the Organizer ADDRESS BOOK entry for `ADDRESS.ODB` with header
`FE "ORGAN[ADDRESS ]"`, so SCHEDULER and ADDRESS BOOK are sibling databases
over the same container format rather than one app calling into the other.

The ADDRESS BOOK payload records are text lines stored behind the ODB index:

```text
NAME<TAB>SALUTATION<TAB>TEL<TAB>FAX<TAB>ADRS<TAB>MEMO<LF>
```

The Organizer parser bounds those fields to `0x28`, `0x0A`, `0x1E`, `0x1E`,
`0x5A`, and `0x64` bytes respectively. The entry keeps the dword offset table
at `[82B0]` and a one-byte first-character cache at `[82B2]`, then compacts the
payload area and rewrites the index table when the foreground UI exits.

After setup, if `[82AE]` is still zero, the handler closes and deletes the empty
database, then returns to the Organizer menu. That matches the brief asterisk
display observed in MAME when the backing store is not initialized or cannot
retain the database.

After correcting the `0x11 = 0x0E` bank mapping to RAM, FILE -> INITIALIZE
formats the full 160 KiB built-in store, and both SCHEDULER and ADDRESS BOOK
enter normally in MAME. This confirms the earlier Scheduler return-to-menu
symptom was caused by the common storage backing, not by the Scheduler UI path
itself.

The same built-in initialization path is reached automatically during cold
startup. Reset enters `C000:00E1` when the retained warm signature/state checks
fail, then `C000:4811` selects built-in store `08` and calls `C000:045A` to
validate the DreamWriter header/checksum at segment `1800`. If that check
fails, `C000:4811` invokes `INT 21h` with `AH=FF/BL=A5/DL=08`, which reaches
the built-in formatter at `C000:2C93`. This is the ROM path behind the boot-time
`INITIALIZING` RAM-store screen.

## Native Format Evidence

The lower `INT 21h` handlers implement FAT12-style structures directly, not just
a DOS-shaped wrapper around an opaque store:

| Evidence | Location | Notes |
| --- | --- | --- |
| 32-byte directory entries | `C000:3868..3905` | Directory scanning advances entries by `0x20` and treats `0x00` as end and `0xE5` as deleted. |
| Attribute byte | `C000:2A68`, `C000:37FA` | Entry offset `+0x0B` is tested/written; read-only blocks delete/write paths with error `0x05`. |
| Packed time/date | `C000:2B35`, `C000:2B44`, `C000:2B5C`, `C000:3EE5` | Firmware packs DOS date/time words and writes them back at directory entry offsets `+0x16..+0x19`. |
| First cluster | `C000:2A68`, `C000:2AC0`, `C000:2C00` | Entry offset `+0x1A` stores the first cluster. New files start allocation search at cluster `2`. |
| File size | `C000:3D81..3D9B`, `C000:3EE5..3F1C` | Entry offsets `+0x1C..+0x1F` are maintained from open-file state. |
| FAT12 chain math | `C000:39BA`, `C000:39C9`, `C000:34FA..356E`, `C000:382D..3867` | Cluster lookup uses `cluster * 3 / 2`, odd/even nibble extraction, and `0xFFF` end-of-chain markers. |
| Free space | `C000:28E0..29A0` | Counts free FAT entries by scanning clusters and treating zero entries as free. |

This makes the SRAM-card/built-in store a FAT12-derived filesystem at minimum.
It still does not look byte-for-byte like a stock PC DOS volume: mount/format
code around `C000:3B2B..3BEC` checks or writes a custom header with words
`0x1997`, `0x0126`, and a geometry/count field at offset `+4`, rather than a
normal IBM/MS-DOS boot sector and BPB. The current best read is therefore:
standard DOS API, standard 8.3 directory entries, and FAT12 cluster allocation,
wrapped in a custom DreamWriter volume header/geometry.

The card-storage capacity probe is at `C000:3C08`. This does not look like a
PCMCIA CIS/attribute-memory query. It first calls the card-access check at
`C000:0AC4`, which sets carry when port `0xA0` bit `0x80` is set, then tests the
linear storage window through the firmware's bank mapping helper at `C000:0239`.
The helper updates ports `0x14` and `0x15` while mapping candidate windows
starting at segment `0x4000` in `0x0800`-paragraph steps, i.e. 32 KiB per step.
Each candidate window is probed by writing `0x5EA6` at `ES:0000`, verifying it,
then writing `0xFFFF`. A second pass counts the windows still reading back
`0xFFFF`, writes a small index value back into each detected window, stores the
count in `[6FAD]`, and stores `count * 0x20` in `[6F21]`. `C000:3B2B` then
writes `[6FAD]` into header word `+4` for the card case. For the built-in store,
the same header field is forced to `5`, which reads as five 32 KiB units, or
160 KiB of built-in file storage.
