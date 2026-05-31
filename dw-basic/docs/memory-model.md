# DW-BASIC Memory Model Policy

The current DW-BASIC port targets the **flat64** memory model.

## flat64

`flat64` is the buildable target today. The ROM card loader reads one
`GWBASIC.OVR` file into one 64K segment and enters BASIC with
`CS=DS=ES=SS`. This keeps the startup path compatible with 64K-class machines
such as the DreamWriter 325.

The flat64 target also has to preserve practical BASIC workspace, not merely
link under the 64K segment limit. The wrapper currently enforces a minimum
free-space guard with `GW_BASIC_MIN_FREE`, and that value should be treated as
part of the target contract while startup is being stabilized.

If the full GW-BASIC feature set does not leave enough program/string space in
flat64, feature omissions should be made as explicit flat64 policy choices.
They should be documented in this file and controlled by named build/profile
switches rather than hidden inside converter behavior. The split128 model
should remain the path for restoring larger feature sets on machines with more
RAM.

The flat64 build intentionally does not preserve the original MASM CSEG/DSEG
`ORG` layout gaps in `gwdata.asm`. In this model, those gaps would consume the
single 64K address space without giving us the original split-segment loader
contract. Ordinary RAM reservations are still preserved as NASM reservations
(`resb`/`resw`) where the conversion can identify MASM `DUP(?)` storage. The
exception is `gwdata.asm`'s low-data phase mirror: placeholders there are
materialized from the matching source-phase initializer when the original
source relied on startup copying ROM constants into RAM.

Files that currently encode flat64 policy:

- `GNUmakefile`: `GW_MEMORY_MODEL ?= flat64`; other values are reserved but
  rejected until implemented.
- `tools/flat_runtime_patches.py`: patches startup and memory-map code so the
  converted BASIC runs in one loaded segment.
- `tools/gwdata_tables.py`: patches generated `gwdata.asm` table/RAM regions
  for the flat64 layout.
- `src/eromcard_gw.asm`: loads one overlay and jumps to `INIT` in the loaded
  segment; enforces `GW_BASIC_MIN_FREE` before entering BASIC.

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
- Update `src/eromcard_gw.asm` to choose `GWBASIC128.OVR` or equivalent when
  RAM allows, otherwise fall back to the flat64 overlay.

Until split128 exists, ORG-gap conversion findings should be treated as known
split-model work, not as flat64 regressions.
