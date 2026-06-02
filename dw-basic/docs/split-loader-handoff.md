# DW-BASIC Split Loader Handoff

Date: 2026-06-02

This document is for resuming the split `DW-BASIC.COD` / `DW-BASIC.DAT`
bring-up in a fresh LLM context. It captures the current facts, the working
test harness shape, the present failure, and the immediate debug focus.

## Current Goal

Bring up a split DW-BASIC ROM CARD delivery:

1. `EROMCARD.X` is the ROM CARD loader program.
2. `DW-BASIC.COD` is a file in RAM storage.
3. `DW-BASIC.DAT` is also a file in RAM storage.
4. The loader finds and validates those files, loads/uses them, populates a
   fixed ABI area at the start of the data segment, and far-transfers to
   `DW-BASIC.COD`.
5. At BASIC entry, `CS` points to `DW-BASIC.COD`; `DS` and `ES` point to the
   data segment whose first window is occupied by the loader/ABI area.
6. `SYSTEM` must return through the loader-resident exit thunk so the original
   caller stack can be restored and control returns to the OS.

The first implementation is allowed to be simpler than the final installer,
but the final system must not depend on precomputed filesystem offsets or a
carefully generated NVRAM layout.

## Important Working Rules

- Do not infer display contents from partial logs. The user can see the screen;
  ask them when visual confirmation matters.
- Do not keep changing BASIC and the loader at the same time without a small
  proof program. Use the split spike to validate loader/data assumptions before
  applying the same idea to BASIC.
- The spike must stay independent. It should use `SPIKE.COD` and `SPIKE.DAT`,
  must not load or mention BASIC, and must not reuse unproven BASIC-specific
  code.
- For ROM CARD file opens in this path, use the RAM-storage fallback drive path
  that has been validated by the spike. The earlier `I:` path was wrong for
  this prepared NVRAM/harness case; the successful split spike found and used
  `H:SPIKE.DAT`.
- Avoid speculative debugger claims. If a MAME breakpoint method is not proven
  to catch and log the breakpoint, say that plainly and fix the method before
  drawing conclusions from it.

## Memory Layout Intent

The current split shape is:

```text
ROM CARD load segment, normally 0A4Fh

0A4F:0000  EROMCARD.X loader code and loader-resident exit thunk
0A4F:....  loader variables / ABI table at known offsets
0A4F:....  beginning of DAT runtime area after ORG gap
            DS=ES remains this segment when transferring to BASIC

COD_SEG:0000  DW-BASIC.COD entry and code

DAT_SEG is effectively the loader segment for the initial model. The DAT image
is linked/assembled with an ORG gap so bytes that would overlap the loader are
not copied over the loader code. BASIC sees DS=ES=DAT/loader segment, with the
front occupied by the loader and fixed ABI window.
```

The loader likely does not need a private stack. If one is present in current
code, treat it as suspect unless there is a concrete reason it is required.

## What The Spike Proved

The split spike now has the same basic `DAT-after-loader` shape that BASIC is
supposed to use:

- `EROMCARD.X` can be preloaded into RAM storage and launched by the ROM CARD
  menu.
- `SPIKE.DAT` can be opened from the RAM-storage path.
- The spike can read data through `DS` after using an ORG-style gap.
- The spike can print a string and return correctly after SPACE.
- The spike exposed a real filename/path bug in the BASIC loader. Fixing that
  moved BASIC to a new failure mode.

Use the spike as the test dummy for any low-level loader/data theory before
touching BASIC.

## Current BASIC Failure

After fixing the loader path bug found by the spike, BASIC starts far enough to
display:

```text
DW-BASIC for DreamWriters
```

It then hangs before displaying the Microsoft heading text that begins with:

```text
\r\n(C) Microsoft, 1982
```

This is no longer the old "cannot load DAT" failure. The current focus is the
code path between the OEM heading string returning and the second heading
string being displayed.

## STROUT Facts

Current code inspection established these facts:

- `STROUT` does not take a far pointer.
- `STROUT` reads the string from `CS:BX` using explicit `CS:` data access.
- Therefore only code-segment strings can be passed directly to `STROUT`.
- The OEM string that displayed successfully was also in `CS`.
- `HEDING` is in `CS` at offset `4E89h` and begins with bytes:

```text
0D 0A 28 43 ...
```

- Testing `HEDING+2` confirmed the second `STROUT` call itself can still fail
  even when the leading CR/LF is skipped. That temporary change must remain
  reverted for normal testing.

## Display Path Facts

The relevant call path is:

```text
STROUT -> OUTDO -> PTRDSP -> KYBDSP[G_SOT] -> SCNSOT -> SCNOUT -> CTLDSP
```

Additional facts:

- `SCNSOT` maps CR into CR+LF behavior and eats an explicit LF following a CR.
- `CTLDSP` calls `SCNPOS`, then uses `CSRX`/`CSRY` as the GW screen-driver
  cursor variables.
- `FUNTAB[10]` maps LF to `LFEED`.
- `FUNTAB[13]` maps CR to `LCARET`.
- Do not use only the DreamWriter console shadow cursor for this path; inspect
  `CSRX` and `CSRY`.

One sampled hang state showed:

```text
CSRY = 01h
CSRX = 1Ah
IP   = 886Fh
AL   = 00h
```

`IP=886Fh` mapped into `scndrv.obj` local offset `040Ch`, inside the
`CALL LSTART` instruction in `SCNMRK`. That sample was taken while the CPU was
running, so treat it as a clue, not as a clean stopped breakpoint state.

The important implication is that a clean register capture immediately before
both `CALL STROUT` instructions is still needed.

## Debug Script Status

`tools/trace_strout_calls.lua` is an in-progress MAME Lua trace script.

Intent:

1. Install a breakpoint before selecting the ROM CARD menu item.
2. Press ENTER after a short delay.
3. Catch the loader far-transfer point.
4. Read the actual loaded BASIC code segment from the loader entry pointer.
5. Install breakpoints at the first and second `CALL STROUT`.
6. Log full register state and `CSRX`/`CSRY` before each call.

Known fixed addresses/offsets used by the script:

```text
loader segment:             0A4Fh
loader transfer IP:         0140h
loader entry segment field: 05BFh
first CALL STROUT IP:       37CDh
second CALL STROUT IP:      37D3h
```

The previous action-string breakpoint style was not reliable:

```lua
device.debug:bpset(addr, "", "lua function_name()")
```

The script is being moved to the pattern used by MAME's cheat plugin:

1. Use `device.debug:bpset(addr)` with no action string.
2. Keep `breakpoint_handlers[bpnum] = function`.
3. Poll `manager.machine.debugger.consolelog` for `Stopped at breakpoint N`.
4. Run the handler.
5. Set `manager.machine.debugger.execution_state = "run"` unless intentionally
   stopping.

The first run after that edit exited before writing
`/tmp/dwbasic-strout-trace.log`, so the script still needs validation. Do not
trust it until the log shows actual breakpoint hits.

## Useful Commands

Build the split BASIC card:

```sh
gmake -C dw-basic split-basic-card
```

Run the prepared NVRAM harness path:

```sh
tools/run_dwbasic_mame.py --prepared-romcard /tmp/dw-nvram-romcard-dw-basic --basic-wait 2
```

Direct MAME trace shape used during debugging:

```sh
mkdir -p /tmp/dwtrace-nvram/drwrt400_1 /tmp/dwtrace-snap
cp /tmp/dw-nvram-romcard-dw-basic /tmp/dwtrace-nvram/drwrt400_1/nvram
rm -f /tmp/dwbasic-strout-trace.log
../mame/drwrt400 drwrt400 -window -skip_gameinfo -ui_active -bios v2_1 \
  -nonvram_save -nvram_directory /tmp/dwtrace-nvram \
  -snapshot_directory /tmp/dwtrace-snap -debug -debugger none \
  -autoboot_script /usr/home/admin/T400/dreamwriter-rom-map/tools/trace_strout_calls.lua \
  -nojoy -nomouse -nothrottle
```

If the direct trace is used, check:

```sh
cat /tmp/dwbasic-strout-trace.log
```

Expected useful lines, once working:

```text
installed_loader_transfer_breakpoint ...
loader_transfer ... entry_segment=....
installed_strout_breakpoints ...
first_strout PS=.... PC=37CD ... BW=....
second_strout PS=.... PC=37D3 ... BW=4E89 ...
```

## Current Dirty Files To Be Aware Of

The worktree is dirty. Do not revert unrelated user or previous-session work.
Relevant changed/untracked files include:

```text
dw-basic/GNUmakefile
dw-basic/docs/memory-model.md
dw-basic/docs/split-loader-handoff.md
dw-basic/src/eromcard_gw.asm
dw-basic/src/eromcard_split_spike.asm
dw-basic/src/split_spike_cod.asm
dw-basic/src/split_spike_dat.asm
tools/run_dwbasic_mame.py
tools/dwbasic_input_bridge.lua
tools/trace_strout_calls.lua
```

There are other dirty files in the tree. Inspect `git status --short` before
editing, and only commit focused file sets when explicitly asked.

## Recommended Next Step

Finish validating `tools/trace_strout_calls.lua`.

The immediate target is not to fix BASIC by guesswork. The target is to capture
the exact full register state immediately before:

```text
first  CALL STROUT at CS:37CD
second CALL STROUT at CS:37D3
```

The capture should include at least:

```text
PS PC DS0 DS1 SS SP AW BW CW DW IX IY PSW CSRY CSRX
```

Once the two call states are known, compare:

- `CS`
- `BX`
- `DS`
- stack pointer and top stack words
- `CSRX`/`CSRY`
- whether the second call is actually passing `BX=HEDING`

Only then decide whether the problem is the call setup, stack damage, display
driver state, or something else in the transition after the OEM string.
