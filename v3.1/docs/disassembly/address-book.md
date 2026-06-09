# Address Book Application

The organizer address book, entered from `DEF0:5CB8` when the
user selects ADDRESS BOOK (item 0x35) from the organizer menu.

Entry point: `DEF0:C122`. Returns via RET when the user exits.

## Entry Flow (DEF0:C122)

```text
1. sub sp,0x408               1032-byte stack frame
2. DEF0:0D80                  clear display
3. C000:3F35(2, F334, 1B)     show "*** PLEASE WAIT ***"
4. [A00A] = [bp-0x320]        data buffer (800 bytes)
   [A00C] = [bp-0x3E8]        sort key buffer (200 bytes)
5. build path "X:ADDRESS.ODB"
   drive from [1005], filename from F37D:000A
6. DEF0:E1F0(drive, buf)      check drive free space
   if fail: return 0
7. DEF0:010D × 2              compute free space → [A004]/[A006]
8. DEF0:E254(path, 0)         clear file attributes
9. DEF0:DB47(path, 2)         open ADDRESS.ODB (read/write)
   store handle at [A002]
10. if open fails:
    DEF0:AD5F(path, F37D, 0xE, 0xC8)  create new DB (200-byte records)
    if create fails: DEF0:00F9 error, return 0
11. DEF0:AC52(0xE, F37D, 0xC8)  validate records
    if fails: close, recreate, retry
12. DEF0:AC02                  init sort key buffer
13. DEF0:BD14                  main address book UI (blocks until exit)
14. SI = return value
15. if [A008]==0: close + delete file, return SI
16. else: save data:
    DEF0:0D80                  clear display
    C000:3F35(2, F334, 1B)     "*** PLEASE WAIT ***"
    DEF0:AE91                  flush data
    DEF0:E08C(handle, 0x10, 0) seek to offset 0x10
    DEF0:DC5E(handle, [A00A], 0x320) write 800 bytes
    DEF0:E048(handle)          close file
    DEF0:E254(path, attrs)     restore file attributes
    return SI
```

## Database Format

File: `ADDRESS.ODB` (filename at `F37D:000A`, file `0xF37D0`).

- Record size: 0xC8 (200) bytes
- Raw record data: 0x132 (306) bytes read per entry
- File header: 0x10 (16) bytes
- Sort key buffer at `[A00C]` (200 bytes, 1 byte per entry)
- Data index at `[A00A]` (800 bytes, 4 bytes per entry)
- Max entries: 200 (0xC8)
- Fields separated by 0x0A (newline) delimiter; 0x09 (tab) = null

### Record Fields

| # | Max | Label | Content |
| ---: | ---: | --- | --- |
| 0 | 40 | (index) | Name / sort key. Displayed in INDEX view. |
| 1 | 10 | TEL | Telephone number. |
| 2 | 30 | FAX | Fax number. |
| 3 | 30 | ADRS | Address. |
| 4 | 90 | MEMO | Memo / notes. |
| 5 | 100 | SALUTATION | Salutation text. |

Total: 40+10+30+30+90+100 = 300 characters + 6 delimiters = 306 bytes.

### Sort Table

Character sort-order table at `F36D:0000` (file `0xF36D0`, 128 bytes).
Maps each character to a sort-order value for case-insensitive
alphabetical sorting:

- A-Z (0x41-0x5A) → 0x01-0x1A
- a-z (0x61-0x7A) → 0x01-0x1A (same as uppercase)
- Space (0x20) → 0x1B
- Digits 0-9 (0x30-0x39) → 0x2B-0x34
- Control chars (0x00-0x1F) → 0x00

Letters sort before digits and punctuation.

## DEF0:AC02 — Init Sort Key Buffer

Reads the first byte of each record's file data into the sort
key buffer at `[A00C]`:

```text
for SI = 0 to [A008]-1:
  seek to record[SI] file position (from [A00A] index)
  read 1 byte into [A00C + SI]
```

Used for fast alphabetical lookup without loading full records.

## DEF0:BD14 — Main Address Book UI

Allocates 0x140 (320) bytes on stack. Manages two display views
(INDEX and CONTENT) with a scrolling 6-entry list.

### Local Variables

| Offset | Purpose |
| --- | --- |
| `[bp-0x29]` | Field 0 buffer (name, 41 bytes). |
| `[bp-0x40]` | Field 1 buffer (TEL, 11 bytes). |
| `[bp-0x5F]` | Field 2 buffer (FAX, 31 bytes). |
| `[bp-0x7E]` | Field 3 buffer (ADRS, 31 bytes). |
| `[bp-0xD9]` | Field 4 buffer (MEMO, 91 bytes). |
| `[bp-0x13E]` | Field 5 buffer (SALUTATION, 101 bytes). |
| `[bp-0x35]` | Field pointer array (6 × 2 bytes). |

SI = view mode (0=CONTENT, 1=INDEX).
DI = selected entry index (absolute, not relative to scroll).
DX = scroll position (first visible entry).
BX = redraw flag.

### Display Loop

```text
1. if SI changed (view toggle):
   if SI==1 (INDEX): DEF0:BA28 — draw index frame
     C000:3F35(0, F35F, 7) — "/"
     DEF0:B5E7(0, F345, 89) — INDEX legend
   if SI==0 (CONTENT): DEF0:B8FC — draw content frame
     C000:3F35(0, F35F, 7) — "/"
     DEF0:B5E7(A, F34D, 89) — CONTENT legend
2. for CX = 0..5: load and display entry row
   DEF0:B1C1(DX+CX, field_ptrs) — load entry fields
   DEF0:AF94(CX, field_ptrs) — display row
3. load selected entry:
   DEF0:B1C1(DI, field_ptrs) — load selected
   DEF0:B0BF(field_ptrs) — display detail (CONTENT view)
4. DEF0:BC41(DI, SI) — highlight selected row
5. if [A008]==0: DEF0:BC16 — show empty message
6. DEF0:0043 — read key → dispatch
```

### INDEX View (DEF0:BA28)

Clears display, draws a 6-row list showing the name (field 0)
of each entry. Calls `DEF0:0D80`, then renders field labels
and input field rectangles via `DEF0:0DF5`.

### CONTENT View (DEF0:B8FC)

Clears display, draws 6 labeled input fields:

```text
DEF0:0DF5(1, 0x00, 0x00, 0xF7, 0x0B)    name field
DEF0:0DF5(1, 0x1A, 0x0D, 0xBB, 0x0B)    TEL field
DEF0:0DF5(1, 0x1A, 0x17, 0xBB, 0x0B)    FAX field
DEF0:0DF5(1, 0x1A, 0x24, 0xBB, 0x1B)    ADRS field
DEF0:0DF5(1, 0xDD, 0x10, 0x9D, 0x23)    MEMO field
DEF0:0DF5(1, 0x122, 0x35, 0x43, 0x0B)   SALUTATION field
```

Field labels from `F339:0000`: `FREE`, `TEL`, `FAX`, `ADRS`,
`MEMO`, `SALUTATION`.

## Key Dispatch

| Key | Code | Handler | Action |
| --- | ---: | --- | --- |
| CANCEL | `0x02`/`0x03` | return 0 | Exit address book. |
| EXIT | `0x0B` | return 1 | Exit address book. |
| TAB | `0x09` | toggle SI | Switch INDEX ↔ CONTENT view. |
| A-Z/a-z | `0x41-7A` | `DEF0:BA57` | Alpha jump: find first entry matching letter. |
| ↵ ENTER | `0xDA` | `DEF0:BA7A` | Edit selected entry. |
| INS | `0x0D` | `DEF0:BAE0` | New entry (if count < 200). |
| BACK | `0x08` | `DEF0:BB99` | Delete selected entry. |
| SEARCH | `0x1B` | `DEF0:B6F3` | Search entries by substring. |
| NEXT | `0x1D` | `DEF0:B618` | Find next search match. |
| ↑ | `0x13` | `DEF0:BF4F` | Move selection up. |
| ↓ | `0x12` | `DEF0:C031` | Move selection down. |

## DEF0:BA57 — Alpha Jump

Takes a key character in AL, converts to uppercase, builds a
1-character search string, calls `DEF0:B544` to find the sorted
position. If no match, calls `DEF0:B4A3` (beep/error). Returns
the new entry index.

## DEF0:B544 — Sorted Position Search

Converts the search string through the sort table at `F36D:0000`
(case-insensitive), then performs a linear scan through the
sorted entry list comparing sort keys. Returns the index of the
first entry >= the search string, or `[A008]` if past the end.

## DEF0:BA7A — Edit Entry

```text
1. DEF0:B8FC              draw content view
2. DEF0:B5E7(4, F356, 31) draw "EDIT" legend
3. DEF0:B1C1(DI, ptrs)    load current entry
4. DEF0:B0BF(ptrs)        display entry
5. DEF0:B797(ptrs)        field editor (all 6 fields)
   if cancelled: return
6. DEF0:B3C4(DI)          remove old entry from sorted index
7. DEF0:B544(name)        find new sorted position
8. DEF0:B2BC(pos, ptrs)   insert entry at new position
9. write updated data to file
```

### DEF0:B797 — Field Editor

Allocates 0x14 bytes on stack. Checks free disk space via
`DEF0:E1F0` before and after editing (calls `DEF0:AE91` to
flush if needed). Then loops through field descriptors at
`F367:000C` (14 bytes per field), calling `DEF0:1B00` for each
field's text input.

Field descriptor format (14 bytes each at `F367:000C`):

| Offset | Size | Purpose |
| ---: | ---: | --- |
| `+0x00` | 2 | Field index (0-5, into field pointer array). |
| `+0x02` | 2 | Max length. |
| `+0x04` | 2 | Display X position. |
| `+0x06` | 2 | Display Y position. |
| `+0x08` | 2 | Input field width. |
| `+0x0A` | 2 | Input parameters. |
| `+0x0C` | 2 | Additional parameters. |

## DEF0:BAE0 — New Entry

```text
1. DEF0:B8FC              draw content view
2. DEF0:B5E7(6, F359, 36) draw "NEW ENTRY" legend
3. clear all 6 field buffers to empty strings
4. DEF0:B797(ptrs)        field editor
   if cancelled: return
5. DEF0:B544(name)        find sorted position
6. DEF0:B2BC(pos, ptrs)   insert new entry
7. write updated data to file
```

## DEF0:BB99 — Delete Entry

```text
1. DEF0:B8FC              draw content view
2. DEF0:B5E7(C, F35C, E)  draw "DELETE" legend
3. DEF0:B1C1(SI, ptrs)    load entry
4. DEF0:B0BF(ptrs)        display entry
5. C000:3F35(E, F33C, 27) show "Deletes this entry"
6. DEF0:0DF5(...)          draw confirm box
7. DEF0:BB58(0x74, 0x21)  Y/N confirmation
   "Are you sure? (Y/N)" at F366:0000
8. if confirmed: DEF0:B3C4(SI) remove from sorted index
9. write updated data to file
```

## DEF0:B6F3 — Search

Draws the search screen and accepts a search string:

```text
1. DEF0:B5E7(8, F35F, 35) grid frame + "SEARCH" legend
2. C000:3F35(A, F363, F)  "SEARCH" label
3. DEF0:0DF5(...)          input field rectangle
4. C000:3F35(E, F362, C)  cursor position
5. copy current search string from [A00E]
6. DEF0:1806(string, params) text input
7. if confirmed: store search string at [A00E]
   return position of first match
```

Search string stored at `[A00E]` (persists between searches).

## DEF0:B618 — Find Next

Starts from the current entry and scans forward through records,
reading each record's raw data and searching for the substring
stored at `[A00E]`. Converts both search string and record data
through the sort table at `F36D:0000` for case-insensitive
matching. Returns the index of the next matching entry.

## DEF0:B1C1 — Load Entry

Reads a 0x132-byte raw record from the file, then parses it
into 6 field buffers:

```text
1. clear all 6 field pointers to empty strings
2. seek to record position (from [A00A] + index*4)
3. read 0x132 bytes into stack buffer
4. parse fields separated by 0x0A (newline):
   field 0: copy up to 40 chars (0x28)
   field 1: copy up to 10 chars (0x0A)
   field 2: copy up to 30 chars (0x1E)
   field 3: copy up to 30 chars (0x1E)
   field 4: copy up to 90 chars (0x5A)
   field 5: copy up to 100 chars (0x64)
   0x09 (tab) within a field = null terminator
```

## DEF0:B2BC — Insert Entry (Sorted)

Shifts entries in the data index (`[A00A]`) and sort key buffer
(`[A00C]`) to make room, then writes the new entry's record data
to the file. Increments `[A008]`.

## DEF0:B3C4 — Remove Entry (Sorted)

Reads the entry's file position from the data index, shifts
remaining entries down to fill the gap. Decrements `[A008]`.

## DEF0:AF94 — Display Entry Row

Renders a single row in the 6-line scrolling list. In INDEX
view, shows the name. In CONTENT view, shows field content
with labels.

## DEF0:B0BF — Display Entry Detail

Renders the selected entry's full content in the CONTENT view
with all 6 fields in their labeled positions.

## DEF0:BC41 — Highlight Selected Row

Draws a highlight rectangle on the selected entry row using
`FF 44` rectangle commands.

## DEF0:B9A2 — Unhighlight Row

Removes the highlight from the previously selected row.

## DEF0:AE91 — Flush Data

Writes modified record data back to the file.

## Display Script Sources

| Address | File | Length | Purpose |
| --- | ---: | ---: | --- |
| `F334:0000` | `0xF3340` | 27 | `*** PLEASE WAIT ***` loading message. |
| `F339:0000` | `0xF3390` | 54 | Content view field labels: `FREE`, `TEL`, `FAX`, `ADRS`, `MEMO`, `SALUTATION`. |
| `F33C:0000` | `0xF33C0` | 39 | `Deletes this entry` confirmation display. |
| `F33F:0000` | `0xF33F0` | 90 | Grid frame: 6 `FF 44` rectangles. |
| `F345:0000` | `0xF3450` | 137 | INDEX legend: `[↵] EDIT`, `[INS] NEW ENTRY`, `[BACK] DELETE`, `[TAB] CONTENT`, `[SEARCH] SEARCH`, `[NEXT] NEXT`. |
| `F34D:0000` | `0xF34D0` | 137 | CONTENT legend: same keys but `[TAB] INDEX`. |
| `F356:0000` | `0xF3560` | 49 | EDIT sub-screen: `EDIT`, `[↵] ENTER`, `[CAN] CANCEL`. |
| `F359:0000` | `0xF3590` | 54 | NEW ENTRY sub-screen: `NEW ENTRY`, `[↵] ENTER`, `[CAN] CANCEL`. |
| `F35C:0000` | `0xF35C0` | 14 | DELETE sub-screen title. |
| `F35F:0000` | `0xF35F0` | 53 | SEARCH sub-screen: `SEARCH`, `[↵] EXECUTE`, `[CAN] CANCEL`. |
| `F362:0000` | `0xF3620` | 12 | Search field cursor position. |
| `F363:0000` | `0xF3630` | 15 | `SEARCH` label with input field rectangle. |
| `F366:0000` | `0xF3660` | 28 | `Are you sure? (Y/N)` confirmation string. |

## String Data

| File offset | Source | Content |
| ---: | --- | --- |
| `0xF3347` | `F334:0007` | `*** PLEASE WAIT ***` loading message. |
| `0xF3397` | `F339:0007` | `FREE` free space indicator. |
| `0xF339E` | `F339:000E` | `TEL` field label. |
| `0xF33A5` | `F339:0015` | `FAX` field label. |
| `0xF33AD` | `F339:001D` | `ADRS` field label. |
| `0xF33B5` | `F339:0025` | `MEMO` field label. |
| `0xF33C4` | `F339:0034` | `SALUTATION` field label. |
| `0xF33E3` | `F33C:0023` | `Deletes this entry` confirmation. |
| `0xF3457` | `F345:0007` | `INDEX` view title. |
| `0xF3463` | `F345:0013` | `[↵] EDIT`. |
| `0xF3473` | `F345:0023` | `[INS] NEW ENTRY`. |
| `0xF3483` | `F345:0033` | `[BACK] DELETE`. |
| `0xF3493` | `F345:0043` | `[TAB] CONTENT`. |
| `0xF34D7` | `F34D:0007` | `CONTENT` view title. |
| `0xF3567` | `F356:0007` | `EDIT` sub-screen title. |
| `0xF3597` | `F359:0007` | `NEW ENTRY` sub-screen title. |
| `0xF35FD` | `F35F:000D` | `SEARCH` sub-screen title. |
| `0xF3665` | `F366:0005` | `Are you sure? (Y/N)` delete confirmation. |
| `0xF37D0` | `F37D:000A` | `ADDRESS.ODB` database filename. |

## State Variables

| Address | Purpose |
| --- | --- |
| `[A002]` | ADDRESS.ODB file handle. |
| `[A004]` | Free space (low word). |
| `[A006]` | Free space (high word). |
| `[A008]` | Entry count. |
| `[A00A]` | Data index buffer (800 bytes, 4 bytes per entry: file offset). |
| `[A00C]` | Sort key buffer (200 bytes, 1 byte per entry: first char of name). |
| `[A00E]` | Search string (persists between SEARCH/NEXT). |
| `[1005]` | Current storage endpoint (drive letter + 0x40). |
| `[133A]` | File protection flag. |

## ROM Data Regions

| Start | End | Type | Content |
| ---: | ---: | --- | --- |
| `0xF36D0` | `0xF3750` | data | Character sort-order table (128 bytes). Case-insensitive: A-Z and a-z both map to 0x01-0x1A. |
| `0xF367C` | `0xF36D0` | data | Field editor descriptors: 6 × 14 bytes at F367:000C. |
| `0xF37D0` | `0xF37E0` | text | `ADDRESS.ODB` filename. |

## Related Functions

| Address | Purpose |
| --- | --- |
| `DEF0:AC02` | Init sort key buffer (read first byte of each record). |
| `DEF0:AC52` | Record search/validate (shared with scheduler). |
| `DEF0:AD5F` | Record create/init (shared with scheduler). |
| `DEF0:AE91` | Flush modified data to file. |
| `DEF0:AF94` | Display entry row in scrolling list. |
| `DEF0:B0BF` | Display entry detail (content view). |
| `DEF0:B1C1` | Load entry: read record, parse 6 fields. |
| `DEF0:B2BC` | Insert entry at sorted position. |
| `DEF0:B3C4` | Remove entry from sorted index. |
| `DEF0:B4A3` | Error beep/notification. |
| `DEF0:B544` | Find sorted position for name string. |
| `DEF0:B5E7` | Draw grid frame (F33F) + legend display script. |
| `DEF0:B618` | NEXT: find next search match (case-insensitive). |
| `DEF0:B6F3` | SEARCH: search string input and first match. |
| `DEF0:B797` | Field editor (6-field form using F367 descriptors). |
| `DEF0:B8FC` | CONTENT view setup (clear + 6 input fields + labels). |
| `DEF0:B9A2` | Unhighlight previously selected row. |
| `DEF0:BA28` | INDEX view setup (clear + list frame). |
| `DEF0:BA57` | Alpha jump: find entry by first letter. |
| `DEF0:BA7A` | Edit entry (load, edit, re-sort, save). |
| `DEF0:BAE0` | New entry (clear, edit, insert sorted, save). |
| `DEF0:BB58` | Y/N confirmation dialog. |
| `DEF0:BB99` | Delete entry (confirm, remove, save). |
| `DEF0:BC16` | Empty list display. |
| `DEF0:BC41` | Highlight selected row. |
| `DEF0:BD14` | Main UI loop (view toggle, key dispatch, scrolling). |
