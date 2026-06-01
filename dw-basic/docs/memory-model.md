# DW-BASIC Memory Model Policy

The current DW-BASIC port targets the **flat64** memory model.

## flat64

`flat64` is the buildable target today. The ROM card loader reads one
`DW-BASIC.FLT` file into memory immediately after the first-stage loader, then
enters the same physical image through an offset-zero segment with
`CS=DS=ES=SS`. This keeps the startup path compatible with 64K-class machines
such as the DreamWriter 325 while avoiding the wasted offset gap that came from
linking the overlay at `0800h`.

The flat64 target also has to preserve practical BASIC workspace, not merely
link under the 64K segment limit. The wrapper currently enforces a minimum
remaining BASIC workspace with `GW_BASIC_MIN_FREE`; those bytes are not reserved
away from BASIC, they are the minimum program/variable/string space required
before the loader will enter BASIC.

If the full GW-BASIC feature set does not leave enough program/string space in
flat64, feature omissions should be made as explicit flat64 policy choices.
They should be documented in this file and controlled by named build/profile
switches rather than hidden inside converter behavior. The split128 model
should remain the path for restoring larger feature sets on machines with more
RAM.

The default flat64 profile sets `GW_ENABLE_GRAPHICS=0`. Graphics tokens remain
recognized for compatibility, but graphics-only entry points fail through
GW-BASIC's normal illegal-function path and the `advgrp`/`gengrp` modules are
not linked. `GW_ENABLE_GRAPHICS=1` keeps the current DreamWriter LCD graphics
scaffolding buildable for larger-memory/split-model work, but it is not the
default 64K target.

The flat64 build intentionally does not preserve the original MASM CSEG/DSEG
`ORG` layout gaps in `gwdata.asm`. In this model, those gaps would consume the
single 64K address space without giving us the original split-segment loader
contract. Ordinary RAM reservations are still preserved as NASM reservations
(`resb`/`resw`) where the conversion can identify MASM `DUP(?)` storage. The
exception is `gwdata.asm`'s low-data phase mirror: placeholders there are
materialized from the matching source-phase initializer when the original
source relied on startup copying ROM constants into RAM.

Files that currently encode flat64 policy:

- `GNUmakefile`: `GW_BASIC_SEPARATE_SEGMENT ?= 1` links `DW-BASIC.FLT` at
  offset zero and has the loader enter it through a paragraph-aligned segment
  after the loader.
- `tools/flat_runtime_patches.py`: patches startup and memory-map code so the
  converted BASIC runs in one loaded segment and reads its memory limit through
  the fixed loader ABI.
- `tools/gwdata_tables.py`: patches generated `gwdata.asm` table/RAM regions
  for the flat64 layout.
- `tools/source_feature_ranges.py`: wraps generated-source symbol ranges when a
  build profile disables an optional feature without changing the converter's
  source-level interpretation.
- `src/eromcard_gw.asm`: loads one overlay and jumps to `INIT` in the loaded
  segment; enforces `GW_BASIC_MIN_FREE` before entering BASIC.
- `src/include/dwloader.inc`: defines the fixed loader ABI at `0A4F:0010`.
  BASIC reads the approved work-area limit from that table, and `SYSTEM`
  far-jumps to the loader-resident exit thunk at `0A4F:0030`.

## split128

`split128` is the intended future target for machines with more than 64K
available. It should use separate code and data segments, preserving the
original GW-BASIC split-segment assumptions where possible.

The original source already has useful pieces for this model:

- `gwdata.asm` has CSEG/DSEG phase markers and `ORG` sites such as `CPMENT`,
  `START`, `CPMMEM`, and `RAMLOW`.
- `gwinit.asm` has startup code that computes and installs a data segment.
- `itsa86.asm` has `MAPCLC`, `MAPINI`, `NEWDS`, `MSWSIZ`, and `SEGOFF` logic.

A split128 implementation should not silently replace flat64. It should add a
separate overlay/container format or file set, then teach the ROM card loader
to choose the split overlay only when enough RAM is available. The flat64
overlay must remain available as the fallback for 64K machines.

Likely split128 work:

- Add `GW_MEMORY_MODEL=split128` build rules instead of relaxing the current
  makefile guard.
- Preserve the `gwdata.asm` ORG sites in a split-aware postprocessor.
- Add a split runtime patch path instead of reusing `flat_runtime_patches.py`.
- Define a split overlay format with code image, initialized data image, entry
  offset, and data limit metadata.
- Update `src/eromcard_gw.asm` to choose `DW-BASIC128.FLT` or equivalent when
  RAM allows, otherwise fall back to the flat64 overlay.

Until split128 exists, ORG-gap conversion findings should be treated as known
split-model work, not as flat64 regressions.
