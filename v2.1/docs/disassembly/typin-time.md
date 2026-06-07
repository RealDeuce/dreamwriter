# Typin' Time

This slice expands the `OTHERS` -> `T I M E` application reached through
`EBBB:0000` / file `0x6BBB0`. The entry wrapper and top-level dispatcher are
introduced in [`wp-others-handlers.md`](wp-others-handlers.md); this file
bottoms the reachable Typin' Time app states, text resources, lesson tables,
and local helpers.

No bitmap assets are reached in this pass. The app's private resources are
normal display-control/text streams under `F87B` plus far-pointer lesson tables
under `F50E`. The extracted lesson strings are listed separately in
[`typin-time-lessons.md`](typin-time-lessons.md).

## Dispatcher

`EBBB:00CC` initializes app state, then calls `EBBB:012E`. The dispatcher keeps
two control words:

| Address | Role |
| ---: | --- |
| `8E52` | Auto-sequence index. |
| `8E54` | Current state code. |
| `8E90` | Last key/event returned by `DC98:F198`. |

When `[8E54]` is zero, `EBBB:012E` advances `[8E52]` modulo 16 and reads the
next word from `F87B:(0004 + [8E52] * 2)` through `EBBB:0116`. Zero entries
are skipped, so this table drives the default flow:

```text
F87B:0004 words = 0, 0, 3, 12, 11, 5, 4, 5, 9, 1, 5, 13, 14, 15, 5, 0
```

The live state table is:

| State | Target | Meaning |
| ---: | --- | --- |
| `1` | `EBBB:0BF4` | Test-menu navigation. |
| `2` | `EBBB:1250` | Live supplied-text test. |
| `3` | `EBBB:0550` | Scoreboard wrapper; draws scoreboard and clears state. |
| `4` | `EBBB:0568` | Scoreboard renderer. |
| `5` | `EBBB:182C` | Error-review header/status setup. |
| `6` | inline | Reset `[8E52]` and `[8E54]` to zero. |
| `7` | `EBBB:0274` | Intro/about screen and title animation. |
| `8` | `EBBB:047C` | Corpus choice screen. |
| `9` | `EBBB:1190` | Start-test handler. |
| `10` | `EBBB:0A56` | Menu-of-tests shell/reset handoff. |
| `11` | inline | No-op loop state. |
| `12` | `EBBB:0EC6` | Live-test footer/status prompt. |
| `13` | `EBBB:08B8` | Scoreboard command handler. |
| `14` | `EBBB:1862` | Options screen shell. |
| `15` | `EBBB:188C` | Options value renderer. |
| `16` | `EBBB:19C0` | Options navigation/value handler. |
| `17` | `EBBB:0A82` | Menu-of-tests grid renderer. |
| `18` | `EBBB:0EF6` | Selected-test text pager. |
| `19` | `EBBB:1B80` | Error-review renderer. |
| `20` | `EBBB:1DB8` | Error-review pager. |
| `21` | `EBBB:157A` | Live free-entry `YOURS` test. |

`EBBB:012E` returns `[8E90]` when the state word reaches zero. The OTHERS
submenu wrapper treats a low-byte `0x0B` as the return-to-parent-menu event.

## App State

The low-RAM state block used by Typin' Time is private to this app:

| Address | Role |
| ---: | --- |
| `8E50` | Corpus bank: `0` Typin' Write, `1` Practice Guide. |
| `8E5A` | Active text mode: supplied text vs. user-entered `YOURS`. |
| `8E5C` | Pending text mode while editing options. |
| `8E60`, `8E62`, `8E64` | Test-grid column/page/visible-row state. |
| `8E66`, `8E68` | Selected test grid column and row. |
| `8E6A` | Raw startup selection code used to derive the initial grid position. |
| `8E6C` | Selected test id, 1-based. |
| `8E6E` | Selected options row. |
| `8E70` | Beep flag toggled by `[CTRL][B]`. |
| `8E72` | Active time limit in seconds. |
| `8E74` | Pending options time limit; `0x270F` means indefinite. |
| `8E76:8E78` | Live-test start time, in seconds since midnight. |
| `8E7A:8E7C` | Current time snapshot. |
| `8E80` | Pending elapsed-time delta. |
| `8E82`, `8E84` | Elapsed minutes and accumulated elapsed seconds. |
| `8E8A` | Typed-character/scoring denominator. |
| `8E8C:8E8E` | Scoreboard math scratch. |
| `8E92` | Typed-text buffer, 0x51 bytes per line. |
| `9351` | Current line number, 1-based during live tests. |
| `9355` | Maximum selected-test line index. |
| `9357` | Current character offset. |
| `9359` | Current line length/last character index. |
| `935B` | Error count. |
| `935D` | Error-review starting line. |

`EBBB:1F74` snapshots time by calling the shared RTC update path and returning
`((hours * 60) + minutes) * 60 + seconds` in `DX:AX`.

## Startup Flow

State 7 displays the about screen from `F87B:003C`, waits for any key, clears
the display state through `DC98:F0CC`, and animates the `TYPIN'TIME ` title
string at `F87B:0030`.

State 8 then draws the corpus choice resource at `F87B:0198`:

| Key | Effect |
| ---: | --- |
| `1` | `[8E50]=0`, initial code `[8E6A]=0x1F`; Typin' Write tests. |
| `2` | `[8E50]=1`, initial code `[8E6A]=0x20`; Practice Guide tests. |
| `0x03` or `[CAN]` | Set state `10`; locally this redraws the menu-of-tests shell and resets selection state before dispatcher handoff. |

For `1` or `2`, the handler derives the initial menu grid position from
`[8E6A]` and calls `EBBB:1FF8` to reset selection and score state.

## Test Menu

State 10 draws the menu-of-tests shell at `F87B:036A`, sets the next state to
`0x10`, and calls `EBBB:1FF8` to reset selection/scoring state. State 17
renders the four-by-four menu-of-tests grid. It displays the grid body at
`F87B:03F8`, then walks the selected corpus bank's pointer grid at
`F50E:275C + 0x7BC * [8E50]`.

Each test cell is `0x3C` bytes, or 15 little-endian far pointers:

| Cell pointer | Use |
| ---: | --- |
| `+0x00` | Menu label/title rendered in the grid. |
| `+0x04..+0x3B` | Practice-line pointers followed by a pointer to a NUL string terminator; unused slots are zero far pointers. |

The selected test id is computed as:

```text
8E6C = selected_row * 4 + selected_column + 1
```

State 1 handles navigation. Arrow-like events `0x10..0x13` move within the
visible grid, `0xDD`/`0xDE` page through previous/next groups, and `0xDA`
accepts the current test by calling `EBBB:2026`.

`EBBB:2026` scans the selected test cell to count non-empty line pointers,
sets `[9355]`, initializes the current line/character fields, and clears the
score/session counters through `EBBB:213C`.

## Scoreboard

State 4 draws the scoreboard resource pair:

| Resource | Length | Final fields |
| --- | ---: | --- |
| `F87B:020E` | `0x88` | `ScoreBoard`, `WPM`, `Errors`, `Time elapsed`. |
| `F87B:0296` | `0x88` | `RET` start/restart/continue, `E` errors, `T` tests, `O` options, `X` exit. |

The scoreboard accumulates elapsed time from `[8E80]` into `[8E84]`, derives
minutes at `[8E82]`, and formats numeric fields through `EBBB:008A`. When the
needed timing or count values are unavailable, it displays the `N/A` resource
at `F87B:0352`. The short `Yes`/`No` resources at `F87B:0356` and `F87B:0358`
are used for completion/status fields.

State 13 dispatches scoreboard commands:

| Key | Effect |
| ---: | --- |
| `0xDA` | Start the selected test; if no test is selected, show `F87B:0592`. |
| `E` / `e` | Enter error review when available. |
| `O` / `o` | Enter options with `[8E6E]=1`. |
| `T` / `t` | Return to the test-selection menu. |
| `X` / `x`, `0x03` | Enter the menu/reset handoff used for app-level exit/cancel cases. |

## Live Tests

State 9 starts a test. It captures the current timestamp in `[8E76:8E78]`,
then enters state 2 for supplied text or state 21 for the `YOURS` mode selected
from options. Key `0xE0` toggles the beep flag and redraws the status prompt.

State 2 compares each typed byte against the selected supplied-text line from
the `F50E` table. Printable mismatches increment `[935B]` and, when beep is
enabled, call `DC98:F1C8` for a short tone. Matching and mismatching printable
bytes are copied into the typed-text buffer at `8E92 + line * 0x51 + column`.
Line completion advances `[9351]`, recomputes `[9359]`, and redraws the next
line/page. Time expiry or the stop/return keys finalize elapsed time through
`EBBB:219C` and return to the scoreboard.

State 21 is the free-entry variant. It records printable bytes into `8E92`
without comparing against ROM text. Backspace deletes the previous character,
redraws a blank, and decrements the typed-count state. Return finalizes the
current buffer through the same `EBBB:219C` path.

The local character classifiers are:

| Helper | Classification |
| --- | --- |
| `EBBB:21F4` | ASCII letter or digit. |
| `EBBB:2264` | Scoring classifier for punctuation/operator ranges plus the uppercase-side `0x3E..0x5A` range; lowercase letters are excluded. |

## Options

State 14 draws the options shell at `F87B:049A`; state 15 renders the current
values:

| Field | Backing state | Values |
| --- | --- | --- |
| `Text` | `[8E5C]` pending, `[8E5A]` active | `SUPPLIED` or `YOURS`. |
| `Clock` | `[8E74]` pending, `[8E72]` active | `1`, `2`, `3`, or `5` minutes, or `INDEFINITE`. |

State 16 handles option editing. Events `0x10`/`0x11` switch between the two
option rows. Events `0x12`/`0x13` toggle `Text` or cycle the clock value
through 60, 120, 180, 300, and `0x270F`. Return commits changed values back to
`[8E5A]` and `[8E72]`; switching to `YOURS` also resets the selected-test
state so the free-entry buffers are rebuilt.

## Error Review

State 5 draws the error-review header and footer, clears `[935D]`, and enters
state 19. State 19 displays two source lines starting at `[935D]`, then walks
the typed-text buffer and the expected source strings together. Mismatched
characters are redrawn with highlight style `0x0108`.

State 20 handles review navigation. Return exits to the scoreboard,
`0xDD`/`0xDE` page backward/forward by two source lines, and `0xE0` toggles
the beep prompt.

## Resource Formats

The `F87B` resources are display streams consumed by `C000:6852` or
`DC98:F07C`. The bytes use the same `FF 40` positioned-text and `FF 44`
rectangle/fill records documented in
[`display-resource-format.md`](display-resource-format.md).

Important Typin' Time strings and final fields:

| Resource | Descriptor | Final text/role |
| --- | --- | --- |
| `F87B:0030` | `char[0x0B]` | `TYPIN'TIME ` title string. |
| `F87B:003C` | display stream, `0xB3` bytes | Intro/about text, support phone number, and any-key prompt. |
| `F87B:0123` | positioned text | `Version 1.0 for DreamWriter` and copyright line. |
| `F87B:0198` | display stream, `0x75` bytes | Corpus choice screen for Typin' Write, Practice Guide, or cancel. |
| `F87B:020E` | display stream, `0x88` bytes | Scoreboard labels. |
| `F87B:0296` | display stream, `0x88` bytes | Scoreboard command legend. |
| `F87B:0352` | NUL string | `N/A`. |
| `F87B:0356` | NUL string | `Yes`. |
| `F87B:0358` | NUL string | ` No`. |
| `F87B:036A` | display stream, `0x8C` bytes | Menu-of-tests shell, title, paging legend, and return legend. |
| `F87B:03F8` | display stream, `0x0F` bytes | Small menu-grid clear/frame record used before drawing test labels. |
| `F87B:0408` | display stream | `[Prev P] [Next P]`, return-to-scoreboard legend. |
| `F87B:049A` | display stream | Select-options shell and navigation legend. |
| `F87B:053C` | NUL strings | `Text`, `Clock`, `SUPPLIED`, `YOURS`, `minute`, `INDEFINITE`. |
| `F87B:0582` | NUL string | `[CTRL][B] Beep`. |
| `F87B:0592` | display stream | `Please select your test first!` plus any-key prompt. |

The lesson/test text region starts at `F50E:0000` / file `0x750E0`. The pointer
grid starts at `F50E:275C` / file `0x7783C`, with two banks separated by
`0x7BC` bytes. The app does not copy or parse a flat lesson format; it follows
these far pointers directly for labels and supplied text lines. See
[`typin-time-lessons.md`](typin-time-lessons.md) for the extracted lesson order
and text.

## Local Arithmetic

The scoreboard uses two small unsigned 32-bit helpers:

| Helper | Role |
| --- | --- |
| `EBBB:2360` | Unsigned 32-bit by 32-bit multiply, keeping the low 32-bit result in `DX:AX`. |
| `EBBB:2392` | Unsigned 32-bit by 32-bit divide used by the same score-scaling path. |

These helpers are local integer score-formatting support. They do not expose a
floating-point package.

## Bottom

The `T I M E` root bottoms inside this slice:

| Root | Bottomed at |
| --- | --- |
| App entry | `EBBB:0000` saves/restores caller segment state and calls `EBBB:00CC`. |
| Dispatcher | `EBBB:012E` walks the `F87B:0004` state sequence and state table. |
| Test selection | `EBBB:0A82`, `0BF4`, `2026`, and the `F50E:275C` pointer grids. |
| Live tests | `EBBB:1190`, `1250`, `157A`, `219C`, and score/session helpers. |
| Scoreboard/options/error review | `EBBB:0568`, `08B8`, `1862`, `188C`, `19C0`, `1B80`, `1DB8`. |
| Resources | `F87B:0030..0592` display streams and strings; no bitmap resources. |

No remaining Typin' Time-only roots are queued.
