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
| `0x516BA` | `0xD16BA` | `H:ADDRESS.ODB` path opened by `C688:AD5C`; address-book handler anchor. |
| `0x53892` | `0xD3892` | `INITIALIZING`. |
| `0x538AA` | `0xD38AA` | Word processor / linguistic technology startup banner. |
| `0x538E9` | `0xD38E9` | NER / Proximity startup copyright banner. |
| `0x53935` | `0xD3935` | mikrolab / Merriam-Webster startup copyright banner. |
| `0x5397C` | `0xD397C` | Startup copyright rights-reserved line. |
| `0x539B3` | `0xD39B3` | `0x7C`-byte first-menu script block copied by `C688:77B4`. |
| `0x539E8` | `0xD39E8` | Organizer menu string. |
| `0x53A1C` | `0xD3A1C` | Word processor menu string. |
| `0x53A2F` | `0xD3A2F` | 36x34 visible 1bpp rounded button bitmap used by the first menu screen; stored as 5 bytes per row. |
| `0x55B6C` | `0xD5B6C` | Start of clear/print/store/spell-check UI string cluster. |
| `0x56B91` | `0xD6B91` | Spell check run screen. |
| `0x57546` | `0xD7546` | Grammar check UI cluster. |
| `0x57CEC` | `0xD7CEC` | DreamLink UI cluster. |
| `0x6F7A0` | `0xEF7A0` | `EROMCARD.X`. |
| `0x6F7EF` | `0xEF7EF` | ROM card strings. |
| `0x6FA78` | `0xEFA78` | Word processor horizontal icon menu table; labels begin at `0x6FA98`: `EDIT TEXT`, `FILE`, `CLEAR TEXT`, `PRINTER`, `COMMUNICATE`, `OTHERS`. |
| `0x6FAE8` | `0xEFAE8` | Word processor `FILE` submenu table/labels: `RECALL`, `STORE`, `DELETE`, `RENAME`, `COPY`, `INITIALIZE`. |
| `0x6FB58` | `0xEFB58` | Word processor `PRINTER` submenu table/labels: `PRINT OUT`, `SET UP 1`, `SET UP 2`. |
| `0x6FBC8` | `0xEFBC8` | Word processor `COMMUNICATE` submenu table/labels: `SEND FILE`, `SEND FILE`, `RECEIVE FILE`, `RECEIVE FILE`, `TERMINAL`, `SET UP`. |
| `0x708BC` | `0xF08BC` | Organizer horizontal icon menu table; labels begin at `0x708D8`: `CALCULATOR`, `CALENDAR`, `SCHEDULER`, `WORLD CLOCK`, `ADDRESS BOOK`. |
| `0x788D3` | `0xF88D3` | Typing tutor version banner. |

## Fonts / Bitmaps

| File offset | Physical | Notes |
| ---: | ---: | --- |
| `0x44D30` | `0xC4D30` | First confirmed 48x40 LCD error icon: main battery low. See `bitmaps.md`. |
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
