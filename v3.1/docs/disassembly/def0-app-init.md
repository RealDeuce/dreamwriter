# DEF0 Application Init

The far-call entry points called from the boot path during cold init
and cold reinit, plus the display+file composite service and session
state management. Address range `DEF0:51FD..5FFF` (109 blocks).

See [`boot.md`](boot.md) for where these are called.

## DEF0:57EF — Display + File Composite (Far-Call Table Entry #39)

Called from `C772:9555`. Allocates a 2560-byte (`0xA00`) stack frame,
renders a display page via `C000:3F35` and `DEF0:0DF5`, then calls
`DEF0:51FD` (file enumeration) and `DEF0:53C0` (display page builder).
Handles interactive file selection with `DEF0:0043` (read key).

## DEF0:51FD..53C0 — File Enumeration

Called from `DEF0:57EF`. Searches for files using `DEF0:E195`
(find first) and `DEF0:E1B4` (find next), compares filenames using
`DEF0:32B3`, and copies matches using `DEF0:32A4`.

## DEF0:5614 — Display Page Setup (11 callers)

Builds an `FF 44` (page setup) display script. Takes AX (page index),
computes pixel position (index * 8 + 16), renders via `C000:3F35`.

## DEF0:595A — Session State Reader

Called from `DEF0:5B14` (session init). Renders session status display
via `DEF0:0D80`, `DEF0:0D91`, and `DEF0:1806` (display callback setup),
then reads session data.

## DEF0:5A17 — Session Recovery A

Called from `DEF0:5B3E` (session error path). Attempts session recovery
using display prompts and `DEF0:2097` (user interaction).

## DEF0:5A6C — Session Recovery B

Called from `DEF0:5B3E` (session error path). Alternate recovery using
`DEF0:593A` (data scan), `DEF0:32B3` (compare), `DEF0:58A8` (validate).

## DEF0:5C07 — Application Subsystem Init

Called from the cold-start path (`C000:00D4`) and cold-reinit path
(`C000:01AB`). Initializes the display, keyboard, file, and application
subsystems by calling five subroutines, then sets a 3-byte signature at
`[A7AA..A7AC]` = `4F 39 32` and clears `[A000]`.

```asm
; file 0xD4B07
DEF0:5C07  9A C116 17EE      call far EE17:16C1   ; window 7 utility init
DEF0:5C0C  E8 094B           call DEF0:A718        ; display subsystem init
DEF0:5C0F  E8 6606           call DEF0:6278        ; keyboard/input subsystem init
DEF0:5C12  E8 CD2C           call DEF0:88E2        ; file subsystem init
DEF0:5C15  E8 0465           call DEF0:C11C        ; application subsystem init
DEF0:5C18  C6 06 AAA7 4F     mov byte [A7AA],4F    ; signature byte 1
DEF0:5C1D  C6 06 ABA7 39     mov byte [A7AB],39    ; signature byte 2
DEF0:5C22  C6 06 ACA7 32     mov byte [A7AC],32    ; signature byte 3
DEF0:5C27  C7 06 00A0 0000   mov word [A000],0     ; clear app state
DEF0:5C2D  CB                retf
```

The signature `4F 39 32` (ASCII `"O92"`) is checked by `DEF0:5C2E`
(the warm-start variant) to detect whether `5C07` has already run.

### Subroutine details

**`EE17:16C1` — Utility library init.** Calls `EE17:0047` with
AX=`0xA37E`. Single-instruction wrapper.

```asm
EE17:16C1  B8 7EA3           mov ax,A37E
EE17:16C4  9A 4700 17EE      call far EE17:0047
EE17:16C9  CB                retf
```

**`DEF0:6278` — Keyboard/input subsystem init.** Clears the keyboard
state word at `[A7A8]`.

```asm
DEF0:6278  C7 06 A8A7 0000   mov word [A7A8],0
DEF0:627E  C3                ret
```

**`DEF0:88E2` — File handle table init.** Clears 200 4-byte file
handle entries at `[A022..A342]`. Each entry gets its first word and
third word zeroed.

```asm
DEF0:88E2  33 C0             xor ax,ax       ; AX = 0
DEF0:88E4  EB 1C             jmp short DEF0:8902
DEF0:88E6  8B D8             mov bx,ax       ; loop body:
DEF0:88E8  D1 E3             shl bx,1
DEF0:88EA  D1 E3             shl bx,1        ; BX = AX * 4
DEF0:88EC  C7 87 22A0 0000   mov word [bx+A022],0
DEF0:88F2  8B D8             mov bx,ax
DEF0:88F4  D1 E3             shl bx,1
DEF0:88F6  D1 E3             shl bx,1
DEF0:88F8  81 C3 22A0        add bx,A022
DEF0:88FC  C7 47 02 0000     mov word [bx+2],0
DEF0:8901  40                inc ax
DEF0:8902  3D C800           cmp ax,C8       ; 200 entries
DEF0:8905  7C DF             jl DEF0:88E6
DEF0:8907  C3                ret
```

**`DEF0:C11C` — Application state init.** Clears the application
state byte at `[A00E]`.

```asm
DEF0:C11C  C6 06 0EA0 00     mov byte [A00E],0
DEF0:C121  C3                ret
```

**`DEF0:A718` — Display subsystem init.** The only substantial init
routine. Sets display dimensions `[A444]=0x6D` (109 columns),
`[A448]=0x8F` (143 rows), then reads display parameter tables from
segments `F68C` and `F382` to configure the LCD geometry. See
[`def0-display-services.md`](def0-display-services.md) for the display
service layer this initializes.

## DEF0:5C2E — Warm-Start Subsystem Reinit

Called from the warm-start entry at `C772:84E8`. Checks the `4F 39 32`
signature to see if `DEF0:5C07` has already run; if not, calls it first.
Then calls `DEF0:115C` with AX=`0x0E`, BX=`0xF243`, CX=`[A000]` and
checks the result.

```asm
; file 0xD4B2E
DEF0:5C2E  51                push cx
DEF0:5C2F  80 3E AAA7 4F     cmp byte [A7AA],4F   ; signature check
DEF0:5C34  75 0E             jnz DEF0:5C44
DEF0:5C36  80 3E ABA7 39     cmp byte [A7AB],39
DEF0:5C3B  75 07             jnz DEF0:5C44
DEF0:5C3D  80 3E ACA7 32     cmp byte [A7AC],32
DEF0:5C42  74 05             jz DEF0:5C49         ; signature OK -> skip
DEF0:5C44  9A 075C F0DE      call far DEF0:5C07   ; signature missing -> full init
DEF0:5C49  C7 06 6F14 FFFF   mov word [146F],FFFF ; temp resume state
DEF0:5C4F  B8 0E00           mov ax,0E
DEF0:5C52  BB 43F2           mov bx,F243
DEF0:5C55  8B 0E 00A0        mov cx,[A000]
DEF0:5C59  9A 5C11 F0DE      call far DEF0:115C   ; subsystem query/init
DEF0:5C5E  8B C8             mov cx,ax
DEF0:5C60  C7 06 6F14 0000   mov word [146F],0    ; clear temp state
DEF0:5C66  83 F9 31          cmp cx,31            ; result check
DEF0:5C69  75 11             jnz DEF0:5C7C
```

If the result is `0x31`, calls `EE17:16CA` and updates `[A000]`:

```asm
DEF0:5C6B  9A CA16 17EE      call far EE17:16CA
DEF0:5C70  B8 0F00           mov ax,0F
DEF0:5C73  BB 43F2           mov bx,F243
DEF0:5C76  9A 5C11 F0DE      call far DEF0:115C
DEF0:5C7B  90                nop
DEF0:5C7C  89 0E 00A0        mov [A000],cx
```

## DEF0:5B03 — Application Session Init

Called from cold-reinit (`C000:01C3`), warm resume (`C000:0303`), and
the NMI resume path. Checks `[133A]` — if zero, returns immediately
(no session to init). Otherwise builds two stack-local buffers and
calls `DEF0:32A4` (copy from `[1345]`), `DEF0:595A`, and `DEF0:32B3`
(compare). May set `[146F]=0x1997` if the session state matches.

```asm
; file 0xD4A03
DEF0:5B03  55                push bp
DEF0:5B04  8B EC             mov bp,sp
DEF0:5B06  83 EC 16          sub sp,16         ; 22-byte local frame
DEF0:5B09  80 3E 3A13 00     cmp byte [133A],0
DEF0:5B0E  75 04             jnz DEF0:5B14     ; [133A]!=0 -> init session
DEF0:5B10  33 C0             xor ax,ax
DEF0:5B12  EB 48             jmp short DEF0:5B5C ; -> return 0
```

Session init path:

```asm
DEF0:5B14  8D 46 F5          lea ax,[bp-0B]    ; local buffer 1
DEF0:5B17  BB 4513           mov bx,1345       ; source: saved session data
DEF0:5B1A  E8 87D7           call DEF0:32A4    ; copy session block
DEF0:5B1D  8D 46 EA          lea ax,[bp-16]    ; local buffer 2
DEF0:5B20  E8 37FE           call DEF0:595A    ; read current session state
DEF0:5B23  85 C0             test ax,ax
DEF0:5B25  75 17             jnz DEF0:5B3E     ; error -> alternate path
DEF0:5B27  8D 46 F5          lea ax,[bp-0B]
DEF0:5B2A  8D 5E EA          lea bx,[bp-16]
DEF0:5B2D  E8 83D7           call DEF0:32B3    ; compare session blocks
DEF0:5B30  85 C0             test ax,ax
DEF0:5B32  74 06             jz DEF0:5B3A      ; match -> skip
DEF0:5B34  C7 06 6F14 9719   mov word [146F],1997 ; session matches -> warm OK
DEF0:5B3A  33 C0             xor ax,ax
DEF0:5B3C  EB 1E             jmp short DEF0:5B5C ; -> return 0
```

Alternate path when `DEF0:595A` returns nonzero (session state error):

```asm
DEF0:5B3E  E8 D6FE           call DEF0:5A17    ; attempt recovery
DEF0:5B41  85 C0             test ax,ax
DEF0:5B43  75 15             jnz DEF0:5B5A     ; recovery failed
DEF0:5B45  E8 12FE           call DEF0:5A6C    ; alternate recovery
DEF0:5B48  85 C0             test ax,ax
DEF0:5B4A  75 0E             jnz DEF0:5B5A     ; also failed
```

Return path:

```asm
DEF0:5B5C  8B E5             mov sp,bp
DEF0:5B5E  5D                pop bp
DEF0:5B5F  CB                retf              ; return AX
```

### Session State Variables

| Address | Purpose |
| --- | --- |
| `[133A]` | Session active flag (0 = no session) |
| `[1345]` | Saved session data block (copied by `DEF0:32A4`) |
| `[146F]` | Set to `0x1997` when saved session matches current state |
| `[A000]` | Application state counter (used by `DEF0:5C2E`) |
| `[A7AA..A7AC]` | Init signature `"O92"` — indicates `DEF0:5C07` has run |
