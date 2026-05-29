# Hardware Confirmation Checklist

This is the board-inspection checklist for hypotheses that currently come from
ROM tracing and MAME behavior. Prefer non-invasive confirmation first: chip
markings, continuity, and passive probing. Use an oscilloscope or logic analyzer
only after identifying safe ground and signal points.

## Clocks And Dividers

| Item | Current model | How to confirm |
| --- | --- | --- |
| Main crystal | MAME uses `X301 = 19.66 MHz`; a likely exact value is `19.6608 MHz`. | Read the crystal can marking near the V20/clock logic. Photograph the marking and nearby divider ICs. If probing, measure the oscillator output with a high-impedance probe. |
| CPU clock | V20 runs at `X301 / 2`, about `9.83 MHz`. | Probe the CPU clock input, or trace the oscillator through divider logic to the V20 clock pin. |
| USART baud clock | Sound/serial model suggests `X301 / 64 = 307.2 kHz` if the crystal is `19.6608 MHz`, matching `19200 * 16`. | Identify the USART chip, then probe its RXC/TXC clock pins while changing baud-rate settings. Look for `307.2 kHz`, `153.6 kHz`, `76.8 kHz`, etc. depending on port `0x30` divider state. |
| Idle/F9 timer base | MAME currently models port `0x53` counts from `X301 / 20480`, about `960 Hz`; `0x60` counts produce 10 Hz. | Look for divider/counter ICs that could produce `960 Hz`, or probe candidate timer/IRQ lines. A 10 Hz wake visible at the CPU interrupt input may be one-shot/re-armed, not free-running. |
| Keyboard scan tick | MAME currently uses the same `X301 / 20480` base for keyboard row IRQs. | In keyboard idle, probe row-select or keyboard IRQ-related lines. Expected row ISR cadence is about `960 Hz`; full scans are about `960 / 11 = 87 Hz`. |

Hardware-shaped divider clues to look for: binary counters such as `4020`,
`4040`, `4060`, `4521`, `393`, `161`, or `163`, plus divide-by-5/decode logic
such as `390` or small glue logic. `20480 = 20 * 1024`, so it can be made from
a binary divider plus a small decimal stage.

## Interrupt And Power Control

| Item | Current model | How to confirm |
| --- | --- | --- |
| Port `0x53` timer latch | Firmware writes `0x0A`, `0x56`, and `0x60`; all observed waits use IRQ `F9` and `[6DA9] bit 0`. The latch value looks like a count, not a vector selector. | Probe writes around the suspected timer hardware if accessible. Confirm whether different latch values change only delay or also route a different interrupt. |
| Port `0x60` bit `0x02` | `C000:0B3C` clears it before arming the `0x53` timer; `C000:0B50` sets it when disarming. This is likely source control, not just an IRQ mask. | Trace port `0x60` latch outputs to interrupt/timer glue. Look for a line that gates or masks the timer source. |
| Port `0x61` keyboard control | Firmware writes only `0xFE` and `0xFF` to this port. `C000:106F` pulses `0xFE -> 0xFF` before row scanning; the row-scan ISR writes `0xFE` after repeated empty scans. | Trace port `0x61` latch output, especially bit 0, to keyboard matrix scan hardware or counter reset/enable pins. Confirm whether `0xFE` holds the scanner idle/reset and `0xFF` releases it. |
| Port `0x20` CSiMON handshake candidate | Normal DreamWriter startup writes `0x00`; the high-ROM CSiMON entry stub writes `0x20` after it is already executing. No retained power-off path writes it, and no ROM read/branch on this port has been found. | Trace port `0x20` latch output. Check whether bit `0x20` goes to monitor/fixture hardware, a ROM-emulator/serial-debug interface, a manufacturing indicator, or external glue that expects a "monitor active" handshake. |
| Port `0x70` power transition | Firmware only writes `0x01` to port `0x70`, and only immediately before a terminal loop. Auto-off, warm/diagnostic, and RTC alarm fallback routes converge there after retained-state checksum and RTC alarm preparation. | Trace port `0x70` latch output to power/reset glue. Confirm whether it cuts main power, requests reset, switches to retention power, or arms a power-control latch. |
| Power switch | Firmware evidence suggests retained suspend/resume paths involving IRQ `F8`, IRQ `FF`, auto-off, RTC alarm setup, reset/wake hardware, and port `0x70`. | Inspect the physical power switch: momentary vs latching, pole count, and routed nets. Trace switch pins to CPU reset, interrupt glue, power-control ICs/transistors, or keyboard matrix. |
| RTC alarm output | The retained power-transition helper scans scheduler and WORLD CLOCK daily-alarm data, programs RP5C01 mode 1 alarm registers, enables the alarm bit, then writes `0x01` to port `0x70` and loops. The ROM behavior strongly implies scheduled/daily alarm wake. | Trace the RTC alarm pin. Check whether it feeds interrupt glue, reset/power-control hardware, or both. Confirm whether scheduled alarms, daily alarms, and the current-minute+1 fallback wake the machine without a keypress. |
| Auto-off wake source | Auto-off decrements `[680B]` in foreground after `hlt` returns; the wake is probably the `0x53` timer/IRQ `F9` path. | With the machine idle, probe CPU interrupt and timer-related lines. Confirm whether the CPU wakes at roughly 10 Hz without key activity. |

## Core Devices

| Item | Current model | How to confirm |
| --- | --- | --- |
| CPU | NEC V20-class CPU. | Read the CPU part marking and package. |
| RTC | MAME maps `0xD0..0xDF` to Ricoh `RP5C01`; firmware treats `0xD0..0xDC` as BCD nibbles, and the `0xDD..0xDF` control writes match RP5C01 mode/test/reset behavior. | Read the RTC chip marking. Trace 32.768 kHz crystal, backup power, chip-select/control pins, and alarm output. Compare against the chip datasheet. |
| LCD controller | Firmware sends compact display command streams with `FF` opcodes; low-level code dynamically emits LCD command bytes. | Identify LCD controller or gate-array markings. Trace CPU/LCD bus control lines and LCD panel signals. |
| Keyboard matrix | Ten active-high rows in MAME, raw row bytes at `6D06..6D0F`. | Trace keyboard membrane connector pins. Confirm row/column count and whether rows are driven by a counter, latch, or controller. |
| Sound | Firmware writes a 16-bit divisor to `0x50/0x51`, gates with `0x52`; MAME uses a beeper. | Identify the speaker driver path. Probe the speaker node and the counter/latch feeding it. Confirm square-wave vs DAC-like/full-swing output and the base clock. |

## External I/O

| Item | Current model | How to confirm |
| --- | --- | --- |
| USART | Firmware programming matches an 8251/8251A-compatible USART, probably NEC uPD71051. Ports are `0xC0` data and `0xC1` status/control. | Read the serial chip marking. Trace RXD/TXD/RTS/CTS/DSR lines to the connector/level shifter. Confirm DTR duplicates RTS and no CD line is routed. |
| Port `0x30` control latch | Bits `0..2` likely select the USART baud-clock divider, bit `0x08` is a setup strobe candidate, bit `0x10` is RS-232 enable/setup state, bit `0x20` drives Centronics `-STB`, bit `0x80` is diagnostic-only so far, and bit `0x40` has no confirmed firmware use. | Trace the latch outputs. In particular, follow bits `0..3` to baud-clock/reset glue near the USART, bit `0x20` to the printer strobe path, and diagnostic bit `0x80` to any PCMCIA attribute/common-memory or communications glue. |
| RS-232 level shifting | MAME now wires the USART to an RS-232 port; hardware should include line drivers. | Identify MAX232-like or discrete level-shifter circuitry. Trace connector pins and handshake lines. |
| Centronics | Firmware outputs data on `0x40`, pulses port `0x30` bit `0x20` for `-STB`, tests `BUSY` on port `0xA0` bit `0x02`, and uses IRQ `FE` for `ACK`. | Trace printer connector pins for data, `-STB`, `BUSY`, `-ACK`, and whether `PE`/`SEL`/`ERROR` are connected to port `0xA0` bits or unused. |
| PCMCIA | MAME maps SRAM/ROM card windows and status lines; firmware uses card presence/access, write-protect, and card battery status. | Identify PCMCIA controller/glue, address/data bus connections, card-detect pins, BVD pins, write-protect, and any bank/window decode logic. |

## Memory And Storage

| Item | Current model | How to confirm |
| --- | --- | --- |
| Internal RAM size variants | Some ROM sets need bit-3 RAM window behavior; 160 KiB vs 128/256 KiB variants remain board-dependent. | Read SRAM chip markings and count packages. Convert chip capacity to total bytes. Trace chip-select/bank-select lines. |
| ROM size and banking | ROM is banked into 128 KiB CPU windows through ports `0x10..0x17`. | Read ROM package markings and capacity. Trace bank-select latch outputs to ROM address lines. |
| PCMCIA capacity behavior | Manual says up to 1 MiB; current format behavior detected about 512 KiB in MAME for tested card images. | Test real SRAM cards of known capacities. Probe bank/window select lines during card format and copy operations. |
| Backup power | Main, CR2032 retention, and PCMCIA SRAM-card battery warnings are mapped through port `0xA0` bits. | Trace battery terminals through comparators/gates to CPU input logic. Confirm threshold circuitry and polarity. |

## Battery And Status Inputs

| Port `0xA0` bit | Current firmware interpretation | How to confirm |
| ---: | --- | --- |
| `0x01` | No confirmed firmware consumer found. | Trace anyway; it may be spare hardware status, an unused Centronics status line, or a model-specific input. |
| `0x02` | Centronics `BUSY`. | Trace to printer connector `BUSY`. |
| `0x04` | CR2032 memory-retention battery low when set. | Trace to backup-battery monitor. Carefully simulate low voltage only if the circuit is understood. |
| `0x08` | Main battery low when set. | Trace to main battery monitor/comparator. |
| `0x10` | PCMCIA SRAM-card battery warning path. | Trace to PCMCIA BVD/status pins. |
| `0x20` | No confirmed firmware consumer found. | Trace anyway; it may be spare hardware status, an unused Centronics status line, or a model-specific input. |
| `0x40` | Likely PCMCIA write-protect. | Trace to PCMCIA write-protect pin. |
| `0x80` | PCMCIA card presence/access gate; current polarity in MAME is card absent/high. | Trace to PCMCIA card-detect pins and any gating logic. |

## Useful Test Modes

| Mode | Use |
| --- | --- |
| Diagnostic chord `SPACE + F + J` at copyright screen | Keyboard matrix confirmation and memory dump access. |
| WP -> OTHERS -> SYSTEM -> sound type preview | Exercises buzzer ports `0x50..0x52`. |
| Organizer -> WORLD CLOCK | Exercises timer wake/RTC display behavior. Seconds should advance without keypresses. |
| WP editor held key | Exercises keyboard repeat timing. |
| WP -> PRINTER | Exercises Centronics strobe/BUSY/ACK paths. |
| WP -> COMMUNICATE -> SET UP/TERMINAL | Exercises USART, baud divider, and handshake lines. |
| WP -> FILE with SRAM card | Exercises PCMCIA card detect, write-protect, battery status, and memory banking. |
