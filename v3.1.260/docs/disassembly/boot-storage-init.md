# Boot Storage Init

Repair-oriented notes for the 3.1.260 cold-start path, using
`t4_ir_3.1_8c8f.ic303`.

## Observed Cold-Start Sequence

The reset vector jumps to `F733:0000`, which sets the high ROM windows and
enters the boot code at `C000:0000` / `C000:0029`.

On a cold start or warm-signature mismatch, the path reaches `C000:0096`:

```asm
C000:0096  E8 5109           call C000:09EA      ; low+high power-on tones
C000:0099  E8 8B02           call C000:0327      ; seed bank-port mirrors
C000:00B7  E8 0103           call C000:03BB      ; clear RAM
C000:00BA  E8 6F64           call C000:652C      ; drive/display init
C000:00BD  E8 6702           call C000:0327
C000:00C0  C6 06 0510 48     mov byte [1005],48
C000:00C5  B3 A5             mov bl,A5
C000:00C7  B2 08             mov dl,08
C000:00C9  B4 FF             mov ah,FF
C000:00CB  E8 D142           call C000:439F      ; built-in store validate/format
C000:00CE  E8 A004           call C000:0571      ; store checksum init
C000:00D1  E8 AF2D           call C000:2E83      ; subsystem init chain
C000:00D4  9A F858 80DF      call far DF80:58F8 ; service/app cold init
```

The two-tone beep therefore confirms execution through `C000:09EA` and entry
into the cold-start path.

## Built-In Store Format Counter

For the boot call `BL=A5`, `DL=08`, `AH=FF`, `C000:439F` selects the built-in
store at segment `0x1800` and formats/tests the built-in storage area.

```asm
C000:43F5  C7 06 4F6F 0018   mov word [6F4F],1800 ; built-in store base
C000:43FB  BB 0500           mov bx,5
C000:43FE  E8 B311           call C000:55B4       ; init [160F] = BX * 0x20
C000:4407  33 C0             xor ax,ax
C000:4409  A3 006F           mov [6F00],ax         ; unit index
C000:440C  E8 5000           call C000:445F       ; RAM test/fill one unit
C000:4411  FF 06 006F        inc word [6F00]
C000:4415  E8 B311           call C000:55CB       ; display progress
C000:441D  BB 2800           mov bx,28h           ; 40 units
C000:4426  A1 006F           mov ax,[6F00]
C000:4429  3B C3             cmp ax,bx
C000:442B  72 DF             jc C000:440C
```

`C000:55CB` converts the unit count to KiB-like progress by multiplying
`[6F00]` by four, then renders it through the small display-script builder:

```asm
C000:55CB  8B 1E 006F        mov bx,[6F00]
C000:55CF  B8 0400           mov ax,4
C000:55D2  F7 E3             mul bx
C000:55D4  A3 0F16           mov [160F],ax
C000:55D7  C6 06 1116 0C     mov byte [1611],0Ch
C000:55DC  C6 06 1216 2E     mov byte [1612],2Eh
C000:55E2  E8 D1D2           call C000:28B6
```

The display helper at `C000:28B6` builds an 11-byte script at `[15B1]`:

```asm
C000:28B6  BF B115           mov di,15B1
C000:28B9  E8 2E00           call C000:28EA       ; FF 02 position command
C000:28BC  A1 0F16           mov ax,[160F]        ; progress value
C000:28C2  E8 0D00           call C000:28D2       ; decimal conversion
C000:28C5  B9 0B00           mov cx,0Bh
C000:28C8  BE B115           mov si,15B1
C000:28CD  E8 903C           call C000:6560       ; render script
```

For this formatter progress path, the ROM emits only this one display script
per progress update. The intended text cursor is `X=0x000C`; `C000:28EA`
stores `Y=[1612] * 6`, so the formatter's `[1612]=0x2E` becomes `Y=0x0114`.
There is a similar storage status helper that uses `[1612]=0x1C`, but the
`0..160` built-in-store format loop reaches the `0x2E` path via `C000:55CB`.

Because the formatter loops `[6F00]` from `0` through `0x28`, and the display
value is `[6F00] * 4`, the visible progress is expected to run:

```text
0, 4, 8, ..., 160
```

This exactly matches the observed `0` to `160` count. It also indicates that
the CPU, ROM, framebuffer renderer, enough low RAM, and the built-in storage
window are all alive far enough to complete the cold storage format/test loop.

## Post-Counter Path

After the counter reaches 160, the formatter writes initial metadata via
`C000:44F2` and `C000:4522`, returns through the storage dispatcher, initializes
the checksum with `C000:0571`, then runs the low-level subsystem chain at
`C000:2E83`.

The 3.1.260 cold service init is `DF80:58F8`:

```asm
DF80:58F8  9A 906F 80DF      call far DF80:6F90   ; utility init
DF80:58FD  E8 AF63           call DF80:BCAF       ; display subsystem init
DF80:5900  E8 D31E           call DF80:77D6       ; keyboard/input init
DF80:5903  E8 6645           call DF80:9E6C       ; file handle init
DF80:5906  E8 427D           call DF80:D64B       ; app state init
DF80:5909  C6 06 AAA7 4F     mov byte [A7AA],4F
DF80:590E  C6 06 ABA7 39     mov byte [A7AB],39
DF80:5913  C6 06 ACA7 32     mov byte [A7AC],32
DF80:5918  C7 06 00A0 0000   mov word [A000],0
DF80:591E  CB                retf
```

These init calls do not intentionally draw a 30-bar test pattern. If a device
shows 30 evenly spaced 4-pixel vertical bars immediately after the `0..160`
progress completes, the ROM has likely moved past the built-in store formatter
and into service/application startup. The bar screen is therefore more likely
to be a framebuffer/bus artifact or a later application draw going wrong than
the formatter's normal output.
