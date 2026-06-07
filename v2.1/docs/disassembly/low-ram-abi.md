# Low-RAM ABI Table

`install_vectors_C000_0ED6` copies the far-pointer table at `C000:0F94..1037`
to `0000:0200`. This slice decodes that installed table. It is not IVT data and
it is not code at the copy destination; callers use the copied entries as far
service pointers.

No image assets are reached in this slice. Several targets are display or icon
rendering helpers; image assets are shown in the UI/menu slices where those
helpers consume concrete bitmap resources.

## Copy Site

```asm
; file 0x40F7B
C000:0F7B  1E                push ds
C000:0F7C  BF 00 02          mov  di,0x0200
C000:0F7F  8C D8             mov  ax,ds
C000:0F81  8E C0             mov  es,ax
C000:0F83  BE 94 0F          mov  si,0x0f94
C000:0F86  B8 00 C0          mov  ax,0xc000
C000:0F89  8E D8             mov  ds,ax
C000:0F8B  B9 52 00          mov  cx,0x0052       ; 164 bytes
C000:0F8E  90                nop
C000:0F8F  F3 A5             rep  movsw
C000:0F91  1F                pop  ds
C000:0F92  07                pop  es
C000:0F93  C3                ret
```

The copied size is `0xA4` bytes, or 41 far pointers.

## Pointer Decode

| RAM vector | Startup target | Current read |
| ---: | --- | --- |
| `[0200]` | `C000:67AD` | Display/resource stream consumer. |
| `[0204]` | `DC98:0E81` | Text/display wrapper; 325 BASIC `F200:0004` analogue. |
| `[0208]` | `DC98:0EE5` | Display/blit wrapper; 325 BASIC `F200:0008` analogue. |
| `[020C]` | `DC98:124C` | Horizontal icon menu renderer. |
| `[0210]` | `DC98:1555` | Wrapped text block renderer. |
| `[0214]` | `DC98:18EA` | Editable text input widget. |
| `[0218]` | `DC98:1BB7` | Grid-oriented editable text widget. |
| `[021C]` | `DC98:214E` | Styled prompt/selection widget. |
| `[0220]` | `DC98:0E70` | Display helper around `C000:67AD`; 325 BASIC `F200:0020` analogue. |
| `[0224]` | `DC98:1077` | Numeric-to-decimal string formatter; 325 BASIC `F200:0024` analogue. |
| `[0228]` | `DC98:10D4` | Leading-zero cleanup for formatted numeric strings; 325 BASIC `F200:0028` analogue. |
| `[022C]` | `DC98:1859` | Input-widget idle callback setter. |
| `[0230]` | `DC98:0CF9` | Blocking key read wrapper around `INT 21h AH=08`; 325 BASIC `F200:0030` analogue. |
| `[0234]` | `DC98:0D19` | Input/idle wrapper used by menu waits. |
| `[0238]` | `DC98:0DAF` | Tone-duration wrapper around `C000:096A`. |
| `[023C]` | `C000:67BF` | Poll/idle wrapper around `C000:49FD`; used by 325 BASIC runtime analogue before blocking key read. |
| `[0240]` | `DC98:E8D5` | File open/create convenience wrapper; 325 BASIC `F200:0040` analogue. |
| `[0244]` | `DC98:E946` | File open/create implementation helper; 325 BASIC `F200:0044` analogue. |
| `[0248]` | `DC98:EE08` | File read wrapper around `INT 21h AH=3F`; 325 BASIC `F200:0048` analogue. |
| `[024C]` | `DC98:EA54` | Higher-level file read/write helper; 325 BASIC `F200:004C` analogue. |
| `[0250]` | `DC98:EE2E` | File close wrapper around `INT 21h AH=3E`; 325 BASIC `F200:0050` analogue. |
| `[0254]` | `DC98:EE40` | File delete wrapper around `INT 21h AH=41`. |
| `[0258]` | `DC98:EE40` | Duplicate delete wrapper; 325 BASIC `F200:0058` analogue. |
| `[025C]` | `DC98:EE56` | File rename wrapper around `INT 21h AH=56`; 325 BASIC `F200:005C` analogue. |
| `[0260]` | `DC98:EE72` | File seek wrapper around `INT 21h AH=42`. |
| `[0264]` | `DC98:EE8A` | Current-position wrapper around `INT 21h AX=4201`. |
| `[0268]` | `DC98:EA98` | Current-position-vs-EOF helper; 325 BASIC `F200:0068` analogue. |
| `[026C]` | `DC98:EB1D` | Higher-level file helper in the `EA54..ED12` helper cluster. |
| `[0270]` | `DC98:EC2A` | File-length helper preserving current position. |
| `[0274]` | `DC98:EEA6` | File attribute get/set wrapper. |
| `[0278]` | `DC98:EC86` | Caller-record fill helper from file/find metadata. |
| `[027C]` | `DC98:ED12` | Caller-record fill helper from file/find metadata. |
| `[0280]` | `DC98:EFD6` | Get free space wrapper around `INT 21h AH=36`; 325 BASIC `F200:0080` analogue. |
| `[0284]` | `DC98:EF7B` | Find-first wrapper; sets DTA, then `INT 21h AH=4E`. |
| `[0288]` | `DC98:EF9A` | Find-next wrapper; sets DTA, then `INT 21h AH=4F`. |
| `[028C]` | `DC98:F000` | File attribute wrapper. |
| `[0290]` | `DC98:F018` | File date/time wrapper. |
| `[0294]` | `DC98:F03A` | File attribute wrapper. |
| `[0298]` | `DC98:F052` | Set file date/time wrapper around `INT 21h AX=5701`; 325 BASIC `F200:009C` analogue. |
| `[029C]` | `DC98:52E5` | Document picker/list UI. |
| `[02A0]` | `DC98:2887` | Tiny application/menu stub: `xor ax,ax; retf`, immediately before `DC98:288A`. |

## Raw Table

```text
file 0x40F94 / C000:0F94
67AD C000  0E81 DC98  0EE5 DC98  124C DC98
1555 DC98  18EA DC98  1BB7 DC98  214E DC98
0E70 DC98  1077 DC98  10D4 DC98  1859 DC98
0CF9 DC98  0D19 DC98  0DAF DC98  67BF C000
E8D5 DC98  E946 DC98  EE08 DC98  EA54 DC98
EE2E DC98  EE40 DC98  EE40 DC98  EE56 DC98
EE72 DC98  EE8A DC98  EA98 DC98  EB1D DC98
EC2A DC98  EEA6 DC98  EC86 DC98  ED12 DC98
EFD6 DC98  EF7B DC98  EF9A DC98  F000 DC98
F018 DC98  F03A DC98  F052 DC98  52E5 DC98
2887 DC98
```

## Compatibility Note

The DreamWriter 325 BASIC page used `F200:xxxx` trampoline calls. The T400 does
not keep that page, but this low-RAM table preserves much of the underlying ABI:
for example, 325 `F200:0030` corresponds to T400 `[0230] -> DC98:0CF9`, the
blocking key-read wrapper.

That is a compatibility inference from the copied table and the known 325 call
sites. Native T400 code more often calls these `DC98` helpers directly or uses
the DOS-like `INT 21h` wrappers.

## Next Splits

No remaining service-level low-RAM ABI splits are queued from this table under
the current boundary. The horizontal icon-menu service at `[020C]` is expanded
in [`horizontal-icon-renderer.md`](horizontal-icon-renderer.md).
