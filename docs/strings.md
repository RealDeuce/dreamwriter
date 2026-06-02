# String Landmarks

Use:

```sh
tools/rom2.py strings --start 0x40000 --end 0x80000 -n 8
```

## Firmware And Diagnostics

| File offset | Physical | Notes |
| ---: | ---: | --- |
| `0x411D6` | `0xC11D6` | Internal software error/reset message. |
| `0x4155E` | `0xC155E` | Trap set/removed status text. |
| `0x42288` | `0xC2288` | Hex digit table. |
| `0x45619` | `0xC5619` | Keyboard/layout-looking table. |
| `0x467E3` | `0xC67E3` | Terminal mode prompt. |
| `0x46912` | `0xC6912` | Diagnostic banner. |

## Main Application

| File offset | Physical | Notes |
| ---: | ---: | --- |
| `0x514FF` | `0xD14FF` | `:MERGE.FIL` filename copied during the WP print/merge path. |
| `0x516BA` | `0xD16BA` | `H:ADDRESS.ODB` path opened by `C688:AD5C`; address-book handler anchor. |
| `0x53892` | `0xD3892` | `INITIALIZING`; tied to the cold retained-RAM/init path and built-in store formatter when the `1800:` volume header/checksum is invalid. |
| `0x538AA` | `0xD38AA` | Word processor / linguistic technology startup banner. |
| `0x538E9` | `0xD38E9` | NER / Proximity startup copyright banner. |
| `0x53935` | `0xD3935` | mikrolab / Merriam-Webster startup copyright banner. |
| `0x5397C` | `0xD397C` | Startup copyright rights-reserved line. |
| `0x539B3` | `0xD39B3` | `0x7C`-byte first-menu script block copied by `C688:77B4`. |
| `0x539E8` | `0xD39E8` | Organizer menu string. |
| `0x53A1C` | `0xD3A1C` | Word processor menu string. |
| `0x53A2F` | `0xD3A2F` | 36x34 visible 1bpp rounded button bitmap used by the first menu screen; stored as 5 bytes per row. |
| `0x55B6C` | `0xD5B6C` | Start of clear/print/store/spell-check UI string cluster. |
| `0x56B88` | `0xD6B88` | Spell-check run display-script record. The title is stored as spaced text: `S P E L L   C H E C K   R U N`. |
| `0x57400` | `0xD7400` | Thesaurus UI display-script cluster. Resource IDs `0x76..0x7F` cover the main `===  T H E S A U R U S  ===` screen, selection prompts, `*** NO SYNONYM IN DICTIONARY ***` at `0x57491`, wait text, next/previous meaning-screen prompts, and the ROM typo `CAN to meannings`. See [`spell-engine.md`](spell-engine.md#editor-thesaurus-front-end). |
| `0x57540` | `0xD7540` | Grammar-check UI cluster. Contains the grammar error prompts and bypass/cancel text. |
| `0x57920` | `0xD7920` | Combined spell-and-grammar run display-script record. The title is stored as spaced text: `S P E L L   &   G R A M M A R  C H E C K   R U N`; the preceding font/control byte is `0x16`, matching the taller on-screen title. |
| `0x57CEC` | `0xD7CEC` | DreamLink UI cluster. |
| `0x6F7A0` | `0xEF7A0` | `EROMCARD.X`; nearby `OTHERS` submenu effective table base is `0x6F7AC`, with labels beginning at `0x6F7C8`: `SYSTEM`, `PREFERENCES`, `T I M E`, `ROM CARD`. `DC98:2B75` loads this file from the candidate card drive, validates header words `0xA4F0/0x1997`, then calls the loaded far entry pointer at `[0xA4F4]`. |
| `0x6F7EF` | `0xEF7EF` | ROM software-card strings: `ROM CARD`, `No ROM card is in the slot`, `Inadequate work memory`, `Can not open EROMCARD.X`, `Not enough memory`, `ROM Card ID error`. |
| `0x6F823` | `0xEF823` | WP OTHERS -> SYSTEM setup resource begins with `AUTO POWER OFF PERIOD : { 2 } { 3 } { 5 } { 10 } { 15 } { 20 } { UNLIMITED }` and `(minutes)`. Handler `DC98:288A` stores the selected index in `[6D2F]`. |
| `0x6F88A` | `0xEF88A` | WP OTHERS -> SYSTEM settings text: `POWER ON BUZZER : { TYPE 1 } { TYPE 2 } { TYPE 3 } { NO }`. Space previews the selected buzzer type through `C000:077C`; handler stores the setting in `[6D30]`. |
| `0x6F8EE` | `0xEF8EE` | WP OTHERS -> PREFERENCES settings resource: `EDITOR PREFERENCES`, `GRAMMAR CHECKING : { ON } { OFF }`, and `STICKY SHIFT KEY : { ON } { OFF }`. Handler `DC98:2A83` stores grammar in `[6D55]` and sticky shift in `[6D24]`. |
| `0x6FA78` | `0xEFA78` | Word processor horizontal icon menu cluster; effective table base is `0x6FA7C`, labels begin at `0x6FA98`: `EDIT TEXT`, `FILE`, `CLEAR TEXT`, `PRINTER`, `COMMUNICATE`, `OTHERS`. |
| `0x6FAE8` | `0xEFAE8` | Word processor `FILE` submenu cluster; effective table base is `0x6FAEC`, labels begin at `0x6FB08`: `RECALL`, `STORE`, `DELETE`, `RENAME`, `COPY`, `INITIALIZE`. This is the PCMCIA SRAM-card storage workflow. |
| `0x6FB58` | `0xEFB58` | Word processor `PRINTER` submenu cluster; effective table base is `0x6FB5C`, labels begin at `0x6FB78`: `PRINT OUT`, `SET UP 1`, `SET UP 2`. `SET UP 1` reaches `DC98:24DB`; `SET UP 2` reaches the shared RS-232 setup screen. |
| `0x6FC3D` | `0xEFC3D` | Printer setup strings: `PRINTER SET UP`, printer model names, `INTERFACE : {PARALLEL} {SERIAL}`, and `PAPER FEED: {AUTOMATIC} {MANUAL}`. |
| `0x6FBC8` | `0xEFBC8` | Word processor `COMMUNICATE` submenu cluster; effective table base is `0x6FBCC`, labels begin at `0x6FBE8`: `SEND FILE`, `SEND FILE`, `RECEIVE FILE`, `RECEIVE FILE`, `TERMINAL`, `SET UP`. Nearby setup strings include `RS-232C SET UP`, `BAUD RATE`, `BIT LENGTH`, `STOP BITS`, `PARITY`, and `X ON/OFF`; handler `DC98:22A1` stores those settings at `6D2A..6D2E`. |
| `0x6FF03` | `0xEFF03` | WP FILE -> COPY UI cluster. Includes `Built-in`, `Card`, `DreamLink`, direction prompts, `No card is in the slot`, `Directory is full of files`, and `Card is write-protected`. |
| `0x708BC` | `0xF08BC` | Organizer horizontal icon menu table; labels begin at `0x708D8`: `CALCULATOR`, `CALENDAR`, `SCHEDULER`, `WORLD CLOCK`, `ADDRESS BOOK`. |
| `0x70948` | `0xF0948` | Calculator error/status strings: `OVERFLOW`, `DIVISION BY ZERO`, `OUT OF RANGE`, and `UNKNOWN ERROR`, stored as four fixed 24-byte fields. |
| `0x709B0` | `0xF09B0` | Four 8x8 calculator-adjacent operator/status glyphs. |
| `0x709D8` | `0xF09D8` | Calculator right-side panel display script: `FF 44` rectangles plus low-number `FF 02`/`FF 06` drawing records. |
| `0x70A6C` | `0xF0A6C` | 4x7 digit table at stride `0x07`. It follows the calculator panel resource, but the confirmed direct caller is later organizer date/calendar-style code around `DC98:6CDD`. |
| `0x7104C` | `0xF104C` | WORLD CLOCK right-side header line script: six `FF 44` rectangle records. Clears a 114x64 strip, then sets five horizontal rules. |
| `0x710DE` | `0xF10DE` | WORLD CLOCK title/menu text script: `WORLD CLOCK`, `[H] SET HOME CITY`, `[2] SET 2ND CITY`, `[S] SET TIME/DATE`, `[F] DISPLAY FORM`, `[A] DAILY ALARM`. |
| `0x71160` | `0xF1160` | WORLD CLOCK SET TIME/DATE text script: `SET TIME/DATE`, `[0xDA] SET`, and `[CAN] CANCEL`. Handler `DC98:AAD5` pairs it with the right-side header line script; `0xDA` is the same selection key/event used by the menu dispatchers. |
| `0x71295` | `0xF1295` | WORLD CLOCK DISPLAY FORM choices: `{ 24 HOUR }` and `{ 12 HOUR }`, edited by `DC98:AD1B` through flag `[6808]`. |
| `0x712AC` | `0xF12AC` | WORLD CLOCK date string tables: three-letter months `JAN..DEC` and weekdays `Sun..Sat`. |
| `0x71380` | `0xF1380` | WORLD CLOCK small marker glyph resource. The app uses offsets `0x000E` and `0x0014` for city markers and blink. |
| `0x713CA` | `0xF13CA` | WORLD CLOCK 96x64 map bitmap, blitted by `DC98:A0CC` through `FF 42`. |
| `0x716CA` | `0xF16CA` | WORLD CLOCK large time digit table. Ten 7x12 digit bitmaps at stride `0x0D`, consumed by `DC98:9AC8`. |
| `0x7174C` | `0xF174C` | WORLD CLOCK 4x12 bitmap separator/colon for the large time renderer. |
| `0x71759` | `0xF1759` | WORLD CLOCK blank 7x12 leading-hour glyph for the large time renderer. |
| `0x71CA6` | `0xF1CA6` | WORLD CLOCK city table begins. Records are `0x38` bytes; marker coordinates are at record offsets `0x1A` and `0x1B`. |
| `0x788D3` | `0xF88D3` | Typing tutor version banner. |

## Fonts / Bitmaps

| File offset | Physical | Notes |
| ---: | ---: | --- |
| `0x44D30` | `0xC4D30` | First confirmed 48x40 LCD error icon: main battery low. See [`bitmaps.md`](bitmaps.md). |
| `0x44E20` | `0xC4E20` | Second confirmed 48x40 LCD error icon: CR2032 memory-retention battery low. |
| `0x44F10` | `0xC4F10` | Third confirmed 48x40 LCD error icon: PCMCIA SRAM card battery low. |
| `0x45000` | `0xC5000` | Dispatcher byte translation table, not a fourth 48x40 bitmap. |
| `0x55110` | `0xD5110` | Candidate status/icon resource cluster before word-processor status strings. |
| `0x58000` | `0xD8000` | Candidate width/metadata table for first `0xB6` glyphs. |
| `0x580B6` | `0xD80B6` | Main 8-byte-per-glyph table used by MAME for `drwrt400`. Printable ASCII appears to start here at code `0x20`. |
| `0x5C000` | `0xDC000` | Later glyph run within MAME's 8x8 debug character layout. |

## Lower ROM Resources

| File offset | Physical | Notes |
| ---: | ---: | --- |
| `0x1C000` | `0x9C000` | Merriam-Webster copyright. |
| `0x1C029` | `0x9C029` | Proximity Technology copyright. |
| `0x25987` | `0xA5987` | Word list cluster begins around here. |
| `0x3C096` | `0xBC096` | ASCII/character tables. |
| `0x3CC5B` | `0xBCC5B` | Merriam-Webster and Proximity copyright string. |
