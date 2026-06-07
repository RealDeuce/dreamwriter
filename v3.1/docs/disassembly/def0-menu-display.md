# DEF0 Menu Display System

The menu display system at `DEF0:2000..29DB` (80 blocks). Renders
interactive menu screens using `DEF0:2097` (the display state query
service, far-call table entry #7) and callbacks into C772 application
routines for menu content.

Called from the file management UI ([`def0-file-dialogs.md`](def0-file-dialogs.md))
and from C772 application code.

See [`def0-display-services.md`](def0-display-services.md) for the
display service API and [`def0-display-rendering.md`](def0-display-rendering.md)
for the low-level rendering pipeline.

## DEF0:2097 — Display State Query

Far-call table entry #7 (`[021C]`). Takes AX (string pointer),
BX (string segment), CX (state pointer), DX (display parameters).
Stack arguments at `[bp+6]` and `[bp+8]` control interactive behavior.

Scans the input string counting `0x7B` (`{`) characters, then dispatches
based on `[bp+0A]`:

- If `[bp+0A]` is zero: calls `DEF0:1FF3` to render the string directly
- Otherwise: calls `DEF0:1FF3` with CX=1 for interactive mode, then
  enters a keystroke wait loop using `DEF0:0063` (check input status)
  and `DEF0:0043` (read key)

The interactive mode supports callback pointers at `[1AF1..1AF3]`
(set by far-call table entry #11, `DEF0:1775`). When a callback is
registered and the `0x1000` flag is set in `[bp+8]`, the callback is
invoked via `CALL FAR [1AF1]` while waiting for input.

9 callers across the DEF0 and C772 segments.

## DEF0:2761 — Menu Screen Entry

Called from `C772:E801` (application menu handler). Sets `[146F]=FFFF`
(temp state), calls `DEF0:115C` (display subsystem query/init) with
AX=6, BX=`F175`, then checks if result is `0x31`. On success, enters
the menu rendering loop via `DEF0:2784`.

```asm
DEF0:2764  C7066F14FFFF   mov word [146F],FFFF   ; temp resume state
DEF0:276A  B80600         mov ax,6
DEF0:276D  BB75F1         mov bx,F175            ; display mode descriptor
DEF0:2770  9A5C11F0DE     call far DEF0:115C     ; display init
DEF0:2775  C7066F140000   mov word [146F],0
DEF0:277B  3D3100         cmp ax,31              ; check result
```

## DEF0:2784 — Menu Rendering Loop

Loops through menu items by calling C772 application callbacks:

1. `DEF0:26B4` — calls `C772:E81A..E946` (7 callbacks)
2. `DEF0:25B7` — calls `C772:E84A` for content rendering
3. `ED1B:0D25` — utility library call
4. `DEF0:2DF1` — display init and rendering

Each iteration calls `C772:E832` to check if more items exist,
then `DEF0:25B7` and `DEF0:2DF1` to render each page.

## DEF0:26B4 — Menu Item Dispatch

Calls `DEF0:115C` to set up the display mode (AX varies per item
type), then dispatches through 7 C772 callbacks to process menu
items:

| Callback | C772 target | Purpose |
| --- | --- | --- |
| `C772:E81A` | `C772:7115` | Get item count |
| `C772:E8C5` | inner | Item type A |
| `C772:E895` | inner | Item type B |
| `C772:E8AD` | inner | Item type C |
| `C772:E87D` | inner | Item type D |
| `DEF0:4A19` | — | File operation entry |

Each C772 callback follows the same pattern: save registers, set
ES=`0xCEF`, call inner routine, read result from `[746C]`, RETF.

## DEF0:2612 — Menu Display Init

Called from `DEF0:2DF1`. Calls `DEF0:115C` with AX=8 to initialize
the display mode, then dispatches through 6 C772 callbacks for
content setup:

| Callback | C772 target |
| --- | --- |
| `C772:E910` | content init |
| `C772:E92B` | section A |
| `C772:E8DD` | section B |
| `C772:E8F5` | section C |
| `C772:E946` | section D |
| `DEF0:21FC` | display page render |

## DEF0:27E3 — Menu Page Renderer

Called from `DEF0:2E1C`. Builds the visual layout for a menu page:

1. Calls `DEF0:0D80` (display init)
2. Renders a 20-byte display script from `F140`
3. Reads menu state from `[1333]` and `[1334]`
4. Calls `DEF0:2097` multiple times with different display parameters
   to render menu items at calculated positions
5. Calls `DEF0:0D91` to render labels from `F146`/`F147` data
6. Calls `C000:08A2` for additional display operations

## DEF0:21FC — Display Page Builder

Large routine (DEF0:21FC..23EB, 495 bytes). Calls `DEF0:0D80` (init),
`DEF0:0D91` (build display script), then renders 10 menu items via
`DEF0:2097` with calculated positions and parameters. Branch table
at the end dispatches on item selection result.

## DEF0:2435 — Alternate Display Page Builder

Similar to `DEF0:21FC` but renders a different page layout. Also uses
`DEF0:0D80`, `DEF0:0D91`, `DEF0:2097`, and `DEF0:1775` (callback
pointer setup). Called from `DEF0:25DA`.

## C772 Application Callbacks

The menu display system uses 12 C772 callbacks (all at C772:E800..E946)
that follow a uniform pattern:

```asm
C772:Exxxx  push cx/dx/si/di/bp
            mov bp,0xCEF        ; ES = application data segment
            mov es,bp
            call C772:inner     ; application-specific handler
            pop bp/di/si/dx/cx
            mov al,[746C]       ; result from handler
            mov ah,0
            retf                ; return AX = result
```

## Display State Variables

| Address | Purpose |
| --- | --- |
| `[1333]` | Menu page row count |
| `[1334]` | Menu page column count |
| `[146F]` | Temp resume state (FFFF during menu operations) |
| `[1AF1..1AF3]` | Display callback far pointer |
| `[746C]` | C772 callback result byte |
| `F140..F175` | ROM display mode descriptors |

## Block Map (80 blocks)

| Address range | Blocks | Purpose |
| --- | --- | --- |
| `DEF0:2000..2097` | 6 | Display script sub-helpers |
| `DEF0:2097..21FC` | 9 | Display state query + interactive loop |
| `DEF0:21FC..23EB` | 4 | Display page builder A |
| `DEF0:2435..25B7` | 5 | Display page builder B |
| `DEF0:25B7..2612` | 7 | Content render + dispatch |
| `DEF0:2612..26B4` | 12 | Menu display init + C772 callbacks |
| `DEF0:26B4..2761` | 13 | Menu item dispatch + C772 callbacks |
| `DEF0:2761..27E3` | 10 | Menu screen entry + rendering loop |
| `DEF0:27E3..29DB` | 14 | Menu page renderer + navigation |
