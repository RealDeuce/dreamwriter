; Generated from disasm: C000:4977-5915
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x4977


; reached from C000:515C
keyboard_status_C000_4977:
; file 0x44977
    call retained_request_C000_4961
    ...            jc   status_has_event_or_power
...
    call timer_disarm_C000_0B50
...
    call idle_halt_C000_4A84
; reached from C000:5155
keyboard_read_C000_4A8D:
; file 0x44A8D
    call retained_request_C000_4961
    ...            jc   retained_power_path
...
    mov  [0x680b],ax
...
    cli
...
    ret
event_dequeue_C000_4B2D:
; file 0x44B2D
C000:4B2D  ...               ; compare queue read/write indexes
C000:4B3E  ...               ; read event word from queue storage
    and  byte [0x70a5],0xfe
    ret

event_enqueue_C000_4B5C:
; file 0x44B5C
C000:4B5C  ...               ; store event word and advance write index
    mov  [0x70e3],cl
    mov  [bx+0x70a6],dx
    ret
keyboard_row_processor_C000_5645:
; file 0x45645
C000:5645  ...               ; compare raw rows 6D06..6D0F to debounce state
...
C000:584D  ...               ; repeat countdown and requeue
C000:5870  ...               ; build event word for event_enqueue_C000_4B5C
C000:58A6  ...               ; snapshot modifier state into DH
C000:5915  ...               ; translate raw event to returned key code
