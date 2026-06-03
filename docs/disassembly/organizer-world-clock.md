# Organizer World Clock

This slice expands the Organizer top-menu `WORLD CLOCK` handler at
`DC98:B67C` / file `0x67FFC`. It bottoms the foreground world clock UI: the
map, two city clocks, city picker, time/date editor, display-form selector, and
daily-alarm editor. The shared next-alarm selector `DC98:D3BB` is expanded in
[`organizer-alarm.md`](organizer-alarm.md).

## App Entry

`DC98:B67C` clears the screen, draws the two selected city labels, draws the
map/header resources, then enters a live key/event loop.

```asm
; file 0x67FFC
DC98:B67C  55                push bp
DC98:B686  9A 70 0E 98 DC    call DC98:0E70
DC98:B68B  ...               ; build an inline FF40/FF42 script at 72E5
DC98:B70C  A1 EA 86          mov  ax,[0x86ea]    ; home city index
DC98:B71E  B9 18 00          mov  cx,0x18
DC98:B721  9A AD 67 00 C0    call C000:67AD      ; home city name
...
DC98:B802  A1 EE 86          mov  ax,[0x86ee]    ; second city index
DC98:B814  B9 18 00          mov  cx,0x18
DC98:B817  9A AD 67 00 C0    call C000:67AD      ; second city name
DC98:B877  E8 52 E8          call DC98:A0CC      ; redraw map and markers
DC98:B87A  ...               ; draw F104:000C line script
DC98:B888  ...               ; draw F10D:000E title/menu script
```

The selected-city state is:

| Address | Role |
| ---: | --- |
| `86EA` | Home city table index. |
| `86EE` | Second city table index. |
| `86EC` | Second-city time delta from home, in 15-minute ticks. |
| `86F0..87EF` | City-order permutation used by the picker. |
| `88F0..89EF` | Per-city daylight-time flags. |
| `89F0` | City-picker order/search mode flag. |

The city table starts at `F1CA:0006` / file `0x71CA6` and uses `0x38`-byte
records:

| Offset | Size | Observed use |
| ---: | ---: | --- |
| `+0x00` | `0x18` | City name/display field. |
| `+0x18` | word | Base time-zone value in 15-minute ticks. |
| `+0x1A` | byte | Map marker x coordinate. |
| `+0x1B` | byte | Map marker y coordinate. |
| `+0x1C` | `0x1A` | Country/region display field. |

The first record formats as:

```text
city="ABIDJAN", tz_ticks=0, marker=(0x2c,0x24), country="Ivory Coast"
```

## Map And Clock Assets

`DC98:A0CC` draws the map area. It sends a clear/positioning script, then emits
an `FF42` bitmap record for the 96x64 map at `F13C:000A`.

| Resource | PNG | Descriptor |
| --- | --- | --- |
| Map bitmap | ![world map](images/worldclock-map-0x713ca.png) | `file 0x713CA`, `96x64`, row bytes `12`. |
| Label marker | ![label marker](images/worldclock-label-marker-0x71380.png) | `file 0x71380`, `7x6`, row bytes `1`; used beside the two city labels. |
| Blink marker A | ![marker A](images/worldclock-marker-blink-a-0x7138e.png) | `file 0x7138E`, `6x6`, row bytes `1`. |
| Blink marker B | ![marker B](images/worldclock-marker-blink-b-0x71394.png) | `file 0x71394`, `6x6`, row bytes `1`. |

```asm
; file 0x66A4C
DC98:A0CC  ...               ; draw F103:0006
DC98:A103  C7 07 40 00       mov  word [bx],0x0040  ; FF42 height
DC98:A10E  C7 07 60 00       mov  word [bx],0x0060  ; FF42 width
DC98:A11A  BA 0A 00          mov  dx,0x000a
DC98:A11D  B9 3C F1          mov  cx,0xf13c         ; F13C:000A map
...
DC98:A1C8  BA 14 00          mov  dx,0x0014         ; second city marker
DC98:A285  BA 0E 00          mov  dx,0x000e         ; home city marker
```

`DC98:9AC8` renders the two large time readouts with bitmap digits, not the
normal text font. The input date/time pointers are `AX=72D7` and `BX=72DF`;
`CX` selects the top or bottom readout.

| Resource | PNG | Descriptor |
| --- | --- | --- |
| Digit `0` | ![world clock digit 0](images/worldclock-digit-0-0x716ca.png) | `file 0x716CA`, `7x12`, row bytes `1`, digit stride `0x0D`. |
| Separator | ![time separator](images/worldclock-time-separator-0x7174c.png) | `file 0x7174C`, `4x12`, row bytes `1`. |
| Blank leading hour | ![blank leading hour](images/worldclock-blank-hour-0x71759.png) | `file 0x71759`, `7x12`, row bytes `1`. |

```asm
; file 0x66448
DC98:9AC8  8B F8             mov  di,ax
DC98:9AD4  8B C1             mov  ax,cx
DC98:9AED  C7 04 0B 00       mov  word [si],0x000b  ; date icon height
DC98:9AFB  C7 04 0B 00       mov  word [si],0x000b  ; date icon width
DC98:9B03  B9 16 00          mov  cx,0x0016
DC98:9B0B  B9 78 F1          mov  cx,0xf178         ; date/month icon table
...
DC98:9B4F  C7 04 0C 00       mov  word [si],0x000c  ; digit height
DC98:9B5D  C7 04 07 00       mov  word [si],0x0007  ; digit width
DC98:9B68  BA 99 00          mov  dx,0x0099         ; blank if hour < 10
DC98:9B6B  B9 6C F1          mov  cx,0xf16c
...
DC98:9C48  B9 8C 00          mov  cx,0x008c         ; time separator
DC98:9C4B  B8 6C F1          mov  ax,0xf16c
```

In 12-hour mode `[6808] != 0`, `DC98:9AC8` maps hour `0` to `12` and uses
`hour % 12` for display. In 24-hour mode `[6808] == 0`, it renders the raw
`0..23` hour and suppresses the leading hour digit with the blank glyph.

## Time Adjustment

`DC98:A06C` refreshes the RTC-backed base time and redraws both city clocks:

```asm
; file 0x669EC
DC98:A06C  E8 B9 6C          call DC98:0D2A      ; INT 21h AH=2A wrapper
DC98:A071  E8 DA 6C          call DC98:0D4E      ; INT 21h AH=2C wrapper
DC98:A082  B8 D7 72          mov  ax,0x72d7
DC98:A085  BB DF 72          mov  bx,0x72df
DC98:A088  8B 36 EA 86       mov  si,[0x86ea]
DC98:A08C  8A 8C F0 88       mov  cl,[si+0x88f0] ; home daylight flag
DC98:A093  E8 32 FA          call DC98:9AC8
DC98:A098  A1 EC 86          mov  ax,[0x86ec]
DC98:A09E  8B C8             mov  cx,ax
DC98:A0A3  E8 2E FF          call DC98:9FD4      ; apply city delta
DC98:A0C2  E8 03 FA          call DC98:9AC8
```

`DC98:9FD4` treats `CX` as a signed quarter-hour count. It adjusts minutes by
`(CX & 3) * 15`, adjusts hours by `CX / 4`, and calls the date helpers when
the hour crosses midnight.

## Main Loop

The main screen loop keeps `SI` as a two-state marker blink and `DI` as a
divider. Every third pass it redraws the selected home-city marker from
`F138:(0x000E + SI * 6)`, then refreshes the live clocks and polls for input.

```asm
; file 0x68258
DC98:B8D8  47                inc  di
DC98:B8D9  83 FF 03          cmp  di,0x0003
DC98:B8E3  33 FF             xor  di,di
DC98:B8E5  B8 01 00          mov  ax,0x0001
DC98:B8E8  2B C6             sub  ax,si
DC98:B8EA  8B F0             mov  si,ax
...
DC98:B93D  8B C6             mov  ax,si
DC98:B942  F7 E3             mul  bx
DC98:B944  BA 0E 00          mov  dx,0x000e
DC98:B947  B9 38 F1          mov  cx,0xf138
DC98:B96B  9A 6C A0 98 DC    call DC98:A06C
DC98:B970  9A 19 0D 98 DC    call DC98:0D19
```

Subcommand dispatch is local and shallow:

| Key | Handler |
| --- | --- |
| `H` / `h` | `DC98:A2CF` with `AX=0`; set home city. |
| `2` | `DC98:A2CF` with `AX=1`; set second city. |
| `S` / `s` | `DC98:AAD5`; set time/date. |
| `F` / `f` | `DC98:AD1B`; display form. |
| `A` / `a` | `DC98:B457`; daily alarm. |

Exit events `0x02` and `0x03` return `AX=0`; event `0x0B` returns `AX=1`.

## City Picker

`DC98:A2CF` redraws the right panel and chooses one of two text scripts:

| Mode | Resource | Length | Final text |
| --- | --- | ---: | --- |
| Home city | `F119:000A` / file `0x7119A` | `0x61` | `SET HOME CITY`, `[TAB] ORDER`, `[INS] DAYLIGHT TIME`, `[0xDA] SET`, `[CAN] CANCEL`. |
| Second city | `F11F:000C` / file `0x711FC` | `0x60` | `SET 2ND CITY`, `[TAB] ORDER`, `[INS] DAYLIGHT TIME`, `[0xDA] SET`, `[CAN] CANCEL`. |

The picker draws six rows at a time from the 222-city table. Each row is an
inline `FF02`/text stream with:

| Field | Meaning |
| --- | --- |
| `F2` before the row | Highlight on the currently selected row. |
| `*` or space | Daylight-time flag from `88F0 + city_index`. |
| `F8` before city text | Marks the home city while browsing. |
| 20 text bytes | City name copied from the city table. |
| `FF 0E 78 00` | Placeholder row when the viewport runs past the table end. |

Keyboard behavior from the loop:

| Event | Action |
| ---: | --- |
| `0x03` | Cancel and return nonzero. |
| `0x09` | Toggle `[89F0]` order mode and redraw from the top. |
| `0x0D` | Toggle the highlighted city's daylight-time flag. |
| `A..Z`, `a..z` | Jump to the first city whose name starts at or after that letter. |
| `0xDA` | Accept the highlighted city and recompute `[86EC]`. |
| `0x12`, `0x13` | Move selection down/up within the six-row viewport. |

Accepting a city recomputes:

```text
86EC = second_city.tz_ticks - home_city.tz_ticks
       + (second_city_daylight - home_city_daylight) * 4
```

If changing the home city or its daylight flag changes the home offset, the
handler applies the offset to the RTC wrapper cache with `DC98:9FD4`, commits
through `DC98:0D72`/`0D8F`, and calls `DC98:D3BB` so the global alarm target is
rebuilt.

## Set Time/Date

`DC98:AAD5` redraws the right panel and sends the `F116:0000` text script. The
script format is positioned text:

```text
FF40 y=0x0000 x=0x017c  text="SET TIME/DATE"
FF40 y=0x000f x=0x016e  text="[0xDA] <selector 0x12> SET"
FF40 y=0x001b x=0x016e  text="[CAN]  CANCEL"
```

The handler reads date/time through `DC98:0D2A` and `DC98:0D4E`, copies the
cache into local editable fields, and redraws a formatted time/date row. The
cache layout is:

| Address | Value |
| ---: | --- |
| `72D7` | Year. |
| `72D9` | Month. |
| `72DB` | Day. |
| `72DD` | Weekday returned by `AH=2A`. |
| `72DF` | Hour. |
| `72E1` | Minute. |
| `72E3` | Second. |

The final time string generated by `DC98:A6F0` is:

```text
24-hour: "HH:MM"
12-hour: "HH:MM  am" or "HH:MM  pm"
```

Month and weekday strings are fixed-width tables at `F12A:000C` / file
`0x712AC`: `JAN..DEC` and `Sun..Sat`.

On accept, the handler validates the date, writes year/month/day and
hour/minute back to the wrapper cache, forces seconds to zero, commits through
`DC98:0D72` and `DC98:0D8F`, then calls `DC98:D3BB`.

## Display Form

`DC98:AD1B` edits `[6808]`, the time display-form flag. It draws:

```text
FF40 y=0x0000 x=0x017f  text="DISPLAY FORM"
FF40 y=0x000f x=0x016e  text="[0xDA] <selector 0x12> SET"
FF40 y=0x001b x=0x016e  text="[CAN]  CANCEL"
```

Then it calls the shared selector at `DC98:214E` over two fixed strings at
`F129:0004` / file `0x71294`:

| Selector value | Final option text |
| ---: | --- |
| `0` | `{ 24 HOUR }` |
| `1` | `{ 12 HOUR }` |

Cancel returns nonzero and leaves `[6808]` unchanged. Accept writes the selected
byte back to `[6808]`.

## Daily Alarm

`DC98:B457` draws the daily-alarm panel:

```text
FF40 y=0x0000 x=0x0182  text="DAILY ALARM"
FF40 y=0x000f x=0x0174  text="[0xDA] <selector 0x12> EDIT"
FF40 y=0x001b x=0x0174  text="[BACK] DELETE"
FF40 y=0x0027 x=0x0174  text="[CAN]  EXIT"
FF40 y=0x0008 x=0x00c5  text="TIME"
FF40 y=0x0008 x=0x00f4  text="MESSAGE"
```

It edits four rows at `89F2 + row * 0x17`:

| Row field | Meaning |
| ---: | --- |
| `+0x00` word | Minutes after midnight, or `0xFFFF` when disabled. |
| `+0x02` bytes | NUL-terminated message text. |

`DC98:AD8D` formats each row as:

```text
disabled: "  :    "
enabled 24-hour: "HH:MM"
enabled 12-hour: "HH:MMam" or "HH:MMpm"
```

`DC98:AF12` is the row editor. It edits hour, minute, optional `a`/`p`, and
message text, then stores the row as minutes after midnight. Backspace on an
enabled row deletes that row by shifting later rows upward, disables the final
row, and calls `DC98:D3BB`.

These daily alarms are not just cosmetic UI state. The retained
power-transition path calls `DC98:D3BB`, which scans scheduler alarms and these
four daily-alarm rows. A selected world-clock daily alarm is marked in the
shared low-RAM alarm buffer as `6D4C = 0x0100 + row`.

## Bottom

The `WORLD CLOCK` foreground root bottoms inside this slice:

| Root | Bottomed at |
| --- | --- |
| App entry | `DC98:B67C` draws the main screen, live clocks, and dispatches subcommands. |
| Map and clock redraw | `DC98:A0CC`, `A06C`, `9AC8`, and `9FD4`. |
| City selection | `DC98:A2CF`, including order mode, letter jump, daylight flags, and city offset recompute. |
| Set time/date | `DC98:AAD5` through RTC wrapper cache commit. |
| Display form | `DC98:AD1B` selector over `{ 24 HOUR }` / `{ 12 HOUR }`. |
| Daily alarm UI | `DC98:B457`, row renderer `AD8D`, and row editor `AF12`. |

The shared scheduler/world-clock next-alarm selector and selected-alarm display
loop are covered by [`organizer-alarm.md`](organizer-alarm.md).
