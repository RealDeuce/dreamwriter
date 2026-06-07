# Organizer Address Book

This slice expands the Organizer top-menu `ADDRESS BOOK` handler at
`DC98:CF12` / file `0x69892`. It covers the foreground address-book UI and the
`ADDRESS.ODB` database format. The word-processor/mail-merge readers of
`ADDRESS.ODB` in the `C688` segment are deliberately out of scope here.

No new bitmap asset is used by this slice. The resources encountered here are
positioned text (`FF40`) and rectangle/line scripts (`FF44`); the top-menu
ADDRESS BOOK icon is already rendered in [`top-icon-menus.md`](top-icon-menus.md).

## Entry Setup

`DC98:CF12` follows the same Organizer ODB scaffold as the scheduler entry:
clear the screen, show `*** WAIT ***`, build a drive-qualified path, open or
create the database, load the 200-entry index, and enter the foreground loop.

```asm
; file 0x69892
DC98:CF12  55                push bp
DC98:CF15  81 EC 08 04       sub  sp,0x0408
DC98:CF1C  9A 70 0E 98 DC    call DC98:0E70
DC98:CF21  9A 87 28 98 DC    call DC98:2887
DC98:CF30  B8 0A 00          mov  ax,0x000a
DC98:CF33  BB 7B F1          mov  bx,0xf17b
DC98:CF36  B9 12 00          mov  cx,0x0012
DC98:CF39  9A AD 67 00 C0    call C000:67AD      ; "*** WAIT ***"
DC98:CF3E  8D 86 E0 FC       lea  ax,[bp-0x320]
DC98:CF42  A3 B0 82          mov  [0x82b0],ax     ; dword offset table
DC98:CF45  8D 86 18 FC       lea  ax,[bp-0x3e8]
DC98:CF49  A3 B2 82          mov  [0x82b2],ax     ; one-byte name cache
```

The entry builds:

```text
<drive from [6805]> ":" "ADDRESS.ODB"
```

with these resources:

| Resource | Descriptor | Final value |
| --- | --- | --- |
| `F1C4:0008` / file `0x71C48` | NUL-terminated filename | `ADDRESS.ODB` |
| `F1C5:0006` / file `0x71C56` | 16-byte ODB header | `FE "ORGAN[ADDRESS ]"` |
| `F17B:000A` / file `0x717BA` | `FF40 y=0x001c x=0x00cc text` | `*** WAIT ***` |

Open/create and validation mirror the scheduler path:

```asm
DC98:CFE9  B9 06 00          mov  cx,0x0006
DC98:CFEC  BA C5 F1          mov  dx,0xf1c5       ; ADDRESS header
DC98:CFEF  BB C8 00          mov  bx,0x00c8       ; 200 slots
DC98:CFF2  E8 5A EB          call DC98:BB4F       ; create ODB
...
DC98:D00C  B8 06 00          mov  ax,0x0006
DC98:D00F  BB C5 F1          mov  bx,0xf1c5       ; ADDRESS header
DC98:D012  B9 C8 00          mov  cx,0x00c8
DC98:D015  E8 2A EA          call DC98:BA42       ; validate/read index
DC98:D049  E8 A6 E9          call DC98:B9F2       ; load first-byte cache
DC98:D04C  E8 B5 FA          call DC98:CB04       ; foreground UI
```

On return, an empty address book is closed and deleted. A nonempty one is
compacted, its `0x320`-byte index table is written back at file offset `0x10`,
and the file is closed.

## ADDRESS.ODB Format

`ADDRESS.ODB` uses the shared Organizer ODB container:

| File offset | Size | Meaning |
| ---: | ---: | --- |
| `0x0000` | `0x10` | Header `FE "ORGAN[ADDRESS ]"`. |
| `0x0010` | `0x320` | 200 little-endian dword record offsets. |
| `0x0330` | variable | Address records. |

The address-book-specific live state is:

| Address | Role |
| ---: | --- |
| `82A8` | Open `ADDRESS.ODB` file handle. |
| `82AA:82AC` | Available storage estimate. |
| `82AE` | Number of live entries. |
| `82B0` | Pointer to the 200-entry dword offset table. |
| `82B2` | Pointer to a 200-byte cache containing the first byte of each record. |
| `82B4` | Last search string, reused by `[NEXT] NEXT`. |

Records are tab-separated fields terminated by a line feed:

```text
NAME<TAB>SALUTATION<TAB>TEL<TAB>FAX<TAB>ADRS<TAB>MEMO<LF>
```

The parser `DC98:BFB1` and editor/display descriptors give these field limits:

| Field | Max bytes | Content-view screen use |
| --- | ---: | --- |
| `NAME` | `0x28` | y=`0x02`, x=`0x04`, width `0x28`. |
| `SALUTATION` | `0x0A` | y=`0x37`, x=`0x126`, width `0x0A`. |
| `TEL` | `0x1E` | y=`0x0F`, x=`0x1E`, width `0x1E`. |
| `FAX` | `0x1E` | y=`0x19`, x=`0x1E`, width `0x1E`. |
| `ADRS` | `0x5A` | y=`0x26`, x=`0x1E`, width `0x1E`, three rows. |
| `MEMO` | `0x64` | y=`0x12`, x=`0xE1`, width `0x19`, four rows. |

`DC98:BFB1` reads up to `0x132` bytes from the selected record offset, splits
on tab and line feed, truncates overflowing fields to their field maximums, and
NUL-terminates each destination field buffer. `DC98:BF47` is the lighter helper
that extracts only the first field; it is used by the sorted insert/search path.

## Database Helpers

`DC98:B9F2` initializes the address-book secondary cache. For each live record
offset in `[82B0]`, it seeks to the record and reads one byte into
`[82B2 + index]`; unused slots are filled with zero.

```asm
; file 0x68372
...
DC98:B9F9  mov  ax,[0x82a8]
DC98:BA02  add  bx,[0x82b0]
DC98:BA0D  call DC98:EE72       ; seek to record offset
DC98:BA15  mov  bx,[0x82b2]
DC98:BA1E  call DC98:EE08       ; read one byte
...
DC98:BA35  mov  byte [bx],0     ; clear remaining cache slots
```

`DC98:C334` finds the sorted position for a name. It maps the proposed string
through the collation table at `F1B4:0008`, uses the one-byte cache to skip
records whose first character sorts before it, then extracts full names with
`DC98:BF47` and compares mapped strings through `DC98:C30F`.

```asm
; file 0x68CB4
DC98:C351  mov  ax,0xf1b4
DC98:C356  mov  al,[es:bx+0x0008] ; map proposed name byte
...
DC98:C373  mov  bx,[0x82b2]
DC98:C37D  mov  al,[es:bx+0x0008] ; map cached first byte
DC98:C382  cmp  al,[bp-0x29]
...
DC98:C397  call DC98:BF47        ; extract stored NAME
DC98:C3BA  call DC98:C30F        ; mapped string compare
```

`DC98:C0AC` inserts a new or edited record:

- shifts `[82B0]` dword offsets and `[82B2]` cache bytes upward from the
  insertion point,
- appends the serialized record at end of file,
- stores the appended offset in the index,
- writes the first name byte to the one-byte cache,
- serializes the six fields with tabs, trims trailing tabs, appends `LF`, and
  subtracts the byte count from the available-storage estimate.

`DC98:C1B4` deletes a record:

- reads from the record offset until `LF` to compute the freed record length,
- adds the freed byte count back to the available-storage estimate,
- shifts following dword offsets and cache bytes downward,
- clears the final offset/cache slot,
- decrements `[82AE]`.

`DC98:BC81` compacts payload storage before close. It walks record payloads
from file offset `0x0330`, finds each live record by matching the current file
offset against the index table, and when deleted records have left gaps, moves
later live records downward and subtracts the gap size from the affected index
entry. It truncates the file to the compacted end through `DC98:EB1D`.

## Screen Resources

The main index frame and right-side menu scripts are ROM resources consumed by
`C000:67AD` or the local helper `DC98:C3D7`.

| Resource | Descriptor | Final formatted text |
| --- | --- | --- |
| `F17D:0000` / file `0x717D0` | index headings, `FF02`/`FF40` script | `NAME`, `TELEPHONE`, `NO.`, `ENTRIES`, `FREE` |
| `F180:0006` / file `0x71806` | content labels, `FF40` script | `TEL`, `FAX`, `ADRS`, `MEMO`, `SALUTATION` |
| `F183:000C` / file `0x7183C` | delete explanatory script | `Deletes this entry` |
| `F186:0004` / file `0x71864` | right-panel `FF44` line script | horizontal separator lines for the menu panel |
| `F18B:000E` / file `0x718BE` | INDEX menu script, length `0x89` | `INDEX`; `[0xDA]    EDIT`; `[INS]  NEW ENTRY`; `[BACK] DELETE`; `[TAB]  CONTENT`; `[SEARCH] SEARCH`; `[NEXT] NEXT` |
| `F194:0008` / file `0x71948` | CONTENT menu script, length `0x89` | `CONTENT`; `[0xDA]    EDIT`; `[INS]  NEW ENTRY`; `[BACK] DELETE`; `[TAB]  INDEX`; `[SEARCH] SEARCH`; `[NEXT] NEXT` |
| `F19D:0002` / file `0x719D2` | EDIT menu script | `EDIT`; `[0xDA]    ENTER`; `[CAN]  CANCEL` |
| `F1A0:0004` / file `0x71A04` | NEW ENTRY menu script | `NEW ENTRY`; `[0xDA]    ENTER`; `[CAN]  CANCEL` |
| `F1A3:000A` / file `0x71A3A` | DELETE title script | `DELETE` |
| `F1A4:0008` / file `0x71A48` | empty-book dialog script | `No entries` |
| `F1A7:0000` / file `0x71A70` | SEARCH menu script | `SEARCH`; `[0xDA]    EXECUTE`; `[CAN]  CANCEL` |
| `F1AA:0006` / file `0x71AA6` | search prompt label | `SEARCH` |
| `F1AC:0000` / file `0x71AC0` | search failure script | `Not found` |
| `F1AD:000C` / file `0x71ADC` | delete confirmation prompt | `Are you sure? (Y/N) ` |

`DC98:C818` draws the index frame, `DC98:C6EC` draws the content frame, and
`DC98:C3D7` prepends the shared right-panel line script before drawing the
caller-selected menu script.

## Index And Content Views

`DC98:CB04` is the foreground address-book loop. It uses:

| Register/state | Meaning |
| --- | --- |
| `SI=1` | Index view. |
| `SI=0` | Content view. |
| `DI` | Selected record index. |
| `DX` | Index view's first visible record. |
| `BX` | Redraw flag. |

In index view, it draws six rows. Each row calls `DC98:BFB1` to parse a record
into the six stack field buffers, then `DC98:BD84` renders a row:

```asm
; file 0x68704
...
DC98:BDAC  shl  cx,1
DC98:BDB2  add  cx,0x000c       ; y = row * 8 + 0x0c
DC98:BDC9  mov  word [bx],0x0008
DC98:BDD4  mov  word [bx],0x0107 ; clear row rectangle
...
DC98:BE2C  mov  si,[di]         ; NAME
DC98:BE44  cmp  dx,0x18         ; max 24 visible chars
...
DC98:BE78  mov  si,[di+0x04]    ; TEL
DC98:BE91  cmp  cx,0x10         ; max 16 visible chars
```

In content view, it parses only the selected record and calls `DC98:BEAF`,
which draws the six fields at the positions listed in the record-format table.
`DC98:CA31` then updates the current-entry number, total entry count, and free
storage count.

## Editing And Search

The event dispatch in `DC98:CB04` is local:

| Event/key | Handler | Action |
| ---: | --- | --- |
| `0x02`, `0x03` | direct return | Exit to Organizer menu with `AX=0`. |
| `0x0B` | direct return | Exit to Organizer menu with `AX=1`. |
| `0x09` | local toggle | Toggle INDEX/CONTENT view. |
| mapped text key | `DC98:C847` | Jump to the first name sorting at or after the typed key. |
| `0xDA` | `DC98:C86A` | Edit selected entry. |
| `0x0D` | `DC98:C8D0` | Create a new entry, capped at 200 records. |
| `0x08` | `DC98:C989` | Delete selected entry after confirmation. |
| `0x1B` | `DC98:C4E3` | Prompt for a search string, then search from the selected row. |
| `0x1D` | `DC98:C408` | Repeat the last search from the next row. |
| `0x13`, `0x12` | local scroll | Move selection up/down, updating the visible page as needed. |

`DC98:C587` is the shared six-field editor used by edit and new-entry flows. It
uses the field descriptor table at `F1AF:0008` / file `0x71AF8`, calls the
shared editable-field widget at `DC98:1BB7`, accepts `0xDA`, cancels on
`0x03`, and moves between fields with `0x13`/`0x12`. It also rejects an entry
whose `NAME` field is blank or only spaces.

`DC98:C86A` edits an existing entry by loading it through `DC98:BFB1`, running
`DC98:C587`, deleting the old record with `DC98:C1B4`, finding the sorted
position with `DC98:C334`, inserting the edited record with `DC98:C0AC`, and
rewriting the index table.

`DC98:C8D0` clears the six field buffers, runs the same editor, inserts the
new record at the sorted position, and rewrites the index table.

`DC98:C989` redraws the content view, overlays the DELETE menu and confirmation
prompt, accepts only `Y`/`y` or `N`/`n`, and on confirmation calls
`DC98:C1B4` followed by an index-table writeback.

`DC98:C408` searches across whole serialized records, not just the name field.
It maps the search string and record bytes through `F1B4:0008`, compares the
mapped search key at each position until `LF`, and returns the first matching
record index. `DC98:C4E3` owns the prompt and stores the search text in
`82B4`; `[NEXT] NEXT` repeats `DC98:C408` starting at `DI + 1`.

## Current Boundary

This bottoms the Organizer ADDRESS BOOK app and its private `ADDRESS.ODB`
record layer. The other Organizer top-menu roots are covered by
[`organizer-calendar.md`](organizer-calendar.md),
[`organizer-scheduler.md`](organizer-scheduler.md),
[`organizer-world-clock.md`](organizer-world-clock.md), and
[`organizer-calculator.md`](organizer-calculator.md). The print/merge paths
that also read `ADDRESS.ODB` are covered in
[`print-merge-handlers.md`](print-merge-handlers.md).
