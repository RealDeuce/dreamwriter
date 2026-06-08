# World Clock Application

The organizer world clock, entered from `DEF0:5CA4` when the user
selects WORLD CLOCK (item 0x34) from the organizer menu.

Entry point: `DEF0:A7C0`. Returns via RET when the user exits.

## Entry Flow (DEF0:A7C0)

```text
1. DEF0:0D80                      clear display
2. build display script at 0x18F1:
   a. FF 40 (0, 0x0B)             position for home city name
   b. FF 42 (7, 6)                clock icon bitmap
   c. embed (8, F2F0)             time column header
   d. 0xE2                        underline attribute
3. loop CX=0..19: copy home city name from timezone record
4. C000:3F35(buf)                 render home city panel header
5. FF 40 (8, 0x14)                position for home country name
6. loop CX=0..19: copy home country name (record +0x1C)
7. C000:3F35(buf)                 render home country name
8. FF 40 (0x22, 0x0B)             position for 2nd city name
   FF 42 (7, 6) + embed (0x0F, F2F0) + 0xE2
9. loop CX=0..19: copy 2nd city name from timezone record
10. C000:3F35(buf)                render 2nd city panel header
11. FF 40 (0x2A, 0x14)            position for 2nd country name
12. loop CX=0..19: copy 2nd country name
13. C000:3F35(buf)                render 2nd country name
14. DEF0:90B8                     render time detail view
15. C000:3F35(6, F2BD, 5A)        draw grid frame (6 FF 44 rectangles)
16. C000:3F35(C, F2C6, 82)        draw WORLD CLOCK title + key legend
17. read timezone display params from [A444] record:
    CX = [+0x1B] - 2              time display X position
    DX = [+0x1A] + 0xE4           time display Y position
18. main display loop
```

## Display Layout

Two timezone panels, side-by-side on the 480×64 LCD:

```text
┌──────────────────────┬──────────────────────┐
│ [icon] ABIDJAN       │ [icon] ABU DHABI     │
│ Ivory Coast          │ United Arab Emirates │
│    12:00             │    16:00             │
└──────────────────────┴──────────────────────┘
  WORLD CLOCK                    Key legend →
```

Panel 1 (home city) is at X=0, panel 2 (2nd city) at X=0x22.

## Main Display Loop (DEF0:AA8E..ABFA)

After the initial render, reads the home city's map coordinates
and enters a timed loop that blinks the city indicator on the
world map while updating the time display.

### Setup (DEF0:AA8E)

```text
SI = 0                           panel toggle (0 or 1)
DI = 0                           tick counter (counts to 3)
CX = home_record[+0x1B] - 2     map X (from [A444] timezone)
DX = home_record[+0x1A] + 0xE4  map Y
```

### Tick Loop (DEF0:AAE6)

```text
1. DI++
2. if DI < 3: → DEF0:AB7B (time update only)
3. if DI == 3: → DEF0:AAEF (redraw indicator + time)
```

### Indicator Blink (DEF0:AAEF, every 3 ticks)

```text
1. push DX, CX; DI = 0          save position, reset counter
2. SI = 1 - SI                  toggle: 0→1→0→1...
3. build display script at 0x18F1:
   FF 40 (CX, DX)               home city map position
   FF 42 (6, 6, SI*6+6, F2F1)   indicator bitmap:
     SI=0 → F2F1:0006 (filled)
     SI=1 → F2F1:000C (hollow)
4. C000:3F35(buf)                render blinking indicator
5. pop DI=0, CX, DX             restore
```

The city indicator on the world map blinks by alternating
between the filled and hollow 6×6 icons every 3 timer ticks.
Only the home city indicator blinks; the 2nd city indicator
is static (drawn once by DEF0:90B8).

### Time Update (DEF0:AB7B)

```text
1. DEF0:9058                    update time for both panels
2. DEF0:0063                    delay/timer check
3. if no key ready: → AAE6      continue tick loop
4. DEF0:0043                    read key → dispatch
```

## Key Dispatch

| Key | Code | Handler | Action |
| --- | ---: | --- | --- |
| CANCEL | `0x02`/`0x03` | return 0 | Exit world clock. |
| EXIT | `0x0B` | return 1 | Exit world clock. |
| S/s | `0x53`/`0x73` | `DEF0:9BFC` | Set time/date. |
| H/h | `0x48`/`0x68` | `DEF0:92EF(0)` | Set home city. |
| 2 | `0x32` | `DEF0:92EF(1)` | Set 2nd city. |
| F/f | `0x46`/`0x66` | `DEF0:9E42` | Display form (12/24 hour). |
| A/a | `0x41`/`0x61` | `DEF0:A581` | Daily alarm setup. |

After any handler returns, the full display is redrawn from
`DEF0:A7CF` (step 2 of entry flow).

## Timezone Data Table

222 timezone records at `F382:000E` (file `0xF382E`), each
0x38 (56) bytes. Record count at `F68B:000E` (file `0xF68BE`).

### Record Format

| Offset | Size | Content |
| ---: | ---: | --- |
| `+0x00` | 20 | City name (uppercase, null-padded). |
| `+0x14` | 4 | Reserved (zero). |
| `+0x18` | 2 | UTC offset in quarter-hours (signed word). |
| `+0x1A` | 1 | Display position parameter 1. |
| `+0x1B` | 1 | Display position parameter 2. |
| `+0x1C` | 20 | Country/region name (mixed case, null-padded). |
| `+0x30` | 8 | Reserved (zero). |

UTC offset examples: 0 = UTC+0 (Abidjan), 16 = UTC+4 (Abu Dhabi),
-24 = UTC-6 (Acapulco), 38 = UTC+9:30 (Adelaide).

Display position computation:
- X = `[+0x1B] - 2`
- Y = `[+0x1A] + 0xE4`

### Sample Records

| # | City | UTC | Country |
| ---: | --- | ---: | --- |
| 0 | ABIDJAN | +0:00 | Ivory Coast |
| 1 | ABU DHABI | +4:00 | United Arab Emirates |
| 2 | ACAPULCO | -6:00 | Mexico |
| 5 | ADELAIDE | +9:30 | Australia |
| 219 | YANGON | +6:30 | Myanmar |
| 221 | ZURICH | +1:00 | Switzerland |

### Timezone Index Table

Word-sized lookup table at `F68C:0000` (file `0xF68C0`), maps
display position to timezone record number. Default: identity
mapping (0, 1, 2, ..., 221). Reordered when the user changes
city sort order via the TAB key in the city select screen.

## DEF0:90B8 — World Map and City Indicator Display

Called from the main entry flow (step 14). Renders the 96×64
world map bitmap and places city indicator icons at the timezone
positions for both panels.

```text
1. C000:3F35(0, F2BC, F)           attribute set
2. build script at 0x18F1:
   FF 40 (0, 0xE6)                 position at (0, 230)
   FF 42 (0x40, 0x60, 2, F2F5)    world map: 64 rows × 96 pixels
                                    source at F2F5:0002 (file 0xF2F52)
3. C000:3F35(buf)                  render world map
4. build script for 2nd city [A448]:
   FF 40 ([+0x1B]-2, [+0x1A]+0xE4) position from timezone record
   FF 42 (6, 6, 0xC, F2F1)         city indicator (6×6, hollow frame)
5. build script for home city [A444]:
   FF 40 ([+0x1B]-2, [+0x1A]+0xE4) position from timezone record
   FF 42 (6, 6, 6, F2F1)           city indicator (6×6, filled block)
6. C000:3F35(buf)                  render both indicators
```

World map bitmap (96×64, 768 bytes):

![World map](images/wc-world-map-0xF2F52.png)

Initial render: 2nd city drawn first (hollow, F2F1:000C), home
city drawn second (filled, F2F1:0006) on top. The home city
indicator then blinks in the main loop (see above). The timezone
record fields +0x1A and +0x1B encode each city's map coordinates:
- Map X = `[+0x1B] - 2` (range ~0x12..0x55, left to right)
- Map Y = `[+0x1A] + 0xE4` (range ~0xF5..0x139, top to bottom)

## DEF0:9058 — Time Display

Called from the main display loop (via `RETF` — far call).
Reads current date/time, then renders the time for both panels
using the shared alarm time renderer from the scheduler:

```
DEF0:9058  push cx / push si
           call DEF0:0074              ; read RTC date
           call DEF0:0098              ; read RTC time
           ; panel 1 (home city):
           call C000:3F35(A, F2BB, 6)  ; position for home time
           mov si,[0xA444]             ; home city index
           mov cl,[si-0x59B6]          ; CL = DST flag from [A64A+si]
           xor ch,ch
           call DEF0:8AB4              ; render time (AX=date, BX=time, CX=DST)
           ; compute 2nd city offset:
           mov cx,0
           mov es,cx
           mov cx,[es:0xA446]          ; CX = UTC offset diff
           call DEF0:8FC0              ; adjust date/time by offset
           ; panel 2 (2nd city):
           call C000:3F35(A, F2C3, 6)  ; position for 2nd time
           mov si,[0xA448]             ; 2nd city index
           mov cl,[si-0x59B6]          ; CL = DST flag
           xor ch,ch
           call DEF0:8AB4              ; render adjusted time
           pop si / pop cx
           retf
```

`[A446]` holds the pre-computed UTC offset difference between the
2nd and home cities (in quarter-hours), adjusted for DST. It is
recalculated whenever either city or DST state changes.

## DEF0:92C4 — Form Display Helper

Shared helper called by the city select, set time, display form,
and alarm handlers. Draws the form input area:

```
DEF0:92C4  call C000:3F35(0, F2BC, F)  ; FF 06 attribute set
           call DEF0:0DF5(1, 0xCE, 3, 0x90, 0x3A)  ; input field rect
           ret
```

## DEF0:92EF — Set Home/2nd City

Called with AX=0 for home city, AX=1 for 2nd city. Allocates
0x16 bytes on stack. Draws a scrolling 6-line city list.

### Local Variables

| Offset | Purpose |
| --- | --- |
| `[bp-2]` | Mode: 0=home city, 1=2nd city (from AX param). |
| `[bp-4]` | Previous city index (saved on entry). |
| `[bp-6]` | Selected city index (highlighted row). |
| `[bp-8]` | Scroll position (first visible city in list). |
| `[bp-A]` | Display loop counter (0..5 for 6 visible rows). |
| `[bp-C]` | Scratch buffer pointer. |
| `[bp-E]` | Working city index for inner loops. |
| `[bp-10]` | Resolved city index for ENTER/INS. |
| `[bp-13]` | Key code from DEF0:0043. |
| `[bp-15]` | UTC offset difference scratch. |

### Entry

```text
1. DEF0:92C4                   draw form input area
2. C000:3F35(6, F2BD, 5A)      grid frame
3. if [bp-2]==1: C000:3F35(8, F2D8, 60) — "SET 2ND CITY"
   if [bp-2]==0: C000:3F35(6, F2D2, 61) — "SET HOME CITY"
4. [bp-4] = current index from [A448] or [A444]
5. [A74A] = 0 (normal display mode)
6. [bp-6] = [bp-8] = 0
```

### Display Loop (DEF0:9359..94C8)

Renders 6 rows (counter at `[bp-A]` from 0 to 5). Each row:

```text
1. FF 02 cursor at (row*2+2, 0xD1)     position
2. if row == selected: 0xF2             highlight attribute
3. 0xE3                                 normal attribute
4. if [A74A]==0: read city from RAM table [A44A+index]
   if [A74A]!=0: use index directly
5. if DST flag [A64A+city] != 0: '*'    DST marker
   else: ' '
6. 0xE3
7. if city == [A444] (home): 0xF8       home city marker
8. 0xE3
9. if index < record count (222):
   loop 20 chars: copy city name from F382 record
   else: FF 0E 0078 (blank row filler)
10. C000:3F35(buf)                      render row
```

### Key Dispatch

| Key | Code | Handler | Action |
| --- | ---: | --- | --- |
| TAB | `0x09` | `DEF0:94F5` | Toggle display order ([A74A] 0↔1). |
| INS | `0x0D` | `DEF0:9519` | Toggle DST for selected city. |
| A-Z/a-z | `0x41-5A`/`0x61-7A` | `DEF0:95F5` | Alpha search: jump to first city starting with letter. |
| ↵ ENTER | `0xDA` | `DEF0:9668` | Confirm city selection. |
| ↑ | `0x13` | `DEF0:97CD` | Move selection up. |
| ↓ | `0x12` | `DEF0:97CD` | Move selection down. |
| CAN | — | `DEF0:9810` | Cancel, return to main. |

### TAB — Toggle Display Order (DEF0:94F5)

Toggles `[A74A]` between 0 and 1:
- 0 = display cities by RAM index order (from `[A44A]` table)
- 1 = display cities by timezone record order (alphabetical)

Resets scroll position and redraws.

### INS — Toggle DST (DEF0:9519)

Toggles the DST flag byte at `[A64A + city_index]` between 0
and 1. Then recalculates the UTC offset for `[A446]`:

```text
new_offset = record[A448].utc - record[A444].utc
           + (DST[A448] - DST[A444]) × 4
```

The ×4 converts DST flag (0/1) to quarter-hours (0/4 = 0/1 hour).

If the modified city is the home city, adjusts the RTC time by
±4 quarter-hours (±1 hour) via `DEF0:8FC0` / `DEF0:00BC` /
`DEF0:00D9` / `DEF0:C5BC`.

### Alpha Search (DEF0:95F5)

Converts lowercase to uppercase (`sub [bp-13], 0x20`), sets
`[A74A]=1`, then scans through the timezone index table comparing
the first character of each city name (`F382:[F68C:[i*2]*0x38+0x0E]`)
until finding one >= the typed letter. Jumps the selection to
that position.

### ENTER — Confirm Selection (DEF0:9668)

Resolves the selected index, then swaps city assignments in the
RAM order table by cycling through indices. If selecting the
2nd city, stores to `[A448]`. If selecting the home city:

```text
1. store [A444] = selected
2. read RTC date/time
3. compute UTC offset: new_record[+0x18] - old_record[+0x18]
4. if DST flags differ: adjust ±4 quarter-hours
5. DEF0:8FC0(date, time, offset) — adjust RTC
6. DEF0:00BC, DEF0:00D9           — write date/time
7. DEF0:C5BC                      — update alarm state
```

Then recalculates `[A446]` for the 2nd panel.

### Arrow Navigation (DEF0:97CD)

```text
↑ (0x13): if [bp-6] > 0: [bp-6]--
↓ (0x12): if [bp-6] < count-1: [bp-6]++
if [bp-6] < [bp-8]: [bp-8]--        scroll up
if [bp-6] >= [bp-8]+6: [bp-8]++     scroll down
```

## DEF0:9BFC — Set Time/Date

Allocates 0x14 bytes on stack. Edits time and date using a
field-by-field input form with live preview.

### Local Variables (date/time struct)

| Offset | Purpose |
| --- | --- |
| `[bp-2]` | Year |
| `[bp-4]` | Day |
| `[bp-6]` | Month |
| `[bp-8]` | AM/PM flag (0=AM, 1=PM, 12-hour mode only) |
| `[bp-A]` | Minute |
| `[bp-C]` | Hour (12-hour adjusted if [1108]!=0) |

### Entry

```text
1. DEF0:92C4                   draw form input area
2. C000:3F35(6, F2BD, 5A)      grid frame
3. C000:3F35(E, F2CE, 38)      "SET TIME/DATE" legend
4. DEF0:0074, DEF0:0098        read current RTC date/time
5. [bp-2] = [18E3] (year)
   [bp-6] = [18E5] (month)
   [bp-4] = [18E7] (day)
6. if [1108]!=0 (12-hour mode):
     [bp-C] = [18EB] mod 12; if 0 → 12
     [bp-8] = ([18EB] >= 12) ? 1 : 0
   else (24-hour mode):
     [bp-C] = [18EB]
7. [bp-A] = [18ED] (minute)
```

### Field Edit Loop (DI=0..3)

```text
DI=0: DEF0:0F87 format hour → DEF0:1806 numeric input
DI=1: DEF0:0F87 format minute → DEF0:1806 numeric input
DI=2: DEF0:9B2F AM/PM selector (skipped in 24-hour mode)
DI=3: DEF0:9817 renders "Time HH:MM am/pm (Day) MMM DD, YYYY"
      then DEF0:9AA0 validates all fields
      if valid: ↵ (0xDA) confirms
```

Field descriptors at `F2F2:0002` (8 bytes per field, 3 entries).

### Navigation Keys (DEF0:9E02)

```text
LEFT  (0x11): DI--; if DI==2 and 24-hour mode: DI-- (skip AM/PM)
RIGHT (0x10): DI++; if DI==2 and 24-hour mode: DI++ (skip AM/PM)
UP    (0x13): DI = 0 (first field)
DOWN  (0x12): DI = 3 (confirm)
```

### Validation and Commit

`DEF0:9AA0` validates the struct at `[bp-C]`:
- 12-hour: hour 1..12; 24-hour: hour 0..23
- Minute < 60
- Month 1..12
- Year 1980 (0x7BC)..2080 (0x820)
- Day 1..days_in_month (via `DEF0:C394`)

Returns: 0=valid, 1=bad hour, 2=bad minute, 4=bad month,
5=bad day, 6=bad year. On error, `DEF0:00F9` shows message.

On success, writes fields back to `[18E3..18EF]` and calls
`DEF0:00BC` (write date), `DEF0:00D9` (write time),
`DEF0:C5BC` (update alarm state).

## DEF0:9E42 — Display Form Toggle

Allocates 2 bytes on stack. Toggles the 12/24 hour display
format stored at `[1108]`:

```text
1. DEF0:92C4                   draw form area
2. C000:3F35(6, F2BD, 5A)      grid frame
3. C000:3F35(8, F2DE, 37)      "DISPLAY FORM" legend
4. DEF0:1775(DEF0:9058)        display current time
5. read current [1108] value
6. DEF0:2097(0, F2E2, &[bp-2], 0xDD)  selection input
7. if confirmed: write new value to [1108]
```

Selection options from `F2E2:0000`: ` 24 H` (24-hour format)
and the alternative (12-hour format).

## DEF0:A581 — Daily Alarm

No local stack frame. Manages up to 4 daily alarm entries stored
at `[A74C]` (23 bytes per entry, 4 entries). Displays alarm list
and allows editing/deleting:

```text
1. C000:3F35(6, F2BD, 5A)      grid frame
2. C000:3F35(2, F2E7, 48)      "DAILY ALARM" legend
3. C000:3F35(0, F2C4, F)       attribute set for alarm area
4. DEF0:0DF5(1, 0xBE, 3, 0xAE, 0x3A)  input field rect
5. C000:3F35(A, F2EB, 17)      "TIME" column header
6. for SI=0..3: DEF0:9EB4(SI)  display alarm row
7. DEF0:A4F8(DI)               highlight selected row
8. loop:
   DEF0:9058                   update time display
   DEF0:0063                   timer check
   DEF0:0043                   read key
   dispatch:
     ↵ (0xDA): DEF0:A039 — edit alarm, DEF0:C5BC — update RTC
     CAN (0x03): return SI
     BACK (0x08): delete alarm entry, shift remaining up
     ↑ (0x13): move selection up (if DI > 0)
     ↓ (0x12): move selection down (if entry exists)
     other: loop
```

### Alarm Entry Format

23 bytes per entry at `[A74C + index * 0x17]`:

| Offset | Size | Content |
| ---: | ---: | --- |
| `+0x00` | 2 | Alarm enable flag (-1 = disabled). |
| `+0x02` | 21 | Alarm data (time, label). |

Global alarm state at `[A791]` (enable word, -1 = no alarm)
and `[A793]` (alarm active byte).

### DEF0:9EB4 — Alarm Row Display

Called with AX=row index, BX=alarm time (minutes since midnight,
or -1 for empty), CX=alarm label string pointer.

```text
1. FF 40 (row*10+0x13, 0xC2)     position at row
2. if BX == -1 (empty slot):
     write "  :     " (blank time)
   else:
     hour = BX / 60; minute = BX % 60
     if [1108]!=0 (12-hour):
       display_hour = hour mod 12; if 0 → 12
       append 'p'/'a' + 'm' based on hour >= 12
     else (24-hour):
       display_hour = hour
       append "  " (two spaces)
     format as "HH:MM am" or "HH:MM   "
3. C000:3F35(buf)                render time string
4. DEF0:1471(label, 0x14, 1, 0xF1) render label text at row position
```

Alarm time is stored as minutes since midnight (0..1439).

### DEF0:A4F8 — Alarm Highlight

Builds an `FF 44` rectangle to highlight the selected alarm row:

```text
FF 44  x = row*10+0x12
       y = 0xC1
       w = 9
       h = 0xA8
       scroll_x = 0
       scroll_y = 0
       0x0A (attribute)
```

### DEF0:A039 — Alarm Edit

Large function (A039..A4F8, 29 blocks). Edits time and label
for the selected alarm. Called with AX=alarm index.

Fields: hour (2 digits), minute (2 digits), AM/PM (12-hour
mode only, via `DEF0:9B2F`), label (text via `DEF0:1806`).

Validates hour/minute ranges. On confirm (0xDA), stores the
alarm time as minutes since midnight at `[A74C + index*0x17]`
and the label string at `[A74C + index*0x17 + 2]`.

## Display Script Sources

| Address | File | Length | Purpose |
| --- | ---: | ---: | --- |
| `F2BD:0000` | `0xF2BD0` | 90 | Grid frame: `FF 02` cursor + 6 `FF 44` rectangles. |
| `F2BC:0000` | `0xF2BC0` | 15 | `FF 06` attribute set for form input area. |
| `F2BB:000A` | `0xF2BBA` | 6 | `FF 40` position for panel 1 time display. |
| `F2C3:000A` | `0xF2C3A` | 6 | `FF 02` cursor for panel 2 time display. |
| `F2C4:0000` | `0xF2C40` | 15 | `FF 06` attribute set for alarm list area. |
| `F2C6:0000` | `0xF2C60` | 130 | `WORLD CLOCK` title + full key legend. |
| `F2CE:0000` | `0xF2CE0` | 56 | `SET TIME/DATE` sub-screen legend. |
| `F2D2:0000` | `0xF2D20` | 97 | `SET HOME CITY` legend with `[TAB] ORDER`, `[INS] DAYLIGHT TIME`. |
| `F2D8:0000` | `0xF2D80` | 96 | `SET 2ND CITY` legend (same format as F2D2). |
| `F2DE:0000` | `0xF2DE0` | 55 | `DISPLAY FORM` legend with `[↵] SET`, `[CAN] CANCEL`. |
| `F2E2:0000` | `0xF2E20` | — | Display form options: ` 24 H`. |
| `F2E7:0000` | `0xF2E70` | 72 | `DAILY ALARM` legend with `[↵] EDIT`, `[BACK] DELETE`, `[CAN] EXIT`. |
| `F2EB:0000` | `0xF2EB0` | 23 | `TIME` column header for alarm list. |
| `F2F0:0008` | `0xF2F08` | 7 | City name icon (filled, 6×7). ![](images/wc-clock-icon1-0xF2F08.png) |
| `F2F0:000F` | `0xF2F0F` | 7 | City name icon (hollow frame, 6×7). ![](images/wc-clock-icon2-0xF2F0F.png) |
| `F2F1:0006` | `0xF2F16` | 6 | Map city indicator (filled, 6×6 — home city). ![](images/wc-time-ind0-0xF2F16.png) |
| `F2F1:000C` | `0xF2F1C` | 6 | Map city indicator (hollow frame, 6×6 — 2nd city). ![](images/wc-time-ind1-0xF2F1C.png) |
| `F2F5:0002` | `0xF2F52` | 768 | World map bitmap (96×64). ![](images/wc-world-map-0xF2F52.png) |
| `F2C5:0000` | `0xF2C50` | 14 | `FF 02` cursor + `Time` label (used by DEF0:9817). |
| `F2C5:000E` | `0xF2C5E` | 14 | `FF 02` cursor + `Date` label (used by DEF0:9817). |
| `F2F2:0002` | `0xF2F22` | 24 | Time input field descriptors (3 × 8 bytes). |

## String Data

| File offset | Source | Content |
| ---: | --- | --- |
| `0xF2C6C` | `F2C6:000C` | `WORLD CLOCK` title. |
| `0xF2C7E` | `F2C6:001E` | `[H] SET HOME CITY` key legend. |
| `0xF2C8E` | `F2C6:002E` | `[2] SET 2ND CITY` key legend. |
| `0xF2C9E` | `F2C6:003E` | `[S] SET TIME/DATE` key legend. |
| `0xF2CAE` | `F2C6:004E` | `[F] DISPLAY FORM` key legend. |
| `0xF2CBE` | `F2C6:005E` | `[A] DAILY ALARM` key legend. |
| `0xF2CF4` | `F2CE:0014` | `SET TIME/DATE` sub-screen title. |
| `0xF2D2C` | `F2D2:000C` | `SET HOME CITY` sub-screen title. |
| `0xF2D3E` | `F2D2:001E` | `[TAB] ORDER`. |
| `0xF2D4E` | `F2D2:002E` | `[INS] DAYLIGHT TIME`. |
| `0xF2D8C` | `F2D8:000C` | `SET 2ND CITY` sub-screen title. |
| `0xF2DEA` | `F2DE:000A` | `DISPLAY FORM` sub-screen title. |
| `0xF2E78` | `F2E7:0008` | `DAILY ALARM` sub-screen title. |
| `0xF2E88` | `F2E7:0018` | `[↵]   EDIT`. |
| `0xF2E98` | `F2E7:0028` | `[BACK] DELETE`. |
| `0xF2EA8` | `F2E7:0038` | `[CAN]  EXIT`. |
| `0xF2EBA` | `F2EB:000A` | `TIME` column header. |
| `0xF2C50` | `F2C5:0000` | `Time` label (set time display). |
| `0xF2C5E` | `F2C5:000E` | `Date` label (set time display). |
| `0xF382E` | `F382:000E` | Timezone city/country database (222 × 56 bytes). |

## State Variables

| Address | Purpose |
| --- | --- |
| `[A444]` | Home city timezone index. |
| `[A446]` | UTC offset difference: 2nd city minus home city, in quarter-hours, DST-adjusted. Recalculated on city change or DST toggle. |
| `[A448]` | 2nd city timezone index. |
| `[A44A+i]` | City order table (addressed as `[i - 0x5BB6]`). Maps display position to city index. |
| `[A64A+i]` | DST flag per city (addressed as `[i - 0x59B6]`). 0=standard, 1=daylight saving. |
| `[A74A]` | City list display mode: 0=by RAM order table, 1=by timezone record order (alphabetical). |
| `[A74C]` | Daily alarm table base (4 × 23 bytes). |
| `[A791]` | Alarm enable word (-1 = disabled). |
| `[A793]` | Alarm active byte. |
| `[1108]` | Time format: 0 = 12-hour, non-zero = 24-hour |
| `[18E3]` | Year (from RTC) |
| `[18E5]` | Month |
| `[18E7]` | Day |
| `[18EB]` | Hour |
| `[18ED]` | Minute |
| `[18EF]` | Second |

## Related Functions

| Address | Purpose |
| --- | --- |
| `DEF0:0074` | Read RTC date (year/month/day → [18E3..18EB]). |
| `DEF0:0098` | Read RTC time (hour/minute/second → [18EB..18EF]). |
| `DEF0:00BC` | Write date to RTC. |
| `DEF0:00D9` | Write time to RTC. |
| `DEF0:8AB4` | Time display renderer (12-hour AM/PM format). |
| `DEF0:8FC0` | Time adjustment for timezone offset. |
| `DEF0:90B8` | Time detail view (from scheduler). |
| `DEF0:92C4` | Form display helper (attribute + input field rect). |
| `DEF0:9817` | Time/date display: renders "HH:MM am (Day) MMM DD, YYYY". |
| `DEF0:9AA0` | Time validation. |
| `DEF0:9B11` | String to number conversion. |
| `DEF0:9B2F` | AM/PM selector input. |
| `DEF0:9EB4` | Alarm row display. |
| `DEF0:A039` | Alarm edit handler. |
| `DEF0:A4F8` | Alarm row highlight. |
| `DEF0:C5BC` | RTC alarm state update. |

## ROM Data Regions

| Start | End | Type | Content |
| ---: | ---: | --- | --- |
| `0xF382E` | `0xF68BE` | data | Timezone database: 222 × 56-byte records (city, UTC offset, country). |
| `0xF68BE` | `0xF68C0` | data | Timezone record count (word: 0x00DE = 222). |
| `0xF68C0` | `0xF6A78` | data | Timezone index table: 222 × 2-byte word indices. |
