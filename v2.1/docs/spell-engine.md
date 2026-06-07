# Banked Spell/Linguistic Service

The banked routine at `3000:0000` is a service thunk into the spelling /
grammar / linguistic engine region. It is reached through the `C000:18A1`
banked far-call helper described in [`banking.md`](../../docs/banking.md).

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
| `0x3D..0x45` | `3000:4BCA` | Same `C000:189E` path for numbered choices. The stub subtracts `0x3C` and passes the one-based selected number to `3000:5026`. |
| `0x46` | `3000:4BDE` | Same `C000:189E` path when caller provides `DL = 0x0A`; result-list setup/count. |
| `0x47` | `3000:4BE8` | Same `C000:189E` path when caller provides `DL = 0x0B`; formatted result-row fetch. |
| `0x58` | `3000:4BF2` | Diagnostic `Q` command. |
| `0x59` | `3000:4BFA` | Diagnostic `R` command. |

The full table covers service IDs `0x00..0x59` and now has its own ROM-map
entry at `0x34C0A..0x34CBE`. Many entries intentionally point at the common
`3000:4C02` error return, while the dense early range points at small service
case stubs in `3000:4AC6..4BFA`. Those stubs then call the larger parser,
candidate-list, and dictionary helpers.

`0x58` and `0x59` are the diagnostic help text's `Q/R=Clear/Reset spell`
commands. The full diagnostic-side slice is in
[`disassembly/diagnostic-spell-services.md`](disassembly/diagnostic-spell-services.md):

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

`3000:4CF4` zero-fills `3C00:6BD8..9687`. `3000:4D1A` performs the reset path:
it initializes candidate state through `3000:5016`, initializes the `84DA`
output record, rebuilds the active page descriptors through `3000:527C`, and
validates the engine buffer through `3000:3AAC`. On validation failure it falls
back through the service-`0x01` initializer at `3000:4D6A`, rings the private
`AX=4420` tone helper five times, and returns `FFFF`.

## Local State

The engine uses `3C00` as its data/stack segment during calls. Some state
addresses visible in the dispatcher and nearby routines:

The low offsets of that segment are ROM constants from file `0x3C000..0x3FFFF`
while the mutable state lives at higher offsets. For example, string/table
pointers such as `0x24F4`, `0x25A2`, and `0x2A1E` refer to ROM constants at
file `0x3E4F4`, `0x3E5A2`, and `0x3EA1E`. State such as `0x6000`, `0x6E48`,
and `0x9662` is in the writable part of the same `3C00` segment.

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

## Editor Grammar Preference

WP -> OTHERS -> PREFERENCES edits the grammar-checking option at `[6D55]`.
`DC98:2A83` / file `0x5F403` draws the `EDITOR PREFERENCES` resource at
`EF8E:0000`, loads `[6D55]` into a local word, and stores it back on accept.
The UI text is `GRAMMAR CHECKING : { ON } { OFF }`; startup initializes
`[6D55]` to zero at `C000:484F`, so the index encoding appears to be
`0 == ON`, `1 == OFF`.

The spell/grammar run path checks the same byte in the C688 linguistic
front-end:

```asm
C688:ED32  mov byte [8E3E],01
C688:ED36  call C688:936A
C688:ED39  cmp dl,01
C688:ED3E  cmp byte [6D55],00
C688:ED43  jnz C688:ED56
C688:ED45  mov byte [8E3E],00
C688:ED4A  call C688:EF24
```

This confirms the editor preference is not just a UI setting. When the service
call reports `DL == 1`, `[6D55] == 0` enables the grammar side of the combined
spell/grammar pass; nonzero skips that setup. This does not yet identify a
gate for the low mapped engine page data at file `0x00000..0x1B413`: the
confirmed `[6D55]` references are startup defaulting, Preferences read/write,
and this C688 front-end branch, not a direct guard around `3000:660F` or the
dictionary stream offset setup.

## Editor Spell/Grammar Front-End

The editor UI reaches the banked service through `C688:936A`, a far wrapper for
`C000:1712`. In that dispatcher, `AH=04` jumps directly to `C000:18A1`, so the
current `DL` is the banked service ID. `AH=05` first goes through `C000:189E`,
which adds `0x3C` to `DL`, then calls `C000:18A1`.

This makes the combined spelling/grammar UI at `C688:ED1F` a concrete service
front-end rather than just a display loop:

```asm
C688:ED2D  mov byte [8E3E],01
C688:ED32  mov dl,23
C688:ED34  mov ah,04
C688:ED36  call C688:936A      ; banked service 0x23
C688:ED39  cmp dl,01
...
C688:ED45  mov byte [8E3E],00 ; grammar pass
C688:ED4A  call C688:EF24
```

`C688:EF24` calls `C688:EF31`, which seeds `DL=0x28` and enters the shared
word-check helper. When `[8E3E] == 0` that helper calls banked service `0x28`
directly; otherwise it follows the spelling-mode wrapper path. The main
checker loop at `C688:D283` uses the same helper with service `0x16` in spelling
mode and `0x2A` in grammar mode:

```asm
C688:D832  mov dl,16
C688:D837  cmp byte [8E3E],00
C688:D83B  mov dl,2A
C688:D840  call C688:D84F
```

Other concrete banked service calls in the editor spell/grammar cluster:

| C688 call site | Service ID | Notes |
| --- | ---: | --- |
| `C688:D32D` | `0x32` | Sent when the editor front-end accepts a space/separator-like token. |
| `C688:D37E` | `0x1C` | Conditional path when the word buffer starts with `0x28` / `(`. |
| `C688:D394` | `0x30` | Follow-up when the front-end's `0x8DA8` flag bit 2 was set. |
| `C688:D85B` | current `DL` | Direct call in grammar mode from the shared word-check helper. |
| `C688:D871` | current `DL` | Spelling-mode call after UI/status update. |
| `C688:D882`, `C688:D890` | `0x04` | Retry/shorten path used by the spelling-mode helper. |
| `C688:D9E4`, `C688:DA3E` | `0x09` | Initializes or refreshes a result/count used by the suggestion browser. |
| `C688:DB71` | `0x08` | Query using text extracted from the marked display buffer. |
| `C688:DB9B`, `C688:DC0E` | `0x09` | Re-enters the result/count path while navigating suggestions. |
| `C688:DC61`, `C688:DD84` | `0x10` or state byte `[8DB7]` | Fetches suggestion/display text into `8DDB`. |
| `C688:DDA0`, `C688:E207` | `0x11` | Advances through fetched suggestion/display text. |
| `C688:E11B` | `0x12` or `0x13` | Branches on `[8E35]`, likely selecting result class/view. |
| `C688:E127` | `0x18` | Used in the `[8E35] == 0x39` special path. |
| `C688:E131` | `0x12` | Companion call in the same special path. |
| `C688:E13C` | `0x19` | Companion call in the same special path. |
| `C688:E403` | `0x3C + [8DB6]` | `AH=05`; selects or expands the numbered candidate currently shown. |
| `C688:E552` | `0x46` | `AH=05`, `DL=0x0A`; returns a count-like value for a result list. |
| `C688:E59A` | `0x47` | `AH=05`, `DL=0x0B`; fills 0x50-byte result records. |
| `C688:F0A6` | `0x07` | Error/status query after `C688:EF24`. |

## Editor Thesaurus Front-End

The `F8` editor dispatch entry at `C688:E274` is the observed Alt+8
Thesaurus path. It first calls `C688:4F85`; if that succeeds it enters
`C688:E282`, then returns through the normal editor loop:

```asm
C688:E274  call C688:4F85
C688:E277  jnc C688:E27C
C688:E279  jmp C688:EDBE
C688:E27C  call C688:E282
C688:E27F  jmp C688:EC9F
```

`C688:E282` clears bit `0x80` in `[8DB4]`, copies or normalizes the current
word into `[8DBA]`, draws resource `0x76` through `C688:7689`, creates a
selection/list wrapper through `C688:71B5` with `CL=1`, `DX=75A0`, then enters
the main Thesaurus loop at `C688:E2EA`.

The Thesaurus front-end uses the same `AH=05` banked-service adjustment as the
spell/grammar suggestion browser:

| C688 call site | Effective service | Observed role |
| --- | ---: | --- |
| `C688:E552` | `0x46` | `DL=0x0A` before `AH=05`; query word at `7F28`, result count returned in `DL` and copied to `[8DB5]` / `[8E3D]`. |
| `C688:E59A` | `0x47` | `DL=0x0B` before `AH=05`; fills the next 0x50-byte result row at `7F50`, then the UI copies it into the visible row buffer. |
| `C688:E403` | `0x3C + [8DB6]` | Selected-number expansion. `DL` is loaded from `[8DB6]` before `AH=05`, so numbered choices 1..9 enter services `0x3D..0x45`. |

`C688:E530` is the list builder. It shows the wait resource `0x7B`, copies the
query word from `[8DBA]` to `7F28`, calls service `0x46`, and loops over
service `0x47` to populate 0x50-byte row buffers. `C688:E5DA` computes each
destination as `0x5800 + 0x370 + 0x50 * ([8DB6] - 1)` and stores it in
`[8E36]`.

Inside the banked dispatcher, services `0x3D..0x45` all share
`3000:4BCA -> 3000:5026`. The stub converts the service ID back to the
one-based selected number. `3000:5026` rewinds/walks the current candidate list
through `3000:685E` and `3000:687C`, selects the requested candidate, then
calls `3000:6892` repeatedly to append related words from the auxiliary list.
It inserts `", "` between returned strings and terminates the caller buffer.
This is the banked side of the Thesaurus meanings string that the C688 UI later
paginates.

The main loop at `C688:E2EA` then displays and navigates those rows. Numeric
selection stores the selected number in `[8DB6]`, shows the `to replace` /
`CAN to meanings` prompts, calls the selected-number banked service, and enters
the meanings display path. `C688:E672` initializes meaning pagination state in
`[8DB8]` and `[8DB9]`; the formatter around `C688:E6C2..E720` copies
comma-separated meaning text into display rows and wraps the marked text in
`F2`/`F3` display controls. `C688:E228` later copies the text between those
markers into `7F28`, copies the original query from `[8DBA]` to `7F68`, and
calls `C688:DF42`, which is the likely replacement/apply step.

Important Thesaurus state bytes:

| Address | Working role |
| ---: | --- |
| `[8DBA]` | Current query word copied from the editor/current-word buffer. |
| `[8DB5]` | Result count returned by service `0x46`. |
| `[8DB6]` | Current result/selection number. |
| `[8DB8]`, `[8DB9]` | Meaning pagination counters initialized by `C688:E672`. |
| `[8E36]` | Pointer to the current 0x50-byte row buffer. |
| `[8E38]` | Visible row/page index. |
| `[8E39]` | Result-window paging state. |
| `[8E3C]` | Boundary/marker flag set by next/previous page movement. |
| `[8E3D]` | Copy of the result count. |

The UI resource table base is file `0x559C0`; entry words at
`0x559C4 + id*2` point to payloads relative to that table. The Thesaurus
cluster currently maps as:

| Resource ID | Payload | Visible text / role |
| ---: | ---: | --- |
| `0x76` | `0x573FE` | Main Thesaurus screen, including `===  T H E S A U R U S  ===`. |
| `0x77` | `0x57441` | `Select No. or CAN to exit`. |
| `0x78` | `0x5746F` | Selection prompt fragment. |
| `0x79` | `0x57476` | `to replace`. |
| `0x7A` | `0x5748A` | `*** NO SYNONYM IN DICTIONARY ***`. |
| `0x7B` | `0x574B3` | `*** W A I T ***`. |
| `0x7C` | `0x574CB` | `CAN to meanings`. |
| `0x7D` | `0x574E4` | `for next screen`. |
| `0x7E` | `0x574FF` | `for previous screen`. |
| `0x7F` | `0x5751D` | `CAN to meannings` as spelled in ROM. |

This strongly ties the editor Thesaurus to the same banked candidate-list
services used by spelling/grammar, but it still does not prove whether the
low slot-0 page data is thesaurus-specific, grammar-specific, or common engine
data. The next useful target is the service `0x46` / `0x47` / selected-number
handler chain inside the banked engine.

This path now has two separate ROM data feeds. The compressed dictionary stream
is read through `3000:660F`, while the active engine slot setup builds direct
page descriptors for the lower mapped window at CPU `0x60000..0x7BFFF`.

The first decode pass through the editor-facing service handlers gives this
working map:

| Service ID | Handler | Working role |
| ---: | --- | --- |
| `0x16` | `3000:4B4C -> 3000:4EDC` | Spelling-mode parse/check wrapper. Translates the caller's text into the engine alphabet at `8F00`, sets `[8EEC]=1`, initializes the parser record through `3000:193A`, appends the word through `3000:1990`, then drives the parser/checker through `3000:1A16`. |
| `0x23` | `3000:4B80` | Returns `[6004] + 1`; this is a state/index query used before optionally entering the grammar pass. |
| `0x24`/`0x25` | `3000:4B88`/`3000:4B92 -> 3000:527C` | Selects engine slot `0` or `1` and rebuilds that slot's page-descriptor list. |
| `0x28` | `3000:4B98 -> 3000:4F38 -> 3000:4666` | Resets parser/tokenizer state: clears `[6D80]`, `[6D7E]`, `[6DA4]`, `[6DA3]`, points `[6D7C]` at the word buffer `8AB4`, and sets parser state `[6D7A]=9`. |
| `0x2A` | `3000:4BA4 -> 3000:4F44` | Grammar-mode word feed/check. Translates the caller's text to `8F00`, calls the parser at `3000:470A`, stores the parser result in `[966A]`, and re-runs `3000:470A` once if the result is `>= 0x40`. |
| `0x3D..0x45` | `3000:4BCA -> 3000:5026` | Selected-result expansion for services produced by `AH=05` with caller `DL=1..9`. Rewinds/walks the active candidate list, then emits comma-separated related words by repeatedly calling `3000:6892`. |
| `0x46` | `3000:4BDE -> 3000:50C4` | Result-list setup/count path used by the editor's `AH=05, DL=0x0A` call. It calls `3000:673A`, stores the count in `[8454]`, and caps the display count at nine items. |
| `0x47` | `3000:4BE8 -> 3000:50F4` | Formats the next numbered result row into the caller buffer. It emits `"N) "`, copies the primary candidate text via `3000:677A`, appends spacing, then copies secondary text via `3000:67E8`. |

`3000:193A` initializes the parser record at `93CC` with primary and secondary
word buffers at `90BE` and `90E2`; `[84D6]` points at the current record and
`[8AD6]` is the current append pointer. `3000:1990` appends translated bytes to
that record and then dispatches through the active engine table at `[9360]+0x10`.
`3000:1A16` drives the active table callbacks at `[9360]+0x0A`, `+0x0C`,
`+0x0E`, and `+0x10` until a final status is reached.

`3000:527C` is the first confirmed reader for the low mapped payload. It stores
the selected slot in `[6004]`, then calls `3000:003D(slot,index)` for indexes
`0..7`. That helper returns an offset/segment pair:

| Slot | Index range | Returned descriptors | Mapped ROM file pages |
| ---: | ---: | --- | ---: |
| `0` | `0..7` | `6000:0000`, `6400:0000`, ... `7C00:0000` | `0x00000`, `0x04000`, ... `0x1C000` |
| `1` | `0..7` | `9000:0000`, `9400:0000`, ... `AC00:0000` | `0x30000`, `0x34000`, `0x38000`, and `0x3C000` for the descriptors that remain inside the wrapper's `0x14` ROM window; `A000:0000` and above are outside the remapped ROM windows during this call. |

The descriptors are copied into a runtime list at `832A + slot * 0x32`, and
`[9104]` is later set to that list by `3000:18EC`. During setup, the first
descriptor is immediately dereferenced:

```asm
3000:52DD  les bx,[bx]
3000:52DF  mov al,[es:bx]
```

For slot `0`, that reads byte `0x04` from `6000:0000`, which is file
`0x00000`. The byte is split into high/low nibbles and feeds a loop-continuation
test:

```asm
3000:530D  and ax,00F0
3000:5312  shr ax,cl
3000:5317  and cx,000F
3000:531A  dec cx
3000:531D  jl  3000:52B2
```

However, this firmware also caps the outer loop at one descriptor group with
`cmp [bp-04],1` / `jnl 3000:531F`, so only the first eight descriptors are
materialized here. The high/low test may be leftover support for a larger slot
page list, but it does not cause a second group to be copied in this ROM.

The first six bytes of the even 0x4000 pages make that high/low split look
intentional:

| File offset | First six bytes | Working read |
| ---: | --- | --- |
| `0x00000` | `04 10 32 02 C8 FF` | block/index byte `0x04` |
| `0x08000` | `14 10 32 02 63 2F` | block/index byte `0x14` |
| `0x10000` | `24 10 32 02 51 DB` | block/index byte `0x24` |
| `0x18000` | `34 10 32 02 A2 56` | block/index byte `0x34` |

Odd 0x4000 pages do not have this same header shape, and the reader only skips
six bytes when `[8EE8]` bit 0 is clear. So the stream appears to be organized as
four logical blocks whose even half starts with a six-byte header and whose odd
half is continuation data. The first header byte plausibly stores block index in
the high nibble and total block count `4` in the low nibble. The final block is
short: data ends at file `0x1B413`, before the reader would naturally wrap into
descriptor 7 at file `0x1C000`.

So the low block is no longer merely mapped by the spell/grammar wrapper; it is
page data for slot `0`. The page header and token classes remain undecoded, but
the stream reader is now visible. The active callback base is a separate table:
`3000:18EC` loads `[9360]` from
`3C00:1604 + slot * 2`, giving callback bases `3C00:0CAE` for slot `0` and
`3C00:219A` for slot `1`, then stores the page-list pointer in `[9104]`.
The startup/init path also selects slot `0`: service `0x00` reaches
`3000:4CC2 -> 3000:4D6A -> 3000:4F76 -> 3000:527C(0)`, and service `0x01`
enters at `3000:4D6A`.

`3000:18EC(slot)` makes the selected slot active by setting `[9104]` to
`832A + slot * 0x32`; `3000:2D5C(index)` then selects one six-byte descriptor
from that list:

```asm
3000:2D60  mov bx,[bp+04]      ; descriptor index
3000:2D63  mov ax,bx
3000:2D65  shl bx,1
3000:2D67  add bx,ax
3000:2D69  shl bx,1            ; index * 6
3000:2D6B  mov si,[9104]
3000:2D6F  mov ax,[bx+si]
3000:2D71  mov dx,[bx+si+2]
3000:2D74  mov [8EFC],ax
3000:2D77  mov [8EFE],dx
```

Only the first four bytes of each six-byte runtime descriptor are populated by
`3000:527C` and used here, as the active far pointer `[8EFC:8EFE]`. The two
extra stride bytes appear to be unused or reserved padding in the descriptor
list rather than source bytes returned by `3000:003D`.
The parser state uses `[8EE6]` as an offset into that active stream and `[8EE8]`
as mixed page/phase state: `[8EE8] & 7` selects the descriptor index, while bit
`0x10` is toggled by the nibble reader.

`3000:20C2` is the core nibble reader. It loads through `LES SI,[8EFC]`,
reads from `[ES:SI + [8EE6]]`, and alternates high/low nibbles by toggling
`[8EE8]` bit `0x10`; the low-nibble phase increments `[8EE6]`. `3000:20F8`
is the companion byte reader from the same stream. If the nibble phase is clear
it returns the next aligned byte and increments `[8EE6]`; if the phase bit is
set it combines the current low nibble with the next byte's high nibble to
return an unaligned byte.

The visible consumers are `3000:1D7E` and `3000:1E6C`. Both compute the
descriptor index from `[8EE8] & 7`, call `3000:2D5C`, and seed `[8EE6] = 6`
when starting at offset zero with the low page/state bit clear. That suggests
the first six bytes of a page are header-like data, although the fields are not
decoded yet. The stream uses `0x0F` as an extension sentinel in at least one
count/value path, and when `[8EE6]` reaches the `0x4000` boundary the code wraps
by advancing `[8EE8]` and resetting the page offset.

This confirms `0x00000..0x1B413` is consumed as a separate nibble-coded slot
page stream. It is not the same format as the 1 KiB compressed dictionary pages
loaded by `3000:B076` and walked by `3000:8B0A`/`3000:8F06`.

The active table selected through `[9360]` is a mixed data/callback table. For
slot `0`, `[9360] = 0x0CAE`; for slot `1`, `[9360] = 0x219A`. The first words
are data-table pointers used by the slot-page parser, while later words are
near callbacks invoked by the parser driver:

| Table offset | Slot 0 value | Slot 1 value | Observed use |
| ---: | ---: | ---: | --- |
| `+00` | `0x0CDC` | `0x161A` | Base of a 257-record cursor table. `3000:1D5A` reads the first four-byte record as the initial stream cursor. |
| `+02` | `0x0CE0` | `0x161E` | Same cursor table, advanced by one four-byte record. One `3000:1E6C` branch indexes this as a 256-entry table after reading a byte with `3000:20F8`. |
| `+04` | `0x10E0` | `0x1A1E` | Sixteen four-byte records used by `3000:1D7E`/`3000:1E6C` for low-nibble-zero classes. |
| `+06` | `0x1120` | `0x1A5E` | Byte table indexed by an extended nibble count in `3000:1E6C`. |
| `+0A` | `0x1600` | `0x6156` | Parser callback called by `3000:1A16`. |
| `+0C` | `0x1694` | `0x6184` | Parser callback called by `3000:1A16`. |
| `+0E` | `0x1530` | `0x5F4C` | Parser callback called by `3000:1A16`. |
| `+10` | `0x12DE` | `0x5C30` | Parser callback called by `3000:1990` and `3000:1A16`. |

`3000:1D5A` copies three bytes from the table at `[ [9360] + 0 ]` into a caller
cursor buffer: a word for `[8EE6]` and a byte for `[8EE8]`. Slot `0` starts with
cursor record `33 AE 16`, i.e. offset `0x33AE` and state byte `0x16`. Since
`0x16 & 7 == 6`, that points into descriptor 6, file `0x18000 + 0x33AE =
0x1B3AE`, close to the end of the short final low block. Slot `1` starts with
cursor record `D8 28 11`, selecting descriptor 1 with offset `0x28D8`.
The pointer spacing confirms the cursor-table interpretation: in both slots,
the `+02` pointer is exactly four bytes after `+00`, and the `+04` table begins
`0x404` bytes after `+00`.

The direct references to stream cursor words `[9682]` and `[9684]` are still
limited to the stream reset/read/seek helpers at `3000:65FE`, `3000:660F`, and
`3000:66AE`; the newly confirmed low-block consumer is this page-descriptor
path, not the positive dictionary stream API.

## Dictionary ROM Windows

During `C000:18A1`, the linguistic wrapper maps several ROM windows before
calling `3000:0000`:

| CPU range | Bank port/value | ROM file range | Confirmed use |
| ---: | --- | ---: | --- |
| `0x30000..0x3FFFF` | `0x11 = 0x02` | `0x30000..0x3FFFF` | Banked spell code. |
| `0x60000..0x7B412` | `0x13 = 0x03` | `0x00000..0x1B412` | Slot-0 engine page data. `3000:527C` synthesizes descriptors beginning at `6000:0000`; `3000:2D5C`/`3000:20C2`/`3000:20F8` later consume it as nibble-coded slot page streams. |
| `0x7B413..0x7B41F` | `0x13 = 0x03` | `0x1B413..0x1B41F` | All-zero tail/padding after the dense payload. |
| `0x7B420..0x7BFFF` | `0x13 = 0x03` | `0x1B420..0x1BFFF` | All `0xFF` padding before the copyright block. |
| `0x7C000..0x7FFFF` | `0x13 = 0x03` | `0x1C000..0x1FFFF` | Copyright/padding at logical stream offset `0`; dictionary header starts at offset `0x100`. |
| `0x80000..0x8FFFF` | `0x14 = 0x02` | `0x20000..0x2FFFF` | Continuation of the confirmed dictionary stream. |
| `0x90000..0x9FFFF` | `0x14 = 0x02` | `0x30000..0x3FFFF` | Banked service code and `3C00` constants are also visible here; slot-1 descriptors from `3000:527C` point at this range. |

The key reader is `3000:660F`. It treats `[3C00:9684]:[3C00:9682]` as a
signed-capable logical byte offset, then computes a source `DS:SI` pair from
that offset. The segment value is not literal; it is built in `DX` and then
loaded into `DS`:

```asm
3000:665D  mov ax,[9682]
3000:6660  mov dx,[9684]
...
3000:6674  add dx,7C00
3000:667A  mov ds,dx
3000:6681  rep movsw
```

Logical offset `0` maps to CPU `0x7C000`, file `0x1C000`. The segment math is
not a simple flat `0x7C000 + offset`: it keeps a 15-bit intra-segment offset and
folds higher bits into `DS`, so the 20-bit physical address can wrap. If handed
large positive offsets, the same math would wrap back to the low mapped payload
at about `0xE4000..0xFF412`. However, `3000:66AE` and the read-side bounds
check in `3000:660F` reject normal positive seeks above `0x14000`, so that
wraparound path is not available through the confirmed stream API.

Signed-negative logical offsets are still possible at the arithmetic level
because the bounds checks use signed comparisons against high word `0x0001`.
With the exact segment construction, the low mapped payload begins at logical
offset about `-0x1CFF0`: that maps to CPU `0x60000`, file `0x00000`. The dense
payload is covered through about `-0x1BDE`, mapping to file `0x1B412`. That
means the low mapped payload is reachable through the normal stream reader only
if a caller intentionally seeds a signed-negative logical offset in that range.

The unresolved part is therefore the caller, not the addressing mechanism. The
known seek callers inspected so far use non-negative offsets derived from the
dictionary header, dictionary page indexes, or caller-supplied search offsets.
The placement of the erased area argues against treating the low payload as a
natural negative-offset prelude to the dictionary stream: the unused `0xFF`
block is immediately before logical offset zero, whereas a backwards-growing
prelude would more naturally leave erased space at the low end of the mapped
window.
The `0x00000..0x1B413` former `banked-dictionary-data` label is now confirmed
as slot-0 engine page data consumed through a nibble-coded page stream, but not
as a fully decoded format. It is followed by a 13-byte zero tail at
`0x1B413..0x1B420`, then all-`0xFF` erased padding through `0x1C000`. Because
the confirmed reader is the banked spell/grammar service and the editor also
exposes a thesaurus path, the broad role is linguistic data, but the exact
contents could include grammar, spelling, thesaurus, or common engine tables.

The `0x1C000..0x30000` stream was also scanned as data for references back into
`0x00000..0x1B413`. Individual byte patterns can look like low absolute
addresses, especially inside compressed data, but no monotonic pointer-table
run was found for 24-bit/32-bit absolute offsets or signed negative 1 KiB page
deltas. The single 32-bit value that decodes as a signed negative stream offset
is the byte sequence `f8 fa fe ff` at file `0x25964`; in context it is the tail
of an ordered byte table immediately before the readable word list, not a
confirmed pointer.

## Dictionary Stream Format

`3000:88A0` initializes the dictionary structure at `3C00:7502`. It resets the
logical stream, seeks to offset `0x100`, reads 16 bytes, and converts them into
eight little-endian words. Detailed disassembly for `3000:8854`, `3000:88A0`,
`3000:89B6`, and `3000:89E2` is maintained in
[`disassembly/banked-dictionary-stream-init.md`](disassembly/banked-dictionary-stream-init.md):

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
reader to read little-endian 16-bit words as two 8-bit reads; detailed
disassembly is maintained in
[`disassembly/banked-dictionary-stream-init.md`](disassembly/banked-dictionary-stream-init.md).

`3000:7972` reads the compressed-word subheader. Detailed disassembly is
maintained in
[`disassembly/banked-compressed-subheader-loader.md`](disassembly/banked-compressed-subheader-loader.md):

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
`0x00000..0x1B413` unresolved for now.

A follow-up byte-shape pass found no plain strings of length 8 or more and no
simple `mov r16,0x6000..0x7BFF` / `mov sreg,r16` load sequence in the banked
`3000` code. The low payload has much less zero density than the confirmed
dictionary stream (`~1.3%` versus `~8.5%` in the compressed word region), which
argues against treating it as just another page of the same dictionary stream
without a confirmed reader. A plain-code sanity check also argues against
treating it as ordinary V20 code: representative disassembly windows decode as
random-looking instruction soup with frequent privileged/interrupt/FPU-style
operations, far returns with arbitrary immediates, and implausible branch
targets rather than stable function structure.

Simple obfuscation checks have not explained the block either. The low payload
has entropy around `7.80` bits/byte, higher than the confirmed `3000` code
region (`~6.85`) and the confirmed dictionary stream (`~7.42`). Single-byte
XOR/add/sub transforms do not reveal text, and repeating-key column checks for
small powers and common periods still look high-entropy rather than code-like
or text-like. That does not rule out encryption or a custom packed format, but
the sharp boundary at file `0x1B413` followed by a short zero tail and erased
`0xFF` padding argues for a deliberately bounded payload rather than random
fall-through code.

Low-level helpers in the late part of the `3000` bank are now separated in the
ROM map:

| Routine | Observed role |
| --- | --- |
| `3000:95B6` | Exact-length dictionary stream read wrapper around `3000:660F`; returns `0` only when the requested byte count was read. |
| `3000:95D4` | Converts byte pairs into little-endian words. |
| `3000:960A` | Copies a NUL-terminated string and returns the destination end pointer. |
| `3000:9626` | Returns the end pointer of a NUL-terminated string. |
| `3000:963A` | Finds a byte in a NUL-terminated string. |
| `3000:9666` | Finds the last occurrence of a byte in a NUL-terminated string. |
| `3000:969E` | Lexicographic string compare helper. |
| `3000:1D5A` | Seeds a slot-page stream cursor from the active table at `[ [9360] + 0 ]`, copying a word offset and byte state. |
| `3000:1D7E` | Slot-page parser stepper using descriptor index `[8EE8] & 7`, stream offset `[8EE6]`, and the nibble reader at `3000:20C2`. |
| `3000:1E6C` | Slot-page parser/record builder using the same descriptor stream; saves/restores stream cursor state when consulting callback-table data. |
| `3000:2D5C` | Selects a six-byte active slot descriptor from `[9104] + index * 6` and loads its far pointer into `[8EFC:8EFE]`. |
| `3000:20C2` | Reads the next nibble from active slot-page stream `[8EFC:8EFE] + [8EE6]`, toggling `[8EE8]` bit `0x10` as the high/low phase. |
| `3000:20F8` | Reads the next byte or unaligned byte from the same active slot-page stream, depending on the current nibble phase. |
| `3000:ADBE` | Reads an arbitrary-width value from the compressed bitstream. |
| `3000:AEB6` | Reads the next byte/nibble-aligned unit from the compressed bitstream. |
| `3000:AFB4` | Skips forward in the compressed bitstream. |
| `3000:B076` | Loads a 1 KiB compressed page and initializes `0x814A..0x8152`. |
| `3000:B0E6` | Dictionary membership/check wrapper used by the inflection handlers. |
| `3000:B116` | Expands a compressed dictionary entry into caller-provided buffers. |
| `3000:B4D4` | Binary-searches compressed word pages for the query word. |
| `3000:A1AA` | Builds candidate metadata and per-candidate record-pointer arrays from packed dictionary records. |
| `3000:A45C` | Builds the selected candidate's related-word pointer list and string pool for Thesaurus/meaning expansion. |
| `3000:A6A2` | Copies or normalizes related-word text into the shared output string pool, splitting on internal `0x0E` and `/` separators. |
| `3000:A7C2` | Chooses a related record pointer from small threshold/pointer tables, with special type remaps through `3000:83E4`. |
| `3000:AA54` | Tests whether a slash/compound-separated expanded string already contains a target fragment. |
| `3000:8B0A` | Decodes the current page edit stream at `dict[0x26]` into the staged word buffer and updates the stream cursor. |
| `3000:8F06` | Advances from the current page edit-stream record to the next materialized word, loading the next page when needed. |
| `3000:89E2` | Loads dictionary page `dict[0x22] + [8A5A]` into `0x864E`. |
| `3000:8A0E` | Post-processes the staged word ending at `8AB2`, producing the compact class/output buffer at `8AA4`. |
| `3000:AB4C` | Resolves a dictionary entry position by loading a 1 KiB compressed page and scanning expanded entries. |
| `3000:AC48` | Expands a packed 17-bit record pointer into caller text, either by copying from the resident word table or by loading a 1 KiB dictionary page. |

## Candidate List Manager

The rough block after the stream reader begins with real code. `3000:66D4`
initializes the high-level candidate/suggestion state:

Detailed service-facing disassembly for the candidate manager is maintained in
[`disassembly/banked-candidate-manager.md`](disassembly/banked-candidate-manager.md).

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
| `0x7730`/`0x7734`/`0x7736`/`0x7738`/`0x773A` | Dictionary header-derived widths/pointers used by packed record and line-list readers. |
| `0x7750..0x7756` | Current packed record bitmask/stream-position fields loaded by `3000:A1AA` and tested by related-word filters. |
| `0x7762` | Candidate/search mode. Values `2`, `4`, and `7` are accepted by `3000:A45C`; other modes reject related-word expansion. |
| `0x7764..0x7767` | Candidate class/count and current normalized candidate word buffer. |
| `0x77C7..0x77FF` | Per-candidate saved pointers, record pointers, and stream positions used while walking packed records. |
| `0x7940..0x7953` | Scratch state for packed candidate class bits, output-pool bounds, and temporary record-pointer arrays during related-word expansion. |

Service-facing helpers around `3000:5016..5216` wrap this candidate manager.
`3000:5016` initializes the candidate state through `3000:66D4`. The following
helpers expose candidate counts and formatted output by calling `3000:673A`,
`3000:677A`, `3000:67E8`, `3000:685E`, `3000:687C`, and `3000:6892`.
The selected-number helper `3000:5026` receives a one-based result number,
rewinds the candidate cursor, advances to that candidate, and emits the
candidate's related-word list as comma-separated text through `3000:6892`.

Small helpers around `3000:677A..688F` copy the active candidate, move to the
next/previous candidate, and return the current candidate's first or later
space-separated fields. `3000:6892` lazily builds an auxiliary related-word
list on first use: when `[7130] == 0`, it calls `3000:A45C([712E]+1, &7130)`,
resets `[6E5C]` to `FFFF`, then walks the word-pointer array at `[7130]`.
Each nonzero word in that array points at a NUL-terminated string in a RAM
string pool; `3000:6892` copies one string to the caller and returns its
length. `3000:690A` is the reverse-walk companion for the same pointer list.

`3000:A45C` is now the main confirmed Thesaurus/meaning expansion builder. It
takes a one-based result number, rejects it if it is outside `[7764]`, and only
continues when the candidate/search mode in `[7762]` is `2`, `4`, or `7`. It
then:

- calls `3000:A1AA` to load packed metadata for the selected result,
- chooses threshold and record-pointer state through `3000:A7C2`,
- expands packed record pointers through `3000:AC48`,
- normalizes/copies candidate text through `3000:A6A2`, and
- writes a zero-terminated word-pointer list followed by a shared string pool.

The pointer list is returned through the caller pointer argument, which is
`0x7130` in the Thesaurus path. The first word in the list is initialized from
`[7943]`, and later entries are taken from the string-pool cursor `[794A]`.
The string-pool cursor is bounded by `[794C]`; if an appended string would
reach or exceed that bound, `3000:A45C` aborts by returning `0`.

`3000:A1AA` is the deeper packed-record reader. It reads bit fields through
`3000:ADBE`, loads compressed pages through `3000:B076` as needed, and builds
temporary candidate/record arrays around `0x77C7`, `0x77E8`, `0x7943`,
`0x7946`, `0x794E`, and `0x7950`. In the normal UI-facing case it also formats
candidate display text through `3000:6964`; in the Thesaurus related-word case,
`3000:A45C` consumes the arrays directly and builds the related-word list.

Three call sites currently reach `3000:A1AA`:

| Caller | Fourth argument | Working mode |
| --- | ---: | --- |
| `3000:98F8` | `2` | Visible candidate/result-list construction from `3000:9848`. This path can call `A1AA` repeatedly while advancing a caller-provided result count. |
| `3000:9F09` | `1` | Packed-record skip/scan path. The caller accumulates offsets with `3000:ADBE` and helper `3000:9F14`, stores the stream position in `7758:775A`, then enters `A1AA`. |
| `3000:A4B9` | `0` | Full selected-result expansion used by `3000:A45C` for Thesaurus related words. |

The first field read by `A1AA` is `dict[0x36]` bits wide:

```asm
3000:A265  push word [7736]
3000:A269  call 3000:ADBE
3000:A26F  mov [7940],al
3000:A274  and ax,00F0
3000:A279  shr ax,4
3000:A27B  mov [bp-0D8],ax
3000:A27F  and byte [7940],0F
```

So the low nibble in `[7940]` is the selected record class used by filters and
by `3000:A7C2`; the high nibble is a small mask/index passed to `3000:A7A0`.
`A7A0` scans for the next set bit and returns a one-based slot number, which
decides which candidate bucket receives following packed counts. The per-bucket
counts live at `7942 + bucket`, although the current firmware configuration
only loops over one bucket in this path.

After that class byte, `A1AA` reads repeated 4-bit count chunks. Each chunk is
added to the current bucket count; a chunk value of `0x0F` is an extension
marker, so chunks continue until a non-`0x0F` nibble appears. Later in the full
mode, it reads up to `0x28` packed record pointers using `dict[0x34]` bits
each and stores them as dwords at the temporary array `[7950]`.

`3000:AC48` is the first concrete consumer of those packed record pointers in
the Thesaurus builder. `A45C` passes it a 17-bit value: the low word plus bit 0
of the high word. `AC48` splits that value this way:

```text
page_index = packed_pointer >> 9
low_part   = packed_pointer & 0x01FF
```

`page_index` must be below `dict[0x0C]`. It is also stored in `[8A5A]` for
later helpers. If `low_part == 0`, `AC48` takes the fast path: it treats
`dict[0x18]` as a resident word-pointer table and copies entry `page_index`
directly to the caller.

If `low_part != 0`, `AC48` loads logical dictionary page
`(dict[0x22] + page_index) * 0x400` through `3000:66AE`/`3000:660F`, staging
the page at `0x864E`. It divides `low_part` by `dict[0x06]` and caps the
quotient at seven, then walks that many page records by adding each record's
lead byte plus `dict[0x06]`. The final record pointer is stored at `dict[0x26]`
and the base word copied from `dict[0x18][page_index]` is staged at `0x8A5C`.
The normal dictionary expansion helpers `3000:8B0A` and `3000:8F06` then walk
within that page until the selected inline record has been materialized.

`3000:8B0A` materializes the word at the current page edit-stream cursor. It
uses `dict[0x26]` as the source cursor, `[8AB2]` as the destination cursor into
the staged word buffer, and then writes both values back before returning:

```asm
3000:8B17  mov di,[8AB2]
3000:8B1B  mov ax,[7528]   ; dict[0x26]
...
3000:8B6B  mov [8AB2],di
3000:8B72  mov ax,[bp-08]
3000:8B76  mov [bx+26],ax  ; dict[0x26]
3000:8B79  call 3000:8A0E
```

The edit stream is byte-coded. Literal-ish bytes below the current dictionary
threshold at `[8A50]+4` are copied directly. Other token ranges either copy
two-byte fragments from `dict[0x16]`, copy bytes from later stream positions,
or stop the current word when a zero token is reached. `0xFF` acts as an
escape/extended marker in the stream. The final call to `3000:8A0E`
post-processes the staged bytes and builds the compact `8AA4` buffer that
later code uses for record type/class checks.

`3000:8F06` is the next-record stepper for the same page stream. It reads the
current `dict[0x26]` byte. If the byte is zero, `3000:8F98` increments `[8A5A]`
and calls `3000:89E2` to load the next dictionary page at
`(dict[0x22] + [8A5A]) * 0x400`; it then resets `dict[0x26]` to `0x8655` and
copies the new base word from `dict[0x18][8A5A]` into `0x8A5C`. Otherwise,
`8F06` applies one edit-token operation to the staged word buffer, updates
`dict[0x26]`, and re-enters `8B0A` to finish materializing the word.

This means the traced Thesaurus path is currently tied to the confirmed
compressed dictionary stream and its packed record metadata. The low slot-0
page data is still possible common engine data, but this selected-result
Thesaurus expansion path does not yet prove a direct slot-0 page-data read.

`3000:6964` formats numbered suggestion lines. It writes a digit, `") "`,
then formats a candidate based on packed record fields and appends text through
the local string helpers at `3000:960A`, `3000:9626`, and `3000:969E`. Detailed
disassembly for this row formatter is maintained in
[`disassembly/banked-candidate-formatter.md`](disassembly/banked-candidate-formatter.md).
The apparent constants such as `0x24F4`, `0x2508`, and `0x2589` in this
formatter are `DS=3C00` RAM/data-segment pointers, not ROM file offsets.

`3000:6B6C..6ECD` is a parser/search-record formatter. It stores the active
record at `0x7134`, inspects fields like `[record+3]` and `[record+6]`, and
uses `3000:B116` to expand dictionary entries into output buffers. Special
cases combine entries with separators such as `/`, which looks like formatting
compound or alternate forms. Detailed disassembly for this layer is maintained
in
[`disassembly/banked-candidate-record-formatter.md`](disassembly/banked-candidate-record-formatter.md).

## Inflection and Suffix Handlers

The rough block immediately after the candidate formatter is a confirmed
suffix/word-form generation island. These routines mutate candidate text in
scratch buffers, append suffix strings from the `3C00` data segment, and call
`3000:B0E6` to check whether the generated form exists in the dictionary.

`3000:6ECE` dispatches on the final character of the current output word. It
subtracts `'e'` and jumps through an inline table at file `0x37124`, covering
letters `e..z`. Detailed disassembly for this first suffix island is maintained
in [`disassembly/banked-suffix-dispatch.md`](disassembly/banked-suffix-dispatch.md):

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
| `0x37150..0x373F2` | Suffix handlers including a `3000:7164` path for final `c/e/l/y` cases and a `3000:721C` path that dispatches through `a..y`; detailed in [`disassembly/banked-suffix-secondary.md`](disassembly/banked-suffix-secondary.md). |
| `0x373F2..0x37424` | Inline `a..y` jump table for `3000:721C`. |
| `0x37424..0x37636` | Continuation of suffix handling, including another large final-letter dispatcher at `3000:748E`; detailed in [`disassembly/banked-suffix-tertiary.md`](disassembly/banked-suffix-tertiary.md). |
| `0x37636..0x37666` | Inline `b..y` jump table for `3000:748E`; documented in [`disassembly/banked-suffix-tertiary.md`](disassembly/banked-suffix-tertiary.md). |
| `0x37666..0x37724` | Candidate-combination helper used by the suffix handlers; documented in [`disassembly/banked-suffix-tertiary.md`](disassembly/banked-suffix-tertiary.md). |
| `0x37724..0x378CE` | Additional suffix handler using record type `0x0B` and strings in the `3C00` data segment; detailed in [`disassembly/banked-suffix-extended.md`](disassembly/banked-suffix-extended.md). |
| `0x37F66..0x37F96` | Inline `c..z` jump table used by `3000:7E12`; documented in [`disassembly/banked-suffix-final-letter-extended.md`](disassembly/banked-suffix-final-letter-extended.md). |
| `0x37F96..0x38232` | Extended suffix/word-form helpers including `3000:7F9C`, `3000:7FD4`, and `3000:8056`; detailed in [`disassembly/banked-suffix-final-letter-extended.md`](disassembly/banked-suffix-final-letter-extended.md). |
| `0x38232..0x38264` | Inline `a..y` jump table used by `3000:8056`; documented in [`disassembly/banked-inflection-helper-tail.md`](disassembly/banked-inflection-helper-tail.md). |
| `0x38264..0x384A8` | Tail helpers for doubled-letter, final-vowel, and pattern-constrained candidate forms; detailed in [`disassembly/banked-inflection-helper-tail.md`](disassembly/banked-inflection-helper-tail.md). |
| `0x384A8..0x38854` | Compound rewrite, visible-space multiword expansion, array compaction, and `0x0E` marker rewriting; detailed in [`disassembly/banked-multiword-expansion.md`](disassembly/banked-multiword-expansion.md). |
| `0x38854..0x38A0E` | Dictionary stream initializer, header/table loader, string pointer-table builder, and 1 KiB page loader; detailed in [`disassembly/banked-dictionary-stream-init.md`](disassembly/banked-dictionary-stream-init.md). |

The combination helper at `3000:7686` copies two candidate fragments into
scratch buffers, inserts byte `0x0E` as a separator when both fragments are
non-empty, and checks the combined result through `3000:B0E6`. This matches the
formatter's earlier use of separator-like bytes in compound or alternate
candidate output.

The constants used by these handlers are in the low `3C00` ROM window:

| Data offset | File offset | Contents |
| ---: | ---: | --- |
| `3C00:2435..25CF` | `0x3E435..0x3E5CF` | Part-of-speech labels, inflection labels, and suffix strings such as `able`, `ses`, `xes`, `zes`, `ally`, `dge`, `est`, `more `, `er`, and `most `. |
| `3C00:2A1E..2AD5` | `0x3EA1E..0x3EAD5` | Eight-byte suffix pattern records searched by `3000:7DCA`. |
| `3C00:2AD6..2B22` | `0x3EAD6..0x3EB22` | Suffix-pattern string pool including `man`, `um`, `us`, `be`, `al`, `le`, `est`, `er`, `ie`, `ing`, `ate`, and ` or `. |
| `3C00:2B26..2B2E` | `0x3EB26..0x3EB2E` | Bit masks used by the compressed bitstream readers. |

These routines probably support both spelling suggestions and grammar-related
word-form checks, but the confirmed behavior at this point is narrower:
candidate inflection, suffix transformation, and dictionary validation.

## Candidate Expansion and Record Dispatch

`3000:79E8` chooses the single-word or multiword candidate expansion path.
`3000:7A1E` is the single-word dispatcher: it starts by expanding the caller's
candidate with `3000:B116`, translates the returned record class through
`3000:83E4`, and stores the active record pointer at `3C00:7180`. Detailed
disassembly is maintained in
[`disassembly/banked-candidate-expansion-dispatcher.md`](disassembly/banked-candidate-expansion-dispatcher.md).

For ordinary single-word forms it calls `3000:8438` to append output pointers
and record pointers to parallel arrays supplied by the caller. When direct
expansion fails, it uses `3000:7DCA` to look up a suffix pattern in the
`3C00:2A1E` data table. The matched pattern's record-kind byte selects one of
11 handlers through the inline jump table at file `0x37D0E`. Detailed
disassembly for the table and pattern scanner is maintained in
[`disassembly/banked-suffix-pattern-records.md`](disassembly/banked-suffix-pattern-records.md):

| Record kind | Handler |
| ---: | --- |
| `0x00` | `3000:7B7E` |
| `0x01` | `3000:7BB6` |
| `0x02` | `3000:7BC8` |
| `0x03` | `3000:7BD0` |
| `0x04` | `3000:7BD8` |
| `0x05` | `3000:7CC2` |
| `0x06` | `3000:7CCA` |
| `0x07` | `3000:7CE0` |
| `0x08` | `3000:7CE6` |
| `0x09` | `3000:7CEC` |
| `0x0A` | `3000:7CF8` |

The handlers call the same suffix helpers described above, use `3000:B0E6` for
dictionary validation, and maintain the candidate pointer/type arrays. The
array helper at `3000:87D6` removes entries by shifting both arrays together.

The separator byte `0x0E` is treated as an internal compound/alternate marker.
`3000:78CE` scans candidate text for `0x0E` or `/`, expands each fragment with
`3000:B116`, and rebuilds the candidate; detailed disassembly is maintained in
[`disassembly/banked-compound-normalizer.md`](disassembly/banked-compound-normalizer.md).
`3000:8808` performs the inverse-style string rewrite: it copies a candidate
into a scratch buffer and replaces every `0x0E` marker with a caller-provided
string. Detailed disassembly for `3000:8808` is maintained in
[`disassembly/banked-multiword-expansion.md`](disassembly/banked-multiword-expansion.md).

`3000:79E8` chooses between the normal expansion path at `3000:7A1E` and the
multiword path at `3000:8528` by checking whether the candidate contains a
space. `3000:8528` splits a space-separated candidate, recursively expands each
part through `3000:7A1E`, and then stitches the resulting pointer/type arrays
back together. This makes the candidate machinery explicitly handle both
compound markers and visible space-separated multiword forms. Detailed
disassembly for `3000:84A8`, `3000:8528`, and the local array helpers is
maintained in
[`disassembly/banked-multiword-expansion.md`](disassembly/banked-multiword-expansion.md).

## Working Interpretation

The code around `3000:46FC..4BFA` has spelling/grammar/linguistic behavior:

- It processes character streams through tables at offsets like `3000:09D8`,
  `3000:116A`, and `3000:12E4`.
- It tracks word/parser state around `3C00:6D7A`, `6D7C`, `6D80`, and `6DA4`.
- It exposes diagnostic clear/reset services through IDs `0x58` and `0x59`;
  those service bodies are now bottomed in
  [`disassembly/diagnostic-spell-services.md`](disassembly/diagnostic-spell-services.md).

This is enough to call `3000:0000` the banked spelling/grammar/linguistic
service thunk. Individual service IDs still need names beyond the confirmed
diagnostic, startup, and editor-facing cases.
