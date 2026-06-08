# C000 Serial I/O and DreamLink

Serial communication and DreamLink endpoint handling at
`C000:3000..3600` (96 blocks). Provides the serial data
transport used by INT 21h file operations for DreamLink
storage endpoints.

See [`int21-file-io.md`](int21-file-io.md) for the file
handlers that call these routines.

## Entry Points

| Address | Caller | Purpose |
| --- | --- | --- |
| `C000:3F47` | Far-call table `[023C]` (#15) | Serial input wrapper: calls `C000:316D`, returns AH=0. |
| `C000:3168` | `C000:62F6` (INT 21h AH=03h) | Serial input (aux read) |
| `C000:3396` | `C000:0676` | Output buffer management |
| `C000:30D1` | internal | Serial buffer check |
| `C000:3528` | internal | Serial data transfer |

## C000:3168 — Serial Input Handler

Called from the INT 21h AH=03h (aux input) stub. Checks DreamLink
endpoint status via `C000:0D42` (`[6F51]==0x0A`), reads from the
serial buffer at `[16D0..16D1]`, transfers data via `C000:3528`,
and calls `C000:0E92` for completion.

```asm
C000:3168  E8D7DB         call C000:0D42       ; DreamLink endpoint check
C000:316B  751E           jnz 318B             ; not DreamLink -> skip
C000:316D  E861FF         call C000:30D1       ; buffer check
C000:3170  721C           jc 318E              ; error
C000:3172  FA             cli                  ; disable interrupts
C000:3173  A0D016         mov al,[16D0]        ; read pointer
C000:3176  3A06D116       cmp al,[16D1]        ; write pointer
C000:317A  FB             sti
C000:317B  75DC           jnz 3159             ; data available
C000:317D  E8A803         call C000:3528        ; transfer data
```

## C000:3396 — Output Buffer Manager

Circular buffer management for serial output. Buffer at
`[149B..15xx]` with write pointer at `[16D3]` and read counter
at `[16D4]`. Wraps at 255 (0xFF), stops accepting data when
buffer has fewer than 32 (0x20) bytes free.

```asm
C000:3396  8A1ED316       mov bl,[16D3]        ; write pointer
C000:339C  88879B14       mov [bx+149B],al     ; store byte
C000:33A2  FEC3           inc bl               ; advance
C000:33A4  3ADE           cmp bl,dh            ; wrap check (FF)
C000:33A8  32DB           xor bl,bl            ; wrap to 0
C000:33AA  881ED316       mov [16D3],bl        ; update pointer
; ...
C000:33BE  80FE20         cmp dh,20            ; 32 bytes free?
C000:33C1  7601           jna 33C4             ; full -> stop
```

## Serial Buffer State

| Address | Purpose |
| --- | --- |
| `[149B..15xx]` | Serial output buffer (256 bytes circular) |
| `[16D0]` | Serial input read pointer |
| `[16D1]` | Serial input write pointer |
| `[16D3]` | Serial output write pointer |
| `[16D4]` | Serial output read counter |
| `[6F51]` | Current storage endpoint (0x0A = DreamLink) |
