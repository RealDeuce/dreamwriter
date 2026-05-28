# Menu Dispatch

This page tracks the application-level menu/event dispatch code reached after the
startup resource has drawn the first two-button screen.

## Inline Key Dispatch Primitive

`C688:92DF` / file `0x4FB5F` is a reusable inline key dispatch trampoline:

```asm
C688:92DF  call C688:EE8C
C688:92E2  mov  bp,sp
C688:92E4  xchg [bp+0],si
C688:92E7  push dx
C688:92E8  mov  dl,al
C688:92EA  mov  al,[cs:si]
C688:92ED  inc  si
C688:92EE  cmp  al,00
C688:92F0  jz   C688:9301
C688:92F2  cmp  al,FF
C688:92F4  jz   C688:92FE
C688:92F6  cmp  al,dl
C688:92F8  jz   C688:92FE
C688:92FA  inc  si
C688:92FB  inc  si
C688:92FC  jmp  C688:92EA
C688:92FE  mov  si,[cs:si]
C688:9301  pop  dx
C688:9302  mov  bp,sp
C688:9304  xchg [bp+0],si
C688:9307  mov  al,[794A]
C688:930A  ret
```

`C688:92DF` first calls `C688:EE8C`; `C688:92E2` is the same dispatcher body
without that pre-call. Callers embed byte/word entries immediately after the
call:

```text
key-byte target-word-le
...
00              ; terminator, continue after the 00 byte
FF target       ; default target
```

The routine rewrites the caller's return address so the `ret` lands at the
selected target.

## First Two-Button Screen

The first-screen post-input code reaches `C688:928D`, which calls `C688:92DF`
and embeds this table:

```text
13 -> C688:92C0
12 -> C688:92CC
DA -> C688:92CC
0B -> C688:92A7
03 -> C688:92A7
00 -> end
```

`C688:92A0` is an indirect jump through the current word pointer in `[75EF]`.
`C688:92C0` and `C688:92CC` move `[75EF]` backward or forward by one word-table
entry, wrapping at the zero terminator. This is the first confirmed cursor/list
navigation primitive.

## Shared Menu Event Loop

`C688:EC9F` / file `0x5551F` is the shared application menu/event loop reached
after the first-screen branch setup:

```asm
C688:EC9F  call C688:77DD
C688:ECA2  mov  al,FF
C688:ECA4  mov  [75E4],al
C688:ECA7  call C688:7795
C688:ECAA  call C688:F13A
C688:ECAD  call C688:8F40
C688:ECB0  call C688:12D6
C688:ECB3  mov  [794A],al
C688:ECB6  call C688:44C4
C688:ECB9  mov  al,[794A]
C688:ECBC  cmp  al,FF
C688:ECBE  jnz  C688:ECC3
C688:ECC0  jmp  C688:ED84
C688:ECC3  call C688:92DF
```

The inline table after `C688:ECC3` starts at file `0x55546` / `C688:ECC6`:

```text
01 -> C688:ECA7
02 -> C688:EF4F
E8 -> C688:EF59
0B -> C688:ECF6
0A -> C688:8319
1D -> C688:8CFB
1B -> C688:8D23
1C -> C688:8D0F
F6 -> C688:ED1F
EA -> C688:ED15
D2 -> C688:AD5C
F7 -> C688:D8AF
F5 -> C688:ED1A
F8 -> C688:E274
03 -> C688:ECF6
FF -> C688:EB15
```

The working key/event values are not fully named yet. The table does show that
the first menu loop is no longer a black box: ordinary events go through a fixed
dispatch table, while `0xFF` no-event/idle goes to `C688:ED84`.

## Handler Anchors

Some targets are already useful anchors:

| Target | File offset | Current read |
| --- | ---: | --- |
| `C688:EB15` | `0x55395` | Default handler. Calls `C688:77AA`, clears `[7520]`, far-calls `DC98:2807`, then loops or jumps through `C688:EF45`. |
| `C688:ECF6` | `0x55576` | Handles `0x0B` and `0x03`. Toggles/tests `[8E3F]`, otherwise calls `C688:622B`, `C688:0B11`, `C688:44C4`, and `C688:77A3`. |
| `C688:ED84` | `0x55604` | Idle/no-event state dispatch keyed by `[79A6]` through `C688:92E2`. |
| `C688:EF4F` | `0x557CF` | Far-calls `DC98:53C3`, then returns to `C688:EC9F`. |
| `C688:EF59` | `0x557D9` | Far-calls `DC98:4D08`; if the result is not `FFFF`, stores `AL` to `[7884]`. |
| `C688:AD5C` | `0x515DC` | Opens `H:ADDRESS.ODB`, reads records, and prints/steps through address-book data. Strong organizer/address-book anchor. |
| `C688:D8AF` | `0x5412F` | Large file/document-style flow with nested `C688:92DF` table. |
| `C688:E274` | `0x54AF4` | Similar large file/document-style flow with nested `C688:92DF` table. |

`C688:ED84` embeds another table after `C688:ED87 call C688:92E2`, keyed by
`[79A6]`:

```text
60 -> C688:ED9C
62 -> C688:EDE8
66 -> C688:EE34
6C -> C688:EE2F
64 -> C688:EDBC
FF -> C688:EDE8
```

## Local Selection Prompts

`C688:8D0F` and `C688:8D23` set `[757D]` to their own address, call
`C688:7689` with resource IDs `0x38` plus `0x19` or `0x37`, populate a 16-byte
buffer at `0x7A30`, and then enter a small inline dispatch:

```text
DA -> C688:8D86
03 -> C688:EC9F
FF -> [757D]
```

`C688:8D86` is a related branch using a second 16-byte buffer at `0x7A1F`:

```text
1D -> C688:8DBF
DA -> C688:8DC4
03 -> C688:EC9F
FF -> C688:8D8E
```

The exact menu meaning is still unnamed, but this is clearly part of the
horizontal menu/list selection machinery: it sets state flags in `[7520]`, calls
`C688:8F40`, updates UI state through `C688:44C4`, and returns to the shared
`C688:EC9F` loop.

## Screen Resource Selector

`C688:7689` is the setup wrapper used by the first confirmed ORGN branch:

```asm
C688:83EC  mov  si,0053
C688:83EF  call C688:7689
```

Inside `C688:7689`, `SI` survives as a screen/resource ID. The wrapper clears
`[799C]`, calls `C688:9541`, then updates state through `C688:2CFA`,
`C688:44C4`, and `C688:7795`.

`C688:9541` / file `0x4FDC1` is now the best concrete name for the screen
resource loader reached from menu code. It:

```text
1. Applies the display/profile byte through C688:4473.
2. Copies a template from C688:8C9C into low RAM at 0x78E3.
3. Calls C688:76BF with the caller's SI value to load a resource into 0x7F28.
4. Parses a small header into 0x78D5, 0x78DB/0x78DF, and 0x78DD/0x78E1.
5. Interprets the remaining resource bytes, emitting characters via C688:5B83
   and inline display script bytes through C688:0240.
```

`C688:76BF` has two modes:

```text
SI high byte == 0: treat SI low byte as a resource ID and call C688:936A
                  with AH=01, DL=resource ID, destination 0x7F28.
SI high byte != 0: treat SI as a CS pointer to a length-prefixed resource block
                   and copy that block to 0x7F28.
```

That means `SI=0x53` in the ORGN path is not an arbitrary state value; it is a
resource ID loaded through the same screen-resource path as other menu screens.
The next unresolved part is the resource ID to table/label binding for the
horizontal icon menus.

## Resource Lookup Service

When `C688:76BF` is called with an 8-bit resource ID in `SI`, it calls
`C688:936A`, a far wrapper for `C000:1712`. With `AH=01`, the service dispatches
through `C000:1873` to `C000:18EE`.

`C000:18EE` uses segment `D59C` / file base `0x559C0` as a resource table:

```asm
C000:18F3  mov bx,[75ED]       ; stream offset inside resource
C000:18F9  mov si,D59C
C000:18FD  mov ds,si
C000:1901  add dx,dx           ; DL resource ID -> word index
C000:1903  mov si,0004
C000:1906  add si,dx
C000:1908  mov si,[si]         ; resource offset in D59C segment
C000:190A  mov dx,[si]         ; resource length/limit
C000:190C  add si,0002         ; payload start
C000:190F  add si,bx           ; support chunked reads
C000:191A  cmp cx,ax
C000:1928  rep movsb           ; copy to caller buffer
```

Resource table entry `n` is the word at file `0x559C4 + n * 2`. The copied
payload begins at `0x559C0 + entry + 2`.

Examples from the first menu branch:

| Resource ID | Table word | Payload file offset | Notes |
| ---: | ---: | ---: | --- |
| `0x53` | `0x1574` | `0x56F36` | ORGN branch setup resource; starts with centered `*** W A I T ***`. |
| `0x5B` | `0x1748` | `0x5710A` | Word-processor-side setup resource; printer/paper setup text follows in the same resource area. |

This establishes the source of resources loaded by `C688:7689`/`C688:9541`.
The 40x40 horizontal-menu icon sources are documented in `bitmaps.md`.
