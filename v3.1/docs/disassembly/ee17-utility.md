# EE17 Utility Library (Window 7)

The EE17 segment lives in window 7 (port `0x17=0x00`, bank 15, file
base `0xEE170`). It contains 212 blocks / 2261 instructions with zero
data gaps — a solid, contiguous code library.

Called from DEF0 (2 call sites) and internally from itself. All external
calls go to `C000:3F35` (display script wrapper, 13 calls) or back into
DEF0. Some routines in the upper address range are called via segment
alias `EF8A` — see [`ef8a-utility.md`](ef8a-utility.md).

## C000:3F35 Dependency

EE17 is one of the two major callers of the display script far wrapper
(the other being DEF0). Every display operation in EE17 goes through
`C000:3F35` with the standard argument pattern:

```asm
MOV AX, page       ; display page
MOV BX, offset     ; script source (within caller's data segment)
MOV CX, length     ; byte count
CALL FAR C000:3F35  ; render display script
```

## EE17:0047 — Clear State Block

Called 14 times from within EE17. Takes AX = base address of a state
block, clears bytes at `[BX]` and `[BX+0x11]` in a loop.

```asm
; file 0xEE1B7
EE17:0047  8B D8             mov bx,ax       ; BX = base address
EE17:0049  C6 07 00          mov byte [bx],0
EE17:004C  C6 47 11 00       mov byte [bx+11],0
EE17:0050  43                inc bx
EE17:0051  33 C0             xor ax,ax       ; counter = 0
EE17:0053  EB 05             jmp short EE17:005A
EE17:0055  C6 07 00          mov byte [bx],0
EE17:0058  43                inc bx
EE17:0059  40                inc ax
EE17:005A  3D 1000           cmp ax,10       ; 16 bytes
EE17:005D  7C F6             jl EE17:0055
EE17:005F  CB                retf
```

Clears a structure with two 17-byte fields at offset 0 and offset 0x11.
Total structure size = 0x22 (34 bytes).

## EE17:08AD — Copy State Block

Called 14 times. Copies a state block from `[BX]` to `[SI]` (17 bytes
at offset 0 and 17 bytes at offset 0x11). Checks `[A342]` first — if
nonzero, returns AX=SI immediately without copying.

```asm
; file 0xEF01D
EE17:08AD  51                push cx
EE17:08AE  56                push si
EE17:08AF  57                push di
EE17:08B0  8B F0             mov si,ax
EE17:08B2  83 3E 42A3 00     cmp word [A342],0
EE17:08B7  74 04             jz EE17:08BD    ; [A342]==0 -> copy
EE17:08B9  8B C6             mov ax,si       ; [A342]!=0 -> return SI
EE17:08BB  EB 20             jmp short EE17:08DD
EE17:08BD  8A 07             mov al,[bx]     ; copy loop
EE17:08BF  88 04             mov [si],al
EE17:08C1  8A 47 11          mov al,[bx+11]
EE17:08C4  88 44 11          mov [si+11],al
EE17:08C7  8B FE             mov di,si
EE17:08C9  47                inc di
EE17:08CA  43                inc bx
```

## EE17:16C1 — Init Entry (Called from DEF0:5C07)

The init entry point called during cold boot from `DEF0:5C07`. Calls
`EE17:0047` with AX=`0xA37E` to clear a state block at that address.

```asm
; file 0xEF831
EE17:16C1  B8 7EA3           mov ax,A37E
EE17:16C4  9A 4700 17EE      call far EE17:0047
EE17:16C9  CB                retf
```

## EE17:16CA — Reinit Entry (Called from DEF0:5C2E)

The warm-reinit entry called during warm boot from `DEF0:5C2E`. More
substantial than the cold init — calls DEF0 display services, then
initializes multiple state blocks and display pages.

```asm
; file 0xEF83A
EE17:16CA  51                push cx
EE17:16CB  52                push dx
EE17:16CC  9A 800D F0DE      call far DEF0:0D80   ; display service
EE17:16D1  B8 0200           mov ax,2
EE17:16D4  50                push ax
EE17:16D5  B8 0800           mov ax,8
EE17:16D8  BB 1B00           mov bx,1B
EE17:16DB  B9 8901           mov cx,189
EE17:16DE  BA 2500           mov dx,25
EE17:16E1  9A F50D F0DE      call far DEF0:0DF5   ; display page setup
```

Continues with multiple display page setup calls and state block
initialization through `EE17:173E`.

## Segment Role

EE17 manages a set of 34-byte state blocks (17+17 byte paired fields)
and associated display pages. The state blocks live in the
`[A300..A400]` RAM area. Called from `DEF0:5C07` (cold init via
`EE17:16C1`) and `DEF0:5C2E` (warm reinit via `EE17:16CA`). The
library provides:

- **Init/clear** (`0047`) — zero out a state block, AX = base address
- **Copy** (`08AD`) — duplicate a state block
- **Display** — render pages through `C000:3F35`

The state blocks track the display subsystem's page configuration.
`EE17:16C1` initializes them with base `AX=0xA37E`, and `EE17:16CA`
reinitializes after a warm restart with display page re-rendering via
`DEF0:0D80` and `DEF0:0DF5`.

## Address Summary

| Address | Callers | Purpose |
| --- | --- | --- |
| `EE17:0047` | 14 | Clear 34-byte state block at [AX] |
| `EE17:08AD` | 14 | Copy state block from [BX] to [AX] |
| `EE17:16C1` | 1 (DEF0:5C07) | Cold init: clear block at [A37E] |
| `EE17:16CA` | 1 (DEF0:5C2E) | Warm reinit: display + state setup |
| `EE17:0009..173E` | — | Full code range (5942 bytes, 0 gaps) |
