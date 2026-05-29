# Banked Spell/Linguistic Service

The banked routine at `3000:0000` is a service thunk into the spelling /
linguistic engine region. It is reached through the `C000:18A1` banked far-call
helper described in [`banking.md`](banking.md).

## Thunk

`C000:18A1` remaps CPU `3000:0000` to ROM file `0x30000`, then calls far
pointer `C000:189A`, which contains `3000:0000`.

The target routine starts at file `0x30000`:

```asm
3000:0000  cld
3000:0001  push si
3000:0002  push es
3000:0003  push ds
3000:0004  push bp
3000:0005  mov cx,ss
3000:0007  mov bx,sp
3000:0009  mov bp,3C00
3000:000C  mov es,bp
3000:000E  mov ds,bp
3000:0010  mov ss,bp
3000:0012  add sp,4000
...
3000:0018  add si,4000
3000:001C  push si
3000:001D  mov ax,dx
3000:001F  push ax
3000:0021  call 3000:4AA6
```

It switches `DS`, `ES`, and `SS` to segment `3C00`, passes two arguments to
`3000:4AA6`, then restores the caller's stack and returns far. Before return it
loads `DX` from `[3C00:6BD8]`, exchanges `AX` and `DX`, and returns that value
to the caller.

Arguments observed so far:

| Caller | Service ID | Buffer argument | Notes |
| --- | ---: | --- | --- |
| `C000:02A8` | `0x3C` | `6A06 + 4000` | Startup/service initialization path via `C000:189E`. |
| `C000:02B0` | `0x01` | `6A06 + 4000` | Cold boot sequence path. |
| `C000:02B8` | `0x00` | `6A06 + 4000` | Cold boot sequence path. |
| `C000:12FB` | `0x58` | caller-dependent `SI + 4000` | Diagnostic `Q` command, documented as clear spell. |
| `C000:15F1` | `0x59` | caller-dependent `SI + 4000` | Diagnostic `R` command path, documented as reset spell. |

## Dispatcher

`3000:4AA6` is a service dispatcher. It rejects service IDs above `0x59`, then
uses a word jump table at file `0x34C0A`:

```asm
3000:4AA6  mov word [6BD8],0000
3000:4AB2  mov ax,[bp+04]        ; service ID
3000:4AB5  cmp ax,0059
3000:4AB8  ja 3000:4C02          ; return FFFF
3000:4ABD  add ax,ax
3000:4ABF  xchg ax,bx
3000:4AC0  jmp [cs:bx+4C0A]
```

Confirmed dispatch entries:

| Service ID | Jump target | Evidence |
| ---: | --- | --- |
| `0x00` | `3000:4AC6` | Called by `C000:02B8` during cold boot sequence. |
| `0x01` | `3000:4ACC` | Called by `C000:02B0` during cold boot sequence. |
| `0x3C` | `3000:4BC2` | Called through `C000:189E`, which adds `0x3C` to `DL`. |
| `0x3D` | `3000:4BCA` | Same `C000:189E` path when caller provides `DL = 1`. |
| `0x58` | `3000:4BF2` | Diagnostic `Q` command. |
| `0x59` | `3000:4BFA` | Diagnostic `R` command. |

`0x58` and `0x59` are the diagnostic help text's `Q/R=Clear/Reset spell`
commands:

```asm
C000:12F8  mov dl,58
C000:12FB  call C000:18A1
...
C000:1301  mov dl,59
C000:1303  call C000:15F0
C000:15F1  call C000:18A1
```

The corresponding dispatch targets run a service body, then fall into the
common dispatcher epilogue:

```asm
3000:4BF2  call 3000:4CF4
3000:4BF5  mov sp,bp
3000:4BF7  pop bp
3000:4BF8  ret

3000:4BFA  call 3000:4D1A
3000:4BFD  mov sp,bp
3000:4BFF  pop bp
3000:4C00  ret
```

## Local State

The engine uses `3C00` as its data/stack segment during calls. Some state
addresses visible in the dispatcher and nearby routines:

| Address | Observed use |
| ---: | --- |
| `3C00:6000` | Engine status flag toggled by dispatcher services. |
| `3C00:6002` | Mode flag set/cleared by service cases around `3000:4B50`. |
| `3C00:6004` | Count-like value returned by one dispatch case. |
| `3C00:6BD8` | Return/status word copied back to caller as `AX`. |
| `3C00:6BDA..6BE6` | Scratch/status words used by parser/search routines. |
| `3C00:8EE2` | Pointer into a small parse/output structure. |
| `3C00:8EEC` | Mode flag used by service routines around `3000:4DA8`. |
| `3C00:966C` | Callback/function pointer invoked by parser path at `3000:0224`. |

## Working Interpretation

The code around `3000:46FC..4BFA` has spelling/linguistic behavior:

- It processes character streams through tables at offsets like `3000:09D8`,
  `3000:116A`, and `3000:12E4`.
- It tracks word/parser state around `3C00:6D7A`, `6D7C`, `6D80`, and `6DA4`.
- It exposes diagnostic clear/reset services through IDs `0x58` and `0x59`.

This is enough to call `3000:0000` the banked spell/linguistic service thunk.
Individual service IDs still need names beyond the confirmed diagnostic and
startup cases.
