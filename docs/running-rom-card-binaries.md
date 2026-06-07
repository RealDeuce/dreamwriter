# Running ROM CARD Binaries

The T400 can run an arbitrary real-mode binary through the `ROM CARD` item in
the `OTHERS` menu when the binary is packaged as a DreamWriter `EROMCARD.X`
file and stored where the normal file system can find it. In the normal
built-in-storage state, this does not require a PCMCIA card: the loader tries
the PCMCIA SRAM endpoint first, then falls back to built-in RAM storage.

This is not a PC DOS `.COM` or `.EXE` path. The firmware uses the storage layer
to find a file named exactly `EROMCARD.X`, reads that file into RAM at a
ROM-specific load address, may validate a small DreamWriter header, and calls the
far entry pointer stored in the file header. The T400 2.1 loader behavior and
failure strings are tracked in [`file-system.md`](../v2.1/docs/file-system.md#rom-card-loader).

## User-Facing Flow

1. Build or obtain a valid DreamWriter ROM CARD executable.
2. Put it in storage with the 8.3 name `EROMCARD.X`.
3. On the T400, choose `OTHERS` -> `ROM CARD`.
4. The firmware loads the file, calls its entry point, and returns to the
   firmware UI when the program returns.

The file can be put on storage by any path that creates a normal DreamWriter
file entry named `EROMCARD.X`. For emulator work, `dw-basic/tools/install_eromcard.py`
can install a payload into a formatted SRAM card image. For hardware work, the
same requirement applies after transferring or copying the file into built-in or
card storage: it must be visible to the file API under the `EROMCARD.X` name.

The practical fallback that enables the "download it into memory storage" path
comes from the loader's candidate-drive order. It builds
`([0x6805] + 1):EROMCARD.X` first, then falls back to `[0x6805]:EROMCARD.X`.
The endpoint map currently identifies drive/endpoint `0x08` as built-in RAM
storage and `0x09` as PCMCIA SRAM storage. Therefore, when `[0x6805]` is the
built-in endpoint (`0x08`), `ROM CARD` tries PCMCIA (`0x09`) and then built-in
RAM (`0x08`). The disassembly evidence for the two probes is in
[`menu-dispatch.md`](../v2.1/docs/menu-dispatch.md#file-menu-and-rom-card-storage), and the
endpoint map is in [`file-system.md`](../v2.1/docs/file-system.md#ioctl-and-endpoint-status).

## File Format

The minimum loaded image is ROM-version specific. The T400 2.1 row below is
audited from `t4_ir_2.1.ic303` and the local disassembly notes. The other rows
are comparative results from external ROM images under `../roms`; keep them
separate from T400 source-of-truth claims unless those images are rechecked.

These are the ROM CARD envelopes observed so far:

| ROM | Selector byte | Load / call-through | Header word 0 | Header word 1 | Status | Example |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| `dator3000.ic303` | `[6005]` | read/call `0x09C00` | `0x1210` | `0x1992` | supported, entry `09C0:0008` | [`EROMCARD-MEMCHECK-Original.X`](../examples/eromcard/EROMCARD-MEMCHECK-Original.X) |
| `dr3_1_02uk.ic303` | `[6005]` | read/call `0x09C00` | `0x1210` | `0x1992` | supported, entry `09C0:0008` | [`EROMCARD-MEMCHECK-Original.X`](../examples/eromcard/EROMCARD-MEMCHECK-Original.X) |
| `dr3_1_03.ic303` | `[6005]` | read/call `0x09C00` | `0x1210` | `0x1992` | supported, entry `09C0:0008` | [`EROMCARD-MEMCHECK-Original.X`](../examples/eromcard/EROMCARD-MEMCHECK-Original.X) |
| `drwrt200.bin` | `[1005]` | read/call `0x0CA00` | not checked | not checked | supported, entry `0CA0:0008` | [`EROMCARD-MEMCHECK-200.X`](../examples/eromcard/EROMCARD-MEMCHECK-200.X) |
| `nakajima_es.ic303` | `[6005]` | read/call `0x09C00` | `0x1210` | `0x1992` | supported, entry `09C0:0008` | [`EROMCARD-MEMCHECK-Original.X`](../examples/eromcard/EROMCARD-MEMCHECK-Original.X) |
| `nts_325_basic.ic303` | `[6005]` | read/call `0x09C00` | `0x1210` | `0x1992` | supported, entry `09C0:0008` | [`EROMCARD-MEMCHECK-Original.X`](../examples/eromcard/EROMCARD-MEMCHECK-Original.X) |
| `t100_2.3.ic303` | none found | none found | none found | none found | unsupported | none |
| `t4_ir_2.1.ic303` | `[6805]` | read/call `0x0A4F0` | `0xA4F0` | `0x1997` | supported, entry `0A4F:0008` | [`EROMCARD-MEMCHECK-T400.X`](../examples/eromcard/EROMCARD-MEMCHECK-T400.X) |
| `t4_ir_3.1_e588.ic303` | `[1005]` | read `0x0A4F0`, call `[0x0CA04]` | not checked | not checked | 1 MiB ROM, unsupported | none |
| `t4_ir_35ba308.ic303` | `[1005]` | read `0x0A4F0`, call `[0x0CA04]` | not checked | not checked | 1 MiB ROM, unsupported | none |
| `wales210.ic303` | `[6005]` | read/call `0x09C00` | `0x1210` | `0x1992` | supported, entry `09C0:0008` | [`EROMCARD-MEMCHECK-Original.X`](../examples/eromcard/EROMCARD-MEMCHECK-Original.X) |

The 512 KiB ROM CARD-capable families are now covered by the checked-in
examples. `drwrt200.bin` is a supported 1 MiB exception because its loader reads
and calls through the same `0x0CA00` base. The 1 MiB T400 ROM CARD loaders have
different call-through behavior and their display/API state has not been fully
understood, so this repository does not currently ship supported `EROMCARD.X`
examples for those ROMs.

For the T400 2.1 ROM, the checked header is:

```text
+0x00  word 0xA4F0
+0x02  word 0x1997
+0x04  far entry pointer, stored as offset then segment
+0x08  first byte available for code/data if the entry points here
```

For the `0x09C00` loader family, use `0x1210, 0x1992` and an entry segment
matching the `0x09C00` handoff address. The checked loaders currently validate
only the first two words before calling the far pointer.

See also:

| Topic | Reference |
| --- | --- |
| Loader search order, load address, header check, errors | [`file-system.md`](../v2.1/docs/file-system.md#rom-card-loader) |
| Menu disassembly showing first candidate then fallback drive | [`menu-dispatch.md`](../v2.1/docs/menu-dispatch.md#file-menu-and-rom-card-storage) |
| Practical `EROMCARD.X` image shape and relocation notes | [`basic-eromcard.md`](basic-eromcard.md#plausible-eromcardx-shape) |
| DreamWriter storage format and card image layout | [`file-system.md`](../v2.1/docs/file-system.md#directory-format-evidence) |
| ROM-card program ABI notes from the BASIC port | [`../dw-basic/docs/porting.md`](../dw-basic/docs/porting.md) |
| DreamLink file transfer protocol notes | [`dreamlink-protocol.md`](dreamlink-protocol.md) |

## Entry ABI And Constraints

The supported loaders call the entry with a far call through the ROM-specific
pointer, such as `[0xA4F4]`, `[0x9C04]`, or `[0xCA04]`.

Known constraints:

| Item | Constraint |
| --- | --- |
| Name | The executable must be named `EROMCARD.X` in 8.3 form. |
| Size | The file must fit within the loader's available work-memory limit. Oversized files show `Inadequate work memory`. |
| Load address | The entire file is copied to the ROM-specific load address; it is not executed in place from card storage. |
| Header | Words at file offsets `+0x00/+0x02` must match the ROM-specific header when the loader checks them. |
| Entry | File offset `+0x04` holds the far pointer the firmware calls. |
| Return | A normal payload can return with `retf`; the firmware then runs the ROM CARD cleanup path. |
| `AX` | The entry sees the byte work-memory limit used for the size check. |
| `DS` | Preserve the caller's `DS` before returning. The firmware expects its data segment to survive the external program. |

Payloads may use the T400's DOS-like `INT 21h` file services and the low-RAM
firmware vector table, but those are firmware ABIs rather than DOS process
services. Keep ROM-specific calls behind a small shim when possible; the current
`dw-basic` payloads use that pattern.

## Emulator Installation

Given a formatted SRAM card image, install the matching example as
`EROMCARD.X`:

```sh
python3 dw-basic/tools/install_eromcard.py \
  --card-in /tmp/dw-card-1m.bin \
  --card-out /tmp/dw-card-1m-test.bin \
  --payload examples/eromcard/EROMCARD-MEMCHECK-T400.X
```

Boot the card image in MAME:

```sh
../mame/drwrt400 drwrt400 \
  -pccard melcard_1m \
  -sramcard /tmp/dw-card-1m-test.bin
```

Then choose `OTHERS` -> `ROM CARD`.

## Example Payload

The three `EROMCARD-MEMCHECK-*.X` files under
[`../examples/eromcard`](../examples/eromcard) are checked-in examples copied
from the shared `dw-basic/src/eromcard_memcheck.asm` source with the matching
ROM CARD envelope selected at build time. Multiple ROMs share the same binary
when their loader envelope is identical.

It displays the ROM CARD launch state, including the incoming `AX`, entry `DS`,
`AX / 0x80`, and the byte limit, then waits until the blocking key-read API
returns ASCII Space before returning to the firmware. This makes stale menu
handoff keys harmless without using the nonblocking key-status wrapper.

Current envelope sizes and hashes:

```text
T400:    0x0A4F0 / 0xA4F0,0x1997: 378 bytes, 977cd0f0ce738fe182409fe6c86631d1b48bfc3b67bf15d6b06f46ce199a7e38
Original: 0x09C00 / 0x1210,0x1992: 378 bytes, c6b928201ae7399cc9f8eb856c645f0ad8a8b683d3f9a73ed41050345b465555
200:      0x0CA00 direct / local marker: 378 bytes, aa0ea8782813eef6f27ea095e1735881e886080bf3bf156fd6a632d7bc25dd46
```

When installed, the payload file still needs to be named `EROMCARD.X`; the
repository filename keeps the `-MEMCHECK` suffix only to identify the example.
