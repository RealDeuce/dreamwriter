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

In MAME, pressing F1 triggers IRQ `FF` and reaches this path. With
`F+J+SPACE` held, breakpoints at `C000:02EE`, `C000:0316`, `C000:0329`, and
`C000:0370` all hit.

## Command Loop

The diagnostic UI starts at `C000:1272`; the command parser/loop starts at
`C000:128F`. The parser recognizes command letters including:

| Command | Evidence |
| --- | --- |
| `M` | Memory dump command text, parser branches through command handling near `C000:134A`. |
| `S` | Set memory command text, parser recognizes `S` near `C000:1356`. |
| `Y`, `Z` | Single-step command text, parser recognizes both near `C000:1366..136C`. |
| `I`, `L` | I/O dump command text, parser recognizes both near `C000:134E..1354`. |
| `T`, `N` | Card attribute / COM command text, parser recognizes both near `C000:136E..1374`. |
| `Q`, `R` | Clear/reset spell command text. These call the banked spell service with IDs `0x58` and `0x59`; see `spell-engine.md`. |

## Strings

| File offset | Physical | Text |
| ---: | ---: | --- |
| `0x46912` | `0xC6912` | `Diagnostic 21BAB047 (97Apr14)        K: Keyboard check` |
| `0x4694E` | `0xC694E` | `Mxxxx:yyyy     dump Memory` |
| `0x4696E` | `0xC696E` | `Sxxxx:yyyy,zz  Set memory` |
| `0x4698D` | `0xC698D` | `Y,Zxxxx:yyyy   Single step` |
| `0x469AD` | `0xC69AD` | `Iyyyy  dump I/O,  L=dump I/O(alarm)` |
| `0x469D6` | `0xC69D6` | `T=Card ATTR, N=COM, Q/R=Clear/Reset spell` |
