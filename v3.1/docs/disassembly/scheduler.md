# Scheduler Application

The organizer scheduler, entered from `DEF0:5C2E` when the user
selects SCHEDULER (item 0x33) from the organizer menu.

Entry point: `DEF0:8908`. Returns via RET when the user exits.

## Entry Flow (DEF0:8908)

```text
1. DEF0:0D80                      clear display
2. C000:3F35(C, F298, 1B)         show "*** PLEASE WAIT ***"
3. build path "X:SCHEDULE.ODB"    drive from [1005], filename from F2B9:000A
4. DEF0:010D × 2                  compute free space
5. DEF0:E254                      set file attributes (INT 21h AX=4301h)
6. DEF0:DB47(path, mode=2)        open SCHEDULE.ODB (INT 21h AH=3Dh)
7. store handle at [A002]
8. if open fails:
   a. DEF0:AD5F(path, F2BA, C8)   create new DB (record size 200)
   b. if create fails: show error (DEF0:00F9), return 0
9. DEF0:AC52(A, F2BA, C8)         search/validate records
10. if search fails: close, recreate, retry
11. DEF0:63D6                     init display state
12. DEF0:C5BC                     RTC state check
13. DEF0:8557                     main scheduler UI (blocks until exit)
14. DEF0:0D80                     clear display
15. C000:3F35(C, F298, 1B)        show "*** PLEASE WAIT ***"
16. DEF0:64BD                     flush schedule data (DEF0:DE34 file write)
17. DEF0:E08C(handle, 10, 0)      seek to offset 0x10
18. DEF0:DC5E(handle, [A00A], 320) write 800 bytes of schedule data
19. DEF0:E048(handle)             close file (INT 21h AH=3Eh)
20. DEF0:E254(path, attrs)        restore file attributes
21. return
```

## Database Format

File: `SCHEDULE.ODB` (filename at `F2B9:000A`, file `0xF2B9A`).

- Record size: 0xC8 (200) bytes
- File header: 0x10 (16) bytes
- Schedule data block: 0x320 (800) bytes at file offset 0x10
- Data buffer at `[A00A]` (stack-allocated, 800 bytes)
- Secondary buffer at `[A00C]` (stack-allocated, 1600 bytes)
- Total stack frame: 0x660 (1632) bytes

Records are searched via `DEF0:AC52` and created via `DEF0:AD5F`
using segment `F2BA` as the record descriptor and size 0xC8 (200).

## DEF0:88E2 — Handle Table Init

Called from `DEF0:5C07` (cold init). Clears the 200-entry file
handle table at `[A022]`:

```
DEF0:88E2  xor ax,ax
DEF0:88E4  jmp short 0x8902
DEF0:88E6  mov bx,ax              ; loop body
           shl bx,1               ;   index × 4
           shl bx,1
           mov word [bx+0xA022],0 ;   clear handle word 0
           mov bx,ax
           shl bx,1
           shl bx,1
           add bx,0xA022
           mov word [bx+0x2],0    ;   clear handle word 1
           inc ax
DEF0:8902  cmp ax,0xC8            ; 200 entries
           jl 0x88E6
           ret
```

Each entry is 4 bytes. Table spans `[A022..A342]` (200 × 4 = 800 bytes).

## DEF0:8557 — Main Scheduler UI

Reads current date via `DEF0:0074`, computes day number via
`DEF0:C3B9`, then enters the weekly view loop.

```
DEF0:8557  push bp
           mov bp,sp
           sub sp,0xE             ; 14 bytes locals
           push cx / push dx / push si
           call DEF0:0074         ; read RTC date
           mov cx,0x1
           mov ax,0x18E3          ; year/month/day address
           call DEF0:C3B9         ; compute day number → AX:BX
           mov [bp-4],ax          ; current day (low)
           mov [bp-2],bx          ; current day (high)
           mov [bp-8],ax          ; "today" (low)
           mov [bp-6],bx          ; "today" (high)
           mov [bp-0xC],ax        ; view start (low)
           mov [bp-0xA],bx        ; view start (high)
```

### Local Variables

| Offset | Purpose |
| --- | --- |
| `[bp-2]:[bp-4]` | Current selected day number (32-bit) |
| `[bp-6]:[bp-8]` | Today's day number (32-bit, from RTC) |
| `[bp-A]:[bp-C]` | View start day number (first day of displayed week) |
| `[bp-E]` | Display script buffer write pointer |

### Range Clamping

```
           mov bx,0x1D51
           mov ax,0x1             ; max = 0x11D51
           sub bx,[bp-0xC]
           sbb ax,[bp-0xA]
           jnl 0x85A2             ; if view_start <= max, ok
           mov word [bp-0xC],0x1D52  ; clamp to 0x11D52
           mov word [bp-0xA],0x1     ; (Dec 31 2099)
```

Day numbers: 1 = Jan 1 1900, max = 0x11D52 (73042) = Dec 31 2099.

### Main Loop (DEF0:85E2)

```
DEF0:85A9  xor si,si              ; SI = day index (0..6)
DEF0:85E2  cmp si,7               ; built all 7 days?
           jl 0x85AD              ; no → build next day
           ...                    ; yes → render and read key
           call DEF0:7DE6         ; render week display
           call DEF0:84D2         ; render header/counts
           ...                    ; compute cursor day offset
           call DEF0:7D60         ; highlight selected day
           call DEF0:0043         ; read key
           ; dispatch key code in AX
```

### 7-Day View Builder (DEF0:85AD)

For each day SI=0..6, computes day number by adding SI to view
start `[bp-0xC]`, checks if it equals today `[bp-8]` to set
highlight flag, then calls `DEF0:699E`:

```
DEF0:85AD  xor ax,ax
           push ax                ; push 0
           mov ax,si
           push ax                ; push day index
           ; compute day_num = view_start + SI
           mov cx,si
           add cx,[bp-0xC]
           adc dx,[bp-0xA]
           push dx                ; push day_hi
           ; check if this day == today
           add ax,[bp-0xC]
           adc dx,[bp-0xA]
           cmp dx,[bp-6]          ; compare high word
           jnz not_today
           cmp ax,[bp-8]          ; compare low word
not_today: jnz 0x85D7
           mov bx,1               ; highlight = 1 (today)
           jmp 0x85D9
DEF0:85D7  xor bx,bx              ; highlight = 0
DEF0:85D9  call DEF0:699E         ; entry navigation/update
           add sp,2               ; pop day_hi
           inc si
```

`DEF0:699E(AX=day_num_lo, BX=highlight, CX=day_num_hi, DX=day_hi,
stack=day_index, 0)` — loads and displays the schedule entry for
the given day. Highlight=1 marks today's column.

## Key Dispatch

| Key | Code | Handler | Action |
| --- | ---: | --- | --- |
| CANCEL | `0x02`/`0x03` | return 0 | Exit scheduler. |
| EXIT | `0x0B` | return 1 | Exit scheduler. |
| TAB | `0x09` | `DEF0:821B` | View/edit entry content. |
| BEGIN | `0x0F` | `DEF0:8664` | Jump to first entry date. |
| END | `0x0E` | `DEF0:8688` | Jump to last entry date. |
| D/d | `0x44`/`0x64` | `DEF0:8082` | Edit selected entry date. |
| ← | `0x13` | `DEF0:86E0` | Previous day (scroll if needed). |
| → | `0x12` | `DEF0:87E2` | Next day (scroll if needed). |

### BEGIN Handler (0x0F, DEF0:8664)

Jumps to the date of the first schedule entry:

```
DEF0:8656  cmp ax,0xF             ; BEGIN key?
           jnz 0x8679
           cmp word [0xA008],0    ; any entries?
           jnz 0x8664
           jmp 0x8606             ; no entries → loop
DEF0:8664  mov si,[0xA00C]        ; secondary buffer base
           mov bx,[si]            ; first entry day (low)
           mov ax,[si+2]          ; first entry day (high)
           mov [bp-4],bx          ; set as current day
           mov [bp-2],ax
           mov cx,1               ; redraw flag
           jmp 0x88D8             ; → top of main loop
```

### END Handler (0x0E, DEF0:8688)

Jumps to the date of the last schedule entry:

```
DEF0:8679  cmp ax,0xE             ; END key?
           jnz 0x86A8
           cmp word [0xA008],0    ; any entries?
           jnz 0x8688
           jmp 0x8606             ; no entries → loop
DEF0:8688  mov si,[0xA008]        ; entry count
           shl si,1               ; × 4
           shl si,1
           sub si,4               ; last entry offset
           add si,[0xA00C]        ; + buffer base
           mov bx,[si]            ; last entry day (low)
           mov ax,[si+2]          ; last entry day (high)
           mov [bp-4],bx          ; set as current day
           mov [bp-2],ax
           mov cx,1               ; redraw flag
           jmp 0x88D8             ; → top of main loop
```

The secondary buffer at `[A00C]` holds 4-byte (day_lo, day_hi)
pairs sorted by date. `[A008]` is the total entry count.

### D/d Handler (0x44/0x64, DEF0:86A8)

```
DEF0:86A8  cmp ax,0x44            ; 'D'?
           jz 0x86B2
           cmp ax,0x64            ; 'd'?
           jnz 0x86C7
DEF0:86B2  mov ax,[bp-4]          ; pass current day
           mov bx,[bp-2]
           call DEF0:8082         ; edit date entry
           mov [bp-4],ax          ; update current day
           mov [bp-2],bx          ; (may have changed)
           mov cx,1               ; redraw
           jmp 0x88D8
```

### ← Previous Day (0x13, DEF0:86E0)

Range check ensures current day > 0 before decrementing:

```
DEF0:86C7  mov cx,0               ; check day > 0
           mov bx,0
           sub cx,[bp-4]
           sbb bx,[bp-2]
           jl 0x86D8              ; day > 0 → check key
           jmp 0x87C8             ; day == 0 → try → key
DEF0:86D8  cmp ax,0x13            ; ← key?
           jz 0x86E0
           jmp 0x87C8             ; not ← → try → key
```

If the new day is still within the current 7-day view, just moves
the cursor. If it falls before the view start, scrolls the display
left by building an `FF 44` rectangle scroll command:

```
DEF0:86E0  ; unhighlight current position
           call DEF0:7D60
           sub word [bp-4],1      ; current_day--
           sbb word [bp-2],0
           ; check if new day < view_start
           mov bx,[bp-4]
           mov ax,[bp-2]
           sub bx,[bp-0xC]
           sbb ax,[bp-0xA]
           jl 0x8708              ; before view → scroll
           jmp 0x87AB             ; still in view → cursor

DEF0:8708  ; scroll display right (shift content to show earlier day)
           sub word [bp-0xC],1    ; view_start--
           sbb word [bp-0xA],0
           ; build FF 44 scroll command at 0x18F1:
           ;   FF 44 0008 0000 0030 0168 0000 0008 00
           ;   x=8, y=0, w=0x30(48), h=0x168(360)
           ;   scroll_x=0, scroll_y=8 (shift right 8px)
           ...
           call C000:3F35         ; execute scroll
           ; then rebuild day 0 entry via DEF0:699E
           jmp 0x87AB             ; update cursor
```

### → Next Day (0x12, DEF0:87E2)

Range check ensures current day < max (0x11D58):

```
DEF0:87C8  mov cx,[bp-4]
           mov bx,[bp-2]
           sub cx,0x1D58          ; compare against max
           sbb bx,1              ; 0x11D58 = last valid week start + 6
           jl 0x87DA              ; in range → check key
           jmp 0x88D5             ; at max → ignore
DEF0:87DA  cmp ax,0x12            ; → key?
           jz 0x87E2
           jmp 0x88D5             ; not → → ignore

DEF0:87E2  ; unhighlight, increment day
           call DEF0:7D60
           add word [bp-4],1      ; current_day++
           adc word [bp-2],0
           ; check if new day >= view_start + 7
           mov bx,[bp-4]
           mov ax,[bp-2]
           mov dx,[bp-0xC]
           mov cx,[bp-0xA]
           add dx,7
           adc cx,0
           sub bx,dx
           sbb ax,cx
           jnl 0x8814             ; past view end → scroll
           jmp 0x88B8             ; still in view → cursor

DEF0:8814  ; scroll display left (shift content to show later day)
           add word [bp-0xC],1    ; view_start++
           adc word [bp-0xA],0
           ; build FF 44 scroll command at 0x18F1:
           ;   FF 44 0010 0000 0030 0168 0000 FFF8 00
           ;   x=0x10, y=0, w=0x30(48), h=0x168(360)
           ;   scroll_x=0, scroll_y=-8 (shift left 8px)
           ...
           call C000:3F35         ; execute scroll
           ; then rebuild day 6 entry via DEF0:699E
           jmp 0x88B8             ; update cursor
```

### Cursor Redraw After Scroll

Both ← and → share the same cursor update path:

```
DEF0:87AB  mov ax,[bp-4]          ; current day
           mov bx,[bp-2]
           sub ax,[bp-0xC]        ; - view start = column index
           sbb bx,[bp-0xA]
           call DEF0:7D60         ; highlight new position
           mov ax,[bp-4]
           mov bx,[bp-2]
           xor cx,cx
           call DEF0:7DE6         ; redraw week header
           jmp 0x8606             ; → read next key
```

## DEF0:662F — Init Display

Clears the screen, draws the scheduler frame with 7 day columns,
and populates the time column headers.

```
DEF0:662F  push bp / mov bp,sp / sub sp,2
           call DEF0:0D80              ; clear display
           mov ax,8
           mov bx,0xF29A              ; frame + WEEKLY legend
           mov cx,0x69
           call DEF0:65C8             ; draw frame (calls C000:3F35 × 2)
```

Then builds a display script at buffer `0x18F1`:

```
           ; FF 40 (1, 0x35) — position at (1, 53)
           ; FF 42 (5, 0x124) — bitmap blit (5 bytes from seg 0x124)
           ; [1108]==0: embed (0x0C, F271) — 12-hour time labels
           ; [1108]!=0: embed (0x06, F27D) — 24-hour time labels
           call C000:3F35             ; render time labels
```

Then loops SI=0..6 building each day column:

```
DEF0:66D5  ; for each day column SI:
           ; FF 40 (SI*8+8, 0x38) — position at column
           ; FF 42 (1, 0x121) — day-of-week header bitmap
           ; embed (count, F289/F271/F27D) — column separator
           call C000:3F35             ; render column header
           ; DEF0:0DF5(1, 0x38, SI*8+9, 0x121, 6) — input field rect
DEF0:6777  cmp si,7
           jl 0x66D5                  ; next column
           ret
```

## DEF0:65C8 — Schedule Frame and Legend

Generic frame display helper. Calls `C000:3F35` twice: first
with `(2, F292, 0x5A)` for the scheduler grid frame (6 `FF 44`
rectangles as row dividers), then with the caller's parameters.

```
DEF0:65C8  push bp / mov bp,sp / sub sp,4
           mov [bp-4],ax          ; save caller's AX
           mov [bp-2],bx          ; save caller's BX
           mov dx,cx              ; save caller's CX
           mov ax,0x2
           mov bx,0xF292
           mov cx,0x5A
           call C000:3F35         ; draw grid frame
           mov ax,[bp-4]          ; restore caller params
           mov bx,[bp-2]
           mov cx,dx
           call C000:3F35         ; draw caller's content
           ret
```

Grid frame at `F292:0002` (file `0xF2920`, 0x5A bytes):

```
F2920: 10 FF
       FF 44 00 00  6E 01  40 00  72 00  00 00  00 00
          00
       FF 44 00 00  6E 01  01 00  72 00  00 00  00 00
          0F
       FF 44 02 00  6E 01  01 00  72 00  00 00  00 00
          0F
       FF 44 04 00  6E 01  01 00  72 00  00 00  00 00
          0F
       FF 44 06 00  6E 01  01 00  72 00  00 00  00 00
          0F
       FF 44 08 00  6E 01  01 00  72 00  00 00  00 00
```

Six `FF 44` rectangles: first at x=0,y=0x16E,w=0x40,h=0x72;
remaining five at successive x positions with w=1 (1-pixel
vertical dividers).

## DEF0:65F9 — Load Entry Content

Searches the secondary buffer for the first entry with a day
number >= the given day. Returns the index in AX.

```
DEF0:65F9  push bp / mov bp,sp / sub sp,4
           mov [bp-4],ax          ; target day (low)
           mov [bp-2],bx          ; target day (high)
           xor ax,ax              ; index = 0
           jmp 0x6624
DEF0:660A  mov bx,ax              ; loop body
           shl bx,1
           shl bx,1               ; index × 4
           add bx,[0xA00C]        ; + buffer base
           mov cx,[bx]            ; entry day (low)
           mov bx,[bx+2]          ; entry day (high)
           sub cx,[bp-4]
           sbb bx,[bp-2]
           jl 0x6623              ; entry < target → next
           jmp 0x662A             ; entry >= target → done
DEF0:6623  inc ax
DEF0:6624  cmp ax,[0xA008]        ; index < count?
           jl 0x660A
           ret                    ; AX = found index or count
```

## DEF0:6786 — Display Entry Content

Clears the display and builds the content view screen with the
same time column structure as the weekly view:

```
DEF0:6786  call DEF0:0D80              ; clear display
           ; build script at 0x18F1:
           ; FF 40 (1, 0x35) — position at (1, 53)
           ; FF 42 (5, 0x124) — bitmap blit
           ; [1108]==0: embed (0x0C, F271) — 12-hour
           ; [1108]!=0: embed (0x06, F27D) — 24-hour
           call C000:3F35
           ; then 4 × DEF0:0DF5 for input field rectangles
```

## DEF0:821B — View/Edit Entry Content (TAB)

Allocates 0xD6 bytes on stack. Loads entry content, displays it,
then enters an edit loop:

```
DEF0:821B  push bp / mov bp,sp / sub sp,0xD6
           call DEF0:65F9         ; find entry at current day
           call DEF0:6786         ; display content view
           ; if entry not found: call DEF0:65C8 to show empty frame
           ; key loop:
DEF0:8271  call DEF0:699E         ; update entry navigation
           call DEF0:7DE6         ; render week entries
           call DEF0:6D96         ; read/update entry data
           ; check for exit keys (CANCEL/EXIT/TAB)
           ; on D/d: call DEF0:8082 (edit date)
           ; on D/d: call DEF0:65F9 (reload entry)
           ; loop back to 0x8271
```

Calls from the TAB content view:
- `DEF0:65F9` — search for entry at current day
- `DEF0:6786` — full content screen redraw
- `DEF0:65C8` — frame and legend
- `DEF0:699E` — entry navigation/update
- `DEF0:7DE6` — week display render
- `DEF0:6D96` — entry data read (via `DEF0:E08C` seek + `DEF0:E022` read)

## DEF0:8082 — Edit Selected Entry (D key)

Allocates 0x18 bytes on stack. Draws the date entry screen with
month/day/year input fields:

```
DEF0:8082  push bp / mov bp,sp / sub sp,0x18
           mov [bp-4],ax          ; day number (low)
           mov [bp-2],bx          ; day number (high)
           ; draw frame:
           mov ax,0x2
           mov bx,0xF2B5          ; DATE entry frame
           mov cx,0x30
           call DEF0:65C8         ; frame + legend
           ; draw field labels:
           mov ax,0x8
           mov bx,0xF2B3          ; Date/DATE/SET labels
           mov cx,0x19
           call C000:3F35
           ; draw input box:
           call DEF0:0DF5(1, 0x90, 0x1B, 0x99, 0x19)
           ; convert day number to date:
           call DEF0:C455         ; → year [bp-0xC], month [bp-0xA], day [bp-0x10]
           ; show current values:
           call DEF0:7F07         ; display entry detail
           ; show cursor prompt:
           call C000:3F35(2, F298, 9) ; cursor indicator
```

Then loops over 3 fields using the field descriptor table at
`F2B8:0002`:

```
           ; for DI=0,1,2 (month, day, year):
           ;   DEF0:0F87(buffer, value, [F2B8:DI*8+2])  format number
           ;   DEF0:1806(buffer, params from F2B8)       text input editing
           ; validate result via DEF0:8041
           ; if invalid: show error, retry
           ; return new day number in AX:BX
```

### DEF0:8041 — Date Validation

Validates month (1..12), year (0x76C..0x834 = 1900..2099), and
day (1..days_in_month):

```
DEF0:8041  push si
           mov si,ax              ; SI = date struct pointer
           cmp word [si],1        ; month >= 1?
           jl invalid_month
           cmp word [si],12       ; month <= 12?
           jng check_year
           mov ax,1               ; error: bad month
           jmp done
check_year:
           cmp word [si+4],0x76C  ; year >= 1900?
           jl invalid_year
           cmp word [si+4],0x834  ; year < 2100?
           jl check_day
           mov ax,3               ; error: bad year
           jmp done
check_day:
           call DEF0:C394         ; days_in_month(year, month)
           cmp word [si+2],1      ; day >= 1?
           jl invalid_day
           cmp ax,[si+2]          ; day <= max?
           jnl ok
           mov ax,2               ; error: bad day
           jmp done
ok:        xor ax,ax              ; 0 = valid
done:      pop si
           ret
```

Returns: 0 = valid, 1 = bad month, 2 = bad day, 3 = bad year.

## DEF0:7F07 — Entry Detail Display

Displays the current entry's month, day, and time fields in the
date entry screen. Builds display script at `0x18F1` with
formatted date/time values via `C000:3F35`.

## DEF0:7D60 — Cursor Position Display

Builds an `FF 44` rectangle command at runtime in the display
script buffer at `0x18F1` to highlight the selected day column:

```
DEF0:7D60  push bp / mov bp,sp / sub sp,2
           ; AX = day offset (0..6 = column index)
           ; build at 0x18F1:
           ;   FF 44
           ;   x = AX * 8 + 8     (column position)
           ;   y = 3
           ;   w = 8              (column width)
           ;   h = 0x2A (42)      (column height)
           ;   scroll_x = 0
           ;   scroll_y = 0
           ;   00                 (terminator)
           mov ax,0x18F1
           mov bx,ds
           ; cx = length (0x18F1 to write pointer)
           call C000:3F35         ; render rectangle
           ret
```

The rectangle highlights a single day column in the 7-day grid.
Column X positions: 8, 16, 24, 32, 40, 48, 56.

## DEF0:7DE6 — Week Display Renderer

Formats and renders the month/year header for the current view
position. Calls `DEF0:C455` to convert day number to date
components, then reads the 3-character month abbreviation from
`F2E3:0008` (file `0xF2E38`) and converts year to 4 ASCII
digits.

```
DEF0:7DE6  push bp / mov bp,sp / sub sp,0xE
           mov [bp-4],ax          ; day number (low)
           mov [bp-2],bx          ; day number (high)
           lea ax,[bp-0xC]
           mov cx,[bp-4]
           mov dx,[bp-2]
           call DEF0:C455         ; → year [bp-C], month [bp-A], day [bp-8]
           ; build display script at 0x18F1:
           ;   FF 40 (0, 0) — position at top-left
           ;   3 bytes: month abbreviation from F2E3:(month-1)*3+8
           ;   ' '
           ;   4 bytes: year digits (year/1000, year/100%10, year/10%10, year%10)
```

Year digit conversion:

```
           mov ax,[bp-0xC]        ; year
           mov bx,0x3E8           ; 1000
           cwd
           idiv bx
           or ax,0x30             ; → ASCII thousands digit
           ; ... same for hundreds, tens, units via /100, /10, %10
```

Then continues building the week display with date formatting
for each visible day's time entries. Renders via `C000:3F35`.

## DEF0:84D2 — Header/Date Display

Displays the entry count and free space indicators in the header
area:

```
DEF0:84D2  push bp / mov bp,sp / sub sp,0xA
           ; format entry count:
           lea ax,[bp-4]
           mov bx,[0xA008]        ; entry count
           mov cx,3               ; 3 digits
           call DEF0:0F87         ; format number → string
           lea ax,[bp-4]
           call DEF0:0FE4         ; strip leading zeros
           ; format free space:
           mov bx,[0xA004]        ; free space (low)
           mov ax,[0xA006]        ; free space (high)
           sub bx,0
           sbb ax,1
           jl show_free           ; if < 0x10000, show number
           ; >= 65536: show "*****" (5 asterisks)
           mov byte [bp-0xA],'*'
           mov byte [bp-9],'*'
           mov byte [bp-8],'*'
           mov byte [bp-7],'*'
           mov byte [bp-6],'*'
           mov byte [bp-5],0
           jmp render
show_free: lea ax,[bp-0xA]
           mov bx,[0xA004]
           mov cx,5               ; 5 digits
           call DEF0:0F87
           lea ax,[bp-0xA]
           call DEF0:0FE4         ; strip leading zeros
render:    ; render entry count at (0x183, 0x38):
           lea ax,[bp-4]
           mov bx,ss
           mov cx,0x183
           mov dx,0x38
           call DEF0:0D91         ; display string
           ; render free space at (0x1B9, 0x38):
           lea ax,[bp-0xA]
           mov bx,ss
           mov cx,0x1B9
           mov dx,0x38
           call DEF0:0D91         ; display string
           ret
```

## DEF0:63D6 — Init Display State

Loops through all schedule entries (up to `[A008]` count),
loading each entry's date from the database file and populating
the secondary buffer at `[A00C]`:

```
DEF0:63D6  push bp / mov bp,sp / sub sp,6
           xor si,si              ; entry index = 0
           jmp 0x6474
DEF0:63E4  ; loop body:
           ; DEF0:E08C — seek to entry offset in file
           ; DEF0:E022 — read entry header
           ; DEF0:E022 — read entry data
           ; extract day number, store at [A00C + SI*4]
           ; ...
DEF0:6474  cmp si,[0xA008]        ; index < count?
           jnl 0x647D
           jmp 0x63E4             ; next entry

DEF0:647D  mov ax,[0xA008]        ; clear remaining slots
           jmp 0x64B1
DEF0:6482  ; zero out [A00C + AX*4] entries for AX..0xC8
DEF0:64B1  cmp ax,0xC8            ; 200 max
           jl 0x6482
           ret
```

## DEF0:64BD — Flush Schedule Data

Writes modified schedule entries back to the database file.
Iterates through entries, comparing buffer state to file state:

```
DEF0:64BD  push bp / mov bp,sp / sub sp,6
           ; DEF0:DE34 — write record header
           ; loop through entries:
           ;   DEF0:AE37 — compare entry
           ;   DEF0:E08C — seek to position
           ;   DEF0:E022 — read current
           ;   if changed:
           ;     DEF0:E08C — seek back
           ;     DEF0:DC5E — write updated entry
           ; DEF0:DD27 — truncate file if entries removed
           ret
```

## DEF0:9058 — Schedule Alarm Display

Called from the alarm handler (`DEF0:AAEF`). Reads current date
and time, then displays matching alarm entries:

```
DEF0:9058  push cx
           call DEF0:0074         ; read RTC date
           call DEF0:0098         ; read RTC time
           ; render [SCHEDULE] title:
           call C000:3F35(?, F2BB, ?) ; from F2BB:000A
           ; display alarm entries:
           call DEF0:8AB4         ; first alarm entry
           call DEF0:8FC0         ; time adjustment
           call C000:3F35(...)    ; separator
           call DEF0:8AB4         ; second alarm entry
```

### DEF0:8AB4 — Alarm Entry Display

Large function (8AB4..8FC0, ~500 instructions across 8 blocks).
Formats schedule entry times in 12-hour AM/PM format. Builds
display scripts with time digits and literal "am"/"pm" text:

```
DEF0:8DE4  ; AM path:
           mov byte [bx],0x61    ; 'a'
           mov byte [bx],0x6D    ; 'm'
DEF0:8DF8  ; PM path:
           mov byte [bx],0x70    ; 'p'
           mov byte [bx],0x6D    ; 'm'
```

Renders alarm time, date, and message fields via `C000:3F35`.

### DEF0:8FC0 — Time Adjustment

Handles hour/minute rollover calculations for alarm display.
Calls `DEF0:C3B9` (day number computation) and `DEF0:C455`
(date/time formatting) for date boundary crossings.

## DEF0:90B8 — Schedule Detail View

Called from `DEF0:AA59`. Renders the detail view with time, date,
and message fields across multiple display scripts:

```
DEF0:90B8  ; 206 instructions, calls C000:3F35 × 3
           ; uses display scripts from:
           ;   F2BC — attribute set for list area
           ;   F2BD — position/attribute for detail view
           ;   plus runtime-built display scripts
```

## Display Script Sources

| Address | File | Length | Purpose |
| --- | ---: | ---: | --- |
| `F292:0002` | `0xF2920` | 90 | Scheduler grid frame: 6 `FF 44` rectangles (vertical column dividers). |
| `F298:000C` | `0xF298C` | 27 | `*** PLEASE WAIT ***` loading message. |
| `F29A:0008` | `0xF29A8` | 105 | Main screen: `WEEKLY` title + key legend (`[TAB] CONTENT`, `[D] DATE`, `[BEGIN] BEGIN`, `[END] END`), time column headers, `CONTENT` header. |
| `F2B3:0008` | `0xF2B38` | 25 | Date entry `FF 44` input field rectangle + `Date` label. |
| `F2B5:0004` | `0xF2B54` | 48 | Date entry frame: `DATE` title, `[↵] SET`, `[CAN] CANCEL`. |
| `F2B8:0002` | `0xF2B82` | 24 | Date edit field descriptor table (3 × 8 bytes: month/day/year). |
| `F2BB:000A` | `0xF2BBA` | 10 | `FF 40` + `FF 06` for alarm display positioning. |
| `F2BC:0000` | `0xF2BC0` | 15 | `FF 06` attribute set for schedule list area. |
| `F2BD:0000` | `0xF2BD0` | 30 | `FF 02` cursor + `FF 44` rectangles for detail view layout. |

## String Data

| File offset | Source | Content |
| ---: | --- | --- |
| `0xF2B9A` | `F2B9:000A` | `SCHEDULE.ODB` database filename. |
| `0xF298C` | `F298:000C` | `*** PLEASE WAIT ***` loading message. |
| `0xF29AF` | `F29A:0018` | `WEEKLY` scheduler title. |
| `0xF29BC` | `F29A:0025` | `[TAB]   CONTENT` key legend. |
| `0xF29CF` | `F29A:0038` | `[D]     DATE` key legend. |
| `0xF29DF` | `F29A:0048` | `[BEGIN] BEGIN` key legend. |
| `0xF29EF` | `F29A:0058` | `[END]   END` key legend. |
| `0xF2A17` | `F29A:0080` | `CONTENT` header for content view. |
| `0xF2B38` | `F2B3:0008` | `Date` input label. |
| `0xF2B59` | `F2B5:0004` | `DATE` date entry title. |
| `0xF2BBA` | `F2BB:000A` | `[SCHEDULE]` alarm display title. |
| `0xF24C9` | `F24C:0009` | Error messages (shared with calculator). |

## State Variables

| Address | Purpose |
| --- | --- |
| `[A002]` | SCHEDULE.ODB file handle |
| `[A004]` | Free space (low word) |
| `[A006]` | Free space (high word) |
| `[A008]` | Schedule entry count |
| `[A00A]` | Schedule data buffer pointer (800 bytes) |
| `[A00C]` | Secondary buffer pointer (1600 bytes, 4-byte day number pairs) |
| `[A022..A342]` | File handle table (200 × 4 bytes), cleared by DEF0:88E2 |
| `[1108]` | Time format: 0 = 12-hour, non-zero = 24-hour |
| `[18E3]` | Current year (from RTC) |
| `[18E5]` | Current month |
| `[18EB]` | Current day |
| `[1005]` | Current storage endpoint (drive letter + 0x40) |
| `[133A]` | File protection flag |

## File Service Calls

| Function | INT 21h | Purpose |
| --- | --- | --- |
| `DEF0:E1F0` | AH=36h | Drive check / free space |
| `DEF0:E254` | AX=4301h | Set file attributes |
| `DEF0:DB47` | AH=3Dh | Open file |
| `DEF0:E048` | AH=3Eh | Close file |
| `DEF0:E05A` | AH=41h | Delete file |
| `DEF0:E08C` | AH=42h | Seek |
| `DEF0:DC5E` | via E08C | Write with seek |
| `DEF0:E022` | via DFD5 | File read |
| `DEF0:DE34` | via E0A4,E08C | Record write |
| `DEF0:DD27` | via E08C | File truncate |
| `DEF0:AC52` | via DE34 | Record search |
| `DEF0:AD5F` | via DB47 | Record create/init |
| `DEF0:AE37` | — | Record compare |

## Related Functions

| Address | Purpose |
| --- | --- |
| `DEF0:C3B9` | Compute day number from year/month/day. |
| `DEF0:C455` | Convert day number to year/month/day components. |
| `DEF0:63D6` | Init display state (load all entries into buffer). |
| `DEF0:64BD` | Flush schedule data (write modified entries to file). |
| `DEF0:65C8` | Schedule frame and legend display (C000:3F35 × 2). |
| `DEF0:65F9` | Find entry by day number in secondary buffer. |
| `DEF0:6786` | Display entry content (clear + build content view). |
| `DEF0:699E` | Entry navigation/update (set highlight, load entry). |
| `DEF0:6D96` | Entry data read (seek + read via DEF0:E08C/E022). |
| `DEF0:7F07` | Entry detail display (month/day/time fields). |
| `DEF0:8041` | Date validation (month/day/year range check). |
| `DEF0:88E2` | Handle table init (clear 200 entries at A022). |
