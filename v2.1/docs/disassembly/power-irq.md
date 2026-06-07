# Power IRQ Roots

This slice follows the installed `F8h` and `FFh` interrupt roots from
[`installed-vectors.md`](installed-vectors.md). The code points to two sides of
the retained power path:

- `F8h` / `C000:03AE` saves the current CPU context and waits for an external
  power transition.
- `FFh` / `C000:02EE` either marks a warm/power-management event or prepares a
  warm/diagnostic transition and reaches the same terminal port `0x70` path.

No image assets are reached in this slice.

## IRQ FF Warm/Power Path

```asm
seed_irq_ff_stub:
; file 0x4001E
C000:001E  E9 CD 02          jmp  irq_ff_warm_power_C000_02EE
```

The handler clears IRQ source bit `0x01` at port `0x90`, inspects the
startup/warm marker at `[6809]`, and chooses between a normal `iret` marker path
and a retained warm/diagnostic path.

```asm
irq_ff_warm_power_C000_02EE:
; file 0x402EE
C000:02EE  50                push ax
C000:02EF  53                push bx
C000:02F0  1E                push ds
C000:02F1  B8 00 00          mov  ax,0
C000:02F4  8E D8             mov  ds,ax
C000:02F6  B0 01             mov  al,0x01
C000:02F8  E6 90             out  0x90,al
C000:02FA  A1 09 68          mov  ax,[0x6809]
C000:02FD  3D 95 19          cmp  ax,0x1995
C000:0300  74 42             jz   warm_state_C000_0344
C000:0302  3D 99 19          cmp  ax,0x1999
C000:0305  74 22             jz   warm_diag_target_C000_0329
C000:0307  83 3E 0D 68 00    cmp  word [0x680d],byte +0
C000:030C  75 10             jnz  mark_power_event_C000_031E
C000:030E  3D 01 00          cmp  ax,0x0001
C000:0311  74 16             jz   warm_diag_target_C000_0329
C000:0313  56                push si
C000:0314  57                push di
C000:0315  51                push cx
C000:0316  E8 39 0F          call C000:1252      ; diagnostic chord compare
C000:0319  59                pop  cx
C000:031A  5F                pop  di
C000:031B  5E                pop  si
C000:031C  74 0B             jz   warm_diag_target_C000_0329

mark_power_event_C000_031E:
C000:031E  C7 06 09 68 9219  mov  word [0x6809],0x1992
C000:0324  1F                pop  ds
C000:0325  5B                pop  bx
C000:0326  58                pop  ax
C000:0327  FB                sti
C000:0328  CF                iret
```

`[6809]=1992` is consumed by foreground idle helpers such as `C000:4961`, which
can then enter the retained power-transition path after the interrupt returns.

The warm/diagnostic branch seeds a retained target and does not return through
`iret`.

```asm
warm_diag_target_C000_0329:
C000:0329  C6 06 07 68 00    mov  byte [0x6807],0
C000:032E  C7 06 79 6D 8D4A  mov  word [0x6d79],0x4a8d
C000:0334  8C C8             mov  ax,cs
C000:0336  A3 7B 6D          mov  [0x6d7b],ax
C000:0339  C7 06 81 6D 9519  mov  word [0x6d81],0x1995
C000:033F  80 26 51 6D F7    and  byte [0x6d51],0xf7

warm_state_C000_0344:
C000:0344  8B EC             mov  bp,sp
C000:0346  83 C5 06          add  bp,byte +0x06
C000:0349  8B 46 00          mov  ax,[bp+0x00]   ; interrupted IP
C000:034C  A3 85 6D          mov  [0x6d85],ax
C000:034F  83 C5 02          add  bp,byte +0x02
C000:0352  8B 46 00          mov  ax,[bp+0x00]   ; interrupted CS
C000:0355  A3 87 6D          mov  [0x6d87],ax
C000:0358  E8 F5 07          call C000:0B50
C000:035B  EB 13             jmp  terminal_power_handoff_C000_0370
```

## Retained Power Transition

`C000:035D` is also reached by foreground auto-off paths after they have saved a
resume target. It checksums the saved context, optionally checksums the built-in
store, cleans up timer/serial state, programs the next RTC alarm, and then
writes `0x01` to port `0x70`.

```asm
retained_power_transition_C000_035D:
; file 0x4035D
C000:035D  E8 D8 00          call checksum_saved_context_C000_0438
C000:0360  80 3E 36 70 00    cmp  byte [0x7036],0
C000:0365  74 03             jz   C000:036A
C000:0367  E8 E1 00          call checksum_builtin_store_C000_044B
C000:036A  E8 10 01          call retained_cleanup_C000_047D
C000:036D  E8 06 00          call prepare_rtc_alarm_C000_0376

terminal_power_handoff_C000_0370:
C000:0370  B0 01             mov  al,0x01
C000:0372  E6 70             out  0x70,al
C000:0374  EB FE             jmp  short C000:0374
```

Current hardware inference: port `0x70` is a retained power/reset handoff latch,
because warm diagnostic, auto-off, and RTC alarm re-arm paths all converge on
the same write and terminal loop.

## RTC Alarm Preparation

`C000:0376` is kept shallow here. It selects the next alarm through the
application-side scheduler/world-clock helper, compares it against the current
RTC shadow, and either programs the stored alarm or a current-minute+1 fallback.

```asm
prepare_rtc_alarm_C000_0376:
; file 0x40376
C000:0376  E4 DD             in   al,0xdd
C000:0378  24 F7             and  al,0xf7         ; pause RTC timer advance
C000:037A  E6 DD             out  0xdd,al
C000:037C  06                push es
C000:037D  9A BB D3 98 DC    call DC98:D3BB      ; select next alarm
C000:0382  07                pop  es
C000:0383  E8 0A 08          call C000:0B90      ; full date/time compare
C000:0386  72 03             jc   C000:038B
C000:0388  E8 F1 07          call C000:0B7C      ; shorter day/time compare
C000:038B  9C                pushf
C000:038C  E4 DD             in   al,0xdd
C000:038E  0C 08             or   al,0x08         ; resume RTC timer advance
C000:0390  E6 DD             out  0xdd,al
C000:0392  9D                popf
C000:0393  72 0F             jc   fallback_alarm_C000_03A4
C000:0395  E8 79 06          call C000:0A11      ; program selected alarm
C000:0398  C6 06 4E 6D 00    mov  byte [0x6d4e],0
C000:039D  E4 DD             in   al,0xdd
C000:039F  0C 04             or   al,0x04         ; enable alarm output
C000:03A1  E6 DD             out  0xdd,al
C000:03A3  C3                ret

fallback_alarm_C000_03A4:
C000:03A4  E8 98 06          call C000:0A3F      ; current minute + 1
C000:03A7  C6 06 4E 6D 01    mov  byte [0x6d4e],1
C000:03AC  EB EF             jmp  C000:039D
```

## IRQ F8 Save/Suspend Path

```asm
seed_irq_f8_stub:
; file 0x40009
C000:0009  E9 A2 03          jmp  irq_f8_save_suspend_C000_03AE
```

This path snapshots the interrupted CPU state under `6D65..6D87`, computes the
context checksum, runs retained cleanup, writes `0xF8` to the RTC/control port
`0xDD`, and then loops forever.

```asm
irq_f8_save_suspend_C000_03AE:
; file 0x403AE
C000:03AE  1E                push ds
C000:03AF  50                push ax
C000:03B0  55                push bp
C000:03B1  8C DD             mov  bp,ds
C000:03B3  B8 00 00          mov  ax,0
C000:03B6  8E D8             mov  ds,ax
C000:03B8  B0 80             mov  al,0x80
C000:03BA  E6 90             out  0x90,al
C000:03BC  83 3E 09 68 01    cmp  word [0x6809],byte +1
C000:03C1  74 67             jz   reuse_saved_target_C000_042A
C000:03C3  81 3E 09 68 9519  cmp  word [0x6809],0x1995
C000:03C9  74 5F             jz   reuse_saved_target_C000_042A

C000:03CB  89 2E 73 6D       mov  [0x6d73],bp    ; DS
C000:03CF  89 1E 67 6D       mov  [0x6d67],bx
C000:03D3  89 0E 69 6D       mov  [0x6d69],cx
C000:03D7  89 16 6B 6D       mov  [0x6d6b],dx
C000:03DB  89 36 6D 6D       mov  [0x6d6d],si
C000:03DF  89 3E 6F 6D       mov  [0x6d6f],di
C000:03E3  8C 06 75 6D       mov  [0x6d75],es
C000:03E7  8C 16 77 6D       mov  [0x6d77],ss
C000:03EB  8B EC             mov  bp,sp
C000:03ED  83 C5 06          add  bp,byte +0x06
C000:03F0  8B 46 00          mov  ax,[bp+0x00]   ; interrupted IP
C000:03F3  A3 79 6D          mov  [0x6d79],ax
C000:03F6  A3 85 6D          mov  [0x6d85],ax
C000:03F9  83 C5 02          add  bp,byte +0x02
C000:03FC  8B 46 00          mov  ax,[bp+0x00]   ; interrupted CS
C000:03FF  A3 7B 6D          mov  [0x6d7b],ax
C000:0402  A3 87 6D          mov  [0x6d87],ax
C000:0405  83 C5 02          add  bp,byte +0x02
C000:0408  8B 46 00          mov  ax,[bp+0x00]   ; FLAGS
C000:040B  A3 7F 6D          mov  [0x6d7f],ax
C000:040E  83 C5 02          add  bp,byte +0x02
C000:0411  89 2E 7D 6D       mov  [0x6d7d],bp    ; SP after interrupt frame
C000:0415  5D                pop  bp
C000:0416  89 2E 71 6D       mov  [0x6d71],bp
C000:041A  58                pop  ax
C000:041B  A3 65 6D          mov  [0x6d65],ax
C000:041E  E8 17 00          call checksum_saved_context_C000_0438
C000:0421  E8 59 00          call retained_cleanup_C000_047D
C000:0424  B0 F8             mov  al,0xf8
C000:0426  E6 DD             out  0xdd,al
C000:0428  EB FE             jmp  short C000:0428

reuse_saved_target_C000_042A:
C000:042A  A1 79 6D          mov  ax,[0x6d79]
C000:042D  A3 85 6D          mov  [0x6d85],ax
C000:0430  A1 7B 6D          mov  ax,[0x6d7b]
C000:0433  A3 87 6D          mov  [0x6d87],ax
C000:0436  EB F0             jmp  C000:0428
```

## Checksums And Cleanup

```asm
checksum_saved_context_C000_0438:
; file 0x40438
C000:0438  BE 65 6D          mov  si,0x6d65
C000:043B  B9 0F 00          mov  cx,0x000f
C000:043E  FC                cld
C000:043F  33 DB             xor  bx,bx
C000:0441  AD                lodsw
C000:0442  03 D8             add  bx,ax
C000:0444  E2 FB             loop C000:0441
C000:0446  89 1E 83 6D       mov  [0x6d83],bx
C000:044A  C3                ret

checksum_builtin_store_C000_044B:
; file 0x4044B
C000:044B  1E                push ds
C000:044C  B8 00 18          mov  ax,0x1800
C000:044F  8E D8             mov  ds,ax
C000:0451  E8 1A 00          call checksum_store_body_C000_046E
C000:0454  89 1E 06 00       mov  [0x0006],bx
C000:0458  1F                pop  ds
C000:0459  C3                ret

checksum_store_body_C000_046E:
C000:046E  BE 08 00          mov  si,0x0008
C000:0471  B9 FC 7F          mov  cx,0x7ffc
C000:0474  FC                cld
C000:0475  33 DB             xor  bx,bx
C000:0477  AD                lodsw
C000:0478  03 D8             add  bx,ax
C000:047A  E2 FB             loop C000:0477
C000:047C  C3                ret
```

`retained_cleanup_C000_047D` begins by disarming the F9 timer through
`C000:0B50`, reloading the auto-off countdown from `[6D31]` into `[680B]`, and
snapshotting the port `0x60` mirror at `[6D4F]` into `[6D50]`. The serial
cleanup tail continues beyond this slice and belongs with serial/power cleanup.

```asm
retained_cleanup_C000_047D:
; file 0x4047D
C000:047D  E8 D0 06          call C000:0B50
C000:0480  A1 31 6D          mov  ax,[0x6d31]
C000:0483  A3 0B 68          mov  [0x680b],ax
C000:0486  A0 4F 6D          mov  al,[0x6d4f]
C000:0489  A2 50 6D          mov  [0x6d50],al
C000:048C  F6 06 4F 6D 10    test byte [0x6d4f],0x10
C000:0491  75 ...            jnz  serial_cleanup_tail
```

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:0376`, `C000:0784`, `C000:0807` | `rtc-alarm-power.md` | Alarm selection, fallback re-arm, and wake discriminator. |
| `C000:047D` tail | `serial-power-cleanup.md` | Serial cleanup behavior shares state with RS-232 IRQ/services. |
| `C000:4961`, `C000:49C2`, `C000:4A8D` | `idle-power.md` | Foreground idle loops that consume `[6809]=1992` and auto-off countdown state. |
