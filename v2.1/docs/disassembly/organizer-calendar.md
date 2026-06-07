# Organizer Calendar

This slice expands the Organizer top-menu `CALENDAR` handler at `DC98:7284` /
file `0x63C04`. CALENDAR is a self-contained foreground viewer: it reads the
current RTC date, renders two month grids, and offers year and display-form
prompts. It does not open an Organizer ODB file.

## Main Loop

`DC98:7284` clears the screen, snapshots today's date through `DC98:0D2A`, and
stores the current year/month/day in `72D7`, `72D9`, and `72DB`. It then draws
the current month on the left and the following month on the right:

```asm
; file 0x63C04
DC98:7284  call DC98:0E70          ; clear/setup display
DC98:7290  call DC98:0D2A          ; current date -> 72D7/72D9/72DB
...
DC98:72B6  xor  cx,cx              ; left month x offset
DC98:72B8  call DC98:6CDD          ; render month grid
...
DC98:72D8  mov  cx,0x00ba          ; right month x offset
DC98:72DB  call DC98:6CDD          ; render next month grid
```

The event loop is small and only changes the visible year/month or exits:

| Input | Action |
| ---: | --- |
| `0x02`, `0x03` | Return `AX=0` to the organizer top menu. |
| `0x0B` | Return `AX=1`. |
| `Y` / `y` | Open the `YEAR` prompt at `DC98:7044`, then redraw both months. |
| `F` / `f` | Open the `DISPLAY FORM` prompt at `DC98:713C`, then redraw headers and months. |
| `0x13` | Previous month, clamped at January 1900. |
| `0x12` | Next month, clamped at December 2099. |

The year clamp matches the standalone year prompt: valid years are
`0x076C..0x0833`, or `1900..2099`.

## Month Grid

`DC98:6CDD` / file `0x6365D` is the month-grid renderer. Its inputs are:

```text
AX = year
BX = month
CX = horizontal offset, 0 for the left grid or 0x00BA for the right grid
```

It renders a three-letter month name from `F12A:000C`, four year digits, weekday
headers, and the day numbers. The date math helpers below it provide month
length, first weekday, and day-count conversion:

| Helper | Role |
| ---: | --- |
| `DC98:D0FA` | Weekday/first-day calculation used before placing day cells. |
| `DC98:D193` | Days-in-month/date validation helper. |
| `DC98:D31E` | Date-count conversion used by calendar and scheduler paths. |

The day numbers are not normal text. They are drawn as 4x6 bitmap digit glyphs
from `F0A6:000C` / file `0x70A6C`:

| Resource | Descriptor | Rendered asset |
| --- | --- | --- |
| `F0A6:000C` / file `0x70A6C` | `FF 42` bitmap glyphs, 4x6 pixels, one byte per row, indexed by digit. | ![calendar digit glyph 0](images/calendar-digit-0-0x70a6c.png) |

When the loop reaches today's date, it compares the cell's year/month/day
against `72D7`, `72D9`, and `72DB` and emits highlight style bytes around the
day number.

`DC98:71F4` / file `0x63B74` renders the seven weekday headers. The display
form byte at `[8A4E]` controls the start day: zero uses the table from the first
entry, and nonzero rotates the table by one day before output.

## Prompts

`DC98:7044` / file `0x639C4` is the `YEAR` prompt. It draws the year prompt
resource, edits a four-digit field through the shared editable-text widget at
`DC98:18EA`, validates `1900..2099`, and returns the accepted year in `AX`.
Invalid entries call the shared error reporter at `DC98:0DAF`.

`DC98:713C` / file `0x63ABC` is the `DISPLAY FORM` prompt. It draws the prompt
menu, then edits `[8A4E]` through the shared prompt selector at `DC98:214E`.
The value is consumed only by the weekday-header renderer.

`DC98:727D` / file `0x63BFD` is a tiny initializer that clears `[8A4E]` to the
default display form.

## Resource Strings

The menu resources are `C000:67AD` display streams. The final formatted text
below omits positioning/control bytes but preserves the visible strings and key
legends:

| Resource | File offset | Descriptor | Final formatted text |
| --- | ---: | --- | --- |
| `F0AB:0002` | `0x70AB2` | `0x5C`-byte right-side menu display stream. | `CALENDAR` / `[<-] PREV MONTH` / `[->] NEXT MONTH` / `[Y] YEAR` / `[F] DISPLAY FORM` |
| `F0B3:0000` | `0x70B30` | `0x2F`-byte `YEAR` menu stream. | `YEAR` / `[RET]    SET` / `[CAN]  CANCEL` |
| `F0B6:0002` | `0x70B62` | `0x37`-byte `DISPLAY FORM` menu stream. | `DISPLAY FORM` / `[RET]    SET` / `[CAN]  CANCEL` |
| `F12A:000C` | `0x712AC` | Twelve packed 3-byte month labels. | `JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC` |
| `F12D:0000` | `0x712D0` | Seven packed 3-byte weekday labels; the renderer copies the first two bytes. | `Su Mo Tu We Th Fr Sa` |

## Boundary

The CALENDAR foreground path is bottomed for current purposes. It uses shared
date math and display widgets, but it has no database, no alarm hooks, and no
calls into the scheduler, address book, or mail-merge/print paths.
