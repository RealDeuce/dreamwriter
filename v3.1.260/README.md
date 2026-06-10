# DreamWriter T400 ROM 3.1.260 Notes

Working target: `t4_ir_3.1_8c8f.ic303`

```text
Size:   1048576 bytes
SHA256: 884787d0f69bff1869bb05c5a5c1a20aef57d519f6fd87a19caa5039c09912a2
SHA1:   5e93b97db045ae9399d04c69ea756d6ae9383bfe
CRC32:  5c062e52
```

This is a later 1 MiB T400 v3.1-family ROM. Its diagnostic banner string is
`Diagnostic 31BAB260    99Feb25`, while the earlier checked-in v3.1 image uses
`Diagnostic 31BAB218`.

The reset vector at file `0xFFFF0` jumps to `F733:0000`:

```asm
FFFF:0000  cli
FFFF:0001  jmp far F733:0000
```

The active disassembly notes remain in [`../v3.1/docs/`](../v3.1/docs/). They
use `t4_ir_3.1_e588.ic303` as the main address target, with 3.1.260 deltas
documented where checked.

Trace-disassembly setup for this image is in
[`docs/disassembly/README.md`](docs/disassembly/README.md).
