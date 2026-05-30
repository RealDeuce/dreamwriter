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

The 325 OTHERS menu dispatch is now confirmed. The menu handler at
`DA69:3455` / file `0x5DAE5` uses table `0x6BC42`; option `4`, `BASIC`, calls
`C57E:DC71`, while option `5` calls the ROM-card loader. `C57E:DC71` is only a
far wrapper: it saves registers, sets `ES=09C0`, calls `C57E:8135`, then returns
`[811F]` in `AL`.

`C57E:8135` is the built-in BASIC launch UI. It draws resource `0x64`, uses the
shared file picker to select a program, builds a drive-qualified selected-file
path at `0x7F5F`, computes a work-memory byte limit from `[8229] * 0x80`, sets
`AX=09C0`, and calls `C57E:01A0`. That helper is the actual high-ROM handoff:

```asm
C57E:01A0  push es
C57E:01A1  mov  si,F200
C57E:01A4  mov  es,si
C57E:01A6  call far [es:0000]
C57E:01AB  pop  es
C57E:01AC  ret
```

The 325 `F200` page begins with the far pointer `F200:7DAB`, so the real BASIC
entry is `F200:7DAB` / file `0x79DAB`. Its launch convention is now bounded:

| Register/input | Meaning on current read |
| --- | --- |
| `DS` | Zero-based firmware/application RAM state; the entry writes low-RAM work fields such as `0x478E..0x47A6`. |
| `AX` | Work-buffer segment from the wrapper, normally `09C0`. |
| `BX` | Work-memory byte limit from `[8229] * 0x80`; values below `0x0C84` produce the BASIC inadequate-memory path. |
| `CX` | Pointer to the NUL-terminated selected program path at `0x7F5F`. |
| `ES` | Set to `09C0` by the wrapper before handoff. |

`F200:7DAB` checks the memory limit, derives several work-area bounds, opens the
selected BASIC file through the `F200:0040` file wrapper, validates the
file-internal header, then enters the interpreter loop. This means an
`EROMCARD.X` package cannot just jump to the interpreter with no context if the
goal is to run a normal BASIC program: it either needs to reproduce a minimal
file-picker/path setup or choose a fixed startup program name and place that
program on the card too.

The current `basic-exec` experiment uses this direct interpreter handoff. It
does not call the full 325 BASIC UI/file-picker loader at `C57E:8135`; it only
fakes the final selected-path/register state and calls `F200:7DAB`. If
`C57E:8135` also initializes BASIC-specific display or runtime state, that would
explain a blank screen or hang even though the PCMCIA mapping and `F200`
trampoline tests pass.

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
| `FF39:000A` | `[023C]` | `C000:67BF` | Poll/idle wrapper around `C000:49FD`; used by BASIC runtime `F200:6800` before the blocking key read. |
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

There is a larger relocation problem beyond the `F200` service calls. The BASIC
code also uses absolute high-ROM far pointers for its own text/resources. For
example, `F200:7E9F` chooses BASIC error-message pointers such as
`FF5B:0004`, `FF5C:0002`, and `FF5D:0006`, which target physical strings around
file `0x7F5A0..0x7F5EE`. The T400 display-text wrapper at `DC98:0E81` really
does treat its `AX/BX` pair as a far pointer by doing `LES BX,[BP-4]`, so those
segment:offset pairs must be relocated, not merely left as 16-bit offsets.

There are also internal high-ROM aliases such as `FF39:0006`, which target code
inside the 325 BASIC image by physical address. If the `F200` segment is copied
to RAM at the `EROMCARD.X` load address, these aliases still point back into
the T400 ROM address space unless they are rewritten. So the simple plan of
"copy the `0x72000..0x7FFFF` segment and patch `call F200:xxxx`" is incomplete.
A real packer needs a relocation pass for code and resource far pointers whose
physical targets fall inside the copied 325 high-ROM span.

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
relocated segment, but it does not by itself repair the absolute far pointers
described above.

The entry stub would probably:

```asm
; sketch only
mov  bx,ax            ; keep ROM CARD work-memory limit
xor  ax,ax
mov  ds,ax            ; BASIC expects zero-based firmware RAM state
mov  ax,09C0
mov  es,ax            ; match the 325 wrapper's work-buffer segment
mov  cx,program_path  ; or build this via a local file picker
call relocated_basic_entry
retf or return AX convention for ROM CARD
```

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

An alternate packer strategy is to copy the whole `F200` page and rewrite far
calls whose target segment is `F200` to the relocated body segment. That handles
the service calls and the local `F200:0004` trampoline page, but still leaves
the `FFxx:xxxx` high-ROM aliases and display-string far pointers to fix. The
relocation rule for those is physical-address based: if an original far pointer
targets a physical address in `0xF2000..0xFFFFF`, translate that physical target
to the copied body's new physical base plus `(target - 0xF2000)`.

## SRAM Image Loading Notes

The scratch image at `/tmp/dw-card-1m.bin` is a formatted card image, but its
DreamWriter header says geometry `0x0010`, i.e. sixteen 32 KiB units or about
512 KiB of usable storage. The relevant layout for inserting a future
`EROMCARD.X` by hand is now understood well enough for a simple writer:

| Region | Offset in image | Notes |
| --- | ---: | --- |
| DreamWriter volume header | `0x0000` | Words `0x1997`, `0x0126`, geometry `0x0010`. |
| FAT12 table | `0x0080` | Starts with `F9 FF FF`; cluster `2` is already allocated in the current image. |
| Root directory | `0x1880` | Four 128-byte sectors, i.e. sixteen 32-byte directory entries. |
| First data cluster, cluster `2` | `0x2880` | Cluster size is 128 bytes. |

The current image already contains one file, `Test.txt`, in root entry `0`,
starting at cluster `2` with size `0x36`. A future `.X` installer can use the
next free 32-byte root entry and allocate clusters from `3` upward. For geometry
`0x10`, the byte offset for cluster `N` is:

```text
offset = (N + 0x4F) * 0x80
```

The directory entry is standard enough for this use: name in 8.3 fields,
attribute byte `0x20`, first cluster at `+0x1A`, and file size at `+0x1C`.
The firmware's ROM-card loader searches for `EROMCARD.X` through the normal
file API, so no ROM-card-specific directory entry is needed.

## Top-Window PCMCIA Experiment

A useful shortcut for MAME testing is to avoid relocating the 325 high-ROM
aliases at all. The current MAME bank model lets the SRAM card appear in CPU
memory. With the top 128 KiB CPU window selected, bank value `0x1B` maps card
page `4` to `0xE0000..0xFFFFF`. Placing the 325 ROM slice
`0x60000..0x7FFFF` at card offset `0x80000` therefore makes the original 325
addresses line up:

```text
card 0x80000 + 0x12000  -> CPU 0xF2000 -> F200:0000
card 0x80000 + 0x19DAB  -> CPU 0xF9DAB -> F200:7DAB
card 0x80000 + 0x1F5B4  -> CPU 0xFF5B4 -> FF5B:0004
```

`tools/build_basic_eromcard.py` builds this test image. It creates a tiny
`EROMCARD.X` that writes `0x1B` to port `0x17`, copies a fixed BASIC program
path to `0x7F5F`, sets up the 325 wrapper register convention, and calls
`F200:7DAB`. The stub currently uses `AX/ES=0800` and `BX=2000` for the BASIC
work area, keeping it below the ROM-card loader's `0xA4F0` load address so the
interpreter does not overwrite the loaded stub/return frame immediately.

Because MAME models LCD scanout base selection through port `0x00` as
`value << 9`, the BASIC wrapper also changes the displayed framebuffer before
entering the interpreter. For the default `0800` work segment, physical
`0x8000` corresponds to LCD port value `0x40`; the wrapper restores the normal
boot/menu value `0x08` if BASIC returns. This matches the likely 325 loader
behavior: it sets `[7653]=1` immediately before the BASIC handoff and clears it
after return, and the low boot/resume code checks `[7653]` while deciding which
display state to restore.

The generated `BASIC.BAS` is editor-readable. Stored editor files begin with
`0xFF`, a one-byte header length, then a document header; the BASIC loader reads
and skips that header before parsing the visible text stream. The current test
file therefore uses the same 16-byte header shape seen in the saved `Test.txt`
card file, followed by the BASIC source and the editor line separator `0x0C`:

```text
ff 10  <16-byte editor header>  10 CLS 0c ...
```

The default generated BASIC program is now a blocking smoke test:

```basic
10 PRINT "BASIC EXEC OK"
20 INPUT "PRESS ENTER";A$
```

This should remain in BASIC until keyboard input is accepted.

The builder accepts repeated `--basic-line` arguments for multi-line test
programs. For example, this creates a version that explicitly opens the BASIC
screen device named in the 325 manual, overwriting the canonical scratch test
image at `/tmp/dw-card-1m-basic.bin`:

```sh
python3 tools/build_basic_eromcard.py \
  --basic-line '10 OPEN "SCRN:" FOR OUTPUT AS #1' \
  --basic-line '20 PRINT #1;"HELLO, WORLD!"' \
  --basic-line '30 CLOSE #1'
```

The BASIC open parser at `F200:96E6` recognizes colon-prefixed pseudo-device
names through the table at `0x7FC02`:

| Name | Returned class | Current read |
| --- | ---: | --- |
| `SCRN:` | `0x80` | Screen output device. Opens by marking the BASIC handle as type `2`; input modes report error `0x36`. |
| `LPT:` | `0x81` | Printer output device. Opens by marking the handle as type `2`; input modes report error `0x36`. |
| `COM:` | `0x82` | Serial device. Opens by marking the handle as type `4` and clearing `[47D3]`. |
| `KYBD:` | `0x83` | Keyboard input device. Opens by marking the handle as type `1`; output modes report error `0x36`. |

The default command writes the current proof-of-concept artifacts to `/tmp`:

```sh
python3 tools/build_basic_eromcard.py
```

Default outputs:

```text
/tmp/EROMCARD.X
/tmp/BASIC.BAS
/tmp/dw-card-1m-basic.bin
```

One MAME command line for the generated image is:

```sh
../mame/drwrt400 drwrt400 -pcmcia melcard_1m -sramcard /tmp/dw-card-1m-basic.bin
```

For isolating the T400 ROM-card loader before entering the 325 BASIC runtime,
the same builder can create a small smoke-test `EROMCARD.X` in the canonical
card image:

```sh
python3 tools/build_basic_eromcard.py --stub smoke
```

The smoke stub does not remap PCMCIA into the top ROM window. It displays
`EROMCARD OK - PRESS KEY` through low-RAM vector `[0204]`, waits for one key
through `[0230]`, and then returns from the ROM-card executable.

The next isolation step is the mapped smoke test:

```sh
python3 tools/build_basic_eromcard.py --stub smoke-map
```

This patches `MAPPED PAGE OK - PRESS KEY` into card page `4` at the address
that should appear as CPU `FF00:0000`, writes bank value `0x1B` to port `0x17`,
displays the string through `[0204]`, waits through `[0230]`, restores port
`0x17` to zero, and returns. This tests top-window PCMCIA reads without entering
the 325 BASIC runtime.

The mapped execution smoke test goes one step further:

```sh
python3 tools/build_basic_eromcard.py --stub smoke-exec
```

This patches a small routine at CPU `FF00:0000` in card page `4`. The loaded
`EROMCARD.X` maps the card page, calls `FF00:0000`, and the mapped routine
displays `MAPPED CODE OK - PRESS KEY`, waits for one key, and returns with
`RETF`. Passing this test proves that the CPU can fetch and return from code in
the mapped PCMCIA top window.

The `basic-exec` mode was useful for proving card-executed wrapper code, but it
is not a good default for the real BASIC experiment. It places the wrapper at
`FF00:0000`, which is physical `0xFF000` / 325 file `0x7F000`. That area is
inside the BASIC high-ROM body; the error/display code around `F200:7E9F`
continues through `0x7F000..0x7FC5`, and the later strings/resources also live
nearby. Overwriting it can turn an ordinary BASIC load/display error into a
hang. The safer `basic` mode keeps the 325 high ROM page intact and runs the
wrapper from the RAM-loaded `EROMCARD.X`.

The `F200` trampoline smoke test isolates the next boundary:

```sh
python3 tools/build_basic_eromcard.py --stub f200-smoke
```

This still enters through the loaded `EROMCARD.X` and still executes the test
routine from mapped `FF00:0000`, but the mapped routine displays
`F200 TRAMPOLINE OK - PRESS KEY` through `call F200:0004` and waits through
`call F200:0030`. Passing this test proves that code fetched from the card can
use the 325 high-ROM trampoline page to reach the T400 low-vector display and
keyboard services. Failing here would mean the blank BASIC launch is happening
before the full interpreter/file path, probably in the `F200` service boundary.

The BASIC-entry probe isolates the direct interpreter call:

```sh
python3 tools/build_basic_eromcard.py --stub basic-probe
```

This displays `BEFORE BASIC - PRESS KEY`, waits, then calls the same direct
`F200:7DAB` entry used by `basic-exec`. If BASIC ever returns, it displays
`BASIC RETURNED - PRESS KEY`. Seeing the first message and then a blank/hang
after the keypress means the failure is inside the direct BASIC entry or its
missing launch state, not in the ROM-card loader, mapped execution, or `F200`
trampoline boundary.

The wrapper step probe stops short of entering BASIC:

```sh
python3 tools/build_basic_eromcard.py --stub basic-steps
```

It displays and waits after each wrapper-controlled operation: mapped wrapper
entry, selected-path copy to `0x7F5F`, setting `[7653]=1`, loading the final
`AX`/`BX`/`CX`/`DS`/`ES` handoff registers, and the LCD scanout switch. The LCD
test says `STEP 5 LCD SWITCH NEXT`, waits, copies the known visible framebuffer
from `0x1000` to the selected BASIC framebuffer, writes port `0x00=0x40`, waits
once while the alternate framebuffer is displayed, restores port `0x00=0x08`,
and then says `STEP 6 LCD RESTORED`. It then stops at
`STEP 7 WOULD CALL BASIC` without calling `F200:7DAB`. Seeing `STEP 5` twice is
expected: the second view is the copied `0x8000` framebuffer after the LCD
scanout switch.

The BASIC load probe isolates the file-loader/parser helper before the
interpreter loop:

```sh
python3 tools/build_basic_eromcard.py --stub basic-load-probe
```

This mode keeps the wrapper in the RAM-loaded `EROMCARD.X`, copies
`I:BASIC.BAS` to `0x7F5F`, reproduces the low-RAM work-area fields that
`F200:7DAB` computes before parsing the program, and then far-calls a tiny
probe pocket at `F200:DE3A`. That pocket is patched into a 438-byte `0xFF`
padding run at 325 file `0x7FE3A`; because it runs inside the `F200` segment,
it can safely make the near call to `F200:31B6` and `RETF` back to the
ROM-card stub.

The expected visible sequence is `BEFORE LOAD - PRESS KEY`, followed by either
`LOAD OK - PRESS KEY` or `LOAD FAILED - PRESS KEY`. A blank screen or hang
after the first keypress means the failure is in the early 325 BASIC
file-loader/parser path or in one of the T400 file-service vectors it reaches
through the 325 `F200` trampoline page. Seeing `LOAD OK` would move the next
fault boundary past file parsing and into the later `F200:7DAB` interpreter
initialization calls.

The current observed result is narrower: after `BEFORE LOAD`, pressing a key
briefly draws horizontal junk and then resets the machine. That points to a
probable execute-in-place collision. The probe is running 325 code from the
PCMCIA-mapped top window, while the first file-loader call opens/reads
`I:BASIC.BAS` from the same PCMCIA storage. If the T400 file layer remaps the
card window for sector I/O, it can replace the code currently executing at
`F200:31B6`.

A smaller RAM-only file probe tests that theory:

```sh
python3 tools/build_basic_eromcard.py --stub basic-file-probe
```

This does not execute the 325 loader/parser. It copies `I:BASIC.BAS` to
`0x7F5F`, opens it through low vector `[0244]`, reads two bytes through
`[0248]`, verifies the editor-file marker byte `0xFF`, closes through `[0250]`,
and reports the result. If this reaches `READ OK - PRESS KEY`, the file and
T400 low-vector open/read/close path are usable from a RAM-loaded `EROMCARD.X`;
the reset in `basic-load-probe` is then most likely caused by executing 325 code
from the mapped card while the card file layer is active.

The `basic-file-probe` result now confirms that boundary: it reaches
`READ OK - PRESS KEY` and returns to the menu.

The next probe keeps the file I/O path in play but removes card-window
execute-in-place:

```sh
python3 tools/build_basic_eromcard.py --stub basic-ram-load-probe
```

The first version embedded the 325 `F200:0000..3B8D` loader/parser slice inside
`EROMCARD.X`, copied it to RAM segment `1200`, patched the five
`call F200:0040/0044/004C` file-service sites inside that copied slice to
direct low-vector calls through `[0244]`, `[0248]`, and `[0250]`, cleared the
PCMCIA top-window bank, then called `1200:31B6`. It reached
`BEFORE RAM LOAD - PRESS KEY`, then hung with varying screen junk after the
keypress.

That hang is probably explained by an undersized copied slice. The parser's
line-number conversion routine at `F200:3935` immediately calls `F200:4FD3`,
outside the original `0x3B8E` byte copy. The current test image therefore uses
a wider `0x5000` byte copy by default:

```sh
python3 tools/build_basic_eromcard.py --stub basic-ram-load-probe
```

For wider slices, the builder patches every direct `call F200:xxxx` trampoline
call whose target is in the low-vector table range, not only the file-service
calls. In the current `0x5000` byte slice, that removes direct `F200:` calls to
`0020`, `0038`, `0040`, `0044`, and `004C`.

One important probe bug was also fixed here: `F200:31B6` is a near subroutine
that returns with `RET`, so the RAM probe must not far-call it directly. The
builder now appends a tiny same-segment wrapper at the end of the copied slice.
For the default `0x5000` byte copy it is:

```asm
1200:5000  push 5007
1200:5003  push 31B6
1200:5006  ret
1200:5007  retf
```

The loaded `EROMCARD.X` far-calls that wrapper instead of far-calling
`1200:31B6`. The previous direct far call could leave a stale segment word on
the stack after `31B6` returned, corrupting subsequent control flow or retained
resume state.

With the wider copy and the wrapper fix, this probe reaches
`RAM LOAD OK - PRESS KEY` and returns to the menu. That proves the 325 BASIC
text loader/parser can run from RAM on the T400 when its low-vector service
calls are thunked and the PCMCIA card is not being executed while it is read.
The next boundary is no longer file loading; it is the post-load runtime
initialization sequence after `F200:31B6`, especially the calls at
`F200:7E20..7E26` to `83EB`, `7C82`, and `7C1E`.

The post-load initializer step probe is:

```sh
python3 tools/build_basic_eromcard.py --stub basic-init-steps-probe
```

It uses the same `0x5000` byte RAM-copied loader/parser setup, then remaps the
325 high page after `31B6` returns so absolute `FFxx:` data references see the
325 tables. The post-load initializer calls do not copy the whole runtime
initializer region into T400 RAM. Instead, the builder patches tiny wrappers
into the known `F200:DE3A` padding run in the mapped 325 page:

```asm
F200:DE3A  push DE41  ; call 83EB, then retf
F200:DE3D  push 83EB
F200:DE40  ret
F200:DE41  retf

F200:DE42  push DE49  ; call 7C82, then retf
F200:DE45  push 7C82
F200:DE48  ret
F200:DE49  retf

F200:DE4A  push DE51  ; call 7C1E, then retf
F200:DE4D  push 7C1E
F200:DE50  ret
F200:DE51  retf
```

This avoids copying a `0xB000` byte slice into low RAM; that earlier attempt
overwrote RAM state needed by the T400 display/menu firmware before the first
checkpoint could be drawn. The visible checkpoints are:

```text
BEFORE RAM LOAD
RAM LOAD OK
BEFORE 83EB
AFTER 83EB
BEFORE 7C82
AFTER 7C82
BEFORE 7C1E
AFTER 7C1E
```

The first missing `AFTER ...` checkpoint identifies the next unsafe initializer
boundary.

The observed result is that the probe reaches `AFTER 7C1E - PRESS KEY` and
then returns to the menu. During the `7C82` step, the word `Ethiopia` briefly
appears on screen; the 325 ROM contains that string once at file `0x6DFA2`.
This suggests the initializer path is touching or briefly exposing a 325
resource/string table, but it is not fatal in this bounded probe. The next
unknown boundary is entering the runtime loop at `F200:7D00` after the
successful initializer sequence.

The runtime-loop probe is:

```sh
python3 tools/build_basic_eromcard.py --stub basic-runtime-probe
```

It performs the same `31B6 -> 83EB -> 7C82 -> 7C1E` sequence without per-step
pauses, then displays `BEFORE RUNTIME - PRESS KEY`. After that keypress it
sets `[7653]=1`, copies the current framebuffer from `0x1000` to the BASIC
framebuffer at `0x8000`, switches LCD scanout to port value `0x40`, and calls a
fourth mapped wrapper:

```asm
F200:DE52  push DE59  ; call 7D00, then retf
F200:DE55  push 7D00
F200:DE58  ret
F200:DE59  retf
```

If the runtime loop ever returns, the stub restores LCD scanout to `0x08`,
clears `[7653]`, displays `RUNTIME RETURNED - PRESS KEY`, unmaps the PCMCIA top
window, and returns to the ROM-card menu. A hang, blank BASIC screen, or visible
BASIC output after `BEFORE RUNTIME` narrows the remaining issue to the runtime
loop and its command-dispatch dependencies rather than file loading or
post-load initialization.

The probes now mirror another detail of the real `F200:7DAB` handoff: after
`31B6` returns, its return value is stored in `[4798]` before calling `7C82`.
This fixed a launch-state mismatch in the earlier harness.

The copied tokenizer also exposes a harder mapping problem. It does not contain
all of its data: it explicitly reads the BASIC keyword offset table at
`F200:65A5` and keyword strings/tokens that follow it. When the 325 high page is
not mapped during `31B6`, the loader returns but the default `10 PRINT ...`
program reaches the runtime as raw ASCII and the branch probe reports
`BRANCH LETTER P`. Keeping the 325 high page mapped during the whole `31B6`
call is not a valid fix either: MAME then hangs after `BEFORE RAM LOAD`,
presumably because the T400 file layer cannot safely read from the PCMCIA card
while the top-window PCMCIA bank is forced to the 325 code/data page.

The next approach should leave the live PCMCIA mapping alone during file I/O and
instead make the RAM-copied tokenizer self-contained. The likely patch is to
copy at least the keyword table/data around original `F200:65A5` into the RAM
loader slice and rewrite the hardcoded tokenizer references that set
`ES=F200`/`BX=65A5` at `F200:34FD..3513` and `F200:3551..3567` so they point at
the RAM slice segment.

The current observed result is that the full runtime-loop probe reaches
`BEFORE RUNTIME - PRESS KEY` and then hangs after the keypress. The word
`Ethiopia` is already printed before the `BEFORE RUNTIME` checkpoint, so that
display artifact belongs to the post-load initializer path rather than to the
runtime-loop entry itself.

The runtime-entry step probe splits the first two calls made by `F200:7D00`:

```sh
python3 tools/build_basic_eromcard.py --stub basic-runtime-steps-probe
```

It performs the same `31B6 -> 83EB -> 7C82 -> 7C1E` setup, then calls mapped
same-segment wrappers for `F200:6800` and `F200:C3FD` separately:

```asm
F200:DE52  push DE59  ; call 6800, then retf
F200:DE55  push 6800
F200:DE58  ret
F200:DE59  retf

F200:DE5A  push DE61  ; call C3FD, then retf
F200:DE5D  push C3FD
F200:DE60  ret
F200:DE61  retf
```

The expected visible sequence is:

```text
BEFORE RAM LOAD
RAM LOAD OK
BEFORE 6800
AFTER 6800
BEFORE C3FD
AFTER C3FD
```

Stopping before `AFTER 6800` means the runtime hang is in the break/key poll
path. That routine first calls `FF39:000A`, which jumps through low vector
`[023C]` to `C000:67BF`. The T400 target preserves the caller's registers
except `AX`, calls the idle/input helper `C000:49FD`, clears `AH`, and returns
far. BASIC then reads keys through `F200:0030` only if that status value says a
key/event is available.
Reaching `AFTER 6800` but stopping before `AFTER C3FD` moves the fault to the
first token/statement fetch path. Reaching `AFTER C3FD` moves the fault beyond
these two setup calls and into later runtime dispatch.

The observed result reaches `AFTER C3FD - PRESS KEY` and returns to the menu,
so the first runtime poll and token fetch are not the hang. The next probe
classifies the first `F200:7D00` branch after `C3FD` without calling the branch
handler:

```sh
python3 tools/build_basic_eromcard.py --stub basic-runtime-branch-probe
```

After the same load/init setup it calls `6800`, calls `C3FD`, stores the
returned runtime byte, displays `TOKEN READ - PRESS KEY`, and then displays one
of:

```text
BRANCH COLON
BRANCH EOL
BRANCH COMMAND
BRANCH LETTER
BRANCH E7
BRANCH ERROR
```

This corresponds to the top-level `F200:7D00` dispatch:

| Message | `F200:7D00` path |
| --- | --- |
| `BRANCH COLON` | `AL == 0x3A`; increment `[47A8]` and loop. |
| `BRANCH EOL` | `AL == 0x00`; increment `[47A8]`, call `7C12`, maybe advance to the next line. |
| `BRANCH COMMAND` | `0x80 <= AL <= 0xB0`; indirect command call through table at `FFB9:0006`. |
| `BRANCH LETTER` | `0x41 <= AL <= 0x5A`; variable/assignment path through `84D5`. |
| `BRANCH E7` | `AL == 0xE7`; special path through `590E`. |
| `BRANCH ERROR` | Fallback syntax/error path through `7BC5` with `AX=2`. |

The `BRANCH LETTER` message includes the actual byte as a character. The latest
confirmed output before trying the invalid always-mapped workaround was
`BRANCH LETTER P`, so the runtime was reading the `P` from raw `PRINT` after
the line header rather than a tokenized command byte. This is not evidence that
the runtime expects tokenized source files on disk; the loader contains a real
keyword recognizer, and the evidence points to that recognizer reading the wrong
table or having the wrong mapping in the current `EROMCARD.X` harness.

Large copied slices can overlap the loaded `EROMCARD.X` image. The builder
therefore copies RAM slices backwards with `STD; REP MOVSW; CLD`, giving
memmove-like behavior before any loaded `.X` tail is overwritten. That only
solves source/destination overlap; it does not make arbitrary low-RAM
destinations safe for huge runtime copies.

This is intentionally a hardware/mapping experiment, not a clean package
format. While BASIC is running, the mapped card page replaces the T400 ROM's
normal `0xE0000..0xFFFFF` contents. That should be acceptable only if the BASIC
code paths used by this first test stay within the 325 high-ROM image and the
T400 low-vector firmware services below the remapped window.

## Current Feasibility Read

This still looks hackable, but less like a same-day direct transplant than the
first pass suggested.

Reasons it is plausible:

- The BASIC body seems to fit under the ROM CARD loader's practical 64 KiB read
  limit if copied as the high-ROM application area.
- The MAME PCMCIA bank model gives us a direct way to map the 325 high ROM into
  its original CPU addresses for a proof-of-concept run.
- It uses the firmware's DOS-like file/storage and display services rather than
  obvious direct hardware-only assumptions for everything.
- The repeated `F200` calls are easy to locate and have a bounded service set.
- Loading at `0xA4F0` can be arranged so the BASIC body starts at a clean
  paragraph boundary (`0xA5000` / `0A50:0000`).

Reasons it is not a direct transplant:

- The 325 BASIC code assumes an `F200` trampoline page that the T400 does not
  provide.
- The entry point is now known, but it expects a selected BASIC program path and
  launch state from the 325 built-in wrapper.
- The RAM variables used by BASIC, including the visible `0x80xx`/`0x81xx`
  state area, need to be checked against T400 allocations.
- Any 325-specific menu setup or current-document/storage state must either be
  reproduced by the entry stub or bypassed safely.
- Absolute high-ROM far pointers such as `FF5B:0004` and `FF39:0006` must be
  relocated to the copied `.X` body, not left pointing at the T400 ROM.

## Next Steps

1. Decide whether the first `.X` should use a fixed startup BASIC filename or
   include a minimal file picker.
2. Build a relocation scanner for far calls/pointers whose physical target lies
   in `0xF2000..0xFFFFF`.
3. Decode the 325 `F200` trampoline page at file `0x72000` and map each used
   offset to a low-RAM vector or helper.
4. Compare the 325 and T400 low-RAM vector tables installed around `0x0200`.
5. Identify the BASIC RAM state ranges and check for collisions with T400
   `EROMCARD.X` execution state.
6. Test `/tmp/dw-card-1m-basic.bin` in MAME and see whether the fixed
   `BASIC.BAS` path reaches the BASIC parser or falls back into a firmware
   service mismatch.
