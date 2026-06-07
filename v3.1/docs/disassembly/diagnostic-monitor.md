# Diagnostic Command Monitor

The terminal command monitor reached via banked thunk B slot 7
(`C000:131D`). Entered from the diagnostic keyboard chord path
([`diagnostic-keyboard-check.md`](diagnostic-keyboard-check.md)).

Reads serial input characters, translates via `C000:0A69`, and
dispatches commands through a lookup table at `C000:1378`.

## C000:131D — Monitor Entry

Sets `[15A2]=1` (monitor active flag), calls `C000:13F5` (init),
then enters the command dispatch loop at `C000:1341`.

```asm
C000:131D  C606A21501     mov byte [15A2],1    ; monitor active
C000:1322  E8D000         call C000:13F5       ; init
C000:1325  EB1A           jmp short 1341       ; -> dispatch loop
```

## C000:1341 — Command Dispatch Loop

Reads a character via `C000:3168` (serial input), translates via
`C000:0A69`, then dispatches:

| Key code | Handler | Purpose |
| --- | --- | --- |
| `0x0B` | `C000:13C5` | Exit monitor |
| `0x03` | `C000:13C5` | Exit monitor (alternate) |
| `0x14` | `C000:1327` | Set flag `[1446] |= 0x01` |
| `0x15` | `C000:132E` | Clear flag `[1446] &= 0xFE` |
| `0x17` | `C000:1335` | Set flag `[1446] |= 0x02` |
| `0x16` | `C000:133C` | Clear flag `[1446] &= 0xFD` |
| other | table at `1378` | Lookup command table |

The command table at `C000:1378` is a list of `(key, handler_offset)`
word pairs terminated by `0x00`.

## Monitor State Variables

| Address | Purpose |
| --- | --- |
| `[15A2]` | Monitor active flag (1 = active) |
| `[1446]` | Diagnostic mode flags (bit 0, bit 1) |

The v3.1 diagnostic monitor is simple — flag toggling and serial I/O
dispatch. No memory read/write or register display commands.
