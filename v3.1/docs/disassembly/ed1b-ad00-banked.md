# ED1B and AD00 Banked Segments

The banked ROM segments in window 7 (`ED1B`, 12 blocks) and window 5
(`AD00`, 458 blocks). ED1B provides the bank-switching wrappers that
enter the AD00 segment and the callback stubs that AD00 uses to reach
DEF0 services. AD00 contains the Card Memory subsystem — a complete
21-opcode command processor for PCMCIA Type 1 SRAM cards (64 KB to
1 MB). This is the "ROM Card" / "Card Memory" feature from the manual
(p.11, 71).

## ED1B — Bank Switch Wrappers (12 blocks)

The ED1B segment is in window 7 alongside EE17. It handles the
bank-switch protocol: save segment registers, remap window 5 to
AD00, call into banked code, restore on return. AD00 calls back
through ED1B stubs to reach DEF0 services while the bank is active.

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

### ED1B Callback Stubs

AD00 calls back into ED1B to reach DEF0 services while the AD00
bank is active. Each stub restores DS/ES/SS from `[7EC0..7EC4]`,
calls the DEF0 service, then restores the banked register state.

| ED1B address | Called from | DEF0 target | Purpose |
| --- | --- | --- | --- |
| `ED1B:0D63` | `AD00:1E44` | `DEF0:0D91` | Build display script |
| `ED1B:0DB3` | `AD00:0288` | `DEF0:0D80` | Display init |
| `ED1B:0E1E` | `AD00:1879` | — | State transfer |
| `ED1B:0E51` | `AD00:1F4E` | `DEF0:00B8` | Get time (far wrapper) |
| `ED1B:0E81` | `AD00:0150` | `DEF0:0043` | Keyboard char input |
| `ED1B:0EB1` | `AD00:1270` | `DEF0:00F9` | Set date |
| `ED1B:0EE9` | `AD00:0143` | `DEF0:0063` | Check input status |
| `ED1B:0F1A` | `AD00:0577` | — | Data transfer (2 blocks) |
| `ED1B:0F4C` | `AD00:0577` | — | Data transfer (3 blocks) |

## AD00 — ROM CARD Subsystem (458 blocks)

The AD00 segment is mapped via port `0x15=0x02` (bank 2). Contains
a complete command processor for ROM CARD external storage with 21
opcodes dispatched through a word table at `AD00:0202`.

### AD00:009A — Subsystem Entry

Called from `ED1B:0D42`. Initializes state variables and enters the
command loop at `AD00:00FC`.

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

### AD00:00FC — Command Loop

Reads a command byte, doubles it as an index into the dispatch
table at `AD00:0202`, and jumps to the handler. Each handler
returns to `AD00:022C` (loop condition) which checks for more
commands.

```asm
AD00:01F9  D1E0           shl ax,1             ; index * 2
AD00:01FB  8BD8           mov bx,ax
AD00:01FD  2EFFA70202     jmp [cs:bx+0x202]    ; dispatch
```

### Dispatch Table (AD00:0202, 21 entries)

All handlers use the C-style frame: `PUSH BP; MOV BP,SP; SUB SP,n`.

| Op | Handler | Blocks | Calls back to ED1B | Purpose |
| ---: | --- | ---: | --- | --- |
| 0 | `AD00:0BCE` | 44 | | Block read |
| 1 | `AD00:122A` | 40 | `ED1B:0EB1` (set date) | Data transfer with timestamp |
| 2 | `AD00:051E` | 11 | | Status query |
| 3 | `AD00:1806` | 3 | `ED1B:0E1E` | Extended status |
| 4 | `AD00:0182` | 0 | | No-op (direct return) |
| 5 | `AD00:0242` | 28 | `ED1B:0F1A,0F4C` (data) | Data write |
| 6 | `AD00:044A` | 11 | `ED1B:0F1A,0F4C` (data) | Data format |
| 7 | `AD00:116A` | 17 | | Directory read |
| 8 | `AD00:0A30` | 2 | | Short operation |
| 9 | `AD00:01A9` | 0 | | No-op (direct return) |
| 10 | `AD00:0EA0` | 2 | | Short operation |
| 11 | `AD00:0892` | 27 | | Block write |
| 12 | `AD00:183C` | 3 | `ED1B:0E1E` | Extended query |
| 13 | `AD00:1866` | 1 | `ED1B:0E1E` | State check |
| 14 | `AD00:199A` | 29 | | Multi-block operation |
| 15 | `AD00:0A5C` | 10 | | Seek/position |
| 16 | `AD00:0ED0` | 37 | | Block format |
| 17 | `AD00:1B5A` | 34 | `ED1B:0D63,0DB3` (display) | Operation with display feedback |
| 18 | `AD00:1D92` | 34 | `ED1B:0D63,0E51` (display, time) | Operation with time+display |
| 19 | `AD00:1554` | 30 | | Extended transfer |
| 20 | `AD00:0536` | 10 | `ED1B:0F1A,0F4C` (data) | Alternate data write |

### Shared Helpers

| Address | Called from | Purpose |
| --- | --- | --- |
| `AD00:00E4` | multiple | Parameter reader: LES BX,[BP+4] |
| `AD00:0108` | `00FC` | Loop continuation |
| `AD00:0143` | multiple | Keyboard status (→ `ED1B:0EE9` → `DEF0:0063`) |
| `AD00:0150` | multiple | Keyboard read (→ `ED1B:0E81` → `DEF0:0043`) |
| `AD00:0288` | op 17,18 | Display init callback (→ `ED1B:0DB3` → `DEF0:0D80`) |
| `AD00:0577` | op 5,6,20 | Data transfer callback (→ `ED1B:0F1A/0F4C`) |
| `AD00:1270` | op 1 | Date set callback (→ `ED1B:0EB1` → `DEF0:00F9`) |
| `AD00:1879` | op 3,12,13 | State transfer callback (→ `ED1B:0E1E`) |
| `AD00:1E44` | op 17 | Display render callback (→ `ED1B:0D63` → `DEF0:0D91`) |
| `AD00:1F4E` | op 18 | Time read callback (→ `ED1B:0E51` → `DEF0:00B8`) |

### Call Flow

```text
DEF0:27B9 (menu rendering)
  → ED1B:0D25 (save regs, switch to bank 2)
    → AD00:009A (init state, enter command loop)
      → AD00:00FC (read command, dispatch)
        → AD00:handler (execute operation)
          → ED1B:callback (restore regs, call DEF0)
            → DEF0:service (display/keyboard/datetime)
          ← ED1B:callback (restore banked regs)
        ← AD00:handler
      → AD00:022C (loop condition)
    ← AD00 (return)
  ← ED1B:0D25 (restore bank, restore regs)
```

## Segment Register Save Area

| Address | Purpose |
| --- | --- |
| `[7EC0]` | Saved DS |
| `[7EC2]` | Saved ES |
| `[7EC4]` | Saved SS |
| `[7EC6]` | Saved SS (for nested callbacks) |
| `[147F]` | Current bank value |
| `[172A]` | Cleared on return from AD00 |
