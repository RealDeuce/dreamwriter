# DreamWriter T400 ROM Map

Reverse-engineering notes, disassembly, and tooling for the DreamWriter T400
typewriter firmware.

## ROM Versions

| Version | Directory | ROM File | Size |
| --- | --- | --- | --- |
| 2.1 | [`v2.1/`](v2.1/) | `t4_ir_2.1.ic303` | 512 KiB |
| 3.1 | [`v3.1/`](v3.1/) | `t4_ir_3.1_e588.ic303` | 1 MiB |
| 3.1.260 | [`v3.1.260/`](v3.1.260/) | `t4_ir_3.1_8c8f.ic303` | 1 MiB |

Each version directory contains the ROM binary and version-specific notes. The
primary 2.1 and 3.1 directories also contain the detailed disassembly docs. See
the README in each directory for details.

## Shared Resources

| Directory | Contents |
| --- | --- |
| [`docs/`](docs/) | Hardware, banking, protocol, and reference docs common to all versions. |
| [`tools/`](tools/) | ROM inspection helpers (`rom2.py`), validation scripts, and MAME automation. See [`tools/README.md`](tools/README.md). |
| [`dw-basic/`](dw-basic/) | NASM-targeted DreamWriter BASIC port workspace. Builds for both ROM versions. |
| [`gw-basic/`](gw-basic/) | Read-only Microsoft GW-BASIC 1983 source tree used as a porting reference. |
| [`mame/`](mame/) | MAME driver snapshot (`nakajies.cpp`). Supports checked-in T400 ROM variants via `-bios`. |
| [`examples/`](examples/) | Example `EROMCARD.X` ROM card payloads. |
| [`third_party/`](third_party/) | Vendored flatlink linker for `dw-basic` builds. |

## Related Projects

| Project | Notes |
| --- | --- |
| [Dreamulator](https://github.com/realDeuce/dreamulator) | DreamWriter emulator project. |
| [DreamWriter 200 notes](https://github.com/RealDeuce/dreamwriter200) | Similar ROM-map notes for the DreamWriter 200. |
