# WP Linguistic Tools

This slice maps the three remaining word-processor app-loop roots reached from
[`app-menu-event-loop.md`](app-menu-event-loop.md): Spell/Grammar Check,
Dictionary, and Thesaurus. The deeper banked spelling/grammar/thesaurus service
dispatcher boundary is mapped in
[`banked-linguistic-services.md`](banked-linguistic-services.md), while deeper
engine notes remain in [`../spell-engine.md`](../spell-engine.md).

No image assets are reached in this slice. These tools draw text/display
resources and reuse the editor display, current-word, and candidate-list
buffers.

## App-Loop Entries

The shared app loop dispatches the editor linguistic events as:

| Event | Root | User-facing tool |
| ---: | --- | --- |
| `0xF6` | `C688:ED1F` | Spell Check / Grammar Check |
| `0xF7` | `C688:D8AF` | Dictionary |
| `0xF8` | `C688:E274` | Thesaurus |

All three start by calling `C688:4F85`; carry set exits through the already
documented app-loop error/resource path at `C688:EDBE`.

## Spell And Grammar Check

`C688:ED1F` is the combined Spell Check / Grammar Check front end. It clears
bit `0x80` in `[8DB4]`, assumes spelling mode by setting `[8E3E]=1`, and calls
the banked linguistic wrapper `C688:936A` with `AH=04`, `DL=0x23`. When that
service returns `DL=1` and the Preferences grammar byte `[6D55]` is zero, the
front end switches to grammar mode by clearing `[8E3E]`, calls `C688:EF24`, and
sets bits in `[8DA8]` before drawing the run screen.

```asm
spell_grammar_entry_C688_ED1F:
; file 0x5559F
C688:ED1F  E8 63 62          call 0x4f85
C688:ED22  73 03             jnc  0xed27
C688:ED24  E9 97 00          jmp  0xedbe
C688:ED27  BE B4 8D          mov  si,0x8db4
C688:ED2A  80 24 7F          and  byte [si],0x7f
C688:ED2D  C6 06 3E 8E 01    mov  byte [0x8e3e],0x1
C688:ED32  B2 23             mov  dl,0x23
C688:ED34  B4 04             mov  ah,0x4
C688:ED36  E8 31 A6          call 0x936a
C688:ED39  80 FA 01          cmp  dl,0x1
C688:ED3C  75 18             jnz  0xed56
C688:ED3E  80 3E 55 6D 00    cmp  byte [0x6d55],0x0
C688:ED43  75 11             jnz  0xed56
C688:ED45  C6 06 3E 8E 00    mov  byte [0x8e3e],0x0
C688:ED4A  E8 D7 01          call 0xef24
C688:ED4D  BE A8 8D          mov  si,0x8da8
C688:ED50  80 0C 01          or   byte [si],0x1
C688:ED53  80 24 FD          and  byte [si],0xfd
C688:ED56  BE 1D 00          mov  si,0x1d
C688:ED59  80 3E 3E 8E 00    cmp  byte [0x8e3e],0x0
C688:ED5E  75 03             jnz  0xed63
C688:ED60  BE 8C 00          mov  si,0x8c
C688:ED63  E8 23 89          call 0x7689
C688:ED66  E8 47 EC          call 0xd9b0
C688:ED69  E8 17 E5          call 0xd283
C688:ED6C  73 0E             jnc  0xed7c
C688:ED6E  E8 37 01          call 0xeea8
C688:ED71  E8 41 EC          call 0xd9b5
C688:ED74  E8 34 02          call 0xefab
C688:ED77  E8 48 01          call 0xeec2
C688:ED7A  73 DA             jnc  0xed56
C688:ED7C  C6 06 A8 8D 00    mov  byte [0x8da8],0x0
C688:ED81  E9 1B FF          jmp  0xec9f
```

`C688:EF24` is the grammar-side setup helper referenced above. It calls
`C688:EF31`, which seeds banked service `0x28` through the shared word-check
helper `C688:D83D`, then clears `[8DA8]`.

```asm
grammar_setup_C688_EF24:
; file 0x557A4
C688:EF24  E8 0A 00          call 0xef31
C688:EF27  C3                ret
C688:EF31  B2 28             mov  dl,0x28
C688:EF33  E8 07 E9          call 0xd83d
C688:EF36  C6 06 A8 8D 00    mov  byte [0x8da8],0x0
C688:EF3B  C3                ret
```

The same lower spell/grammar cluster is already cataloged from the service
boundary in
[`banked-linguistic-services.md`](banked-linguistic-services.md), with deeper
parser/checker notes in
[`../spell-engine.md`](../spell-engine.md#editor-spellgrammar-front-end),
including banked services `0x16`, `0x2A`, and the suggestion-browser service
calls.

## Dictionary Front End

`C688:D8AF` is the Dictionary root. It prepares the current editor word through
the same normalization helpers used by Thesaurus, copies the current query into
`[8DBA]`, displays resource `0x39`, builds a one-line selection/list wrapper
at `0x75A0`, and enters a local inline dispatch table. The visible resource
strings identify the screen as `DICTIONARY`, with choices to suggest from the
dictionary, add to the dictionary, and view/remove the user dictionary.

```asm
dictionary_entry_C688_D8AF:
; file 0x5412F
C688:D8AF  E8 D3 76          call 0x4f85
C688:D8B2  73 03             jnc  0xd8b7
C688:D8B4  E9 07 15          jmp  0xedbe
C688:D8B7  BE B4 8D          mov  si,0x8db4
C688:D8BA  80 24 7F          and  byte [si],0x7f
C688:D8BD  E8 57 BE          call 0x9717
C688:D8C0  E8 01 6C          call 0x44c4
C688:D8C3  E8 7A BE          call 0x9740
C688:D8C6  E8 31 54          call 0x2cfa
C688:D8C9  E8 44 AD          call 0x8610
C688:D8CC  E8 5D FD          call 0xd62c
C688:D8CF  E8 0E 05          call 0xdde0
C688:D8D2  E8 78 FD          call 0xd64d
C688:D8D5  E8 EC 6B          call 0x44c4
C688:D8D8  E8 34 FD          call 0xd60f
C688:D8DB  74 03             jz   0xd8e0
C688:D8DD  EB 69             jmp  0xd948
C688:D8E0  BE 28 7F          mov  si,0x7f28
C688:D8E3  8A 04             mov  al,[si]
C688:D8E5  0A C0             or   al,al
C688:D8E7  75 03             jnz  0xd8ec
C688:D8E9  E9 8C 00          jmp  0xd978
C688:D8EC  BA BA 8D          mov  dx,0x8dba
C688:D8EF  E8 29 18          call 0xf11b
C688:D8F2  BE BA 8D          mov  si,0x8dba
C688:D8F5  E8 01 18          call 0xf0f9
C688:D8F8  E8 BA 00          call 0xd9b5
C688:D8FB  BE 39 00          mov  si,0x39
C688:D8FE  E8 88 9D          call 0x7689
C688:D901  B1 01             mov  cl,0x1
C688:D903  BA A0 75          mov  dx,0x75a0
C688:D906  E8 AC 98          call 0x71b5
C688:D909  E8 26 18          call 0xf132
C688:D90C  E8 D0 B9          call 0x92df
```

Selected dictionary actions leave the inline table and land in the local
handlers below. `C688:D927` re-enters the dictionary screen after a helper at
`C688:E0CB` returns `AL=1`. `C688:D930` copies the current query from `[8DBA]`
to `0x757F` and calls `C688:F09F`, matching the add/retype-user-word side.
`C688:D978` enters the shared suggestion browser at `C688:D9C3`.

```asm
dictionary_action_handlers_C688_D927:
; file 0x541A7
C688:D927  E8 A1 07          call 0xe0cb
C688:D92A  3C 01             cmp  al,0x1
C688:D92C  74 CA             jz   0xd8f8
C688:D92E  EB 18             jmp  0xd948
C688:D930  BE BA 8D          mov  si,0x8dba
C688:D933  BF 7F 75          mov  di,0x757f
C688:D936  B9 20 00          mov  cx,0x20
C688:D939  06                push es
C688:D93A  BD 00 00          mov  bp,0
C688:D93D  8E C5             mov  es,bp
C688:D93F  FC                cld
C688:D940  F3 A4             rep  movsb
C688:D942  07                pop  es
C688:D943  8B D7             mov  dx,di
C688:D945  E8 57 17          call 0xf09f
C688:D948  E8 C5 AC          call 0x8610
C688:D94B  E8 C8 06          call 0xe016
C688:D94E  74 1F             jz   0xd96f
C688:D950  E8 DA BD          call 0x972d
C688:D953  EB 1D             jmp  0xd972
C688:D96F  E8 E3 FF          call 0xd955
C688:D972  E8 4F 6B          call 0x44c4
C688:D975  E9 27 13          jmp  0xec9f
C688:D978  E8 95 AC          call 0x8610
C688:D97B  E8 AF BD          call 0x972d
C688:D97E  E8 43 6B          call 0x44c4
C688:D981  E9 3F 00          jmp  0xd9c3
```

The suggestion browser at `C688:D9C3` displays resource `0x3A`, points
`[8E11]` at the row buffer `0x8E13`, calls banked service `0x09` to get the
result count into `[8DB5]`/`[8DB6]`, fills up to six visible rows through
`C688:DD5C`, then loops around a second resource screen (`0x3E`) and another
inline dispatch table.

```asm
dictionary_suggestion_browser_C688_D9C3:
; file 0x54243
C688:D9C3  C6 06 34 8E 00    mov  byte [0x8e34],0
C688:D9C8  E8 BA 75          call 0x4f85
C688:D9CB  73 03             jnc  0xd9d0
C688:D9CD  E9 EE 13          jmp  0xedbe
C688:D9D0  BE B4 8D          mov  si,0x8db4
C688:D9D3  BE 3A 00          mov  si,0x3a
C688:D9D6  E8 B0 9C          call 0x7689
C688:D9D9  BE 13 8E          mov  si,0x8e13
C688:D9DC  89 36 11 8E       mov  [0x8e11],si
C688:D9E0  B2 09             mov  dl,0x9
C688:D9E2  B4 04             mov  ah,0x4
C688:D9E4  E8 83 B9          call 0x936a
C688:D9E7  8A C2             mov  al,dl
C688:D9E9  A2 B5 8D          mov  [0x8db5],al
C688:D9EC  A2 B6 8D          mov  [0x8db6],al
C688:D9EF  0A C0             or   al,al
C688:D9F1  74 58             jz   0xda4b
C688:D9F3  C6 06 A9 8D 00    mov  byte [0x8da9],0
C688:D9F8  C6 06 AA 8D 00    mov  byte [0x8daa],0
C688:D9FD  C6 06 AB 8D 00    mov  byte [0x8dab],0
C688:DA02  B0 10             mov  al,0x10
C688:DA04  A2 B7 8D          mov  [0x8db7],al
C688:DA07  E8 52 03          call 0xdd5c
C688:DA0A  72 1D             jc   0xda29
...
C688:DA4B  BE 3E 00          mov  si,0x3e
C688:DA4E  E8 38 9C          call 0x7689
C688:DA51  B1 01             mov  cl,0x1
C688:DA53  E8 4E 97          call 0x71a4
C688:DA56  A0 4A 79          mov  al,[0x794a]
C688:DA59  3C 03             cmp  al,0x3
C688:DA5B  75 EE             jnz  0xda4b
C688:DA5D  E9 3F 12          jmp  0xec9f
```

## Thesaurus Front End

`C688:E274` is the Thesaurus root. This slice records the C688 app-loop entry
and the screen setup boundary; the result-list and meanings engine is already
expanded in [`../spell-engine.md`](../spell-engine.md#editor-thesaurus-front-end).

```asm
thesaurus_entry_C688_E274:
; file 0x54AF4
C688:E274  E8 0E 6D          call 0x4f85
C688:E277  73 03             jnc  0xe27c
C688:E279  E9 42 0B          jmp  0xedbe
C688:E27C  E8 03 00          call 0xe282
C688:E27F  E9 1D 0A          jmp  0xec9f

thesaurus_screen_setup_C688_E282:
C688:E282  BE B4 8D          mov  si,0x8db4
C688:E285  80 24 7F          and  byte [si],0x7f
C688:E288  E8 8C B4          call 0x9717
C688:E28B  E8 36 62          call 0x44c4
C688:E28E  E8 AF B4          call 0x9740
C688:E291  E8 66 4A          call 0x2cfa
C688:E294  E8 79 A3          call 0x8610
C688:E297  E8 92 F3          call 0xd62c
C688:E29A  E8 43 FB          call 0xdde0
C688:E29D  E8 AD F3          call 0xd64d
C688:E2A0  E8 21 62          call 0x44c4
C688:E2A3  E8 69 F3          call 0xd60f
C688:E2A6  75 26             jnz  0xe2ce
C688:E2A8  BE 28 7F          mov  si,0x7f28
C688:E2AB  8A 04             mov  al,[si]
C688:E2AD  0A C0             or   al,al
C688:E2AF  74 1D             jz   0xe2ce
C688:E2B1  BA BA 8D          mov  dx,0x8dba
C688:E2B4  E8 64 0E          call 0xf11b
C688:E2B7  BE BA 8D          mov  si,0x8dba
C688:E2BA  E8 3C 0E          call 0xf0f9
C688:E2BD  BE 76 00          mov  si,0x76
C688:E2C0  E8 C6 93          call 0x7689
C688:E2C3  B1 01             mov  cl,0x1
C688:E2C5  BA A0 75          mov  dx,0x75a0
C688:E2C8  E8 EA 8E          call 0x71b5
C688:E2CB  E8 1C 00          call 0xe2ea
C688:E2CE  3C 01             cmp  al,0x1
C688:E2D0  75 09             jnz  0xe2db
C688:E2D2  BE 7A 00          mov  si,0x7a
C688:E2D5  E8 B1 93          call 0x7689
C688:E2D8  E8 12 B4          call 0x96ed
C688:E2DB  E8 32 A3          call 0x8610
C688:E2DE  E8 4C B4          call 0x972d
C688:E2E1  EB 03             jmp  0xe2e6
C688:E2E3  E8 6F F6          call 0xd955
C688:E2E6  E8 DB 61          call 0x44c4
C688:E2E9  C3                ret
```

## Resources

| Resource | Table word | Payload | Visible role |
| ---: | ---: | ---: | --- |
| `0x1D` | `0x11C7` | `0x56B87` | Spell Check run screen: `S P E L L   C H E C K   R U N`. |
| `0x8C` | `0x1F5E` | `0x5791E` | Spell & Grammar run screen. |
| `0x39` | `0x12E1` | `0x56CA1` | Main Dictionary screen and action choices. |
| `0x3A` | `0x1372` | `0x56D32` | View/remove user dictionary screen. |
| `0x3E` | `0x13E6` | `0x56DA6` | Suggestion/action screen around `SUGGEST`. |
| `0x76` | `0x1C3C` | `0x573FC` | Main Thesaurus screen; see `spell-engine.md` for the full resource cluster. |
| `0x7A` | `0x1AC8` | `0x57488` | No-synonym status path used after Thesaurus setup. |

## State Fields

| Address | Role in this slice |
| ---: | --- |
| `[6D55]` | Preferences grammar-checking word; zero enables the grammar side when service `0x23` reports it is available. |
| `[75A0]` | List/selection wrapper buffer passed to `C688:71B5`. |
| `[757F]` | Temporary dictionary word buffer used before `C688:F09F`. |
| `[7F28]` | Current editor/query word buffer used by Dictionary and Thesaurus. |
| `[8DA8]` | Spell/grammar mode flags adjusted during the grammar setup path. |
| `[8DA9]`, `[8DAA]`, `[8DAB]` | Dictionary suggestion row/page counters. |
| `[8DB4]` | Linguistic UI mode flags; these roots clear bit `0x80` on entry. |
| `[8DB5]`, `[8DB6]` | Candidate/result count and current selection number. |
| `[8DB7]` | Banked service selector used while fetching suggestion rows. |
| `[8DB8]`, `[8DB9]` | Candidate pagination/copy counters. |
| `[8DBA]` | Normalized query word copied from the editor/current-word buffer. |
| `[8DDB]` | Banked-service text result buffer. |
| `[8E11]` | Pointer into the dictionary visible row buffer at `0x8E13`. |
| `[8E34]` | Dictionary suggestion-browser refresh flag. |
| `[8E3E]` | Spell/grammar mode byte: `1` for spelling, `0` for grammar. |

## Bottom

`C688:ED1F`, `C688:D8AF`, and `C688:E274` are now named and tied to their
editor UI resources. Further depth belongs to the shared banked linguistic
engine and candidate-list internals already tracked in
[`../spell-engine.md`](../spell-engine.md).
