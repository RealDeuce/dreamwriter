# Device IRQ Roots

IRQ handlers for the hardware peripherals: serial (F9/FC/FD), keyboard
scan reset (FA), and Centronics parallel output (FE). The keyboard row
scan IRQ (FB) is in [`keyboard-irq.md`](keyboard-irq.md), the NMI/power
IRQ (F8/FF) are in [`nmi-context.md`](nmi-context.md) and
[`power-irq.md`](power-irq.md).

## IRQ F9 — Timer/Wake Acknowledge

Clears bit 0 of `[1497]`, writes `0x40` to port `0x90` (LCD control).
Single-purpose acknowledge handler.

```asm
; file 0xC05C0
C000:05C0  50                push ax
C000:05C1  1E                push ds
C000:05C2  B8 0000           mov ax,0
C000:05C5  8E D8             mov ds,ax
C000:05C7  B0 40             mov al,40
C000:05C9  E6 90             out 90,al
C000:05CB  80 26 9714 FE     and byte [1497],FE  ; clear bit 0
C000:05D0  1F                pop ds
C000:05D1  58                pop ax
C000:05D2  FB                sti
C000:05D3  CF                iret
```

## IRQ FA — Keyboard Scan Reset/Start

Sets bit 2 in the IRQ mask `[143A]`, writes `0x20` to port `0x90`,
resets the keyboard scan state byte `[132C]`, then calls `C000:1303`
to reinitialize the keyboard scan hardware.

```asm
; file 0xC05D4
C000:05D4  50                push ax
C000:05D5  53                push bx
C000:05D6  1E                push ds
C000:05D7  B8 0000           mov ax,0
C000:05DA  8E D8             mov ds,ax
C000:05DC  80 0E 3A14 04     or byte [143A],04   ; set bit 2 in IRQ mask
C000:05E1  A0 3A14           mov al,[143A]
C000:05E4  E6 60             out 60,al           ; update IRQ mask port
C000:05E6  B0 20             mov al,20
C000:05E8  E6 90             out 90,al           ; LCD control
C000:05EA  C6 06 2C13 00     mov byte [132C],0   ; reset scan state
C000:05EF  E8 110D           call C000:1303       ; keyboard scan init
C000:05F2  1F                pop ds
C000:05F3  5B                pop bx
C000:05F4  58                pop ax
C000:05F5  FB                sti
C000:05F6  CF                iret
```

`C000:1303` is shared with the IRQ mask setup in
[`subsystem-init.md`](subsystem-init.md) at `C000:12CC`.

## IRQ FC — RS-232 Serial Receive

Reads the USART status from port `0xC1`, checks for errors, reads
the data byte from port `0xC0`, and queues it through `C000:3396`.
If `[1491]==1`, skips processing (serial disabled state).

```asm
; file 0xC0676
C000:0676  50                push ax
C000:0677  53                push bx
C000:0678  1E                push ds
C000:0679  51                push cx
C000:067A  52                push dx
C000:067B  B8 0000           mov ax,0
C000:067E  8E D8             mov ds,ax
C000:0680  B0 08             mov al,08
C000:0682  E6 90             out 90,al           ; LCD control
C000:0684  80 3E 9114 01     cmp byte [1491],1   ; serial disabled?
C000:0689  74 24             jz C000:06AF        ; yes -> skip
C000:068B  52                push dx
C000:068C  BA C100           mov dx,C1           ; USART status port
C000:068F  EC                in al,dx
C000:0690  5A                pop dx
```

Continues with error checking, data read from port `0xC0`, and
call to `C000:06EF` (serial byte handler) and `C000:3396` (queue
processor). Full handler extends to `C000:0763` with multiple
branches for error conditions and flow control.

## IRQ FD — Serial Transmit Acknowledge

Clears bit 3 of `[1693]` (transmit-ready flag). Single-purpose
acknowledge handler.

```asm
; file 0xC084A
C000:084A  50                push ax
C000:084B  1E                push ds
C000:084C  B8 0000           mov ax,0
C000:084F  8E D8             mov ds,ax
C000:0851  B0 04             mov al,04
C000:0853  E6 90             out 90,al           ; LCD control
C000:0855  80 26 9316 F7     and byte [1693],F7  ; clear bit 3
C000:085A  1F                pop ds
C000:085B  58                pop ax
C000:085C  FB                sti
C000:085D  CF                iret
```

## IRQ FE — Centronics Parallel Output

Reads the next byte from a buffer pointed to by `[1480]`. If the
byte is nonzero, outputs it to the Centronics port. If `[1492]!=1`
(output not active), skips.

```asm
; file 0xC085E
C000:085E  50                push ax
C000:085F  53                push bx
C000:0860  1E                push ds
C000:0861  B8 0000           mov ax,0
C000:0864  8E D8             mov ds,ax
C000:0866  B0 02             mov al,02
C000:0868  E6 90             out 90,al           ; LCD control
C000:086A  80 3E 9214 01     cmp byte [1492],1   ; output active?
C000:086F  75 0F             jnz C000:0880       ; no -> done
C000:0871  8B 1E 8014        mov bx,[1480]       ; buffer pointer
C000:0875  8A 07             mov al,[bx]         ; next byte
C000:0877  43                inc bx
C000:0878  89 1E 8014        mov [1480],bx       ; advance pointer
C000:087C  3C 00             cmp al,0            ; end of buffer?
C000:087E  75 0F             jnz C000:088F       ; no -> output byte
C000:0880  80 0E 3A14 40     or byte [143A],40   ; set bit 6 in IRQ mask
C000:0885  A0 3A14           mov al,[143A]
C000:0888  E6 60             out 60,al           ; update IRQ mask
C000:088A  1F                pop ds
C000:088B  5B                pop bx
C000:088C  58                pop ax
C000:088D  FB                sti
C000:088E  CF                iret
```

At `C000:088F`, the byte output path writes to the Centronics data
port and triggers the strobe via port `0x30` bit 5 (the same
click-pulse pattern used for the buzzer in
[`sound-lowlevel.md`](sound-lowlevel.md)):

```asm
; file 0xC088F
C000:088F  E6 40             out 40,al           ; serial/parallel data port
C000:0891  A0 8214           mov al,[1482]       ; port 30 shadow
C000:0894  0C 20             or al,20            ; set bit 5 (strobe)
C000:0896  E6 30             out 30,al
C000:0898  90                nop                  ; timing
C000:0899  90                nop
C000:089A  90                nop
C000:089B  90                nop
C000:089C  24 DF             and al,DF           ; clear bit 5
C000:089E  E6 30             out 30,al
C000:08A0  EB E8             jmp short C000:088A ; -> update mask, IRET
```

## State Variables

| Address | IRQ | Purpose |
| --- | --- | --- |
| `[1491]` | FC | Serial receive disabled flag (`1` = disabled) |
| `[1492]` | FE | Centronics output active flag (`1` = active) |
| `[1480]` | FE | Centronics output buffer pointer |
| `[1497]` | F9 | Bit 0 cleared by timer acknowledge |
| `[1693]` | FD | Bit 3 cleared by transmit acknowledge |
| `[132C]` | FA | Keyboard scan state, reset by scan-cycle IRQ |
