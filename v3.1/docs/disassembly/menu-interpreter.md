# Menu Scripting Interpreter

The C772 application runtime is built around a bytecode interpreter at
`C772:3944`. Application logic is encoded as inline bytecode programs
after `CALL C772:022D` instructions. The interpreter reads and dispatches
opcodes from these programs, executing native handler routines for each
one.

The bytecode programs drive all user-visible features: the Organizer
menu (Calculator, Calendar, Scheduler, World Clock, Address Book) and
the Word Processor menu (Edit Text, File, Clear Text, Printer,
Communicate, Others). Menu strings are in EE17 ROM data
(`EE17:31D4..4390`). See `docs/reference/dreamwriter-t400-manual-summary.md`
for the complete feature map.

160 call sites in the ROM use this pattern. A duplicate interpreter
loop exists at `C000:B064` (reached from thunk B slot 11) allowing
the editor utility to yield back to the interpreter without returning
to C772.

## C772:022D — Yield to Interpreter

```asm
C772:022D  E91437         jmp C772:3944
```

Callers do `CALL C772:022D` followed by inline bytecode. The `CALL`
pushes the address of the first bytecode byte onto the stack. The
interpreter pops it as SI.

## C772:3944 — Fetch-Decode-Execute Loop

```asm
C772:3944  5E             pop si            ; SI = bytecode pointer
C772:3945  2E8A04         mov al,[cs:si]    ; fetch opcode byte
C772:3948  46             inc si
C772:3949  8AC8           mov cl,al         ; CL = opcode
C772:394B  3C44           cmp al,0x44
C772:394F  7208           jc 3959           ; < 0x44: single-byte
C772:3951  2E8A04         mov al,[cs:si]    ; >= 0x44: read param
C772:3954  8AD0           mov dl,al         ; DL = parameter
C772:3956  B600           mov dh,0
C772:3958  46             inc si
C772:3959  56             push si           ; save bytecode pointer
C772:395A  BE6F39         mov si,396F       ; table base
C772:395D  B500           mov ch,0
C772:395F  03F1           add si,cx         ; index by raw opcode
C772:3961  2E8B34         mov si,[cs:si]    ; load handler address
C772:3964  B94439         mov cx,3944       ; push return address
C772:3967  51             push cx
C772:3968  FFE6           jmp si            ; dispatch
```

Opcode values in the bytecode stream are **pre-doubled** — the table
at `396F` has word entries indexed by value directly (no shift needed).
Single-byte opcodes use bytecodes `0x00..0x42`. Two-byte opcodes use
`0x44..0xBE` with the second byte passed in DL.

Each handler returns via `RET` to `3944`, re-entering the loop. The
bytecode pointer is on the stack from the `PUSH SI` at `3959`.

## Shared Helpers

### C772:37B3 — Load State Field

Loads a state block field addressed by DL into registers.

```asm
C772:37B3  BEF773         mov si,73F7       ; state block base
C772:37B6  03F2           add si,dx         ; + field offset
C772:37B8  8B0C           mov cx,[si]       ; CX = field value
C772:37BA  8B161675       mov dx,[7516]     ; DX = accumulator
C772:37BE  0AC0           or al,al          ; set flags
C772:37C0  C3             ret
```

Returns: SI = field pointer, CX = field value, DX = accumulator
`[7516]`. Called by 20+ handlers.

### C772:393E — Save Flags

```asm
C772:393E  9F             lahf              ; AH = flags
C772:393F  8826AC74       mov [74AC],ah     ; save to [74AC]
C772:3943  C3             ret
```

Saves the CPU flags (ZF, SF, CF) to `[74AC]` for conditional branch
opcodes. Used by comparison and arithmetic opcodes as the intermediate
step before the branch handlers test `[74AC]`.

### C772:5E35 — Text Editor Service Dispatcher

Saves editor state, then looks up a behavior mode byte from the
16-byte table at `C772:5E08` using `CL & 0x0F` as index. The
loaded byte goes into CH and its bits control the editing operation:

| CH bit | Meaning |
| ---: | --- |
| `0x01` | Input processing path |
| `0x02` | Alternate direction |
| `0x04` | Cursor manipulation |
| `0x08` | Queue character to `[74B3]` ring buffer |
| `0x10` | Text buffer read/write |
| `0x20` | Read from `[710F]` state pointer |
| `0x80` | State save/restore around operation |

The 16-entry mode table at `C772:5E08`:

```text
[0]=0x70  [1]=0x31  [2]=0x34  [3]=0xA1
[4]=0xA4  [5]=0x32  [6]=0x12  [7]=0x72
[8]=0x2A  [9]=0x22  [A]=0x11  [B]=0x21
[C]=0x24  [D]=0x3A  [E]=0x02  [F]=0x39
```

CL values in the handler opcodes select from this table via `CL & 0xF`.
The upper nibble of CL adds additional flags (`0x10` = direction,
`0x80` = special mode). So CL is a packed mode selector, not a named
service ID.

### C772:041A — Bit Field Resolver

Takes DL (packed field: bits 4-0 = field offset * 2, resolved to
SI pointing into `[046A]` table). Returns AL = current field value,
SI = field pointer. Used by the flag set/clear/toggle opcodes
`0x56`/`0x58`/`0x5A`.

## Dispatch Table (C772:396F, 96 entries)

### Flow Control

| Bytecode | Handler | Behavior |
| ---: | --- | --- |
| `0x00` | `C772:367E` | **Goto**: pop SI (discard bytecode pointer), load SI from `[7516]`. Jumps to address stored in accumulator. |
| `0x02` | `C772:367D` | **Return**: pop SI (return to caller's bytecode stream). |
| `0x06` | `C772:3672` | **Shift accumulator**: `[7516] >>= 1`. |
| `0x40` | `C772:37C1` | **Push accumulator**: pop 2 stack words, push `[7516]`, re-enter interpreter. Saves accumulator for later restore. |
| `0x42` | `C772:37CB` | **Pop accumulator**: pop 3 stack words, restore `[7516]` from third, re-enter interpreter. |
| `0x82` | `C772:38F0` | **Relative branch** (param DL): sign-extend DL, subtract 2, add to bytecode pointer, re-enter interpreter. Unconditional relative jump within bytecode. |

### Conditional Branches

All conditional branches test a flag byte then jump to `C772:38F0`
(relative branch) if the condition is met, or `RET` (fall through)
if not. The branch offset is in DL (parameter byte).

| Bytecode | Handler | Condition |
| ---: | --- | --- |
| `0x84` | `C772:38D1` | Branch if `[742B] != 0` (pending operation) |
| `0x86` | `C772:38DB` | Branch if `[7434] - [7415] >= 0` (cursor past mark) |
| `0x88` | `C772:38E8` | Branch if `[745D] & 0x02` (mode flag set) |
| `0x8A` | `C772:38C1` | Branch if `[745D] & 0x02 == 0` (mode flag clear) |
| `0x8C` | `C772:38B9` | Branch if `[745D] & 0x10 == 0` (alt mode clear) |
| `0x8E` | `C772:3889` | Branch if `[74AC] & 0x40 != 0` (ZF=0 from last compare) |
| `0x90` | `C772:38A9` | Branch if `[74AC] & 0x80 == 0` (SF=0, positive) |
| `0x92` | `C772:38A1` | Branch if `[74AC] & 0xC0 == 0` (ZF=0 and SF=0, greater) |
| `0x94` | `C772:3899` | Branch if `[74AC] & 0xC0 != 0` (ZF=1 or SF=1, LE) |
| `0x96` | `C772:38B1` | Branch if `[74AC] & 0x80 != 0` (SF=1, negative) |
| `0x98` | `C772:3891` | Branch if `[74AC] & 0x40 == 0` (ZF=1 from last compare) |
| `0x9A` | `C772:3880` | Branch if `[745D] & 0x10 != 0` and fall-through RET |
| `0x9C` | `C772:38C9` | Branch if `[745D] & 0x08 != 0` |

### Conditional Branches with Pre-Compare

These call a helper first (`C772:0446` reads `[7516]`, `C772:044B`
resolves via `041A`), then `AND AL,DL` and `LAHF`→`[74AC]`, then
jump to a branch handler.

| Bytecode | Handler | Pre-compare | Branch condition |
| ---: | --- | --- | --- |
| `0x9E` | `C772:03E6` | `0446` (accumulator) | Branch if ZF=0 (bits match) |
| `0xA0` | `C772:03EC` | `0446` (accumulator) | Branch if ZF=1 (bits clear) |
| `0xA2` | `C772:03F8` | `044B` (field) | Branch if ZF=0 |
| `0xA4` | `C772:03F2` | `044B` (field) | Branch if ZF=1 |

### Test and Compare

| Bytecode | Handler | Behavior |
| ---: | --- | --- |
| `0x50` | `C772:3903` | **Test state flags**: `AL = [73F7] AND DL`, save flags to `[74AC]`. Tests the editor active/mode byte. |
| `0x52` | `C772:390A` | **Test display flags**: `AL = [745F] AND DL`, save flags. |
| `0x54` | `C772:3911` | **Test mode flags**: `AL = [745D] AND DL`, save flags. |
| `0x5C` | `C772:3932` | **Compare accumulator**: `SI = [74B5] & 0xFF - DX`, save flags. Compares last key code against parameter. |
| `0x5E` | `C772:3918` | **Test key 0xE9**: if `[74B5]==0xE9`, compare `[74E6]-DX`, save flags. Else set ZF=0. |
| `0x60` | `C772:3925` | **Test key 0xEF**: if `[74B5]==0xEF`, compare `[74E6]-DX`, save flags. Else set ZF=0. |

### Data Operations

All use `C772:37B3` to load state field addressed by DL. After the
operation, the handler stores results back to the field via SI.

| Bytecode | Handler | Behavior |
| ---: | --- | --- |
| `0x66` | `C772:3696` | **Increment word**: CX++, store to `[SI]`, advance SI. |
| `0x68` | `C772:3690` | **Decrement word**: CX--, store to `[SI]`. |
| `0x6A` | `C772:36D3` | **Add with carry**: `[7516] = DX + CX + CF`, save flags. |
| `0x6C` | `C772:36E9` | **Subtract with borrow**: `[7516] = DX - CX - CF`, save flags. |
| `0x6E` | `C772:36B0` | **Call subroutine**: push CX (field value) as return address, re-enter interpreter at the subroutine. |
| `0x74` | `C772:3715` | **Load accumulator**: `[7516] = CX` (copy field to accumulator), save flags. |
| `0x76` | `C772:36F8` | **Store byte**: `[SI] = DL`. Writes parameter to state field. |
| `0x78` | `C772:3724` | **Exchange**: swap SI and DX (exchange field pointer and accumulator), save flags. |
| `0x7A` | `C772:373B` | **Add signed immediate**: sign-extend DL, `[7516] += DX`, save flags. |
| `0x7C` | `C772:370E` | **Store word**: `[SI] = DX`, advance SI. Writes accumulator to field. |

### Text Buffer Operations

| Bytecode | Handler | Behavior |
| ---: | --- | --- |
| `0x04` | `C772:3668` | **Copy forward**: loop reading via `3BB6` (read-forward from `[740F]`/`[7413]`) and writing via `3C2D` (write-forward to `[740D]`/`[7411]`) until carry. |
| `0x14` | `C772:37FB` | **Write marker 0xEA**: `AL=0xEA`, jump to `3C2D` (write-forward). Inserts end-of-block marker. |
| `0x16` | `C772:3805` | **Write marker 0xFF**: `AL=0xFF`, jump to `3BFA` (write-backward). Inserts fill marker. |
| `0x18` | `C772:3800` | **Write marker 0xFF forward**: `AL=0xFF`, jump to `3C2D`. |
| `0x28` | `C772:3BD8` | **Read backward**: read one byte from text buffer (backward direction, `[740D]`/`[7411]`). Returns byte in AL. |
| `0x62` | `C772:3BFA` | **Write backward**: write AL to text buffer (backward direction, `[740F]`/`[7413]`). |

### Flag Set/Clear/Toggle

These operate on a bit field table at `C772:046A`. The parameter
byte DL encodes the field offset (bits 4-0) which is doubled to
index a word table.

| Bytecode | Handler | Behavior |
| ---: | --- | --- |
| `0x56` | `C772:03FE` | **Set bits**: `[SI] \|= DL`. OR parameter into field. |
| `0x58` | `C772:040E` | **Clear bits**: `[SI] &= ~DL`. AND-NOT parameter from field. |
| `0x5A` | `C772:0406` | **Toggle bits**: `[SI] ^= DL`. XOR parameter into field. |

### Editor Service Dispatch

These set CL (mode selector) and optionally DL (parameter), then
jump to `C772:5E35`. CL's low nibble selects a behavior mode from
the table at `5E08`; CL's upper bits add direction/special flags.
See the `5E35` documentation above for CH bit meanings.

| Bytecode | Handler | CL | DL | Effect |
| ---: | --- | ---: | --- | --- |
| `0x0A` | `C772:37D5` | `0x02` | `[7415]+1` | Cursor right (mode `[2]=0x34`: buf r/w + alt) |
| `0x0C` | `C772:37DF` | `0x12` | `[7415]-1` | Cursor left (mode `[2]=0x34` + direction) |
| `0x1A` | `C772:380E` | `0x17` | `0x02` | Cursor op (mode `[7]=0x72`: buf r/w + cursor) |
| `0x1C` | `C772:383E` | `0x01` | `0xFF` | Input + test: if result bit 4 set, return; else read-backward |
| `0x1E` | `C772:3830` | `0x11` | `0xFF` | Input + direction: test result, chain to `0x1A` |
| `0x20` | `C772:5E18` | `0x11` | `0xFF` | Display refresh (mode `[1]=0x31` + direction) |
| `0x26` | `C772:385D` | `0x00` | `0x00` | Null/refresh (mode `[0]=0x70`: cursor + buf r/w) |
| `0x2A` | `C772:5E2B` | `0x19` | `0x00` | Insert mode (mode `[9]=0x22`: alt + input) |
| `0x2C` | `C772:5E2F` | `0x29` | `0x00` | Delete mode (mode `[9]=0x22` + direction) |
| `0x2E` | `C772:386A` | `[74B5]` | `[74B5]` | Key-driven edit (key code selects mode) |
| `0x30` | `C772:3872` | `[74B5]` | `[74B5]` | Key-driven edit (alternate entry via `5E22`) |
| `0x32` | `C772:3856` | `0x07` | `0x01` | Cursor op (mode `[7]=0x72`) |
| `0x34` | `C772:3824` | `0x05` | `0x01` | Buffer op (mode `[5]=0x32`: buf r/w + alt) |
| `0x36` | `C772:380A` | `0x17` | `0x01` | Cursor op (mode `[7]=0x72` + direction) |
| `0x44` | `C772:384C` | `0x01` | param | Input (mode `[1]=0x31`) with parameter |
| `0x46` | `C772:3851` | `0x11` | param | Input + direction with parameter |
| `0x48` | `C772:3810` | `0x17` | param | Cursor (mode `[7]=0x72` + direction) with parameter |
| `0x4A` | `C772:382B` | `0x85` | param | Special mode (mode `[5]=0x32` + `0x80` flag) |
| `0x4C` | `C772:3815` | `0x15` | param | Buffer + direction with parameter |
| `0x4E` | `C772:3826` | `0x05` | param | Buffer (mode `[5]=0x32`) with parameter |
| `0x64` | `C772:5E1E` | `0x0A` | param | Queue char (mode `[A]=0x11`) |
| `0x7E` | `C772:5E22` | `0x3A` | param | Queue + state save (mode `[A]=0x11` + direction + state) |
| `0xBC` | `C772:0BE9` | `0x05` | param | Buffer op (call, not jump, returns to caller) |

### State Management

| Bytecode | Handler | Behavior |
| ---: | --- | --- |
| `0x08` | `C772:387A` | **Set operation mode**: `[74C8] = 0x82`. |
| `0x12` | `C772:36DC` | **Restore context**: pop SI, pop DX, pop CX, push DX, push SI, reload `[7516]` and test AL. Stack frame manipulation for context restore. |
| `0x22` | `C772:2DBD` | **Conditional dispatch**: test `[74B2] & 1`, if set jump to `C772:41AC` (alternate handler). Otherwise continue. |
| `0x24` | `C772:37E9` | **Keyboard service**: call `C772:1ADB`, check `[745D] & 2`, set `[742B]=5` if set, jump to `C772:3D4B`. |
| `0x38` | `C772:45A7` | **Snapshot state**: REP MOVSB 107 bytes from `[73F7]` to `[0000:DI]` via `[7487]`. |
| `0x3A` | `C772:64F4` | **Snapshot + restore A**: call `45A7` (snapshot), then `4556` (restore) with mode from `[74BE]`. |
| `0x3C` | `C772:64EA` | **Snapshot + restore B**: call `45A7`, then `4556` with mode from `[74C0]`. |
| `0x3E` | `C772:3864` | **Reset + dispatch**: call `C772:2B21`, then jump to `2DBD` (conditional dispatch). |
| `0x80` | `C772:381A` | **Snapshot + restore C** (param DL): call `45A7`, then `4556` with mode from DL. |

### Inline Data

| Bytecode | Handler | Behavior |
| ---: | --- | --- |
| `0xA6` | `C772:371C` | **Load inline byte**: read next byte from bytecode stream into DH. Advances bytecode pointer. |
| `0xA8` | `C772:36FE` | **Read inline + store byte**: call `37B3`, read byte from bytecode stream via second stack pointer, store to `[SI]`. |
| `0xAA` | `C772:3728` | **Read inline + store word**: call `37B3`, read byte from bytecode stream, zero-extend to word, store to `[SI]`, advance SI. |
| `0xAC` | `C772:3767` | **Read inline + multi-store** (word): call `37B3` twice, read bytecode byte, use as index, store result. |
| `0xAE` | `C772:3763` | **Read inline + multi-store** (byte): same as 0xAC but single-byte result. |
| `0xB0` | `C772:374A` | **Indirect load**: call `37B3`, read bytecode byte, use `[SI]` as secondary index, indirect read. |
| `0xB2` | `C772:3684` | **Load inline + jump**: read byte from bytecode stream into DH, swap SI/DX, `JMP SI`. Loads a code address from the stream and jumps to it. |
| `0xB4` | `C772:378E` | **Inline call**: read byte and word from bytecode stream (DH + 2-byte address). Push return to interpreter, push inline address, call `37B3` twice with different field selectors, return to inline address. Implements a 3-byte inline subroutine call. |

### Display and Application

| Bytecode | Handler | Behavior |
| ---: | --- | --- |
| `0x0E` | `C772:6CE4` | **Screen redraw**: clear display state `[742F]` via `C772:0DC0`, save/restore cursor `[73F9]`/`[7415]`, call `C772:6D09` + `C772:6C90`. Full screen refresh. |
| `0x10` | `C772:6CE0` | **Screen redraw (alt)**: set AL=1, fall through to `0x0E`. |
| `0x70` | `C772:36B9` | **Setup with zero AL**: xor AL, fall through to `0x72`. |
| `0x72` | `C772:36BD` | **Pop + store to bytecode**: call `37B3`, pop stack to CX, store CL (and CH if AL!=0) to bytecode pointer location. Modifies inline data. |
| `0xB6` | `C772:369E` | **Inline far-call**: read word from bytecode stream as DX, swap SI/DX, call `C772:98EC` (state check). Calls a native routine whose address is inline in the bytecode. |
| `0xB8` | `C772:04E8` | **Application entry** (complex): enters a native code block (handler code extends past the simple dispatch pattern). |
| `0xBA` | `C772:5E00` | **Jump table**: a 24-byte lookup table (not executable code). Contains service parameters used by `5E35`. |
| `0xBE` | `C772:E81F` | **Document operation**: enters 5 bytes into the `C772:E81A` callback (skips register saves), sets `ES=0xCEF`, calls `C772:7115` (document open/validate loop: input via `9530`, process via `73F6`, validate via `85D2`, execute via `8976`, commit via `51E0`, snapshot via `45A7`). |

## Bytecode Program Format

A bytecode program is a sequence of opcode bytes embedded inline
after `CALL C772:022D`. The bytes following the CALL are read by
the interpreter, not executed as x86 instructions.

```text
CALL C772:022D     ; yield to interpreter
db 0x38            ; snapshot state (opcode 0x38)
db 0x50, 0x01      ; test [73F7] & 1 (opcode 0x50, param 0x01)
db 0x8E, 0xF8      ; branch if NZ by -8 (opcode 0x8E, offset 0xF8)
db 0x02            ; return (opcode 0x02)
```

- Opcodes `0x00..0x42`: single byte, no parameter
- Opcodes `0x44..0xBE`: two bytes — opcode + parameter in DL
- Opcodes `0xA6`, `0xA8`, `0xAA`, `0xAC`, `0xAE`, `0xB0`, `0xB4`:
  consume additional inline data bytes beyond the parameter

A program ends when a handler doesn't return to the interpreter
loop — typically `0x00` (goto), `0x02` (return), or `0xB2`
(jump to native code).

## VM Registers

| Address | Purpose |
| --- | --- |
| `[7516]` | Accumulator (word). Loaded/stored by most data ops. |
| `[74AC]` | Flags byte (saved LAHF). Tested by conditional branches. |
| `[74B5]` | Last key code. Tested by `0x5E`/`0x60`. |
| `[74E6]` | Key parameter. Used with `0x5E`/`0x60`. |
| `[73F7]` | State block base. 107 bytes of application state. |
| `[742B]` | Pending operation code. |
| `[7415]` | Cursor position (text buffer). |
| `[7434]` | Mark position (for range operations). |
| `[745D]` | Mode flags (bits: 1=mode, 3=alt, 4=special). |
| `[745F]` | Display flags. |
| `[74B2]` | Dispatch flags (bit 0 selects alternate handler). |
| `[74C8]` | Operation mode byte. |
