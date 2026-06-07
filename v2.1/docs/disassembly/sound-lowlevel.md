# Low-Level Sound Helpers

This slice resolves the small sound helpers reached by
[`diagnostic-int1.md`](diagnostic-int1.md) and other low-level buzzer paths.

No image assets are reached in this slice.

## Low-RAM ABI Wrapper

`DC98:0DAF` is the low-RAM ABI entry at `[0238]`. It adapts the caller's
`AX/BX` arguments into the near tone helper convention, preserves the broad
caller register set, and calls `C000:087F`.

```asm
tone_duration_wrapper_DC98_0DAF:
; file 0x5D72F
DC98:0DAF  55                push bp
DC98:0DB0  57                push di
DC98:0DB1  56                push si
DC98:0DB2  52                push dx
DC98:0DB3  51                push cx
DC98:0DB4  8B CB             mov  cx,bx
DC98:0DB6  8B D8             mov  bx,ax
DC98:0DB8  9A 7F 08 00 C0    call C000:087F
DC98:0DBD  59                pop  cx
DC98:0DBE  5A                pop  dx
DC98:0DBF  5E                pop  si
DC98:0DC0  5F                pop  di
DC98:0DC1  5D                pop  bp
DC98:0DC2  CB                retf
```

`C000:087F` is only a far-call veneer over `C000:096A`:

```asm
tone_duration_far_C000_087F:
; file 0x4087F
C000:087F  E8 E8 00          call C000:096A
C000:0882  CB                retf
```

## Tone Helper

`C000:096A` is the duration wrapper. If `BX != 0`, it starts a tone with `BX` as
the 16-bit divisor. If `BX == 0`, it turns the tone off for a rest. `CX` is the
duration loop count.

```asm
tone_duration_C000_096A:
; file 0x4096A
C000:096A  50                push ax
C000:096B  53                push bx
C000:096C  51                push cx
C000:096D  0B DB             or   bx,bx
C000:096F  74 05             jz   tone_off_for_rest_C000_0976
C000:0971  E8 28 00          call tone_on_C000_099C
C000:0974  EB 03             jmp  C000:0979
C000:0976  E8 30 00          call tone_off_C000_09A9
...
C000:0989  E8 07 01          call main_battery_low_C000_0A93
C000:098C  F9                stc
C000:098D  75 06             jnz  C000:0995
...
C000:0995  E8 11 00          call tone_off_C000_09A9
C000:0998  59                pop  cx
C000:0999  5B                pop  bx
C000:099A  58                pop  ax
C000:099B  C3                ret
```

The duration loop periodically calls `C000:0A93`, so a main-battery-low result
can cut the tone short.

## Gate Helpers

`C000:099C` and `C000:09A9` are the exact helpers called by the installed
`INT 1` hook.

```asm
tone_on_C000_099C:
; file 0x4099C
C000:099C  8A C3             mov  al,bl
C000:099E  E6 50             out  0x50,al
C000:09A0  8A C7             mov  al,bh
C000:09A2  E6 51             out  0x51,al
C000:09A4  B0 7F             mov  al,0x7f
C000:09A6  E6 52             out  0x52,al
C000:09A8  C3                ret

tone_off_C000_09A9:
; file 0x409A9
C000:09A9  B0 FF             mov  al,0xff
C000:09AB  E6 52             out  0x52,al
C000:09AD  C3                ret
```

Ports `0x50/0x51` latch a 16-bit divisor, `0x52=0x7F` gates output on, and
`0x52=0xFF` gates output off.
