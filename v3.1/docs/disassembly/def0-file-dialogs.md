# DEF0 File Dialogs

The file management UI at `DEF0:29DC..4AA9` (269 blocks). Implements
the file open, save, delete, and directory listing dialogs. Uses
display services for screen rendering and file services for storage
operations.

Called from the menu display system (`DEF0:2DF1` via `DEF0:27C8`) and
from the application init path (`DEF0:5B14`).

See [`def0-menu-display.md`](def0-menu-display.md) for the menu
system and [`def0-file-services.md`](def0-file-services.md) for the
underlying file operations.

## External Entry Points

| Address | Caller | Purpose |
| --- | --- | --- |
| `DEF0:2DF1` | `DEF0:27C8` | File dialog main entry |
| `DEF0:32A4` | `DEF0:5B14` | Copy NUL-terminated string |
| `DEF0:32B3` | `DEF0:5B14` | Compare NUL-terminated strings |
| `DEF0:4A19` | `DEF0:2724` | File operation entry (from menu item dispatch) |

## DEF0:2DF1 — File Dialog Entry

Initializes display mode via `DEF0:115C` (AX=8, BX=`F132`), then calls
`DEF0:2612` (menu display init). Enters a loop with `DEF0:2E1C` calling
display and file operations until the user completes or cancels.

```asm
DEF0:2DF5  B80800         mov ax,8
DEF0:2DF8  BBF132         mov bx,F132          ; display mode descriptor
DEF0:2DFB  9A5C11F0DE     call far DEF0:115C   ; display init
; ...
DEF0:2E0C  E803F8         call DEF0:2612        ; menu display init
```

The loop at `DEF0:2DF5..2EA8` dispatches through:
- `DEF0:29DC` — render file list dialog box
- `DEF0:2C37` — render file operation confirmation dialog
- `DEF0:3E56` — directory listing and file selection

## DEF0:3E56 — Directory Listing

The main file browser (DEF0:3E56..40CA, 636 bytes). Allocates an
`0x84E` (2126) byte stack frame for file data. Builds a wildcard
pattern `"x:*.*"` where `x` is the drive letter from `[0000:1005]`
offset by `[si+0x800]`:

```asm
DEF0:3E65  B80000         mov ax,0
DEF0:3E68  8EC0           mov es,ax
DEF0:3E6A  26A00510       mov al,[es:1005]     ; drive base
DEF0:3E6E  32E4           xor ah,ah
DEF0:3E70  BB0800         mov bx,8
DEF0:3E73  2BD8           sub bx,ax
DEF0:3E75  83C340         add bx,byte +0x40
DEF0:3E78  899C0008       mov [si+800],bx      ; store drive number
```

Calls `DEF0:E195` (find first, INT 21h AH=4Eh) to enumerate files,
then `DEF0:2F6C` for display.

## DEF0:2F6C — File Selection Dispatcher

Checks `[si+0x80E]` (file operation mode). If `0x0E`, jumps to
`DEF0:310E` (special handler). Otherwise dispatches through a large
switch on the operation code (`DEF0:2F83..30F2`):

| Code | Handler | File service calls |
| --- | --- | --- |
| 0 | `DEF0:2FD2` | `DEF0:2ED6` (dialog render) |
| 1 | `DEF0:2FEF` | `DEF0:2ED6` |
| 2 | `DEF0:300C` | `DEF0:2ED6` |
| 3 | `DEF0:3029` | `DEF0:2ED6` |
| 4 | `DEF0:3046` | `DEF0:2ED6` |
| 5 | `DEF0:3063` | `DEF0:2ED6` |
| 6 | `DEF0:3080` | `DEF0:2ED6` |
| 7 | `DEF0:309D` | `DEF0:2ED6` |
| 8 | `DEF0:30BA` | `DEF0:2ED6` |
| 9 | `DEF0:30D6` | `DEF0:2ED6` |
| 10 | `DEF0:30F2` | `DEF0:2ED6` |

All 11 handlers call `DEF0:2ED6` to render the dialog, then jump
to `DEF0:3144` (common return).

## DEF0:2ED6 — Dialog Render

Renders a file dialog box. Calls `C000:3F35` with a 15-byte script
from `F164`, then `DEF0:0DF5` to set up the dialog page (40x22 at
position 0x16, 0x12C), and `DEF0:0D91` to render filename and
status labels.

## DEF0:3B1E — Build Wildcard Pattern

Builds the file search pattern `"drive:*.*"` for `INT 21h AH=4Eh`
(find first). Reads drive letter from `[0000:1005]`, combines with
the path prefix from `[si+0x800]`, appends `":*.*\0"`.

```asm
DEF0:3B32  26A00510       mov al,[es:1005]     ; drive base
DEF0:3B38  03840008       add ax,[si+800]      ; + path offset
DEF0:3B3C  8807           mov [bx],al          ; drive letter
DEF0:3B3E  43             inc bx
DEF0:3B3F  C6073A         mov byte [bx],':'
DEF0:3B42  43             inc bx
DEF0:3B43  C6072A         mov byte [bx],'*'
DEF0:3B46  43             inc bx
DEF0:3B47  C6072E         mov byte [bx],'.'
DEF0:3B4A  43             inc bx
DEF0:3B4B  C6072A         mov byte [bx],'*'
DEF0:3B4E  43             inc bx
DEF0:3B4F  C60700         mov byte [bx],0      ; NUL terminator
```

## Shared Helpers

| Address | Called | Purpose |
| --- | --- | --- |
| `DEF0:330E` | 25x | Display page position calculator. Builds `FF 44` page setup commands with computed pixel coordinates (column * 10 + 14, row * 90 + 223). |
| `DEF0:34F5` | 17x | Filename display renderer. Takes SI (filename), DI (display state). |
| `DEF0:32D8` | 4x | Display mode selector. Calls `DEF0:0F87` (display mode dispatch), `DEF0:0FE4` (character filter), `DEF0:0D91` (render). |
| `DEF0:32A4` | 4x | Copy NUL-terminated string: `BX` source → `AX` destination. |
| `DEF0:32B3` | 3x | Compare NUL-terminated strings: `AX` vs `BX`, CX bytes max. Returns 0 if equal. |
| `DEF0:3635` | 2x | Page boundary check. Adjusts CX if display extends past allowed area. |
| `DEF0:3C90` | 1x | File list renderer. Takes SI (file data), DI (display position). Large loop building display entries. |
| `DEF0:36AD` | 5x | File entry display helper. |
| `DEF0:33B7` | 3x | Drive status display. Shows drive letter via `DEF0:0D91` using `F1C6` descriptor. |
| `DEF0:3401` | 3x | File entry formatter. |
| `DEF0:347B` | 3x | Alternate entry formatter. |
| `DEF0:2EAB` | 5x | Dialog box frame renderer. Calls `C000:3F35` + `DEF0:0DF5`. |

## DEF0:4A19 — File Operation Entry (from Menu)

Called from `DEF0:2724` (menu item dispatch). Initializes display
via `DEF0:0D80`, renders status line via `DEF0:0D91`, then calls
`DEF0:462D` for the file operation dialog loop.

```asm
DEF0:4A19  ...
DEF0:4A31  9A800DF0DE     call far DEF0:0D80   ; display init
DEF0:4A36  ...            ; render status
DEF0:4A58  E8D2FB         call DEF0:462D       ; file operation dialog
```

## DEF0:462D — File Operation Dialog

Renders the file operation dialog (open/save/delete) with filename
display, confirmation prompts, and progress indicators. Calls
display services for rendering and `DEF0:39E3` for file operation
execution.

The dialog loop at `DEF0:46B3..49A2` processes user input through
`DEF0:2F6C` (file selection), `DEF0:330E`/`DEF0:34F5` (display),
and file services (`DEF0:E195`, `DEF0:E048`, etc.).

## File Dialog State

| Address | Purpose |
| --- | --- |
| `[si+0x800]` | Drive number / path offset |
| `[si+0x802]` | File list page index |
| `[si+0x808]` | File count |
| `[si+0x80A]` | Current display mode |
| `[si+0x80E]` | File operation mode |
| `[0000:1005]` | System drive base letter |
| `F132` | File dialog display mode descriptor |
| `F164` | Dialog box display script (15 bytes) |
| `F1C6` | Drive status display descriptor |

## Block Map (269 blocks)

| Address range | Blocks | Purpose |
| --- | --- | --- |
| `DEF0:29DC..2DBB` | 17 | File list dialog render |
| `DEF0:2DF1..2EA8` | 8 | File dialog entry + main loop |
| `DEF0:2EAB..310E` | 24 | Dialog render + file selection dispatch |
| `DEF0:310E..32D8` | 9 | Special handlers + display |
| `DEF0:32A4..3635` | 12 | String helpers + display helpers |
| `DEF0:3635..3E56` | 42 | File entry renderers + pattern builder |
| `DEF0:3E56..40CA` | 32 | Directory listing + file browser |
| `DEF0:40CA..462D` | 55 | File operation execution + prompts |
| `DEF0:462D..4AA9` | 70 | File operation dialog loop |
