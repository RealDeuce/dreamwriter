# ROM CARD EROMCARD.X Launcher

This page documents the v3.1 OTHERS -> ROM CARD executable launcher. In
`t4_ir_3.1_e588.ic303` it is at `DEF0:2C37` (file offset `0xE1B37`). In the
later [`v3.1.260`](../../../v3.1.260/) `t4_ir_3.1_8c8f.ic303` image, the same
loader has shifted to `DF80:2C39` (file offset `0xE2439`). This is separate from the AD00 ROM CARD
storage command processor documented in [`ed1b-ad00-banked.md`](ed1b-ad00-banked.md).

The launcher is a conventional filesystem loader. It searches for a file named
`EROMCARD.X`, reads it into RAM at `0xA4F0`, and then hands control to a far
pointer that is part of the loaded image. It is not part of the display
bytecode/markup interpreter.

## Menu Entry

The OTHERS submenu loop at `DEF0:2DF1..2EA8` dispatches item 4 to the launcher:

```asm
DEF0:2E7F  inc  dx
DEF0:2E80  mov  bx,dx
DEF0:2E82  add  bx,0x30
DEF0:2E85  cmp  ax,bx
DEF0:2E87  jnz  DEF0:2E99
DEF0:2E89  call DEF0:2C37      ; OTHERS -> ROM CARD
DEF0:2E8C  cmp  ax,0x000b      ; CAN/exit return
```

`DEF0:2C37` returns the payload return value on successful launch, or zero for
most local failure paths. The menu loop treats `0x0B` specially as an exit.

The later `8c8f` ROM has the same menu shape in the shifted `DF80` segment:

```asm
DF80:2E81  inc  dx
DF80:2E82  mov  bx,dx
DF80:2E84  add  bx,0x30
DF80:2E87  cmp  ax,bx
DF80:2E89  jnz  DF80:2E9B
DF80:2E8B  call DF80:2C39      ; OTHERS -> ROM CARD
DF80:2E8E  cmp  ax,0x000b
```

## Resources

| Resource | Meaning |
| --- | --- |
| `F131:000C` / file `0xF131C` (`e588`) or `F185:0008` / file `0xF1858` (`8c8f`) | Filename string: `EROMCARD.X`. |
| `F15B` | `No ROM card is in the slot`. |
| `F15D` | `Press CAN to exit`. |
| `F15E` | `Inadequate work memory`. |
| `F160` | `Can not open EROMCARD.X`. |
| `F161` | `Not enough memory`. |
| Same EE17 string block | `ROM Card ID error` text is present nearby, but this v3.1 launcher body does not reference it directly. |

## Path Search

The launcher builds a local path buffer at `[bp-0x14]`. It seeds a far string
pointer at `[bp-0x18] = F131:000C`, copies `EROMCARD.X`, and probes two
candidate drives:

1. `([0000:1005] + 1):EROMCARD.X`
2. `[0000:1005]:EROMCARD.X`

The first candidate is built here:

```asm
DEF0:2C46  lea  bx,[bp-0x14]       ; path buffer
DEF0:2C49  mov  word [bp-0x18],0x000c
DEF0:2C4E  mov  word [bp-0x16],0xf131
DEF0:2C53  mov  ax,0
DEF0:2C56  mov  es,ax
DEF0:2C58  mov  al,[es:0x1005]     ; system drive base
DEF0:2C5C  inc  al                 ; first try card/next drive
DEF0:2C5E  mov  [bx],al
DEF0:2C61  mov  byte [bx],':'
```

After the filename copy, `DEF0:E195` probes the candidate:

```asm
DEF0:2C77  lea  ax,[bp-0x14]       ; path
DEF0:2C7A  mov  bx,0x0002          ; find-first attributes
DEF0:2C7D  lea  cx,[bp-0x43]       ; caller DTA
DEF0:2C80  call far DEF0:E195
DEF0:2C85  test ax,ax
DEF0:2C87  jz   DEF0:2CDD          ; found
```

If the first search fails, the drive byte in the same path buffer is rewritten
with `[0000:1005]` and `DEF0:E195` is called again.

`DEF0:E195` is the DOS-like find-first wrapper. It sets the caller DTA through
`INT 21h AH=1A`, then runs `INT 21h AH=4E` with `AX = path`, `BX = attrs`, and
`CX = DTA`.

## Missing File

If neither candidate exists, the launcher displays:

```text
No ROM card is in the slot
Press CAN to exit
```

It loops on `DEF0:0043` until the key code is `0x03` or `0x0B`, then returns
without opening a file.

## Work-Memory Limit

After find-first succeeds, `DEF0:2CDD` calls `C772:01CD`. That helper prepares
the editor/application state for the external launcher, sets `[1442] = 1`, and
returns:

```asm
C772:01E5  mov ax,[0x7576]
C772:01E8  mov bx,0x0080
C772:01EB  mul bx                 ; AX = [7576] * 0x80
```

The launcher saves that byte limit in `DI` and compares it against the DTA file
size fields:

```asm
DEF0:2CDD  call far C772:01CD
DEF0:2CE2  mov  di,ax
DEF0:2CE4  xor  bx,bx
DEF0:2CE6  mov  ax,di
DEF0:2CE8  sub  ax,[bp-0x29]       ; DTA file size low word
DEF0:2CEB  sbb  bx,[bp-0x27]       ; DTA file size high word
DEF0:2CEE  jnl  DEF0:2D2B          ; enough memory
```

Oversized files are rejected before opening. The cleanup helper `C772:01F3` is
called, then the UI displays:

```text
Inadequate work memory
Press CAN to exit
```

## Open, Read, Close

The selected candidate path is opened read-only through `DEF0:DB47`:

```asm
DEF0:2D2B  xor  ax,ax
DEF0:2D2D  push ax                 ; mode 0
DEF0:2D2E  lea  ax,[bp-0x14]
DEF0:2D31  push ax                 ; path
DEF0:2D32  call far DEF0:DB47
DEF0:2D3A  mov  si,ax              ; handle
DEF0:2D3C  cmp  si,0
DEF0:2D3F  jnl  DEF0:2D60
```

Open failure calls `C772:01F3`, displays `Can not open EROMCARD.X`, waits for
one key, and returns zero.

On success, the file is read to fixed RAM address `0xA4F0`:

```asm
DEF0:2D60  mov  ax,si              ; handle
DEF0:2D62  mov  bx,0xa4f0          ; destination offset
DEF0:2D65  mov  cx,[bp-0x29]       ; byte count = file size low word
DEF0:2D68  call far DEF0:E022      ; INT 21h AH=3F read
DEF0:2D6D  cwd
DEF0:2D6E  sub  ax,[bp-0x29]
DEF0:2D71  sbb  dx,[bp-0x27]
DEF0:2D74  jnl  DEF0:2D9C          ; read count covers DTA size
```

`DEF0:E022` returns the read count in `AX`, or `0xFFFF` on error. Since `CX` is
only the low 16 bits of the file size, a nonzero high word in the DTA cannot be
fully read by this single call and falls into the short-read failure path.

Short read or read error closes the handle through `DEF0:E048`, calls
`C772:01F3`, displays `Not enough memory`, waits for one key, and returns zero.

## Launch Handoff

On successful read, the launcher closes the file and calls `C772:0212` with the
work-memory byte limit in `AX`:

```asm
DEF0:2D9C  mov  ax,si
DEF0:2D9E  call far DEF0:E048      ; close
DEF0:2DA3  mov  ax,di              ; work-memory byte limit
DEF0:2DA5  call far C772:0212      ; call far [CA04]
DEF0:2DAA  mov  cx,ax              ; preserve payload return
DEF0:2DAC  call far C772:01F3
DEF0:2DB1  mov  ax,cx
```

`C772:0212` is only a register-preserving trampoline:

```asm
C772:0212  push cx
C772:0213  push dx
C772:0214  push si
C772:0215  push di
C772:0216  push bp
C772:0217  call far [0xca04]
C772:021B  pop  bp
C772:021C  pop  di
C772:021D  pop  si
C772:021E  pop  dx
C772:021F  pop  cx
C772:0220  retf
```

The payload return value in `AX` is returned to the OTHERS submenu after
`C772:01F3` finalizes the launcher state and clears `[1442]`.

There is no separate ROM-side write to `[CA04]` between the read and the
trampoline. The read at `DEF0:2D68` populates the range starting at `0xA4F0`;
`0xCA04 - 0xA4F0 = 0x2514`, so the trampoline reads the far entry pointer from
loaded file offset `+0x2514`:

| Loaded address | File offset | Meaning |
| ---: | ---: | --- |
| `0xCA04` | `+0x2514` | Entry offset word for `call far [CA04]`. |
| `0xCA06` | `+0x2516` | Entry segment word for `call far [CA04]`. |

## v2.1 Comparison

The v3.1 search, memory-limit check, fixed load address, and open/read/close
sequence match the v2.1 loader at `DC98:2B75` closely. The important difference
is the entry validation/handoff:

| Version | Handoff behavior |
| --- | --- |
| v2.1 | After loading, checks `[0xA4F0] == 0xA4F0` and `[0xA4F2] == 0x1997`, then calls the far entry pointer at `[0xA4F4]`. |
| v3.1 | No equivalent inline header check has been found in `DEF0:2C37`; success calls `C772:0212`, which calls the far entry pointer loaded at `[0xCA04]`, i.e. file offset `+0x2514`. |

Targeted ROM byte searches found the v3.1 `0xA4F0` load immediate in the
launcher, but not a local `0x1997` comparison or a simple direct write to
`[0xCA04]`. The recursive trace at `trace-full.txt` shows the complete success
path: read to `0xA4F0`, close, `C772:0212`, then `C772:0217 call far [0xca04]`.
Therefore the vector setup is the file read itself, and a v3.1 `EROMCARD.X`
must place its far entry pointer at file offset `+0x2514`.

The practical binary envelope is therefore:

```text
+0x0000..+0x2513  padding or payload data not used by the handoff
+0x2514           entry offset word
+0x2516           entry segment word
+0x2518           first byte available for code if the entry points here
```

A same-segment payload loaded at `0x0A4F0` can use segment `0x0A4F` and an
entry offset equal to the code's file offset. If the entry starts immediately
after the vector, the words at `+0x2514` are `0x2518, 0x0A4F`, and execution
starts at physical `0x0CA08`.

## Later v3.1 8c8f Variant

`t4_ir_3.1_8c8f.ic303` keeps the same launcher ABI, but the surrounding code
and segment names moved:

| Item | `e588` | `8c8f` |
| --- | --- | --- |
| Loader entry | `DEF0:2C37`, file `0xE1B37` | `DF80:2C39`, file `0xE2439` |
| Menu call | `DEF0:2E89 call DEF0:2C37` | `DF80:2E8B call DF80:2C39` |
| Find-first wrapper | `DEF0:E195` | `DF80:F6C4` |
| Open wrapper | `DEF0:DB47` | `DF80:F076` |
| Read wrapper | `DEF0:E022` | `DF80:F551` |
| Close wrapper | `DEF0:E048` | `DF80:F577` |
| App prep/finalize/trampoline | `C772:01CD`, `01F3`, `0212` | `C774:01CC`, `01F2`, `0211` |
| Trampoline instruction | `C772:0217 call far [0xca04]` | `C774:0216 call far [0xca04]` |

The later ROM still reads `EROMCARD.X` to `0xA4F0`, then calls through
`[0xCA04]`; the entry pointer is therefore still loaded from file offset
`+0x2514`. Targeted byte searches in `8c8f` found no local `cmp 0x1997` or
`mov ax,[0xA4F2]` header-check pattern.

## Failure Summary

| Condition | Action |
| --- | --- |
| Neither candidate path is found | Display `No ROM card is in the slot` plus `Press CAN to exit`; wait for `0x03` or `0x0B`. |
| File size exceeds `C772:01CD` (`8c8f`: `C774:01CC`) work-memory limit | Cleanup via `C772:01F3` (`8c8f`: `C774:01F2`); display `Inadequate work memory` plus `Press CAN to exit`; wait for `0x03` or `0x0B`. |
| Open fails | Cleanup via `C772:01F3` (`8c8f`: `C774:01F2`); display `Can not open EROMCARD.X`; wait once; return zero. |
| Read count is less than DTA file size | Close, cleanup via `C772:01F3` (`8c8f`: `C774:01F2`); display `Not enough memory`; wait once; return zero. |
| Read succeeds | Close, call payload through `C772:0212` (`8c8f`: `C774:0211`), cleanup via `C772:01F3` (`8c8f`: `C774:01F2`), return payload `AX`. |

## Call Flow

```text
DEF0:2E89
  -> DEF0:2C37
       -> DEF0:E195     find EROMCARD.X on candidate drive
       -> DEF0:E195     fallback find on base drive
       -> C772:01CD     prepare app state and compute work limit
       -> DEF0:DB47     open
       -> DEF0:E022     read to 0xA4F0
       -> DEF0:E048     close
       -> C772:0212     call far [CA04] loaded from file offset +0x2514
       -> C772:01F3     finalize app state
```
