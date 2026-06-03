# Diagnostic Spell Services

This slice expands the diagnostic monitor's `Q` and `R` commands. The monitor
help text describes them as `Clear spell` and `Reset spell`; both commands enter
the banked spell/grammar/linguistic service thunk through `C000:18A1`.

## Diagnostic Entry Paths

The command parser recognizes uppercase `Q` and `R` before entering the normal
hex-field scanner:

```asm
; file 0x412F8
C000:12F8  B2 58             mov  dl,0x58
C000:12FA  53                push bx
C000:12FB  E8 A3 05          call C000:18A1
C000:12FE  5B                pop  bx
C000:12FF  EB 05             jmp  C000:1306

; file 0x41301
C000:1301  B2 59             mov  dl,0x59
C000:1303  E8 EA 02          call C000:15F0
```

After either path returns, the monitor forces the dump command state to `P` and
sets the dump base to `0000:3000`:

```asm
C000:1306  C6 06 BB 6E 50    mov  byte [0x6ebb],0x50
C000:130B  BA 00 30          mov  dx,0x3000
C000:130E  89 16 B9 6E       mov  [0x6eb9],dx
C000:1312  BA 00 00          mov  dx,0
C000:1315  89 16 B7 6E       mov  [0x6eb7],dx
C000:1319  E9 85 00          jmp  C000:13A1
```

`R` uses a local wrapper so it can leave the spell-engine data windows selected
after `C000:18A1` has returned:

```asm
; file 0x415F0
C000:15F0  53                push bx
C000:15F1  E8 AD 02          call C000:18A1
C000:15F4  B0 03             mov  al,0x03
C000:15F6  E6 13             out  0x13,al
C000:15F8  B0 02             mov  al,0x02
C000:15FA  E6 14             out  0x14,al
C000:15FC  5B                pop  bx
C000:15FD  C3                ret
```

## Dispatcher Stubs

`C000:18A1` maps the banked code at `3000:0000`, which dispatches through
`3000:4AA6`. Service IDs `0x58` and `0x59` are the final valid entries in the
`0x00..0x59` jump table:

```asm
; file 0x34BF2
3000:4BF2  E8 FF 00          call 3000:4CF4
3000:4BF5  8B E5             mov  sp,bp
3000:4BF7  5D                pop  bp
3000:4BF8  C3                ret

; file 0x34BFA
3000:4BFA  E8 1D 01          call 3000:4D1A
3000:4BFD  8B E5             mov  sp,bp
3000:4BFF  5D                pop  bp
3000:4C00  C3                ret
```

The banked thunk copies `[3C00:6BD8]` into `DX`, exchanges `AX` and `DX`, and
returns far, so status/error codes written to `[6BD8]` are returned to the
caller in `AX`.

## Q: Clear Spell State

Service `0x58` is a direct clear of the engine's high work-state range:

```asm
; file 0x34CF4
3000:4CF4  C7 06 D4 6B D8 6B mov  word [0x6bd4],0x6bd8
3000:4CFA  C7 06 D6 6B 88 96 mov  word [0x6bd6],0x9688
3000:4D00  EB 0B             jmp  3000:4D0D

3000:4D02  8B 1E D4 6B       mov  bx,[0x6bd4]
3000:4D06  FF 06 D4 6B       inc  word [0x6bd4]
3000:4D0A  C6 07 00          mov  byte [bx],0
3000:4D0D  A1 D6 6B          mov  ax,[0x6bd6]
3000:4D10  39 06 D4 6B       cmp  [0x6bd4],ax
3000:4D14  72 EC             jc   3000:4D02
3000:4D16  2B C0             sub  ax,ax
3000:4D18  C3                ret
```

This zero-fills `3C00:6BD8..9687` and returns `AX=0`. Because the range begins
at `[6BD8]`, the returned status cell is also cleared before the thunk returns.
This is a stronger clear than just emptying the candidate list: it also clears
parser state, dictionary stream cursors, result-list scratch, and the engine's
working buffers in that range.

## R: Reset Spell Engine

Service `0x59` performs a rebuild/validation pass. It first initializes the
candidate manager, then builds a local output record at `84DA`, rebuilds the
active slot descriptors, and validates the engine buffer:

```asm
; file 0x34D1A
3000:4D1A  E8 F9 02          call 3000:5016      ; candidate manager init
3000:4D1D  0B C0             or   ax,ax
3000:4D1F  74 05             jz   3000:4D26
3000:4D21  B8 FF FF          mov  ax,0xffff
3000:4D24  C3                ret

3000:4D26  B8 DA 84          mov  ax,0x84da
3000:4D29  50                push ax
3000:4D2A  B8 08 01          mov  ax,0x0108
3000:4D2D  50                push ax
3000:4D2E  E8 15 E9          call 3000:3646      ; initialize output record
3000:4D31  83 C4 04          add  sp,4
3000:4D34  C7 06 EE 8F DA 84 mov  word [0x8fee],0x84da
3000:4D3A  FF 36 04 60       push word [0x6004]
3000:4D3E  E8 3B 05          call 3000:527C      ; rebuild selected slot pages
3000:4D41  83 C4 02          add  sp,2
3000:4D44  E8 65 ED          call 3000:3AAC      ; validate engine buffer
3000:4D47  0B C0             or   ax,ax
3000:4D49  74 1B             jz   3000:4D66
```

If validation fails, the reset service falls back through the same startup
initializer used by service `0x01`, then rings the private `AX=4420` tone
helper five times and returns failure:

```asm
3000:4D4B  E8 1C 00          call 3000:4D6A
3000:4D4E  E8 E6 B2          call 3000:0037      ; INT 21h AX=4420 tone
3000:4D51  E8 E3 B2          call 3000:0037
3000:4D54  E8 E0 B2          call 3000:0037
3000:4D57  E8 DD B2          call 3000:0037
3000:4D5A  E8 DA B2          call 3000:0037
3000:4D5D  C7 06 00 60 00 00 mov  word [0x6000],0
3000:4D63  EB BC             jmp  3000:4D21

3000:4D66  2B C0             sub  ax,ax
3000:4D68  C3                ret
```

The initializer at `3000:4D6A` is shared with service `0x01`:

```asm
; file 0x34D6A
3000:4D6A  E8 09 02          call 3000:4F76
3000:4D6D  B8 08 60          mov  ax,0x6008
3000:4D70  50                push ax
3000:4D71  B8 C4 0B          mov  ax,0x0bc4
3000:4D74  50                push ax
3000:4D75  E8 68 EC          call 3000:39E0
3000:4D78  83 C4 04          add  sp,4
3000:4D7B  E8 A0 EC          call 3000:3A1E
3000:4D7E  C7 06 00 60 00 00 mov  word [0x6000],0
3000:4D84  2B C0             sub  ax,ax
3000:4D86  C3                ret
```

`3000:4F76` clears `[6002]`, points the engine output buffer descriptor at
`6008`, initializes a `0x108` byte record at `84DA`, sets the active output
pointer `[8FEE]=84DA`, resets `[6BCC]=0x20`, clears `[6006]`, and calls
`3000:527C(0)` to rebuild slot-0 page descriptors. `3000:39E0` and
`3000:3A1E` then seed and validate the `6008` buffer; `3000:3AAC` later checks
the same buffer checksum and calls `3000:4034`.

## Bottom

The diagnostic `Q/R` roots are now tied off at the already documented banked
engine helpers:

| Root | Bottomed at |
| --- | --- |
| `Q` / service `0x58` | Self-contained zero-fill at `3000:4CF4..4D18`. |
| `R` / service `0x59` | Candidate init `3000:5016`, slot-page rebuild `3000:527C`, buffer init `3000:4D6A/4F76`, and existing parser/checker validation helpers. |

No new strings or image assets are reached by these service bodies. The only
visible command text is the previously decoded diagnostic help line
`T=Card ATTR, N=COM, Q/R=Clear/Reset spell`.
