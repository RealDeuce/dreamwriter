# Diagnostic INT 1 Hook

`install_vectors_C000_0ED6` installs `INT 1` at `C000:157D`. This appears to be
a diagnostic/single-step hook controlled by low-RAM state at `6EBC..6EC0`.

No image assets are reached in this slice.

## Install Site

```asm
; file 0x40F70
C000:0F70  B8 7D 15          mov  ax,0x157d
C000:0F73  BF 04 00          mov  di,0x0004       ; IVT vector 01h
C000:0F76  AB                stosw
C000:0F77  B8 00 C0          mov  ax,0xc000
C000:0F7A  AB                stosw
```

## Hook Body

The interrupt frame is addressed through `BP` after saving `DS`, `BP`, and
`BX`. With that layout, `[bp+6]` is the saved IP, `[bp+8]` is saved CS, and
`[bp+0x0A]` is saved FLAGS.

```asm
diagnostic_int1_C000_157D:
; file 0x4157D
C000:157D  1E                push ds
C000:157E  55                push bp
C000:157F  53                push bx
C000:1580  8B EC             mov  bp,sp
C000:1582  BB 00 00          mov  bx,0
C000:1585  8E DB             mov  ds,bx
C000:1587  F6 06 C0 6E 80    test byte [0x6ec0],0x80
C000:158C  75 3D             jnz  int1_active_C000_15CB
C000:158E  8B 1E BC 6E       mov  bx,[0x6ebc]
C000:1592  3B 5E 06          cmp  bx,[bp+0x06]    ; saved IP
C000:1595  75 30             jnz  int1_return_C000_15C7
C000:1597  8B 1E BE 6E       mov  bx,[0x6ebe]
C000:159B  3B 5E 08          cmp  bx,[bp+0x08]    ; saved CS
C000:159E  75 27             jnz  int1_return_C000_15C7
C000:15A0  80 3E C0 6E 01    cmp  byte [0x6ec0],0x01
C000:15A5  75 07             jnz  int1_chain_f8_C000_15AE
C000:15A7  80 0E C0 6E 80    or   byte [0x6ec0],0x80
C000:15AC  EB 1D             jmp  int1_active_C000_15CB
```

When the saved CS:IP matches `[6EBE]:[6EBC]`, state byte `[6EC0]` determines the
action. State `1` sets bit `0x80` and enters the active path. Other matching
states clear the trap flag in the saved FLAGS word and jump through IVT vector
`F8h`.

```asm
int1_chain_f8_C000_15AE:
C000:15AE  81 66 0A FF FE    and  word [bp+0x0a],0xfeff ; clear TF
C000:15B3  50                push ax
C000:15B4  BB 28 00          mov  bx,0x0028
C000:15B7  E8 E2 F3          call C000:099C
C000:15BA  58                pop  ax
C000:15BB  5B                pop  bx
C000:15BC  5D                pop  bp
C000:15BD  1F                pop  ds
C000:15BE  FF 2E E0 03       jmp  far [0x03e0]    ; chain to installed F8h

int1_clear_tf_C000_15C2:
C000:15C2  81 66 0A FF FE    and  word [bp+0x0a],0xfeff

int1_return_C000_15C7:
C000:15C7  5B                pop  bx
C000:15C8  5D                pop  bp
C000:15C9  1F                pop  ds
C000:15CA  CF                iret
```

The active path increments `[6EC0]`, optionally clears trap flag on wrap, calls
two sound/delay helpers, and returns through the common `iret` path.

```asm
int1_active_C000_15CB:
C000:15CB  FE 06 C0 6E       inc  byte [0x6ec0]
C000:15CF  74 F1             jz   int1_clear_tf_C000_15C2
C000:15D1  50                push ax
C000:15D2  BB 28 00          mov  bx,0x0028
C000:15D5  E8 C4 F3          call C000:099C
C000:15D8  B8 88 13          mov  ax,0x1388
C000:15DB  48                dec  ax
C000:15DC  75 FD             jnz  C000:15DB
C000:15DE  E8 C8 F3          call C000:09A9
C000:15E1  BB 80 00          mov  bx,0x0080
C000:15E4  B8 B0 04          mov  ax,0x04b0
C000:15E7  48                dec  ax
C000:15E8  75 FD             jnz  C000:15E7
C000:15EA  4B                dec  bx
C000:15EB  75 F7             jnz  C000:15E4
C000:15ED  58                pop  ax
C000:15EE  EB D7             jmp  int1_return_C000_15C7
```

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6EBC` | Watched saved IP for the `INT 1` hook. |
| `6EBE` | Watched saved CS for the `INT 1` hook. |
| `6EC0` | Hook state byte; bit `0x80` forces the active path. |
| IVT `[03E0]` | Installed `F8h` vector, used as a far-chain target. |

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:099C`, `C000:09A9` | [`sound-lowlevel.md`](sound-lowlevel.md) | Tone gate helpers used by this hook and other buzzer paths. |
| `C000:1240`, `C000:128F` | `diagnostics-ui.md` | Main diagnostic chord gate and command UI. |
