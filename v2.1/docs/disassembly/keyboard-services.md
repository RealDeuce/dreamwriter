# Keyboard And Event Services

This slice follows the keyboard/event services reached from both
[`keyboard-irq.md`](keyboard-irq.md) and [`int21-dispatch.md`](int21-dispatch.md).
The IRQ side ends at the row processor `C000:5645`; `INT 21h AH=08` and
`AH=0B` consume the same event queue through `C000:4A8D` and `C000:4977`.

No image assets are reached in this slice.

## Nonblocking Status

`INT 21h AH=0B` reaches `C000:515C`, which calls `C000:4977`. The helper first
checks the retained-power request latch through `C000:4961`, then tests the
event queue. A queued event returns `AL=FF`; otherwise it may idle through the
same low-power foreground path used by blocking reads.

```asm
; reached from C000:515C
keyboard_status_C000_4977:
; file 0x44977
C000:4977  E8 E7 FF          call retained_request_C000_4961
C000:497A  72 ...            jc   status_has_event_or_power
...
C000:498E  E8 BF C1          call timer_disarm_C000_0B50
...
C000:49A6  E8 DB 00          call idle_halt_C000_4A84
```

The retained-power latch helper is intentionally documented with
[`idle-power.md`](idle-power.md), because it consumes the `[6809]=1992` marker
set by the `F8h` power IRQ.

## Blocking Read

`INT 21h AH=08` reaches `C000:5155`, which calls `C000:4A8D`. This is the main
foreground key/event wait loop. It dequeues raw event words, refreshes the
auto-off counter from `[6D31]` into `[680B]`, services battery-warning display
state, and translates the event through `C000:5915` before returning to the DOS
style dispatcher.

```asm
; reached from C000:5155
keyboard_read_C000_4A8D:
; file 0x44A8D
C000:4A8D  E8 D1 FE          call retained_request_C000_4961
C000:4A90  72 ...            jc   retained_power_path
...
C000:4AA6  A3 0B 68          mov  [0x680b],ax
...
C000:4AE3  FA                cli
...
C000:4B1A  C3                ret
```

The service can return `AL=EB` for the special `[70E7]` path observed in the
wait loop. Ordinary translated keys return with carry clear through the
dispatcher's common `iret` wrapper.

## Event Queue

The event queue is a ring controlled by `[70E2]`, `[70E3]`, and status bit
`[70A5] bit 0`. `C000:4B2D` dequeues a word and clears the empty flag when the
read catches up to the write pointer. `C000:4B5C` inserts a new event word for
the foreground services.

```asm
event_dequeue_C000_4B2D:
; file 0x44B2D
C000:4B2D  ...               ; compare queue read/write indexes
C000:4B3E  ...               ; read event word from queue storage
C000:4B4E  80 26 A5 70 FE    and  byte [0x70a5],0xfe
C000:4B5B  C3                ret

event_enqueue_C000_4B5C:
; file 0x44B5C
C000:4B5C  ...               ; store event word and advance write index
C000:4B84  88 0E E3 70       mov  [0x70e3],cl
C000:4B88  89 97 A6 70       mov  [bx+0x70a6],dx
C000:4B8C  C3                ret
```

## Row Processor

`C000:5645` runs after the `FBh` row-scan ISR has filled `6D06..6D0F`. It
compares the raw ten-row matrix against the first-stage debounce rows at
`6D10..6D19` and the stable rows at `6D1A..6D23`. Transitions update the active
key count `[6EAE]`, sticky/modifier bytes `6D25..6D27`, and repeat state.

```asm
keyboard_row_processor_C000_5645:
; file 0x45645
C000:5645  ...               ; compare raw rows 6D06..6D0F to debounce state
...
C000:584D  ...               ; repeat countdown and requeue
C000:5870  ...               ; build event word for event_enqueue_C000_4B5C
C000:58A6  ...               ; snapshot modifier state into DH
C000:5915  ...               ; translate raw event to returned key code
```

The repeat path reloads `[6EB3]` to `8` after queueing a repeat event and sets
`[70E8]=1`. Modifier snapshot `C000:58A6` accounts for shift, caps, control,
alt, and sticky state; it clears bit `0x10` when `[6811] != 0`.

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6D06..6D0F` | Raw keyboard matrix rows from IRQ `FBh`. |
| `6D10..6D19` | First-stage debounce row cache. |
| `6D1A..6D23` | Stable debounced row cache. |
| `6D25..6D27` | Modifier/sticky-key state. |
| `6EAE` | Active key count. |
| `6EB0`, `6EB2`, `6EB3` | Repeat row/bit and countdown state. |
| `70E2`, `70E3` | Event queue read/write pointers. |
| `70A5 bit 0` | Event queue status bit used by enqueue/dequeue. |

The translation tables are expanded in
[`keyboard-translation.md`](keyboard-translation.md). Foreground idle and
retained resume paths are expanded in [`idle-power.md`](idle-power.md).
