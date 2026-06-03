# Battery And Card Status Helpers

This slice follows the port `0xA0` helpers reached from
[`idle-power.md`](idle-power.md), [`storage-geometry.md`](storage-geometry.md),
and local/card storage write paths.

No image assets or string resources are reached in this slice. The rendered
battery-warning icons are shown in [`idle-power.md`](idle-power.md).

## Combined Warning Query

`C000:0A6A` returns a priority-coded warning value:

| Return `AL` | Meaning | Helper |
| ---: | --- | --- |
| `0` | No active warning. | common zero return at `C000:0A90`. |
| `1` | Main battery low. | `C000:0A93`. |
| `2` | CR2032 memory-retention battery low. | `C000:0AA4`. |
| `3` | PCMCIA SRAM-card battery low. | `C000:0AB2`. |

```asm
combined_battery_status_C000_0A6A:
; file 0x40A6A
C000:0A6A  E4 A0             in   al,0xa0
C000:0A6C  A8 80             test al,0x80
C000:0A6E  74 02             jz   card_present_for_warning_C000_0A72
C000:0A70  0C 10             or   al,0x10
C000:0A72  34 10             xor  al,0x10
C000:0A74  A8 1C             test al,0x1c
C000:0A76  74 18             jz   no_warning_C000_0A90
C000:0A78  E8 18 00          call main_battery_low_C000_0A93
C000:0A7D  B0 01             mov  al,0x01
...
C000:0A80  E8 21 00          call retention_battery_low_C000_0AA4
C000:0A85  B0 02             mov  al,0x02
...
C000:0A88  E8 27 00          call card_battery_low_C000_0AB2
C000:0A8D  B0 03             mov  al,0x03
```

When port `0xA0 bit 0x80` is set, the combined helper forces bit `0x10` high
before inverting the card-battery sense. That suppresses a card-battery warning
when the card is absent/not ready.

## Individual Battery Helpers

The individual low-battery helpers double-sample the relevant status bit.

```asm
main_battery_low_C000_0A93:
; file 0x40A93
C000:0A93  E4 A0             in   al,0xa0
C000:0A95  A8 08             test al,0x08
C000:0A97  74 F7             jz   no_warning_C000_0A90
C000:0A99  E4 A0             in   al,0xa0
C000:0A9B  A8 08             test al,0x08
C000:0A9D  74 F1             jz   no_warning_C000_0A90
C000:0A9F  32 C0             xor  al,al
C000:0AA1  FE C0             inc  al
C000:0AA3  C3                ret

retention_battery_low_C000_0AA4:
C000:0AA4  E4 A0             in   al,0xa0
C000:0AA6  A8 04             test al,0x04
C000:0AA8  74 E6             jz   no_warning_C000_0A90
C000:0AAA  E4 A0             in   al,0xa0
C000:0AAC  A8 04             test al,0x04
C000:0AAE  74 E0             jz   no_warning_C000_0A90
C000:0AB0  EB ED             jmp  C000:0A9F
```

The card-battery helper requires card-present/not-ready bit `0x80` clear and
card battery bit `0x10` clear on two reads.

```asm
card_battery_low_C000_0AB2:
C000:0AB2  E4 A0             in   al,0xa0
C000:0AB4  A8 80             test al,0x80
C000:0AB6  75 D8             jnz  no_warning_C000_0A90
C000:0AB8  A8 10             test al,0x10
C000:0ABA  75 D4             jnz  no_warning_C000_0A90
C000:0ABC  E4 A0             in   al,0xa0
C000:0ABE  A8 10             test al,0x10
C000:0AC0  75 CE             jnz  no_warning_C000_0A90
C000:0AC2  EB DB             jmp  C000:0A9F
```

## Card Access And Write-Protect

Two short helpers expose card state to storage code:

```asm
card_access_check_C000_0AC4:
; file 0x40AC4
C000:0AC4  50                push ax
C000:0AC5  E4 A0             in   al,0xa0
C000:0AC7  A8 80             test al,0x80
C000:0AC9  58                pop  ax
C000:0ACA  F8                clc
C000:0ACB  75 0B             jnz  card_status_carry_C000_0AD8
C000:0ACD  C3                ret

card_write_protect_C000_0ACE:
C000:0ACE  50                push ax
C000:0ACF  E4 A0             in   al,0xa0
C000:0AD1  A8 40             test al,0x40
C000:0AD3  58                pop  ax
C000:0AD4  F8                clc
C000:0AD5  75 01             jnz  card_status_carry_C000_0AD8
C000:0AD7  C3                ret

card_status_carry_C000_0AD8:
C000:0AD8  F9                stc
C000:0AD9  C3                ret
```

`C000:0AC4` sets carry when bit `0x80` is set. `C000:0ACE` sets carry when bit
`0x40` is set.

## Port `0xA0` Current Read

| Bit | Firmware interpretation |
| ---: | --- |
| `0x02` | Centronics `BUSY`, consumed by printer output. |
| `0x04` | CR2032 retention battery low, active high. |
| `0x08` | Main battery low, active high. |
| `0x10` | PCMCIA SRAM-card battery status, active-low low-battery indication when card-present bit permits. |
| `0x40` | SRAM-card write-protect. |
| `0x80` | SRAM-card absent/not-ready gate. |

Bits `0x01` and `0x20` still have no confirmed firmware consumer in the reached
paths.

## Attribute-Space Note

These helpers are status-bit tests only. The card formatter and local storage
paths use them before common-memory access; they do not select or parse PCMCIA
attribute memory.
