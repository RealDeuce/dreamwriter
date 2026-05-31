# DW-BASIC Out-of-Memory Scratch Notes

This is a temporary diagnostic log for unexpected `Out of memory` reports seen
while driving DW-BASIC under MAME. Each entry should include the clean-boot
status, command sequence, screen result, and any state dumps needed to reproduce.

## 2026-05-31: `WIDTH 80`

- Harness: `tools/run_dwbasic_mame.py --window-position ""`
- Run state: normal harness launch, which deletes NVRAM/snapshots unless
  `--no-clean` is used.
- Preceding commands in same BASIC session:
  - `PRINT 7` -> printed `7`, returned `Ok`
  - `LOCATE 1,1` -> `Syntax error`, returned `Ok`
  - `SCREEN 0` -> returned `Ok`
- Command:
  - `WIDTH 80`
- Snapshot result:

```text
Ok
SCREEN 0
Ok
WIDTH 80
Out of memory
Ok
```

- Notes:
  - This is not the wrapper-level `DW-BASIC NEEDS MORE MEMORY` failure. It is
    BASIC's normal `Out of memory` error string and returns to `Ok`.
  - Needs a clean isolated repro to determine whether prior `LOCATE`/`SCREEN`
    commands matter.

## 2026-05-31: post trap-table fix retest

- Baseline commit: `9176eb1 Fix DW-BASIC startup memory corruption`.
- Run state: normal harness launch with clean NVRAM/snapshots.
- Isolated command:
  - `WIDTH 80` -> `Ok`
  - `PRINT ERR` -> `0`
- Old preceding sequence retest:
  - `PRINT 7` -> printed `7`
  - `LOCATE 1,1` -> no syntax error; subsequent output overwrote earlier
    screen cells as expected for cursor positioning
  - `SCREEN 0` -> `Ok`
  - `WIDTH 80` -> `Ok`
  - `PRINT ERR` -> `0`
- Notes:
  - The prior `WIDTH 80` BASIC `Out of memory` repro no longer reproduces after
    the `NUMTRP == 0` trap-table startup fix.
  - No wrapper-level `DW-BASIC NEEDS MORE MEMORY` path was hit in this retest.
