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

`C000:5098` saves caller registers into a small stack frame, stores the original
`AH` at `[6F5F]`, maps `AH` through the byte table at `C000:5000`, then calls a
near handler pointer from the word table at `C000:5060`. Unsupported functions
fall into a tight loop at `C000:5110`; `AH=FF` is a private direct service that
calls `C000:2C4A`.

Confirmed public service map:

| `AH` | Handler | Meaning |
| ---: | --- | --- |
| `03` | `C000:5117` | Console/device input status path. |
| `04` | `C000:0D71` | Character/device output using `DL`; used by low-level text output. |
| `05` | `C000:5146` | Device input helper. |
| `08` | `C000:5155` | Keyboard/input helper. |
| `0B` | `C000:515C` | Input status helper. |
| `0E` | `C000:5163` | Select current drive. |
| `19` | `C000:5167` | Get current drive. |
| `1A` | `C000:516B` | Set DTA. |
| `2A` | `C000:516F` | Get date. |
| `2B` | `C000:51C7` | Set date. |
| `2C` | `C000:5209` | Get time. |
| `2D` | `C000:523D` | Set time. |
| `2F` | `C000:5270` | Get DTA. |
| `36` | `C000:5274` | Get free disk space. |
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
| `5B` | `C000:5304` -> `C000:2A1B` | Create new file. |

The date/time services are backed by the RTC port block, not the storage layer:
`C000:516F`/`5209` decode BCD shadow bytes read from ports `0xD0..0xDC`, while
`C000:51C7`/`523D` convert binary date/time values back to BCD and write the
RTC. These services still follow the DOS register convention closely enough for
application code to use normal-looking `AH=2A`/`2B`/`2C`/`2D` calls.

## IOCTL And Endpoint Status

The `AH=44` dispatcher at `C000:5298` is not a broad DOS IOCTL
implementation. It recognizes standard-looking `AX=4400`, then a private range
`AX=4420..4429`:

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
wrapper.

On a successful find-first result, the loader takes the file size from the DTA
size fields at offsets `+0x1A/+0x1C`, checks available work memory, opens the
same path with `DC98:E946` (`AH=3D`), reads the whole file to `0xA4F0` with
`DC98:EE08` (`AH=3F`), and closes it with `DC98:EE2E` (`AH=3E`).

Only after the file is loaded does the ROM-card-specific check happen:

```asm
DC98:2CE2  mov bx,[0A4F0]
DC98:2CE6  mov ax,[0A4F2]
DC98:2CE9  cmp ax,1997
DC98:2CEE  cmp bx,0A4F0
DC98:2D15  call C688:022B      ; calls far [0xA4F4]
```

So the current read is that `EROMCARD.X` is a normal 8.3 file on a checked
storage endpoint, and the special ROM-card format begins inside that loaded
file. The remaining ROM-card questions are the full executable header layout,
the exact candidate-drive mapping from `[0x6805]`, and whether a loaded stub can
intentionally execute further code from the mapped card window.

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

## Scheduler Database

The Organizer SCHEDULER entry point is `DC98:990D` / file `0x6628D`. It first
draws the resource at file `0x70E0A`, which contains `*** WAIT ***`, then builds
a path from the active drive byte `[6805]` and `SCHEDULE.ODB` at file `0x71010`.
The expected database header is `ORGAN[SCHEDULE]` at file `0x71021`.

If `SCHEDULE.ODB` is missing, the handler creates it with a 16-byte header and a
200-entry 4-byte index table. Existing files are validated by comparing the
header and scanning the 200 index entries; nonzero offsets below the file size
increment the entry count at `[82AE]`. After setup, if `[82AE]` is still zero,
the handler closes and deletes the empty database, then returns to the Organizer
menu. That matches the brief asterisk display observed in MAME when the backing
store is not initialized or cannot retain the database.

After correcting the `0x11 = 0x0E` bank mapping to RAM, FILE -> INITIALIZE
formats the full 160 KiB built-in store, and both SCHEDULER and ADDRESS BOOK
enter normally in MAME. This confirms the earlier Scheduler return-to-menu
symptom was caused by the common storage backing, not by the Scheduler UI path
itself.

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
