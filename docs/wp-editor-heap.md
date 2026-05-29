# Word Processor Editor Heap

## Current Read

The word processor uses a private block heap for live document text/state. It
is initialized by the `C688` application startup path and managed by helpers
around `C688:39C7..3C68`.

The heap is separate from the FAT-like Built-in/Card/DreamLink storage layer.
FILE -> RECALL imports a stored document stream into this heap; FILE -> STORE
exports the current editor state back through the file API. See
[`file-system.md`](file-system.md#recall-and-the-working-document) for the
RECALL path.

## Heap Initialization

`C688:29D9` clears low-RAM editor/UI state and calls `C688:294B`, which probes
available RAM and builds a free list:

```asm
C688:29D9  mov  di,77B8
C688:29DC  mov  cx,7F29
C688:29EB  rep  stosb
C688:2A01  call C688:294B
```

`C688:294B` walks the table at `C688:8A17`, write-tests candidate memory, and
links discovered 128-byte blocks. At the end:

```asm
C688:29BB  mov  [79E1],al    ; FF sentinels
C688:29BE  mov  [781B],al
C688:29C1  mov  [7A50],cx    ; free-list head
C688:29C5  add  cx,0080
C688:29C9  mov  [822F],cx
C688:29CD  mov  si,[7A52]    ; total block count
C688:29D1  mov  [7A54],si    ; free block count
```

Observed table bytes begin with candidate high-page values from `0x00` through
`0xD0`, then terminate with `0xFF`. The probe increments `[7A52]` for each
accepted block.

## Block Format And Counters

The allocator works in `0x80` byte blocks. The normal text payload area is
`0x7C` bytes, with link words at the end of the block:

| Offset | Current read |
| ---: | --- |
| `+0x00..+0x7B` | Payload bytes while allocated; next-free pointer while on the free list. |
| `+0x7C` | Link word used by one side of the editor chain. |
| `+0x7E` | Link word used by the other side of the editor chain. |

Important low-RAM fields:

| Address | Current read |
| ---: | --- |
| `[7A50]` | Free-list head. |
| `[7A52]` | Total discovered block count. |
| `[7A54]` | Free block count. |
| `[78E3]` | Allocated/in-use block count for the active editor heap state. |
| `[78E7]`, `[78E9]` | Chain-side block pointers updated by allocator/release helpers. |
| `[78EB]`, `[78ED]` | Current forward/backward block pointers. |
| `[78EF]`, `[78F1]` | Byte offsets within the current forward/backward blocks. |

`C688:39C7` allocates one block from `[7A50]`, links it into the active editor
chain, decrements `[7A54]`, and increments `[78E3]`:

```asm
C688:39C7  mov  dx,[7A50]
...
C688:3A1A  mov  dx,[es:si]   ; next free block
C688:3A1F  mov  [7A50],si
C688:3A23  mov  si,[7A54]
C688:3A27  dec  si
C688:3A28  mov  [7A54],si
C688:3A2C  mov  si,[78E3]
C688:3A30  inc  si
C688:3A31  mov  [78E3],si
```

`C688:3A38` releases/rotates a block back to the free list, increments
`[7A54]`, and decrements `[78E3]`:

```asm
C688:3A42  mov  si,[7A50]
C688:3A48  mov  [es:si],dx
...
C688:3AD5  mov  si,[7A54]
C688:3AD9  inc  si
C688:3ADA  mov  [7A54],si
C688:3ADE  mov  si,[78E3]
C688:3AE2  dec  si
C688:3AE3  mov  [78E3],si
```

## Stream Helpers

The byte-stream helpers wrap these blocks as a forward/backward editable text
structure:

| Helper | Current read |
| --- | --- |
| `C688:3AEB` | Read/advance through the `[78ED]` side; releases/rotates when offset crosses a block boundary. |
| `C688:3B0D` | Read/retreat through the `[78EB]` side; releases/rotates when offset crosses a block boundary. |
| `C688:3B2F` | Append/write a byte to the `[78ED]` side; allocates a new block when `[78F1]` underflows. |
| `C688:3B62` | Append/write a byte to the `[78EB]` side; allocates a new block when `[78EF]` reaches `0x7C`. |
| `C688:3B97` | Copy/move one byte from the `[78ED]` side to the `[78EB]` side, allocating if needed. |
| `C688:3BDE` | Copy/move one byte from the `[78EB]` side to the `[78ED]` side, allocating if needed. |

The editor insertion path eventually funnels through `C688:5B83`/`5B87` and
`C688:5B9A`, which snapshot cursor/state fields and then use the stream
helpers above. This is the path RECALL reaches after `C688:4F63` resets the
editor state.

## Cross-Application Use

Current evidence says this is a WP/editor heap, not a shared Organizer heap:

* Direct near references to the allocator and stream helpers are all inside the
  `C688` segment.
* A whole-ROM far-call scan found no direct far calls to `C688:39C7`,
  `C688:3A38`, `C688:3B2F`, `C688:3B62`, `C688:5B83`, or `C688:5B9A`.
* The only far calls from the `DC98` application/menu bank into `C688` are WP
  menu/file wrappers and ROM CARD setup/cleanup entries, not Organizer
  CALENDAR/SCHEDULER/ADDRESS BOOK handlers.
* Organizer handlers observed so far use file/database wrappers and fixed
  low-RAM/global or stack buffers. For example, SCHEDULER uses handles/state
  around `0x82A8..0x82B0`, local stack buffers, and the `DC98:EE..` file API.

So Calendar/Scheduler/Address Book can reduce Built-in/Card storage free space
through their database files, but they do not currently appear to reduce the
live WP document heap size. The fixed RAM they use is part of the firmware's
overall memory layout, so it may reduce the maximum possible heap configured at
startup, but it is not dynamically allocated from `[7A50]`.

## Useful Watchpoints

For MAME debugging, the most useful state to watch is:

| Address | Why |
| ---: | --- |
| `[7A54]` | Remaining free heap blocks; should drop as a document is imported/edited. |
| `[78E3]` | Allocated block count for the active editor heap state. |
| `[7A50]` | Free-list head; useful for allocator corruption. |
| `[78EB]`/`[78ED]` and `[78EF]`/`[78F1]` | Current chain blocks and byte offsets. |

If another app ever reduces WP document capacity, `[7A54]` should change while
entering that app. The current static call evidence suggests it should not.
