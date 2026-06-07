# Word-Processor COMMUNICATE Handlers

This slice expands the `COMMUNICATE` submenu handler roots from
[`wp-submenus.md`](wp-submenus.md). The file-transfer entries share the same
FILE picker/name-entry UI layer documented in
[`wp-file-handlers.md`](wp-file-handlers.md), then hand off to the `C000`
transfer engine through the `C688:9364` far-call wrapper.

## Handler Roots

| Menu item | Icon | Wrapper | Inner root | File offset | Role |
| --- | --- | --- | --- | ---: | --- |
| `SEND FILE` | ![SEND FILE](images/wp-comm-send-file-1-0x6efc2.png) | `C688:EC24` | `C688:7F5A` | `0x4E7DA` | Pick a document and send it through RS-232C using the non-XMODEM stream path. |
| `SEND FILE` `(XMODEM)` | ![SEND FILE XMODEM](images/wp-comm-send-file-2-0x6f472.png) | `C688:EC3F` | `C688:811D` | `0x4E99D` | Pick a document and send it with the XMODEM packet path. |
| `RECEIVE FILE` | ![RECEIVE FILE](images/wp-comm-receive-file-1-0x6f08a.png) | `C688:EBF1` | `C688:7E3E` | `0x4E6BE` | Prompt for an output filename and receive through the non-XMODEM stream path. |
| `RECEIVE FILE` `(XMODEM)` | ![RECEIVE FILE XMODEM](images/wp-comm-receive-file-2-0x6f53a.png) | `C688:EC09` | `C688:8005` | `0x4E885` | Prompt for an output filename and receive with the XMODEM packet path. |
| `TERMINAL` | ![TERMINAL](images/wp-comm-terminal-0x6f152.png) | `C688:EC5A` | `C000:1089` | `0x41089` | Enter terminal mode through service `AH=07`. |

The file-transfer wrappers save registers, set `ES=0A4F`, call the inner
handler, restore registers, and return `AL=[794A]`, `AH=0`. The `SEND FILE`,
`SEND FILE (XMODEM)`, and `RECEIVE FILE (XMODEM)` wrappers call `C688:0013`
before their inner handlers.

```asm
; C688:EC3F / file 0x554BF, SEND FILE XMODEM wrapper
C688:EC3F  push cx
C688:EC40  push dx
C688:EC41  push si
C688:EC42  push di
C688:EC43  push bp
C688:EC44  mov  bp,0A4F
C688:EC47  mov  es,bp
C688:EC49  call C688:0013        ; serial-transfer storage-target preflight
C688:EC4C  call C688:811D        ; SEND FILE through RS-232C (XMODEM)
...
C688:EC52  mov  al,[794A]
C688:EC55  xor  ah,ah
C688:EC57  retf
```

The serial-transfer preflight rejects the DreamLink endpoint by silently
changing active target `0x0A` back to built-in target `0x08`.

```asm
; C688:0013 / file 0x46893
C688:0013  cmp  byte [6806],0A
C688:0018  jz   C688:0030
C688:001A  ret

C688:0030  mov  byte [6806],08
C688:0035  clc
C688:0036  ret
```

## Transfer Modes

The `C688` handlers select the visible resources, prepare the picker or
filename field, set a transfer mode byte at `[8294]`, and call `C688:9364` with
`AH=06`. `C688:9364` is a near wrapper around `C000:170E`, which dispatches to
the `C000:17ED` script interpreter and then into the transfer-engine command
table at `C000:1E33`.

| Flow | UI resources | `[8294]` | `AL` to `C688:788A` | Script pointer | Transfer engine |
| --- | --- | ---: | ---: | --- | --- |
| Receive, non-XMODEM | `0x8E`, `0x90`, `0x92` | unchanged / `0` | `0x07` | `C688:7F52` | `C000:22F3`, the serial stream receiver. |
| Receive, XMODEM | `0x91`, `0x8F`, `0x90`, `0x92` | `0x01` | `0x0C` | `C688:8115` | `C000:2702`, the XMODEM receiver. |
| Send, non-XMODEM | `0x93`, `0x95` | `0x02` | `0x08` | `C688:7F52` | `C000:2422`, the serial byte/escape sender. |
| Send, XMODEM | `0x94`, `0x95` | `0x03` | `0x0B` | `C688:7F52` | `C000:260D`, the XMODEM sender. |

`[8294] >= 2` changes IRQ `FC` receive handling: the serial ISR no longer
queues ordinary incoming bytes while the send paths are active. That keeps
foreground protocol reads in control of acknowledgements and flow-control
bytes.

## XMODEM Capability

The XMODEM sender and receiver are classic 128-byte, 8-bit-checksum XMODEM.
No evidence of XMODEM-1K or CRC mode appears in the reachable transfer engine.

The positive evidence is the live packet code:

```asm
; C000:260D / file 0x4260D, XMODEM send
C000:263B  mov  ah,03
C000:263D  int  21h
C000:2646  cmp  al,15          ; wait for NAK, not "C"
...
C000:264E  mov  dx,6C0B
C000:2651  mov  cx,0080        ; read exactly 128 payload bytes
C000:2655  mov  ah,3F
C000:2657  int  21h
...
C000:2660  cmp  ax,0080
C000:2665  mov  bx,ax          ; short final block
C000:266A  mov  byte [bx+si],1A ; pad with Ctrl-Z to 128 bytes
...
C000:2680  mov  byte [si],01   ; SOH
C000:2687  mov  [si+01],bh     ; block number
C000:268A  not  bh
C000:268C  mov  [si+02],bh     ; ones-complement block number
...
C000:2692  add  [6F28],dl      ; additive low-8 checksum
C000:2696  mov  ah,04
C000:2698  int  21h            ; send SOH, header, 128 data bytes
...
C000:26A6  mov  dl,[6F28]
C000:26AA  mov  ah,04
C000:26AC  int  21h            ; send one checksum byte
...
C000:26C2  cmp  al,06          ; ACK
C000:26C6  cmp  al,18          ; CAN
...
C000:26DA  mov  dl,04          ; EOT after EOF
```

```asm
; C000:2702 / file 0x42702, XMODEM receive
C000:2745  mov  dl,15
C000:2747  mov  ah,04
C000:2749  int  21h            ; request checksum mode with NAK
...
C000:279D  mov  [bx+6C08],al
C000:27A6  cmp  bl,84          ; 132-byte packet: 3 header + 128 data + checksum
C000:27AB  add  [6F28],al      ; sum first 131 bytes
...
C000:27B4  cmp  al,04          ; single-byte EOT
C000:27B8  mov  dl,06          ; ACK EOT
...
C000:27C8  cmp  al,[6F28]      ; compare received checksum byte
...
C000:27D7  cmp  byte [si],01   ; require SOH
C000:27DF  cmp  ah,[6F27]      ; expected block number
...
C000:27F5  mov  cx,0080
C000:2809  mov  dx,6C0B
C000:280D  mov  ah,40
C000:280F  int  21h            ; write exactly 128 payload bytes
C000:281D  mov  dl,06          ; ACK accepted block or duplicate block
```

The negative scan matches that reading. In `C000:1E00..2880`, the only block
size constants used by the transfer helpers are `0x80` payloads and `0x84`
packet length. There is no `mov/cmp 0x0400` transfer size, no STX sender or
receiver path for 1K blocks, and no literal `"C"` (`0x43`) handshake in the
XMODEM engine. The only checksum state is the low byte at `[6F28]`; there is no
CRC16 shift/xor loop or two-byte CRC compare in this slice.

The receive path does not appear to validate the ones-complement header byte
directly. It verifies SOH, the expected block number or one-block duplicate,
and the additive checksum. Because `SOH + block + ~block == 0 mod 256`, summing
the first 131 bytes gives the same checksum byte as summing only the 128 data
bytes for valid packets.

## Non-XMODEM Send

The first `SEND FILE` entry asks whether to convert a document to ASCII before
entering its stream sender. If conversion is accepted, `[6D51] bit 0x04` is set.
This is not a raw serial file dump. It always terminates the transmitted stream
with Ctrl-Z (`0x1A`) and it may encode control bytes or convert word-processor
markup before output.

```asm
; C688:7F5A / file 0x4E7DA
C688:7F5A  mov  si,0093
C688:7F5D  call C688:7689        ; SEND FILE through RS-232C
C688:7F60  call C688:81A1        ; directory/list setup
C688:7F63  call C688:9187        ; picker
...
C688:7F94  call C688:8263        ; "Convert to ASCII ?" prompt
C688:7F99  cmp  al,59           ; 'Y'
C688:7F9B  jnz  C688:7F9F
C688:7F9D  or   byte [6D51],04
...
C688:7FA8  mov  byte [8294],02
C688:7FAD  mov  al,08
C688:7FAF  call C688:788A
C688:7FB4  mov  si,7F52
C688:7FB7  mov  word [75EF],7516
C688:7FBE  mov  ah,06
C688:7FC0  call C688:9364
C688:7FC5  mov  byte [8294],00
```

The stream sender at `C000:2422` reads 128-byte chunks from the selected file
and emits bytes through `INT 21h AH=04`.

```asm
; C000:2422 / file 0x42422, non-XMODEM serial stream send
C000:245F  mov  bx,[6F19]
C000:2463  mov  dx,6C08
C000:2466  mov  cx,0080
C000:246A  mov  ah,3F
C000:246C  int  21h             ; read file chunk
...
C000:2474  or   ax,ax
C000:2476  jnz  C000:247B
C000:2478  jmp  C000:25DD      ; EOF -> send Ctrl-Z
```

For ordinary non-document bytes, control values below space are escaped as
`0x08` followed by the byte plus `0x60`; printable bytes are sent directly.

```asm
C000:24C2  cmp  dl,20
C000:24C5  jnc  C000:24D6      ; printable byte
C000:24C8  mov  dl,08
C000:24CA  mov  ah,04
C000:24CC  int  21h            ; escape prefix
...
C000:24D3  add  dl,60
C000:24D6  mov  ah,04
C000:24D8  int  21h            ; escaped or direct byte
```

If the file begins with internal document markers `0xFE` or `0xFF`, the sender
enters a document-aware state. Without ASCII conversion it still escapes control
bytes. With ASCII conversion enabled, it skips internal header/control payloads,
converts hard-return/form-feed-like document codes `0x0C` and `0xDB` to CR/LF,
emits printable `0x20..0xDF` bytes, and treats `0xE8`, `0xE9`, `0xEC`, `0xED`,
`0xEE`, and `0xEF` as multi-byte formatting controls rather than ordinary
bytes.

```asm
C000:249B  mov  byte [6F1F],01
C000:24A0  cmp  dl,FE
C000:24A3  jz   C000:24BD
C000:24A5  cmp  dl,FF
C000:24AA  mov  byte [6F1F],03
C000:24AF  test byte [6D51],04  ; ASCII conversion selected?
C000:24B6  or   byte [6F1F],80
...
C000:2555  cmp  dl,0C
C000:2558  jz   C000:257D
C000:255A  cmp  dl,DB
C000:255D  jz   C000:257D
C000:255F  cmp  dl,20
C000:2562  jc   C000:2571      ; drop low controls in document mode
C000:2564  cmp  dl,E0
C000:2567  jnc  C000:2596      ; formatting controls
...
C000:257D  mov  dl,0D
C000:2581  int  21h
C000:2587  mov  dl,0A
C000:258B  int  21h            ; document line break -> CR/LF
```

At end of file, the non-XMODEM sender closes the file and sends Ctrl-Z.

```asm
C000:25DD  call C000:2003      ; close file
C000:25E0  mov  dl,1A
C000:25E2  mov  ah,04
C000:25E4  int  21h
```

## XMODEM Send

The second `SEND FILE` entry uses the same picker shell but skips the ASCII
conversion prompt and selects mode `[8294]=3`.

```asm
; C688:811D / file 0x4E99D
C688:811D  mov  si,0094
C688:8120  call C688:7689        ; SEND FILE through RS-232C (XMODEM)
C688:8123  call C688:81A1
C688:8126  call C688:9187
...
C688:815B  mov  byte [8294],03
C688:8160  mov  al,0B
C688:8162  call C688:788A
C688:8167  mov  si,7F52
C688:816A  mov  word [75EF],7516
C688:8171  mov  ah,06
C688:8173  call C688:9364
C688:8178  mov  byte [8294],00
```

## Non-XMODEM Receive

The first `RECEIVE FILE` entry prompts for a filename, validates it, performs
the shared overwrite/secret-file prompts, then enters the stream receive path.
This path is closer to a plain serial capture than the sender, but it is not
completely raw: Ctrl-Z ends the receive, and the same `0x08` control-byte escape
can be decoded unless `[6D51]` bit `0x10` disables that filtering.

```asm
; C688:7E3E / file 0x4E6BE
C688:7E3E  mov  si,008E
C688:7E41  mov  ch,03
C688:7E43  call C688:EE9E
C688:7E46  call C688:81A8
...
C688:7E69  mov  si,0090
C688:7E6C  call C688:82FF        ; filename-entry field
...
C688:7E85  call C688:82A6        ; validate/normalize filename
...
C688:7F22  mov  si,0092
C688:7F25  call C688:7689        ; Receiving / count status
C688:7F28  call C688:7BC6
C688:7F2B  mov  al,07
C688:7F2D  call C688:788A
C688:7F32  mov  si,7F52
C688:7F35  mov  word [75EF],7516
C688:7F3C  mov  ah,06
C688:7F3E  call C688:9364
```

Mode `0x07` in the descriptor at `750F` reaches `C000:22F3`. The receiver
creates the output file, then repeatedly drains one serial byte through
`C000:5117` into a 128-byte buffer at `6C08`.

```asm
; C000:22F3 / file 0x422F3, non-XMODEM serial stream receive
C000:22F3  call C000:2603      ; DTA/buffer setup at 6C08
C000:22F6  mov  si,778E
C000:22F9  mov  cx,000C
C000:22FC  mov  di,6F03
C000:22FF  call C000:22AF      ; build target pathname
...
C000:2313  mov  ah,3C
C000:2315  int  21h            ; create/truncate output file
...
C000:2331  mov  cx,0000
C000:2334  mov  di,6C08
C000:2339  call C000:5117      ; blocking serial byte read/dequeue
C000:233C  call C000:288D      ; progress/display assist while idle
```

With filtering enabled, the receiver recognizes document/control lead bytes
`0xFE`/`0xFF`, stops on Ctrl-Z, and decodes the `0x08` escape form back to a
control byte by subtracting `0x60` from the following byte.

```asm
C000:2345  test byte [6D51],10
C000:234A  jnz  C000:237B      ; filter disabled: store byte as-is
...
C000:235F  cmp  al,FE
C000:2363  cmp  al,FF
...
C000:2373  cmp  al,08
C000:2375  jz   C000:23B1      ; next byte is escaped control
C000:2377  cmp  al,1A
C000:2379  jz   C000:2385      ; Ctrl-Z terminates receive
C000:237B  mov  [di],al
...
C000:23B1  mov  byte [6F20],FF ; remember escape prefix
...
C000:23B9  mov  byte [6F20],00
C000:23BE  sub  al,60
C000:23C0  jmp  C000:237B      ; store decoded control byte
```

The receiver writes each full 128-byte buffer, and on termination writes the
short final count before closing.

```asm
C000:237F  cmp  cx,0080
C000:2383  jc   C000:2337
C000:2385  mov  [6F1D],cx
...
C000:2396  mov  dx,6C08
C000:239B  mov  ah,40
C000:239D  int  21h            ; write captured bytes
...
C000:23A7  cmp  ax,0080
C000:23AC  jmp  C000:2331      ; continue only after a full block
C000:23AE  jmp  C000:20D9      ; short block: close/finish
```

## XMODEM Receive

The second `RECEIVE FILE` entry is structurally the same prompt/overwrite/secret
flow, but it uses the XMODEM text resource and mode `[8294]=1`.

```asm
; C688:8005 / file 0x4E885
C688:8005  mov  si,0091
C688:8008  call C688:7689        ; RECEIVE FILE through RS-232C (XMODEM)
C688:800B  mov  si,008F
C688:800E  mov  ch,02
C688:8010  call C688:EE9E
C688:8013  call C688:81A8
...
C688:80DB  mov  si,0092
C688:80DE  call C688:7689        ; Receiving / count status
C688:80E1  call C688:7BC6
C688:80E4  mov  byte [8294],01
C688:80E9  mov  al,0C
C688:80EB  call C688:788A
C688:80F0  mov  si,8115
C688:80F3  mov  word [75EF],7516
C688:80FA  mov  ah,06
C688:80FC  call C688:9364
C688:8101  mov  byte [8294],00
```

## Terminal

The terminal wrapper enters `C000:1089` through `C688:936A` and service
`AH=07`. The terminal loop initializes the serial hardware, polls translated
keys, maps a few editor/navigation keys to control bytes, sends printable bytes
through `INT 21h AH=04`, and drains received serial bytes through `C000:4B8D`.
There is no file-transfer framing here: this is interactive keyboard-to-serial
and serial-to-display behavior over the normal serial services.

```asm
; C688:EC5A / file 0x554DA
C688:EC5A  push cx
C688:EC5B  push dx
C688:EC5C  push si
C688:EC5D  push di
C688:EC5E  push bp
C688:EC5F  mov  bp,0A4F
C688:EC62  mov  es,bp
C688:EC64  mov  ah,07
C688:EC66  call C688:936A        ; C000:1712 -> service AH=07 -> C000:1089
C688:EC69  mov  [794A],al
...
C688:EC73  retf
```

The bottom is the shared serial layer: output uses `INT 21h AH=04` /
`C000:0D71` / `C000:0D96`, and input uses the IRQ `FC` receive queue drained by
`C000:4B8D`. Those primitives are expanded in
[`serial-services.md`](serial-services.md) and [`device-irq.md`](device-irq.md).

## Setup

The COMMUNICATE `SET UP` menu entry is not a transfer protocol path. It calls
the shared RS-232C setup editor at `DC98:22A1`, which is expanded in
[`setup-screens.md`](setup-screens.md). That editor changes the serial
configuration bytes `6D2A..6D2E`; the actual hardware programming is the shared
USART setup path documented in [`serial-services.md`](serial-services.md).

## Resource Descriptors

Resource IDs are looked up through the `C688` display-resource table. Payload
offsets below are ROM file offsets.

| ID | Table word | Payload | Length | Descriptor / final formatted text |
| ---: | ---: | ---: | ---: | --- |
| `0x0E` | `0x0318` | `0x55CDA` | `0x000F` | Yes/No choice descriptor, final labels `Yes` and `No`. |
| `0x0F` | `0x0329` | `0x55CEB` | `0x000F` | Yes/No choice descriptor, final labels `Yes` and `No`. |
| `0x10` | `0x033A` | `0x55CFC` | `0x0019` | Prompt text `Convert to ASCII ?`. |
| `0x36` | `0x114A` | `0x56B0C` | `0x003B` | Prompt text `File name already exists` / `Overwrite? (Y/N): <input>`. |
| `0x8D` | `0x22CE` | `0x57C90` | `0x0005` | Tiny display/status descriptor used by selected-file flag checks. |
| `0x8E` | `0x1FDB` | `0x5799D` | `0x0048` | `DIRECTORY` / `RECEIVE FILE through RS-232C` / `ENTER FILE NAME:`. |
| `0x8F` | `0x2025` | `0x579E7` | `0x006C` | Receive instructions: directory key, TAB changes Built-in/Card, select receives, CAN cancels. |
| `0x90` | `0x2093` | `0x57A55` | `0x0011` | Filename edit-field descriptor. |
| `0x91` | `0x20A6` | `0x57A68` | `0x0051` | `DIRECTORY` / `RECEIVE FILE through RS-232C (XMODEM)` / `ENTER FILE NAME:`. |
| `0x92` | `0x20F9` | `0x57ABB` | `0x0035` | Transfer status: `Receiving` / `Press any key to exit` / `count:`. |
| `0x93` | `0x2130` | `0x57AF2` | `0x00AE` | `DIRECTORY` / `SEND FILE through RS-232C`; picker instructions for select, TAB, and CAN. |
| `0x94` | `0x21E0` | `0x57BA2` | `0x00B7` | `DIRECTORY` / `SEND FILE through RS-232C (XMODEM)`; picker instructions for select, TAB, and CAN. |
| `0x95` | `0x2299` | `0x57C5B` | `0x0033` | Transfer status: `Sending` / `Press any key to exit` / `count:`. |
| `0x96` | `0x22D5` | `0x57C97` | `0x002C` | Prompt text `Do you want to make the file` / `as secret?`. |
| `0x97` | `0x2303` | `0x57CC5` | `0x000F` | Yes/No choice descriptor with `No` selected. |
| `0x98` | `0x2314` | `0x57CD6` | `0x000F` | Yes/No choice descriptor with `Yes` selected. |

Final visible strings:

```text
DIRECTORY
RECEIVE FILE through RS-232C

ENTER FILE NAME:
```

```text
DIRECTORY
RECEIVE FILE through RS-232C (XMODEM)

ENTER FILE NAME:
```

```text
Press <directory-key> for DIRECTORY
Press TAB to change Built-in or Card
Press <DA> to receive  Press CAN to cancel
```

```text
DIRECTORY
SEND FILE through RS-232C

Position cursor to a file
Press <DA> to send the file
Press TAB to change Built-in or Card
Press CAN to cancel
```

```text
DIRECTORY
SEND FILE through RS-232C (XMODEM)

Position cursor to a file
Press <DA> to send the file
Press TAB to change Built-in or Card
Press CAN to cancel
```

```text
Receiving

Press any key to exit

count:
```

```text
Sending

Press any key to exit

count:
```

```text
Convert to ASCII ?
```

```text
Do you want to make the file
as secret?

Yes    No
```

## Current Bottom

The COMMUNICATE submenu roots are now expanded to their protocol/file-transfer
bottoms without entering the broader printer application or unrelated document
handlers. Remaining nearby shared roots are the common document/list re-entry
targets already queued from [`app-menu-event-loop.md`](app-menu-event-loop.md)
and the `PRINTER -> PRINT OUT` application handler.
