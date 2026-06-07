# INT 21h Endpoint And IOCTL Helpers

This slice follows the private endpoint/status helpers reached by
`INT 21h AH=44`, especially `AX=4428` and `AX=4429`.

No image assets are reached in this slice.

## Endpoint Probe AX=4428

`C000:3064` probes the three copy/file endpoints and returns an availability
bitmask in `AL`.

```asm
endpoint_probe_C000_3064:
; file 0x43064
C000:3064  B0 00             mov  al,0
C000:3066  8A 26 A5 6F       mov  ah,[0x6fa5]
C000:306A  8B 1E A3 6F       mov  bx,[0x6fa3]
C000:306E  53                push bx

; built-in RAM filesystem
C000:306F  C6 06 A5 6F 08    mov  byte [0x6fa5],0x08
C000:3074  C7 06 A3 6F 0018  mov  word [0x6fa3],0x1800
C000:307A  50                push ax
C000:307B  E8 EB 0A          call mount_current_endpoint_C000_3B69
C000:307E  58                pop  ax
C000:307F  72 02             jc   C000:3083
C000:3081  0C 01             or   al,0x01

; PCMCIA SRAM card filesystem
C000:3083  C6 06 A5 6F 09    mov  byte [0x6fa5],0x09
C000:3088  C7 06 A3 6F 0040  mov  word [0x6fa3],0x4000
C000:308E  50                push ax
C000:308F  E8 D7 0A          call mount_current_endpoint_C000_3B69
C000:3092  58                pop  ax
C000:3093  72 02             jc   C000:3097
C000:3095  0C 02             or   al,0x02

; DreamLink peer
C000:3097  50                push ax
C000:3098  E8 0D 11          call dreamlink_probe_C000_41A8
C000:309B  58                pop  ax
C000:309C  72 02             jc   C000:30A0
C000:309E  0C 04             or   al,0x04

C000:30A0  88 26 A5 6F       mov  [0x6fa5],ah
C000:30A4  5B                pop  bx
C000:30A5  89 1E A3 6F       mov  [0x6fa3],bx
C000:30A9  B4 00             mov  ah,0
C000:30AB  89 46 00          mov  [bp+0x00],ax
C000:30AE  F8                clc
C000:30AF  C3                ret
```

| Returned bit | Meaning |
| ---: | --- |
| `0x01` | Built-in RAM filesystem mounted. |
| `0x02` | PCMCIA SRAM card filesystem mounted. |
| `0x04` | DreamLink serial peer probe succeeded. |

## IOCTL 4400 And Aliases

`C000:30B0` is the `AX=4400` handler, but it also aliases private `AL=28/29`
forms to the endpoint probe and DreamLink finish helper.

```asm
ioctl_4400_C000_30B0:
; file 0x430B0
C000:30B0  E8 B1 0F          call resolve_handle_C000_4064
C000:30B3  8B 46 00          mov  ax,[bp+0x00]
C000:30B6  3C 28             cmp  al,0x28
C000:30B8  75 02             jnz  C000:30BC
C000:30BA  EB A8             jmp  endpoint_probe_C000_3064
C000:30BC  3C 29             cmp  al,0x29
C000:30BE  74 5E             jz   dreamlink_finish_wrapper_C000_311E
```

Plain `AX=4400` resolves the handle to an endpoint and returns a DOS-ish device
or drive word in `DX`.

## File Date/Time AX=5700/5701

`C000:30DA` is reached by `AH=57`. `AL=0` reads the open file's date/time words
from handle state. `AL=1` writes them and marks the built-in/card store dirty.

```asm
service_57_file_datetime_C000_30DA:
; file 0x430DA
C000:30DA  E8 87 0F          call resolve_handle_C000_4064
C000:30DD  8B 46 00          mov  ax,[bp+0x00]
C000:30E0  0A C0             or   al,al
C000:30E2  74 11             jz   get_file_datetime_C000_30F5
C000:30E4  FE C8             dec  al
C000:30E6  74 20             jz   set_file_datetime_C000_3108
...
C000:30F5  E8 BB 0C          call C000:3DB3
C000:30FA  8B 4F 16          mov  cx,[bx+0x16]
C000:30FD  89 4E 04          mov  [bp+0x04],cx
C000:3100  8B 57 14          mov  dx,[bx+0x14]
C000:3103  89 56 06          mov  [bp+0x06],dx
...
C000:3108  C6 06 36 70 01    mov  byte [0x7036],1
C000:3116  89 4F 16          mov  [bx+0x16],cx
C000:3119  89 57 14          mov  [bx+0x14],dx
```

## DreamLink Finish AX=4429

`C000:311E` returns success immediately for non-DreamLink handles. For endpoint
`0x0A`, it sends an end-of-transfer sequence: `0x1A`, zero padding to the active
block length, byte `[7049]`, terminator `0x11`, then a `0x40` command/response.

```asm
dreamlink_finish_wrapper_C000_311E:
C000:311E  E8 04 00          call dreamlink_finish_C000_3125
C000:3121  89 46 00          mov  [bp+0x00],ax
C000:3124  C3                ret

dreamlink_finish_C000_3125:
; file 0x43125
C000:3125  E8 3C 0F          call resolve_handle_C000_4064
C000:3128  A0 A5 6F          mov  al,[0x6fa5]
C000:312B  3C 0A             cmp  al,0x0a
C000:312D  74 05             jz   C000:3134
C000:312F  B8 00 00          mov  ax,0
C000:3132  F8                clc
C000:3133  C3                ret
C000:3134  B2 1A             mov  dl,0x1a
C000:3136  52                push dx
C000:3137  E8 8A DC          call serial_send_byte_C000_0DC4
...
C000:3159  8A 16 49 70       mov  dl,[0x7049]
C000:315D  E8 64 DC          call serial_send_byte_C000_0DC4
C000:3162  B2 11             mov  dl,0x11
C000:3164  E8 5D DC          call serial_send_byte_C000_0DC4
C000:3169  E8 87 0E          call C000:3FF3
C000:316E  C6 06 37 70 40    mov  byte [0x7037],0x40
C000:3173  E8 0C 0F          call dreamlink_response_C000_4082
```

If `[7051]` reports a DreamLink status, the status word at `[703B]` becomes the
returned error and carry is set.

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:4064`, `3DB3` | `int21-handle-core.md` | Handle-to-endpoint resolution and handle state access. |
| `C000:41A8`, `4082`, `3FF3` | `dreamlink-file-core.md` | DreamLink probe/response transaction details. |
| `C000:0DC4` | `serial-services.md` | Serial byte sender used by DreamLink finish. |
