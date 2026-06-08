# Calendar Application

The organizer calendar, entered from `DEF0:5C2E` when the user
selects CALENDAR (item 0x32) from the organizer menu.

Entry point: `DEF0:627F`. Returns via RET when the user exits.

## Entry Flow (DEF0:627F)

```text
1. DEF0:0D80                      clear display
2. C000:3F35(8, F255, 5A)         draw calendar grid frame (6 FF 44 rectangles)
3. C000:3F35(4, F263, 5C)         draw title + key legend
4. C000:3F35(2, F25B, 6)          set cursor position (1, 0x36) for top calendar
5. DEF0:61EF                      draw day-of-week headers (top)
6. C000:3F35(8, F25B, 6)          set cursor position (1, 0xF0) for bottom calendar
7. DEF0:61EF                      draw day-of-week headers (bottom)
8. DEF0:0074                      read current date from RTC
9. compute next month (DX=year, SI=month, DI=next month)
10. C000:3F35(E, F25B, F)         set attribute for top calendar area
11. DEF0:5CD8(DX, SI, 0)          render current month calendar
12. C000:3F35(E, F25C, F)         set attribute for bottom calendar area
13. DEF0:5CD8(year, DI, BA)       render next month calendar
14. DEF0:0043                     read key → main loop
```

## Main Key Loop (DEF0:62E1..63D1)

```text
Key dispatch:
  0x02/0x03  → exit (return 0)
  0x0B       → exit (return 1)
  0x13 (↑)   → previous month
  0x12 (↓)   → next month
  0x59/'Y'   → Year select sub-screen (DEF0:603F)
  0x46/'F'   → Display Form toggle (DEF0:6137)
  other      → ignored, loop to DEF0:0043
```

### Previous Month (0x13 / ↑)

Decrements SI (month). If SI reaches 0, wraps to 12 and
decrements DX (year). Year clamped to minimum 0x76C (1900).

### Next Month (0x12 / ↓)

Increments SI (month). If SI reaches 13, wraps to 1 and
increments DX (year). Year clamped to maximum 0x833 (2099).

After any month change, redraws both calendars via `DEF0:5CD8`
and re-reads the next key.

## DEF0:61EF — Day-of-Week Headers

Reads 3-character day abbreviations from `F2E5:000C` (file
`0xF2E5C`) and builds a display script with 7 entries. If
`[A7A8]!=0` (week starts on Monday), shifts the starting index
by 1.

Day abbreviation table (7 × 3 bytes):

```text
F2E5:000C: Sun Mon Tue Wed Thu Fri Sat
```

## DEF0:5CD8 — Month Calendar Renderer

Called with AX=year, BX=month, CX=Y-offset for positioning.

1. Builds `FF 02` cursor position at (4, CX+0x12).
2. Reads 3-character month name from `F2E3:0008` (file `0xF2E38`)
   at offset `(month-1) × 3`.
3. Converts year to 4 ASCII digits via successive divide by
   1000/100/10/1, ORing with 0x30.
4. Renders month name + year header via `C000:3F35`.
5. Calls `DEF0:C394(year, month)` — days in month.
6. Calls `DEF0:C2FB(year, month, 1)` — day-of-week for 1st.
7. Calls `DEF0:C51F` — build calendar grid layout.
8. Loops day=1..days_in_month, rendering each day number at the
   correct grid position (row = week, column = day-of-week).

Month abbreviation table (12 × 3 bytes):

```text
F2E3:0008: JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC
```

### Day Number Rendering (DEF0:5E52)

For each day, computes the grid position:
- Y = CX + 0x36 + row × 16
- X = column × 4 + 4

Builds an `FF 02` cursor + two ASCII digit characters (tens and
units, with leading space for single digits). Renders via
`C000:3F35`.

## DEF0:603F — Year Select Sub-Screen

Entered when the user presses 'Y'. Draws:

1. Calendar grid frame (`F255:0008`, 90 bytes).
2. Year screen legend (`F26B:0004`, 47 bytes): `YEAR`,
   `[↵]    SET`, `[CAN]  CANCEL`.
3. Input field rectangle via `DEF0:0DF5`.
4. `Year` label (`F269:0000`, 10 bytes).
5. Calls `DEF0:0F87` to format current year as 4-digit string.
6. Calls `DEF0:1806` for numeric input field editing.

Returns the new year value in AX.

## DEF0:6137 — Display Form Toggle

Entered when the user presses 'F'. Toggles `[A7A8]` between
0 (week starts Sunday) and 1 (week starts Monday). Draws:

1. Calendar grid frame (`F255:0008`).
2. Display Form legend (`F26E:0004`, 55 bytes): `DISPLAY FORM`,
   `[↵]    SET`, `[CAN]  CANCEL`.
3. Input field rectangle via `DEF0:0DF5`.
4. `Year` label (`F269:0000` — shared, but used as generic label).
5. Calls `DEF0:2097` for selection input.

After toggling, redraws the full calendar with the new week start.

## Date Math Functions

| Address | Purpose | Parameters |
| --- | --- | --- |
| `DEF0:C2C9` | Leap year check | AX=year. Returns AX=1 if leap, 0 if not. |
| `DEF0:C2FB` | Day-of-week | AX=year, BX=month, CX=day. Returns AX=day (0=Sun..6=Sat). |
| `DEF0:C394` | Days in month | AX=year, BX=month. Returns AX=days (28-31). Feb adjusted for leap. |
| `DEF0:C51F` | Calendar grid layout | Builds grid positions for month display. |

### Days-per-Month Table

12 word entries at `F37E:000E` (file `0xF37EE`):

```text
31 28 31 30 31 30 31 31 30 31 30 31
```

February overridden to 29 by `DEF0:C2C9` leap year check.

## State Variables

| Address | Purpose |
| --- | --- |
| `[18E3]` | Current year (read from RTC via DEF0:0074) |
| `[18E5]` | Current month |
| `[A7A8]` | Display form: 0=week starts Sunday, 1=week starts Monday |

## Display Script Sources

| Address | File | Length | Purpose |
| --- | ---: | ---: | --- |
| `F255:0008` | `0xF2558` | 90 | Calendar grid frame: 6 `FF 44` rectangles (horizontal row dividers). |
| `F263:0004` | `0xF2634` | 92 | Main screen title + key legend: `CALENDAR`, `[↑] PREV MONTH`, `[↓] NEXT MONTH`, `[Y] YEAR`, `[F] DISPLAY FORM`. |
| `F25B:0002` | `0xF25B2` | 6 | `FF 02` cursor (1, 0x36) — top calendar position. |
| `F25B:0008` | `0xF25B8` | 6 | `FF 02` cursor (1, 0xF0) — bottom calendar position. |
| `F25B:000E` | `0xF25BE` | 15 | `FF 06` attribute for top calendar area (column=4, Y=0x36, cell 12×0x7E). |
| `F25C:000E` | `0xF25CE` | 15 | `FF 06` attribute for bottom calendar area (column=4, Y=0xF0, cell 12×0x7E). |
| `F26B:0004` | `0xF26B4` | 47 | Year sub-screen: `YEAR`, `[↵] SET`, `[CAN] CANCEL`. |
| `F25D:000E` | `0xF25DE` | 15 | `FF 44` rectangle for Year/Form input field. |
| `F269:0000` | `0xF2690` | 10 | `FF 40` position + `Year` label. |
| `F26E:0004` | `0xF26E4` | 55 | Display Form sub-screen: `DISPLAY FORM`, `[↵] SET`, `[CAN] CANCEL`. |

## String Data

| File offset | Source | Content |
| ---: | --- | --- |
| `0xF2E38` | `F2E3:0008` | Month abbreviations: `JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC` (12 × 3 bytes). |
| `0xF2E5C` | `F2E5:000C` | Day-of-week abbreviations: `Sun Mon Tue Wed Thu Fri Sat` (7 × 3 bytes). |
| `0xF2634` | `F263:0004` | `CALENDAR` title. |
| `0xF2644` | `F263:0014` | `[↑] PREV MONTH` (0xDE = ↑ glyph). |
| `0xF2654` | `F263:0024` | `[↓] NEXT MONTH` (0xDD = ↓ glyph). |
| `0xF2664` | `F263:0034` | `[Y] YEAR`. |
| `0xF2674` | `F263:0044` | `[F] DISPLAY FORM`. |
| `0xF26B4` | `F26B:0004` | `YEAR` title. |
| `0xF26C4` | `F26B:0014` | `[↵]    SET`. |
| `0xF26D4` | `F26B:0024` | `[CAN]  CANCEL`. |
| `0xF26E4` | `F26E:0004` | `DISPLAY FORM` title. |
| `0xF2690` | `F269:0000` | `Year` input label. |
| `0xF37EE` | `F37E:000E` | Days-per-month table (12 words). |
