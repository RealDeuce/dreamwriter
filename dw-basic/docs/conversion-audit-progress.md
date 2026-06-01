# DW-BASIC MASM-to-NASM Conversion Audit Progress

Purpose: line-by-line validation of every auto-converted file in `dw-basic/src/gw`
against its MASM source in `gw-basic`.

Status key:
- `pending`: not assigned yet
- `in_progress`: assigned or actively being reviewed
- `complete`: reviewed line-by-line; findings recorded

## Fix Coverage

- Fixed in `tools/masm2nasm.py`: inherited initial radix support for standalone
  `math2.asm`, CS override preservation for `XLAT BYTE PTR ?CSLAB`,
  MASM boolean `AND`/`OR` expression conversion, location-count assignments
  such as `CTLCNT=$-CTLITB`, MASM indexed memory syntax normalization, MASM
  `PROC`/`ENDP` scaffolding removal, and `END <entry>` scaffolding removal.
- Fixed in `tools/masm2nasm.py`: bare MASM data-symbol operands now account for
  DSEG extern declarations and label-prefixed converted instruction lines.
  This covers the recorded `maclng.asm`, `dskcom.asm`, `advgrp.asm`, and
  `gwmain.asm` missed memory-load findings.
- Fixed in `tools/gwram_tables.py`: `R1` now exports a `$-1` alias before the
  reserved word, `PDIRAM` now models the first initialization-block expansion
  and second active-page labeled expansion, and RAM macro reservations now use
  `resb` instead of initialized zero bytes.
- Fixed in `tools/gwdata_tables.py`: MASM `DB`/`DW ... DUP(?)` reservations in
  `gwdata.asm` now emit `resb`/`resw` instead of initialized zero data,
  including generated table reservations and the `USRTAB`, `KBUF`, `BUF`,
  `TEMPST`, `DSCTMP`, `PARM1`, and `PARM2` regions.
- Fixed in `tools/gwdata_tables.py`: the `gwdata.asm` low-data phase now
  materializes `DUP(?)` placeholders from matching source-phase initializers
  when the original source relied on ROM-copy startup initialization. This
  covers runtime bytes such as `NUMCON`'s fake `CONCON`/`CONCN2` CHRGET stream,
  `RNDX`, `USRTAB`, printer defaults, and related low-data defaults while
  preserving truly unknown storage as `resb`/`resw`.
- Fixed in `src/gw/bimisc.asm`: the DreamWriter OEM profile currently has no
  event traps (`NUMTRP == 0`), so `INITRP` now skips the trap-table clearing
  loop and clears only `ONGSBF`. The unguarded source loop used `CH=NUMTRP`;
  with zero traps that wrapped to 256 iterations and zeroed code following
  `TRPTBL`, including `CLS`, `LOCATE`, and `COLOR`.
- Documented memory-model policy in `docs/memory-model.md`: `flat64` is the
  current build target, `split128` is reserved for a future separate
  code/data overlay, `GW_BASIC_MIN_FREE` is part of the flat64 workspace
  contract, and any flat64 feature omissions should be explicit named profile
  choices rather than converter side effects.
- Regenerated affected converted sources and verified `gw-objects` and
  `gw-basic-bin` build successfully after these fixes.

## Files

| File | Status | Notes |
| --- | --- | --- |
| advgrp.asm | complete | agent explicit full line-by-line audit; conversion defects found |
| biboot.asm | complete | agent audit; conversion defect found |
| bimisc.asm | complete | agent audit; NUMTRP zero-loop defect |
| biprtu.asm | complete | agent audit; no functional defects found |
| biptrg.asm | complete | agent audit; no functional defects found |
| bistrs.asm | complete | local audit; public absolute export defect |
| call86.asm | complete | agent audit; comment-only mismatch |
| dskcom.asm | complete | local audit; bare data-symbol load defects |
| fiveo.asm | complete | explicit full line-by-line recheck; no conversion defects found |
| gengrp.asm | complete | agent audit; no functional defects found |
| gio86.asm | complete | local explicit full line-by-line audit; ROM-vector stub delta |
| giocas.asm | complete | local audit; no conversion defects found |
| giocom.asm | complete | local audit; latent COM device-code dependency |
| giocon.asm | complete | local audit; no conversion defects found |
| giodsk.asm | complete | agent explicit full line-by-line audit; conversion defects found |
| giokyb.asm | complete | local audit; OEM config trap-count delta |
| giolpt.asm | complete | agent audit; conversion defect found |
| gioscn.asm | complete | agent audit; latent expression mismatch |
| giotbl.asm | complete | local audit; hand-written port semantic differences |
| gwdata.asm | complete | agent explicit full line-by-line audit; layout/export deltas found |
| gweval.asm | complete | agent explicit full line-by-line audit; export-model deltas only |
| gwinit.asm | complete | agent audit; public end-marker export defect |
| gwlist.asm | complete | explicit full line-by-line recheck; no conversion defects found |
| gwmain.asm | complete | agent explicit full line-by-line audit; conversion defects found |
| gwram.asm | complete | agent audit; conversion defects found |
| gwsts.asm | complete | agent explicit full line-by-line audit; source-equivalence deltas found |
| ibmres.asm | complete | explicit full line-by-line recheck; findings found |
| itsa86.asm | complete | agent audit; flat-ROM stubs not source-equivalent |
| kanj86.asm | complete | local audit; no conversion defects found |
| maclng.asm | complete | local audit; conversion defects found |
| math1.asm | complete | agent explicit full line-by-line audit; XLAT CS override defect |
| math2.asm | complete | agent explicit full line-by-line audit; radix conversion defects found |
| next86.asm | complete | agent audit; no functional defects found |
| scndrv.asm | complete | agent explicit full line-by-line audit; CTLCNT conversion defect |
| scnedt.asm | complete | agent audit; no conversion defects found |

## Findings

Findings will be recorded here as each file completes.

### maclng.asm

Reviewed MASM source `gw-basic/maclng.asm` lines 1-258 against converted
`dw-basic/src/gw/maclng.asm` lines 1-237.

Findings:
- `gw-basic/maclng.asm:64` `MOV BX,MCLTAB` is a MASM memory load from the
  `MCLTAB` word variable. Converted `dw-basic/src/gw/maclng.asm:61` is
  `MOV BX,MCLTAB`, which is a NASM immediate symbol load. It should be a memory
  load, e.g. `MOV BX,word [MCLTAB]`.
- `gw-basic/maclng.asm:123` `MOV BX,MCLPTR` similarly became
  `dw-basic/src/gw/maclng.asm:117` `MOV BX,MCLPTR`; should load `[MCLPTR]`.
- `gw-basic/maclng.asm:138` `MOV BX,MCLPTR` similarly became
  `dw-basic/src/gw/maclng.asm:131` `MOV BX,MCLPTR`; should load `[MCLPTR]`.
- `gw-basic/maclng.asm:192` `MOV BX,MCLPTR` similarly became
  `dw-basic/src/gw/maclng.asm:180` `MOV BX,MCLPTR`; should load `[MCLPTR]`.
- `gw-basic/maclng.asm:238` `MOV BX,MCLPTR` similarly became
  `dw-basic/src/gw/maclng.asm:222` `MOV BX,MCLPTR`; should load `[MCLPTR]`.

Other checked conversions in this file matched MASM intent: segment wrappers
were removed, public/extrn declarations became `global`/`extern`, `OFFSET`
operands became immediates, `INS86 56` became `db 0o56`, `INS86 367,332`
became `db 0o367, 0o332`, and MASM byte memory stores/loads were bracketed
where the converter recognized explicit `BYTE PTR`.

### biboot.asm

Agent-reviewed MASM source `gw-basic/biboot.asm` lines 1-74 against converted
`dw-basic/src/gw/biboot.asm` lines 1-57.

Finding:
- `gw-basic/biboot.asm:73` `END BIBOOT` is a MASM end-of-source/entry-point
  directive. Converted `dw-basic/src/gw/biboot.asm:56` leaves `END BIBOOT` as
  active NASM source, which is invalid unless a macro happens to define it.
  It should be omitted or converted to a comment/build entry mechanism.

Other checked conversions in this file matched MASM intent: includes,
`CPM86`, comments, `extern START`, `BIBOOT`, instructions, operands, octal
constant `200O` to `0o200`, `PUBLIC LSTVAR` to `global LSTVAR`, and
`LSTVAR LABEL WORD` to `LSTVAR:`. MASM-only `SEGMENT`, `ENDS`, `ASSUME`,
`PAGE`, `.SALL`, `TITLE`, `SUBTTL`, and comment-block syntax were acceptably
omitted or commented.

### giocas.asm

Reviewed MASM source `gw-basic/giocas.asm` lines 1-32 against converted
`dw-basic/src/gw/giocas.asm` lines 1-20.

No conversion defects found. Segment/assume/end scaffolding and `.SALL` were
omitted as expected, includes became `dwoem.inc`, `gio86u.inc`, and
`msdosu.inc`, `EXTRN DERDNA:NEAR` became `extern DERDNA`, `PUBLIC MOTOR`
became `global MOTOR`, and `MOTOR: JMP DERDNA` was preserved.

### kanj86.asm

Reviewed MASM source `gw-basic/kanj86.asm` lines 1-43 against converted
`dw-basic/src/gw/kanj86.asm` lines 1-30.

No conversion defects found. Segment/assume/end scaffolding and `.SALL` were
omitted as expected, includes became `dwoem.inc`, `gio86u.inc`, and
`msdosu.inc`, the false `IF CPM86 INCLUDE CPM86U ENDIF` block became a NASM
`%if CPM86` block containing only a TODO comment, public labels were preserved
as `global` plus labels, and `EXTRN SNERR:NEAR` / `JMP SNERR` were converted
correctly.

### giocon.asm

Reviewed MASM source `gw-basic/giocon.asm` lines 1-119 against converted
`dw-basic/src/gw/giocon.asm` lines 1-100.

No conversion defects found. Segment/assume/end scaffolding, `.SALL`, and
listing directives were omitted as expected. Includes, `CPM86`, publics,
externs, dispatch-table `DW` entries, labels, constants (`LOW OFFSET MD_SQO`,
`255D`, `LOW 0`, `LOW 255D`), `CALLOS C_DCIO` to `mov ah, C_DCIO` / `int 33`,
and `JMP PDCBAX` all match MASM intent.

### giolpt.asm

Agent-reviewed MASM source `gw-basic/giolpt.asm` lines 1-354 against converted
`dw-basic/src/gw/giolpt.asm` lines 1-328.

Findings:
- `gw-basic/giolpt.asm:153` `MOV AH,LOW OFFSET MD_SQO OR MD_RND` should load
  the immediate mask value `MD_SQO OR MD_RND` (`2 | 4`). Converted
  `dw-basic/src/gw/giolpt.asm:135` is `MOV AH,MD_SQO OR [MD_RND]`, introducing
  a bogus memory reference and invalid NASM syntax. Functional conversion
  defect.
- Comment-only mismatch: `gw-basic/giolpt.asm:3` `.RADIX 8 ; To be safe`
  became `dw-basic/src/gw/giolpt.asm:5` `; .RADIX 8`, dropping the inline
  comment.

Other checked conversions in this file matched MASM intent: labels,
globals/externs, dispatch table words, DCB offsets, byte/word memory operands,
constants, error-code table bytes, device symbol renames such as `$_LPT1` to
`DOL__LPT1`, and MASM-only directive omissions/comments.

### next86.asm

Agent-reviewed MASM source `gw-basic/next86.asm` lines 1-159 against converted
`dw-basic/src/gw/next86.asm` lines 1-162.

No functional conversion defects found. Comment-only mismatch: source line 3
`.RADIX 8 ; To be safe` became converted line 5 `; .RADIX 8`, dropping the
inline comment. MASM segment/assume/end/listing scaffolding was omitted as
expected, include/public/extern handling matched, `SHORT` qualifiers were
omitted without changing assembled short jump encodings, memory-vs-immediate
semantics were preserved, and octal/`LOW` idioms were converted correctly.

### scnedt.asm

Agent-reviewed MASM source `gw-basic/scnedt.asm` lines 1-462 against converted
`dw-basic/src/gw/scnedt.asm` lines 1-404.

No functional conversion defects found. Reviewed sections covered headers,
includes, directives, publics/externs, constants, `PINLIN`/`QINLIN`/`INLIN`,
the editor loop, `SCNSEM`, `INLRET`, `EDTBRK`, `CLRFLG`, `EDIT`, help edit,
`ERREDT`, ASCII load/save handlers, and `OUTCH1`. MASM scaffolding was omitted
as expected, `LOW`/`OFFSET`/numeric suffixes and `BYTE PTR`/`WORD PTR` were
preserved correctly, and bare symbols such as `BUF`, `KBUF`, `CHRRET`,
`CHRLNF`, `CHRAPP`, and `BUFLEN` were verified as immediates/equates rather
than missed memory loads.

### gioscn.asm

Agent-reviewed MASM source `gw-basic/gioscn.asm` lines 1-327 against converted
`dw-basic/src/gw/gioscn.asm` lines 1-285.

No functional conversion defects found in emitted executable/data code. Latent
non-functional mismatch:
- `gw-basic/gioscn.asm:31` `FKFSRL=(SCROLT-1) AND 1` became
  `dw-basic/src/gw/gioscn.asm:23` `%define FKFSRL (SCROLT-0o1) AND 0o1`; MASM
  `AND` was not converted to NASM `&`. The symbol is unused in this converted
  file, so no current code/data effect.

Other checked conversions matched MASM intent: dispatch table entries, labels,
public/global entry points, `$CATTY` to `DOL_CATTY`, instructions, operands,
branch targets, memory references, immediates, `LOW`/`OFFSET` constants,
`BYTE PTR`/`WORD PTR` forms, `F_WID[SI]`, and short jump handling.

### call86.asm

Agent-reviewed MASM source `gw-basic/call86.asm` lines 1-94 against converted
`dw-basic/src/gw/call86.asm` lines 1-91.

No functional conversion defects found. One comment-preservation mismatch:
`gw-basic/call86.asm:3` `.RADIX 8 ; To be safe` became
`dw-basic/src/gw/call86.asm:5` `; .RADIX 8`, dropping the inline comment.
Includes, publics/externs, labels, instructions, operands, data/raw opcode
handling, and radix-sensitive constants were checked and matched MASM intent.

### gwram.asm

Agent-reviewed MASM source `gw-basic/gwram.asm` lines 1-466 against converted
`dw-basic/src/gw/gwram.asm` lines 1-343.

Findings:
- Source lines 57-67, consumed at 384-385, define `R1` labels one byte before
  the reserved word using `ORG $-1` / `ORG $+1`. Converted lines 28-34 label
  the current byte instead. This breaks `MAXUPD+1` / `MINUPD+1`, whose
  consumers store/call through those `+1` addresses.
- Source lines 315 and 336 invoke `PDIRAM` under different `RINIT` definitions,
  using macro phases at 308-327 and body lines 272-273. Converted lines 36-42
  add a one-shot `%ifndef` guard, label `KEYSW` during the first invocation,
  and suppress the second expansion. Under literal source macro semantics this
  moves `KEYSW` and following page-dependent data one byte earlier.
- Source uninitialized `DB SIZE DUP(?)` reservations at lines 64-66, 74-76,
  348-350, and 364-366 became converted `R`/`R1` macro output using
  `times %2 db 0` at lines 23-24 and 31-32. That changes uninitialized RAM
  declarations into image-initialized data.
- `$DATE` is public in source lines 27 and 38. Converted lines 67-68 and 75
  rename the label to `DOL_DATE` but do not export it.
- `FOPTSZ` is a public absolute in source lines 423-424. Converted lines
  306-307 use `global FOPTSZ` plus `%assign FOPTSZ 64`, which does not emit or
  export an object symbol like an `equ`-style symbol.
- Source macro size accounting and `%OUT *FATAL RINIT ERROR*` layout checks at
  lines 79-88, 308-327, and 341-373 are omitted in the conversion. This is not
  runtime code, but it removes layout validation and contributes to the macro
  layout drift above.

Validated as equivalent/non-defective: string bytes, CR/LF expansion,
octal/decimal constants, soft-key table bytes, `OFFSET CR` / `OFFSET QUOTE`
data-byte idioms, and ordinary data labels apart from the issues above. This
file contains no executable instruction operands.

### giotbl.asm

Reviewed MASM source `gw-basic/giotbl.asm` lines 1-124 against hand-written
port file `dw-basic/src/gw/giotbl.asm` lines 1-44.

This file is explicitly not a literal converter output: converted lines 1-5
state that it is hand-written because the upstream source is a MASM macro table
for a configurable DOS/CP/M device set, while this port exposes only the
console keyboard/screen devices during first bring-up.

Findings:
- Source line 35 publishes `_DVTBL`, `_DVPTR`, `_DVINI`, `_DVTRM`, and `$_NDEV`.
  Converted lines 19-22 publish the four tables but not an equivalent exported
  `DOL__NDEV` symbol; `DOL__NDEV` currently lives as `%define DOL__NDEV 3` in
  `dw-basic/src/include/dwoem.inc`.
- Source lines 103-105 make `_DVPTR[0]` the disk dispatch table, `DSKDSP`,
  followed by the non-disk device dispatch entries. Converted lines 30-34 make
  `_DVPTR[0]` `_RET`, followed by `KYBDSP`, `SCNDSP`, and `CONDSP`. That may be
  intentional for first bring-up with disk omitted, but it is not source
  equivalent.

Validated as equivalent under the current DreamWriter config: `NMLPT=0`,
`GWCASS=0`, and `NMCOMT=0` mean the source `NAMES` macro expands only `KYBD`,
`SCRN`, and `CONS`; converted lines 24-28 emit those same three device names
with IDs matching `DOL__KYBD=0o377`, `DOL__SCRN=0o376`, and `DOL__CONS=0o375`.
The `_DVINI` and `_DVTRM` entries also match those three non-disk devices.

### giocom.asm

Reviewed MASM source `gw-basic/giocom.asm` lines 1-865 against converted
`dw-basic/src/gw/giocom.asm` lines 1-812.

Finding:
- `gw-basic/giocom.asm:32` declares `$_COM1:NEAR`, and line 861 uses
  `OFFSET ($_COM1-400O)` to compute a COM unit id from a device id. Converted
  lines 25 and 811 use `extern DOL__COM1` and `DOL__COM1-0o400`, but the
  current DreamWriter `dwoem.inc` defines only `DOL__KYBD`, `DOL__SCRN`,
  `DOL__CONS`, `DOL__LPT1`, and `DOL__NDEV`; there is no `DOL__COM1`. With
  `NMCOMT=0` this is latent unless COM code is linked or reached, but it is not
  a complete source-equivalent conversion of the COM device-code dependency.

Other checked conversions matched MASM intent: segment and listing scaffolding
were omitted/commented, includes and globals/externs were converted, dispatch
table words and labels were preserved, DCB offset constants retained their
values, octal/decimal constants were converted correctly, explicit
`BYTE PTR`/`WORD PTR` memory references were bracketed, `OFFSET` constants were
kept as immediates, short jumps were relaxed without changing control flow,
error-code labels were mapped to `ERRC_` constants, and COM parsing/input/output
paths preserved their register and stack behavior. Comment-only mismatch:
`.RADIX 8 ; To be safe` again lost the inline `; To be safe` comment.

### biprtu.asm

Agent-reviewed MASM source `gw-basic/biprtu.asm` lines 1-469 against converted
`dw-basic/src/gw/biprtu.asm` lines 1-460.

No functional conversion defects found. The converted module assembled cleanly
with `nasm -f obj -I src/include/`, and regenerating it with
`tools/masm2nasm.py` produced an identical file.

Non-functional mismatches: converted lines 1-2 add generator scaffolding, MASM
segment/listing/end scaffolding is omitted or commented as expected,
`EXTRN` groups and type qualifiers are split/dropped for NASM, comment
indentation/blank lines are collapsed, and `SHORT` branch qualifiers are
dropped with unchanged branch targets.

Verified equivalence classes: public/extern handling, octal/decimal constants,
`LOW`/`OFFSET`/character literals/expression operators, bare data-symbol memory
operands such as `FACLO` and `USFLG`, `BYTE PTR` memory forms, generated
labels and `$+3` skip idioms, `DB 276O` opcode byte preservation, and the
string-field/numeric-field/scientific-notation formatting paths.

### biptrg.asm

Agent-reviewed MASM source `gw-basic/biptrg.asm` lines 1-693 against converted
`dw-basic/src/gw/biptrg.asm` lines 1-697.

No functional conversion defects found. The converted module assembled cleanly
with `nasm -f obj -I dw-basic/src/include/`.

Non-functional mismatches: converted lines 1-2 add generator scaffolding, and
source line 3 `.RADIX 8 ; To be safe` became converted line 5 `; .RADIX  8`,
dropping the inline `; To be safe` comment.

Verified equivalence classes: MASM scaffolding removal/commenting,
`PUBLIC`/`EXTRN` handling including `$DZERO` to `DOL_DZERO`, bare data-symbol
memory operands such as `DIMFLG`, `ARYTAB`, `STREND`, `TEMP2`, `TEMP3`,
`NAMCNT`, `NAMTMP`, `OPTVAL`, `VALTYP`, and `PRMLEN`, `OFFSET` immediates and
`ERRBS` to `ERRC_ERRBS`, `LOW`/decimal/octal/character constants, memory
operand sizing, short branch removal, `$+3` skip idioms, raw `DB OFFSET 44` and
`DB 266O`, and variable/allocation paths.

### gengrp.asm

Agent-reviewed MASM source `gw-basic/gengrp.asm` lines 1-569 against converted
`dw-basic/src/gw/gengrp.asm` lines 1-550.

No functional conversion defects found.

Non-functional mismatches: converted lines 1-2 add generator scaffolding, MASM
structural/listing directives are omitted or commented as expected, the
`COMMENT *` block became semicolon comments, formatting/comment columns changed,
and source `INCLUDE OEM.H` maps to `%include "dwoem.inc"` with relevant token
and OEM constants verified.

Verified equivalence classes: public/extern handling, bare data-symbol memory
operands including `GRPACX`, `GRPACY`, `GXPOS`, `GYPOS`, `MAXDEL`, `MINDEL`,
`MAXUPD+1`, `MINUPD+1`, `ATRBYT`, `DRWSCL`, and `DRWANG`, `OFFSET`
immediates, `LOW OFFSET` token constants, decimal/octal constants,
`BYTE PTR` memory operands, short/local jumps and `$+3` idioms, `INS86 321,353`
to `db 0o321, 0o353`, and inline `DB OFFSET` character/token bytes.

### itsa86.asm

Agent-reviewed MASM source `gw-basic/itsa86.asm` lines 1-300 against converted
`dw-basic/src/gw/itsa86.asm` lines 1-280.

Strict source equivalence fails because the public startup mapping routines are
replaced by live flat-ROM stubs and the converted original bodies are renamed
out of the public call path:
- Source lines 121-199 implement `MAPINI` stack/DS relocation, `SEGINI`,
  `CLEARC`, PSP setup, and free-bytes printing. Converted lines 109-111 make
  public `MAPINI` just `RET`; the converted original body starts at line 112 as
  `MAPINI_ORIGINAL`.
- Source lines 218-271 implement `MAPCLC` option validation, `SETCBF`,
  `NEWDS`, `CPMMEM`, and `MSWSIZ` setup. Converted lines 198-204 only set
  `NEWDS = DS` and `MSWSIZ = [MEMSIZ]`, then return; the converted original
  body starts at line 205 as `MAPCLC_ORIGINAL`.

These look deliberate for the flat ROM card build, not mechanical converter
bugs. Excluding those scaffolds, no MASM-to-NASM functional conversion defects
were found in the preserved code.

Non-functional mismatches: converted lines 1-2 add a banner, MASM structural
directives are removed/commented, `.RADIX 8 ; To be safe` loses the inline
comment, `COMMENT *` sentinels are not preserved literally, and inline comment
spacing changes throughout.

Verified equivalence classes: public/extern handling, direct and based memory
operands, `OFFSET` immediates, `LOW` constants, radix handling, labels, calls,
jumps, `REP MOVSW`, arithmetic/tests/shifts, stack ops, and interrupt operands
in the retained original bodies. No `HIGH` operators or active conditional
assembly blocks occur in this file.

### bimisc.asm

Agent-reviewed MASM source `gw-basic/bimisc.asm` lines 1-944 against converted
`dw-basic/src/gw/bimisc.asm` lines 1-899.

Finding:
- Source line 8 includes `OEM.H`, where `NUMTRP` is computed from enabled trap
  switches. Converted line 6 includes `dwoem.inc`, where `NUMTRP` is currently
  `0`. Source line 459 / converted line 459 load `NUMTRP` into `CH`, then the
  loop at source line 461 / converted line 461 is not guarded for zero. A zero
  count therefore means 256 iterations, not none. The same issue appears in
  `GOTRP`: source lines 489-490 / converted lines 487-488.

Aside from this include/config substitution, instruction-level MASM-to-NASM
rewrites in `bimisc.asm` looked correct.

Non-functional mismatches: converted lines 1-2 add generated-source scaffolding,
MASM segment/data blocks and final `END` are omitted/commented, `PAGE`/`SUBTTL`
directives are removed or commented, and comment indentation changes
mechanically.

Verified equivalence classes: public/extern handling apart from the trap-count
constant issue, bare data-symbol memory references, `OFFSET` immediates, `LOW`,
octal/decimal/character constants, `BYTE PTR` operands, `INS86` bytes/words,
short jumps, `$+3` skip idioms, generated labels, and inline `db` skip/data
bytes.

### gwinit.asm

Agent-reviewed MASM source `gw-basic/gwinit.asm` lines 1-456 against converted
`dw-basic/src/gw/gwinit.asm` lines 1-418.

Finding:
- Source lines 451-454 define and publish `$LAST` and `LASTWR` at the current
  location. Converted lines 415-418 use `global DOL_LAST` / `global LASTWR`
  followed by `%define ... $`. `%define` is preprocessor-only, so no label or
  public OMF symbol is emitted. The agent verified the assembled object exports
  only `INIT` and `CMDERR`, not `DOL_LAST` or `LASTWR`.

Intentional ROM-card deltas reviewed: source EXE/DSEG setup is replaced by
flat `DS=ES=CS` setup, source `CPMMEM`/`SEGOFF` sizing is replaced by
the fixed loader ABI limit at `0A4F:DW_LOADER_ABI_LIMIT`, the converted code
forces an empty command tail, and `CALL MAPCLC` is commented/no-op for ROM-card
startup. After accounting for those, no ordinary instruction-level conversion
defects were found.

Non-functional mismatches: converted lines 1-2 add warnings, MASM structural
directives are commented/omitted, and several comments are reflowed or detached
from original instruction lines.

Verified equivalence classes: extern/public handling except the end-marker
defect above, octal/decimal constants, `OFFSET`, `LOW`, character constants,
`DB` operands after `SYNCHR`, bare data-symbol memory references,
`BYTE PTR` memory operands, `INS86` expansions, labels, short branch removal,
and ordinary instruction operands.

### bistrs.asm

Reviewed MASM source `gw-basic/bistrs.asm` lines 1-1110 against converted
`dw-basic/src/gw/bistrs.asm` lines 1-1113.

Finding:
- Source line 50 publishes `INCSTR`, and source lines 524-526 / 649-652 /
  693 use `INCSTR` as an absolute offset into `DSCTMP`. Converted line 86
  declares `global INCSTR`, while converted lines 552-553 and 673-674 define it
  only with `%assign`. Like the other public-absolute cases, this is a
  preprocessor value, not an emitted/exported object symbol. The converted file
  assembles cleanly, but `strings /tmp/bistrs.obj` shows exported labels such
  as `STRPRT`, `FRETM2`, and `LEFTUS`, not `INCSTR`. No external consumer of
  `INCSTR` was found in the current tree, so this is latent unless something
  expects the source public symbol.

No instruction-level MASM-to-NASM functional conversion defects were found.

Non-functional mismatches: converted lines 1-2 add generator scaffolding,
MASM segment/data blocks and final `END` are omitted/commented, `.RADIX 8 ;
To be safe` loses the inline comment, `PAGE`/`SUBTTL` are removed or commented,
and comment indentation/alignment is mechanically changed throughout. The
source label `MID$LP` is converted to `MIDDOL_LP`, matching the project’s
`$`-label rename convention.

Verified equivalence classes: public/extern handling except the `INCSTR`
absolute export issue, device/OEM include substitution without active
conditionals in this file, direct and based memory operands, bare data-symbol
memory loads/stores (`TEMPPT`, `FACLO`, `VALTYP`, `FRETOP`, `MEMSIZ`,
`STREND`, `TEMP9`, `ARYTAB`, `ARYTA2`, `VARTAB`, `TEMP8`, `TXTTAB`),
`OFFSET` immediates, `LOW` constants, octal/decimal/character constants,
raw `DB` skip bytes `260O`/`272O`, `DB OFFSET` parser bytes, generated labels,
`$+3` skip idioms, short branch removal, string temporary/free/garbage
collection paths, string function paths, `INSTR`, `LHSMID`, and `FRE`.

### giokyb.asm

Reviewed MASM source `gw-basic/giokyb.asm` lines 1-891 against converted
`dw-basic/src/gw/giokyb.asm` lines 1-832.

Finding:
- Source line 8 includes `OEM.H`, where `NMKEYT=14`, `IBMLIK=1`, and `SCP=1`.
  Converted line 6 includes `dwoem.inc`, where `NMKEYT=0`, `IBMLIK=0`, and
  `SCP=0`. `IBMCSR` and `INTHND` do not affect emitted code in this file, but
  `NMKEYT` is used in the function-key trap check: source line 370 / converted
  line 348 compare the key index against `NMKEYT`. With `NMKEYT=0`, no function
  key is considered trappable here. This is likely consistent with the current
  DreamWriter “no traps” config, but it is not source-equivalent to `OEM.H`.

No instruction-level MASM-to-NASM functional conversion defects were found.
The converted file assembled cleanly with `nasm -f obj -I dw-basic/src/include/`.

Non-functional mismatches: converted lines 1-2 add generator scaffolding, MASM
segment/data blocks and final `END` are omitted/commented, `.RADIX 8 ; To be
safe` loses the inline comment, `COMMENT *` content becomes ordinary comments,
and comment indentation/alignment changes mechanically.

Verified equivalence classes: dispatch table words, public/extern handling,
queue descriptor/address immediates (`KYBQDS`, `KYBQUE`, `KYBQSZ`), direct
memory references (`CMDOFF`, `SAVKEY`, `SAVKYF`, `MSDCCF`, `SAVSTK`, `SAVTXT`,
`CURLIN`, `F_SUPR`, `DSCPTR`, `FACLO`, `VALTYP`, `CSRTYP`, `CSRFLG`, `F_INST`),
`OFFSET` immediates, `LOW` constants, decimal/octal/character constants,
raw `DB 2EH` segment override, parser/data bytes, `CS:` based table reads,
`$FN`/`$USR` token comparisons mapped to `TOK_FN`/`TOK_USR`, short branch
removal, key queueing, soft-key expansion, `INKEY$`, and cursor support paths.

### dskcom.asm

Reviewed MASM source `gw-basic/dskcom.asm` lines 1-866 against converted
`dw-basic/src/gw/dskcom.asm` lines 1-845.

Findings:
- Bare MASM data-symbol memory loads were converted as NASM immediates:
  - Source line 93 `MOV BX,DSCPTR` loads the string-data pointer stored at
    `DSCPTR`. Converted line 122 `MOV BX,DSCPTR` loads the address of the
    descriptor pointer field. It should load `[DSCPTR]`.
  - Source line 347 `MOV BX,CURLIN` became converted line 364
    `MOV BX,CURLIN`; should load `[CURLIN]`.
  - Source line 381 `MOV BX,TXTTAB` became converted line 398
    `MOV BX,TXTTAB`; should load `[TXTTAB]`.
  - Source line 591 `MOV BX,TEMPB` became converted line 587 `MOV BX,TEMPB`;
    should load `[TEMPB]`.
  - Source line 596 `MOV BX,TEMPA` became converted line 592 `MOV BX,TEMPA`;
    should load `[TEMPA]`.
  - Source line 650 `MOV BX,TXTTAB` became converted line 643
    `MOV BX,TXTTAB`; should load `[TXTTAB]`.
  - Source line 653 `MOV BX,VARTAB` became converted line 646
    `MOV BX,VARTAB`; should load `[VARTAB]`.
  - Source line 667 `MOV BX,STREND` became converted line 658
    `MOV BX,STREND`; should load `[STREND]`.
  - Source line 670 `MOV BX,FRETOP` became converted line 661
    `MOV BX,FRETOP`; should load `[FRETOP]`.
  - Source line 783 `MOV BX,PTRFIL` became converted line 767
    `MOV BX,PTRFIL`; should load `[PTRFIL]`.

The converted file assembled cleanly with `nasm -f obj -I dw-basic/src/include/`,
which is expected because these are semantically wrong immediates rather than
syntax errors.

Other checked conversions matched MASM intent: public/extern handling, segment
scaffolding removal, parser `DB OFFSET` bytes, `LOW` constants, decimal/octal
constants, raw `DB 271O` skip bytes, explicit `BYTE PTR`/word memory operands,
stores to data symbols such as `CURLIN`, `VARTAB`, `TEMPA`, `TEMPB`, `PTRFIL`,
`RUNFLG`, and `NLONLY`, `OFFSET` uses for `BUF`, `FD_SIZ`, `FD_DAT`, and
routine addresses, generated labels, `$+3` skip idioms, short branch removal,
load/run/merge/save flow, `FIELD`, `LSET`/`RSET`, and fixed-length `INPUT$`.

### fiveo.asm

Reviewed MASM source `gw-basic/fiveo.asm` lines 1-821 against converted
`dw-basic/src/gw/fiveo.asm` lines 1-822. Rechecked explicitly line by line
after the scope correction; every source line, including comments, MASM-only
directives, declarations, labels, instructions, data bytes, and final `END`,
was accounted for.

No functional conversion defects found. The converted file assembled cleanly
with `nasm -f obj -I dw-basic/src/include/`.

Non-functional mismatches: converted lines 1-2 add generated-source
scaffolding, MASM segment/data blocks and final `END` are omitted/commented,
`.RADIX 8 ; To be safe` loses the inline comment, `PAGE`/`SUBTTL` directives
are removed or commented, and comment indentation/alignment changes
mechanically. Source `COMMON` is renamed to public `BASIC_COMMON` because
`COMMON` is a NASM directive; current converted references in `gwdata.asm` and
`ibmres.asm` use `BASIC_COMMON`.

Verified equivalence classes: public/extern handling including `CHAIN`,
`CHNRET`, `WRITE`, `SKPNAM`, and `COMMON`/`BASIC_COMMON`; data-symbol memory
references (`ENDFOR`, `SAVSTK`, `CURLIN`, `NXTLIN`, `MRGFLG`, `MDLFLG`,
`OPTFLG`, `TOPTFG`, `OPTVAL`, `TOPTVL`, `CHNLIN`, `CMSPTR`, `CMEPTR`,
`TXTTAB`, `SUBFLG`, `VALTYP`, `ARYTAB`, `VARTAB`, `STREND`, `TEMP3`,
`TEMP9`, `FRETOP`, `SAVFRE`, `CHNFLG`, `NLONLY`, `FACLO`, and `PTRFIL`);
routine/address immediates (`ERRWE`, `COMPT2`, `PTRGTR`, `BCKUCM`, `CAYSTR`);
`$FOR`, `$WHILE`, `$COMMON`, `$MERGE`, and `$DELETE` token references mapped
to token constants; `OFFSET` and `LOW OFFSET` immediates; `LOW`, decimal,
octal, and character constants; explicit `BYTE PTR` operands; raw `INS86
71,27` conversion to `db 0o71, 0o27` under the source `INS86` octal-byte
macro; parser `DB OFFSET` bytes; `$+3` conditional-return idioms; generated
labels; short branch removal; WHILE/WEND stack scanning; CHAIN/COMMON variable
preservation; and WRITE output/file-padding paths.

### gwlist.asm

Reviewed MASM source `gw-basic/gwlist.asm` lines 1-838 against converted
`dw-basic/src/gw/gwlist.asm` lines 1-841. Rechecked explicitly line by line
after the scope correction; every source line, including comments, MASM-only
directives, declarations, labels, instructions, data bytes, and final `END`,
was accounted for.

No functional conversion defects found. The converted file assembled cleanly
with `nasm -f obj -I dw-basic/src/include/`.

Non-functional mismatches: converted lines 1-2 add generated-source
scaffolding, MASM segment/data blocks and final `END` are omitted/commented,
`.RADIX 8 ; To be safe` loses the inline comment, `.XLIST`/`.LIST`/`PAGE` and
`SUBTTL` directives are removed or commented, and comment indentation/alignment
changes mechanically. Source `INCLUDE BINTRP.H` becomes `%include "dwoem.inc"`;
for this file, `BINTRP.H` contributes `OEM.H` constants plus unused table
macros, while the active code uses constants/tokens supplied by `dwoem.inc` and
`gwtokens.inc`.

Verified equivalence classes: public/extern handling for `LLIST`, `LIST`,
`LISPRT`, `BUFLIN`, `PLOOP2`, `TSTANM`, `DELETE`, and `DEL`; data-symbol
memory references (`PTRFIL`, `TEMP`, `CURLIN`, `DOT`, `F_EDIT`, `DORES`,
`TEMPA`, `CONLO`, `CONSAV`, `CONTYP`, `CONTXT`, `VARTAB`, `ARYTAB`, and
`STREND`); address immediates (`BUF`, `NOSNGQ`, `RESLST-1`, `CONLIN`, `REDDY`,
and `FINI`); `LOW OFFSET` constants (`MD_SQO`, `BUFLEN`, `OCTCON`, `DBLCN1`,
`SNGQTK`, `PLUSTK`, and `HEXCON`); `$DATA`, `$REM`, `$ELSE`, `$WHILE`, `$USR`,
and `$FN` token references mapped to token constants; `OLD86`/`OLDBLD`
boolean expressions; decimal, octal, and character constants; parser
`DB OFFSET 44D`; `$+3` conditional-return idioms; generated labels; short
branch removal; `INS86 56` conversion to `db 0o56` code-segment prefixes; list
printing, line decrunching, reserved-word expansion, numeric constant listing,
and delete/compact paths.

### ibmres.asm

Explicit full line-by-line recheck covered MASM source
`gw-basic/ibmres.asm` lines 1-988 and include `gw-basic/ibmres.h` lines 1-79
against converted `dw-basic/src/gw/ibmres.asm` lines 1-1694.

Findings so far:
- Source line 31 publishes `$KEY2B`, `$COM2B`, `$PEN2B`, and `$STR2B`; source
  macro definitions in `gw-basic/ibmres.h` lines 12-16 and 63-77 also publish
  every `$TOKEN` produced by `T`, `R`, and `R2`. Converted lines such as
  `dw-basic/src/gw/ibmres.asm:49`, `:260`, and the other `DOL_*` assignments
  use `%assign` only. These are preprocessor values, not exported object
  symbols. Same public-absolute export class as prior `INCSTR`/`LASTWR`
  findings.
- Source line 135 publishes `NUMCMD`, and lines 150-160 begin publishing token
  aliases like `THENTK`, `TABTK`, `STEPTK`, and `USRTK`. Converted lines
  264-290 define these with `%assign` only, again with no object export.
- Source statement dispatch entries for disk/graphics/device features are not
  source-equivalent in the converted table. Examples in this checked range:
  source lines 118-120 dispatch `LOAD`, `MERGE`, and `SAVE`, while converted
  lines 218-226 dispatch all three to `NODSKS`; source lines 123-126 dispatch
  `MOTOR`, `BSAVE`, `BLOAD`, and `SOUND`, while converted lines 233-244 route
  several to `FCERR`/`NODSKS`. These look like deliberate DreamWriter feature
  policy deltas, not mechanical syntax conversions.
- Source lines 161-234 continue the same public-absolute export issue for
  `FNTK`, `SPCTK`, `NOTTK`, `ERLTK`, `ERCTK`, `USINTK`, `INSRTK`, `SNGQTK`,
  `CLINTK`, operator tokens, and `LSTOPK`; converted lines 291-322 define them
  only with `%assign`.
- Source function dispatch entries are also not fully source-equivalent where
  disabled features are routed away. Examples in this checked range: source
  lines 277 and 286-289 dispatch `LPOS`, `PEN`, `STICK`, and `STRIG` to their
  named handlers, while converted lines 411-436 route them to `FCERR`.
- Source lines 521-720 continue the public-absolute token export issue for the
  extended FE/FD tokens and `$COM2B`; converted lines 1096-1233 define values
  with `%assign` only and do not emit object symbols.
- Source extended statement dispatch entries in lines 555-588 are not
  source-equivalent where converted lines 1098-1197 route many entries to
  `NODSKS` or `FCERR` instead of the original named handlers. Renames such as
  `COMMON` to `BASIC_COMMON`, `TIMES` to `TIMES_STMT`, `VIEW` to `VIEW_STMT`,
  and `WINDOW` to `WINDOW_STMT` were accounted for separately.
- Source FD function dispatch entries in lines 599-608 dispatch `CVI`, `CVS`,
  `CVD`, `MKI$`, `MKS$`, `MKD$`, `KTN`, `JIS`, `KPOS`, and `KLEN`; converted
  lines 1204-1233 route all of them to `FCERR`.
- Within source lines 521-720, the `SPCTAB`, `ALPTAX`, and `RESLSX` table byte
  expansions themselves match expected NASM values, including `YTAB`, `ZTAB`,
  special operator bytes, FE/FD token values, `ADR` words, and the expanded
  extended reserved-word spellings.
- Source lines 724-735 publish `NUMGFN`, `BOTCON`, `TOPCON`, `$RNDFN`,
  `$DATCO`, `$REMCO`, `NMREL`, `$CHRFN`, `$CSNGF`, and `$CDBLF`; converted
  lines 1437-1446 define these values with `%define` only and do not emit
  object symbols.
- Source lines 740-988 (`CRUNCX`, `LISTX`, `NEWSTX`, and `EVALX`) otherwise
  match instruction intent in the converted output. Checked conversions include
  offset immediates (`ALPTAX`, `RESLSX-1`, `LABBCK`), byte memory references
  (`[BX]`, `TEMPA`, `FLGOVC`), octal constants, `LOW` constants, removed
  `SHORT` qualifiers, generated labels, code-segment-prefix `INS86` byte
  sequences, and the hand-encoded `PUSH word [CS:STMDSX+SI]` /
  `PUSH word [CS:FUNDSX+SI]` sequences.

### gio86.asm

Explicit full line-by-line recheck covered MASM source
`gw-basic/gio86.asm` lines 1-2277 against converted
`dw-basic/src/gw/gio86.asm` lines 1-2081.

Findings: no mechanical instruction/data conversion defect found in the active
checked code. Header, include, segment, assume, `DOSIO` macro omission,
extern/public declarations, `OPEN`, record
length parsing, `CLOSE`, and the first `WIDTH` path were accounted for. Token
externs such as `$FOR`, `$INPUT`, `$LEN`, `EQULTK`, and `$LPRINT` are supplied
by `gwtokens.inc`; device pseudo-symbols such as `$_LPT1` are supplied by
`dwoem.inc` as `DOL__*` constants. Checked memory operands in this range
(`FILMOD`, string descriptors via `[BX]`, and `F_WID[SI]`) are bracketed
correctly. Source lines 261-560 add the rest of `WIDTH`, `BSAVE`/`BLOAD`,
and most of `PRINT`; checked MASM data-symbol references such as `SAVSEG`,
`SAVLEN`, `PTRFIL`, `FACLO`, and string-descriptor fields are bracketed
correctly, and `USINTK`/`TABTK`/`SPCTK` token references are supplied by
`gwtokens.inc`. Source lines 561-860 add EOF/LOC/LOF, random GET/PUT,
file-number parsing, `PRGFIL`, `NAMBAS`, `NULOPN`, and `OPNFIL`; checked
address immediates such as `F_MODE` and `FILDEV` remain immediates in NASM,
while true data references such as `PTRFIL`, `TEMP`, `FILMOD`, and `FILDEV`
are bracketed correctly. Source lines 861-1465 add `CLSALL`, `CLSFIL`,
`INCHR`/`INCHRE`, CR/output helpers, binary block helpers, file dispatch, and
`CDEVID`; checked `CS:` table reads, `IOJUMP` indirect jump, pseudo-FDB
device-code handling, byte/word FDB fields, and pointer variables such as
`FILTAB`, `STKLOW`, `PTRFIL`, `FREFDB`, `CHNFLG`, `NLONLY`, `RUNFLG`,
`BUFMIN`, `VARTAB`, `TXTTAB`, and `FRETOP` match source intent.
Source lines 1466-2065 add `NAMSCN`, `PARDEV`, FDB allocation/free,
string-space relocation, queue helpers, and `GIOINI`/`GIOTRM`; checked
address immediates (`FILNM`, `FILOPT`, `FNAML`, `F_MODE`, queue offsets),
`CS:` device-table reads, `REP MOVSB`, and data references such as `DEVTBL`,
`FILMOD`, `PTRFIL`, `FILTAB`, `STKLOW`, `FRETOP`, `STREND`, `VARTAB`,
`ARYTAB`, `MEMSIZ`, `SAVFRE`, `DEVINI`, and `DEVTRM` match source intent.
`ERROM` is converted to an error-code immediate in this range, matching the
public-absolute collapse class already recorded elsewhere.
Source lines 2066-2277 finish `DOALDV`, `FINLPT`, `FINPRT`, MSDOS vector
helpers, and final `CSEG ENDS`/`END`. Converted `DOALDV`, `FINLPT`, `FINPRT`,
`SAVVEC`, `SETVEC`, `XCESDS`, and `GETVEC` preserve instruction intent,
including the `CALL word [CS:BX+DI-2]`, LPT pseudo-device code, cursor-state
memory references, `LES DX,[BX]`, and `DOSIO 37D` expansion. Source
`MSISET`/`MSIRST` DOS vector save/restore bodies at lines 2191-2222 are
replaced by ROM-card stubs at converted lines 2023-2030; this is an
intentional-looking port delta but not source-equivalent. Error externs
`ERRDWP`, `ERRDNR`, and `ERRDME` are also collapsed to immediate error-code
constants in `DSKERR`, matching the public-absolute collapse class recorded
elsewhere. MASM final `CSEG ENDS` and `END` are omitted.

### giodsk.asm

Agent-reviewed MASM source `gw-basic/giodsk.asm` lines 1-1218 against
converted `dw-basic/src/gw/giodsk.asm` lines 1-1173.

Findings:
- `gw-basic/giodsk.asm:90` became
  `dw-basic/src/gw/giodsk.asm:90` `byte [DATOFS][BX+SI]`, invalid NASM.
  Source means `byte [DATOFS+BX+SI]`.
- `gw-basic/giodsk.asm:251` became
  `dw-basic/src/gw/giodsk.asm:243` `word [F_CLOC]+[SI+2]`, invalid/wrong.
  Source means `word [F_CLOC+SI+2]`.
- `gw-basic/giodsk.asm:277` became
  `dw-basic/src/gw/giodsk.asm:268` `word [FCB_FS]+[SI+2]`; should be
  `word [FCB_FS+SI+2]`.
- `gw-basic/giodsk.asm:327` became
  `dw-basic/src/gw/giodsk.asm:318` `word [FCB_RN]+[SI+2]`; should be
  `word [FCB_RN+SI+2]`.
- `gw-basic/giodsk.asm:389` became
  `dw-basic/src/gw/giodsk.asm:376` `byte [DATOFS][BX+SI]`; should be
  `byte [DATOFS+BX+SI]`.
- `gw-basic/giodsk.asm:406` became
  `dw-basic/src/gw/giodsk.asm:392` `byte [FD_DAT]-[BX+SI+1]`, invalid and
  reversed. Source means `byte [FD_DAT+BX+SI-1]`.
- `gw-basic/giodsk.asm:434` became
  `dw-basic/src/gw/giodsk.asm:418` with the same bad `FD_DAT-1[BX+SI]`
  conversion; should be `byte [FD_DAT+BX+SI-1]`.
- `gw-basic/giodsk.asm:445` became
  `dw-basic/src/gw/giodsk.asm:429` `byte [DATOFS][BX+SI]`; should be
  `byte [DATOFS+BX+SI]`.
- `gw-basic/giodsk.asm:600` became
  `dw-basic/src/gw/giodsk.asm:573` `word [FCB_RN]+[SI+2]`; should be
  `word [FCB_RN+SI+2]`.
- `gw-basic/giodsk.asm:686` became
  `dw-basic/src/gw/giodsk.asm:654` `word [FCB_RN]+[SI+2]`; should be
  `word [FCB_RN+SI+2]`.
- `gw-basic/giodsk.asm:1152` became
  `dw-basic/src/gw/giodsk.asm:1114` `byte -[DI+1]`, invalid. Source `-1[DI]`
  means `byte [DI-1]`.
- `gw-basic/giodsk.asm:1213-1215` MASM `PROC FAR` / `ENDP` scaffolding was
  left active at `dw-basic/src/gw/giodsk.asm:1171-1173`. This is invalid NASM;
  the retained `RET` inside a MASM far proc also needs explicit review for
  far-return semantics.

Other checked conversions matched source intent: `CALLOS` macro expansions,
`$` symbol renames, public label exports, and MASM segment/listing scaffolding
omissions/comments.

### advgrp.asm

Agent-reviewed MASM source `gw-basic/advgrp.asm` lines 1-1359 against
converted `dw-basic/src/gw/advgrp.asm` lines 1-1293. NASM syntax-only assemble
of the converted file passed during the read-only audit.

Findings:
- Repeated MASM bare data operands were converted as NASM immediates instead
  of memory loads. These should be bracketed in NASM:
  `gw-basic/advgrp.asm:214` -> `dw-basic/src/gw/advgrp.asm:195`
  `MOV BX,MOVCNT`; `:219` -> `:199` `MOV BX,CSAVEA`; `:223` -> `:202`
  `MOV BX,SKPCNT`; `:224` -> `:203` `MOV DX,MOVCNT`; `:235` -> `:213`
  `MOV BX,CSAVEA`; `:291` -> `:261` `MOV BX,CSAVEA`; `:312` -> `:279`
  `MOV BX,STREND`; `:318` -> `:283` `MOV BX,FRETOP`; `:329` -> `:293`
  `MOV BX,FRETOP`; `:341` -> `:304` `MOV BX,STREND`; `:348` -> `:311`
  `MOV BX,PSNLEN`; `:356` -> `:319` `MOV DX,QUELEN`; `:361` -> `:324`
  `MOV BX,QUEINP`; `:391` -> `:354` `MOV BX,PSNLEN`; `:400` -> `:363`
  `MOV BX,QUEOUT`; `:437` -> `:400` `MOV DX,FRETOP`; `:442` -> `:405`
  `MOV BX,STREND`.
- The same bare-data defect appears in CIRCLE/reflection code:
  source/converted pairs `565->534 GXPOS`, `587->555 CRCSUM`,
  `639->604 CNPNTS`, `641->606 CPCNT`, `644->609 CXOFF`,
  `659->623 CPCNT8`, `660->624 CNPNTS`, `664->628 CPCNT`,
  `667->631 CSTCNT`, `671->635 CENCNT`, `722->679 CXOFF`,
  `728->685 CYOFF`, `738->694 GRPACX`, `740->696 GRPACY`,
  `748->704 GRPACX`, `752->708 GRPACY`, `757->712 ASPECT`, and
  `825->783 CNPNTS`.
- The same bare-data defect appears in GET/PUT paths:
  source/converted pairs `912->873 MAXDEL`, `924->885 MINDEL`,
  `949->910 MINDEL`, `1012->972 GXPOS`, and `1022->982 GYPOS`.
- `gw-basic/advgrp.asm:32` `KANJSW=PC8A OR (TSHIBA AND (TRUROM-1))` became
  `dw-basic/src/gw/advgrp.asm:26` `%define KANJSW PC8A | (TSHIBA AND
  (TRUROM-1))`; MASM `AND` was not converted to NASM `&`. Latent
  preprocessor-expression defect if `KANJSW` is evaluated.

Source-equivalence deltas:
- `MINUTK` and `$OR`/`$AND`/`$PRESET`/`$PSET`/`$XOR` source extern/absolute
  token uses at source lines 74, 857, 884, and 1087-1091 became preprocessor
  constants at converted lines 845 and 1041-1045. This removes extern
  references and is a potential public-absolute export/relocation delta,
  although this file does not itself public-export those symbols.
- `VIEW`/`WINDOW` source constants were renamed to `VIEW_STMT`/`WINDOW_STMT`
  at converted lines 32 and 34-37. No in-file use was found and current values
  remain effectively zero via the include, but the source symbol names differ.

Other checked conversions matched expected patterns: routine publics for
`PAINT`, `CIRCLE`, `GPUTG`, and `DRAW`; `MOVRI`, `INS86`, `POPR`, `ADR`,
token table widths, generated labels, and omitted MASM segment/ASSUME/TITLE/
PAGE scaffolding.

### math2.asm

Agent-reviewed MASM source `gw-basic/math2.asm` lines 1-1882 against converted
`dw-basic/src/gw/math2.asm` lines 1-1847.

Findings:
- The standalone converted file loses the inherited MASM `.RADIX 8` state from
  `math1.asm`; many bare MASM octal literals were emitted as NASM decimal
  literals. Source/converted line pairs: `57->92`, `58->93`, `101->134`,
  `134->167`, `204->233`, `205->234`, `217->245`, `296->322`, `301->327`,
  `356->380`, `391->415`, `578->596`, `754->764`, `776->784`, `815->819`,
  `857->860`, `877->880`, `879->882`, `935->933`, `960->958`, `961->959`,
  `993->991`, `1017->1013`, `1025->1021`, `1028->1024`, `1047->1043`,
  `1048->1044`, `1064->1058`, `1082->1076`, `1089->1082`, `1091->1084`,
  `1124->1115`, `1307->1293`, `1511->1491`, `1554->1532`, `1564->1542`,
  `1701->1675`, `1711->1685`, `1716->1690`, `1724->1698`, `1741->1713`,
  `1753->1725`, `1755->1727`, `1757->1729`, `1759->1731`, `1779->1749`,
  `1780->1750`, `1796->1766`, `1804->1774`, `1843->1811`, and `1846->1814`.
  Example: source line 296 `LOW 220` should be NASM `0o220`, but converted
  line 322 uses decimal `220`.

Other deltas:
- Converted lines 23-54 add `global` declarations not present in
  `gw-basic/math2.asm` itself. The source file has no `PUBLIC`/`EXTRN`
  directives, so these are injected port/build declarations rather than direct
  conversions.
- No public absolute symbol converted to `%define` was found in this file.
  `SUBTTL` comments, omitted `CSEG ENDS`, and final `END` handling were
  otherwise as expected.

### gwsts.asm

Agent-reviewed MASM source `gw-basic/gwsts.asm` lines 1-2346 against converted
`dw-basic/src/gw/gwsts.asm` lines 1-2162. The converted file assembled during
the read-only audit.

Findings:
- Conditional-path conversion defect: source `CPMXIO` macro definition at
  `gw-basic/gwsts.asm:56` was dropped. Converted lines 47-48 leave an empty
  `%if CPM86`, but converted lines 2086 and 2097 still call `CPMXIO`. Hidden
  with current `CPM86=0`, but not source-equivalent.
- Public symbol rename/export deltas: source `TIMES` at lines 2117 and 2126
  became `TIMES_STMT` at converted lines 1949 and 1962; source `VIEW` and
  `WINDOW` at lines 2335-2338 became `VIEW_STMT` and `WINDOW_STMT` at
  converted lines 2154-2157. Likely intentional NASM/token collision handling,
  but original public names are not exported by this file.
- Public absolute/external constants were collapsed to preprocessor/immediate
  values rather than consumed as exports: `$ON`/`$OFF`/`$STOP`/`$LIST`,
  `$KEY2B`/`$PEN2B`/`$STR2B`/`$COM2B`, `T_ON`/`T_STOP`/`T_REQ`, `EQULTK`, and
  `ERRADV`. Immediate values appear to match, but this is a potential
  public-absolute export dependency delta.
- `$FACLO`/`$FACM1`/`$FMULS` are renamed externs (`DOL_FACLO`, `DOL_FACM1`,
  `DOL_FMULS`) rather than lost; this is a symbol-name delta but remains
  externally linked.

No other instruction, data table, generated label, memory-vs-immediate
operand, directive/scaffolding, or DOSIO expansion defects were found in the
active converted code.

### gwdata.asm

Agent-reviewed MASM source `gw-basic/gwdata.asm` lines 1-1565 against
converted `dw-basic/src/gw/gwdata.asm` lines 1-1332. Converted file assembled
during the read-only audit with only zeroing warnings for `?` storage in a
non-BSS section.

Findings:
- Segment/`ORG` layout is not preserved. Source `ORG 5O`, `ORG 400O`,
  `ORG 2D`, and `ORG 0+400O` at lines 189, 193, 624, and 812 are comments at
  converted lines 237, 240, 424, and 601. Within this file, `BEGCSG`,
  `CPMWRM`, `CPMENT`, `DOL_START`, and `START` assemble at the same offset
  instead of `CPMENT` being at offset 5 and `START` at octal 400; `BEGDSG`,
  `CPMMEM`, and `RAMLOW` similarly collapse to one offset. Source-equivalence
  defect unless external build/link layout deliberately supplies the gaps.
- Public error-number absolute symbols are not exported. Source lines 348-587
  publish QQ-derived error constants from `ERRNF` through disk error constants
  and `LSTERR`; converted lines 319-394 emit the string table plus local/
  preprocessor values only. `DSKLOC` is `equ` at converted line 375 but lacks
  `global`; `LSTERR` is `%define` at line 394.
- Other public absolute symbols became non-exporting preprocessor values:
  `FILEXT` source lines 1006-1007 -> converted lines 786-787; `DIRTMP`
  source lines 1047-1048 -> converted lines 826-827; `PRMSIZ` source lines
  1313-1314 -> converted line 1094; `FMLTT1` source lines 1519-1520 ->
  converted lines 1299-1300; `FMLTT2` source lines 1521-1522 -> converted
  lines 1301-1302.
- Extern handling changed: `CONCON` and `CONCN2` are source externs at line 74
  but are supplied as immediate include constants in converted lines 443-444;
  `COMMON` source extern at line 176 is renamed to `BASIC_COMMON` at converted
  line 228; the reserved-word/token extern block at source lines 230-260 is
  mostly omitted in converted lines 259-265.
- Fixed after runtime testing: the low-data phase initially treated the data
  phase `NUMCON` bytes as `resb`, losing the source-phase fake `CONCON` and
  `CONCN2` CHRGET tokens. The generator now copies matching source-phase
  initializers into the active data-phase symbols where the original source
  used `DUP(?)` placeholders for ROM-copy initialized data. Other unknown
  `DUP(?)` storage remains `resb`/`resw`.
- Duplicate generated labels are emitted for `$OVMSG`/`OVRMSG` and
  `$DIV0M`/`DIVMSG` at converted lines 327-334 and 340-347. NASM accepts the
  same-address duplicates, so this is not a binary-content defect, but it is a
  generated-label delta.
- All public `$...` labels are renamed to `DOL_...`; examples include
  `$START`, `$RNDX`, `$VALTP`, and the math buffer aliases from source lines
  1437-1513. This appears intentional, but all cross-file references must use
  the same rename scheme.

No other instruction/data-content mismatches were found: octal constants,
`INS86`, `ADR`, empty `ADRP`, `ACRLF`, and straight data/message table bytes
otherwise matched source intent.

### scndrv.asm

Agent-reviewed MASM source `gw-basic/scndrv.asm` lines 1-2465 against
converted `dw-basic/src/gw/scndrv.asm` lines 1-2284.

Findings:
- `gw-basic/scndrv.asm:1136` defines `CTLCNT=$-CTLITB` at the end of the
  table. Converted `dw-basic/src/gw/scndrv.asm:1028` uses `%define CTLCNT
  $-CTLITB`, and line 1041 expands it later at the use site. In NASM this makes
  `$` the later instruction location, not the table-end location, inflating the
  scan count. This should be an assembled constant (`equ`-style), not a lazy
  preprocessor macro.
- Public absolute symbols `TRMLNF`, `TRMEOL`, `TRMWRP`, `TRMNWP`, `TRMNUL`,
  and `SCNSIZ` from source lines 161-174 are declared `global` at converted
  lines 124-136 but defined with `%assign`/`%define`. These are not real NASM
  symbols, so they may not export MASM-style `PUBLIC` absolute symbols.

Other checked conversions matched source intent: MASM scaffolding omission/
commenting, extern/public routine labels, `SHORT`, `LOW`, `OFFSET`, radix
conversions, memory operands, tables, and commented `COMMENT %` blocks. No
hardware port deltas were found.

### gweval.asm

Agent-reviewed MASM source `gw-basic/gweval.asm` lines 1-1646 against
converted `dw-basic/src/gw/gweval.asm` lines 1-1673. Converted file assembled
during the read-only audit.

No instruction, operand, data-emission, generated-label, `INS86`, `POPR`,
radix, memory-vs-immediate, or straight-line code conversion defects found.

Source-equivalence/link-contract deltas:
- MASM scaffolding is omitted/commented as expected: `.RADIX`, segment/assume
  scaffolding, listing directives, `PAGE`, `SUBTTL`, `CSEG ENDS`, `END`, and
  `DO_EXT`.
- Source public `$OHCNS` at line 809 is exported as `DOL_OHCNS` at converted
  line 870. This matches the repo `$` rename scheme, but the original public
  name is not exported.
- External absolute/token symbols were collapsed to include constants rather
  than NASM externs: `PRMSIZ`, `ERRID`, `ONECON`, `DBLCON`, reserved-word token
  externs from `CLINTK` through `$VARPTR`, `$RNDFN`, `NUMGFN`, `BOTCON`, and
  `TOPCON`. Values appear equivalent, but this is a potential public-absolute
  export/link-contract delta.
- Many source error-table externs are omitted because this file does not
  reference them after conversion: `LSTERR`, `DSKERR`, `NONDSK`, and most
  `ERR*` symbols from source lines 213-228.
- `$OVMSG` and `$STPRN` externs are renamed to `DOL_OVMSG` and `DOL_STPRN`;
  references are consistent.
- Raw port I/O behavior is preserved, not shimmed: source `INS86` forms for
  `IN AL,DX` / `OUT DX,AL` emit matching bytes at converted lines 1586, 1597,
  and 1624.

### math1.asm

Agent-reviewed MASM source `gw-basic/math1.asm` lines 1-3827 against converted
`dw-basic/src/gw/math1.asm` lines 1-5630.

Findings:
- `gw-basic/math1.asm:114` uses `XLAT BYTE PTR ?CSLAB` under the code-segment
  dummy label/comment. Converted `dw-basic/src/gw/math1.asm:270` is plain
  `xlatb`, losing the implied code-segment override. Since `XLAT` defaults
  through `DS:BX`, this can read the hex/octal digit table from the wrong
  segment. It should preserve `CS`, e.g. `cs xlatb`.

Source-equivalence deltas:
- Source line 2423 label `FLOAT:` is converted as `FLOAT_SUB:` at converted
  line 2468. It is not public and no references to `FLOAT` were found, so this
  appears to be NASM keyword avoidance rather than a behavioral defect.
- Converted lines 3819-5630 are explicitly marked as continuation from
  `../gw-basic/math2.asm` and have no counterpart in `gw-basic/math1.asm`.
  Related extra globals also appear at converted lines 10-39. If the combined
  `math1+math2` file is intentional, this is a packaging delta rather than a
  defect in the `math1` portion.

Public/external handling: source publics and externs have corresponding
NASM `global`/`extern` declarations with `$` mapped to `DOL_`; no public
absolute symbol converted only to a preprocessor value was found. Omitted MASM
scaffolding is non-semantic or represented as comments/includes.

### gwmain.asm

Agent-reviewed MASM source `gw-basic/gwmain.asm` lines 1-3566 against
converted `dw-basic/src/gw/gwmain.asm` lines 1-3560.

Findings:
- MASM bare data-symbol reads were converted as NASM immediates instead of
  memory loads:
  `gw-basic/gwmain.asm:419` -> `dw-basic/src/gw/gwmain.asm:484`
  `MOV BX,DATLIN`; `:484` -> `:545` `MOV BX,SAVSTK`; `:501` -> `:562`
  `MOV BX,ONELIN`; `:1804` -> `:1847` `MOV BX,CONTXT`; `:1972` -> `:2007`
  `MOV DX,CONLO`; `:2503` -> `:2520` `MOV BX,ERRTXT`; `:3225` -> `:3232`
  `MOV BX,TXTTAB`; `:3304` -> `:3309` `MOV BX,CONTXT`. These should load
  from memory, e.g. `[DATLIN]`, `[SAVSTK]`, etc.
- `DERMAK` macro expansion is not layout-equivalent. Source lines 397-415
  expand to the original skip-chain form (`MOV DL,imm`, `DB 271O`, final
  `ORG $-1` overlay with `JMP SHORT ERROR`). Converted lines 410-483 emit
  independent `mov dl, ERRC_*` / `jmp ERROR` routines and leave an extra
  standalone `JMP ERROR`. Per-entry behavior is likely equivalent, but code
  size and all following label offsets differ.
- Potential export defects for public absolutes: source public constants
  `OCTCON`, `HEXCON`, `CONCN2`, `ONECON`, `CONCON`, `DBLCON`, and `DBLCN1`
  at lines 1728-1746 became `%assign`/`%define` values at converted lines
  1781-1792 with no object exports. Absolute/alias exports for `FORSZC` and
  `DATAS` also need verification against the link contract.
- Extern surface changed substantially. Source error/token externs at lines
  207, 213-226, and 253-281 are mostly omitted or constantized in converted
  lines 249-300. Examples: `LSTERR`/`DSKERR`/`NONDSK`/`ERR*` become `ERRC_*`;
  `$DATA`/`$GOTO`/other tokens become `TOK_*`; `EQULTK`, `MINUTK`, `PLUSTK`,
  `SNGQTK`, `STEPTK`, `THENTK`, and `NUMCMD` are used as constants rather than
  declared in this file.

Aside from the findings above, no additional instruction, label, data-byte,
radix, `INS86`, or `MOVRI` conversion defects were found. MASM scaffolding
omission/commenting was not counted as a defect except where it affects export
or import behavior.
