# INT 21h Dispatcher

This slice follows the `INT 21h` root installed by
[`installed-vectors.md`](installed-vectors.md): IVT vector `21h` points to
`C000:0006`, and `C000:0006` jumps to `C000:5098`.

No image assets are reached in this slice.

## Vector Stub

```asm
seed_int21_vector_target:
; file 0x40006
C000:0006  E9 8F 50          jmp  int21_dispatch_C000_5098
```

## Dispatcher Core

The dispatcher builds a stack frame containing the caller registers, switches
`DS` to low RAM, translates `AH` through a byte table at `C000:5000`, and calls
a near handler pointer from `C000:5060`.

Handlers write return registers back into the saved frame. The dispatcher then
restores registers, copies the handler carry status into the caller's saved
FLAGS image, and exits with `iret`.

```asm
int21_dispatch_C000_5098:
; file 0x45098
C000:5098  55                push bp
C000:5099  56                push si
C000:509A  57                push di
C000:509B  83 EC 0E          sub  sp,byte +0x0e
C000:509E  8B EC             mov  bp,sp
C000:50A0  89 46 00          mov  [bp+0x00],ax
C000:50A3  89 5E 02          mov  [bp+0x02],bx
C000:50A6  89 4E 04          mov  [bp+0x04],cx
C000:50A9  89 56 06          mov  [bp+0x06],dx
C000:50AC  8C 5E 08          mov  [bp+0x08],ds
C000:50AF  8C 46 0A          mov  [bp+0x0a],es
C000:50B2  BE 00 00          mov  si,0
C000:50B5  8E DE             mov  ds,si
C000:50B7  88 26 5F 6F       mov  [0x6f5f],ah     ; original service number
C000:50BB  C7 06 C1 6E 0000  mov  word [0x6ec1],0

C000:50C1  80 FC FF          cmp  ah,0xff
C000:50C4  74 4C             jz   private_format_C000_5112
C000:50C6  80 FC 60          cmp  ah,0x60
C000:50C9  73 45             jnc  unsupported_service_C000_5110
C000:50CB  32 C0             xor  al,al
C000:50CD  86 C4             xchg ah,al           ; AX = AH service number
C000:50CF  8B F0             mov  si,ax
C000:50D1  2E 8A 84 00 50    mov  al,[cs:si+0x5000]
C000:50D6  3C FF             cmp  al,0xff
C000:50D8  74 36             jz   unsupported_service_C000_5110
C000:50DA  D1 E0             shl  ax,1
C000:50DC  8B F0             mov  si,ax
C000:50DE  2E 8B 84 60 50    mov  ax,[cs:si+0x5060]
C000:50E3  FB                sti
C000:50E4  FF D0             call ax
C000:50E6  FA                cli
```

Unsupported `AH < 60h` entries are encoded as `0xff` in the byte table.
Unsupported `AH >= 60h` also goes to the same tight loop. `AH=FFh` bypasses the
normal table and enters the private initialize/format path at `C000:2C4A`.

```asm
C000:50E7  9F                lahf                 ; preserve handler flags
C000:50E8  83 C4 0E          add  sp,byte +0x0e
C000:50EB  9E                sahf
C000:50EC  8B 46 00          mov  ax,[bp+0x00]
C000:50EF  8B 5E 02          mov  bx,[bp+0x02]
C000:50F2  8B 4E 04          mov  cx,[bp+0x04]
C000:50F5  8B 56 06          mov  dx,[bp+0x06]
C000:50F8  8E 5E 08          mov  ds,[bp+0x08]
C000:50FB  8E 46 0A          mov  es,[bp+0x0a]
C000:50FE  5F                pop  di
C000:50FF  5E                pop  si
C000:5100  8B EC             mov  bp,sp           ; BP points at saved FLAGS
C000:5102  72 06             jc   return_with_carry_C000_510A
C000:5104  80 66 06 FE       and  byte [bp+0x06],0xfe
C000:5108  5D                pop  bp
C000:5109  CF                iret
return_with_carry_C000_510A:
C000:510A  80 4E 06 01       or   byte [bp+0x06],0x01
C000:510E  5D                pop  bp
C000:510F  CF                iret

unsupported_service_C000_5110:
C000:5110  EB FE             jmp  short C000:5110

private_format_C000_5112:
C000:5112  E8 35 DB          call C000:2C4A
C000:5115  EB D0             jmp  C000:50E7
```

## Service Tables

`C000:5000` is a 96-byte `AH` to handler-index table. `0xff` means unsupported.
`C000:5060` is the handler pointer table. The valid index range is `00h..1Bh`.

| `AH` | Handler | Current read |
| ---: | --- | --- |
| `03` | `C000:5117` | Serial/input status path. |
| `04` | `C000:0D71` | Serial/device character output using caller `DL`. |
| `05` | `C000:5146` | Parallel printer character output through `C000:0920`. |
| `08` | `C000:5155` | Blocking keyboard/event read through `C000:4A8D`. |
| `0B` | `C000:515C` | Nonblocking keyboard/event status through `C000:4977`. |
| `0E` | `C000:5163` | Select current drive through `C000:28A7`. |
| `19` | `C000:5167` | Get current drive through `C000:28B9`. |
| `1A` | `C000:516B` | Set DTA pointer through `C000:28C3`. |
| `2A` | `C000:516F` | Get date. |
| `2B` | `C000:51C7` | Set date. |
| `2C` | `C000:5209` | Get time. |
| `2D` | `C000:523D` | Set time. |
| `2F` | `C000:5270` | Get DTA pointer. |
| `36` | `C000:5274` | Get free disk space. |
| `3C` | `C000:5278` -> `C000:29AD` | Create/truncate file. |
| `3D` | `C000:527C` -> `C000:2B84` | Open file. |
| `3E` | `C000:5280` -> `C000:2C41` | Close file. |
| `3F` | `C000:5284` -> `C000:3194` | Read file. |
| `40` | `C000:5288` -> `C000:32B1` | Write file. |
| `41` | `C000:528C` -> `C000:3730` | Delete file. |
| `42` | `C000:5290` -> `C000:356F` | Seek file. |
| `43` | `C000:5294` -> `C000:37A7` | Get/set file attributes. |
| `44` | `C000:5298` | IOCTL/private status subdispatcher. |
| `4E` | `C000:52F4` -> `C000:2DE2` | Find first. |
| `4F` | `C000:52F8` -> `C000:2E27` | Find next. |
| `56` | `C000:52FC` -> `C000:2FE5` | Rename file. |
| `57` | `C000:5300` -> `C000:30DA` | Get/set file date/time. |
| `5B` | `C000:5304` -> `C000:2A1B` | Create new file, failing if already present. |
| `FF` | `C000:2C4A` | Private initialize/format service; bypasses the tables. |

## Shallow Wrappers

Several handlers are one-call wrappers that write return registers back into the
dispatcher frame.

```asm
service_03_serial_input_status_C000_5117:
C000:5117  E8 73 FA          call C000:4B8D
C000:511A  F6 06 A5 70 02    test byte [0x70a5],0x02
C000:511F  74 21             jz   C000:5142
C000:5121  E8 D4 F8          call C000:49F8
C000:5124  0A C0             or   al,al
C000:5126  74 EF             jz   service_03_serial_input_status_C000_5117
C000:5128  B4 80             mov  ah,0x80
C000:512A  0A 26 57 6D       or   ah,[0x6d57]
C000:512E  80 26 57 6D 01    and  byte [0x6d57],0x01
C000:5133  80 E4 FE          and  ah,0xfe
C000:5136  8B 5E 02          mov  bx,[bp+0x02]
C000:5139  8A DC             mov  bl,ah
C000:513B  89 5E 02          mov  [bp+0x02],bx
C000:513E  89 46 00          mov  [bp+0x00],ax
C000:5141  C3                ret
C000:5142  B4 00             mov  ah,0
C000:5144  EB E4             jmp  C000:512A

service_05_parallel_output_C000_5146:
C000:5146  E8 D7 B7          call C000:0920
C000:5149  8B 5E 02          mov  bx,[bp+0x02]
C000:514C  8A D8             mov  bl,al
C000:514E  89 5E 02          mov  [bp+0x02],bx
C000:5151  89 46 00          mov  [bp+0x00],ax
C000:5154  C3                ret

service_08_blocking_key_C000_5155:
C000:5155  E8 35 F9          call C000:4A8D
C000:5158  88 46 00          mov  [bp+0x00],al
C000:515B  C3                ret

service_0B_key_status_C000_515C:
C000:515C  E8 18 F8          call C000:4977
C000:515F  88 46 00          mov  [bp+0x00],al
C000:5162  C3                ret
```

The drive/DTA wrappers and file wrappers are similarly thin:

```asm
C000:5163  E8 41 D7          call C000:28A7       ; AH=0E
C000:5166  C3                ret
C000:5167  E8 4F D7          call C000:28B9       ; AH=19
C000:516A  C3                ret
C000:516B  E8 55 D7          call C000:28C3       ; AH=1A
C000:516E  C3                ret

C000:5270  E8 5D D6          call C000:28D0       ; AH=2F
C000:5273  C3                ret
C000:5274  E8 69 D6          call C000:28E0       ; AH=36
C000:5277  C3                ret
C000:5278  E8 32 D7          call C000:29AD       ; AH=3C
C000:527B  C3                ret
C000:527C  E8 05 D9          call C000:2B84       ; AH=3D
C000:527F  C3                ret
C000:5280  E8 BE D9          call C000:2C41       ; AH=3E
C000:5283  C3                ret
C000:5284  E8 0D DF          call C000:3194       ; AH=3F
C000:5287  C3                ret
C000:5288  E8 26 E0          call C000:32B1       ; AH=40
C000:528B  C3                ret
C000:528C  E8 A1 E4          call C000:3730       ; AH=41
C000:528F  C3                ret
C000:5290  E8 DC E2          call C000:356F       ; AH=42
C000:5293  C3                ret
C000:5294  E8 10 E5          call C000:37A7       ; AH=43
C000:5297  C3                ret
C000:52F4  E8 EB DA          call C000:2DE2       ; AH=4E
C000:52F7  C3                ret
C000:52F8  E8 2C DB          call C000:2E27       ; AH=4F
C000:52FB  C3                ret
C000:52FC  E8 E6 DC          call C000:2FE5       ; AH=56
C000:52FF  C3                ret
C000:5300  E8 D7 DD          call C000:30DA       ; AH=57
C000:5303  C3                ret
C000:5304  E8 14 D7          call C000:2A1B       ; AH=5B
C000:5307  C3                ret
```

## Date And Time Services

The date/time services are backed by the RP5C01 shadow buffer at `6D96..6DA2`.
They are kept in this slice because they are compact and do not branch into the
storage subsystem.

```asm
service_2A_get_date_C000_516F:
C000:516F  E8 0A 00          call C000:517C
C000:5172  88 46 00          mov  [bp+0x00],al    ; AL = weekday
C000:5175  89 4E 04          mov  [bp+0x04],cx    ; CX = year
C000:5178  89 56 06          mov  [bp+0x06],dx    ; DH = month, DL = day
C000:517B  C3                ret

C000:517C  E8 E1 B9          call C000:0B60       ; read RTC shadow
...
C000:51B7  8B C1             mov  ax,cx           ; year
C000:51B9  8A DE             mov  bl,dh           ; month
C000:51BD  8A CA             mov  cl,dl           ; day
C000:51C1  E8 44 01          call C000:5308       ; weekday
C000:51C6  C3                ret

service_2B_set_date_C000_51C7:
C000:51C7  E8 04 00          call C000:51CE
C000:51CA  88 46 00          mov  [bp+0x00],al
C000:51CD  C3                ret
C000:51CE  BE 96 6D          mov  si,0x6d96
...
C000:5205  E8 C1 B7          call C000:09C9       ; write RTC date
C000:5208  C3                ret

service_2C_get_time_C000_5209:
C000:5209  E8 07 00          call C000:5213
C000:520C  89 4E 04          mov  [bp+0x04],cx    ; CH = hour, CL = minute
C000:520F  89 56 06          mov  [bp+0x06],dx    ; DH = second
C000:5212  C3                ret
C000:5213  E8 4A B9          call C000:0B60       ; read RTC shadow
...
C000:523C  C3                ret

service_2D_set_time_C000_523D:
C000:523D  E8 04 00          call C000:5244
C000:5240  88 46 00          mov  [bp+0x00],al
C000:5243  C3                ret
C000:5244  BE 96 6D          mov  si,0x6d96
...
C000:526C  E8 3F B7          call C000:09AE       ; write RTC time
C000:526F  C3                ret
```

`C000:5308` computes the weekday from binary year/month/day rather than trusting
the RTC weekday/status shadow byte.

## IOCTL Subdispatcher

`AH=44` is a compact private subdispatcher. It accepts standard-looking
`AX=4400`, then the private range `AX=4420..4429`. Other `AH=44` calls return
with carry set.

```asm
service_44_ioctl_C000_5298:
C000:5298  8B 46 00          mov  ax,[bp+0x00]
C000:529B  0A C0             or   al,al
C000:529D  74 22             jz   ioctl_4400_C000_52C1
C000:529F  2D 20 44          sub  ax,0x4420
C000:52A2  74 21             jz   ioctl_4420_C000_52C5
C000:52A4  48                dec  ax
C000:52A5  74 22             jz   ioctl_4421_C000_52C9
...
C000:52B9  48                dec  ax
C000:52BA  74 30             jz   ioctl_4428_C000_52EC
C000:52BC  48                dec  ax
C000:52BD  74 31             jz   ioctl_4429_C000_52F0
C000:52BF  F9                stc
C000:52C0  C3                ret

C000:52C1  E8 EC DD          call C000:30B0       ; AX=4400
C000:52C4  C3                ret
C000:52C5  E8 A4 B5          call C000:086C       ; AX=4420
C000:52C8  C3                ret
C000:52C9  A0 E6 70          mov  al,[0x70e6]     ; AX=4421
C000:52CC  89 46 00          mov  [bp+0x00],ax
C000:52CF  C3                ret
C000:52D0  E8 E9 B9          call C000:0CBC       ; AX=4422
C000:52D3  C3                ret
C000:52D4  E8 4E BA          call C000:0D25       ; AX=4423
C000:52D7  C3                ret
C000:52D8  E8 54 07          call C000:5A2F       ; AX=4424
C000:52DB  C3                ret
C000:52DC  E8 69 06          call C000:5948       ; AX=4425
C000:52DF  C3                ret
C000:52E0  80 0E 51 6D 08    or   byte [0x6d51],0x08 ; AX=4426
C000:52E5  C3                ret
C000:52E6  80 26 51 6D F7    and  byte [0x6d51],0xf7 ; AX=4427
C000:52EB  C3                ret
C000:52EC  E8 75 DD          call C000:3064       ; AX=4428 endpoint probe
C000:52EF  C3                ret
C000:52F0  E8 2B DE          call C000:311E       ; AX=4429 DreamLink finish
C000:52F3  C3                ret
```

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:28A7..30DA` | `int21-filesystem-front.md` | Drive selection, DTA handling, find/open/create/delete/rename/date wrappers. |
| `C000:3194`, `C000:32B1`, `C000:356F`, `C000:37A7` | `int21-file-io.md` | Read/write/seek/attributes and local FAT-like storage paths. |
| `C000:2C4A` | `int21-format.md` | Private `AH=FF/BL=A5` initialize/format service. |
| `C000:3064`, `C000:311E` | `int21-endpoints.md` | Built-in/card/DreamLink endpoint probe and DreamLink finish helper. |
| `C000:0D71`, `C000:5117` | `serial-services.md` | Serial character device status/output services. |
| `C000:5146`, `C000:0920` | `printer-device.md` | Printer character output service and Centronics byte writer. |
| `C000:4A8D`, `C000:4977`, `C000:5915` | `keyboard-services.md` | Blocking/nonblocking key services and translation. |
