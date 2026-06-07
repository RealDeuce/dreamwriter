# Diagnostics

## Entry Gate

The diagnostic gate is reached on warm paths, not normal cold boot:

```asm
C000:08DA  call C000:1240
C000:08DD  jc C000:08E0
C000:08DF  ret
C000:08E0  mov word [6D81],1995
```

`C000:1240` enters diagnostics only if the keyboard matrix matches the expected
chord:

```asm
C000:1240  call C000:1252
C000:1243  jz C000:1247
C000:1245  clc
C000:1246  ret
C000:1247  call C000:1272
```

`C000:1252` compares RAM `6D06..6D0F` against bytes stored at `C000:1268`:

```text
00 08 00 00 80 00 00 00 40 00
```

With the MAME keyboard matrix this is `SPACE + F + J`:

| RAM byte | Row bit | Key |
| ---: | ---: | --- |
| `6D07 = 08` | row 1 bit 3 | `SPACE` |
| `6D0A = 80` | row 4 bit 7 | `F` |
| `6D0E = 40` | row 8 bit 6 | `J` |

## Warm IRQ Entry

The synthetic IRQ `FF` path at `C000:02EE` also checks the chord:

```asm
C000:0316  call C000:1252
C000:031C  jz C000:0329
```

On match it stores resume/diagnostic state:

```text
[6807] = 00
[6D79] = 4A8D
[6D7B] = CS
[6D81] = 1995
```

It then reaches:

```asm
C000:0370  mov al,01
C000:0372  out 70,al
C000:0374  jmp C000:0374
```

In MAME, the `Home` power key samples the held keyboard rows into `6D06..6D0F`
before the retained-RAM wake/reset path, and reset entry samples them again
before the ROM starts. The port `0x61` `FE -> FF` scan-enable edge samples them
again after the firmware resets its scan state. Holding `F+J+SPACE` while
pressing `Home` reaches the ROM's warm diagnostic path. The synthetic F1 IRQ
reaches `C000:02EE` as a direct debugger shortcut; with `F+J+SPACE` held,
breakpoints at `C000:02EE`, `C000:0316`, `C000:0329`, and `C000:0370` all hit.
Interactive testing confirmed that holding `F+J+SPACE` enters the diagnostic UI
from the copyright/warm startup path, but not during the `INITIALIZING` cold
path.

## Command Loop

The diagnostic UI starts at `C000:1272`; the command parser/loop starts at
`C000:128F`. The initial visible diagnostic banner only shows the title and
`K: Keyboard check`: `C000:1277..1280` renders `0x42` bytes from
`C688:0086` / file `0x46906`, which stops before the longer command-help
strings that follow in ROM. The block is a display script with embedded text,
not plain NUL-terminated strings; it runs through file `0x46A1D`.
Interactive testing confirmed that typing an address still dumps a memory
block, so the parser is more capable than the visible help implies.

Pressing `?` in the diagnostic UI redraws a longer help page. The parser tests
for `0x3F` at `C000:12B9..12D0` and calls `C000:16EB`, which renders `0xF9`
bytes from the same `C688:0086` / file `0x46906` string block instead of the
short `0x42`-byte startup banner.

Two small C688 wrappers immediately after the diagnostic script render 15-byte
script fragments from the end of that same block:

```asm
C688:019D  mov si,017F
C688:01A0  mov cx,000F
C688:01A3  mov dx,cs
C688:01A5  call C000:16E7

C688:01AB  mov si,018E
C688:01AE  jmp C688:01A0
```

Those fragments start at files `0x469FF` and `0x46A0E`. Treat them as
diagnostic display-script resources when doing code sweeps.

No port `0xA0` card-status check appears in this banner/parser path. The
PCMCIA status helpers that read `0xA0` are in the storage/card routines, while
the diagnostic `T`/`N` commands here write port `0x30` bit 7 using temporary
values derived from the `[6D94]` control-latch mirror.

The parser recognizes command letters including:

| Command | Evidence |
| --- | --- |
| `?` | Full help redraw; `C000:12B9..12D0` dispatches to `C000:16EB`. |
| `M` | Memory dump command text, parser branches through command handling near `C000:134A`. |
| `S` | Set memory command text, parser recognizes `S` near `C000:1356`. |
| `Y`, `Z` | Single-step command text, parser recognizes both near `C000:1366..136C`. |
| `I`, `L` | I/O dump command text, parser recognizes both near `C000:13CA..13D4`. |
| `T`, `N` | Card attribute / COM command text, parser recognizes both near `C000:136E..1374`. |
| `Q`, `R` | Clear/reset spell command text. These call the banked spell service with IDs `0x58` and `0x59`; see [`spell-engine.md`](../v2.1/docs/spell-engine.md). |

The `I` and `L` commands are real arbitrary I/O read paths, not fixed hardware
port consumers. The parser records the selected command in `[6EBB]`, parses the
requested port into `[6EB9]`, and the dump loop calls `C000:1534`. When `[6EBB]`
is `I` or `L`, that helper reads from the current port through `DX`:

```asm
C000:1534  mov  cx,ds
C000:1536  mov  si,[6EB9]
...
C000:1554  mov  dx,si
C000:1556  in   al,dx
C000:1557  mov  bl,al
```

`L` is the "dump I/O(alarm)" shortcut documented in the help text; it seeds
`[6EB9]` with `0x00D0`, matching the RTC register block. No corresponding
arbitrary `out dx,...` path has been found in this diagnostic parser; the `S`
command writes memory, while `T`/`N` are the fixed port `0x30` bit-7 controls.

## Exit Behavior

Diagnostic mode returns to its caller rather than resetting the machine. The
top-level parser treats keycodes `0x0B`, `0x02`, and `0x03` as exit/cancel
events:

```asm
C000:12AD  cmp al,0B
C000:12AF  jz  C000:12CE
C000:12B1  cmp al,02
C000:12B3  jz  C000:12CE
C000:12B5  cmp al,03
C000:12B7  jz  C000:12CE
C000:12CE  stc
C000:12CF  ret
```

`C000:1240` propagates that carry return to the warm/startup caller. Interactive
testing showed that leaving diagnostics continues the interrupted boot path.

## Strings

| File offset | Physical | Text |
| ---: | ---: | --- |
| `0x46912` | `0xC6912` | `Diagnostic 21BAB047 (97Apr14)        K: Keyboard check` |
| `0x4694E` | `0xC694E` | `Mxxxx:yyyy     dump Memory` |
| `0x4696E` | `0xC696E` | `Sxxxx:yyyy,zz  Set memory` |
| `0x4698D` | `0xC698D` | `Y,Zxxxx:yyyy   Single step` |
| `0x469AD` | `0xC69AD` | `Iyyyy  dump I/O,  L=dump I/O(alarm)` |
| `0x469D6` | `0xC69D6` | `T=Card ATTR, N=COM, Q/R=Clear/Reset spell` |
