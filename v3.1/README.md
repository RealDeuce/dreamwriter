# DreamWriter T400 ROM 3.1 Notes

Working target: `t4_ir_3.1_e588.ic303`

```text
Size:   1048576 bytes
SHA256: d105317a9818a1b29b5d6f4c676f96bbd961646a571a0f4b6dc9b88cbe1de8e2
```

The 3.1 ROM is 1 MiB (double the 512 KiB v2.1 image). It uses the same
8-port banking scheme but fills all 8 ROM banks. At startup only windows 6-7
are ROM; windows 0-5 are RAM. See [`docs/map.md`](docs/map.md) for the full
address model and [`banking.md`](../docs/banking.md) for the shared banking
notes.

MAME supports this ROM via `drwrt400 -bios v3_1`.

## Boot Path

Startup begins at `C000:0000` (file `0xC0000`):

```asm
C000:0000  jmp C000:0029
```

The reset chain is `FFFF:0000` -> `F6E3:0000` (trampoline, sets bank ports)
-> `C000:0000`. Port values `0x16=0x01, 0x17=0x00` are identical to v2.1;
the trampoline segment and file offsets differ because the 1 MiB ROM uses
different bank-to-file mapping.

`C000:0029` initializes hardware, checks a 4-byte warm-RAM signature `"218"`
at `RAM [1000]` against `C000:7799`, and branches to cold or warm paths.

Cold start: reinitializes subsystems, validates the built-in store, installs
interrupt vectors, and enters the application runtime via `JMP FAR C772:0004`.

See [`docs/disassembly/boot.md`](docs/disassembly/boot.md) for the full
annotated disassembly.

## Documentation Index

| File | Description |
| --- | --- |
| [`docs/README.md`](docs/README.md) | Index for the v3.1 ROM notes. |
| [`docs/map.md`](docs/map.md) | Address model, banking layout, reset chain. |
| [`docs/rom-regions.tsv`](docs/rom-regions.tsv) | Machine-readable region map (initial). |
| [`docs/entry-points.md`](docs/entry-points.md) | Confirmed code entry points. |
| [`docs/disassembly/boot.md`](docs/disassembly/boot.md) | Annotated boot disassembly. |
