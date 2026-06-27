# Keyboard Processor

The high-level keyboard processing chain called from the IRQ FB handler
after all 10 keyboard rows have been scanned. See
[`keyboard-irq.md`](keyboard-irq.md) for the IRQ handler that populates
the matrix at `[1306..130F]` and calls this processor.

## C000:3AE3 — Keyboard Processor Entry

Called from the IRQ FB handler at `C000:0662` after a complete 10-row
scan with at least one key detected. Compares the new scan at
`[1306..130F]` against the previous scan saved at `[1310..1323]` to
detect key transitions (press/release).

```asm
; file 0xC3AE3
C000:3AE3  BB 0613           mov bx,1306     ; new scan
C000:3AE6  BE 1013           mov si,1310     ; previous scan
C000:3AE9  8A 07             mov al,[bx]     ; current row
C000:3AEB  3A 04             cmp al,[si]     ; compare with previous
C000:3AED  75 3F             jnz C000:3B2E   ; row changed -> process
C000:3AEF  46                inc si
C000:3AF0  3A 04             cmp al,[si]     ; compare with debounce copy
C000:3AF2  74 03             jz C000:3AF7    ; matches -> next row
C000:3AF4  E9 9800           jmp C000:3B8F   ; debounce mismatch -> process
```

Row-scan loop continues:

```asm
C000:3AF7  43                inc bx
C000:3AF8  46                inc si
C000:3AF9  81 FE 2413        cmp si,1324     ; end of matrix?
C000:3AFD  75 EA             jnz C000:3AE9   ; no -> next row
C000:3AFF  F6 06 9D15 01     test byte [159D],1
C000:3B04  74 07             jz C000:3B0D    ; no pending flag -> continue
C000:3B06  80 26 9D15 FE     and byte [159D],FE ; clear flag
C000:3B0B  F9                stc
C000:3B0C  C3                ret             ; return CF=1
```

If no rows changed and no debounce mismatches, falls through to
`C000:3B0D` which checks `[15A1]` and calls `C000:3CEB` (the key
repeat handler).

### Key Change Processing (C000:3B2E)

When a row changed, the processor:
1. Identifies which bit(s) changed (XOR old with new)
2. Looks up the key code from the keyboard translation table at
   `[1126]` (populated by `C000:3ED4` during init)
3. Applies modifiers (shift, control, alt) from `[1310]` row 0
4. Queues the translated key code for consumption

The keyboard translation tables were copied from ROM during init
by `C000:3EBB` (80 bytes to `[1643]`) and `C000:3ED4` (480 bytes
to `[1126]` with a 6-entry pointer table at `[1114]`).

### ROM Translation Table Source (C000:3887, 480 bytes)

Six 80-byte tables (one per modifier state), each containing 10
rows × 8 columns matching the physical keyboard matrix. `0xFF`
marks unused positions. Copied to RAM `[1126..1305]`.

```text
; Table 0: unshifted (C000:3887, file 0xC3887)
3887: FF FF FF 11 DA FF FF FF FF 60 03 20 FF FF 35 FF   ; row 0-1 partial
3897: FF 0C 31 09 FF FF FF FF 33 32 71 77 65 FF 73 64   ; "32qwe.sd"
38A7: 34 FF 7A 78 61 FF 72 66 FF FF 62 76 74 79 67 63   ; "4.zxa.rf..bvtygc"
38B7: 36 12 0D 10 5C 2F 68 6E 3D 37 02 13 0B 75 6D 6B   ; "6...\\/hn=7...umk"
38C7: 38 2D 5D 27 69 6A 2C 30 39 FF FF FF FF FF FF FF   ; "8-]'ij,09"

; Table 1: shifted (C000:38D7)
; Table 2: Caps Lock (C000:3927)
; Table 3: Caps Lock + shifted (C000:3977)
; Table 4: Alt (C000:39C7)
; Table 5: Control (C000:3A17)
```

Key layout (unshifted): `32qwe`, `sd4`, `zxarfbvtygc6`, `\/hn=7`,
`umk8-]'ij,09`, `p;lo.` — matching the DreamWriter physical key
arrangement.

Selected non-printing keys from the same unshifted table are:

| Physical key | Matrix position | Translated byte |
| --- | --- | ---: |
| `ENTER` / Return | row 0 bit 4 | `DA` |
| `INS` | row 6 bit 2 | `0D` |
| `CAN` | row 1 bit 2 | `03` |
| `WP` | row 7 bit 4 | `0B` |

This is UI-command translation, not terminal-mode transmitted characters.
Terminal mode remaps several physical keys separately before serial output.

### ROM Key Code Mapping Source (C000:3927, 80 bytes)

Copied to RAM `[1643..1692]` by `C000:3EBB`. Maps key repeat
pairings.

## Translation Modes

The IRQ path does not enqueue a final character byte directly. `C000:3D0E`
stores a packed event in the ring buffer at `[1694...]`: `DL` is the matrix
index (`row * 8 + column`) and `DH` contains modifier flags built by
`C000:3D44`. The dequeue path `C000:3DBA` then translates that packed event.

Important `C000:3DBA` cases:

| Condition | Translation behavior |
| --- | --- |
| `[143C] & 0x01` | Diagnostic/special table at `C000:3E5C`. |
| `[143C] & 0x08` | Six 80-byte tables copied to `[1126...]`; modifier state indexes the pointer table at `[1114...]`. This is the mode that exposes the editor command bytes from the `C000:3A17` control table. |
| Normal mode, `DH & 0x80` and not Alt | Uses the separate key-code mapping table at `[1643...]` copied from `C000:3927`, not the `C000:3A17` control table. |
| Normal mode, no Ctrl special case | Uses the six translation tables through `C000:3EAC`. |

This distinction matters when naming word-processor commands. In the editor
six-table mode, the control table at `C000:3A17` maps the manual's text-layout
keys to these command bytes:

| Manual key | Matrix key | Editor command byte |
| --- | --- | ---: |
| `CTRL+1` | `1` | `E2` |
| `CTRL+2` | `2` | `E3` |
| `CTRL+5` | `5` | `EE` |
| `CTRL+6` | `6` | `EF` |
| `CTRL+7` | `7` | `F1` |
| `CTRL+8` | `8` | `F2` |
| `CTRL+9` | `9` | `18` |
| `CTRL+0` | `0` | `05` |
| `CTRL+TAB` | `TAB` | `07` |
| `CTRL+INS` | `INS` | `E7` |
| `CTRL+_` | `-` / `_` | `ED` |
| `CTRL+C` | `C` | `1E` |
| `CTRL+R` | `R` | `19` |
| `CTRL+E` | `E` | `D6` |
| `CTRL+G` | `G` | `D8` |
| `CTRL+H` | `H` | `D1` |
| `CTRL+V` | `V` | `D4` |
| `CTRL+X` | `X` | `F4` |
| `CTRL+B` | `B` | `E0` |
| `CTRL+Z` | `Z` | `E1` |
| `CTRL+Q` | `Q` | `FC` |
| `CTRL+W` | `W` | `FB` |

Those are editor input command bytes. They should not be confused with stored
word-processor body markers of the same numeric value.

### State Variables

| Address | Purpose |
| --- | --- |
| `[1306..130F]` | Current keyboard row scan (10 rows from port 0xB0) |
| `[1310..1319]` | Previous scan (for change detection) |
| `[131A..1323]` | Debounce copy |
| `[1324]` | Key repeat enabled flag |
| `[1325..1327]` | Key repeat state |
| `[132C]` | Scan state / empty-scan counter |
| `[132D]` | Row counter (0..9) |
| `[132E]` | Key repeat initial delay |
| `[132F..1332]` | Key repeat parameters |
| `[1114..111F]` | 6-entry pointer table into `[1126]` |
| `[1126..1305]` | Keyboard translation table (480 bytes) |
| `[1643..1692]` | Key code mapping table (80 bytes) |
| `[159D]` | Bit 0: pending key event flag |
| `[15A1]` | Key repeat active flag |
