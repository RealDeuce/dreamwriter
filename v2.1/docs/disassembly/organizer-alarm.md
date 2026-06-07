# Organizer Alarm Selector

This slice expands the shared Organizer alarm roots reached from the RTC power
paths: `DC98:D3BB` / file `0x69D3B` and `DC98:DB5E` / file `0x6A4DE`. These
are the bridge between SCHEDULER records, WORLD CLOCK daily alarms, and the
low-level RP5C01 alarm programming documented in
[`rtc-programming.md`](rtc-programming.md).

## Next-Alarm Selection

`DC98:D3BB` snapshots the current date and time through `DC98:0D2A` and
`DC98:0D4E`, converts the date to the scheduler day-count domain, and searches
two alarm sources:

| Source | RAM range | Shape |
| --- | ---: | --- |
| Scheduler alarms | `82C8..85E7` | 200 entries, each `date_delta word` + `minutes word`; cleared entries have date `FFFF`. |
| WORLD CLOCK daily alarms | `89F2..8A4D` | Four 0x17-byte rows; the first word is the daily alarm time or `FFFF`. |

Scheduler entries are one-shot dated alarms. The selector ignores entries that
are before today's date, and for today's date it ignores entries whose time is
not later than the current minute. It keeps the earliest future candidate.

Daily WORLD CLOCK alarms are rolling alarms. If a daily alarm time has already
passed today, the candidate date is tomorrow; otherwise it is today. A daily
alarm candidate source is stored as `0x0100 + daily_alarm_index`, while a
scheduler source is stored as the scheduler record index.

If no candidate exists, `D3BB` writes a disabled marker:

```text
6D41 = FF
6D42..6D4B = 00
6D4C = 0000
```

When a candidate exists, `D3BB` converts it back to year/month/day and writes
decimal nibbles into the RTC alarm buffer:

| RAM | Meaning |
| ---: | --- |
| `6D41..6D42` | Year within century, tens/ones. |
| `6D43..6D44` | Month, tens/ones. |
| `6D45..6D46` | Day of month, tens/ones. |
| `6D48..6D49` | Hour, tens/ones. |
| `6D4A..6D4B` | Minute, tens/ones. |
| `6D4C` | Selected source id: scheduler index or `0x0100 + daily index`. |

The low-level retained power path then programs those bytes through
`C000:0376` and compares them on wake through `C000:0B90`.

## Display Helpers

`DC98:D678` / file `0x69FF8` formats the selected alarm time into a caller's
display buffer. It follows the WORLD CLOCK display-form byte `[6808]`: zero
formats `HH:MM`, and nonzero formats 12-hour time with `am`/`pm`.

`DC98:D751` / file `0x6A0D1` draws a selected SCHEDULER alarm. It emits the
`SCHEDULE ALARM` title, a cancel hint, a date/time line, then uses the selected
scheduler source id in `6D4C` to locate the record text in the scheduler record
buffer area.

`DC98:DA58` / file `0x6A3D8` draws a selected WORLD CLOCK daily alarm. It emits
the `DAILY ALARM` title, the same cancel hint, the formatted time, and then
uses `6D4C - 0x0100` to select the daily-alarm label row.

The display resources decode to:

| Resource | File offset | Descriptor | Final formatted text |
| --- | ---: | --- | --- |
| `F502:0006` | `0x75026` | Shared clear/frame display stream. | Display-control frame, no visible text. |
| `F504:000E` | `0x7504E` | `0x32`-byte schedule alarm title stream. | `SCHEDULE ALARM` / `Press CAN to exit` |
| `F508:0000` | `0x75080` | `0x2F`-byte daily alarm title stream. | `DAILY ALARM` / `Press CAN to exit` |

## Wake Loop

`DC98:DB5E` is called by the warm/RTC alarm discriminator after the low-level
compare accepts an application alarm. If `6D41 == FF`, it returns `FFFF` and
there is no application alarm to show.

Otherwise it:

1. Sets `[680D]=1` to mark the alarm-display state.
2. Starts the alarm sound path through `C000:088F`.
3. Dispatches to `D751` for scheduler sources or `DA58` for daily-alarm sources
   by testing whether `6D4C < 0x0100`.
4. Polls keyboard/status for up to `0x0258` iterations, accepting the cancel
   path and also watching for the warm marker `[6809] == 1992`.
5. Stops the sound path through `C000:0899`, clears `[680D]`, refreshes the next
   alarm by calling `D3BB`, and returns the wake-loop result in `AX`.

The return code is stored through `CX` inside the loop: `0` for a cancel-style
exit, `1` when the warm marker is observed, and `2` when the wait loop times
out.

## Boundary

This bottoms the shared Organizer alarm hook. Scheduler records enter through
the `82C8` table built by `DC98:73DB`; WORLD CLOCK daily alarms enter through
the four rows at `89F2`; the selected result is only the low-RAM RTC alarm
buffer `6D41..6D4C`.
