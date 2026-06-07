# DEF0 Storage Subsystem

The internal storage management subsystem at `DEF0:7000..9FFF`
(245 blocks). Handles the DreamWriter's internal file format —
document storage, retrieval, and format conversion. Initialized by
`DEF0:88E2` (file handle table init, called from `DEF0:5C07`).

The storage subsystem bridges between the application-level document
model and the low-level file services in
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

Called from the storage subsystem for document formatting:

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
