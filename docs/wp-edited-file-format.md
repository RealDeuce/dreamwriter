# Word Processor Edited File Format

This note tracks the native word-processor edited-file payload, as distinct
from the filesystem container and the organizer `*.ODB` databases. The current
evidence comes from the C772 document operation path in v3.1 and the matching
v3.1.260 serializer signature at `C774:82D5`.

## High-Level Shape

Stored WP payloads are editor streams. The native headered form begins with a
serialized state header:

| Payload offset | Size | Meaning |
| ---: | ---: | --- |
| `0x0000` | `1` | Header marker `0xFF`. |
| `0x0001` | `1` | Header length in bytes, not including the marker or this length byte. |
| `0x0002` | `N` | Serialized editor state header. Minimum confirmed length is `0x0E`. |
| `0x0002 + N` | variable | Editor text/control stream. |

Older test files with `FF 10 ...` fit this structure: `0x10` is not a separate
file type byte, it is the serialized header length. The native serializer can
also produce `FF 0E ...` when the variable header table is empty. The reader
also has a non-header path when the first stream byte is not `0xFF`.

## Implementation Checklist

For a native reader/writer, the mechanically important rules are:

- Detect native versus legacy input: treat leading `FF` as the native header
  marker. A non-`FF` first byte is the RECALL legacy/plain path, not a malformed
  native file.
- Parse a native header: read the one-byte length, then seven little-endian
  words, then an even-length tab-stop tail. ROM-produced native files use
  header length `0x0E..0x2E`; external tools should flag lengths outside that
  range, odd tab tails, truncated fixed words, and stored tab words with the
  runtime sentinel high bit set.
- Restore tab stops: copy stored tab words into the live-equivalent table and
  append `80 80` as the in-RAM sentinel. The sentinel is not stored in native
  files.
- Decode body records: consume only `E8`, `E9`, `EC`, `ED`, `EE`, and `EF` as
  fixed-width multi-byte records. Treat `EA`, `EB`, and `F0..FF` style markers
  as single-byte controls. Unknown `E9`/`EF` subtypes remain records and must
  not be reinterpreted as text bytes.
- Validate fixed-width records: the closing byte of each fixed-width record
  should match the opening marker. For the confirmed `EF 06` producer, the
  sign-extension byte is `00` for nonnegative accumulator bytes and `FF` for
  negative accumulator bytes.
- Write a native file: emit `FF`, the header length, the seven serialized
  words, the tab-stop bytes before the `80 80` sentinel, then the body stream.
  The filesystem byte count terminates the file; local native STORE does not
  append a payload `0x1A`.
- Handle legacy/plain RECALL: for non-`FF` input, preserve tabs initially,
  accept bytes `0x20..0xDF`, drop unsupported C0 controls and bytes `>= 0xE0`,
  convert CR/LF to `0x0C` while collapsing CR/LF pairs, and expand tabs to
  eight-column stops when the live editor span path requires it.

`tools/decode_wp_payload.py --body --strict --require-native` validates native
STORE captures against these parser invariants. For non-`FF` RECALL captures,
use `--legacy-preview` instead of `--require-native`.

## Canonical Byte Grammar

The native payload grammar, stated without the provenance notes, is:

```text
payload         := native-payload | legacy/plain input
native-payload  := FF header-length header-bytes body-stream
header-bytes    := seven-le16-words tab-stop-words
tab-stop-words  := zero to sixteen little-endian words, no 8080h sentinel
body-stream     := zero or more body-items, terminated by the file byte count
```

A reader should choose the native grammar only when payload byte zero is
`0xFF`. Otherwise the ROM takes the legacy/plain RECALL path and normalizes
the byte stream before seeding default format state.

For native files, `header-length` is the byte count of `header-bytes` only.
ROM-produced values are `0x0E..0x2E`: seven fixed words plus up to sixteen
two-byte tab stops. The in-RAM `80 80` tab sentinel is appended by the reader
after loading and is not stored in the file.

The body stream is self-synchronizing only if the decoder consumes the known
fixed-width records as records:

```text
E8 <word-a> <word-b> E8
E9 <subtype> <word> E9
EC <old-pitch> <new-pitch> EC
ED <old-spacing> <new-spacing> ED
EE <word-a> <word-b> EE
EF <subtype> <line-pos-word> <signed-byte> <sign-extension> EF
F0..FF as single-byte style toggles, except the initial file header marker
EA and EB as single-byte formatter run delimiters
other bytes as single-byte stream items unless a scanner/control path claims them
```

The closing marker byte should match the opening marker for `E8`, `E9`,
`EC`, `ED`, `EE`, and `EF`. Unknown `E9` or `EF` subtypes are still records
with the same width. They should be reported as unknown subtype records, not
reinterpreted as text or used to resynchronize by scanning for another marker.

Bytes from the editor keyboard/control tables are not automatically stored as
the same byte values. Several user commands materialize as formatter output:
Page End stores as `E9 02 <word> E9`, Vertical Line as frame glyph `C6` plus
range/separator records in the simple sample, Center/Right Flush as `E4`
alignment fill plus text, Decimal Tab as an `EE` range record plus text, and
Indent/Indent Clear as `E8` positional records.

## Header Layout

`C772:82D6` serializes the header by writing these seven words, then appending
the tab-stop table bytes from `0x7A20` up to but not including the `8080h`
sentinel. Words are written little-endian.

| Header offset | Size | Source field | Current read |
| ---: | ---: | --- | --- |
| `+0x00` | `2` | `[7438]` | Left margin in horizontal internal units. `C772:8B03` displays/edits this field directly, with manual space values converted through the `*6` input path. Nonzero also causes `C772:5C65` to run a positioning pass before emitting ruler/tab markers. |
| `+0x02` | `2` | `[7436]` | Right margin span relative to the left margin, in horizontal internal units. `C772:88C4` displays it as `[7438] + [7436]`, `C772:8B78` edits it with the manual 10-space minimum gap (`0x3C` internal units), and `C772:5C65` emits editor-ruler marker `0x29` at this relative position. The `rm76` STORE sample confirms that changing manual right margin 75 -> 76 changes this word from `0x0186` to `0x018C`. |
| `+0x04` | `2` | `[742D]` | Right-margin-coupled ruler/layout threshold, stored as a position relative to the left margin. `C772:16CA` uses `[742D]` to alter formatter class selection before that threshold. The Page Format right-margin path computes the old `[7436] - [742D]` gap at `C772:8C2E`, saves it in `[708E]`, and after editing `[7436]` stores `[742D] = [7436] - old_gap` when possible, otherwise `[742D] = [7436]`. The `rm76` sample shows the default zero-gap value moving with `[7436]` (`0x0186` -> `0x018C`). A controlled `CTRL+7` indent sample with a five-space indent marker did **not** change this header word; it saved the one-line indent as an `E8 1E 00 00 00 E8` body record instead. Current read: `[742D]` participates in persistent ruler/layout state, but it is not the direct serialized form of a simple one-line indent command. |
| `+0x06` | `2` | `[741B]` | Paper width span relative to the left margin, in horizontal internal units. `C772:8BE6` displays/edits it as `[7438] + [741B]`, requires it to remain at or beyond the right margin span, and keeps the absolute value below the manual paper-width maximum. The `pw86` STORE sample confirms that changing manual paper width 85 -> 86 changes this word from `0x01C2` to `0x01C8`. The `rm76` sample shows the Page Format right-margin edit also increasing this span, apparently preserving the default 10-space gap between right margin and paper width. |
| `+0x08` | `2` | `[7423]` | Paper length in doubled line units. `C772:897D` displays it through the divide-by-2 path, `C772:8AAE` edits it, rejects values at or above `0xC7` internal units, and keeps it at least two printed lines beyond the top margin. The `pl67` STORE sample confirms that changing manual paper length 66 -> 67 changes this word from `0x0084` to `0x0086`. |
| `+0x0A` | `2` | `[7425]` | Top margin in doubled line units. `C772:897D` displays it through the divide-by-2 path; `C772:89B9` edits it, keeps it below `[7423] - 4`, and copies it into live fields `[741D]` and `[7429]`. The `tm7` STORE sample confirms that changing manual top margin 6 -> 7 changes this word from `0x000C` to `0x000E`. |
| `+0x0C` | `2` | `[741F]` | Printable body-end / bottom-margin complement in doubled line units. The bottom margin displayed by `C772:897D` is `([7423] - ([741F] + 2)) / 2`; `C772:89EE` edits that displayed bottom margin by storing `[741F] = [7423] - bottom_margin*2 - 2`. The `bm7` STORE sample confirms that changing manual bottom margin 6 -> 7 changes this word from `0x0076` to `0x0074`; the `pl67` sample shows the default field moving with paper length (`0x0076` -> `0x0078`) to preserve the displayed bottom margin. |
| `+0x0E` | variable | `[7A20...]` | Individual tab-stop table, terminated in RAM by `80 80` but stored without that sentinel. |

The header length byte is therefore:

```text
0x0E + number_of_tab_stop_bytes_before_80_80
```

For well-formed native files produced by the ROM, the valid range is
`0x0E..0x2E`: seven fixed words plus zero to sixteen two-byte tab-stop entries.
The tab tail length is therefore even. The serializer enforces this by stopping
when it sees the `8080h` sentinel or when `SI` reaches `0x7A40`; it then stores
`(SI - 0x7A20) + 0x0E` as the length byte.

On load, `C772:83A2` reads the length byte, restores the same seven words via
`C772:8401`, then copies `length - 0x0E` bytes into `[7A20...]` and appends
`80 80` in RAM as the table sentinel. `C772:8A2F` then normalizes the
line-layout fields used for top/bottom/body limits:

```text
[7425] bit 15 clear
[7425] <= [7429]
[7429] + 2 <= [741F]
[741F] + 2 <= [7423]
```

The reader does not clamp the length to the serializer's `0x2E` maximum and
does not reject odd or sub-`0x0E` values before entering the copy loop. A robust
external decoder should treat lengths outside `0x0E..0x2E`, odd tab-tail
lengths, or truncated seven-word headers as malformed native files rather than
as alternate format variants.

The mapping above comes from the Page Format edit/display routines, not just
from the raw serializer. Horizontal values use the `C772:8868` input path,
which converts manual space columns to internal units by multiplying by 6. That
matches the manual's left/right-margin minimum gap: 10 spaces become `0x3C`
internal units. Line values use the `C772:885C` path, which stores manual line
counts doubled; this accounts for the `C772:8AAE` paper-length limit just below
`0xC7`, which accepts the manual maximum of 99 lines (`99 * 2 = 198`).

Controlled v3.1 Dreamulator STORE samples now confirm the left-margin unit and
the relative right-margin-span interpretation. The default empty/text samples
store this header prefix:

```text
FF 10 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00 1E 00
```

After opening Page Format with `CTRL+3`, changing only `LEFT MARGIN` from
`010` to `011`, and storing an empty file as `lm11`, the native file is exactly
18 bytes:

```text
FF 10 42 00 86 01 86 01 C2 01 84 00 0C 00 76 00 1E 00
```

Only header word `+0x00` changed: `0x003C` became `0x0042`, matching
`10 * 6` versus `11 * 6` internal horizontal units. Header word `+0x02`
remained `0x0186`, so the stored right-margin value is the span from the left
margin, not the absolute manual column. The visible/manual right margin shifts
with the left margin unless edited separately, exactly as the manual describes.

A complementary empty-file sample changes only `RIGHT MARGIN` from `075` to
`076` on a default Page Format screen and stores as `rm76`:

```text
FF 10 3C 00 8C 01 8C 01 C8 01 84 00 0C 00 76 00 1E 00
```

Relative to the default header, word `+0x02` changed from `0x0186` to
`0x018C`, again a one-column `*6` delta. The sample also shows the coupled
Page Format state changes made by the ROM for this edit: word `+0x04` follows
the right-margin span because the default `[7436] - [742D]` gap is zero, and
word `+0x06` changes from `0x01C2` to `0x01C8`, preserving the default
10-space gap between the displayed right margin and paper width. This is useful
saved-file evidence for the fields, but it is also a reminder that Page Format
UI edits can update multiple serialized header words at once.

A direct `PAPER WIDTH` edit from `085` to `086`, stored as empty file `pw86`,
confirms the fourth serialized word independently:

```text
FF 10 3C 00 86 01 86 01 C8 01 84 00 0C 00 76 00 1E 00
```

Only word `+0x06` changed relative to the default header:
`0x01C2 -> 0x01C8`, the expected one-column `*6` delta. This separates the
paper-width field from the coupled right-margin edit above: when Paper Width is
edited directly, the margin span and indent/default threshold words remain
unchanged.

A direct `PAPER LENGTH` edit from `066` to `067`, stored as empty file `pl67`,
confirms the fifth serialized word:

```text
FF 10 3C 00 86 01 86 01 C2 01 86 00 0C 00 78 00 1E 00
```

Word `+0x08` changed from `0x0084` to `0x0086`, matching the expected doubled
line units (`66 * 2` versus `67 * 2`). Word `+0x0C` also changed from
`0x0076` to `0x0078`, which preserves the displayed six-line bottom margin
under the documented formula `([7423] - ([741F] + 2)) / 2`. The top-margin
word stayed `0x000C`.

A direct `TOP MARGIN` edit from `006` to `007`, stored as empty file `tm7`,
confirms the sixth serialized word:

```text
FF 10 3C 00 86 01 86 01 C2 01 84 00 0E 00 76 00 1E 00
```

Only word `+0x0A` changed relative to the default header:
`0x000C -> 0x000E`, again matching doubled line units. Paper length and the
bottom/body-limit complement remained unchanged.

A direct `BOTTOM MARGIN` edit from `006` to `007`, stored as empty file `bm7`,
confirms the seventh serialized word:

```text
FF 10 3C 00 86 01 86 01 C2 01 84 00 0C 00 74 00 1E 00
```

Only word `+0x0C` changed relative to the default header:
`0x0076 -> 0x0074`. This is the expected inverse two-unit delta from the
formula `[741F] = [7423] - bottom_margin*2 - 2`; increasing the displayed
bottom margin by one line decreases the stored body-end complement by two.
Paper length and top margin remained unchanged.

Do not treat the broader page-format/editor snapshot at `C772:8C8C`/`C772:8CF0`
as another spelling of this on-disk header. That snapshot copies a wider live
state block through `[73E0...]`: `[7438]`, `[7436]`, a third slot loaded from
`[7436]` but restored into `[742D]`, then `[741B]`, `[7423]`, `[7425]`,
`[741F]`, `[741D]`, `[7429]`, byte `[743A]`, `[7417]`, and `[73FB]`. The file
serializer `C772:82D6`, by contrast, writes the actual `[742D]` value and stops
after the seven words plus tab-stop table. This means the snapshot is useful
page-format evidence, but it is not an authoritative byte layout for stored WP
files.

The live editor flag byte `[742F]` is not part of this serialized header.
That matters for Word Wrap: the status renderer uses `[742F] & 0x02`, but
the native file header has no slot for that bit. A saved file can therefore
preserve wrapped text only indirectly as the resulting editor stream, not as a
recoverable Word Wrap preference. The bit is still used by formatter/runtime
paths, so its absence from the header should not be read as meaning the live
editor has no wrap state.

## Tab-Stop Table

The variable header tail is the individual tab-stop table described by the
T400 manual's Edit Text tab feature. It can hold up to 16 word entries, matching
the manual's stated maximum for individually set tabs. `C772:8C6B` builds this
table from a constant tab spacing by repeatedly adding a base step until the
position reaches `0x0324`, or 16 entries have been generated. A word whose high
byte is `0x80` terminates or marks unused entries.

The manual's Page Format screen also has a `TAB SPACE` setting for constant
tabs. The corresponding live scalar is `[743A]`: `C772:8C39` displays/edits it,
and `C772:8C62` calls `C772:8C6B` to regenerate `[7A20...]` when the value is
nonzero. That scalar is present in the broader in-RAM editor snapshot at
`C772:8C8C`/`C772:8CF0`, but it is not one of the seven words serialized by
`C772:82D6`, and it is not appended after the tab table. The native file
therefore stores the effective tab-stop table, not the original
constant-tab-spacing value as a separate field.

A controlled v3.1 Dreamulator sample confirms the on-disk form for constant
tabs. Setting Page Format `TAB SPACE` to `005` spaces and storing an otherwise
empty file as `ts5` produces this 48-byte payload:

```text
FF 2E 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00
1E 00 3C 00 5A 00 78 00 96 00 B4 00 D2 00 F0 00
0E 01 2C 01 4A 01 68 01 86 01 A4 01 C2 01 E0 01
```

The length byte `0x2E` is `0x0E + 0x20`: seven fixed header words plus all 16
two-byte tab stops. `TAB SPACE = 5` spaces becomes a `0x001E` internal-unit
step (`5 * 6`), and the generated table is:

```text
001E 003C 005A 0078 0096 00B4 00D2 00F0
010E 012C 014A 0168 0186 01A4 01C2 01E0
```

The live RAM table has the same 32 bytes followed by the `80 80` sentinel at
`[7A40]`. The stored file omits that sentinel.

Known table constructors:

| Routine | Effect |
| --- | --- |
| `C772:5C24` | Clears the table to just `8080h`. |
| `C772:5C37` | Seeds the table with `001Eh`, then fills the remaining bytes with `0x80`. |
| `C772:8C6B` | Generates up to 16 evenly spaced tab stops below `0x0324`. |

`C772:5C65` walks this table while rebuilding/formatting the editor stream.
For normal entries it emits spacing to the tab position, using `0x20` as the
queued character. This ties the table to ruler/tab formatting rather than to
the text body itself.

`C772:4ED4` is the editor command handler for individual tab edits; the
v3.1.260 equivalent starts at `C774:4EF3`. In this command context, byte `0xEE`
is TAB SET (`CTRL+5`). It rejects position zero, negative positions, and
absolute positions at or beyond `[7438] + [7415] >= 0x0324`; then it walks the
16-entry `[7A20...]` table, refuses duplicate entries or entries within six
internal units, opens a two-byte slot by shifting later entries toward
`[7A3F]`, stores the current relative position `[7415]`, and calls the ruler
rebuild helper (`C772:5C54` / `C774:5C73`). Byte `0xEF` is TAB CLEAR
(`CTRL+6`): it walks the same table,
finds the first tab stop at or to the right of `[7415]`, shifts following table
bytes left over it, and rebuilds the ruler. That matches the manual behavior.
These command bytes are not the same thing as stored body-stream marker records
`EE` and `EF`; the meaning depends on whether the byte is being handled as an
editor command or as serialized document content. The on-disk effect of
ordinary tab set/clear is the changed serialized header tail, not a literal body
record.

The same command handler also branches on `0xF1`, the editor command byte for
manual `CTRL+7` / INDENT. The traced branch is header/ruler-state oriented
rather than a literal body-byte insertion: it rejects positions at or beyond the
right-margin span `[7436]`, requires at least the manual's 10-space separation
from that right margin, records the command position in `[74B9]` and `[749F]`,
commits pending edit/range state through `C772:515E`, and rebuilds the ruler
via `C772:5C54`. `C772:515E` is not a simple literal record writer: it drains
pending range state `[7430]`, temporarily moves `[7415]` to the saved boundary
`[744C]`, may insert padding spaces, and invokes the lower reflow helpers. The
ruler rebuild `C772:5C65` emits internal/editor markers from these fields
(`0x29` at `[7436]`, and `0x27` at `[74B9]` when nonzero). The manual describes
indention as a temporary left margin and says the ruler `I` marker appears at
the indent position; that matches `[74B9]` as the live displayed marker.

A controlled v3.1 STORE sample pins down the same-line serialized form. In a
fresh document, entering five spaces, pressing `CTRL+7`, typing `abc`, and
storing as `ind1` produces:

```text
FF 10 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00
1E 00 20 20 20 20 20 E8 1E 00 00 00 E8 61 62 63
```

Before STORE, live RAM had `[74B9] = 0x001E`, exactly five spaces times six.
The saved header remained the default `FF 10 ... 1E 00`; `[742D]` stayed
`0x0186`. The indent command therefore materialized in this case as an `E8`
body record with operands `0x001E` and `0x0000`, followed by the indented text.
Right-margin Page Format edits still show `[742D]` moving with `[7436]`, so
that header word remains a persistent ruler/layout threshold, but it is not the
direct serialized storage for this simple `CTRL+7` indent marker.

A second sample follows the manual's normal set/clear flow: enter five spaces,
press `CTRL+7`, press Return, type `abc`, press Return, press `CTRL+8`, type
`def`, and store as `iclr`. It produces:

```text
FF 10 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00
1E 00 20 20 20 20 20 E8 1E 00 00 00 E8 0C 61 62
63 E8 00 00 1E 00 E8 0C 64 65 66
```

The first `E8` record is the indent-set line: word A is the new indent position
`0x001E`, word B is zero. The second `E8` record is the indent-clear line: word
A is zero, word B is the old indent position `0x001E`. The fixed header again
remains default.

`CTRL+8` / INDENT CLR returns editor command byte `0xF2`, but the v3.1 and
v3.1.260 searches have not found a matching command path analogous to the
`0xF1` indent-set branch. Exact `cmp al,0xF2` hits in C772/C774 are unrelated to
the editor command: the v3.1 hits at `C772:DB47` and `C772:E284` scan
`F2...F3` resource/string delimiters, and the `B0 F2` hit at `C772:A0DE` is in
a display/status script path. The inline VM scripts reinforce that negative
evidence: v3.1 has a `5C F1` compare-key operation at `C772:4136`, and
v3.1.260 has the same compare at `C774:4135`, but neither ROM has a `5C F2`
or `F2 5C` bytecode pair. Direct field-write checks found no dedicated
clear-indent reset. The nearby `[742D]` writes are the Page Format
right-margin gap-preservation path (`C772:500B` seeds the threshold and
`C772:503F` recomputes it after `[7436]` changes), while `[74B9]` is set by
the `F1` branch at `C772:4FC1` and zeroed by broader ruler cleanup paths:
tab/ruler-table constructors `C772:5C24` and `C772:5C37`, plus the general
nonzero-`[74B9]` cleanup at `C772:595D..596B`. The current working model is
that clear-indent is represented by returning the same positional state to its
non-indented value, not by a distinct literal `0xF2` body marker. The `iclr`
sample confirms the normal clear-line form as an `E8 0000 001E E8` record.

The live indent-marker field `[74B9]` is also not serialized directly. It is
zeroed by tab/ruler-table constructors `C772:5C24` and `C772:5C37`, both of
which rebuild the ruler through `C772:5C65`, and by the general cleanup path at
`C772:595D..596B` when `[74B9]` is nonzero. Other helpers update `[749F]` as
part of cursor/range snapshots
(`C772:1303`, `C772:5BD6`, `C772:7996`), but those are live editor snapshots
rather than header fields.

Decimal-tab paths do not store the `CTRL+TAB` command byte literally. Literal
command byte `0x07` is not one of the special bytes in the `C772:167D`
formatter scanner table, its classifier-table entry is zero, and the C772
literal searches found no command-handler compare analogous to the `F1` indent
branch. Earlier notes treated formatter state/index `0x07` as an `EE` producer,
but the v3.1 table decode corrects that: `C772:18C6` indexes
`C772:1542 - 1 + [7476]`, so state `0x04` maps to `EE`, while state `0x07`
maps to space (`0x20`). State `0x07` is still meaningful, though: `C772:183A`
preserves `[7476] == 7`, and when the formatter class in `[7477]` is `0x08`,
`C772:1850` runs a special adjustment sequence (`C772:5E35` mode `0x15`, width
measurement for `D7`, then `C772:5E35` mode `0x12` against `[7436]`). That
matches the manual's Decimal Tab behavior, where text before the decimal shifts
left and no-decimal text flushes right at the tab position. Current read:
Decimal Tab is a stateful formatter/reflow mode using ordinary spacing/range
records, not a distinct stored `0x07` body marker. A controlled v3.1
Dreamulator STORE sample named `dtab` confirms the saved form for
`CTRL+TAB`, `12.3`: after the default native header, the body is
`EE 12 00 00 00 EE 31 32 2E 33`. That is an `EE` spacing/range record followed
by the literal text `12.3`, with no literal `07` command byte.

## Serializer Path

The FILE menu document operation reaches `C772:7115` through bytecode opcode
`0xBE`. After file selection and directory-entry flag checks, the native
RECALL and STORE paths both converge on `C772:72BA`, which stores the operation
mode in `[7515]` and calls `C772:8046`.

| `[7515]` | User operation | `C772:8046` behavior | Thunk subservice |
| ---: | --- | --- | ---: |
| `0` | RECALL/load | Opens and reads the selected file, copies received bytes into the editor stream, then runs `C772:8340` to parse/restore or skip the native header according to the setup flag state. | `0x04` |
| `1` | STORE/save | Normalizes the current editor stream, serializes the native header with `C772:82D6`, then writes the resulting stream to the selected file. | `0x05` |

The same conversion spine is present in the newer v3.1.260 ROM with the
expected C774-bank address shift:

| Role | v3.1 | v3.1.260 |
| --- | ---: | ---: |
| Main RECALL/STORE stream converter | `C772:8046` | `C774:8045` |
| Serialized-header writer | `C772:82D6` | `C774:82D5` |
| Header parser / stream normalizer | `C772:8340` | `C774:833F` |
| Header word reader helper | `C772:8401` | `C774:8400` |
| Clear/reinitialize destination state | `C772:84F2` | `C774:84F1` |
| Thunk-A request builder | `C772:861B` | `C774:861A` |
| Chunk handoff helper | `C772:863C` | `C774:863B` |
| Incoming span calculator | `C772:87BF` | `C774:87BE` |
| Editor state snapshot restore | `C772:8976` | `C774:8975` |
| Chunk copy helper | `C772:8DA8` | `C774:8DA7` |
| Default tab-table builder | `C772:8C6B` | `C774:8C6A` |
| Line-layout normalizer | `C772:8A2F` | `C774:8A2E` |
| Current editor state snapshot | `C772:45A7` | `C774:45A6` |

The STORE setup path is:

```text
C772:7115 / STORE branch
  -> C772:8976        restore editor state snapshot selector [746A]
  -> C772:51E0        commit/normalize editor stream through inline bytecode
  -> C772:45A7        snapshot current editor state
  -> C772:72BA
     -> [7515] = 1
     -> C772:8046     document stream conversion
        -> C772:82D6  serialize the WP header
        -> C772:861B  build request record for subservice 0x05
        -> C772:863C  write chunks via thunk-A slot 6
```

`C772:82D6` first writes the header bytes into the forward editor-buffer side,
then copies them into the output side with the backward stream primitives. It
finally writes the length byte and then `0xFF` through `C772:3BFA`; because
that primitive writes backward, the file-order result is `FF length header`.
Before dispatching the filesystem request, the STORE mode sets `[7025]=1` and
`[7E17] |= 0x10`. It also copies `[740F]` to `[7489]`, then `C772:8782`
computes the number of bytes available for output from the editor-buffer
position fields. `C772:861B` builds the thunk-A request by storing the
subservice in `[7030]`, the selected-file parameter block pointer `72ACh` in
`[702C]`, the requested byte count in `[702E]`, and a seven-byte request
descriptor pointer/length in `[7027]`/`[7029]`. `C772:863C` then calls thunk-A
slot 6 and treats returned status `0x80` as a data-chunk handshake.

For STORE, `C772:8DA8` copies bytes from the editor buffer into the service
payload buffer returned by `C772:863C`, advances `[7489]` across editor buffer
pages, and accumulates the copied byte count in `[709B]`. The loop keeps
feeding chunks until `C772:863C` returns a non-`0x80` status. That final status
then drives the cleanup path: on success the remaining in-memory stream is
trimmed/moved, `[7020]` is cleared, and `C772:8340` runs in outgoing
normalization mode because `[7E17] & 0x10` is set.

The chunk handshake is count-word based, not sentinel based. `C772:863C` reads
the returned count word, caps the next handoff at `0x80` bytes, stores the
leftover count back through the same pointer, and advances `SI` to the payload
buffer immediately after the count word. In the local file service, that count
word is `[1006]` and the payload buffer is `[1008...]`. `C000:24C0` seeds
`[1006]` and `[160B]` from the requested byte count, returns status `0x80`,
then writes subsequent filled chunks from `[1008]` with `INT 21h AH=40h`.
Full 128-byte writes return another `0x80` handshake; a short final write
closes the file and returns success. Therefore a native edited file is
terminated by the filesystem byte count, not by an appended `0x1A`.

The `C000:60B0` call in the final-write path only emits a `0x1A` EOF block for
the DreamLink endpoint case (`[6F51] == 0x0A`). For a local native STORE it
returns success without writing an extra byte. Treat any DreamLink `0x1A` as a
transport EOF marker outside the edited-file payload, not as a body-stream
terminator.

The other `0x1A` handling in `C772:810C..812B` is RECALL-side cleanup. After
the service reports final status `0`, the loop is skipped when `[7025] == 1`
(STORE). Otherwise it walks the remaining backward stream bytes, copies any
nonzero byte other than `0x1A`, and decrements `[709B]` for stripped NUL/`0x1A`
bytes. This is how imported or transport-padded input is trimmed before the
final `C772:8340` conversion; it is not evidence that native STORE appends an
EOF byte.

The RECALL setup path is the inverse:

```text
C772:7115 / RECALL branch
  -> C772:8976        restore editor state snapshot selector [746A]
  -> C772:51E0        prepare/clear destination stream state
  -> C772:45A7        snapshot current editor state
  -> if text exists, prompt:
       INS byte 0x0D    -> insert path
       ENTER byte 0xDA  -> C772:84F2 clear/reinitialize path
  -> C772:72BA
     -> [7515] = 0
     -> C772:8046
        -> [7E17] &= ~0x10
        -> C772:51E0
        -> if CF clear: [7E17] |= 0x10, C772:45A7, C772:8976
        -> if CF set: fall through with [7E17] bit 0x10 clear
        -> C772:861B  build request record for subservice 0x04
        -> C772:863C  read chunks via thunk-A slot 6
        -> C772:8340  final stream conversion using the resulting [7E17] state
```

The matching reader/converter is `C772:8340`. With `[7E17] & 0x10` clear, it
recognizes `0xFF`, parses the length/header, restores the seven state words,
and rebuilds the `[7A20]` table. With `[7E17] & 0x10` set, it treats `0xFF`
as a header to skip while converting/normalizing the outgoing stream rather
than restoring the state fields. If the incoming stream does not start with
`0xFF`, `C772:8340` writes the first byte back into the stream and seeds a
default tab table through `C772:8C6B(0x30)`, so pre-header/plain legacy payloads
still load as editor streams.

When `[7E17] & 0x10` is set and a skipped header is not immediately followed by
an `EC` record, `C772:8340` injects a default `EC 02 02 EC` state record before
continuing. The byte after the skipped header is not discarded: `C772:8367`
reads it, writes it back with `C772:3BFA` when it is not `EC`, emits the default
pitch record, then continues with that saved byte still in the stream. If the
next byte is already `EC`, the converter just writes that `EC` back and does not
inject another record. This is a conversion/normalization artifact of the
load/store path, not a required extra field in the leading file header.

For RECALL, `C772:87BF` computes the expected incoming span from `[7576]` and
returns `max([7576] - 6, 0) * 0x7C`, matching the editor-buffer page payload
span. `C772:861B` uses subservice `0x04`; each `C772:863C` status `0x80`
response returns a pointer to a count word followed by payload bytes.
`C772:863C` caps the handed-off count at `0x80`, stores any leftover count back
through the returned pointer, and advances `SI` to the payload. `C772:8DA8`
then copies the returned bytes into the forward editor-buffer side
(`[740D]`/`[7411]`), allocating another buffer page with `C772:3A92` when that
side reaches its `0x7C` byte page limit, and accumulates the received byte
count in `[709B]`. After the service reports a final non-`0x80` status, the
success path copies any remaining non-NUL, non-`0x1A` bytes, rewinds the
moved-byte count, and calls `C772:8340`. The traced setup does not leave
`[7E17] & 0x10` unconditionally clear here: if the preparatory `C772:51E0`
call returned CF clear, `C772:8046` set bit `0x10` again before the service
loop, so the final converter skips a leading native header instead of parsing
it. If that preparation path returns CF set, the bit remains clear and the same
converter parses the header. This matches the manual's user-visible split:
ordinary RECALL after clearing the current work text automatically applies the
recalled file's page format, while INSerting a recalled file into existing text
ignores the recalled file's page format.

There is also a separate legacy/plain-payload path before the final
`C772:8340` header parser. During the first `0x80` data-chunk handshake,
`C772:80F2..8102` tests the first returned payload byte while `[7020] & 0x01`
is still set. If that first byte is not `0xFF`, it sets `[7020] & 0x02`.
After the read finishes, the success cleanup at `C772:8151` sees that bit and
runs `C772:81AF` instead of copying the received bytes unchanged. That filter
accepts tabs and bytes `0x20..0xDF`, drops other C0 controls and bytes
`>= 0xE0`, and converts CR and LF to the editor separator byte `0x0C` while
collapsing a CR/LF pair to one separator through `[7020] & 0x04`. A second pass
at `C772:81F8` tracks eight-column tab stops in `[7021]`; when it encounters a
tab and the editor has a nonzero page/buffer span in `[7576]`, it emits spaces
up to the next stop. The v3.1.260 equivalent plain-payload filter starts at
`C774:81CE`. Current read: a recalled file whose first byte is not `FF` is
treated as legacy/plain text and normalized into an editor stream before the
usual `C772:8340` default-header path seeds the tab table.
`tools/decode_wp_payload.py --legacy-preview` mirrors this byte filter for
captured non-`FF` payloads; `--legacy-expand-tabs` enables the eight-column tab
expansion used by the second pass when the live editor span is nonzero.

The key-code evidence for that mapping is in `C772:7115`: after the "text
exists" prompt, byte `0x0D` (physical `INS`, from the `C000:3887` unshifted
keyboard table) jumps directly to `C772:7181`, while byte `0xDA` (physical
`ENTER`/Return) calls `C772:84F2` and `C772:7197` before continuing through
`C772:7189`. `C772:84F2` resets/reinitializes the current editor state: it
selects the default tab/page-format setup through `C772:5C37`, clears
`[7D76]`, snapshots state, and runs a fixed sequence of state-update helpers.
That makes the static mapping: insert recall leaves current text/format state
in place and later skips the recalled file header; clear/replace recall
reinitializes the work text first, then lets the final converter parse the
recalled file header. A live Dreamulator RECALL sample named `TS5` confirms the
clear/replace path: after recalling a 48-byte native file whose header length is
`0x2E`, RAM held `[7438]=003C`, `[7436]=0186`, `[742D]=0186`, `[741B]=01C2`,
`[7423]=0084`, `[7425]=000C`, and `[741F]=0076`. The saved 32-byte tab table
was restored at `[7A20]` as:

```text
1E 00 3C 00 5A 00 78 00 96 00 B4 00 D2 00 F0 00
0E 01 2C 01 4A 01 68 01 86 01 A4 01 C2 01 E0 01
80 80
```

The trailing `80 80` is the runtime sentinel appended by the reader; it is not
part of the serialized 48-byte file payload.

The byte movement between the converter and the filesystem layer is through
the C000 thunk-A service dispatcher, not through the DEF0 organizer database
helpers. `C772:861B` builds a request record at `7030` from the current
converter command, source/destination buffer, and byte count; `C772:863C`
calls thunk-A slot 6 and treats returned status `0x80` as a chunked data
handshake. The chunk can be shorter than 128 bytes; `0x80` is the maximum
count handed to the converter for one iteration.
The service record is interpreted by `C000:2295`, whose subservices include
normal INT 21h file open/read/write/close operations. For native recall/store,
the important subservices are:

| Subservice | Handler | Disk operation | Notes |
| ---: | --- | --- | --- |
| `0x04` | `C000:2417` | Open + read | Builds `drive:name`, opens with `AH=3Dh`, reads 128-byte chunks with `AH=3Fh`, returns a pointer to the count at `[1006]` and status `0x80` for data chunks. |
| `0x05` | `C000:24C0` | Create/open + write | Creates with `AH=3Ch` or opens with `AH=3Dh` for DreamLink endpoint `0x0B`, returns `[1006]`/`[1008]` handoff buffers with status `0x80`, writes full 128-byte chunks with `AH=40h`, and closes once the final short chunk is written. Local native STORE does not append a payload `0x1A`; DreamLink EOF is a transport marker. |
| `0x07` | `C000:2798` | Text export | Creates a text file and writes a filtered text view of the editor stream. |
| `0x08` | `C000:29A5` | Text import | Opens a text file and feeds translated characters/control markers into the editor path. This path is useful evidence for persistent body control-record widths. |
| `0x09` | `C000:2B82` | Finish/EOF helper | Sends an output `0x1A` and closes/finishes the transfer path. |
| `0x0B` | `C000:2B90` | Handshaked transfer read/send | Uses 128-byte file reads plus endpoint `AH=03h/04h` handshaking. |
| `0x0C` | `C000:2C85` | Handshaked transfer receive/write | Creates a file, receives 128-byte blocks over endpoint `AH=04h`, validates block/checksum bytes, and writes with `AH=40h`. |

## Body Stream

The body after the header is the editor stream consumed by the C772 text-buffer
primitives:

| Routine | Direction | Purpose |
| --- | --- | --- |
| `C772:3BB6` | forward read | Reads bytes from the editor stream. |
| `C772:3BD8` | backward read | Reads bytes from the opposite editor-buffer side. |
| `C772:3C2D` | forward write | Writes bytes into the forward side. |
| `C772:3BFA` | backward write | Writes bytes into the output/prepend side. |

The parser is stateful. `C772:5E35` is the common scanner setup path; it
saves the current native editor state, points `[710F]` at the marker staging
buffer `[74E5...]`, snapshots `[745F]`, `[7460]`, `[7407]`, `[7417]`,
`[744A]`, and `[7415]`, then walks the stream. Parsed marker bytes are exposed
as:

| Address | Role while scanning |
| --- | --- |
| `[74B5]` | Current marker/key byte. The VM has direct tests for `E9` and `EF`. |
| `[74E5]` | Staging-buffer marker byte when builders create a record before feeding it back through the scanner. |
| `[74E6]` | First operand slot. For `E9`/`EF`, this is the subtype byte used by dispatch/test paths. |
| `[74E7]` | Next operand byte. For `E9`, this is the low byte of the builder's `DX` word; for `EF`, it is the low byte of the vertical line-position word. |
| `[74E8]` | Next operand byte / saved span position for multi-word records. For `E9`, this is the high byte of the builder's `DX` word; for `EF`, it is the high byte of the vertical line-position word. |
| `[74E9]` | Next operand byte. For `E9`, this is the closing marker byte; for `EF`, this is the signed `[7433]` accumulator byte. |
| `[74EA]` | For `EF`, this is the sign extension of `[74E9]` (`00` or `FF`). |
| `[74EB]` | For `EF`, this is the closing marker byte. |

For the shared `E9` builder specifically, these slots are byte-aligned as the
on-disk record: `C772:5279` writes `[74E5]=E9`, `[74E6]=subtype`, the incoming
`DX` word to `[74E7..74E8]`, and `[74E9]=E9`. The v3.1.260 builder at
`C774:5278` has the same shape. `trace-full.txt` stops the preceding block at
the `RET` at `C772:5278`, so this builder is easiest to verify from the raw ROM
bytes or by disassembling from `C772:5279` directly:

```text
C772:5279  lahf
C772:527A  mov si,74E5
C772:527D  mov word [si],00E9  ; [74E5]=E9, [74E6]=00 until subtype write
C772:5281  inc si
C772:5282  mov [si],al         ; subtype
C772:5284  inc si
C772:5285  mov [si],dx         ; operand word
C772:5289  mov dl,E9
C772:528B  mov [si],dl         ; closing marker
C772:528E  call C772:5E1E      ; feed staged marker through scanner/writer
```

The confirmed `EF 06` producer writes the longer shape directly:
`[74E5]=EF`, `[74E6]=06`, `[74E7..74E8]=[7417]`,
`[74E9]=[7433]`, `[74EA]=sign([7433])`, and `[74EB]=EF`.

Current confirmed body markers:

| Byte | Evidence | Current read |
| ---: | --- | --- |
| `0x0C` | Observed stored test files; WP communicate/export paths also treat it as a hard-return/form-feed-like document separator. | Line/document separator in the editor stream. |
| `0x1A` | `C772:810C..812B` suppresses copying `0x1A` and NUL only in the non-STORE final cleanup path (`[7025] != 1`) after the service reports success. DreamLink can also carry a transport EOF block outside the native file payload. | EOF/control padding marker for import/transport cleanup, not a native STORE terminator and not ordinary display text in that branch. |
| `0xC0..0xCA` | `C772:2EE8` uses the frame glyph/mask table at `C772:2EC4..2ED9`. A controlled `fram` STORE sample after drawing with framing mode contains glyph bytes `C4`, `C8`, and `C6` in the saved body, with no literal `18`. An isolated `CTRL+V` / Vertical Line sample stores `C6` after an `EE 0000 0000 EE` range record. | Framing/line/corner glyph bytes. Decode through the frame table below when they occur as ordinary body glyphs; the vertical-line command can materialize as glyph `C6`, not as literal command byte `D4`. |
| `0xD6` | The classifier table entry is ordinary glyph class `0x0500`, but the layout scanner has an explicit separator/boundary exception: `C772:2420` compares `CH` with `DB`, then `D6`, and accepts either before the byte-copy path at `C772:2486`; v3.1.260 mirrors this at `C774:241F`/`C774:2423`/`C774:2485`. Targeted searches found no matching late-ROM literal-`D6` body writer/builder shape. A controlled `CTRL+E` / Page End STORE sample does **not** store literal `D6`; it stores `E9 02 0C 00 E9`. | Parser-recognized boundary byte or synthetic/display boundary case, not the normal saved form of the Page End command in the tested path. |
| `0xDB` | `C000:29A5` converts it to CR/LF through the same path as `0x0C`. | Alternate line/document separator in text conversion. |
| `0xE4` | Controlled v3.1 Dreamulator STORE samples for a one-character centered line (`cent`) and a one-character right-flush line (`rfls`) store runs of `E4` before the final `61` byte, with no literal `1E`, `19`, or `1F` marker in the saved body. `C000:29A5` does not assign `E4` a fixed-width record shape and strips it singly in text conversion. | Alignment fill byte materialized by formatter/STORE output. Not a structured high-byte record. |
| `0xE8` | The text reader/import conversion path `C000:29A5` recognizes it as a persistent control record and skips five following bytes. Two executable late-ROM producers stage it through the shared record helper: `C772:0B61 -> C772:507D` and `C772:0CDB -> C772:507D`; the v3.1.260 equivalents are `C774:0B60 -> C774:507C` and `C774:0CDA -> C774:507C`. `C772:680B`/`C774:680A` handle the parsed record as a saved endpoint marker using `[74E8]`, `[7434]`, `[7419]`, and `[7427]`. The v2.1 redraw path names the equivalent handler as a saved-start/span update. Controlled indent STORE samples emit `E8 1E 00 00 00 E8` for set and `E8 00 00 1E 00 E8` for clear. | Multi-byte saved span/start endpoint checkpoint. The `ind1`/`iclr` samples confirm one user-facing producer: INDENT/INDENT CLR stores the new/old indent positions in this record. |
| `0xE9` | `C000:29A5` skips four following bytes. `C772:5279` stages `E9 subtype <DX word> E9`; `C772:665A` dispatches it through a subtype table at `C772:66C1`; the VM interpreter also has a dedicated test for `[74B5] == E9` and compares the subtype byte in `[74E6]`. Other formatter branches explicitly special-case subtypes `0x02` and `0x06`. A controlled `CTRL+E` / Page End sample stores `E9 02 0C 00 E9`; the combined `low2` sample stores the same subtype as `E9 02 0E 00 E9` after preceding vertical-line layout output. | Multi-byte subtype-dispatched layout/control event with a context-dependent little-endian layout/span operand. The subtype values are byte offsets into a jump table, and confirmed stored values are even-coded. Subtype `0x02` is now tied to at least one user-facing producer: Page End, but the operand word is not a fixed Page End constant. |
| `0xEA` | `C772:37FB` / `C774:37FA` is a VM text-buffer opcode that writes byte `EA` through the forward stream writer. The EC/ED rewrite loop writes the same delimiter at `C772:3FD9` / `C774:3FD8`; the style/display rewrite loop writes it at `C772:4051` / `C774:4050` before scanning/copying a formatting run until `EB`. The text conversion path `C000:29A5` does not assign it a fixed-width record shape; it strips unrecognized high bytes singly. | Single-byte formatter run/scratch delimiter that can exist in the editor stream, but not a fixed-width document record. |
| `0xEB` | `C772:364B` / `C774:364A` searches for `EB` with scan mode `0x23`, and the `C772:3FC9` / `C774:3FC8` and `C772:4011` / `C774:4010` rewrite loops stop when the scanner returns `DL == EB`. A raw `mov al,EB` exists in the C772 output/translation path at `C772:C4BD -> C772:D4C9`, but no matching editor-buffer delimiter writer has been found in the late-ROM formatter stream paths; the in-place builder patterns `C6 04 EB` and `C7 04 EB 00` are also absent. `C000:29A5` strips it singly rather than treating it as a record with operands. | End delimiter for formatter runs, paired operationally with `EA`; not a fixed-width document record. |
| `0xEC` | `C772:6507` emits a four-byte `EC old new EC` record for `[7460]` changes; after a skipped header, `C772:8340` special-cases `0xEC` and injects a default `EC 02 02 EC` record when one is absent. `C772:9F72` displays the saved value through the status pitch table `PS`, `10`, `12`, `BF`. | Character pitch state-change record. |
| `0xED` | `C772:64FE` emits a four-byte `ED old new ED` record for `[7407]` changes. `C772:A030` renders the saved value as line spacing by shifting it right and using the low bit as the half-line marker. | Line-spacing state-change record. |
| `0xEE` | `C000:29A5` skips five following bytes and has special handling that can emit spaces based on two stored word values. `C772:505F` builds one concrete `EE <DX> 0000 EE` form; `C772:18FA` and `C772:A5EA` also stage `EE` records through the formatter stream helper. The formatter class table at `C772:1542` maps state/index `0x04` to `EE`, and `C772:18C6` emits that as an `EE` record. `C772:6913` treats parsed records as range/boundary markers, asserts pending range state in `[7430]`, and updates `[74E8]`, `[744C]`, and `[744E]`. The `fram` sample includes `EE 24 00 24 00 EE` and `EE 24 00 00 00 EE` between stored frame glyphs. The `dtab` sample stores `CTRL+TAB`, `12.3` as `EE 12 00 00 00 EE 31 32 2E 33`, tying Decimal Tab to this record family. | Multi-byte range boundary/spacing control record. Used by framing STORE output as ordinary layout/range state around inserted glyphs and by Decimal Tab output as a spacing/range record before the typed number. |
| `0xEF` | `C000:29A5` skips six following bytes. `C772:6139` / `C774:6138` emits `EF 06 <line-pos-word> <signed-byte> <sign-extension> EF` after advancing `[7417]` by current line spacing `[7407]` and crossing the printable body-end threshold `[741F]`; it carries the new `[7417]`, `[7433]`, and a sign-extension byte for `[7433]`. The parser dispatches subtype values through `C772:69D8` / `C774:69D7`, and the VM interpreter has a dedicated test for `[74B5] == EF` with subtype comparison through `[74E6]`. The `efpg` STORE sample with 70 hard-returned `x` lines contains only repeated `78 0C` body pairs and no `EF`, so ordinary typed hard returns past the page body are not enough to produce this record. | Multi-byte vertical formatter/body-boundary continuation record. The confirmed producer emits subtype `0x06`; the dispatch table also consumes subtypes `0x00`, `0x02`, and `0x04`. Exact UI names still open. |
| `0xF0..0xFF` | `C772:65CA`/`C772:6611` emit single-byte markers when bits in `[745F]` change. Existing interpreter notes call `[745F]` display flags. | Native WP display/style toggle markers. These are not the same byte values as C000 display-renderer escapes; renderer/printer paths translate this editor state later. |
| `0xFF` | Header marker at file start; also reachable as the style clear/end marker for `[745F]` bit 7 inside the body stream. | Context-sensitive: header escape only at the stream start when followed by a nonzero length. |

The `EC`/`ED` records are emitted by `C772:6515`:

```text
<kind> <old-value> <new-value> <kind>
```

where `<kind>` is `EC` or `ED`. The parser paths around `C772:3FC9` and
`C772:3FAE` scan these records and update `[7460]` or `[7407]` respectively.

`EA`/`EB` are different from the fixed-width records. The late-ROM formatter
uses `EA` as a single-byte start delimiter for scratch/rewrite runs and scans
until `EB`; decoding a stored file should therefore treat either byte as a
single control byte unless reconstructing the live editor buffer's formatter
scratch state.

The fixed-width multi-byte records now have confirmed byte shapes:

| Marker | File bytes | Producer/consumer evidence |
| ---: | --- | --- |
| `0xE8` | `E8 <word-a> <word-b> E8` | `C000:29A5` confirms the five-byte payload width; `C772:0B61` and `C772:0CDB` stage `E8` records through `C772:507D`, with v3.1.260 equivalents at `C774:0B60`, `C774:0CDA`, and `C774:507C`; `C772:680B`/`C774:680A` consume the two word slots through `[74E6]`/`[74E8]` and update saved endpoint fields. Emulator STORE samples confirm `E8 1E 00 00 00 E8` for a five-space `CTRL+7` indent marker and `E8 00 00 1E 00 E8` for the corresponding `CTRL+8` clear line. |
| `0xE9` | `E9 <subtype> <word> E9` | `C772:5279` builds this exact layout by writing the subtype byte followed by the incoming `DX` word; `C772:665A` dispatches on the subtype byte at `[74E6]`. The equivalent v3.1.260 builder is `C774:5278`. Emulator STORE sample `pend` confirms `CTRL+E` / Page End as `E9 02 0C 00 E9`; `low2` confirms the same Page End subtype can carry a different word (`0x000E`) after preceding layout output. |
| `0xEC` | `EC <old> <new> EC` | `C772:6507`/`C772:6515` emit this for `[7460]` changes; emulator STORE sample `pitc` confirms the four-byte shape. |
| `0xED` | `ED <old> <new> ED` | `C772:64FE`/`C772:6515` emit this for `[7407]` changes; emulator STORE sample `line` confirms the four-byte shape. |
| `0xEE` | `EE <word-a> <word-b> EE` | `C772:505F` builds `EE <DX> 0000 EE`; `C772:18FA` and `C772:A5EA` stage additional `EE` records; `C772:1542` maps formatter state/index `0x04` to `EE`; `C000:29A5` treats the two words as spacing positions and may emit `(word-a - word-b) / 6` spaces. Emulator STORE samples confirm `EE 12 00 00 00 EE` before `12.3` for Decimal Tab and `EE` records around frame/line glyph output. |
| `0xEF` | `EF 06 <line-pos-word> <signed-byte> <sign-extension> EF` | `C772:6139` emits subtype `0x06`, the updated vertical position `[7417]`, byte `[7433]`, and `00`/`FF` as the sign extension of `[7433]`; the v3.1.260 equivalent is `C774:6138`. `C772:69E0` consumes the record as seven bytes during directional scans and restores `[7433]` from the final operand byte when unwinding the span. The negative `efpg` sample confirms this is not the normal encoding for a long sequence of explicit hard returns. |
| `0xF0..0xFF` | `<marker>` | Single-byte `[745F]` style toggles, not fixed-width records: set/start for bit `n` is `F0 + 2n`; clear/end is `F1 + 2n`. |

External decoders should consume only the fixed-width records listed above as
multi-byte units. `EA`, `EB`, and style markers are single-byte controls, while
bytes `0x20..0xDF` are display/glyph bytes only when a formatter/control path
does not claim them. For record validation, the last byte of an `E8`, `E9`,
`EC`, `ED`, `EE`, or `EF` record should match the opening marker; for the
confirmed `EF 06` producer, the sign-extension byte is `00` when the signed
accumulator byte is nonnegative and `FF` when it is negative. Unknown `E9` or
`EF` subtype values should be reported as unknown subtype records, not decoded
as plain text.

`tools/decode_wp_payload.py --strict --require-native` implements these checks
for native STORE captures: malformed native headers, truncated fixed-width
records, mismatched closing marker bytes, and invalid `EF` sign-extension bytes
make the command exit nonzero. Omit `--require-native` for RECALL captures that
may legitimately take the legacy/plain path.

### Position/Range Records

`E8` and `EE` are the two fixed-width positional records. They are dispatched
directly by `C772:6634` before the `E9`/`EF` subtype tables, so their marker
bytes are top-level stream records rather than subtype events.

`E8` is best described as a saved span/start endpoint record. In forward scans,
`C772:680B` writes the record's second word operand (`[74E8]`) into `[7434]`
and `[7427]` depending on scan flags, then copies the first word operand
(`[74E6]`) into `[7419]`. In reverse or rebuild scans it can instead restore
`[74E8]` from the current `[7434]` or saved `[7419]`. The v3.1.260 handler at
`C774:680A` is the same logic with the expected one-byte address shift.

The two executable late-ROM producers are both internal position checkpoints.
`C772:0B61` stores the current `DX` in `[7419]` before staging `E8`, while
`C772:0CDB` stages `E8` from `SI`, then records `SI` as both `[7419]` and
`[7434]` before refreshing `[749F]` through `C772:504A`. Direct-call scans to
the shared helper also find a `C772:4FE1` / `C774:4FE0` byte pattern, but that
hit is inline interpreter data after a `C772:22D` / `C774:22C` VM call, not an
executable producer. This makes `E8` a cursor/span endpoint checkpoint used
while moving through formatted text, not ordinary body text. The `ind1` sample
also confirms that manual INDENT (`CTRL+7`) and INDENT CLR (`CTRL+8`) serialize
to this record. Five spaces followed by `CTRL+7` produced
`E8 1E 00 00 00 E8`, carrying the live indent marker `[74B9] = 0x001E`. In the
manual set/clear flow, `CTRL+8` later produced the inverse
`E8 00 00 1E 00 E8`.

`EE` is the corresponding range boundary/spacing record. `C772:6913` marks
the scan state with `[745D] |= 0x41`, can set `[7430]` to `0xFF` or `0xFE`
for directional pending-range cases, and records the active boundary words in
`[744C]` and `[744E]`. The text-import conversion path has independent
evidence for the spacing role: after collecting an `EE` record, `C000:29A5`
computes `(word-a - word-b) / 6` and emits that many ASCII spaces when the
difference is positive.

The pending-range machinery remains relevant for more complex layout cases.
When `[7430]` is nonzero and a `C772:5E35` mode permits cursor/range handling,
the dispatcher can synthesize an `EE` marker event in `[74B5]` and enter the
normal marker-dispatch tail instead of copying a literal command byte. However,
the controlled `ind1` and `iclr` samples show that normal `CTRL+7`/`CTRL+8`
set/clear lines are not serialized through `EE` and do not update the fixed
header: they write `E8` saved endpoint records carrying the new and old indent
positions. Current read: indention set/clear lines use existing positional
records and ruler state, not distinct stored `F1`/`F2` command markers; more
complex after-the-fact reflow cases may still involve the `EE` range-boundary
machinery.

The formatter class table at `C772:1542` is another important `EE` producer
hint, but it also explains why Decimal Tab is not a literal byte. `C772:18C6`
indexes that table as `C772:1542 - 1 + [7476]`: state `0x01` maps to `0C`,
state `0x02` to space, state `0x03` to `D1`, state `0x04` to `EE`, state
`0x05` to `2D`, state `0x06` to `DB`, and state `0x07` back to space. If the
emitted byte is `EE`, `C772:18FA` stages an `EE` record using the saved boundary
in `[744E]`. `C772:167D` scans a six-byte special-character set (`0C`, space,
`D1`, `EE`, `2D`, `DB`), indexes the formatter transition table at
`C772:1549`, and then dispatches through the action table at `C772:1756`.
The action at `C772:17B2` loads `AL=07` and stores it in `[7476]`; on the next
`C772:18C6` emit path that state maps to a space, but `C772:183A` deliberately
does not clear `[7476]` when it is `7`.

The preserved state-7 path has its own right-alignment branch. If `[7477]` is
`0x08`, `C772:1850` calls `C772:5E35` with `CL=0x15`, measures/classifies
glyph `D7` via `C772:25DE`, computes a distance from the right-margin span
`[7436]`, and calls `C772:5E35` again with `CL=0x12`. The manual says Decimal
Tab shifts typed digits left until a decimal point lands at the tab stop, and
also works as a flush-right tab when no decimal point is typed. The ROM behavior
matches that stateful alignment model. The literal `0x07` command byte from
the keyboard table is therefore best treated as an editor command source only;
it has no confirmed body-parser role. The isolated `dtab` STORE sample confirms
the practical saved form for `CTRL+TAB`, `12.3`: the body starts with
`EE 12 00 00 00 EE` and then stores the literal ASCII bytes `31 32 2E 33`.

### Low-Byte Layout Controls

Several manual formatting commands use bytes below the high-byte record range.
They must be interpreted in editor/layout context, not as ordinary glyphs:

| Byte | Manual/input source | Current file-format evidence |
| ---: | --- | --- |
| `0x07` | Decimal Tab (`CTRL+TAB`) | Editor command byte confirmed by the keyboard table. Negative evidence: literal `0x07` is not in the `C772:167D` special scanner set, its classifier-table entry does not directly emit a persistent control, and no C772 command-handler compare for `0x07` has been found. Formatter state/index `0x07` maps to space, not `EE`, but it is preserved and has a special `[7477] == 0x08` adjustment branch through `C772:1850` that aligns against `[7436]`. The `dtab` STORE sample confirms the saved body uses an `EE` spacing/range record followed by the typed number, not a stored `0x07` marker. |
| `0x18` | Framing (`CTRL+9`) | Confirmed as a live editor command/mode path. `C772:13A8` compares the queued byte with `0x18` and calls `C772:2EE8`; that helper sets `[7D4B] |= 0x01`, computes frame connection masks from the glyph at the cursor and neighboring frame glyphs, translates the resulting mask back to a stored line/corner glyph through the table seeded at `C772:2EC2` with pairs at `C772:2EC4..2ED9`, and writes through the normal edit/update helpers (`C772:48C2`, `C772:55E9`, `C772:48CC`, `C772:515E`). No parser path has been found that treats literal body byte `0x18` as a persistent frame marker. Controlled saved-file evidence agrees: the `fram` sample stores frame glyph bytes plus `EE` layout records, with no literal `18`. Current read: `0x18` enables/updates framing mode, while the stored stream contains the resulting line/corner glyph bytes and normal layout records. |
| `0x1E` | Center (`CTRL+C`) | Formatter/output paths recognize it as a layout control and map it to byte `0x52` in the staged annotation/output stream (`C772:6223`, `C772:A725`). A controlled v3.1 STORE sample with `CTRL+C`, `a` does not save a literal `1E`; it saves alignment fill (`E4` repeated) followed by `61`. Current read: `0x1E` is an editor/layout command marker, while STORE can materialize the resulting centered line as fill plus text. |
| `0x1F` | Right-flush formatter/output marker | Formatter/output paths recognize it beside `0x1E` and map it to byte `0x72` (`C772:6223`, `C772:A725`; v3.1.260 equivalents `C774:6266`, `C774:A77D`). `C772:1E57` / `C774:1E56` also set `[745D]=0x1F` from an internal local branch, and the main scanner path at `C772:225E` / `C774:225D` explicitly accepts `CH == 0x1F` or `CH == 0x1E` before calling the annotation/output builder. The keyboard control table at `C000:3A17` confirms `CTRL+R -> 0x19`, but exact C772/C774 literal searches found no `mov al,0x19` or `cmp al,0x19`, the C772 VM bytecode has no `5C 19` compare-key operation, and the classifier table gives `0x19` a zero entry rather than the special `0x70` class used by `0x1E`/`0x1F`. A live Dreamulator check after `CTRL+R` on an empty line showed the runtime handoff had occurred: the visible cursor moved to column 75, byte `[745D]` was `1F`, and the current/staged byte `[74B5]`/`[74E5]` was `E4` alignment fill. A controlled v3.1 STORE sample with `CTRL+R`, `a` saves alignment fill (`E4` repeated) followed by `61`, with no literal `19` or `1F` body byte. Static evidence does not show a direct `0x19` body/parser consumer; the known route is through formatter/scanner state, with `C772:17B7..1850` selecting the right-align adjustment path (`[7477] == 08`) and `C772:1E57` later writing `[745D]=1F` from a layout-table branch. For file decoding, neither `0x19` nor `0x1F` is the ordinary saved form. |
| `0xD1` | Syllable hyphen (`CTRL+H`) | Controlled STORE sample `hyph` confirms direct storage: typing `a`, `CTRL+G`, `b`, `CTRL+H`, `c` stores body bytes `61 D8 62 D1 63`. Formatter paths treat `D1` as a special hyphen marker, skip it in word-breaking scans, and can convert it to `0xD7` before output (`C772:A302`, `C772:A36C`, `C772:A498`, `C772:2200`). |
| `0xD4` | Vertical-line command byte (`CTRL+V`) | The normal classifier treats byte `0xD4` as an ordinary glyph-class byte: `C772:25DE` indexes table `C772:7C02`, whose `0xD4` entry at `C772:7DAA` is `0x0500`, not a special layout class. Targeted late-ROM searches found no common C772/C774 command-handler or body-writer shape for literal `D4`: no `5C D4` VM compare-key pair, no `cmp al,D4`, no `mov al,D4`, and no in-place `D4` builder pattern. The isolated `CTRL+V` STORE sample does **not** store literal `D4`; it stores `EE 00 00 00 00 EE C6 0C`. Current read: treat `D4` as the input command byte only. The tested saved-file path materializes the command as frame/line glyph `C6` plus normal range/separator records. |
| `0xD6` | Page-boundary scanner byte; Page End input command byte (`CTRL+E`) | The classifier table entry for `D6` is also `0x0500`, and the layout scanner has an explicit exception for page boundaries: `C772:2420` accepts `CH == DB` or `CH == D6`, then falls through to the byte-copy path at `C772:2486`; v3.1.260 has the same exception at `C774:241F`/`C774:2423` before the copy at `C774:2485`. Targeted late-ROM searches found no common literal-`D6` stream builder shape. The isolated `CTRL+E` STORE sample does **not** store literal `D6`; it stores `E9 02 0C 00 E9`. Current read: `D6` is a parser-recognized boundary byte, but the normal tested Page End command serializes as an `E9` subtype-`0x02` record. |
| `0xD7` | Formatter-emitted hyphen marker | In the hyphen-class predicate with `0xD8` and ASCII `-` (`C772:D53E`), and used as the formatter/output replacement for `0xD1`. |
| `0xD8` | Required hyphen (`CTRL+G`) | Controlled STORE sample `hyph` confirms direct storage: typing `a`, `CTRL+G`, `b`, `CTRL+H`, `c` stores body bytes `61 D8 62 D1 63`. `D8` is in the same hyphen class as `0xD7` and ASCII `-` (`C772:D53E`), but unlike `D1` it is already the required-hyphen stored body byte rather than a formatter-emitted replacement. |

The framing command helper has a concrete glyph table. `C772:13A8` dispatches
command byte `0x18` to `C772:2EE8`; that routine seeds its scan at
`C772:2EC2`, then uses the paired table at `C772:2EC4..2ED9` to convert
between stored frame glyph bytes and a four-bit connection mask. The zero at
`C772:2EDA` terminates the scan:

| Glyph | Mask |
| ---: | ---: |
| `C0` | `03` |
| `C1` | `0B` |
| `C2` | `0E` |
| `C3` | `07` |
| `C4` | `0A` |
| `C5` | `0F` |
| `C6` | `05` |
| `C7` | `0D` |
| `C8` | `0C` |
| `C9` | `09` |
| `CA` | `06` |

The same helper scans a 13-byte directional/edge set at `C772:2EDB..2EE7`
(`00`, `11`, `10`, `13`, `12`, `DF`, `DC`, `0F`, `0E`, `FD`, `FE`, `DE`,
`DD`). `C772:2F28`
identifies the current frame/direction byte, `C772:2F50` checks neighboring
glyphs and builds a connection mask, and `C772:2FC8` translates that mask back
to a stored glyph byte. When the edit path is active (`[7480] & 0x01`),
`C772:2FEA` stages command byte `F4` in `[74B6]`, calls `C772:48C2`, marks
the line dirty through `[7463]`, sets `[750E] |= 0x08`, then calls
`C772:55E9`, `C772:48CC`, and `C772:515E`. The exit path at `C772:3010`
clears `[7D4B] & 0x01`. This makes framing a command-driven glyph updater:
saved documents should be decoded as glyph bytes plus ordinary layout records,
not as a literal stored `0x18` control.

A controlled v3.1 Dreamulator STORE sample named `fram` was made by enabling
framing with `CTRL+9`, drawing with `CTRL` plus cursor keys, and storing the
result through the normal FILE/STORE path. Because earlier non-drawing cursor
movement in that session changed the starting position, treat this as an exact
serialization sample rather than a minimal geometry fixture. The 44-byte file
payload is:

```text
FF 10 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00
1E 00 0C 0C 0C 0C 20 20 20 20 C4 C4 EE 24 00 24
00 EE C8 DB EE 24 00 00 00 EE C6 DB
```

The body after the default header is:

```text
0C 0C 0C 0C 20 20 20 20 C4 C4 EE 24 00 24 00 EE
C8 DB EE 24 00 00 00 EE C6 DB
```

This confirms the practical storage model: framing inserts ordinary frame glyph
bytes (`C4`, `C8`, `C6` in this sample) and may leave `EE` positional/range
records around those glyphs. It does not preserve the editor command byte
`0x18` in the file body.

Two smaller isolated v3.1 Dreamulator STORE samples pin down adjacent manual
line/page commands:

| Sample | Keystrokes | Stored body after `FF 10 ... 1E 00` header |
| --- | --- | --- |
| `vlin` | `CTRL+V` / Vertical Line | `EE 00 00 00 00 EE C6 0C` |
| `pend` | `CTRL+E` / Page End | `E9 02 0C 00 E9` |

The combined `low2` sample (`CTRL+V`, then `CTRL+E`) stores the same vertical
line prefix followed by `E9 02 0E 00 E9`; the Page End operand moves after the
inserted vertical-line/separator state. These samples supersede the earlier
static-only assumption that the commands were saved as literal `D4` and `D6`
body bytes. `D4` and `D6` remain ROM-recognized classifier/scanner byte values,
but they are not the normal saved bytes for these two tested commands.

The current evidence is asymmetric for Center and Right Flush. The keyboard
control table at `C000:3A17` confirms `CTRL+C -> 0x1E` and `CTRL+R -> 0x19`,
while the formatter paths found so far recognize `0x1E` and `0x1F`. Exact
C772/C774 literal searches for `cmp al,0x19` / `mov al,0x19` found no
command/stream consumer. The only nearby executable `0x19` relevant to the
editor service is `C772:5E2B` / `C774:5E2A`, which loads `CL=19h` before
entering `C772:5E35` / `C774:5E34`; that is a packed scanner/service mode
selector documented by the menu VM, not a comparison against the keyboard
command byte or a stored body byte. The C772 inline VM bytecode also has no
`5C 19` compare-key operation. The apparent `19 5C` hit at `C772:0512`
decodes as `88 19` (conditional branch with relative offset `0x19`) followed
by `5C 20` (compare `[74B5]` with space).

The normal VM key-driven edit opcode also does not compare `0x19`: opcode
`0x2E` loads `[74B5]` into `DL` and jumps through `C772:5E1E`, which queues
that byte in `[74E5]` and enters scanner mode `0x0A`. The classifier at
`C772:25DE` then indexes the word table at `C772:7C02`; entry `0x19`
(`C772:7C34`) is `0000h`, while entries `0x1E` and `0x1F` (`C772:7C3E` and
`C772:7C40`) are both `F000h`, which drives the special class-`0x70` path at
`C772:6223` and `C772:225E`. The v3.1.260 classifier has the same shape:
`C774:25DD` indexes `C774:7C01`, where entry `0x19` (`C774:7C33`) is `0000h`
and entries `0x1E`/`0x1F` (`C774:7C3D`/`C774:7C3F`) are `F000h`.

By contrast, `0x1F` is handled in multiple scan/output paths. `C772:1E57` /
`C774:1E56` store `0x1F` in `[745D]` when the formatter's table-driven scanner
reaches `[747E] + DX == [7485]` and the word loaded from `[7489] + [74FB]` has
bit `0x40` set (`test dl,40h` at `C772:1E24` / `C774:1E23`). That is an
internal layout-table branch, not a direct keyboard-command dispatch.
`C772:6223` / `C774:6266` map stored/control byte `0x1F` to annotation byte
`0x72`; `C772:A725` / `C774:A76F` emit the same `0x72` annotation for `0x1F`;
and `C772:225E` / `C774:225D` accept `CH == 0x1F` beside `CH == 0x1E` before
entering the annotation builder.

The static route found so far is indirect. Command `0x19` is not re-seen as a
literal parser byte; the command drives editor state that the formatter later
reads. The alignment formatter at `C772:17B7..1850` checks `[7477]`, and the
`[7477] == 08` branch performs right-margin/tab-position adjustment through two
`C772:5E35` scans. Separately, `C772:1E57` sets `[745D]=1F` when a
layout-table word's bit `0x40` is reached. That matches the live `CTRL+R`
snapshot, but it is not a literal `0x19 -> 0x1F` byte rewrite.

A live v3.1 Dreamulator snapshot after entering Edit Text and pressing
`CTRL+R` confirms the runtime side of the handoff. The visible status was
`Col 75`, matching movement to the default right margin. RAM held
`[745D]=1F`, while `[74B5]` and the staged byte at `[74E5]` were both `E4`,
the alignment-fill byte seen in the saved STORE samples. The safe file-format
wording is therefore: `0x1F` is the right-flush formatter/output marker, and
`0x19` is the editor command byte that can drive the live right-flush state,
but neither `0x19` nor `0x1F` should be decoded as the ordinary saved body form
for the tested one-line right-flush case. For file-format purposes this closes
the decoding rule: that saved form is `E4` fill plus the line text.

Two controlled v3.1 Dreamulator STORE samples show how simple one-character
alignment lines are serialized:

| Sample | Keystrokes | Stored body after `FF 10 ... 1E 00` header |
| --- | --- | --- |
| `cent` | `CTRL+C`, `a` | `E4` repeated 39 times, then `61` |
| `rfls` | `CTRL+R`, `a` | `E4` repeated 78 times, then `61` |

The sample file sizes are `0x3A` and `0x61` bytes respectively, so the body
lengths after the 18-byte header are 40 and 79 bytes. This confirms that, at
least for these single-character lines, STORE emits the final aligned stream
rather than preserving a literal center/right-flush command byte in the body.
The `E4` fill bytes are native alignment fill, not ASCII spaces; the text
conversion path strips unrecognized high bytes singly.

### Format-State Records

`EC` and `ED` are the two most concrete non-positional format records. They
both store an old value and a new value, and the scanner uses those values to
restore or change live editor state while walking a span:

| Marker | Live field | Confirmed value behavior |
| ---: | --- | --- |
| `EC` | Character Pitch: `[7460]` / snapshot `[7481]` | `C772:4D11` cycles the saved value by `+2`, wrapping before `0x06`; the normal cycle is therefore `0x00` (`PS`), `0x02` (`10`), `0x04` (`12`). `C772:9F72` indexes the two-character status table at `C772:E76E`, whose even entries are `PS`, `10`, `12`, `BF`. `C772:4DD5` temporarily forces `0x06`, saves the previous value in `[7D77]`, and `C772:4E0B` restores it. |
| `ED` | Line Spacing: `[7407]` / snapshot `[748D]` | `C772:4D51`/`4D5E` cycle this second format family. In the normal `[7481] != 0x06` case it increments through values below `0x05` and wraps to `0x02`, matching manual line-spacing values `1`, `1 1/2`, and `2` as internal half-line units `2`, `3`, and `4`. `C772:A030` renders the saved value by shifting it right to ASCII `0`..`9` and using the low bit as the half-line marker. When `[7481] == 0x06`, it advances by two through values below `0x09` and wraps to `0x04`. |

`C772:5505` is the redraw/rebuild helper used around these changes. It scans
past existing `EC`/`ED` records, applies encountered operand bytes back into
the two live fields, and can emit new `EC`/`ED` records only when the requested
value differs from the current one (`C772:6510`). This makes the file records
state deltas over a text range, not standalone document metadata.

The T400 manual names the user-facing controls as Character Pitch (`CTRL+1`,
status values `10`, `12`, `PS`) and Line Spacing (`CTRL+2`, status values `1`,
`1 1/2`, `2`). The v3.1 keyboard control table maps those keys to editor command
bytes `E2` and `E3`; the status renderer evidence above ties the persistent
records to the user-visible settings. The manual also names Word Wrap as the
status-area `A` indicator. `C772:A067` renders that indicator from
`[742F] & 0x02`: when the bit is clear, the status renderer writes `A` plus
the adjacent indicator glyph; when the bit is set, it writes spaces. That gives
the observed status-bit behavior, though the final UI polarity/name should be
checked against the live editor.

Current evidence points to Word Wrap being editor/session flow state, not a
stored document setting. The native header serializer `C772:82D6` writes only
the seven header words and the `[7A20...]` tab-stop table; it does not serialize
`[742F]`. The body-stream records found so far can set other `[742F]` bits
(`E9` subtypes `0x14`/`0x16` change bit `0x01`, and subtype `0x08` changes bit
`0x10`), but no persistent producer has been found for `[742F] & 0x02`.
The late ROMs do contain transient uses of that bit: the formatter target at
`C772:4328` / `C774:4327` saves `[742F]`, sets bit `0x02` while outputting
byte `C6`, then restores the saved byte; the status renderer at `C772:A067`
tests the same bit for the manual's `A` indicator. Cross-version raw-byte
searches found the same `[742F]` reference pattern in v3.1 and v3.1.260, and
found no bytecode flag set/clear/toggle targeting bit `0x02` of field `[742F]`.
The file-format read is therefore that word wrap is consumed while typing or
editing to decide when to flow text into new lines/control records. Once saved,
the file keeps only that resulting editor stream; the original live wrap-mode
preference is not recoverable from the file format evidence currently in hand.

Controlled v3.1 Dreamulator STORE samples confirm the `EC`/`ED` record shapes
in saved files. Because `Clear the text workspace?` does not reset every live
format scalar, the exact operand values in these samples are evidence for
record grammar and live cycle state, not universal defaults:

| Sample | Keystrokes before `a` / before `b` | Stored body tail |
| --- | --- | --- |
| `pitc` | `CTRL+1` / `CTRL+1` | `EC 04 02 EC 61 EC 00 04 EC 62` |
| `line` | `CTRL+2` / `CTRL+2` | `ED 03 02 ED 61 ED 04 03 ED 62` |

Both files use the same default `FF 10 ... 1E 00` header prefix as the plain
text and style-marker samples below, followed by the shown body tail.

The manual also describes storing a page-layout template as an ordinary stored
text file after clearing work memory. It says that template preserves right
margin, left margin, paper width, paper length, top margin, bottom margin,
pitch, and line spacing. That is consistent with an empty or nearly empty native
WP body whose leading header, generated tab-stop table, and `EC`/`ED` state
records carry the useful format state. The first, second, fourth, fifth, sixth,
and seventh header words now trace directly to the manual's left margin, right
margin, paper width, paper length, top margin, and bottom-margin-derived body
limit. The code caveat is that not every live format scalar has an independent
serialized slot: `TAB SPACE` is represented by the generated tab-stop table,
and Word Wrap has no confirmed serialized setting at all. Likewise, the broader
page-format snapshot should not be mapped one-to-one onto the file header: it
includes extra live fields and normalizes one slot by saving `[7436]` where the
restore path writes `[742D]`, while the file header preserves `[742D]` directly.

The `[745F]` toggle encoding is:

| `[745F]` bit | Set/start marker | Clear/end marker | Manual/key-table name | Current confidence |
| ---: | ---: | ---: | --- | --- |
| `0` | `F0` | `F1` | Underline (`CTRL+X`, manual name `XXX`) | `CTRL+X` returns editor command byte `F4`; the command path at `C772:411D` calls `C772:0270`, whose default case maps it to bit 0. Formatter space handling also tests this bit. An emulator STORE sample with `CTRL+X`, `a`, `CTRL+X`, `b` saves `F0 61 F1 62`, confirming `F0` starts the underlined span and `F1` ends it. |
| `1` | `F2` | `F3` | Temporary format/rebuild state | Confirmed encoding; `C772:049A` sets it while also setting `[742F] & 0x20`, and the paired exit path clears both. `C772:5505` may restore only this bit after comparing scanned state with the saved value. No manual key name is known. |
| `2` | `F4` | `F5` | OVERTYPE / autostrike (`CTRL+_`) | `CTRL+_` is physical `-`/`_` and maps to editor command byte `ED` in the control table. Emulator STORE sample `ovtp` for `a`, `CTRL+_`, `b` saves `F4 62 61 F5`, confirming bit 2 is the native overtype/autostrike span marker. Scanner/classifier paths also test this bit to bypass or alter character-class processing and spacing state, and `C772:0270` refuses Expanded Text while bit 2 is active. |
| `3` | `F6` | `F7` | Expanded text (`CTRL+Z`) | `CTRL+Z` returns editor command byte `E1`; `C772:0270` maps `E1` to bit 3 unless bit 2 is already active. Emulator STORE sample `expd` confirms `F6 61 F7 62` for expanded `a` followed by normal `b`. |
| `4` | `F8` | `F9` | Boldface (`CTRL+B`) | `CTRL+B` returns editor command byte `E0`; `C772:0270` maps `E0` to bit 4. Emulator STORE sample `bold` confirms `F8 61 F9 62` for bold `a` followed by normal `b`. |
| `5` | `FA` | `FB` | Superscript (`CTRL+Q`) | `CTRL+Q` returns editor command byte `FC`; `C772:0270` maps `FC` to bit 5 unless saved state `[7480]` already has bit 6. Emulator STORE sample `supr` confirms `FA 61 FB 62` for superscript `a` followed by normal `b`. |
| `6` | `FC` | `FD` | Subscript (`CTRL+W`) | `CTRL+W` returns editor command byte `FB`; `C772:0270` maps `FB` to bit 6 unless saved state `[7480]` already has bit 5. Emulator STORE sample `subc` confirms `FC 61 FD 62` for subscript `a` followed by normal `b`. |
| `7` | `FE` | `FF` | Encoded slot only | Confirmed generic encoding, but no direct v3.1/v3.1.260 set/clear producer has been found. Body `FF` is only a style marker after the initial header position. |

The user-visible names above come from the T400 manual's Text Formatting and
Appendix C quick-reference sections, then through the v3.1 keyboard control
translation table at `C000:3A17` when the editor uses the `[143C] & 0x08`
six-table translation mode. They name the editor command sources, not the raw
file bytes. For example, `CTRL+X` produces command byte `F4`, but the stored
underline markers are `F0/F1`; the stored `F4/F5` pair belongs to OVERTYPE
(`[745F]` bit 2).

Direct disassembly of the style-command mapper confirms that there is no
hidden manual style bit beyond the named ones above. `C772:0270` maps command
byte `E0` to mask `0x10` and marker base `F8`, `FC` to `0x20`/`FA` unless
subscript is already active, `FB` to `0x40`/`FC` unless superscript is already
active, `E1` to `0x08`/`F6` unless overtype bit 2 is active, and the default
case to `0x01`/`F0`. The v3.1.260 equivalent mapper starts at `C774:028F`.
The underline path at `C772:4118..4121` / `C774:4137..4140` loads command byte
`F4` and reaches that default case. No case in either mapper selects mask
`0x02` or `0x80`, so bits 1 and 7 are not exposed by this command table.

Bit 1 is tied to temporary formatter/rebuild state rather than to a named text
face. `C772:049A` sets `[745F] & 0x02` together with `[742F] & 0x20` before
entering a formatting helper, and the paired cleanup around `C772:04CE` clears
both. `C772:5505` may later restore only bit 1 after comparing scanned state
with the saved value. OVERTYPE bit 2 is also structurally special:
`C772:65CA` removes it from the normal shift loop with `& 0xFB`. When bit 2
is being cleared, the emitter writes `F5` before walking the remaining clear
bits from `F1` upward.
When bit 2 is being set, it first walks the remaining set bits from `F0`
upward, then writes `F4`. `C772:6B87`, `C772:60AA`, and `C772:A2B2` use this
bit as a gate around character-class and spacing processing. That behavior is
still relevant for decoding, but the `ovtp` STORE sample ties the user-facing
name to the same serialized `F4/F5` markers.

For decoder purposes, each marker byte `F0..FF` still maps mechanically to one
bit operation:

```text
bit = (marker - F0) / 2
even marker: set/start that bit
odd marker: clear/end that bit
```

The special bit-2 order matters for reserialization when multiple style bits
change at the same position; it does not change the individual marker meaning.

Bit 7 remains an encoding slot only. The generic style-delta emitter at
`C772:65CA..6632` / `C774:65C9..6631` can emit any bit in `[745F]`: it starts
from marker `F0` or `F1`, shifts the pending delta right one bit at a time, and
increments the marker by two for each shift, so a bit-7 delta naturally reaches
`FE` or `FF`. That is parser/serializer capacity, not proof of a normal
producer. The direct user-command mapper at `C772:0270` / `C774:028F` assigns
command bytes only to bits 0 and 3 through 6; bit 2 is sample-backed by the
separate OVERTYPE/autostrike path, while bit 1 remains formatter/rebuild-only.
The generic VM flag resolver can represent a `0x80` mask
(`C772:0462..0469` / `C774:0461..0468`), but targeted bytecode searches in both
late ROMs found no `56 E2`, `58 E2`, or `5A E2` sequence that would set, clear,
or toggle field index 2 (`[745F]`) with that mask, and no `52 80` display-flag
test. Raw byte searches likewise found no direct `or/and/xor/test/mov
[745F],0x80` producer or test. A decoder should therefore accept body `FE`/`FF`
as valid style toggle bytes, because the delta emitter can serialize them if
the bit changes, but current evidence does not assign them a T400 manual
feature name.

Two controlled v3.1 Dreamulator STORE samples from an isolated NVRAM image
first confirmed the native payload shape and the bit-0 marker polarity. A
plain `abc` document saved as `fmt0` has a 21-byte file payload:

```text
FF 10 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00
1E 00 61 62 63
```

The same setup with `CTRL+X`, `a`, `CTRL+X`, `b` saved as `fmtu` has a
22-byte payload:

```text
FF 10 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00
1E 00 F0 61 F1 62
```

In both cases the leading `FF 10` header and seven little-endian header words
match the serializer layout above. The underline sample confirms that the even
style marker (`F0` for bit 0) starts/sets the style span and the odd marker
(`F1`) clears/ends it.

The same isolated-NVRAM method also confirms the user-facing style pairs for
bits 3 through 6. Each sample stores the same `FF 10 ... 1E 00` default header
prefix and a 4-byte styled body tail:

| Sample | Keystrokes before `a` / before `b` | Stored body tail |
| --- | --- | --- |
| `expd` | `CTRL+Z` / `CTRL+Z` | `F6 61 F7 62` |
| `bold` | `CTRL+B` / `CTRL+B` | `F8 61 F9 62` |
| `supr` | `CTRL+Q` / `CTRL+Q` | `FA 61 FB 62` |
| `subc` | `CTRL+W` / `CTRL+W` | `FC 61 FD 62` |

Operationally, parsed marker bytes are also exposed to the C772 bytecode VM as
event-like state. `C772:3918` tests whether `[74B5] == E9` and then compares
`[74E6]` with the bytecode operand; `C772:3925` does the same for `EF`. This
means `E9` and `EF` are not only passive layout annotations: editor scripts can
branch on their subtype/parameter while formatting or moving through the stream.

### Sample Extraction Notes

The emulator STORE samples cited above were extracted from isolated
Dreamulator NVRAM images with the built-in store volume at offset `0x18000`.
The observed volume layout for these captures is:

| Structure | Offset within store volume |
| --- | ---: |
| FAT12 table | `0x0080` |
| Root directory | `0x0800` |
| Cluster 2 data | `0x1800` |
| Cluster size | `0x0400` |

The helper `tools/extract_wp_nvram.py` lists and extracts these files without
modifying the NVRAM image. For example:

```sh
python3 tools/extract_wp_nvram.py /home/admin/.fltk/dreamulator/dreamulator/wpformat_hyphen_31.ic303.nvram --extract hyph --hex
```

prints the saved `hyph` payload:

```text
0000: ff 10 3c 00 86 01 86 01 c2 01 84 00 0c 00 76 00
0010: 1e 00 61 d8 62 d1 63
```

This extraction path is not part of the WP file format itself; it is only the
reproducibility method for the controlled Dreamulator samples.

### Manual Naming Cross-Reference

The T400 manual is a naming source, not by itself byte-format evidence. The
table below tracks which manual controls have a confirmed file-format mapping
and which are still only candidates for the unresolved body records.

| Manual feature | Manual key | Editor command byte | Current file-format evidence |
| --- | --- | ---: | --- |
| Character Pitch | `CTRL+1` | `E2` | Stored as `EC old new EC`; emulator STORE sample `pitc` confirms the record in the body stream. |
| Line Spacing | `CTRL+2` | `E3` | Stored as `ED old new ED`; emulator STORE sample `line` confirms the record in the body stream. |
| Tab Set / Tab Clear | `CTRL+5` / `CTRL+6` | `EE` / `EF` | Updates the leading header's `[7A20...]` tab-stop table; no persistent body record needed for ordinary tab stops. |
| Underline (`XXX`) | `CTRL+X` | `F4` | Stored through `[745F]` bit 0, markers `F0/F1`. |
| OVERTYPE / autostrike | `CTRL+_` | `ED` | Stored through `[745F]` bit 2, markers `F4/F5`. The isolated `ovtp` STORE sample for `a`, `CTRL+_`, `b` stores `F4 62 61 F5`, matching the manual behavior where the cursor backs up and the second character combines with the first at the same position. |
| Expanded text | `CTRL+Z` | `E1` | Stored through `[745F]` bit 3, markers `F6/F7`. |
| Boldface | `CTRL+B` | `E0` | Stored through `[745F]` bit 4, markers `F8/F9`. |
| Superscript | `CTRL+Q` | `FC` | Stored through `[745F]` bit 5, markers `FA/FB`. |
| Subscript | `CTRL+W` | `FB` | Stored through `[745F]` bit 6, markers `FC/FD`. |
| Word Wrap | `CTRL+INS` | `E7` | Confirmed by the `C000:3A17` control table at matrix row 6 bit 2, the physical `INS` key. Status/UI state is `[742F] & 0x02`. Static file-format evidence shows no serialized header slot and no persistent body record for this flag. The saved stream preserves the resulting line/control layout, not the live wrap flag. |
| Decimal Tab | `CTRL+TAB` | `07` | Literal `0x07` has no confirmed body-parser role. Formatter state `0x07` maps to space but remains active; when the formatter class is `0x08`, `C772:1850` performs a right-margin/tab-position adjustment through `C772:5E35`. The isolated `dtab` STORE sample confirms the saved stream contains an `EE` spacing/range record (`EE 12 00 00 00 EE`) followed by the typed `12.3`, not a distinct decimal-tab byte. |
| Indent / Indent Clear | `CTRL+7` / `CTRL+8` | `F1` / `F2` | `F1` reaches `C772:4ED4`, records the command position in live ruler fields `[74B9]`/`[749F]`, and requires the cursor to be at least 10 spaces before the right margin. Controlled samples confirm the normal saved form is an `E8` body record, not a literal `F1`/`F2`: `CTRL+7` after five spaces stores `E8 1E 00 00 00 E8`, and the corresponding `CTRL+8` clear line stores `E8 00 00 1E 00 E8`; the fixed header remains default. Exact C772/C774 `0xF2` compares are unrelated resource delimiter scans, and direct `[74B9]` zeroing is table/ruler cleanup rather than a command-specific body marker writer. |
| Center / Right Flush | `CTRL+C` / `CTRL+R` | `1E` / `19` | `0x1E` is handled by formatter/output paths as Center. The right-flush formatter/output marker is `0x1F`, which maps to annotation byte `0x72` through `C772:6223` and `C772:A725`, is written to `[745D]` by an internal formatter branch at `C772:1E57`, and is accepted by the class-`0x70` path at `C772:225E`. A live `CTRL+R` snapshot confirms the command reaches this state (`[745D]=1F`, status `Col 75`) while staging `E4` alignment fill. Controlled one-character STORE samples show the saved body materialized as `E4` alignment fill followed by the text byte, with no literal `1E`, `19`, or `1F` in those saved bodies. |
| Page End | `CTRL+E` | `D6` | Stored as an `E9` subtype-`0x02` record in the isolated `pend` sample: `E9 02 0C 00 E9`. `D6` is still accepted by the layout scanner beside `DB`, but targeted late-ROM searches found no literal-`D6` stream builder, and it is not the normal saved byte for the tested Page End command. |
| Required / syllable hyphen | `CTRL+G` / `CTRL+H` | `D8` / `D1` | Low-byte hyphen controls. Controlled sample `hyph` stores `CTRL+G` as `D8` and `CTRL+H` as `D1` in `61 D8 62 D1 63`. `D1` is treated as a soft/syllable marker and can be converted to `D7`; `D8`, `D7`, and ASCII `-` share a hyphen predicate. |
| Vertical line | `CTRL+V` | `D4` | Stored as frame/line glyph output in the isolated `vlin` sample: `EE 00 00 00 00 EE C6 0C`. `C6` is the vertical frame-table glyph (`mask 0x05`), while `D4` is the input command byte and has no saved-file sample or C772/C774 body-writer evidence backing it as a persistent marker. |
| Framing | `CTRL+9` | `18` | Live editor mode command. `C772:13A8 -> C772:2EE8` computes frame connection masks from current/neighboring line glyphs, translates them through the `C772:2EC4..2ED9` mask/glyph pair table, and writes the resulting glyph through the normal edit/update path. `C772:494C` can reissue command `18` through the mode command path. The controlled `fram` STORE sample confirms the saved stream contains frame glyphs (`C4`, `C8`, `C6` in that capture) plus ordinary layout records (`EE ... EE`), not a persistent body marker `18`. |

The command-byte column is an editor input mapping. It is not a stored-stream
encoding table.

### Subtype Dispatch Records

`E9` and `EF` both use their first operand byte as a direct offset into native
jump tables. The code therefore mechanically permits byte-indexed subtypes, but
the normal records seen by the producer/consumer paths are even-coded. For
`E9`, subtypes `0x00..0x1C` select two-byte short-jump entries; subtype `0x1E`
starts a three-byte near jump to the common continuation path. For `EF`, the
confirmed `0x00..0x06` entries are all two-byte short jumps.

`E9` dispatches through `C772:66C1` / `C774:66C0`. Its record word is the
little-endian `DX` value supplied to the shared builder, not part of the
subtype selector. Confirmed table entries are:

| Subtype | v3.1 handler | v3.1.260 handler | Writer status | Current read |
| ---: | --- | --- | --- | --- |
| `0x00` | `C772:66BE -> 6744` | `C774:66BD -> 6743` | Consumer only in current scan. | Clear transient marker state `[745D]`. |
| `0x02` | `C772:66E2` | `C774:66E1` | Confirmed late-ROM writer. | Major run/page-boundary setup: sets `[745D]=CB`, clears `[749D]` and `[7433]`, updates `[7417]`, `[744A]`, `[7A42]`, and then rebuilds layout state. The isolated `pend` STORE sample ties this subtype to the manual Page End command as `E9 02 0C 00 E9`; `low2` shows the same subtype with operand `0x000E`, so the word is layout/span state rather than a fixed command signature. |
| `0x04` | `C772:6744` | `C774:6743` | Consumer only in current scan. | Clear transient marker state. |
| `0x06` | `C772:66B9` | `C774:66B8` | Confirmed late-ROM writer. | Synthesizes byte `0xDF` through the normal character/layout classifier. |
| `0x08` | `C772:6734` | `C774:6733` | Consumer only in current scan. | Toggles `[742F] bit 0x10`. |
| `0x0A` | `C772:6744` | `C774:6743` | Consumer only in current scan. | Clear transient marker state. |
| `0x0C` | `C772:6725` | `C774:6724` | Confirmed late-ROM writer. | Reverse-direction/range case: may set `[745D]=03`, restore saved cursor fields, then continue layout. The direct late-ROM writer is reached from the main edit/format loop, not from a named manual command path found so far. |
| `0x0E` | `C772:6744` | `C774:6743` | Consumer only in current scan; sibling writer entry joins the `0x0C` body, but no caller was found. | Clear transient marker state. |
| `0x10` | `C772:6744` | `C774:6743` | Consumer only in current scan. | Clear transient marker state. |
| `0x12` | `C772:6744` | `C774:6743` | Consumer only in current scan. | Clear transient marker state. |
| `0x14` | `C772:674C` | `C774:674B` | Consumer only in current scan. | Set `[742F] bit 0x01`. |
| `0x16` | `C772:6754` | `C774:6753` | Consumer only in current scan. | Clear `[742F] bit 0x01`. |
| `0x18` | `C772:6744` | `C774:6743` | Consumer only in current scan. | Clear transient marker state. |
| `0x1A` | `C772:667E` | `C774:667D` | Consumer only in current scan. | Signed spacing/indent accumulator: adjusts `[752E]` and `[7433]` from the record operand when direction flags require it. |
| `0x1C` | `C772:6744` | `C774:6743` | Consumer only in current scan. | Clear transient marker state. |
| `0x1E` | `C772:66DF -> 62D8` | `C774:66DE -> 62D7` | Consumer only in current scan. | Layout-state continuation without a subtype-specific mutation. |

Producer scans show three confirmed routes to the `E9` record builder in both
v3.1 and v3.1.260 (`C772:5279` / `C774:5278`). A rel16 call scan to the
builder finds exactly `C772:1057`, `C772:4320`, and `C772:4331`; the newer ROM
has the corresponding `C774:1056`, `C774:431F`, and `C774:4330` calls. The
`0x0C` producer is ordinary linear code with a direct caller in the main
edit/format loop. The builder always serializes the `DX` word present at the
call site. The builder itself is a short post-`RET` code island, so generated
linear traces can miss it; the raw-byte disassembly from `C772:5279` is the
authoritative check for the staged `E9 subtype word E9` layout. For the `0x0C`
producer, raw disassembly of the embedded entry shows that it computes
`SI = [741F] + 2 - [7417]`, sets `AL=1` and `DX=0`, calls the
shared span helper (`C772:3DAC` / `C774:3DAB`), then emits `E9 0C` with the
helper's returned `DX`. The operand is therefore post-helper layout/span state,
not simply the pre-helper body-end distance. The `0x06` and `0x02` producers
are formatter/VM entry routines embedded immediately after a `ret`;
`trace-full.txt` omits them as
linear blocks, but the raw ROM bytes at file offset `0xCBA3B` in v3.1 and
`0xCBA5A` in v3.1.260 confirm the entry sequences. A direct rel16 call/jump
scan found no ordinary caller for those embedded entries. However, a
cross-version byte/word scan does find their addresses in the nearby
formatter/VM operand stream: v3.1 contains the byte operands `1B 43` and
`28 43` near `C772:7A65`/`7A6B`, while v3.1.260 contains the corresponding
target words `431A` and `4327` at `C774:7A64`/`7A6A`. These entries should
therefore be treated as dispatcher-reached formatter targets rather than normal
subroutine calls.

| Producer | Subtype emitted | Immediate context |
| --- | ---: | --- |
| `C772:103E -> 1057` / `C774:103D -> 1056` | `0x0C` | Page/body-limit range setup. The entry pushes operation byte `0x16`, computes `SI = [741F] + 2 - [7417]`, enters `C772:3DAC` / `C774:3DAB` with `AL=1` and `DX=0`, emits `E9 0C` using the helper's returned `DX`, snapshots `[7421] - 1` into `[7335]` and `[7337]`, initializes `[7339]`, and then uses `[7423]`, `[741D]`, and `[7450] & 0x80` before the `10C7`/`10C6` cursor/layout update. Direct-call scans find the normal caller at `C772:496E` / `C774:496D`, inside helper `C772:4922` / `C774:4921`. That helper is called from the main edit/format loop at `C772:570A` / `C774:5709` when `[74C3] & 0x10` is set after a nontrivial input byte. The immediate guard requires `[7463] & 0x08`, no `[7313] & 0x20`, local byte `0xEA`, and `[745E] & 0x03 == 0`. The sibling `0x0E` entry at `C772:103A` / `C774:1039` joins the same writer body, but direct near-call and C772/C774 word-table scans did not find a caller. |
| `C772:431B` / `C774:431A` | `0x06` | Formatter/layout boundary target. Cross-version target operands in the formatter/VM stream (`C772:7A65` / `C774:7A64`) reference this entry even though no ordinary rel16 caller exists. It first calls `C772:086E` / `C774:086D`, which compares a half-scaled `[7193]` position against `[7438] + [7415]` and can abort with `[74C8]=0x80` when the current scanner state cannot accept the boundary. It then loads `AL=06` (`C772:431E` / `C774:431D`), calls the `E9` builder, and calls `C772:2AF6` / `C774:2AF5` to reconcile the active range/display window. The consumer for subtype `0x06` synthesizes byte `0xDF`, so this is a layout/display boundary record, not plain text. |
| `C772:4328` / `C774:4327` | `0x02` | Major formatter/rebuild target. Cross-version target operands in the same formatter/VM stream (`C772:7A6B` / `C774:7A6A`) reference this entry. It starts with an inline-bytecode call through `C772:022D` / `C774:022C`, then loads `AL=02` (`C772:432F` / `C774:432E`) and calls the `E9` builder. The following inline bytecode/tests cover `DB` and `0C` separators, `[7D76]`, the same `086E` position guard, and the `6E33` range calculator; the path stages an `EE` range through `A5EA`/`A634`, sets `[750E] |= 0x80`, emits style deltas through `655D`/`65CF`, temporarily sets `[742F] & 0x02` while outputting byte `C6`, and then calls `3DAC` to update the span. The `pend` STORE sample shows that this subtype is also the serialized form reached by the simple manual Page End command. |

These sites confirm that subtypes `0x02`, `0x06`, and `0x0C` are actually
written by both late ROMs. Subtype `0x02` now has one sample-backed manual
name: Page End in the simple `pend` capture. The static producer context still
looks like a broader formatter/rebuild boundary, so this should be read as
"Page End uses this record class" rather than "all `E9 02` records are only
Page End." The `pend` and `low2` samples also show that the Page End operand
word is context-dependent layout state (`0x000C` versus `0x000E`), not a
constant command byte sequence. Subtype `0x0C` is now bounded to the main
edit/format loop's page/body-limit side-effect path, but it still has no named
manual command. Subtype `0x06` remains an internal formatter/range boundary
until a saved-file sample or a higher-level command trace connects it to a
named operation.

Do not confuse the `0x14`/`0x16` `E9` records with the manual's Word Wrap
toggle. These records change `[742F] & 0x01`; the status renderer's Word Wrap
`A` indicator is controlled by `[742F] & 0x02`, which is not in the serialized
native header and has no confirmed persistent body record.

The v2.1 redraw path shows the same marker class in the display/layout stream:
its `E9` table can synthesize display bytes such as `0xDF` or `0xD6`, redraw a
mode-dependent range, and convert some stream bytes into `F2`/`F3`-class mode
markers. That supports reading `E9` as a layout/display event record rather
than as document text.

`EF` dispatches through `C772:69D8`; the v3.1.260 equivalent table starts at
`C774:69D7`. Confirmed table entries are:

| Subtype | v3.1 handler | v3.1.260 handler | Writer status | Current read |
| ---: | --- | --- | --- | --- |
| `0x00` | `C772:6A24` | `C774:6A23` | Consumer only in current scan. | Saved `[749D]` checkpoint. Depending on scan direction and mode flags, it stages the old `[749D]` through the common positional helper and then stores either the signed word at `[74E9..74EA]` or the line-position word at `[74E7..74E8]` back to `[749D]`. |
| `0x02` | `C772:6A50` | `C774:6A4F` | Consumer only in current scan. | No subtype-specific mutation; returns through the common marker tail. |
| `0x04` | `C772:6A56` | `C774:6A55` | Consumer only in current scan. | Vertical-position/range boundary adjustment. It sets `[745D]=CB`; in forward scans it compares the record line-position word at `[74E7..74E8]` against `[7417] + 2`, stores either the record word or `[7417] + 2` back to `[7417]`, snapshots `[7415]` into `[7A42]`, and joins the page-boundary tail. In reverse scans it uses the signed word at `[74E9..74EA]` with the same two-line guard before joining the reverse cursor/layout tail. |
| `0x06` | `C772:69E0` | `C774:69DF` | Confirmed late-ROM writer. | Body/page continuation boundary. Clears `[7433]`, consumes the record's remaining bytes during directional scans, and restores `[7433]` from the signed accumulator byte at `[74E9]` when unwinding the span. |

The only `EF` producer found in both late ROMs is the inline subtype-`0x06`
writer in the main formatter boundary path (`C772:6139` / `C774:6138`). The
only `B0 EF` hits in the C772/C774 segments are the opening and closing marker
bytes of that writer (`C772:6140`, `C772:6169`; `C774:613F`, `C774:6168`), and
no `B2 EF`, `C7 04 EF 00`, or `C6 04 EF` builder-style pattern was found. A
rel16 call/jump scan also finds no ordinary callers to the four `EF` table
handlers; those handlers are reached through the subtype table dispatch at
`C772:665D` / `C774:665C`. The writer first
advances `[744A]` and `[7417]` by the current line spacing `[7407]`, checks the
new line position against `[741F]`, and only emits the record when that test
has reached or passed the printable body-end threshold and the editor active
bit `[73F7] & 0x01` is set. The stored word `[74E7..74E8]` is therefore the new
vertical line position, not a horizontal text span. The following byte
`[74E9]` is the current signed offset/accumulator `[7433]`, `[74EA]` is its
sign extension (`00` for non-negative, `FF` for negative), and `[74EB]` is the
closing `EF`. After writing the record it clears `[7433]`,
updates `[73FB]`, `[7468]`, `[741D]`, `[7417]`, `[744A]`, `[7485]`, increments
`[7421]`, and falls into the shared range/cursor reset tail. This makes the
confirmed `EF 06` form a body/page continuation boundary tied to vertical
layout state, not an arbitrary subtype-dispatched user command. A controlled
negative STORE sample named `efpg` typed 70 `x` lines separated by hard returns;
the saved body after the header is simply repeated `78 0C` pairs, with no `EF`
record. That bounds the producer more narrowly: it is not emitted merely
because user text crosses the displayed page body via explicit hard returns.

The v2.1 redraw code treats `EF` subtype `0x06` specially as a continuation
case: it copies a saved operand into the current span state and recomputes the
active range. Non-`0x06` `EF` records feed a synthetic output path that emits a
pair of formatted word operands.

Cross-version evidence from the v2.1 redraw path matches the same grammar:
`0xEE`, `0xE8`, `0xEF`, `0xED`, `0xE9`, and `0xEC` are decoded as compact
multi-byte editor markers, and `0xF0`, `0xF2`, and following even values are
appended as single-byte mode markers for set display bits. The v2.1 names also
support reading `E8` as a saved-start/span marker rather than ordinary text.

`C000:29A5`, the text reader/import conversion path, provides a second view
of persistent body grammar. It passes most printable `0x20..0xDF` bytes to the
editor endpoint, converts `0x0C` and `0xDB` to CR/LF, ignores control bytes
below `0x20`, and skips fixed-size WP control records:

| Marker | Bytes after marker skipped by conversion path | Current confidence |
| ---: | ---: | --- |
| `0xE8` | `5` | Confirmed record width; saved span/start endpoint behavior documented above. |
| `0xE9` | `4` | Confirmed record width; subtype table documented above. |
| `0xEC` | `3` | Matches `EC old new EC`. |
| `0xED` | `3` | Matches `ED old new ED`. |
| `0xEE` | `5` | Confirmed record width; range-boundary and spacing behavior documented above. |
| `0xEF` | `6` | Confirmed record width; subtype table documented above. |

The conversion path also gives negative evidence for `EA`/`EB` as structured
records. It only recognizes fixed-width payloads for `E8`, `E9`, `EC`, `ED`,
`EE`, and `EF`; any other byte `>= E0`, including `EA`, `EB`, and single-byte
style markers, is stripped one byte at a time in text conversion. That matches
the formatter evidence: `EA`/`EB` are single-byte run delimiters in the editor
stream, not records with operand bytes. The observed raw `EB` immediate in the
C772 output/translation path is not evidence of a stored-file record shape.

Low control bytes are not uniformly ordinary text. The text conversion path
drops bytes below `0x20` except for `0x0C`, and the native RECALL cleanup path
strips trailing NUL/`0x1A` bytes when `[7025] != 1`; however, the native
editor/layout scanner has confirmed low-byte controls and scanner exceptions
such as `0xD1`, `0xD6`, `0xD7`, `0xD8`, `0x1E`, and `0x1F`. Bytes
`0x20..0xDF` should therefore be treated as glyph bytes only when no
formatter/control path claims the current byte. The isolated `vlin` and `pend`
samples also show why command-byte tables must not be read as stored-byte
tables: the manual Vertical Line and Page End commands did not serialize as
literal `D4` or `D6`. Conversely, `E4` is now confirmed as a native body byte
even though it falls in the high-byte range that text conversion strips when no
fixed-width record decoder claims it.

## Remaining Non-Format Questions

The container, leading header layout, native disk read/write path, and byte
layouts for the main high-byte body controls are now concrete. User-facing
`[745F]` text-style names are tied to manual key names where the ROM has a
keyboard-command path; bit 2 is now sample-backed as OVERTYPE/autostrike, bit
1 remains formatter structural state, and bit 7 is still only an encoded slot
with no direct producer found.

For parser/interchange purposes, the remaining open questions below are naming
and higher-level provenance questions, not unknown byte widths: external code
can identify the native header, validate the tab-stop tail, consume every
confirmed fixed-width body record, and report unknown subtype values without
losing stream synchronization.
Character pitch (`EC`) and line spacing (`ED`) are now tied to status-renderer
evidence. The serialized header now maps most of the manual Page Format screen:
left margin, right margin, paper width, paper length, top margin, and the
bottom-margin-derived body limit. The `lm11` STORE sample confirms that the
left margin is stored as manual spaces times 6 and that the right-margin field
is a span relative to the left margin. The `rm76` sample independently confirms
the right-margin span and shows the default `[742D]` and paper-width span
coupling performed by the Page Format UI. The `pw86` sample confirms the
paper-width span independently. The `pl67` sample confirms paper length as
doubled line units and shows the default bottom/body-limit complement moving
with paper length to preserve the displayed bottom margin. The `tm7` sample
confirms top margin independently in the same doubled line units, and the
`bm7` sample confirms the bottom-margin complement formula directly. The third
word `[742D]` is now tied to persistent ruler/layout threshold behavior and to
the Page Format right-margin gap-preservation path, but the `ind1` sample
proves that a simple one-line indent command does not serialize by changing
that header word. The tab-stop
header tail is tied to the manual's tab feature, and the manual's constant `TAB SPACE`
setting has also been tied to live field `[743A]`; the `ts5` STORE sample
confirms that the file stores the generated `[7A20...]` tab table bytes
(`FF 2E` for the default fixed header plus 16 two-byte stops) rather than
`[743A]` itself. The file-header serializer has also been
separated from the broader live page-format snapshot, whose extra fields remain
useful for naming but are not serialized in the native file header.

The T400 manual is useful for final naming, but the remaining high-byte records
still need higher-level command traces before assigning UI labels. The direct
`E9` producer set is now cross-version-confirmed for subtypes `0x02`, `0x06`,
and `0x0C`; the `pend` STORE sample assigns subtype `0x02` to the manual Page
End command in at least the simple tested case, while `low2` proves its operand
word can vary with surrounding layout state. Subtype `0x0C` is now traced back
to the main edit/format loop's page/body-limit side-effect helper, while
subtype `0x06` still looks like a formatter/range boundary without a standalone
manual command name.

`EF` producer evidence is now likewise bounded: only subtype
`0x06` has a direct late-ROM writer, and that writer is tied to vertical
formatter/body continuation state. The `efpg` STORE sample shows that 70
explicit hard-returned lines serialize as repeated `78 0C` pairs with no `EF`,
so `EF 06` is not the ordinary stored form of user-typed page crossing.
Decimal Tab is now tied to formatter state
`0x07` plus the `[7477] == 0x08` right-alignment branch, and the `dtab` STORE
sample confirms that a simple decimal-tabbed `12.3` line serializes as an `EE`
spacing/range record followed by literal text, with no literal stored `0x07`
marker. Indent set/clear now has a sample-backed command/ruler/body trace:
`C772:4ED4` records the live marker in `[74B9]`/`[749F]`; the `ind1` STORE
sample serializes a five-space one-line indent as `E8 1E 00 00 00 E8`; and the
manual-flow `iclr` sample serializes the corresponding clear line as
`E8 00 00 1E 00 E8`. Both leave the fixed header unchanged. The remaining
indent uncertainty is only for more complex after-the-fact reflow cases, not
for the normal set/clear line encoding.

`CTRL+8` returns `0xF2`, but the exact C772/C774 `0xF2` hits found so far are
unrelated resource-delimiter or display/status-script paths, and neither ROM
has a `5C F2` VM compare-key operation. That is stronger negative evidence for
a distinct persistent `0xF2` body marker. The observed clear-side mechanics are
ordinary ruler cleanup/reset paths, especially the `[74B9]` zeroing sites, plus
the existing range/reflow machinery. Center now has code evidence as a
formatter/output control plus sample-backed STORE materialization into `E4`
alignment fill. Right Flush is now split into a confirmed keyboard command byte
(`0x19`), a live-confirmed formatter/output state marker (`0x1F` in `[745D]`),
and sample-backed STORE materialization into `E4` fill. Static evidence now
rules out a direct literal, VM compare-key, or classifier-table dispatch from
`0x19` to `0x1F`; the exact upstream key-handler setup remains a UI-path
question, not a file-format ambiguity. The runtime handoff and the negative
saved-body evidence are both sample-backed, and the confirmed `0x1F` paths are
cross-version-stable in both late ROMs. Page End is now sample-backed as an
`E9 02 <word> E9` record whose word is layout-dependent, and the `hyph` sample
confirms `CTRL+G`/`CTRL+H` as directly stored `D8`/`D1` hyphen controls.
Vertical line is now tied to stored frame/line glyph `C6` plus an `EE` range
record and `0C` separator in the simple `vlin` sample, not to literal `D4`.
Framing is now traced as a live glyph-insertion/editor mode rather than a
literal stored `0x18` control byte; the `fram` saved-file sample validates the
practical command-to-glyph storage model by showing `C4`/`C8`/`C6` glyph bytes
and `EE` range records in the body, with no `0x18` marker. Word Wrap is now
bounded as a non-serialized typing/reflow mode in the file format: `CTRL+INS`
maps to editor command byte `E7`, but the saved file preserves only the
line/control stream produced while editing, not the mode flag itself. TAB SET
and TAB CLEAR are now tied to the header tab-stop table rather than to a
persistent body record.
