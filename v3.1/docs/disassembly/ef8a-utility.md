# EF8A Utility Routines

Utility routines at segment `EF8A` (31 blocks, 265 instructions).
Physically in window 7 at file `0xEF8A0`, overlapping the upper end
of the EE17 segment. Called from `EE17:1411` and `EE17:1853` via
`CALL FAR EF8A:xxxx` — the CPU runs this code with `CS=EF8A`, not
`CS=EE17`.

The routines manage state block operations, calling back into EE17
helpers (`EE17:0047`, `EE17:0817`, `EE17:0A4D`, `EE17:0A78`,
`EE17:0AF4`).

## Entry Points

| Address | Caller | Purpose |
| --- | --- | --- |
| `EF8A:00F0` | `EE17:1411` | Main entry: init + dispatch loop |
| `EF8A:000F` | `EF8A:0123` | State block copy (6 callers) |
| `EF8A:0020` | `EF8A:0123` | State block clear (3 callers) |
| `EF8A:0037` | `EF8A:0123` | State block compare (4 callers) |
| `EF8A:0057` | `EF8A:0123` | State block update (7 callers) |
| `EF8A:007B` | `EF8A:01B8` | State block validate (1 caller) |
| `EF8A:00B6` | `EF8A:0123` | State block format (3 callers) |

## EF8A:00F0 — Main Entry

Called from `EE17:1411`. Checks `[A342]` — if zero, enters the
init path at `EF8A:010E` which calls `EE17:0A4D` and `EE17:0047`
to set up the state block base. Then enters the main dispatch
loop at `EF8A:0123`.

## EF8A:0123 — Dispatch Loop

Large routine (151 bytes). Calls the six state block operations
(`000F`, `0020`, `0037`, `0057`, `00B6`) and EE17 helpers
(`EE17:0817`) to process state blocks. Branches to `EF8A:01EF`
for extended processing and `EF8A:01B8` for validation.

## EF8A:01B8..01EF — Validation Loop

Calls `00B6` (format), `0037` (compare), `007B` (validate),
`0020` (clear) in a loop processing multiple state blocks.

## EF8A:0243..0278 — Cleanup

Called at the end of the dispatch loop. Calls `EE17:0047` (init),
`EE17:0AF4`, and `EE17:0A78` in a loop to finalize state blocks.

## Relationship to EE17

`EF8A` is physically `EE17:1730+` but runs with a different CS.
The segment alias exists because `EE17:1853` uses `CALL FAR`
with segment value `0xEF8A` to reach these routines. Both EE17
and EF8A are in window 7 (fixed, not banked).
