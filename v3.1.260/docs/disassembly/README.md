# ROM 3.1.260 Disassembly

Use the `v31-260` trace profile in `tools/trace_boot.py`. It keeps the same
recursive tracer used for v3.1, but selects the shifted 3.1.260 segment map and
dispatch-table offsets:

```sh
python3 tools/trace_boot.py --profile v31-260 \
  --irqs --thunks --int21 --menu-vm --dispatch \
  > v3.1.260/docs/disassembly/trace-full.txt
```

The tracer can also be run incrementally. Load an existing trace first, then add
new seed families:

```sh
python3 tools/trace_boot.py --profile v31-260 \
  --load v3.1.260/docs/disassembly/trace-full.txt \
  --dispatch \
  > /tmp/trace-full.next.txt
```

Current 3.1.260 profile landmarks:

| Role | Segment / Offset |
| --- | --- |
| Boot entry | `C000:0029` |
| Application entry | `C774:0006` / `C774:000A` |
| Service layer | `DF80` |
| Menu VM table | `C774:396E` |
| INT 21h validity / dispatch tables | `C000:61E8` / `C000:6248` |
| Display command table | `C000:687B` |
| Extended blit table | `C000:7437` |

Repair-focused startup notes:

- [`boot-storage-init.md`](boot-storage-init.md) tracks the cold-start path,
  built-in storage formatter, `0..160` progress counter, and the post-counter
  `DF80:58F8` cold service init.
