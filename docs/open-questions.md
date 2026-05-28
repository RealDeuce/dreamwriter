# Open Questions

1. The direct branch inventory over `0x40000..0x50000` is noisy because linear
   disassembly crosses inline data. Build a function-boundary-aware pass before
   promoting new targets.
2. Name more service IDs in the banked spell/linguistic dispatcher at
   `3000:4AA6`. Confirmed so far: startup IDs `0x00`, `0x01`, `0x3C`, `0x3D`
   and diagnostic `Q/R` IDs `0x58`, `0x59`.
3. Trace the text rendering routine that consumes the `0x580B6` glyph table and
   confirm the exact role of the candidate width/metadata table at `0x58000`.
4. Confirm how the renderer selects the bold glyph run at `0x586B6`, the
   small/down-shifted glyph run at `0x58CB6`, and the small-bold run at
   `0x592B6`, the narrow run at `0x598B6`, and the narrow-bold run at
   `0x59EB6`, the narrow-small run at `0x5A4B6`, and the narrow-small-bold run
   at `0x5AAB6`.
5. Identify the consumer and code mapping for the sparse/remapped glyph sets at
   `0x5B0B6`, `0x5B6B6`, `0x5BCB6`, and `0x5C2B6`.
6. Confirm whether the dense tables after `F8DC:000D` are glyph data, boot
   graphics, or another packed resource.
7. Classify the code or packed data beginning around `0x5C98E`, immediately
   after the MAME-declared glyph stream.
8. Find the caller/trigger path for the `C000:5097` dispatcher table at
   `0x45000` and name the `AH` service values it handles.
9. Identify the encoding and consumer for the candidate status/icon resource
   cluster around `0x55110..0x552AC`.
10. Confirm how the startup banner resource at `0x53888..0x539AA` is selected.
   The manual and `mame/nakajies.cpp` TODO indicate boot should display the
   version/copyright notice, while the current emulated path appears to show
   only `INITIALIZING` before the menu. No direct `mov si,D008/D012/D02A`
   reference has been found yet.
11. Determine whether the missing startup banner is tied to hard V20 reset
   versus the retained-RAM power/wake path through IRQ `F8`/`FF` and port
   `0x70`.
12. Confirm the physical power-button wiring. Current firmware evidence suggests
   IRQ `F8` is the suspend/save side and IRQ `FF` is the wake/reset side, but
   MAME exposes only synthetic IRQ keys and no named power input.
13. Decode the `C688:0240` inline display script opcode table at `C688:38A4`
   enough to split script bytes from code automatically.
14. Trace references to the main UI string cluster at `0x53800..0x58000` backward
   to identify menu handlers.
15. Split confirmed code from inline strings/data around `C000:1200..16FF`.
16. Split confirmed code from data in the `C688:0000..01FF` far-call area.
17. Name the low RAM variables in `6D00..70FF` as their roles become stable.
18. Decode the `FF 44` resource records handled at `C000:675D`; current evidence
    suggests positioned region/line/fill drawing rather than source-backed
    bitmap blits.
19. Finish the horizontal menu drawing trace. The organizer icon table at
    `0x708BC`, the word-processor top table at `0x6FA78`, and the `COMMUNICATE`
    submenu table at `0x6FBC8` resolve to confirmed menu-matching 40x40 icon
    sources plus fixed-width labels. The final utility that consumes these
    icon/label tables still needs confirmation.
