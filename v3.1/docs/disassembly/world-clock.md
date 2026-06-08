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

## Main Display Loop (DEF0:AAEF)

Alternates between the two timezone panels, updating the
time display and checking for key input:

```text
loop:
  1. toggle SI between 0 and 1 (panel index)
  2. build display script:
     FF 40 (CX, DX)              time position from timezone record
     FF 42 (6, 6)                time indicator bitmap
     embed (SI*6+6, F2F1)        time digit segment
  3. C000:3F35(buf)              render time display
  4. DEF0:9058                   update time for both panels
  5. DEF0:0063                   delay/timer check
  6. if timer expired → loop
  7. DEF0:0043                   read key → dispatch
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

## DEF0:9058 — Time Display

Called from the main display loop. Reads current date/time
(`DEF0:0074`, `DEF0:0098`), then displays the time for both
panels:

```text
1. DEF0:0074                   read RTC date
2. DEF0:0098                   read RTC time
3. C000:3F35(A, F2BB, 6)       position for panel 1 time
4. DEF0:8AB4([A444] offset)    render panel 1 time (AM/PM format)
5. DEF0:8FC0([A446])           adjust for timezone offset
6. C000:3F35(A, F2C3, 6)       position for panel 2 time
7. DEF0:8AB4([A448] offset)    render panel 2 time
```

The timezone offset at `[A446]` is read from RAM `[SI - 0x59B6]`
where SI = `[A444]`. This maps to the per-city UTC offset stored
in RAM at `[A64A + city_index]`.

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
0x16 bytes on stack. Draws the city selection list with scrolling.

```text
1. DEF0:92C4                   draw form area
2. C000:3F35(6, F2BD, 5A)      draw grid frame
3. if AX==1: C000:3F35(8, F2D8, 60) — "SET 2ND CITY" legend
   if AX==0: C000:3F35(6, F2D2, 61) — "SET HOME CITY" legend
4. load current city index from [A448] or [A444]
5. display 6 cities at a time in scrolling list
6. key loop:
   - show city names from timezone data (F382/F68C)
   - highlight selected city with 0xF2 attribute
   - mark home city with 0xF8 marker
   - mark alarm-enabled city with '*'
   - ↵ (0xDA): confirm selection
   - ↑ (0x13): scroll up
   - ↓ (0x12): scroll down
   - TAB: reorder
   - INS: toggle daylight time
   - CAN: cancel
```

### City List Display

Each row in the 6-line list shows:

```text
[highlight] [alarm*] city_name (20 chars) [home_marker]
```

City names are read from `F382:[0x0E + F68C:[index*2] * 0x38]`.
When the display reaches the end of the 222-record list, remaining
rows show `FF 0E 0078` (underline off + spacing).

## DEF0:9BFC — Set Time/Date

Allocates 0x14 bytes on stack. Draws the time/date editing form
with 3 or 4 input fields depending on time format:

```text
1. DEF0:92C4                   draw form area
2. C000:3F35(6, F2BD, 5A)      draw grid frame
3. C000:3F35(E, F2CE, 38)      draw "SET TIME/DATE" legend
4. DEF0:0074, DEF0:0098        read current date/time
5. if [1108]!=0 (24-hour mode):
     store hour directly
   else (12-hour mode):
     compute hour mod 12 → [bp-0xC]
     if hour==0: set to 12
     compute AM/PM flag → [bp-8]
6. field edit loop (DI=0..3):
   field 0: hour (2 digits)
   field 1: minute (2 digits)
   field 2: AM/PM selector (12-hour mode only, via DEF0:9B2F)
   field 3: confirm (via DEF0:9817 display, ↵=0xDA to accept)
7. validate via DEF0:9AA0
8. if valid: write to RTC via DEF0:00BC/DEF0:00D9
9. DEF0:C5BC                   update RTC alarm state
```

### Field Navigation

```
LEFT  (0x11): previous field, skip AM/PM in 24-hour mode
RIGHT (0x10): next field, skip AM/PM in 24-hour mode
UP    (0x13): jump to first field (DI=0)
DOWN  (0x12): jump to confirm (DI=3)
```

Field descriptors at `F2F2:0002` (8 bytes per field).

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

Renders a single alarm entry row. Called with AX=row index,
BX=alarm data word, CX=alarm data string pointer. Formats the
time and label for display.

### DEF0:A4F8 — Alarm Highlight

Updates the highlight cursor on the selected alarm row.
Called with AX=row index.

### DEF0:A039 — Alarm Edit

Edits the selected alarm entry. Sets time and label fields.
Called with AX=alarm index.

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
| `F2F0:0008` | `0xF2F08` | — | Clock icon bitmap (7×6). |
| `F2F0:000F` | `0xF2F0F` | — | Clock icon bitmap (alternate position). |
| `F2F1:0006` | `0xF2F16` | — | Time digit segment bitmaps (2 panels × 6 bytes). |
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
| `0xF382E` | `F382:000E` | Timezone city/country database (222 × 56 bytes). |

## State Variables

| Address | Purpose |
| --- | --- |
| `[A444]` | Home city timezone index |
| `[A446]` | Home city UTC offset (from RAM table) |
| `[A448]` | 2nd city timezone index |
| `[A64A+i]` | Per-city alarm/offset byte (indexed by city) |
| `[A74A]` | Display mode flag for city list |
| `[A74C]` | Alarm entry table base (4 × 23 bytes) |
| `[A791]` | Alarm enable word (-1 = disabled) |
| `[A793]` | Alarm active byte |
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
| `DEF0:9817` | Time display formatting. |
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
