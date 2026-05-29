# ROM Tool Reference

`rom2.py` contains small inspection helpers for the DreamWriter T400 ROM 2.1
image. By default it reads `t4_ir_2.1.ic303` from the repository root and
expects the 512 KiB image with SHA-256:

```text
bb6a437d4c25f90eb7a0b8bc3d41e1ca2c74196aabe60954a598c66405397757
```

Use `--rom PATH` before the subcommand to inspect a different file:

```sh
tools/rom2.py --rom t4_ir_2.1.ic303 verify
```

The script assumes the 2.1 ROM is loaded at physical `0x80000`, matching the
local MAME model. File offsets therefore map to physical addresses by adding
`0x80000`.

## Number And Address Syntax

Integer arguments accept `0x` prefixes and `$` prefixes for hexadecimal values.
Bare values containing `a..f` are also parsed as hexadecimal. Bare values made
only of digits are parsed by Python's normal integer rules, so use `0x40000` or
`$40000` when you mean hexadecimal `40000`.

The `addr` command also accepts:

| Form | Meaning |
| --- | --- |
| `file:0x46912` | ROM file offset. |
| `phys:0xc6912` | 20-bit physical address. |
| `c688:0053` | Real-mode segment:offset address. Segment and offset parts are bare hexadecimal unless prefixed. |
| `0x46912` | Bare value below `0x80000` is treated as a file offset. |
| `0xc6912` | Bare value at or above `0x80000` is treated as physical. |

## Commands

### `verify`

Checks the ROM size and SHA-256 digest.

```sh
tools/rom2.py verify
```

### `addr`

Converts between ROM file offsets, physical addresses, and canonical
segment:offset form. If the physical address is in `0xC0000..0xCFFFF`, it also
prints the convenient `C000:xxxx` alias.

```sh
tools/rom2.py addr file:0x46912
tools/rom2.py addr phys:0xc6912
tools/rom2.py addr c688:0053
```

### `bank`

Describes how a MAME bank-select port/value pair maps a 128 KiB CPU window.
Ports `0x10..0x17` correspond to the eight `0x20000`-byte CPU windows.

```sh
tools/rom2.py bank 0x17 0x00 --cpu 0xffff0
tools/rom2.py bank 0x11 0x0e --cpu 0x20000
```

The helper models normal ROM/RAM banking and the current special bit-3 RAM
window behavior used by the MAME driver notes.

### `strings`

Lists printable ASCII runs. The scan excludes tab, carriage return, and line
feed. Output includes file offset, physical address, `C000:` alias when
applicable, and text.

```sh
tools/rom2.py strings --start 0x40000 --end 0x80000 -n 8
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `-n`, `--minimum` | `8` | Minimum printable run length. |
| `--start` | `0` | File offset to begin scanning. |
| `--end` | ROM end | File offset to stop scanning. |

### `glyphs`

Renders fixed-height 1bpp glyphs as `#` and `.` text. Glyph rows are read
MSB-first, one byte per row unless `--height` changes the row count. The default
font is the main 8x8 font at file `0x580B6`, with first character code `0x20`.

```sh
tools/rom2.py glyphs --text 'A0!'
tools/rom2.py glyphs --bold --text 'A0!'
tools/rom2.py glyphs --code 0xc0 --code 0xc1
tools/rom2.py glyphs --base 0x5c8b6 --first-code 0x00 --count 27
```

Font-base shortcuts:

| Option | Base | Meaning |
| --- | ---: | --- |
| `--bold` | `0x586B6` | Bold glyph run. |
| `--small` | `0x58CB6` | Small/down-shifted glyph run. |
| `--small-bold` | `0x592B6` | Small bold/down-shifted glyph run. |
| `--narrow` | `0x598B6` | Narrow glyph run. |
| `--narrow-bold` | `0x59EB6` | Narrow bold glyph run. |
| `--narrow-small` | `0x5A4B6` | Narrow small/down-shifted glyph run. |
| `--narrow-small-bold`, `--narrow-bold-small` | `0x5AAB6` | Narrow small bold/down-shifted glyph run. |
| `--sparse` | `0x5B0B6` | Sparse/remapped glyph run. |
| `--sparse-bold` | `0x5B6B6` | Sparse/remapped bold glyph run. |
| `--sparse-small` | `0x5BCB6` | Sparse/remapped small glyph run. |
| `--sparse-small-bold`, `--sparse-bold-small` | `0x5C2B6` | Sparse/remapped small bold glyph run. |

Other options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--base` | `0x580b6` | File offset for glyph `--first-code`; ignored when a shortcut is used. |
| `--first-code` | `0x20` | Character code represented by the first glyph at `--base`. |
| `--height` | `8` | Bytes/rows per glyph. |
| `--columns` | `8` | Visible columns to render from each row byte. |
| `--width-table` | `0x58000` | Optional file offset for per-glyph width/metadata bytes; pass `--width-table ""` to suppress it. |
| `--count` | `16` | Number of sequential glyphs when no text/code is given. |
| `--text` | none | Render glyphs for each character in a string. |
| `--code` | none | Render a specific code; may be repeated. |

### `bitmap`

Renders fixed-size 1bpp bitmap blocks as `#` and `.` text.

```sh
tools/rom2.py bitmap --base 0x44d30 --row-bytes 6 --height 40 --count 3
tools/rom2.py bitmap --base 0x53a2f --row-bytes 5 --height 34 --columns 36
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--base` | required | File offset of the first bitmap block. |
| `--row-bytes` | `6` | Bytes per bitmap row. |
| `--height` | `40` | Bitmap height in rows. |
| `--columns` | `row-bytes * 8` | Visible columns to render. |
| `--count` | `1` | Number of sequential bitmap blocks to render. |
| `--stride` | `row-bytes * height` | Bytes between bitmap blocks. |
| `--invert` | off | Render zero bits as set pixels. |

### `bitmap-records`

Scans for plausible `FF 42` source-backed bitmap records. The record format
handled by the scanner is:

```text
FF 42  height:u16le  width:u16le  source_off:u16le  source_seg:u16le
```

The source pointer is converted through real-mode segment:offset addressing
back to a ROM file offset. Candidates are rejected if dimensions are outside the
requested range, the source pointer is outside the ROM, or the source bitmap
would run past EOF.

```sh
tools/rom2.py bitmap-records --start 0x53800 --end 0x58000 --commands
tools/rom2.py bitmap-records --start 0x40000 --end 0x80000 --require-position --format markdown
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--start` | `0` | File offset to begin scanning. |
| `--end` | ROM end | File offset to stop scanning. |
| `--min-height` | `1` | Minimum record height. |
| `--max-height` | `64` | Maximum record height. |
| `--min-width` | `1` | Minimum record width. |
| `--max-width` | `480` | Maximum record width. |
| `--limit` | `0` | Maximum records to print; `0` means all. |
| `--require-position` | off | Only include records immediately preceded by `FF 40 x:u16le y:u16le`. |
| `--commands` | off | Print matching `bitmap` render commands. |
| `--format` | `text` | Output format: `text` or `markdown`. |

### `position-ops`

Finds `FF 40` position records followed by another `FF xx` resource opcode
within a configurable gap. This is useful for discovering compact display
scripts that are not direct `FF 42` bitmap blits.

The `FF 40` format decoded here is:

```text
FF 40  x:u16le  y:u16le
```

```sh
tools/rom2.py position-ops --start 0x50000 --end 0x58000
tools/rom2.py position-ops --start 0x6f000 --end 0x79000 --min-opcode 0x41 --max-opcode 0x44
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--start` | `0` | File offset to begin scanning. |
| `--end` | ROM end | File offset to stop scanning. |
| `--max-gap` | `80` | Maximum bytes after `FF 40` to search for the next `FF`. |
| `--min-opcode` | `0x40` | Minimum following opcode byte. |
| `--max-opcode` | `0x4F` | Maximum following opcode byte. |
| `--limit` | `0` | Maximum records to print; `0` means all. |

### `xrefs`

Runs `ndisasm` over a file-offset range and extracts direct branch/call targets
from the linear disassembly. This is an inventory helper, not a recursive
disassembler. It does not follow control flow, recover function boundaries, or
resolve indirect calls/jumps.

`ndisasm` must be installed and available on `PATH`.

```sh
tools/rom2.py xrefs --start 0x40000 --end 0x50000
tools/rom2.py xrefs --start 0x40000 --end 0x50000 --format markdown --limit 20
tools/rom2.py xrefs --start 0x5d000 --end 0x62000 --near-seg 0xdc98
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--start` | `0x40000` | File offset where disassembly begins. |
| `--end` | `0x50000` | File offset where disassembly stops. |
| `--near-seg` | `0xC000` | Segment used to resolve near branch/call targets. |
| `--limit` | `40` | Maximum rows or target-summary entries to print. |
| `--format` | `text` | Output format: `text` prints branch rows, `markdown` prints target counts. |

Recognized direct-control-flow mnemonics are `call`, `jmp`, conditional jumps,
and `loop`/`loopz`/`loopnz`. Far `seg:off` targets are resolved directly; near
targets are resolved through `--near-seg`.

## Typical Workflows

Check that the expected ROM is present:

```sh
tools/rom2.py verify
```

Convert an address from a disassembly note:

```sh
tools/rom2.py addr C000:1240
```

Scan a ROM area for strings:

```sh
tools/rom2.py strings --start 0x6f700 --end 0x70500 -n 6
```

Render a known 40x40 menu icon:

```sh
tools/rom2.py bitmap --base 0x704d4 --row-bytes 5 --height 40 --columns 40
```

Render a complete font run:

```sh
tools/rom2.py glyphs --narrow-small-bold --count 95 > narrow-small-bold-20-7e.txt
```

Generate bitmap render commands from inline display records:

```sh
tools/rom2.py bitmap-records --start 0x53800 --end 0x58000 --commands
```
