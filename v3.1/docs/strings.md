# String Landmarks

Use:

```sh
tools/romtool.py strings <offset> <length>
tools/romtool.py find <text>
```

## Firmware And Diagnostics

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xC146A` | `C000:146A` | Internal software error/reset message. |
| `0xC14C9` | `C000:14C9` | ` INT! ` interrupt marker. |
| `0xC1813` | `C000:1813` | `TRAP WAS SET AT` / `TRAP WAS REMOVED` status text. |
| `0xC272D` | `C000:272D` | `0123456789ABCDEF` hex digit table. |
| `0xC2793` | `C000:2793` | `:*.*` wildcard pattern. |
| `0xC2908` | `C000:2908` | `Error  accessing Device. Press any key to cancel.` |
| `0xC7701` | `C000:7701` | `Terminal mode   press ` terminal mode banner. |
| `0xC7789` | `C000:7789` | `Diagnostic 31BAB218` diagnostic banner with build date `98Jun21`. |
| `0xC77C8` | `C000:77C8` | Diagnostic command help: `M` memory dump, `S` set memory, `Y`/`Z` single step, `I`/`O` I/O, `L` alarm I/O, `T` card ATTR, `N` COM, `Q`/`R` clear/reset spell. |
| `0xC7799` | `C000:7799` | `218` warm-RAM signature (4 bytes). |

## Keyboard Translation Tables

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xC3037` | `C000:3037` | Keyboard scan-to-internal tables (6 variants × 80 bytes). Row layout follows the physical keyboard matrix. |
| `0xC389F` | `C000:389F` | Lowercase unshifted key codes: `32qwe...`. |
| `0xC38EF` | `C000:38EF` | Shifted key codes: `#@QWE...`. |
| `0xC398F` | `C000:398F` | Caps Lock key codes. |
| `0xC39DF` | `C000:39DF` | Caps Lock + Shift key codes. |
| `0xC3AB7` | `C000:3AB7` | Key repeat pairing table. |
| `0xC3F2A` | `C000:3F2A` | `teacher123` — default password. |

## Startup And Copyright

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD64DC` | `C772:EDBC` | `INITIALIZING` display script (24 bytes). |
| `0xD64F4` | `C772:EDD4` | `WORD PROCESSOR (C) 1992 NER Inc. Ver.3.00 and (C) 1992 mikrolab Ver.5.00. All Rights Reserved` (99 bytes). |
| `0xD655E` | `C772:EE3E` | `International CorrectSpell English spelling correction system ` (68 bytes). |
| `0xD65A2` | `C772:EE82` | `Copyright 1995 by Inso Corporation. All Rights Reserved. ` (63 bytes). |
| `0xD65E1` | `C772:EEC1` | `International CorrectSpell is a trademark of Inso Corporation.` (68 bytes). |
| `0xD6625` | `C772:EF05` | `US English Concise International Electronic Thesaurus` (59 bytes). |
| `0xD6660` | `C772:EF40` | `Reproduction or disassembly of embodied programs, algorithms or databases prohibited` (90 bytes). |

## Main Menu And Application

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD66F4` | `C772:EFD4` | `ORGANIZER MENU` menu title. |
| `0xD6728` | `C772:F008` | `WORD PROCESSOR MENU` menu title. |
| `0xD6816` | `C772:F0F6` | `The batteries are too low to operate` low-battery message. |
| `0xD683B` | `C772:F11B` | `Dreamlink` DreamLink label. |
| `0xD684D` | `C772:F12D` | Printer control sequence table: `UIZSFHTPS101215tbCSDYLRPEffNrPStwswspINKAKER0R1GOmy`. |
| `0xD68AE` | `C772:F18E` | `CLEAR TEXT` followed by ` in work memory` and `Are you sure? (Y/N):` confirm prompt. |

## Print UI

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD6920` | `C772:F200` | `PRINT TEXT` dialog header. |
| `0xD6986` | `C772:F266` | `FROM PAGE` / `TO PAGE` / `PAGE NUMBERING? (Y/N)` / `MERGE? (Y/N)` print options. |
| `0xD6A33` | `C772:F313` | `PRINT START ?` confirmation. |
| `0xD6A6A` | `C772:F34A` | `Convert to ASCII ?` text export prompt. |
| `0xD6D27` | `C772:F607` | `PRINT TEXT` active printing display with pause/cancel instructions. |

## File Management UI

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD6A85` | `C772:F365` | `NAME LIST` merge address list selector. |
| `0xD6AE8` | `C772:F3C8` | `ADDRESS.ODB is not found` error. |
| `0xD6B32` | `C772:F412` | `MERGE.FIL is not found` error. |
| `0xD6B6A` | `C772:F44A` | `INITIALIZE` display with WARNING erase prompt. |
| `0xD6C38` | `C772:F518` | `SEARCH` / `REPLACE SEARCH` dialog cluster. |
| `0xD73FC` | `C772:FCDC` | `RECALL FILE` dialog with directory selector. |
| `0xD7447` | `C772:FD27` | `BASIC` — BASIC file type label. |
| `0xD744F` | `C772:FD2F` | `DIRECTORY` — directory listing header. |
| `0xD7577` | `C772:FE57` | `DELETE FILE` confirmation dialog. |
| `0xD7639` | `C772:FF19` | `RENAME FILE` dialog with old/new name fields. |
| `0xD7736` | — | `STORE TEXT` file save dialog. Past C772 segment limit (file 0xD771F). |
| `0xD2744` | `C772:B024` | `:MERGE.FIL` filename constant. |
| `0xD28FE` | `C772:B1DE` | `H:ADDRESS.ODB` address-book path. |

## Spell Check UI

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD77F9` | — | `SPELL CHECK RUN` with `Press any key to cancel.` and `Pauses automatically on checked words.` |
| `0xD7851` | — | `SPELL CHECK` main spell check dialog: suggest/add/bypass/retype/dictionary options. |
| `0xD793D` | — | `View & Remove user dict.` user dictionary management. |
| `0xD79FB` | — | `*** NO SUGGESTION ***` no spelling suggestions message. |
| `0xD7A33` | — | `SUGGEST` replacement word selector. |
| `0xD7F9F` | — | `Word added to the dictionary` / `Word already in the dictionary` / `User Dictionary is full` / `Invalid word` status messages. |
| `0xD8A17` | — | `Spell Checking is Disabled` status message. |

## Thesaurus UI

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD59E3` | `C772:E2C3` | `Meanings` thesaurus heading. |
| `0xD59F0` | `C772:E2D0` | `Synonyms for ` thesaurus heading. |
| `0xD803F` | — | `T H E S A U R U S for:` spaced title. |
| `0xD80C9` | — | `*** NO SYNONYM IN DICTIONARY ***` no results message. |

## Grammar Check UI

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD8109` | — | `GRAMMAR CHECK :` followed by error types: Beginning, Punctuation, Capitalization, Spacing, Double word, Quotation errors. Each with bypass/exit options. |
| `0xD8462` | — | `SPELL & GRAMMAR CHECK RUN` combined check title with `Pauses automatically on checked words.` |

## Communication UI

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD84C4` | — | `RECEIVE FILE through RS-232C` / `RECEIVE FILE through RS-232C (XMODEM)` receive dialogs. |
| `0xD85ED` | — | `SEND FILE through RS-232C` / `SEND FILE through RS-232C (XMODEM)` send dialogs. |
| `0xD86FF` | — | `DreamLink -` connection label. |
| `0xD87AC` | — | DreamLink error messages: connection error, not connected, host error. |

## Storage Error Messages

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD7002` | `C772:F8E2` | `No card is in the slot` PCMCIA error. |
| `0xD70B0` | `C772:F990` | `No disk is in the FDD` floppy disk error. |
| `0xD715C` | `C772:FA3C` | `Disk is not formatted or not compatible` format error. |
| `0xD71D4` | `C772:FAB4` | `Inadequate store memory space` storage full. |
| `0xD7220` | `C772:FB00` | `Card or FD is write-protected` write protect error. |
| `0xD726C` | `C772:FB4C` | `Remaining work memory is inadequate` RAM full. |
| `0xD7309` | `C772:FBE9` | `Store memory read error` I/O error. |
| `0xD7371` | `C772:FC51` | `Directory is full of files` directory limit. |
| `0xD73BA` | `C772:FC9A` | `File is not text` format mismatch. |

## Format Settings

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD7CCC` | — | `FORMAT SETTING` dialog: Left/Right Margin, Paper Width/Length, Tab Space, Top/Bottom Margin with `(1"=6 Lines)` hint. |

## Work Memory Messages

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD7A84` | — | `Work memory is full` with COPY/MOVE clear prompt. |
| `0xD7BE5` | — | `Inadequate COPY/MOVE memory` error. |
| `0xD7C22` | — | `COPY/MOVE memory will be automatically cleared when COPY/MOVE is executed.` |

## Editor Status Labels

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD5E3F` | `C772:E71F` | Status line mode labels: `OFF`, `CHA`, `LIN`, `CAPS`, `SHIFT`, `CAPS `. |
| `0xD5E9E` | `C772:E77E` | Status line indicators: `CODE`, `PRNT`, `FULL`, `HYPH`, `FRM `, `INS `, `ins `, `ZOOM`, `MARK`, `REPL`. |
| `0xD5ED4` | `C772:E7B4` | `REPLLE` replace mode label (truncated display). |
| `0xD5EF2` | `C772:E7D2` | `WAIT` processing indicator. |
| `0xD5EFA` | `C772:E7DA` | Merge field tags: `NAME(`, `SALUTATION(`, `TEL(`, `FAX(`, `ADRS(`. |

## Printer Control Sequences

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD36F9` | `C772:BFD9` | PCL/ESC sequences: `&d0D`, `(s3B`, `(s0B`, `&a-30V`, `&a+30V`, etc. HP PCL printer control. |
| `0xD39B6` | `C772:C296` | Font selection sequences: `(s1p10h12V`, `(s0p10h12V`, etc. PCL font size/pitch. |
| `0xD3C6A` | `C772:C54A` | Character translation table (166 bytes): maps internal codes to printer character set. |

## EE17 Menu Strings

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xF131C` | `EE17:31AC` | `EROMCARD.X` ROM card executable filename used by the launcher at `DEF0:2C37`. |
| `0xF1344` | `EE17:31D4` | Others submenu: `COMMUNICATE`, `SYSTEM`, `PREFERENCES`, `ROM CARD`. |
| `0xF13B4` | `EE17:3244` | `T I M E` spaced time menu label. |
| `0xF140F` | `EE17:329F` | `SYSTEM SET UP` / `AUTO POWER OFF PERIOD` with `{ 2 } { 3 } { 5 } { 10 } { 15 } { 20 } { UNLIMITED }` and `(minutes)`. |
| `0xF1476` | `EE17:3306` | `POWER ON BUZZER` with `{ TYPE 1 } { TYPE 2 } { TYPE 3 } { NO }`. |
| `0xF14E1` | `EE17:3371` | `EDITOR PREFERENCES` / `STICKY SHIFT KEY` / `BIG FONT MODE` / `SPELL CHECKING` / `PASSWORDS` / `SAVE ONLY TEXT ON FDD`. |
| `0xF15B8` | `EE17:3448` | ROM card launcher/error messages: `No ROM card is in the slot`, `Inadequate work memory`, `Can not open EROMCARD.X`, `Not enough memory`, `ROM Card ID error`; the visible failure prompts except ID-error are referenced by `DEF0:2C37`, while the local v3.1 launcher body does not directly reference the ID-error string. |
| `0xF16B0` | `EE17:3540` | Filename invalid characters: `"\ *+,/:<=>?[]|`. |
| `0xF16C1` | `EE17:3551` | `Password Registry` password UI. |
| `0xF1716` | `EE17:35A6` | `teacher123` — default password (same as C000:3F2A). |
| `0xF1772` | `EE17:3602` | WP horizontal menu: `EDIT TEXT`, `FILE`, `CLEAR TEXT`, `PRINTER`, `T I M E`, `OTHERS`. |
| `0xF17E2` | `EE17:3672` | File submenu: `RECALL`, `STORE`, `DELETE`, `RENAME`, `COPY`, `INITIALIZE`. |
| `0xF1852` | `EE17:36E2` | Printer submenu: `PRINT OUT`, `SET UP 1`, `SET UP 2`. |
| `0xF18C2` | `EE17:3752` | Communicate submenu: `SEND FILE` ×2, `RECEIVE FILE` ×2, `TERMINAL`, `SET UP`. |

## Organizer Menu Strings

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xF245A` | `EE17:3CEB` | Organizer menu: `CALCULATOR`, `CALENDAR`, `SCHEDULER`, `WORLD CLOCK`, `ADDRESS BOOK`. |
| `0xF2B9A` | `EE17:442A` | `SCHEDULE.ODB` scheduler database filename. |
| `0xF37D0` | `EE17:5060` | `ADDRESS.ODB` address book database filename. |

## Calculator Strings

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xF24C9` | `F24C:0009` | Calculator error messages: `OVERFLOW`, `DIVISION BY ZERO`, `OUT OF RANGE`, `UNKNOWN ERROR` (4 × 24 bytes). |

## Calendar Strings

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xF2E38` | `F2E3:0008` | Month abbreviations: `JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC` (12 × 3 bytes). |
| `0xF2E5C` | `F2E5:000C` | Day-of-week abbreviations: `Sun Mon Tue Wed Thu Fri Sat` (7 × 3 bytes). |
| `0xF2634` | `F263:0004` | Calendar title and key legend: `CALENDAR`, `[↑] PREV MONTH`, `[↓] NEXT MONTH`, `[Y] YEAR`, `[F] DISPLAY FORM`. |
| `0xF26B4` | `F26B:0004` | Year sub-screen: `YEAR`, `[↵] SET`, `[CAN] CANCEL`. |
| `0xF26E4` | `F26E:0004` | Display Form sub-screen: `DISPLAY FORM`, `[↵] SET`, `[CAN] CANCEL`. |
| `0xF2690` | `F269:0000` | `Year` input label. |

## Scheduler Strings

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xF298C` | `F298:000C` | `*** PLEASE WAIT ***` loading message. |
| `0xF29AF` | `F29A:0018` | `WEEKLY` scheduler title. |
| `0xF29BC` | `F29A:0025` | `[TAB]   CONTENT` key legend. |
| `0xF29CF` | `F29A:0038` | `[D]     DATE` key legend. |
| `0xF29DF` | `F29A:0048` | `[BEGIN] BEGIN` key legend. |
| `0xF29EF` | `F29A:0058` | `[END]   END` key legend. |
| `0xF2A17` | `F29A:0080` | `CONTENT` header for content view. |
| `0xF2B38` | `F2B3:0008` | `Date` input label (with `FF 44` field rectangle). |
| `0xF2B54` | `F2B5:0004` | Date entry: `DATE`, `[↵] SET`, `[CAN] CANCEL`. |

## World Clock Strings

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xF2C6C` | `F2C6:000C` | `WORLD CLOCK` title. |
| `0xF2C7E` | `F2C6:001E` | `[H] SET HOME CITY` key legend. |
| `0xF2C8E` | `F2C6:002E` | `[2] SET 2ND CITY` key legend. |
| `0xF2C9E` | `F2C6:003E` | `[S] SET TIME/DATE` key legend. |
| `0xF2CAE` | `F2C6:004E` | `[F] DISPLAY FORM` key legend. |
| `0xF2CBE` | `F2C6:005E` | `[A] DAILY ALARM` key legend. |
| `0xF2CF4` | `F2CE:0014` | `SET TIME/DATE` sub-screen title. |
| `0xF2D2C` | `F2D2:000C` | `SET HOME CITY` sub-screen title. |
| `0xF2D3E` | `F2D2:001E` | `[TAB] ORDER` key legend. |
| `0xF2D4E` | `F2D2:002E` | `[INS] DAYLIGHT TIME` key legend. |
| `0xF2D8C` | `F2D8:000C` | `SET 2ND CITY` sub-screen title. |
| `0xF2DEA` | `F2DE:000A` | `DISPLAY FORM` sub-screen title. |
| `0xF2E78` | `F2E7:0008` | `DAILY ALARM` sub-screen title. |
| `0xF382E` | `F382:000E` | Timezone city/country database (222 records × 56 bytes). |

## Address Book Strings

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xF3347` | `F334:0007` | `*** PLEASE WAIT ***` loading message. |
| `0xF3397` | `F339:0007` | Field labels: `FREE`, `TEL`, `FAX`, `ADRS`, `MEMO`, `SALUTATION`. |
| `0xF33E3` | `F33C:0023` | `Deletes this entry` confirmation. |
| `0xF3457` | `F345:0007` | `INDEX` view title + key legend: `[↵] EDIT`, `[INS] NEW ENTRY`, `[BACK] DELETE`, `[TAB] CONTENT`, `[SEARCH] SEARCH`, `[NEXT] NEXT`. |
| `0xF34D7` | `F34D:0007` | `CONTENT` view title + key legend (same keys, `[TAB] INDEX`). |
| `0xF3567` | `F356:0007` | `EDIT` sub-screen: `[↵] ENTER`, `[CAN] CANCEL`. |
| `0xF3597` | `F359:0007` | `NEW ENTRY` sub-screen. |
| `0xF35FD` | `F35F:000D` | `SEARCH` sub-screen: `[↵] EXECUTE`, `[CAN] CANCEL`. |
| `0xF3665` | `F366:0005` | `Are you sure? (Y/N)` delete confirmation. |

## Miscellaneous

| File offset | Segment:Offset | Notes |
| ---: | ---: | --- |
| `0xD0755` | `C772:9035` | `  LIST OF DOC.  ` document list title. |
| `0xD1925` | `C772:A205` | `vtab ` vertical tab label. |
| `0xD4A2` | `C772:5D82` | Ruler string: `0,,,,+,,,,1,,,,+,,,,2...` 80-column ruler pattern. |
| `0xD1DEF` | `C772:A6CF` | Printer model/feature codes: `UIZSFHTPS101215tbCSDYLRPEffNrPStwswspINKAKER0R1GOmy`. |
| `0xD7E47` | — | `Built-in Memory-` / `Card Memory-` storage type labels. |
| `0xD7E74` | — | `INITIALIZE BUILT-IN MEMORY` with `WARNING!   WARNING!   WARNING!` and `CTRL + WP` confirmation instructions. |
| `0xD8ADD` | — | `To Be Implemented - Press any key to exit.` placeholder for unfinished features. |
| `0xD8B0E` | — | `NJD 1` / `NJD 2` / `NJD 3` debug/test labels. |
