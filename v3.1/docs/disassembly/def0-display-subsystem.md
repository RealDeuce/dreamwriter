# DEF0 Display Subsystem

The display configuration and management subsystem at
`DEF0:A000..BFFF` (253 blocks). Initialized by `DEF0:A718`
(called from `DEF0:5C07` cold init). Handles LCD geometry
configuration, display page management, and application-level
display state.

See [`def0-display-services.md`](def0-display-services.md) for
the far-call table display service API and
[`def0-display-rendering.md`](def0-display-rendering.md) for the
low-level rendering pipeline.

## DEF0:A718 — Display Subsystem Init

Called from `DEF0:5C07` (cold init). Sets display dimensions
`[A444]=0x6D` (109 columns), `[A448]=0x8F` (143 rows), then reads
display parameter tables from segments `F68C` and `F382` to
configure the LCD controller.

This is the only substantial routine called during cold init
(the other four init calls are single-instruction stubs).

## DEF0:A7C0 — Display Mode Handler

Called from `DEF0:5CA4` (warm reinit, result=0x34). Handles
display mode selection and configuration after warm restart.

## A000-AFFF — Display Configuration (115 blocks)

| Address | Caller | Purpose |
| --- | --- | --- |
| `DEF0:A718` | `DEF0:5C07` | Display subsystem init |
| `DEF0:A7C0` | `DEF0:5CA4` | Display mode handler |
| `DEF0:A4F8` | internal | Display parameter calculator (7 callers) |
| `DEF0:AC02` | `DEF0:C24A` | Display page manager |
| `DEF0:AC52` | `DEF0:89F3` | Data read for display |
| `DEF0:AD5F` | `DEF0:8987` | Error display handler (4 callers) |
| `DEF0:AE37` | `DEF0:64ED` | Input field display |
| `DEF0:AE91` | `DEF0:C26C` | Display state update |
| `DEF0:AF94` | `DEF0:BDA0` | Display refresh |

## B000-BFFF — Display Services (138 blocks)

Extended display services, mostly called internally:

| Address | Callers | Purpose |
| --- | --- | --- |
| `DEF0:B0BF` | 5 | Display line renderer |
| `DEF0:B1C1` | 6 | Display block renderer |
| `DEF0:B5E7` | 6 | Display page updater |
| `DEF0:B8FC` | 4 | Display scroll handler |
| `DEF0:B9A2` | 5 | Display cursor handler |
| `DEF0:BD14` | `DEF0:C24A` | Display page switcher |

## Display State Variables

| Address | Purpose |
| --- | --- |
| `[A444]` | Display width (0x6D = 109 columns) |
| `[A448]` | Display height (0x8F = 143 rows) |
| `[A00E]` | Application state byte (cleared by C11C) |
| `F68C` | Display parameter table segment (ROM) |
| `F382` | LCD geometry table segment (ROM) |

## AD5F — Error Display Handler

Called from file operations (4 callers). Takes AX (filename pointer),
BX (display length), CX (error code), DX (error descriptor). Renders
an error message on screen using display services.

## Call Flow

```text
DEF0:5C07 (cold init)
  → DEF0:A718 (display subsystem init)
    → configure [A444], [A448]
    → read from F68C, F382 segments

DEF0:5CA4 (warm reinit, result=0x34)
  → DEF0:A7C0 (display mode handler)
```
