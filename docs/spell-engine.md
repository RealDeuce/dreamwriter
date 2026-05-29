# Banked Spell/Linguistic Service

The banked routine at `3000:0000` is a service thunk into the spelling /
grammar / linguistic engine region. It is reached through the `C000:18A1`
banked far-call helper described in [`banking.md`](banking.md).

## Thunk

`C000:18A1` remaps CPU `3000:0000` to ROM file `0x30000`, then calls far
pointer `C000:189A`, which contains `3000:0000`.

The target routine starts at file `0x30000`:

```asm
3000:0000  cld
3000:0001  push si
3000:0002  push es
3000:0003  push ds
3000:0004  push bp
3000:0005  mov cx,ss
3000:0007  mov bx,sp
3000:0009  mov bp,3C00
3000:000C  mov es,bp
3000:000E  mov ds,bp
3000:0010  mov ss,bp
3000:0012  add sp,4000
...
3000:0018  add si,4000
3000:001C  push si
3000:001D  mov ax,dx
3000:001F  push ax
3000:0021  call 3000:4AA6
```

It switches `DS`, `ES`, and `SS` to segment `3C00`, passes two arguments to
`3000:4AA6`, then restores the caller's stack and returns far. Before return it
loads `DX` from `[3C00:6BD8]`, exchanges `AX` and `DX`, and returns that value
to the caller.

Arguments observed so far:

| Caller | Service ID | Buffer argument | Notes |
| --- | ---: | --- | --- |
| `C000:02A8` | `0x3C` | `6A06 + 4000` | Startup/service initialization path via `C000:189E`. |
| `C000:02B0` | `0x01` | `6A06 + 4000` | Cold boot sequence path. |
| `C000:02B8` | `0x00` | `6A06 + 4000` | Cold boot sequence path. |
| `C000:12FB` | `0x58` | caller-dependent `SI + 4000` | Diagnostic `Q` command, documented as clear spell. |
| `C000:15F1` | `0x59` | caller-dependent `SI + 4000` | Diagnostic `R` command path, documented as reset spell. |

## Dispatcher

`3000:4AA6` is a service dispatcher. It rejects service IDs above `0x59`, then
uses a word jump table at file `0x34C0A`:

```asm
3000:4AA6  mov word [6BD8],0000
3000:4AB2  mov ax,[bp+04]        ; service ID
3000:4AB5  cmp ax,0059
3000:4AB8  ja 3000:4C02          ; return FFFF
3000:4ABD  add ax,ax
3000:4ABF  xchg ax,bx
3000:4AC0  jmp [cs:bx+4C0A]
```

Confirmed dispatch entries:

| Service ID | Jump target | Evidence |
| ---: | --- | --- |
| `0x00` | `3000:4AC6` | Called by `C000:02B8` during cold boot sequence. |
| `0x01` | `3000:4ACC` | Called by `C000:02B0` during cold boot sequence. |
| `0x3C` | `3000:4BC2` | Called through `C000:189E`, which adds `0x3C` to `DL`. |
| `0x3D` | `3000:4BCA` | Same `C000:189E` path when caller provides `DL = 1`. |
| `0x58` | `3000:4BF2` | Diagnostic `Q` command. |
| `0x59` | `3000:4BFA` | Diagnostic `R` command. |

`0x58` and `0x59` are the diagnostic help text's `Q/R=Clear/Reset spell`
commands:

```asm
C000:12F8  mov dl,58
C000:12FB  call C000:18A1
...
C000:1301  mov dl,59
C000:1303  call C000:15F0
C000:15F1  call C000:18A1
```

The corresponding dispatch targets run a service body, then fall into the
common dispatcher epilogue:

```asm
3000:4BF2  call 3000:4CF4
3000:4BF5  mov sp,bp
3000:4BF7  pop bp
3000:4BF8  ret

3000:4BFA  call 3000:4D1A
3000:4BFD  mov sp,bp
3000:4BFF  pop bp
3000:4C00  ret
```

## Local State

The engine uses `3C00` as its data/stack segment during calls. Some state
addresses visible in the dispatcher and nearby routines:

| Address | Observed use |
| ---: | --- |
| `3C00:6000` | Engine status flag toggled by dispatcher services. |
| `3C00:6002` | Mode flag set/cleared by service cases around `3000:4B50`. |
| `3C00:6004` | Count-like value returned by one dispatch case. |
| `3C00:6BD8` | Return/status word copied back to caller as `AX`. |
| `3C00:6BDA..6BE6` | Scratch/status words used by parser/search routines. |
| `3C00:8EE2` | Pointer into a small parse/output structure. |
| `3C00:8EEC` | Mode flag used by service routines around `3000:4DA8`. |
| `3C00:966C` | Callback/function pointer invoked by parser path at `3000:0224`. |

## Dictionary ROM Windows

During `C000:18A1`, the linguistic wrapper maps several ROM windows before
calling `3000:0000`:

| CPU range | Bank port/value | ROM file range | Confirmed use |
| ---: | --- | ---: | --- |
| `0x30000..0x3FFFF` | `0x11 = 0x02` | `0x30000..0x3FFFF` | Banked spell code. |
| `0x60000..0x7BFFF` | `0x13 = 0x03` | `0x00000..0x1BFFF` | Mapped, but no confirmed reader yet. |
| `0x7C000..0x7FFFF` | `0x13 = 0x03` | `0x1C000..0x1FFFF` | Start of the confirmed dictionary stream. |
| `0x80000..0x8FFFF` | `0x14 = 0x02` | `0x20000..0x2FFFF` | Continuation of the confirmed dictionary stream. |

The key reader is `3000:660F`. It treats `[3C00:9684]:[3C00:9682]` as a
logical byte offset, converts that offset to a 1 KiB page, and copies from
segment `7C00 + page * 0x40`:

```asm
3000:665D  mov ax,[9682]
3000:6660  mov dx,[9684]
...
3000:6674  add dx,7C00
3000:667A  mov ds,dx
3000:6681  rep movsw
```

Logical offset `0` therefore maps to CPU `0x7C000`, file `0x1C000`. The known
seek callers set offsets inside this logical stream. No explicit
`6000`-segment reader has been found in the banked linguistic code, so the earlier
`0x00000..0x1BFFF` former `banked-dictionary-data` label is currently only a mapped
payload, not a decoded format. Since the product also has grammar checking,
this low mapped payload should be treated as possible grammar/linguistic data,
not only a spelling dictionary.

An odd segment base was checked as a possible way to skip the copyright/header
area and read the lower mapped chunk. The banked code has no confirmed
`0x6000..0x7BFF` segment load in this path; the only confirmed ROM source
segment load is the computed `7C00 + page * 0x40` form in `3000:660F`.
`3000:66AE` does not explicitly reject negative logical offsets, so a
pre-biased seek could theoretically land below CPU `0x7C000`, but the known
callers use non-negative offsets derived from the dictionary header and page
indexes.

The `0x1C000..0x30000` stream was also scanned as data for references back into
`0x00000..0x1BFFF`. Individual byte patterns can look like low absolute
addresses, especially inside compressed data, but no monotonic pointer-table
run was found for 24-bit/32-bit absolute offsets or signed negative 1 KiB page
deltas. The single 32-bit value that decodes as a signed negative stream offset
is the byte sequence `f8 fa fe ff` at file `0x25964`; in context it is the tail
of an ordered byte table immediately before the readable word list, not a
confirmed pointer.

## Dictionary Stream Format

`3000:88A0` initializes the dictionary structure at `3C00:7502`. It resets the
logical stream, seeks to offset `0x100`, reads 16 bytes, and converts them into
eight little-endian words:

```asm
3000:88CB  mov ax,0100
3000:88D1  call 3000:66AE        ; seek
3000:88DB  mov ax,0010
3000:88E3  call 3000:95B6        ; exact-length read
3000:88F4  mov ax,0008
3000:88FD  call 3000:95D4        ; byte-pairs to words
```

The ROM 2.1 header at file `0x1C100` is:

| Struct offset | Value | Observed use |
| ---: | ---: | --- |
| `+00` | `0x0001` | Header/version-like field. |
| `+02` | `0x0500` | Unknown count/limit. |
| `+04` | `0x0046` | Base value used by later parser adjustment code. |
| `+06` | `0x0040` | Stride/divisor used while walking compressed entries. |
| `+08` | `0x005A` | Byte count loaded to local table `0x7622`. |
| `+0A` | `0x005B` | Word count loaded to local table `0x752A`. |
| `+0C` | `0x0021` | Compressed page count/index bound. |
| `+0E` | `0x02CC` | Byte count loaded to string/symbol table `0x7236`. |

The loader then reads the variable sections immediately after the 16-byte
header:

| Destination | Length source | Notes |
| ---: | --- | --- |
| `0x7622` | `[dict+08]` bytes | Byte lookup table. |
| `0x752A` | `[dict+0A] * 2` bytes | Word lookup table. |
| `0x7236` | `[dict+0E]` bytes | NUL-terminated string/symbol table. |
| `0x7182` | built from `[dict+08]` strings | Pointer table into the string/symbol data. |
| `0x75E0` | built from `[dict+0C]` strings | Second pointer table into the remaining string data. |

It computes `[dict+22]` as the first 1 KiB page after those local tables:

```text
dict[22] = ((((dict[0A] * 2) + dict[08] + dict[0E] + 0x10F) & 0xFC00) >> 10) + 1
```

For ROM 2.1 this gives `dict[22] = 2`. The compressed bitstream starts at
logical offset `([dict+22] + [dict+0C]) * 0x400 = 0x8C00`, which is file
`0x24C00`.

## Compressed Word Data

`3000:96D6` opens the compressed stream for the dictionary structure returned
by `3000:88A0`. It calls `3000:B076` with the starting logical byte offset,
then calls `3000:7972` to load the bitstream subheader.

`3000:B076` is the 1 KiB page loader. With its flag argument set, it stores
`offset >> 10` in `[8150]`, uses `offset & 0x03FF` as the starting byte inside
the page, seeks through `3000:66AE`, reads `0x400` bytes to `0x864E`, and sets:

| Address | Meaning |
| ---: | --- |
| `0x814A` | Current byte pointer, initially `0x864E + (offset & 0x03FF)`. |
| `0x814C` | Remaining bit count from the current byte. |
| `0x814E` | Inclusive page-buffer end, `0x8A4D`. |
| `0x8150` | Current 1 KiB logical page number. |
| `0x8152` | Current byte for nibble-oriented decoders. |

`3000:ADBE` reads an arbitrary number of bits from this page buffer and calls
`3000:B076` again when the pointer passes `0x814E`. `3000:8854` uses that bit
reader to read little-endian 16-bit words as two 8-bit reads.

`3000:7972` reads the compressed-word subheader:

| Address | Source |
| ---: | --- |
| `0x9650..0x965F` | Eight 16-bit bitstream header words. |
| `0x9662` | Points to a symbol table loaded at `0x7166`; length is `[0x9652]`. |
| `0x9660` | Points to a word-offset table loaded at `0x7136`; count is `[0x9658]`. |
| `0x9664` | Base address `0x2B30` for compressed word pages. |

`3000:B116` is the visible consumer of this compressed word data. It decodes
entries from the page selected through `[9660] + [9664]`. The format is
nibble-oriented:

- Nibbles are consumed high nibble, then low nibble, using `[8152]` as the
  current byte.
- A nibble value of `0xF` is an extension sentinel; the decoder keeps adding
  nibbles until a value below `0xF` appears.
- One variable-length nibble sum backs up the destination pointer, giving the
  entry a prefix/back-reference style compression.
- The next variable-length nibble sum indexes the symbol table at `[9662]`; the
  byte found there is emitted.
- A zero symbol terminates the expanded word.

`3000:B4D4` uses the same nibble-coded stream for binary search against a query
word, and `3000:B116` expands matching entries into caller-provided buffers.
This explains the readable letter-order data around file `0x24C00`, including
the subheader tables, while keeping the lower mapped payload at
`0x00000..0x1BFFF` unresolved for now.

## Candidate List Manager

The rough block after the stream reader begins with real code. `3000:66D4`
initializes the high-level candidate/suggestion state:

```asm
3000:66DA  mov word [712E],FFFF
3000:66E0  mov word [6E48],0000
3000:66E6  call 3000:88A0      ; load dictionary header/stream tables
3000:66FC  call 3000:96D6      ; open compressed word stream
...
3000:6713  mov ax,0050
3000:6716  imul word [bp-02]
3000:6719  add ax,6E5E
3000:6721  mov [bx+6E4A],ax    ; nine 0x50-byte candidate buffers
```

Observed state in `3C00`:

| Address | Meaning |
| ---: | --- |
| `0x6E48` | Candidate count returned by `3000:9848`. |
| `0x6E4A..0x6E5B` | Nine word pointers to candidate text buffers. |
| `0x6E5C` | Secondary candidate/list index used by related-word helpers. |
| `0x6E5E..0x712D` | Nine `0x50`-byte candidate text buffers. |
| `0x712E` | Current candidate index; `FFFF` means no active candidate. |
| `0x7130` | Pointer to an auxiliary related-word list built by `3000:A45C`. |
| `0x7132` | Dictionary structure pointer returned by `3000:88A0`. |
| `0x7134` | Current parser/search record pointer used by formatter helpers. |

Small helpers around `3000:677A..688F` copy the active candidate, move to the
next/previous candidate, and return the current candidate's first or later
space-separated fields. The code around `3000:6892..6962` lazily builds and
walks an auxiliary related-word list via `3000:A45C`.

`3000:6964` formats numbered suggestion lines. It writes a digit, `") "`,
then formats a candidate based on packed record fields and appends text through
the local string helpers at `3000:960A`, `3000:9626`, `3000:963A`, `3000:9666`,
and `3000:969E`. The apparent constants such as `0x24F4`, `0x2508`, and
`0x2589` in this formatter are `DS=3C00` RAM/data-segment pointers, not ROM
file offsets.

`3000:6B6C..6ECE` is a parser/search-record formatter. It stores the active
record at `0x7134`, inspects fields like `[record+3]` and `[record+6]`, and
uses `3000:B116` to expand dictionary entries into output buffers. Special
cases combine entries with separators such as `/`, which looks like formatting
compound or alternate forms.

## Inflection and Suffix Handlers

The rough block immediately after the candidate formatter is a confirmed
suffix/word-form generation island. These routines mutate candidate text in
scratch buffers, append suffix strings from the `3C00` data segment, and call
`3000:B0E6` to check whether the generated form exists in the dictionary.

`3000:6ECE` dispatches on the final character of the current output word. It
subtracts `'e'` and jumps through an inline table at file `0x37124`, covering
letters `e..z`:

| Final letter | Handler |
| --- | --- |
| `e` | `3000:7042` |
| `f` | `3000:701A` |
| `h` | `3000:6F1C` |
| `m` | `3000:70FC` |
| `n` | `3000:70D8` |
| `o` | `3000:7086` |
| `s` | `3000:6F30` |
| `u` | `3000:6FF8` |
| `x` | `3000:6F86` |
| `y` | `3000:6EF4` |
| `z` | `3000:7014` |
| other covered letters | `3000:7150` |

The generated variants include English-looking transformations such as adding
`s`, changing final `y` to `i` before another suffix, `f` to `v` before `e`,
and special plural-like cases around endings such as `is` and `us`. The routine
does not simply emit those forms; each variant is validated through the
dictionary lookup before it is accepted.

Other handlers in the same island use similar final-letter dispatch:

| File range | Role |
| ---: | --- |
| `0x37150..0x373F2` | Suffix handlers including a `3000:7164` path for final `c/e/l/y` cases and a `3000:721C` path that dispatches through `a..y`. |
| `0x373F2..0x37424` | Inline `a..y` jump table for `3000:721C`. |
| `0x37424..0x37636` | Continuation of suffix handling, including another large final-letter dispatcher at `3000:748E`. |
| `0x37636..0x37666` | Inline `b..y` jump table for `3000:748E`. |
| `0x37666..0x37724` | Candidate-combination helper used by the suffix handlers. |

The combination helper at `3000:7686` copies two candidate fragments into
scratch buffers, inserts byte `0x0E` as a separator when both fragments are
non-empty, and checks the combined result through `3000:B0E6`. This matches the
formatter's earlier use of separator-like bytes in compound or alternate
candidate output.

These routines probably support both spelling suggestions and grammar-related
word-form checks, but the confirmed behavior at this point is narrower:
candidate inflection, suffix transformation, and dictionary validation.

## Working Interpretation

The code around `3000:46FC..4BFA` has spelling/grammar/linguistic behavior:

- It processes character streams through tables at offsets like `3000:09D8`,
  `3000:116A`, and `3000:12E4`.
- It tracks word/parser state around `3C00:6D7A`, `6D7C`, `6D80`, and `6DA4`.
- It exposes diagnostic clear/reset services through IDs `0x58` and `0x59`.

This is enough to call `3000:0000` the banked spelling/grammar/linguistic
service thunk. Individual service IDs still need names beyond the confirmed
diagnostic and startup cases.
