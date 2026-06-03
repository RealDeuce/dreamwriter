# Printer Output

This slice maps the application-side printer output layer below
[`wp-print-out.md`](wp-print-out.md) and
[`print-merge-handlers.md`](print-merge-handlers.md), and above the physical
Centronics/serial services in [`printer-device.md`](printer-device.md) and
[`serial-services.md`](serial-services.md).

No bitmap assets are reached in this slice. The visible pause/cancel prompts are
string/display resources around `0x56024..0x56295`.

## Printer Setup State

`C688:C0D7` copies the PRINTER SET UP fields documented in
[`setup-screens.md`](setup-screens.md) into the output-layer state. `[6D59]`
selects the printer model and is masked to three bits before storing in
`[829E]`. `[6D5B]` is the PAPER FEED byte; bit `0` is shifted into `[82A3]`
bit `1`. The interface selector `[6D5A]` is not copied here because the byte
sink reads it directly when choosing serial versus parallel output.

```asm
printer_load_setup_state_C688_C0D7:
; file 0x52957
C688:C0D7  BE 59 6D          mov  si,0x6d59
C688:C0DA  8A 04             mov  al,[si]
C688:C0DC  24 07             and  al,0x7
C688:C0DE  3C 08             cmp  al,0x8
C688:C0E0  72 02             jc   printer_model_ok_C688_C0E4
C688:C0E2  B0 00             mov  al,0
printer_model_ok_C688_C0E4:
C688:C0E4  A2 9E 82          mov  [0x829e],al
C688:C0E7  8A 64 02          mov  ah,[si+0x2]
C688:C0EA  80 E4 01          and  ah,0x1
C688:C0ED  D0 E4             shl  ah,1
C688:C0EF  88 26 A3 82       mov  [0x82a3],ah
C688:C0F3  C3                ret
```

The table at `C688:BFA7` is a word vector table for character/control output.
Most entries point at the default `C688:C057` stub, while selected entries land
on neighboring stubs that load printer-specific byte values before jumping to
the shared tail.

```asm
printer_char_output_stubs_C688_C057:
; file 0x528D7
C688:C057  E9 97 0F          jmp  printer_char_tail_C688_CFF1
C688:C05A  B0 E0             mov  al,0xe0
C688:C05C  E9 92 0F          jmp  printer_char_tail_C688_CFF1
C688:C05F  B0 E1             mov  al,0xe1
C688:C061  E9 8D 0F          jmp  printer_char_tail_C688_CFF1
C688:C064  B0 E2             mov  al,0xe2
C688:C066  E9 88 0F          jmp  printer_char_tail_C688_CFF1
```

`C688:CFF1` is the final character tail: it flushes spacing/position state,
copies `AL` into `DL`, emits the byte through `C688:C82A`, restores spacing
state, clears `CL`, and returns.

```asm
printer_char_tail_C688_CFF1:
; file 0x53871
C688:CFF1  E8 CF FF          call printer_spacing_flush_C688_CFC3
C688:CFF4  3B 1E F9 78       cmp  bx,[0x78f9]
C688:CFF8  7E 00             jng  0xcffa
printer_char_emit_C688_CFFA:
C688:CFFA  8A D0             mov  dl,al
C688:CFFC  E8 2B F8          call printer_emit_byte_C688_C82A
C688:CFFF  E8 CD FF          call printer_spacing_restore_C688_CFCF
C688:D002  32 C9             xor  cl,cl
C688:D004  C3                ret
```

## Byte Sink

`C688:C82A` is the common application byte sink. `[82A3] bit 3` is the cancel
flag and bit `0` suppresses output. Otherwise the routine saves `DL` in
`[8295]`, reads the setup interface byte `[6D5A]`, and sends the byte through
parallel `INT 21h AH=05` when `[6D5A] bit 0` is clear or serial
`INT 21h AH=04` when the bit is set.

The low-level services are mapped separately: `AH=05` reaches the Centronics
writer in [`printer-device.md`](printer-device.md), while `AH=04` reaches the
serial transmitter in [`serial-services.md`](serial-services.md).

```asm
printer_emit_byte_C688_C82A:
; file 0x530AA
C688:C82A  F6 06 A3 82 08    test byte [0x82a3],0x8
C688:C82F  74 01             jz   printer_emit_not_canceled_C688_C832
C688:C831  C3                ret
printer_emit_not_canceled_C688_C832:
C688:C832  F6 06 A3 82 01    test byte [0x82a3],0x1
C688:C837  74 01             jz   printer_emit_allowed_C688_C83A
C688:C839  C3                ret
printer_emit_allowed_C688_C83A:
C688:C83A  88 16 95 82       mov  [0x8295],dl
C688:C83E  BE 59 6D          mov  si,0x6d59
C688:C841  F6 44 01 01       test byte [si+0x1],0x1
C688:C845  75 09             jnz  printer_emit_serial_C688_C850
C688:C847  B4 05             mov  ah,0x5
C688:C849  CD 21             int  0x21
C688:C84B  0A C0             or   al,al
C688:C84D  75 0A             jnz  printer_emit_error_C688_C859
C688:C84F  C3                ret
printer_emit_serial_C688_C850:
C688:C850  B4 04             mov  ah,0x4
C688:C852  CD 21             int  0x21
C688:C854  0A C0             or   al,al
C688:C856  75 01             jnz  printer_emit_error_C688_C859
C688:C858  C3                ret
printer_emit_error_C688_C859:
C688:C859  E8 08 03          call printer_poll_control_key_C688_CB64
C688:C85C  3C 03             cmp  al,0x3
C688:C85E  75 03             jnz  printer_maybe_pause_C688_C863
C688:C860  E9 F5 02          jmp  printer_cancel_C688_CB58
printer_maybe_pause_C688_C863:
C688:C863  3C 20             cmp  al,0x20
C688:C865  74 01             jz   printer_pause_retry_C688_C868
C688:C867  C3                ret
printer_pause_retry_C688_C868:
C688:C868  E8 3A 03          call printer_pause_loop_C688_CBA5
C688:C86B  8A 16 95 82       mov  dl,[0x8295]
C688:C86F  EB B9             jmp  printer_emit_byte_C688_C82A
```

## Pause And Cancel Control

`C688:CB64` is a filtered nonblocking key poll used by the output error path.
It checks for a pending key with `INT 21h AH=0B`, reads it with `AH=08`, and
accepts only four bytes from the inline table at `C688:CB8E`:
`DA 20 03 00` (`SELECT`, `SPACE`, `CAN`, terminator). Any other pending input
is discarded and the poll restarts.

`C688:CB58` displays resource `0x21` and sets `[82A3] bit `3`, the cancel flag.
`C688:CBA5` displays a pause prompt, waits for `SELECT` or `CAN`, and either
restores the print-progress prompt or sets the same cancel bit.

```asm
printer_cancel_C688_CB58:
; file 0x533D8
C688:CB58  BE 21 00          mov  si,0x21
C688:CB5B  E8 86 00          call printer_show_resource_C688_CBE4
C688:CB5E  80 0E A3 82 08    or   byte [0x82a3],0x8
C688:CB63  C3                ret

printer_poll_control_key_C688_CB64:
C688:CB64  57                push di
C688:CB65  B4 0B             mov  ah,0xb
C688:CB67  CD 21             int  0x21
C688:CB69  5F                pop  di
C688:CB6A  3C 00             cmp  al,0
C688:CB6C  75 01             jnz  printer_key_ready_C688_CB6F
C688:CB6E  C3                ret
printer_key_ready_C688_CB6F:
C688:CB6F  57                push di
C688:CB70  B4 08             mov  ah,0x8
C688:CB72  CD 21             int  0x21
C688:CB74  5F                pop  di
C688:CB75  33 DB             xor  bx,bx
C688:CB77  BE 8E CB          mov  si,0xcb8e
C688:CB7A  2E 3A 00          cmp  al,[cs:bx+si]
C688:CB7D  74 09             jz   printer_key_accepted_C688_CB88
C688:CB7F  43                inc  bx
C688:CB80  2E 80 38 00       cmp  byte [cs:bx+si],0
C688:CB84  75 F4             jnz  printer_key_filter_C688_CB7A
C688:CB86  EB DC             jmp  printer_poll_control_key_C688_CB64
printer_key_accepted_C688_CB88:
C688:CB88  50                push ax
C688:CB89  E8 06 00          call printer_drain_keys_C688_CB92
C688:CB8C  58                pop  ax
C688:CB8D  C3                ret
```

```asm
printer_pause_loop_C688_CBA5:
; file 0x53425
C688:CBA5  BE 24 00          mov  si,0x24
C688:CBA8  B5 02             mov  ch,0x2
C688:CBAA  A0 B3 8D          mov  al,[0x8db3]
C688:CBAD  24 03             and  al,0x3
C688:CBAF  75 0A             jnz  printer_pause_show_C688_CBBB
C688:CBB1  BE 33 00          mov  si,0x33
C688:CBB4  EB 05             jmp  printer_pause_show_C688_CBBB
printer_between_pages_entry_C688_CBB6:
C688:CBB6  BE 22 00          mov  si,0x22
C688:CBB9  B5 02             mov  ch,0x2
printer_pause_show_C688_CBBB:
C688:CBBB  E8 2D 00          call printer_show_resource2_C688_CBEB
printer_pause_wait_C688_CBBE:
C688:CBBE  E8 A3 FF          call printer_poll_control_key_C688_CB64
C688:CBC1  3C DA             cmp  al,0xda
C688:CBC3  74 0A             jz   printer_pause_continue_C688_CBCF
C688:CBC5  3C 03             cmp  al,0x3
C688:CBC7  75 F5             jnz  printer_pause_wait_C688_CBBE
C688:CBC9  80 0E A3 82 08    or   byte [0x82a3],0x8
C688:CBCE  C3                ret
printer_pause_continue_C688_CBCF:
C688:CBCF  50                push ax
C688:CBD0  BE 1A 00          mov  si,0x1a
C688:CBD3  A0 B3 8D          mov  al,[0x8db3]
C688:CBD6  24 03             and  al,0x3
C688:CBD8  75 03             jnz  printer_restore_progress_C688_CBDD
C688:CBDA  BE 1F 00          mov  si,0x1f
printer_restore_progress_C688_CBDD:
C688:CBDD  B5 02             mov  ch,0x2
C688:CBDF  E8 09 00          call printer_show_resource2_C688_CBEB
C688:CBE2  58                pop  ax
C688:CBE3  C3                ret
```

## Counted Stream Emitters

`C688:CC1F` emits a counted byte string from `CS:SI`, `C688:CC38` emits the
same format from `DS:SI`, and `C688:CC51` emits `DH` spaces. All three clear
`CL` before returning, matching the character-output tail's completion state.

```asm
printer_emit_cs_counted_C688_CC1F:
; file 0x5349F
C688:CC1F  52                push dx
C688:CC20  2E 8A 34          mov  dh,[cs:si]
C688:CC23  FE C6             inc  dh
C688:CC25  46                inc  si
printer_emit_cs_loop_C688_CC26:
C688:CC26  FE CE             dec  dh
C688:CC28  74 0A             jz   printer_emit_cs_done_C688_CC34
C688:CC2A  2E 8A 14          mov  dl,[cs:si]
C688:CC2D  56                push si
C688:CC2E  E8 F9 FB          call printer_emit_byte_C688_C82A
C688:CC31  5E                pop  si
C688:CC32  EB F1             jmp  printer_emit_cs_loop_C688_CC26
printer_emit_cs_done_C688_CC34:
C688:CC34  5A                pop  dx
C688:CC35  32 C9             xor  cl,cl
C688:CC37  C3                ret

printer_emit_ds_counted_C688_CC38:
C688:CC38  52                push dx
C688:CC39  33 D2             xor  dx,dx
C688:CC3B  8A 34             mov  dh,[si]
C688:CC3D  FE C6             inc  dh
C688:CC3F  46                inc  si
printer_emit_ds_loop_C688_CC40:
C688:CC40  FE CE             dec  dh
C688:CC42  74 09             jz   printer_emit_ds_done_C688_CC4D
C688:CC44  8A 14             mov  dl,[si]
C688:CC46  56                push si
C688:CC47  E8 E0 FB          call printer_emit_byte_C688_C82A
C688:CC4A  5E                pop  si
C688:CC4B  EB F2             jmp  printer_emit_ds_loop_C688_CC40
printer_emit_ds_done_C688_CC4D:
C688:CC4D  5A                pop  dx
C688:CC4E  32 C9             xor  cl,cl
C688:CC50  C3                ret

printer_emit_spaces_C688_CC51:
C688:CC51  B2 20             mov  dl,0x20
C688:CC53  FE C6             inc  dh
printer_spaces_loop_C688_CC55:
C688:CC55  FE CE             dec  dh
C688:CC57  74 05             jz   printer_spaces_done_C688_CC5E
C688:CC59  E8 CE FB          call printer_emit_byte_C688_C82A
C688:CC5C  EB F7             jmp  printer_spaces_loop_C688_CC55
printer_spaces_done_C688_CC5E:
C688:CC5E  32 C9             xor  cl,cl
C688:CC60  C3                ret
```

## Formatter Bridge

The merge handlers emit selected address-book fields through `C688:5B83`, and
the application event loop also reaches `C688:5B90`. These entries are not the
hardware byte sink; they bridge caller bytes and mode selectors into the shared
formatter/editor-output state. `C688:5B83` stores `DL` in `[79C3]` and selects
mode `0x0A`; `C688:5B90` selects mode `0x19` and clears `DL`. The shared entry
then saves `[75EF]`, points it at `[79C3]`, snapshots the current editor layout
state, and loads mode flags from the table at `C688:5B6D`.

```asm
formatter_emit_byte_C688_5B83:
; file 0x4C403
C688:5B83  B1 0A             mov  cl,0x0a
C688:5B85  EB 02             jmp  formatter_store_byte_C688_5B89
formatter_emit_byte_alt_C688_5B87:
C688:5B87  B1 3A             mov  cl,0x3a
formatter_store_byte_C688_5B89:
C688:5B89  8A C2             mov  al,dl
C688:5B8B  A2 C3 79          mov  [0x79c3],al
C688:5B8E  EB 0A             jmp  formatter_shared_state_C688_5B9A
formatter_mode_19_C688_5B90:
C688:5B90  B1 19             mov  cl,0x19
C688:5B92  EB 02             jmp  formatter_zero_dl_C688_5B96
formatter_mode_29_C688_5B94:
C688:5B94  B1 29             mov  cl,0x29
formatter_zero_dl_C688_5B96:
C688:5B96  B2 00             mov  dl,0
C688:5B98  EB 00             jmp  formatter_shared_state_C688_5B9A
formatter_shared_state_C688_5B9A:
C688:5B9A  FF 36 EF 75       push word [0x75ef]
C688:5B9E  C7 06 EF 75 C3 79 mov  word [0x75ef],0x79c3
C688:5BA4  C6 06 56 79 00    mov  byte [0x7956],0
C688:5BA9  A0 3D 79          mov  al,[0x793d]
C688:5BAC  A2 9A 79          mov  [0x799a],al
C688:5BAF  A0 3E 79          mov  al,[0x793e]
C688:5BB2  A2 5F 79          mov  [0x795f],al
C688:5BB5  A0 E5 78          mov  al,[0x78e5]
C688:5BB8  A2 6B 79          mov  [0x796b],al
C688:5BBB  8B 36 F5 78       mov  si,[0x78f5]
C688:5BBF  89 36 46 79       mov  [0x7946],si
C688:5BC3  8B 36 28 79       mov  si,[0x7928]
C688:5BC7  89 36 63 79       mov  [0x7963],si
C688:5BCB  8B 36 F3 78       mov  si,[0x78f3]
C688:5BCF  89 36 44 79       mov  [0x7944],si
C688:5BD3  8A C1             mov  al,cl
C688:5BD5  24 0F             and  al,0xf
C688:5BD7  B4 00             mov  ah,0
C688:5BD9  8B F0             mov  si,ax
C688:5BDB  81 C6 6D 5B       add  si,0x5b6d
C688:5BDF  2E 8A 2C          mov  ch,[cs:si]
C688:5BE2  C7 06 ED 75 3B 79 mov  word [0x75ed],0x793b
```

The deeper `C688:5B9A` formatter path remains shared with editor display and
redraw code; this slice only names the printer/merge-facing entry boundary.

## Resources And State

| Resource | Table word | Payload | Role |
| ---: | ---: | ---: | --- |
| `0x1A` | `0x0664` | `0x56024` | Print-progress screen: `PRINT TEXT`, `PRINTING`, pause/cancel instructions. |
| `0x1F` | `0x06CD` | `0x5608D` | Alternate print-progress screen used when `[8DB3] & 3 == 0`. |
| `0x21` | `0x0742` | `0x56102` | Cancel status; includes `Printing was canceled`. |
| `0x22` | `0x07A2` | `0x56162` | Insert-paper prompt. |
| `0x24` | `0x0836` | `0x561F6` | Pause prompt with continue/cancel text. |
| `0x33` | `0x0894` | `0x56254` | Alternate pause prompt used when `[8DB3] & 3 == 0`. |

| Address | Role in this slice |
| ---: | --- |
| `[6D59]` | PRINTER model selector copied into `[829E]`. |
| `[6D5A]` | INTERFACE selector; bit `0` chooses serial `AH=04` instead of parallel `AH=05`. |
| `[6D5B]` | PAPER FEED selector copied into `[82A3] bit 1`. |
| `[8295]` | Saved output byte restored after pause/retry. |
| `[829E]` | Masked printer model selector. |
| `[82A3]` | Output flags: bit `3` cancels output, bit `0` suppresses emission, bit `1` receives paper-feed state. |
| `[75EF]`, `[75ED]` | Formatter descriptor pointers rewritten by `C688:5B9A`. |
| `[79C3]` | One-byte formatter input buffer for `C688:5B83`. |

## Bottom

The application printer formatter frontier is now mapped through the byte sink
that chooses serial `INT 21h AH=04` or parallel `AH=05`. Remaining printer depth
is in the shared formatter/editor-output body below `C688:5B9A` and in the
larger printer motion/spacing tables referenced by `C688:CFC3` and
`C688:CFCF`.
