# Organizer Scheduler

This slice expands the Organizer top-menu `SCHEDULER` entry at `DC98:990D` /
file `0x6628D`, including the foreground weekly/content UI rooted at
`DC98:955C` / file `0x65EDC`. The short answer on its relationship to ADDRESS
BOOK is unchanged: SCHEDULER and ADDRESS BOOK are sibling applications over a
shared Organizer ODB file framework. The scheduler does not directly call the
address-book UI or consume address-book records in the paths traced here.

## Entry Setup

`DC98:990D` follows the same scaffold later used by the Organizer ADDRESS BOOK
entry `DC98:CF12`: clear the screen, show a `*** WAIT ***` resource, build a
drive-qualified database path from `[6805]`, validate or create the ODB file,
load its index table, and then enter the foreground app loop.

```asm
; file 0x6628D
DC98:990D  55                push bp
DC98:9910  81 EC 60 06       sub  sp,0x0660
DC98:9917  9A 70 0E 98 DC    call DC98:0E70
DC98:991C  9A 87 28 98 DC    call DC98:2887
DC98:992B  B8 0A 00          mov  ax,0x000a
DC98:992E  BB E0 F0          mov  bx,0xf0e0
DC98:9931  B9 12 00          mov  cx,0x0012
DC98:9934  9A AD 67 00 C0    call C000:67AD      ; "*** WAIT ***"
DC98:9939  8D 86 E0 FC       lea  ax,[bp-0x320]
DC98:993D  A3 B0 82          mov  [0x82b0],ax     ; index table buffer
DC98:9940  8D 86 C0 F9       lea  ax,[bp-0x640]
DC98:9944  A3 B2 82          mov  [0x82b2],ax     ; scheduler date/time cache
```

The file name and header resources are:

| Resource | Final value |
| --- | --- |
| `F101:0000` / file `0x71010` | `SCHEDULE.ODB` |
| `F102:0000` / file `0x71020` | `FE "ORGAN[SCHEDULE]"` |

The active path is built as:

```text
<drive from [6805]> ":" "SCHEDULE.ODB"
```

The entry then opens the file, validates it through `DC98:BA42`, or creates it
through `DC98:BB4F` if the open/validation fails:

```asm
DC98:99C9  lea  ax,[bp-0x654]       ; path buffer
DC98:99CE  call DC98:E946           ; open
DC98:99D6  mov  [0x82a8],ax         ; file handle
...
DC98:99E0  lea  ax,[bp-0x654]
DC98:99E4  mov  cx,0x0000
DC98:99E7  mov  dx,0xf102           ; header pointer
DC98:99EA  mov  bx,0x00c8           ; 200 index slots
DC98:99ED  call DC98:BB4F           ; create ODB
...
DC98:9A07  mov  ax,0x0000
DC98:9A0A  mov  bx,0xf102
DC98:9A0D  mov  cx,0x00c8
DC98:9A10  call DC98:BA42           ; validate existing ODB
```

## Shared ODB Format

`DC98:BA42` and `DC98:BB4F` are shared by both SCHEDULER and ADDRESS BOOK.
They treat the database as:

| File offset | Size | Meaning |
| ---: | ---: | --- |
| `0x0000` | `0x10` | 16-byte app header. |
| `0x0010` | `0x320` | 200 little-endian dword record offsets. |
| `0x0330` | variable | Record payload area. |

`DC98:BA42` validates an existing file by checking the header and reading the
200 dword index table into `[82B0]`. It counts nonzero offsets that are still
below the current file size and stores that count in `[82AE]`.

```asm
; file 0x683C2
DC98:BA42  call DC98:EC2A       ; get file size
DC98:BAA5  read 0x10 bytes      ; header
DC98:BACD  compare 16 bytes     ; against caller header pointer
DC98:BAEB  read count*4 bytes   ; index table into [82B0]
DC98:BB07  mov  [0x82ae],0
DC98:BB34  inc  word [0x82ae]   ; one valid nonzero record offset
```

`DC98:BB4F` creates the same structure: it opens the path, writes the caller's
16-byte header, writes a zeroed 200-entry offset table, and clears `[82AE]`.

The shared low-RAM/global state is:

| Address | Role |
| ---: | --- |
| `82A8` | Open ODB file handle. |
| `82AA:82AC` | Available storage estimate used before creating the index. |
| `82AE` | Number of live index entries. |
| `82B0` | Pointer to 200-entry dword offset table. |
| `82B2` | App-specific secondary cache pointer. |

Scheduler records are serialized as line-feed-terminated variable-length
records, with a fixed binary header before the note text:

| Record offset | Size | Meaning |
| ---: | ---: | --- |
| `+0x00` | `4` | Date dword used by the scheduler date helpers and `[82B2]` cache. |
| `+0x04` | `2` | Begin time in minutes after midnight; `FFFF` means blank. |
| `+0x06` | `2` | End time in minutes after midnight; `FFFF` means blank. |
| `+0x08` | `1` | Alarm-enabled flag. |
| `+0x09` | variable | Note text, NUL in the edit buffer and `0x0A` on disk. |

The scheduler compactor and editor cap an individual record at `0xD2` bytes.

## Address-Book Parallels

The Organizer ADDRESS BOOK entry at `DC98:CF12` has the same scaffold, but
uses a different file name, header, and secondary cache shape:

| App | Entry | File | Header | Secondary cache |
| --- | --- | --- | --- | --- |
| SCHEDULER | `DC98:990D` | `SCHEDULE.ODB` | `FE "ORGAN[SCHEDULE]"` | 200 dwords at `[82B2]`. |
| ADDRESS BOOK | `DC98:CF12` | `ADDRESS.ODB` | `FE "ORGAN[ADDRESS ]"` | 200 bytes at `[82B2]`. |

```asm
; file 0x69892
DC98:CF30  mov  ax,0x000a
DC98:CF33  mov  bx,0xf17b
DC98:CF36  mov  cx,0x0012
DC98:CF39  call C000:67AD       ; same wait screen pattern
DC98:CF3E  lea  ax,[bp-0x320]
DC98:CF42  mov  [0x82b0],ax     ; same dword offset table
DC98:CF45  lea  ax,[bp-0x3e8]
DC98:CF49  mov  [0x82b2],ax     ; address-book one-byte cache
...
DC98:CFE9  mov  cx,0x0006
DC98:CFEC  mov  dx,0xf1c5       ; ADDRESS header pointer
DC98:CFEF  mov  bx,0x00c8
DC98:CFF2  call DC98:BB4F
DC98:D00C  mov  ax,0x0006
DC98:D00F  mov  bx,0xf1c5
DC98:D012  mov  cx,0x00c8
DC98:D015  call DC98:BA42
```

After the shared ODB setup, the apps diverge:

| App | Loader | Loaded from records |
| --- | --- | --- |
| SCHEDULER | `DC98:73DB` | Date/time/alarm metadata from each scheduler record. |
| ADDRESS BOOK | `DC98:B9F2` | One byte per address-book record into the secondary cache. |

There is no direct scheduler call to `DC98:CF12`, no direct address-book call
from the scheduler entry path, and no use of `ADDRESS.ODB` by the scheduler.
The relationship is the shared ODB framework and common storage conventions.

## Scheduler Alarm Cache

`DC98:73DB` reads each scheduler record listed by the ODB index and builds the
low-RAM alarm scan table used by `DC98:D3BB`.

```asm
; file 0x63D5B
DC98:73E9  seek [82B0 + si*4]        ; record offset
DC98:740F  read 4 bytes -> [82B2+si*4]
DC98:741D  read 5 bytes -> stack
DC98:7425  cmp  byte [bp-0x2],0
DC98:744E  load record date dword
DC98:7457  sub  date,0x63df
DC98:7464  store date delta at 82C8 + si*4
DC98:7472  store time word at 82C8 + si*4 + 2
```

If the fifth byte read from the record is zero, the scheduler alarm slot is
cleared. Otherwise the record's date field is normalized by subtracting
`0x63DF`, and the time word is copied into the scheduler alarm table. The
next-alarm selector `DC98:D3BB` later scans `82C8..85E7` as 200 scheduler
date/time pairs before considering the four WORLD CLOCK daily alarms.

This is the real scheduler tie into the broader OS behavior: it feeds the same
RTC alarm target selection path that WORLD CLOCK daily alarms use.

## Foreground Weekly View

`DC98:955C` is the foreground scheduler loop reached after the ODB entry setup.
It snapshots the RTC date, converts it to the scheduler date dword format, and
keeps three date values on its stack:

| Stack value | Role |
| --- | --- |
| selected date | The day highlighted in the weekly list. |
| today | The current RTC date, used for the "today" marker in row rendering. |
| visible week start | The first day shown by the seven-row weekly view. |

The weekly screen is redrawn through:

| Helper | File offset | Role |
| ---: | ---: | --- |
| `DC98:7634` | `0x63FB4` | Clears the screen, draws the weekly frame/menu, and emits weekday/date headers. |
| `DC98:79A3` | `0x64323` | Renders one day row, including day labels, small digit glyphs, event summaries, and alarm/marker symbols. |
| `DC98:8D65` | `0x656E5` | Highlights or clears the selected weekly row with a generated `FF 44` rectangle. |
| `DC98:8DEB` | `0x6576B` | Renders the current month/year label from the month-name table. |
| `DC98:94D7` | `0x65E57` | Draws the live entry count and free-storage/status field. |

The weekly event loop dispatches:

| Input | Action |
| ---: | --- |
| `0x02`, `0x03` | Return `AX=0` to the organizer top menu. |
| `0x0B` | Return `AX=1`. |
| `0x09` | Enter the content loop at `DC98:9220`; non-exit returns redraw weekly. |
| `D` / `d` | Open the date prompt at `DC98:9087`. |
| `0x0F` | Jump to the first scheduler record date. |
| `0x0E` | Jump to the last scheduler record date. |
| `0x13` | Previous day, scrolling the visible week when needed. |
| `0x12` | Next day, scrolling the visible week when needed. |

Navigation is clamped to the same broad 1900..2099 date range used by the
calendar and date-entry helpers.

## Content View

`DC98:9220` / file `0x65BA0` is the scheduler `CONTENT` loop. It receives a
selected date pointer, locates the first record for that date through
`DC98:75FE`, redraws the content frame, and displays either the selected record
or a blank placeholder.

Record display uses two helpers:

| Helper | File offset | Role |
| ---: | ---: | --- |
| `DC98:7D9B` | `0x6471B` | Loads one indexed record from the ODB payload and converts the disk line feed to a NUL-terminated note. |
| `DC98:7DE7` | `0x64767` | Draws begin/end time, alarm state, and note text; follows `[6808]` for 12-hour vs. 24-hour display. |

The content loop dispatches:

| Input | Action |
| ---: | --- |
| `0x02`, `0x03`, `0x0B` | Return to the caller/top menu path. |
| `0x09` | Return to the weekly view. |
| `A` / `a` | Toggle the selected record's alarm byte through `DC98:8CCC`, then refresh `DC98:D3BB`. |
| `D` / `d` | Open the date prompt at `DC98:9087`. |
| `0xDA` | Edit the current record through `DC98:8B86`. |
| `0x0D` | Create a new record through `DC98:8BDB`. |
| `0x08` | Confirm and delete through `DC98:8C59`. |
| `0x13`, `0x12` | Previous/next record on the same date, otherwise previous/next day. |

## Edit, Insert, Delete

The editor and writeback helpers are scheduler-specific, but they follow the
same index-table discipline as ADDRESS BOOK:

| Helper | File offset | Role |
| ---: | ---: | --- |
| `DC98:74C2` | `0x63E42` | Scheduler compactor. Moves live payload records down and truncates the file. |
| `DC98:75FE` | `0x63F7E` | Finds the first cached date greater than or equal to a requested date. |
| `DC98:831A` | `0x64C9A` | Finds the sorted insert position by date and begin time. |
| `DC98:838B` | `0x64D0B` | Appends the serialized record, shifts index/cache entries, updates free space, and writes the note terminator as line feed. |
| `DC98:8675` | `0x64FF5` | Six-field scheduler editor for begin/end time and note text. |
| `DC98:8B86` | `0x65506` | Edit-current handler: load, edit, delete old record, reinsert sorted, and rewrite the index. |
| `DC98:8BDB` | `0x6555B` | New-entry handler: seed a blank record for the selected date, edit, insert, and rewrite the index. |
| `DC98:8C59` | `0x655D9` | Delete handler with confirmation prompt. |
| `DC98:8CCC` | `0x6564C` | Alarm toggle; updates both the file record and the `82C8` alarm scan entry. |
| `DC98:9087` | `0x65A07` | Date prompt; validates month/day/year and returns the date dword. |
| `DC98:98E7` | `0x66267` | Clears the scheduler alarm scan table before a rebuild. |

The editor stores begin/end time as minutes after midnight modulo `0x05A0`
(`1440`). A blank begin time is allowed only when the note contains non-space
text, so an entry must have either a usable time or meaningful note content.

## UI Resources

Scheduler menus are `C000:67AD` display streams. The final formatted strings
below omit positioning/control records but preserve visible labels and key
legends:

| Resource | File offset | Descriptor | Final formatted text |
| --- | ---: | --- | --- |
| `F0E0:000A` | `0x70E0A` | `0x12`-byte wait/status stream. | `*** WAIT ***` |
| `F0E1:000C` | `0x70E1C` | `0x69`-byte weekly menu stream. | `WEEKLY` / `[TAB]   CONTENT` / `[D]     DATE` / `[BEGIN] BEGIN` / `[END]   END` / `E:` / `F:` |
| `F0E8:0006` | `0x70E86` | `0x85`-byte content menu stream. | `CONTENT` / `[RET]     EDIT` / `[INS]   NEW ENTRY` / `[BACK]  DELETE` / `[TAB]   WEEKLY` / `[A]     ALARM` / `[D]     DATE` |
| `F0F0:000C` | `0x70F0C` | `0x33`-byte edit menu stream. | `EDIT` / `[RET]     ENTER` / `[CAN]   CANCEL` |
| `F0F4:0000` | `0x70F40` | `0x38`-byte new-entry menu stream. | `NEW ENTRY` / `[RET]     ENTER` / `[CAN]   CANCEL` |
| `F0F7:0008` | `0x70F78` | `0x0E`-byte delete-title stream. | `DELETE` |
| `F0F8:0006` | `0x70F86` | `0x27`-byte delete prompt stream. | `Deletes this entry` |
| `F0FA:000E` | `0x70FAE` | `0x19`-byte date prompt label stream. | `Date` |
| `F0FC:0000` | `0x70FC0` | `0x30`-byte date menu stream. | `DATE` / `[RET] SET` / `[CAN]  CANCEL` |
| `F101:0000` | `0x71010` | NUL-terminated file name. | `SCHEDULE.ODB` |
| `F102:0000` | `0x71020` | 16-byte ODB header string. | `FE "ORGAN[SCHEDULE]"` |

The weekly day rows reuse the same small 4x6 digit glyph resource as CALENDAR:
`F0A6:000C` / file `0x70A6C`.

## Writeback And Compaction

When the foreground scheduler UI returns, `DC98:990D` deletes an empty database
or compacts and writes back the ODB:

```asm
DC98:9A51  cmp  word [0x82ae],0
DC98:9A58  call DC98:EE2E       ; close if empty
DC98:9A64  call DC98:EE40       ; delete empty SCHEDULE.ODB
...
DC98:9A7E  call DC98:74C2       ; compact scheduler record payloads
DC98:9A84  seek 0x10
DC98:9A94  write 0x320 bytes from [82B0]
DC98:9AA3  call DC98:EE2E       ; close
```

The address book has the same final structure but uses its own compactor:
`DC98:BC81`. The two compactors are near-copies with different record buffer
sizes: scheduler reads up to `0xD2` bytes per record, while address book reads
up to `0x132` bytes.

## Boundary

This slice resolves the scheduler/address-book relationship and the foreground
SCHEDULER UI:

| Question | Answer |
| --- | --- |
| Does SCHEDULER call ADDRESS BOOK? | No direct call found in the traced scheduler entry/setup/writeback path. |
| Do they share storage format? | Yes. Both are 16-byte-header Organizer ODB files with a 200-entry dword offset table. |
| Do they share helper routines? | Yes: `DC98:BA42`, `BB4F`, file wrappers, and low-RAM state `82A8..82B2`. |
| Do they share records? | No. `SCHEDULE.ODB` and `ADDRESS.ODB` have separate headers and app-specific record loaders. |
| Does scheduler feed a system hook? | Yes. `DC98:73DB` builds scheduler alarm slots consumed by `DC98:D3BB`. |
| Is the scheduler foreground UI bottomed? | Yes for the weekly/content/date/edit/new/delete/alarm paths described here. |

The remaining Organizer-adjacent paths are outside this slice: C688 print and
mail-merge readers that consume `ADDRESS.ODB`, and user-facing printer
formatters.
