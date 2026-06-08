# INT 21h File I/O Handlers

The INT 21h dispatcher at `C000:6277` (documented in
[`int21-dispatch.md`](int21-dispatch.md)) routes each AH function to a
handler. Most file operations are single-instruction stubs that call
into deeper implementation routines.

## Handler Stubs

Each stub is `CALL target; RET` — the actual implementation is at the
call target, which returns to the stub, which returns to the INT 21h
dispatcher.

```asm
; file 0xC6373..0xC6416
C000:6373  E8 12DC           call C000:3F88  ; AH=2Fh: get DTA address
C000:6376  C3                ret
C000:6377  E8 1EDC           call C000:3F98  ; AH=36h: get disk free space
C000:637A  C3                ret
C000:637B  E8 35DD           call C000:40B3  ; AH=3Ch: create file
C000:637E  C3                ret
C000:637F  E8 19DF           call C000:429B  ; AH=3Dh: open file
C000:6382  C3                ret
C000:6383  E8 E6DF           call C000:436C  ; AH=3Eh: close file
C000:6386  C3                ret
C000:6387  E8 FAE5           call C000:4984  ; AH=3Fh: read file
C000:638A  C3                ret
C000:638B  E8 54E7           call C000:4AE2  ; AH=40h: write file
C000:638E  C3                ret
C000:638F  E8 09EC           call C000:4F9B  ; AH=41h: delete file
C000:6392  C3                ret
C000:6393  E8 44EA           call C000:4DDA  ; AH=42h: seek
C000:6396  C3                ret
C000:6397  E8 8CEC           call C000:5026  ; AH=43h: get/set attributes
C000:639A  C3                ret
C000:6405  E8 35E1           call C000:453D  ; AH=4Eh: find first
C000:6408  C3                ret
C000:6409  E8 7DE1           call C000:4589  ; AH=4Fh: find next
C000:640C  C3                ret
C000:640D  E8 46E3           call C000:4756  ; AH=56h: rename file
C000:6410  C3                ret
C000:6411  E8 7EE4           call C000:4892  ; AH=57h: get/set file date
C000:6414  C3                ret
C000:6415  E8 13DD           call C000:412B  ; AH=5Bh: create new (same as 3Ch)
C000:6418  C3                ret
```

## Implementation Dispatch Map

| AH | DOS function | Stub | Implementation | Address range |
| ---: | --- | --- | --- | --- |
| `03h` | Aux input | `C000:62F6` | direct | |
| `04h` | Aux output | `C000:0FFC` | direct | |
| `05h` | Printer output | `C000:6325` | direct | |
| `08h` | Char input (no echo) | `C000:6334` | direct | |
| `0Bh` | Check input status | `C000:633B` | direct | |
| `0Eh` | Select disk | `C000:6342` | direct | |
| `19h` | Get current disk | `C000:6346` | direct | |
| `1Ah` | Set DTA address | `C000:634A` | direct | |
| `2Ah` | Get date | `C000:634E` | direct | |
| `2Bh` | Set date | `C000:635B` | direct | |
| `2Ch` | Get time | `C000:6362` | direct | |
| `2Dh` | Set time | `C000:636C` | direct | |
| `2Fh` | Get DTA | `C000:6373` | `C000:3F88` | |
| `36h` | Disk free space | `C000:6377` | `C000:3F98` | |
| `3Ch` | Create file | `C000:637B` | `C000:40B3` | `4000..4300` |
| `3Dh` | Open file | `C000:637F` | `C000:429B` | `4200..4400` |
| `3Eh` | Close file | `C000:6383` | `C000:436C` | `4300..4500` |
| `3Fh` | Read file | `C000:6387` | `C000:4984` | `4900..4B00` |
| `40h` | Write file | `C000:638B` | `C000:4AE2` | `4A00..4D00` |
| `41h` | Delete file | `C000:638F` | `C000:4F9B` | `4F00..5100` |
| `42h` | Seek | `C000:6393` | `C000:4DDA` | `4D00..4F00` |
| `43h` | Get/set attrs | `C000:6397` | `C000:5026` | `5000..5200` |
| `44h` | IOCTL | `C000:639B` | dispatch | `6300..6500` |
| `4Eh` | Find first | `C000:6405` | `C000:5A0C` | `5A00..5B00` |
| `4Fh` | Find next | `C000:6409` | `C000:5A33` | `5A00..5B00` |
| `56h` | Rename | `C000:640D` | `C000:5B83` | `5B00..5C00` |
| `57h` | Get/set date | `C000:6411` | `C000:5BC9` | `5B00..5D00` |
| `5Bh` | Create new | `C000:6415` | `C000:40B3` | same as 3Ch |
| `FFh` | Store validate | `C000:4396` | direct | `4300..4500` |

## IOCTL Dispatch (AH=44h)

The IOCTL handler at `C000:639B` has its own sub-dispatch based on AL:

```asm
; file 0xC639B
C000:639B  8B 46 00          mov ax,[bp+0]    ; AX from caller
C000:639E  0A C0             or al,al
C000:63A0  74 28             jz C000:63CA     ; AL=0: get device info
C000:63A2  2D 2044           sub ax,4420      ; AL=0x20: ?
C000:63A5  74 27             jz C000:63CE
C000:63A7  48                dec ax           ; AL=0x21
C000:63A8  74 28             jz C000:63D2
C000:63AA  48                dec ax           ; AL=0x22
C000:63AB  74 2C             jz C000:63D9
...
```

## File Implementation Routines

The actual file operations live in three main clusters, now fully traced
via the `--int21` flag:

- **`C000:40B3..4540`** — create, open, close, storage dispatch
- **`C000:4984..5100`** — read, write, seek, delete, attributes
- **`C000:453D..4892`** — find first/next, rename, date/time

### Shared Helpers

| Address | Callers | Purpose |
| --- | --- | --- |
| `C000:528B` | create, open, delete, attrs, find, rename | Filename parser. Takes DS:DX (filename), ES from `[BP+8]`. |
| `C000:587C` | close, read, write, seek | Handle lookup. Resolves BX (file handle) to internal state. |
| `C000:5D25` | create | Directory operation. |
| `C000:5DB7` | delete | Directory removal. |
| `C000:0D42` | read, write | DreamLink endpoint check. Tests `[6F51]` for endpoint `0x0A`. |
| `C000:5703` | seek | File pointer helper. |
| `C000:5497` | seek, attrs | Storage geometry helper. |
| `C000:569B` | close | Handle release. |
| `C000:50F5` | attrs | Attribute modifier. |

### Implementation Entry Points (Traced)

**`C000:40B3` — Create file (AH=3Ch).** Saves CX (attributes) to
`[6F1C]`, parses filename via `C000:528B`, calls directory operations.

```asm
C000:40B3  89 0E 1C6F        mov [6F1C],cx    ; save attributes
C000:40B7  8B F2             mov si,dx         ; SI = filename
C000:40B9  52                push dx
C000:40BA  06                push es
C000:40BB  8E 46 08          mov es,[bp+8]     ; ES from caller
C000:40BE  E8 CA11           call C000:528B    ; parse filename
```

**`C000:429B` — Open file (AH=3Dh).** Saves access mode from AX to
`[6F32]`, parses filename, may fall through to create at `C000:40B3`.

**`C000:436C` — Close file (AH=3Eh).** Calls handle lookup (`587C`),
handle release (`569B`), jumps to common return at `C000:51CA`.

```asm
C000:436C  E8 0D15           call C000:587C    ; handle lookup
C000:436F  E8 2913           call C000:569B    ; handle release
C000:4372  E9 550E           jmp C000:51CA     ; common return
```

**`C000:4984` — Read file (AH=3Fh).** Calls handle lookup, checks if
endpoint is DreamLink (`[6F51]==0x0A`), reads data.

**`C000:4AE2` — Write file (AH=40h).** Same structure as read — handle
lookup, DreamLink check, write data.

**`C000:4DDA` — Seek (AH=42h).** Handle lookup, clears `[6F41..6F44]`,
saves DX:CX as seek offset to `[6F12..6F15]`, dispatches on seek mode
from AX.

**`C000:4F9B` — Delete file (AH=41h).** Sets `[6FE2]=1`, parses
filename, calls directory removal at `C000:5DB7`.

**`C000:5026` — Get/set attributes (AH=43h).** Parses filename,
dispatches on AL (0=get, 1=set).

### File State Variables

| Address | Purpose |
| --- | --- |
| `[6F1C]` | Create attributes (from CX) |
| `[6F32]` | Open access mode (from AL) |
| `[6F41..6F44]` | Seek result accumulator |
| `[6F12..6F15]` | Seek offset (DX:CX from caller) |
| `[6F51]` | Current storage endpoint |
| `[6F5A]` | Seek mode (from AL) |
| `[6F5E..6F61]` | File handle table (4 bytes, cleared to FF) |
| `[6FE2]` | File operation active flag |
| `[15AF]` | Error code word |
