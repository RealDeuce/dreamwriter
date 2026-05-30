# DreamWriter 325 BASIC As EROMCARD.X

This is a feasibility note for extracting the BASIC interpreter from the
DreamWriter 325 ROM and repackaging it as a T400 `EROMCARD.X` executable.

Source image examined:

```text
../tmp/dw325 - 2_0US.BIN
size:   524288 bytes
sha256: d88cf3739b6d44318c1ab14215f748fe3f5e70aa34f1594e3c629795a0201c61
```

The source file is outside this repo and is not part of the T400 ROM map.
Addresses below are file offsets in the 325 image unless otherwise noted.

## First-Pass Findings

The 325 firmware integrates BASIC as a built-in application. Its OTHERS menu
string cluster contains:

```text
0x6BC42  EROMCARD.X
0x6BC6A  SYSTEM
0x6BC77  SECRET
0x6BC84  DICTIONARY
0x6BC91  BASIC
0x6BC9E  ROM CARD
```

There is also a BASIC directory/execution UI in the file-resource string area:

```text
0x545AC  BASIC
0x545B4  DIRECTORY
0x545C2  Position cursor to a file
0x545E7  to execute
0x54601  to change Built-in or Card
0x5462A  to cancel
```

The interpreter itself appears to live in the high ROM application area, roughly
`0x74000..0x7FFFF`. This is the same broad area that contains Typin' Time in the
T400 ROM, so it looks like a replaceable high-ROM application slot rather than
a small independent routine.

Useful BASIC landmarks:

```text
0x785E3  keyword/token string area: APPEND, BEEP, CHR$, CLEAR, CLOSE, DATA...
0x786CC  PRINT
0x7F58A  Redo from start
0x7F5A0  Can't load the file
0x7F5B4  Line too long
0x7F5C2  Invalid line format
0x7F5D6  Inadequate work memory
0x7F60F  BASICPROGRAM:
0x7F61E  PROGRAM TEXT AREA
0x7F630  ARRAY VARIABLE AREA
0x7F644  SIMPLE VARIABLE/STRING AREA
0x7F6BC  NEXT without FOR
0x7F6CE  Syntax error
0x7F714  Overflow
0x7F71E  Out of memory
0x7F800  File not found
0x7F8CE  Program terminated normally
0x7F8EA  Break
0x7FC02  SCRN
0x7FC07  LPT
0x7FC0C  COM
0x7FC11  KYBD
```

## Why It Is Not A Direct Copy

The 325 BASIC code makes near calls within its loaded segment and also far-calls
firmware service trampolines in the 325 ROM. In particular, the 325 image has an
`F200:xxxx` trampoline page at file `0x72000`. It begins with a table of
`jmp far [0x0204]`, `jmp far [0x0208]`, and similar IVT/RAM-vector jumps, plus
small local service wrappers.

The T400 ROM does not have the same `F200` page at file `0x72000`; that area is
ordinary resource/data in the T400 image. Therefore the high-ROM BASIC code
cannot simply be copied into an `EROMCARD.X` file and expected to run.

Confirmed far calls from the 325 high-ROM BASIC area to `F200` include:

```text
F200:0004  many call sites around 0x79F9C..0x7A372
F200:0008  0x79F2C, 0x7A056, 0x7A11D
F200:0020  0x75BC3, 0x763D0, 0x79FB9, 0x7A0DA
F200:0024  0x78284, 0x78293, 0x782A2, 0x782DE, 0x782ED, 0x782FC, 0x7903D, 0x7A09F, 0x7A2C0
F200:0028  0x7A0A7, 0x7A2C8
F200:0030  0x7880A, 0x79FB2, 0x7A07C, 0x7A37C
F200:0038  0x75CD6, 0x771ED, 0x7A074, 0x7A0D2
F200:0040  0x7529E, 0x7B939, 0x7BA14, 0x7BA87, 0x7BB30, 0x7BC44, 0x7BCB3
F200:0044  0x752C5, 0x752FB, 0x75353, 0x7D635
F200:0048  0x7D6AE
F200:004C  0x7531C, 0x7DCD2, 0x7DD2D
F200:0050  0x7C7E0
F200:0058  0x7CA50
F200:005C  0x7D607, 0x7D68C
F200:0068  0x7C2C8
F200:0080  0x7B8E9, 0x7B9F0, 0x7BAE6, 0x7BC20, 0x7C797, 0x7C9BD, 0x7CA10
F200:009C  0x7B687
```

The exact meaning of each `F200` service is not decoded yet. Because the
trampoline mostly jumps through low RAM vectors beginning at `0x0204`, the first
thing to check is whether those vector indexes match the T400 vector table built
by `C000:0ED6`.

That comparison is now partly confirmed. The T400 still builds a low-RAM far
pointer table at `0x0200` from ROM table `C000:0F94`, but it does not keep the
325's `F200:` trampoline page. In other words, the newer ROM appears to retain
the underlying vector-table ABI and replace most high-level consumers with
direct calls or DOS-like `INT 21h` wrappers.

For the `F200` entries used by the 325 BASIC code, the equivalent T400 low-RAM
vectors would resolve as follows after startup:

| 325 call | Low-RAM vector | T400 startup target | Current read |
| --- | ---: | --- | --- |
| `F200:0004` | `[0204]` | `DC98:0E81` | Display text wrapper; builds an `FF 40` LCD stream. |
| `F200:0008` | `[0208]` | `DC98:0EE5` | Display/blit wrapper; builds paired `FF 44` LCD commands. |
| `F200:0020` | `[0220]` | `DC98:0E70` | Display helper around `C000:67AD`. |
| `F200:0024` | `[0224]` | `DC98:1077` | Numeric-to-decimal string formatter. |
| `F200:0028` | `[0228]` | `DC98:10D4` | Leading-zero cleanup for formatted numeric strings. |
| `F200:0030` | `[0230]` | `DC98:0CF9` | Blocking key read wrapper around `INT 21h AH=08`. |
| `F200:0038` | `[0238]` | `DC98:0DAF` | Wrapper around `C000:087F`; exact low-level service still open. |
| `F200:0040` | `[0240]` | `DC98:E8D5` | File open/create convenience wrapper. |
| `F200:0044` | `[0244]` | `DC98:E946` | File open/create implementation helper. |
| `F200:0048` | `[0248]` | `DC98:EE08` | File read wrapper around `INT 21h AH=3F`. |
| `F200:004C` | `[024C]` | `DC98:EA54` | Higher-level file read/write helper. |
| `F200:0050` | `[0250]` | `DC98:EE2E` | File close wrapper around `INT 21h AH=3E`. |
| `F200:0058` | `[0258]` | `DC98:EE40` | File delete wrapper around `INT 21h AH=41`. |
| `F200:005C` | `[025C]` | `DC98:EE56` | File rename wrapper around `INT 21h AH=56`. |
| `F200:0068` | `[0268]` | `DC98:EA98` | File I/O helper; exact high-level convention still open. |
| `F200:0080` | `[0280]` | `DC98:EFD6` | Get free space wrapper around `INT 21h AH=36`. |
| `F200:009C` | `[029C]` | `DC98:F052` | Set file date/time wrapper around `INT 21h AX=5701`. |

This supports the compatibility-thunk approach below: a T400 `EROMCARD.X`
package could provide a small local `F200`-style trampoline page, or rewrite
each 325 `call F200:xxxx` to call the corresponding T400 vector/wrapper
directly. The unresolved risk is calling convention drift: the target addresses
line up with plausible services, but the 325 BASIC call sites still need to be
checked against the T400 wrapper argument conventions one service at a time.

## Plausible EROMCARD.X Shape

The T400 `ROM CARD` loader reads `EROMCARD.X` to physical `0x0A4F0`, validates
the `0xA4F0/0x1997` header, and calls the far pointer at file offset `+0x04`.
See [`file-system.md`](file-system.md#rom-card-loader).

A practical package would likely look like:

```text
+0x0000  word 0xA4F0
+0x0002  word 0x1997
+0x0004  far pointer to entry stub
+0x0008  padding/alignment
+0x0010  copied 325 BASIC segment body, aligned to physical 0xA5000
...      entry stub and local thunks, or thunks placed before the copied body
```

If the BASIC body starts at `EROMCARD.X` file offset `0x10`, the loader places
it at physical `0x0A5000`, which is addressable as `0A50:0000`. That preserves
the interpreter's internal near offsets if the body is treated as a single
relocated segment.

The entry stub would probably:

```asm
; sketch only
push cs
pop  ds
push cs
pop  es
call/jmp basic_entry
retf or return AX convention for ROM CARD
```

The real entry point still needs to be identified from the 325 OTHERS -> BASIC
menu dispatch.

## Patch Strategy For F200 Calls

The cleanest-looking patch is to replace each 5-byte `call F200:xxxx` with a
same-size local near-call sequence:

```asm
push cs
call local_f200_xxxx_thunk
nop
```

The local thunk can then emulate the 325 `F200` behavior, for example by jumping
through the T400 low-RAM vector table if the vector index is compatible:

```asm
local_f200_0024_thunk:
    jmp far [0x0224]
```

This preserves far-call return behavior: the original call would push a far
return address, and `push cs` plus `call near` also leaves a far-looking return
frame for a `retf`-returning target.

If the T400 vector table does not match the 325 vector table, the thunks need to
translate each `F200` service to the equivalent T400 firmware service or
reimplement the small service locally.

## Current Feasibility Read

This looks hackable, but not trivial.

Reasons it is plausible:

- The BASIC body seems to fit under the ROM CARD loader's practical 64 KiB read
  limit if copied as the high-ROM application area.
- It uses the firmware's DOS-like file/storage and display services rather than
  obvious direct hardware-only assumptions for everything.
- The repeated `F200` calls are easy to locate and have a bounded service set.
- Loading at `0xA4F0` can be arranged so the BASIC body starts at a clean
  paragraph boundary (`0xA5000` / `0A50:0000`).

Reasons it is not a direct transplant:

- The 325 BASIC code assumes an `F200` trampoline page that the T400 does not
  provide.
- The real BASIC application entry point still needs to be traced.
- The RAM variables used by BASIC, including the visible `0x80xx`/`0x81xx`
  state area, need to be checked against T400 allocations.
- Any 325-specific menu setup or current-document/storage state must either be
  reproduced by the entry stub or bypassed safely.

## Next Steps

1. Trace the 325 OTHERS -> BASIC handler from the menu string/table around
   `0x6BC6A..0x6BC9E` to identify the real BASIC entry point and setup calls.
2. Decode the 325 `F200` trampoline page at file `0x72000` and map each used
   offset to a low-RAM vector or helper.
3. Compare the 325 and T400 low-RAM vector tables installed around `0x0200`.
4. Identify the BASIC RAM state ranges and check for collisions with T400
   `EROMCARD.X` execution state.
5. Build a minimal `EROMCARD.X` proof of concept that just enters a copied BASIC
   banner or error path before attempting full file/program execution.
