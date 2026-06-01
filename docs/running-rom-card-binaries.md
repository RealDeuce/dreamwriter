# Running ROM CARD Binaries

The T400 can run an arbitrary real-mode binary through the `ROM CARD` item in
the `OTHERS` menu when the binary is packaged as a DreamWriter `EROMCARD.X`
file and stored where the normal file system can find it. In the normal
built-in-storage state, this does not require a PCMCIA card: the loader tries
the PCMCIA SRAM endpoint first, then falls back to built-in RAM storage.

This is not a PC DOS `.COM` or `.EXE` path. The firmware uses the storage layer
to find a file named exactly `EROMCARD.X`, reads that file into RAM at physical
address `0x0A4F0`, validates a small DreamWriter header, and calls the far entry
pointer stored in the file header. The loader behavior and failure strings are
tracked in [`file-system.md`](file-system.md#rom-card-loader).

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
[`menu-dispatch.md`](menu-dispatch.md#file-menu-and-rom-card-storage), and the
endpoint map is in [`file-system.md`](file-system.md#ioctl-and-endpoint-status).

## File Format

The minimum loaded image is:

```text
+0x00  word 0xA4F0
+0x02  word 0x1997
+0x04  far entry pointer, stored as offset then segment
+0x08  first byte available for code/data if the entry points here
```

Common tiny payloads point the entry at `0A4F:0008`, because the whole file is
loaded at physical `0x0A4F0`. The loader currently validates only the first two
words before calling the far pointer.

See also:

| Topic | Reference |
| --- | --- |
| Loader search order, load address, header check, errors | [`file-system.md`](file-system.md#rom-card-loader) |
| Menu disassembly showing first candidate then fallback drive | [`menu-dispatch.md`](menu-dispatch.md#file-menu-and-rom-card-storage) |
| Practical `EROMCARD.X` image shape and relocation notes | [`basic-eromcard.md`](basic-eromcard.md#plausible-eromcardx-shape) |
| DreamWriter storage format and card image layout | [`file-system.md`](file-system.md#directory-format-evidence) |
| ROM-card program ABI notes from the BASIC port | [`../dw-basic/docs/porting.md`](../dw-basic/docs/porting.md) |
| DreamLink file transfer protocol notes | [`dreamlink-protocol.md`](dreamlink-protocol.md) |

## Entry ABI And Constraints

The loader calls the entry with a far call through `[0xA4F4]`.

Known constraints:

| Item | Constraint |
| --- | --- |
| Name | The executable must be named `EROMCARD.X` in 8.3 form. |
| Size | The file must fit within the loader's available work-memory limit, returned by `C688:01E6` as `[7A54] * 0x80`. Oversized files show `Inadequate work memory`. |
| Load address | The entire file is copied to physical `0x0A4F0`; it is not executed in place from card storage. |
| Header | Words at file offsets `+0x00/+0x02` must be `0xA4F0, 0x1997`. |
| Entry | File offset `+0x04` holds the far pointer the firmware calls. |
| Return | A normal payload can return with `retf`; the firmware then runs the ROM CARD cleanup path. |
| `AX` | The entry sees `AX = [7A54] * 0x80`, the byte work-memory limit used for the size check. |
| `DS` | Preserve the caller's `DS` before returning. The firmware expects its data segment to survive the external program. |

Payloads may use the T400's DOS-like `INT 21h` file services and the low-RAM
firmware vector table, but those are firmware ABIs rather than DOS process
services. Keep ROM-specific calls behind a small shim when possible; the current
`dw-basic` payloads use that pattern.

## Emulator Installation

Given a formatted SRAM card image:

```sh
python3 dw-basic/tools/install_eromcard.py \
  --card-in /tmp/dw-card-1m.bin \
  --card-out /tmp/dw-card-1m-test.bin \
  --payload examples/eromcard/EROMCARD-MEMCHECK.X
```

Boot the card image in MAME:

```sh
../mame/drwrt400 drwrt400 \
  -pccard melcard_1m \
  -sramcard /tmp/dw-card-1m-test.bin
```

Then choose `OTHERS` -> `ROM CARD`.

## Example Payload

[`../examples/eromcard/EROMCARD-MEMCHECK.X`](../examples/eromcard/EROMCARD-MEMCHECK.X)
is a checked-in example copied from `dw-basic/build/EROMCARD-MEMCHECK.X`.

It displays the ROM CARD launch state, including the incoming `AX`, entry `DS`,
`[7A54]`, and the computed byte limit, waits for one key, then returns to the
firmware. This makes it useful for testing that the file was found, loaded,
called, and able to return cleanly.

Current captured artifact:

```text
size:   999 bytes
sha256: 12afddf0b6eecaa26f24e852260a9da071be360ed2a01671c5cbc8c40fddf550
header: f0 a4 97 19 08 00 4f 0a
```

When installed, the payload file still needs to be named `EROMCARD.X`; the
repository filename keeps the `-MEMCHECK` suffix only to identify the example.
