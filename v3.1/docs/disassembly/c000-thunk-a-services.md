# C000 Thunk A Services

The thunk A service handlers at `C000:1A00..22FF` (67 blocks).
Reached from the thunk A dispatch table at `C000:1A00` (12 entries)
via the thunk A entry at `C000:19CB`. These provide core display
rendering, keyboard, serial, and DreamLink services to the C772
application runtime.

See [`banked-thunk-dispatch.md`](banked-thunk-dispatch.md) for the
thunk A dispatch mechanism.

## Thunk A Dispatch Table (C000:1A00, 12 entries)

| Slot | Handler | Callers | Purpose |
| ---: | --- | --- | --- |
| 0, 6 | `C000:1AA2` | Spell check (`C772:970F` AH=6), display services | Multi-function service dispatch |
| 1, 11 | `C000:1A9D` | State queries | Load DI from `[710F]` (state pointer) |
| 2, 5, 7 | `C000:1A18` | Key input | Key event dispatch: tests `[7195]`, calls serial I/O and key translation |
| 3 | `C000:1A95` | Sound | Returns AL from `[7195]` (via `C000:1D85` fixed beep) |
| 4 | `C000:1A55` | DreamLink | DreamLink service: calls `C772:CF7C`, key translate |
| 8, 9, 10 | `C000:19E7` | Error | Software error halt (via `C000:1DCF` endpoint dispatch) |

## C000:1AA2 — Multi-Function Service (Slot 0/6)

The main thunk A handler. Reads a service byte from `[ES:SI]`
(using BX as the segment, SI as the offset), restores ES, loads
DI from `[710F]`, then dispatches on AL:

```asm
C000:1AA2  8CC5           mov bp,es       ; save ES
C000:1AA4  8EC3           mov es,bx       ; ES = caller segment
C000:1AA6  268A04         mov al,[es:si]  ; AL = service byte
C000:1AA9  8EC5           mov es,bp       ; restore ES
C000:1AAB  8B3E0F71       mov di,[710F]   ; DI = state pointer
C000:1AAF  3C05           cmp al,5
C000:1AB1  7423           jz 1AD6         ; AL == 5: display script render
C000:1AB3  3C07           cmp al,7
C000:1AB5  742F           jz 1AE6         ; AL == 7: display script render (alt)
C000:1AB7  3C03           cmp al,3
C000:1AB9  741F           jz 1ADA         ; AL == 3: text output service
C000:1ABB  3C08           cmp al,8
C000:1ABD  741F           jz 1ADE         ; AL == 8
C000:1ABF  3C09           cmp al,9
C000:1AC1  741F           jz 1AE2         ; AL == 9
```

| AL | Handler | Behavior |
| ---: | --- | --- |
| 3 | `C000:1ADA` | Text output service: calls `C000:1DEA`. |
| 5 | `C000:1AD6` | Display script render. |
| 7 | `C000:1AE6` | Display script render (alternate). |
| 8 | `C000:1ADE` | Service 8. |
| 9 | `C000:1AE2` | Service 9. |

## C000:1DEA — Text Output Service

Called from slot 0 (AX=3). The text output engine for the display.
Loops reading characters, calls `C000:1E60` (character setup) and
`C000:20D3` (character classification). Large routine spanning
`C000:1DEA..2069` (24 blocks).

Character processing pipeline:
1. `C000:1E60` — Set up character from source
2. `C000:1EC0` — Character attribute lookup
3. `C000:1EE0` / `C000:1EFD` — Character width/positioning
4. `C000:2036` — Pixel-level character blit
5. `C000:21A3` — Advance cursor position
6. `C000:21C3` — Line wrap/scroll check
7. `C000:21DC` — Multi-byte character handler

## C000:1A18 — Key Event Dispatch (Slot 2/5/7)

Tests `[7195]` for the key source mode. If nonzero, calls
`C000:316D` (serial I/O input). Always calls `C000:0A69`
(key code translation). Dispatches on the translated key code
for special handling (error halt via `C000:19E7` if invalid).

## C000:1A55 — DreamLink Service (Slot 4)

Tests `[7195]` and DL value. If valid, calls `C772:CF7C` (far call
into C772 DreamLink handler) and `C000:0A69` (key translate).
Falls through to `C000:19E7` (error halt) if DL is invalid.

## C000:1DCF — Endpoint Dispatch (Slot 8)

Dispatches on `[6F51]` (DreamLink endpoint):
- `0x0A` → `C000:0D42` (DreamLink endpoint check)
- `0x0B` → `C000:0D53`
- other → `C000:0D61`

## C000:2295 — Request-Record Service Dispatcher

Called from thunk-A multi-function service `AL=5` (`C000:1AD6`). The caller
passes a request script through `[ES:SI]`; `C000:2295` follows the script
pointer to the request record, reads the subservice byte, and dispatches
through the word table at `C000:22EF`.

Result convention:

| Request offset | Meaning |
| ---: | --- |
| `+0x04` | Returned pointer, usually a buffer or count word such as `[1006]`. |
| `+0x06` | Returned status word. Low byte is cleared; high byte receives the service status/error value. |

Subservices used by the word-processor file paths include:

| Subservice | Handler | Current read |
| ---: | --- | --- |
| `0x00` | `C000:2309` | Find-first/probe selected file via `AH=4Eh`; maps common DOS errors into UI status codes. |
| `0x01` | `C000:2339` | Rename: get attributes with `AH=43h`, reject read-only files, then rename with `AH=56h`. |
| `0x02` | `C000:238D` | Delete with `AH=41h`. |
| `0x03` | `C000:23BB` | Device/drive control call through `INT 21h AH=FFh`. |
| `0x04` | `C000:2417` | Open/read selected file: open with `AH=3Dh`, read up to 128 bytes with `AH=3Fh`, close with `AH=3Eh` at EOF. |
| `0x05` | `C000:24C0` | Create/open and write selected file: create with `AH=3Ch` or open with `AH=3Dh` on endpoint `0x0B`, hand off `[1006]` count plus `[1008]` data buffers, write full 128-byte chunks with `AH=40h`, close on final short write. Local native STORE does not append a payload `0x1A`; DreamLink EOF is transport-level. |
| `0x06` | `C000:25EC` | Drive free-space/status summary via `AH=36h`; formats counts into `[7A4C...]`. |
| `0x07` | `C000:2798` | Plain-text export: creates a text file and writes a filtered editor-stream view. |
| `0x08` | `C000:29A5` | Plain-text import: opens a text file and feeds translated bytes to the editor endpoint. |
| `0x09` | `C000:2B82` | Finish/EOF helper: sends an output `0x1A` and closes/finishes the transfer path. |
| `0x0A` | `C000:23E8` | Get/set file attributes with `AH=43h`; returns attributes in `SI`. |
| `0x0B` | `C000:2B90` | Handshaked file send/read path using 128-byte file reads and endpoint `AH=03h/04h`. |
| `0x0C` | `C000:2C85` | Handshaked receive/write path using endpoint `AH=04h`, block/checksum validation, and `AH=40h` file writes. |

The native WP edited-file converter in `C772:8046` reaches this dispatcher via
`C772:861B`/`C772:863C` and thunk-A slot 6 (`C772:970F` with `AH=6`). Those
paths are documented with the edited-file format in
[`../../../docs/wp-edited-file-format.md`](../../../docs/wp-edited-file-format.md).

## C772 Blocks Reached via Thunk A

The thunk A services call into C772 for application-level
operations:

| Address | Called from | Purpose |
| --- | --- | --- |
| `C772:CF7C` | `C000:1A55` (slot 4) | DreamLink protocol handler |
| `C772:CE6C` | `C772:CF86` | DreamLink sub-handler: calls `C772:8976`, `970F`, `C50D`, `CB7x` |
