# DEF0 Keyboard/Input Subsystem

The keyboard and input processing subsystem at `DEF0:6278..6FFF`
(80 blocks). Initialized by `DEF0:6278` (called from `DEF0:5C07`
cold init). Processing routines called from the storage subsystem
(`DEF0:8xxx`) during interactive file operations.

## DEF0:6278 — Keyboard Init

Clears the keyboard state word at `[A7A8]`. Called from `DEF0:5C07`
(cold init). Single instruction.

```asm
DEF0:6278  C706A8A70000   mov word [A7A8],0
DEF0:627E  C3             ret
```

## DEF0:627F — Input Display Handler

Called from `DEF0:5C7C` (warm reinit, result=0x32). Initializes the
display via `DEF0:0D80`, renders display scripts via `C000:3F35`,
then enters an input processing loop. Large routine
(DEF0:627F..63D6, 343 bytes).

## DEF0:63D6..6474 — Input Field Renderer

Called from `DEF0:8A30`. Renders an input field display using
display scripts. Handles cursor positioning and character display.

## DEF0:64BD..659B — Input Validation

Called from `DEF0:8A57`. Validates input data, calls `DEF0:DE34`
(file service for data verification). Branches through validation
checks.

## DEF0:65C8 — Input Buffer Handler

Called 6 times within the keyboard subsystem. Manages the input
buffer for character entry and editing.

## DEF0:65F9..6624 — Character Processor

Called from `DEF0:821B`. Processes individual character input events.

## DEF0:662F..66A0+ — Multi-Character Input

Called from `DEF0:8557`. Handles multi-character input sequences.
Calls `DEF0:0D80` (display init) and `DEF0:65C8` (input buffer).

## DEF0:6786..67F7+ — Input Mode Switch

Called from `DEF0:821B`. Handles display mode switching during
input. Calls `DEF0:0D80` (display init).

## DEF0:699E..6A02+ — Input Completion Handler

Called from `DEF0:85D7`. Processes completed input. Calls
`DEF0:C455` (application state update).

## DEF0:6D96..6DDF+ — Input Data Transfer

Called from `DEF0:8271`. Transfers input data via file services
(`DEF0:E08C`, `DEF0:E022`).

## DEF0:6DE2..6F40+ — Input Parsing

Called from `DEF0:82AF`. Parses structured input data with
multiple branch paths.

## Entry Points

| Address | Caller | Purpose |
| --- | --- | --- |
| `DEF0:6278` | `DEF0:5C07` | Init: clear keyboard state |
| `DEF0:627F` | `DEF0:5C7C` | Input display handler (warm reinit) |
| `DEF0:63D6` | `DEF0:8A30` | Input field renderer |
| `DEF0:64BD` | `DEF0:8A57` | Input validation |
| `DEF0:65F9` | `DEF0:821B` | Character processor |
| `DEF0:662F` | `DEF0:8557` | Multi-character input |
| `DEF0:6786` | `DEF0:821B` | Input mode switch |
| `DEF0:699E` | `DEF0:85D7` | Input completion |
| `DEF0:6D96` | `DEF0:8271` | Data transfer |
| `DEF0:6DE2` | `DEF0:82AF` | Data parsing |

## State Variables

| Address | Purpose |
| --- | --- |
| `[A7A8]` | Keyboard state word (cleared at init) |
