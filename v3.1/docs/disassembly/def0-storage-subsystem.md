# DEF0 Storage Subsystem

The internal storage management subsystem at `DEF0:7000..9FFF`
(245 blocks). Handles file/session storage helpers and the indexed
organizer database container used by Scheduler and Address Book. Initialized
by `DEF0:88E2` (file handle table init, called from `DEF0:5C07`).

The storage subsystem bridges between application-level storage models and
the low-level file services in
[`def0-file-services.md`](def0-file-services.md).

## DEF0:88E2 — File Handle Table Init

Clears 200 4-byte entries at `[A022..A342]`. Each entry tracks one
open file handle. Called from `DEF0:5C07` (cold init).

```asm
DEF0:88E2  33C0           xor ax,ax         ; counter = 0
DEF0:88E4  EB1C           jmp short 8902
; loop:
DEF0:88E6  8BD8           mov bx,ax
DEF0:88E8  D1E3           shl bx,1
DEF0:88EA  D1E3           shl bx,1          ; BX = AX * 4
DEF0:88EC  C78722A00000   mov word [bx+A022],0  ; clear word 0
DEF0:88F2  ...
DEF0:88FC  C74702 0000    mov word [bx+2],0     ; clear word 2
DEF0:8901  40             inc ax
DEF0:8902  3DC800         cmp ax,0xC8       ; 200 entries
DEF0:8905  7CDF           jl 88E6
DEF0:8907  C3             ret
```

## DEF0:8908 — Storage Session Entry

Called from `DEF0:5C90` (warm reinit, result=0x33). The main entry
for storage operations during a session. Allocates a 1632-byte
(`0x660`) stack frame, initializes the display, then builds a file
path with drive letter:

```asm
DEF0:8912  9A800DF0DE     call far DEF0:0D80   ; display init
DEF0:8917  B80C00         mov ax,0xC
DEF0:891A  BB98F2         mov bx,F298          ; storage display descriptor
DEF0:891D  B91B00         mov cx,0x1B
DEF0:8920  9A353F00C0     call far C000:3F35   ; render
; ...
DEF0:8948  26A00510       mov al,[es:1005]     ; drive base
DEF0:894C  8807           mov [bx],al          ; drive letter
DEF0:894F  C6073A         mov byte [bx],':'    ; colon
```

Calls file services (`DEF0:E254` find first, `DEF0:DB47` open,
`DEF0:AD5F` error handler, `DEF0:E048` close) and keyboard
subsystem routines (`DEF0:63D6`, `DEF0:64BD`) for interactive
file selection.

## DEF0:8987..89F1 — File Open Sequence

Opens a file using `DEF0:DB47` (open via INT 21h AH=3Dh), stores
the handle at `[A002]`, and calls `DEF0:AC52` (data read) and
`DEF0:AD5F` (error display). Uses file state variables:

| Address | Purpose |
| --- | --- |
| `[A002]` | Current file handle |
| `[A004]` | File size low word |
| `[A006]` | File size high word |
| `[A00A]` | Read buffer pointer |
| `[A00C]` | Write buffer pointer |

## 7000-7FFF — Text Processing (79 blocks)

Called from the storage subsystem for record text/layout processing:

| Address | Caller | Purpose |
| --- | --- | --- |
| `DEF0:7B81` | `DEF0:8373` | Text block processor |
| `DEF0:7BD6` | `DEF0:8389` | Text format handler |
| `DEF0:7C54` | `DEF0:83D0` | Text layout calculator |
| `DEF0:7CC7` | `DEF0:8314` | Text style processor |
| `DEF0:7D60` | `DEF0:85E2` | Line break handler (5 callers) |
| `DEF0:7DE6` | `DEF0:85E2` | Word wrap handler (4 callers) |
| `DEF0:7F07` | `DEF0:8082` | Text output formatter |

## 8000-8FFF — Storage Core (82 blocks)

The core storage routines:

| Address | Caller | Purpose |
| --- | --- | --- |
| `DEF0:88E2` | `DEF0:5C07` | File handle table init |
| `DEF0:8908` | `DEF0:5C90` | Storage session entry |
| `DEF0:8987` | internal | File open sequence |
| `DEF0:89F3` | internal | Data read + validation |
| `DEF0:8A30` | internal | Input field renderer (→ `DEF0:63D6`) |
| `DEF0:8A57` | internal | Data validation (→ `DEF0:64BD`) |
| `DEF0:8AB4` | `DEF0:9058` | Read block handler |
| `DEF0:8FC0` | `DEF0:9058` | Write block handler (3 callers) |

## Indexed Organizer Database Format

This section documents the shared indexed database container used by the
organizer applications, not the word-processor edited-document format. The
confirmed callers are Scheduler (`SCHEDULE.ODB`) and Address Book
(`ADDRESS.ODB`). The same code is documented here with the v3.1 labels; in
v3.1.260 this block is reached through the shifted `DF80` service segment, for
example `DEF0:AC52` is `DF80:A352` and `DEF0:7BD6` is `DF80:72D6`.

The outer file layout is:

| File offset | Size | Meaning |
| ---: | ---: | --- |
| `0x0000` | `0x10` | File-type/header bytes. `DEF0:AC52` reads these bytes and compares them with a 16-byte caller-supplied header pointer. The header value is not a fixed literal in this code block. |
| `0x0010` | `0x320` | Record offset table: 200 little-endian 32-bit absolute file offsets. |
| `0x0330...` | variable | Record payloads. Each nonzero offset-table entry points to one record payload. |

The validator at `DEF0:AC52` takes a caller-supplied header pointer and maximum
record count. The known organizer callers use `0xC8` records. The routine
checks that the file is at least `0x10 + count * 4` bytes, seeks to offset zero,
compares the 16-byte header, then reads `count * 4` bytes into the in-memory
offset table at `[A00A]`. It counts valid table entries until it sees a zero
offset or an offset greater than or equal to the file size. The active count is
stored in `[A008]`.

Known header pointers:

| Application | File | Header pointer | Notes |
| --- | --- | --- | --- |
| Scheduler | `SCHEDULE.ODB` | `F2BA:000A` | v3.1.260 file offset `0xF2BAA`; opened by `DEF0:8908`, validated through `DEF0:89F3`. |
| Address Book | `ADDRESS.ODB` | `F37D:000E` | v3.1.260 file offset `0xF37DE`; opened by `DEF0:C122`, validated through `DEF0:C20D`. |

Record offsets are absolute offsets from the beginning of the file. They are
not relative to the table. A zero table entry terminates the active list; after
that point the remaining table entries are ignored. The table is rewritten as a
whole after edits: `DEF0:7B81` and `DEF0:7BD6` seek to file offset `0x10` and
write `0x320` bytes from `[A00A]`.

The Scheduler record helpers handle records through a `0xD2`-byte temporary
buffer:

| Record offset | Size | Meaning |
| ---: | ---: | --- |
| `+0x00` | `4` | Record position/state dword. The write path copies this into the side table at `[A00C]`. |
| `+0x04` | `2` | Record metadata word. When `+0x08` is nonzero, this is mirrored to `[A022 + index*4 + 2]`. |
| `+0x06` | `2` | Record metadata word; initialized to `FFFFh` by the insert/create path. |
| `+0x08` | `1` | Metadata-present flag. Zero clears the side metadata for this record; nonzero preserves and mirrors the metadata fields. |
| `+0x09` | variable | Text bytes. In memory the string is NUL-terminated; on disk the terminating NUL is replaced with `0x0A`. |

`DEF0:7187` reads an existing Scheduler record by seeking to the selected
offset-table entry, reading `0xD2` bytes, and scanning from record offset
`+0x09` until `0x0A`. `DEF0:7386` inserts or replaces a Scheduler record: it
creates a new offset-table entry, records the current file end as the record
offset, mirrors the record state into the side tables, scans from `+0x09` to
the in-memory NUL terminator, replaces that terminator with `0x0A`, writes that
many bytes, and reduces the cached remaining-size counter by the bytes written.
Address Book uses the same outer offset-table container, but its raw records
are the 306-byte, six-field records documented in
[`address-book.md`](address-book.md).

Deleting a record compacts all three in-memory tables: `[A00A]` record offsets,
`[A00C]` record state dwords, and `[A022]` side metadata records. The file data
area is append-style during the edit session; the table is the authoritative
record list after the update is committed.

Current open points:

* The exact semantic names for record fields `+0x00..+0x07` are not fully
  assigned yet for Scheduler. The code proves how they are stored, mirrored,
  and cleared.
* The 16-byte header is caller-supplied rather than a literal in the storage
  core.
* This ODB container must not be treated as the v3.1 word-processor file
  format until the C772 document STORE/RECALL path is tied to it. The known
  v2.1-compatible WP test files using `FF 10 <16-byte header>` are a different
  payload shape.

## 9000-9FFF — Application Storage Logic (84 blocks)

Higher-level storage operations called from the application
services (`DEF0:Axxx`):

| Address | Caller | Purpose |
| --- | --- | --- |
| `DEF0:9058` | `DEF0:AAEF` | Block read/write dispatcher (8 callers) |
| `DEF0:90B8` | `DEF0:AA59` | Block format handler |
| `DEF0:92EF` | `DEF0:ABB8` | Document section handler |
| `DEF0:9B11` | internal | Shared helper (8 callers) |
| `DEF0:9BFC` | `DEF0:ABA9` | Section index handler |
| `DEF0:9E42` | `DEF0:ABD6` | Section display renderer |
| `DEF0:9EB4` | `DEF0:A5DB` | Section state updater |

## File Handle Table

The file handle table at `[A022..A342]` has 200 entries of 4 bytes
each:

```text
[A022 + n*4 + 0]: word — handle status (0 = free)
[A022 + n*4 + 2]: word — associated data
```

## ROM Data References

| Address | Purpose |
| --- | --- |
| `F298` | Storage display descriptor |
| `F2B9` | File operation descriptor |
| `F2BA` | File path prefix |

## Call Flow

```text
DEF0:5C07 (cold init)
  → DEF0:88E2 (clear file handle table)

DEF0:5C90 (warm reinit, result=0x33)
  → DEF0:8908 (storage session)
    → DEF0:8987 (file open)
      → DEF0:DB47 (open via INT 21h)
      → DEF0:AD5F (error handler)
    → DEF0:63D6 (keyboard input field)
    → DEF0:64BD (input validation)
    → DEF0:9058 (block read/write)
      → DEF0:8AB4 (read block)
      → DEF0:8FC0 (write block)
```
