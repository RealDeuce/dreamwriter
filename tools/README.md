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
segment:offset form.

The command accepts one or more values and can also read additional values from
stdin:

```sh
tools/rom2.py addr file:0x46912
tools/rom2.py addr phys:0xc6912
tools/rom2.py addr c688:0053
tools/rom2.py addr --segment c688 44db
printf 'C688:0080\\n0x6bbb0\\n' | tools/rom2.py addr --stdin --format compact file:0x46912
```

Output formats:

| Format | Meaning |
| --- | --- |
| `text` | `file`, `phys`, and `seg:off` with optional `C000` alias (default). |
| `compact` | one-line single record: `input: file 0x... phys 0x... seg:off`. |
| `tsv` | machine-friendly tab-separated fields `input`, `file`, `phys`, `seg:off`, `alias`. |

You can keep output minimal with compact/tsv during address-heavy disassembly
validation:

```sh
tools/rom2.py addr --format tsv C688:0053 c688:00A0
printf '0x46912\\nC700:1234\\nphys:0x8a000\\n' | tools/rom2.py addr --stdin --format compact
```

Use `--segment` when working inside a known code segment. Bare values are parsed
as offsets in that segment, and explicit `file:`, `phys:`, or `seg:off` inputs
must also be representable inside the chosen 64 KiB segment window:

```sh
tools/rom2.py addr --segment c688 44db --format compact
# C688:44DB: file 0x4AD5B phys 0xCAD5B C688:44DB

tools/rom2.py addr --segment c688 file:0x4ad5b C000:AD5B --format compact
# file:0x4ad5b: file 0x4AD5B phys 0xCAD5B C688:44DB
# C000:AD5B: file 0x4AD5B phys 0xCAD5B C688:44DB
```

If the physical address is in `0xC0000..0xCFFFF`, `text` (and `tsv`) also include the
`C000:xxxx` alias.

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

### `decode_lcd_text.py`

Decodes a `drwrt400` LCD snapshot PNG into text using the ROM's main 6x8 text
font.  The decoder is exact: every 6x8 cell must match a ROM glyph, otherwise it
reports the row/column and cell pixels that did not decode.

```sh
python3 tools/decode_lcd_text.py ../mame/snap/drwrt400/0000.png
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--rom` | `t4_ir_2.1.ic303` | ROM image to read font data from. |
| `--font-base` | `0x580b6` | File offset for the first glyph. |
| `--first-code` | `0x20` | Character code represented by the first glyph. |
| `--last-code` | `0x7e` | Last character code accepted as text. |
| `--no-trim` | off | Preserve trailing spaces on each decoded row. |
| `--allow-cursor` | off | Treat an all-lit 6x8 cell as the active inverse text cursor. |
| `--allow-inverse` | off | Decode exact bitwise-inverted ROM glyphs as text. |
| `--attrs` | off | Print a fixed-width two-hex-digit attribute mask line after each decoded text line; plain cells are `..`. Bits are `01` underline, `02` inverse, `04` bold, `08` small font, and `10` superscript position. |
| `--cursor-char` | space | Character emitted for `--allow-cursor`. |

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

### `render_rom_bitmap_png.py`

Writes a fixed-size 1bpp ROM bitmap to PNG without external dependencies. Bits
are decoded MSB-first, matching the text `bitmap` helper above. Set bits render
as black pixels by default.

```sh
tools/render_rom_bitmap_png.py 0x53a2f 36 34 /tmp/startup-button.png --row-bytes 5 --scale 4
tools/render_rom_bitmap_png.py 0x6e59a 40 40 /tmp/wp-edit-text.png --row-bytes 5 --scale 4
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--rom` | `t4_ir_2.1.ic303` | ROM image to read. |
| `--row-bytes` | `ceil(width / 8)` | Bytes per source bitmap row. |
| `--stride` | effective `row-bytes` | Bytes between source rows. |
| `--scale` | `1` | Nearest-neighbor output scale. |
| `--invert` | off | Treat zero bits as black pixels. |

### `generate_symbol_index.py`

Builds `docs/disassembly/symbol-index.html`, a static sortable symbol table
from named labels in `docs/disassembly/*.md`. Labels with address suffixes such
as `foo_C000_1234:` use the suffix; labels without a suffix use the next nearby
instruction address.

```sh
tools/generate_symbol_index.py
tools/generate_symbol_index.py --check
```

### `disassembly_audit.py`

Runs semantic consistency checks over `docs/disassembly/*.md` and generates
review indexes for the annotated disassembly. The check mode validates:

- `; file 0x...` comments against nearby labels or first shown instructions.
- labels with embedded addresses against nearby instruction addresses.
- documented PNG asset dimensions against the checked-in PNG files.
- string-resource table rows for non-empty final text.

The generate mode writes:

- `docs/disassembly/asset-index.md`
- `docs/disassembly/string-resource-index.md`
- `docs/disassembly/ram-ledger.md`
- `docs/disassembly/io-port-ledger.md`
- `docs/disassembly/transfer-targets.md`
- `docs/disassembly/call-graph.dot`

```sh
tools/disassembly_audit.py check
tools/disassembly_audit.py generate
tools/disassembly_audit.py check --generated
```

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

### `disasm`

Disassemble an arbitrary ROM window from a mixed address without manual address
translation. This command sets the `ndisasm` origin to the chosen physical
address so branch/call targets come out as the expected segment-friendly
addresses for your notes.

```sh
tools/rom2.py disasm c688:0053 --count 0x300
tools/rom2.py disasm file:0x6bbb0 --count 0x180
tools/rom2.py disasm phys:0x8e520
printf 'C688:0053\\nC688:00A0\\n' | tools/rom2.py disasm --stdin --count 0x200
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--count` | `0x400` | Bytes to feed to `ndisasm` from the start address. |
| `--stdin` | off | Read additional start addresses from stdin. |
| `--count-output` | off | Print an extra blank line after each decoded block. |

`ndisasm` must be installed and available on `PATH`.

### `xref-scan`

Scans Markdown files for `TODO-xref` markers and validates that each marker has at
least one parsable address token (`seg:off`, `file:...`, or `phys:...`).

```sh
tools/rom2.py xref-scan docs/disassembly/README.md docs/disassembly/*.md
tools/rom2.py xref-scan --format markdown docs/disassembly/boot.md
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `scope` | `docs/disassembly/*.md` | Markdown files, globs, or directories to scan. |
| `--format` | `text` | Output format: `text` or `markdown`. |

Exit status is non-zero when any `TODO-xref` line cannot be resolved to a known
address form.

### `queue-audit`

Audits the queue in `docs/disassembly/README.md`, checks whether queue roots also
appear in other disassembly markdown files, and shows open vs already-seen roots.

```sh
tools/rom2.py queue-audit
tools/rom2.py queue-audit --open-only
tools/rom2.py queue-audit --format markdown --queue docs/disassembly/README.md
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--queue` | `docs/disassembly/README.md` | Path for the queue section to audit. |
| `--scope-docs` | `docs/disassembly/*.md` | Markdown files used to determine if a root is already seen elsewhere. |
| `--open-only` | off | Show only roots currently not found outside the queue file. |
| `--format` | `text` | Output format: `text` or `markdown`. |

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

### `regions`

Lists the machine-readable first-pass ROM region map. The default map is
`docs/rom-regions.tsv`. File ranges are always standalone ROM offsets; CPU
ranges are derived from the region `segment` column when present, so banked
code can disassemble at the address it expects to run from.

```sh
tools/rom2.py regions
tools/rom2.py regions --types code,monitor-code --format markdown
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--regions` | `docs/rom-regions.tsv` | TSV region map path. |
| `--types` | none | Comma-separated region types to include. |
| `--format` | `text` | Output format: `text` or `markdown`. |

### `io-scan`

Disassembles mapped regions with `ndisasm` and lists x86 `in`/`out`/string I/O
instructions. This is intended for code-only sweeps: by default it scans only
`code` and `monitor-code` regions from `docs/rom-regions.tsv`, which avoids the
worst false positives from text, fonts, bitmaps, and display-resource streams.
The results are only as accurate as the current region map.

```sh
tools/rom2.py io-scan --summary
tools/rom2.py io-scan --limit 80
tools/rom2.py io-scan --types monitor-code --format markdown
```

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--regions` | `docs/rom-regions.tsv` | TSV region map path. |
| `--types` | `code,monitor-code` | Comma-separated region types to disassemble and scan. |
| `--summary` | off | Print counts by direct port, with `DX/string` for variable-port/string I/O. |
| `--limit` | `0` | Maximum rows to print; `0` means all. |
| `--format` | `text` | Output format: `text` or `markdown`. |

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

Run a code-only I/O sweep from the first-pass region map:

```sh
tools/rom2.py io-scan --summary
```

Run the full disassembly validation workflow (snippet bytes + disassembly signature + TODO-xref + queue audit):

```sh
tools/disasm-validate.sh
tools/disasm-validate.sh --open-only --docs docs/disassembly/*.md --queue docs/disassembly/README.md
```

You can scope validation to a single markdown file:

```sh
python3 tools/validate_snippets.py docs/disassembly/app-menu-event-loop.md
tools/disasm-validate.sh --docs docs/disassembly/app-menu-event-loop.md
```
