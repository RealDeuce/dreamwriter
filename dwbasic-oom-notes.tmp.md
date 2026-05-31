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
