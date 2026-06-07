# Menu Scripting Interpreter

The C772 application runtime is built around a bytecode interpreter at
`C772:3944`. Application logic is encoded as inline bytecode programs
after `CALL C772:022D` instructions. The interpreter reads and dispatches
opcodes from these programs, executing native handler routines for each
one.

This is NOT a general-purpose BASIC-style interpreter — it's a
domain-specific engine for driving the typewriter's menu system and
application UI. The 96 opcodes handle display rendering, keyboard input,
menu navigation, application state management, and launching native
code modules (WP editor, organizer apps, etc.).

## C772:022D — Yield to Interpreter

A `JMP C772:3944` that serves as the "yield" instruction. Callers do:

```asm
    CALL C772:022D    ; push return address (= bytecode pointer)
    db opcode, ...    ; inline bytecode program follows
```

The `CALL` pushes the address of the first bytecode byte onto the stack.
The interpreter pops it as SI and starts executing opcodes from there.
160 call sites in the ROM use this pattern.

```asm
; file 0xC794D
C772:022D  E9 1437           jmp C772:3944
```

## C772:3944 — Interpreter Fetch-Decode-Execute Loop

```asm
; file 0xCB064
C772:3944  5E                pop si            ; SI = bytecode pointer
C772:3945  2E 8A04           mov al,[cs:si]    ; fetch opcode byte
C772:3948  46                inc si
C772:3949  8A C8             mov cl,al         ; CL = opcode
C772:394B  3C 44             cmp al,44
C772:394D  90                nop
C772:394E  90                nop
C772:394F  72 08             jc C772:3959      ; opcode < 0x44: no parameter
C772:3951  2E 8A04           mov al,[cs:si]    ; opcode >= 0x44: read param byte
C772:3954  8A D0             mov dl,al         ; DL = parameter
C772:3956  B6 00             mov dh,0
C772:3958  46                inc si            ; advance past parameter
C772:3959  56                push si           ; save bytecode pointer
C772:395A  BE 6F39           mov si,396F       ; dispatch table base
C772:395D  B5 00             mov ch,0          ; CX = opcode (zero-extended)
C772:395F  03 F1             add si,cx         ; but opcodes index words...
```

Note: `ADD SI,CX` adds the opcode value once, not doubled. This means
the dispatch table entries are packed as single bytes? No — looking at
the actual table, CL already contains the raw opcode and the table at
`396F` is indexed by opcode value directly. Since each entry is 2 bytes
(a word), and the opcode is NOT doubled, the effective index is
`396F + opcode`. But that only works if the opcode values are
pre-multiplied by 2 in the bytecode. Let me re-examine...

Actually, looking at the raw table: 96 opcodes (0x00..0x5F) × 2 bytes
= 192 bytes. The table at `396F` runs to `3A2F`. And `ADD SI,CX` adds
the raw opcode value. So the opcodes in the bytecode stream are
**pre-doubled** — opcode 0 is bytecode `0x00`, opcode 1 is bytecode
`0x02`, opcode 2 is bytecode `0x04`, etc. The maximum single-byte
opcode bytecode is `0x43` (representing handler slot 33), and
two-byte opcodes start at bytecode `0x44` (handler slot 34).

```asm
C772:3961  2E 8B34           mov si,[cs:si]    ; SI = handler address from table
C772:3964  B9 4439           mov cx,3944       ; CX = interpreter loop address
C772:3967  51                push cx           ; push return to interpreter
C772:3968  FF E6             jmp si            ; dispatch to handler
```

Each handler executes and returns via `RET` which pops `3944` and
re-enters the interpreter loop. The bytecode pointer is still on the
stack from the `PUSH SI` at `3959`.

## Dispatch Table at C772:396F

96 entries (192 bytes), each a 16-bit offset within C772. The opcode
bytecode values are pre-doubled, so bytecode `0x00` = slot 0,
`0x02` = slot 1, `0x04` = slot 2, etc.

| Bytecode | Slot | Handler | Notes |
| ---: | ---: | --- | --- |
| `00` | 0 | `C772:367E` | |
| `02` | 1 | `C772:367D` | |
| `04` | 2 | `C772:3668` | |
| `06` | 3 | `C772:3672` | |
| `08` | 4 | `C772:387A` | |
| `0A` | 5 | `C772:37D5` | |
| `0C` | 6 | `C772:37DF` | |
| `0E` | 7 | `C772:6CE4` | |
| `10` | 8 | `C772:6CE0` | |
| `12` | 9 | `C772:36DC` | |
| `14` | 10 | `C772:37FB` | |
| `16` | 11 | `C772:3805` | |
| `18` | 12 | `C772:3800` | |
| `1A` | 13 | `C772:380E` | |
| `1C` | 14 | `C772:383E` | |
| `1E` | 15 | `C772:3830` | |
| `20` | 16 | `C772:5E18` | |
| `22` | 17 | `C772:2DBD` | |
| `24` | 18 | `C772:37E9` | |
| `26` | 19 | `C772:385D` | |
| `28` | 20 | `C772:3BD8` | |
| `2A` | 21 | `C772:5E2B` | |
| `2C` | 22 | `C772:5E2F` | |
| `2E` | 23 | `C772:386A` | |
| `30` | 24 | `C772:3872` | |
| `32` | 25 | `C772:3856` | |
| `34` | 26 | `C772:3824` | |
| `36` | 27 | `C772:380A` | |
| `38` | 28 | `C772:45A7` | copies 0x6B bytes [73F7]->[7487+] |
| `3A` | 29 | `C772:64F4` | calls 45A7 + 4556 |
| `3C` | 30 | `C772:64EA` | |
| `3E` | 31 | `C772:3864` | |
| `40` | 32 | `C772:37C1` | |
| `42` | 33 | `C772:37CB` | |
| `44` | 34 | `C772:384C` | (first two-byte opcode slot) |
| `46` | 35 | `C772:3851` | |
| `48` | 36 | `C772:3810` | |
| `4A` | 37 | `C772:382B` | |
| `4C` | 38 | `C772:3815` | |
| `4E` | 39 | `C772:3826` | |
| `50` | 40 | `C772:3903` | |
| `52` | 41 | `C772:390A` | |
| `54` | 42 | `C772:3911` | |
| `56` | 43 | `C772:03FE` | |
| `58` | 44 | `C772:040E` | |
| `5A` | 45 | `C772:0406` | |
| `5C` | 46 | `C772:3932` | |
| `5E` | 47 | `C772:3918` | |
| `60` | 48 | `C772:3925` | |
| `62` | 49 | `C772:3BFA` | |
| `64` | 50 | `C772:5E1E` | set CL=0x0A, fall through |
| `66` | 51 | `C772:3696` | |
| `68` | 52 | `C772:3690` | |
| `6A` | 53 | `C772:36D3` | |
| `6C` | 54 | `C772:36E9` | |
| `6E` | 55 | `C772:36B0` | |
| `70` | 56 | `C772:36B9` | |
| `72` | 57 | `C772:36BD` | |
| `74` | 58 | `C772:3715` | |
| `76` | 59 | `C772:36F8` | |
| `78` | 60 | `C772:3724` | |
| `7A` | 61 | `C772:373B` | |
| `7C` | 62 | `C772:370E` | |
| `7E` | 63 | `C772:5E22` | set CL=0x3A, fall through |
| `80` | 64 | `C772:381A` | |
| `82` | 65 | `C772:38F0` | |
| `84` | 66 | `C772:38D1` | |
| `86` | 67 | `C772:38DB` | |
| `88` | 68 | `C772:38E8` | (first two-byte in upper range) |
| `8A` | 69 | `C772:38C1` | |
| `8C` | 70 | `C772:38B9` | |
| `8E` | 71 | `C772:3889` | |
| `90` | 72 | `C772:38A9` | |
| `92` | 73 | `C772:38A1` | |
| `94` | 74 | `C772:3899` | |
| `96` | 75 | `C772:38B1` | |
| `98` | 76 | `C772:3891` | |
| `9A` | 77 | `C772:3880` | |
| `9C` | 78 | `C772:38C9` | |
| `9E` | 79 | `C772:03E6` | |
| `A0` | 80 | `C772:03EC` | |
| `A2` | 81 | `C772:03F8` | |
| `A4` | 82 | `C772:03F2` | |
| `A6` | 83 | `C772:371C` | |
| `A8` | 84 | `C772:36FE` | |
| `AA` | 85 | `C772:3728` | |
| `AC` | 86 | `C772:3767` | |
| `AE` | 87 | `C772:3763` | |
| `B0` | 88 | `C772:374A` | |
| `B2` | 89 | `C772:3684` | |
| `B4` | 90 | `C772:378E` | |
| `B6` | 91 | `C772:369E` | |
| `B8` | 92 | `C772:04E8` | |
| `BA` | 93 | `C772:5E00` | |
| `BC` | 94 | `C772:0BE9` | |
| `BE` | 95 | `C772:E81F` | |

Handlers concentrated at `C772:3600..39FF` (72 of 96) are likely simple
state/display primitives. Outlier handlers at `C772:03xx`, `04xx`,
`0Bxx`, `2Dxx`, `45xx`, `5Exx`, `64xx`, `6Cxx`, and `E8xx` are the
more complex operations — probably application launchers and display
mode switches.

## Bytecode Format

Each bytecode program is a sequence of opcode bytes embedded after
`CALL C772:022D`. Opcode values are pre-doubled (each value indexes a
2-byte table entry at `C772:396F`).

- **Single-byte opcodes**: bytecodes `0x00..0x43`. The raw byte is the
  table index.
- **Two-byte opcodes**: bytecodes `0x44..0xBE`. The first byte is the
  table index, the second byte is a parameter passed in DL.

A bytecode program ends when a handler does not return to the
interpreter loop (i.e., it calls `C772:022D` itself to start a new
program, or it enters a native code path that doesn't return).

## Handler Classification (Partial)

Based on the trace:

- **`C772:45A7`** (opcode `0x38`): Copies 0x6B bytes from `[73F7]` to
  the address at `[7487]`. State save/restore operation.
- **`C772:64F4`** (opcode `0x3A`): Calls `45A7` then `4556`. Composite
  state operation.
- **`C772:5E18`** (opcode `0x20`): Sets CL=`0x11`, DL=`0xFF`, jumps to
  shared handler at `C772:5E35`. Display mode switch.
- **`C772:5E1E`** (opcode `0x64`): Sets CL=`0x0A`, shared handler.
- **`C772:5E2F`** (opcode `0x2C`): Sets CL value, shared handler.
- **`C772:3BFA`** (opcode `0x62`): Likely a control-flow opcode
  (conditional branch within bytecode).
- **`C772:E81F`** (opcode `0xBE`): Far outlier address — probably
  launches a major application module.

Full handler characterization requires tracing each handler's behavior
and correlating with known UI operations.

## Architectural Relationship

```text
                    C772:022D (yield to interpreter)
                         |
                    C772:3944 (fetch-decode-execute)
                         |
                    C772:396F (dispatch table, 96 entries)
                         |
         +---------------+---------------+
         |               |               |
    C772:36xx-39xx   C772:5Exx      C772:E8xx
    (primitives)   (display modes) (app launchers)
         |               |               |
    state/display    DEF0 calls      native code
    operations       via far-call    modules
                     table [0200]
```
