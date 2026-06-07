# ED1B and AD00 Banked Segments

The banked ROM segments in window 7 (`ED1B`, 3 blocks) and window 5
(`AD00`, 18 blocks). These segments provide ROM CARD / external storage
functionality reached via bank-switching through port `0x15`.

## ED1B — Window 7 Bank Switch Wrappers (3 blocks)

The ED1B segment is in window 7 alongside EE17. It provides wrappers
that switch to the AD00 bank and call through with segment register
save/restore.

### ED1B:0D25 — Bank Switch Entry

Called from `DEF0:27B9` (menu rendering loop). Saves DS, ES, SS to
`[7EC0..7EC4]`, saves current bank value from `[147F]`, switches
to bank 2 (port `0x15` = `0x02` → AD00 segment), calls `AD00:009A`,
restores the original bank, and clears `[172A]`.

```asm
ED1B:0D2F  8C06C27E       mov [7EC2],es        ; save ES
ED1B:0D33  8C16C47E       mov [7EC4],ss        ; save SS
ED1B:0D37  A07F14         mov al,[147F]        ; current bank
ED1B:0D3A  50             push ax
ED1B:0D3B  B002           mov al,2             ; bank 2 = AD00
ED1B:0D3D  A27F14         mov [147F],al
ED1B:0D40  E615           out 0x15,al          ; switch bank
ED1B:0D42  9A9A0000AD     call far AD00:009A   ; call into banked ROM
ED1B:0D47  58             pop ax
ED1B:0D48  A27F14         mov [147F],al        ; restore bank
ED1B:0D4B  E615           out 0x15,al          ; switch back
```

### ED1B:0E81 — Banked Keyboard Read

Called from `AD00:0150`. Restores DS/ES/SS from `[7EC0..7EC4]`
(saved by `ED1B:0D25`), calls `DEF0:0043` (keyboard char input),
then restores the banked segment registers.

### ED1B:0EE9 — Banked Input Status Check

Called from `AD00:0143`. Same segment restore pattern as `0E81`,
calls `DEF0:0063` (check keyboard input status).

## AD00 — External Storage / ROM CARD (18 blocks)

The AD00 segment is mapped via port `0x15=0x02` (bank 2). Contains
the external storage handler, likely for ROM CARD operations.

### AD00:009A — External Storage Entry

Allocates a 2-byte stack frame. Initializes state variables at
`[1B02..1B24]` and `[2014]`:

| Address | Value | Purpose |
| --- | --- | --- |
| `[1B02]` | `0x0000` | Operation counter |
| `[1B04]` | `0x0006` | Block size |
| `[1B06]` | `0x0000` | Current offset |
| `[1B08]` | `0x0000` | Status |
| `[1B1E]` | `0x0001` | Active flag |
| `[1B20]` | `0x0000` | Error code |
| `[1B22]` | `0x003C` | Timeout (60 ticks) |
| `[1B24]` | `0x003C` | Max timeout |
| `[2014]` | `0x00` | Operation mode |

Then calls `AD00:00FC` for the main operation loop.

### AD00:00FC — Operation Loop

Main dispatch loop for external storage operations. Uses the
C-style stack frame convention. Jumps to `AD00:022C` for the
loop condition, dispatches through `AD00:0108` and continuation
blocks.

### AD00:00E4 — Parameter Reader

Reads a parameter from a far pointer at `[BP+4]` via LES.

### AD00:0143 / AD00:0150

Call back into ED1B for keyboard status check and character
read while the AD00 bank is active.

## Segment Register Save Area

| Address | Purpose |
| --- | --- |
| `[7EC0]` | Saved DS |
| `[7EC2]` | Saved ES |
| `[7EC4]` | Saved SS |
| `[7EC6]` | Saved SS (for nested calls) |
| `[147F]` | Current bank value |
| `[172A]` | Cleared on return |
