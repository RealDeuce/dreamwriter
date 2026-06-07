# DEF0 File Services

File and storage service wrappers in the DEF0 segment. Far-call table
entries #16-#38 are file services. Many share a common core routine at
`DEF0:DFD5`.

See [`int21-file-io.md`](int21-file-io.md) for the underlying C000
INT 21h file handlers these eventually call.

## Far-Call Table File Entries

| # | RAM addr | Target | Calls | Purpose |
| ---: | --- | --- | --- | --- |
| 16 | `[0240]` | `DEF0:DAD6` | — | File service (standalone). |
| 17 | `[0244]` | `DEF0:DB47` | `DEF0:E14C` | File service. |
| 18 | `[0248]` | `DEF0:E022` | `DEF0:DFD5` | File op via core. |
| 19 | `[024C]` | `DEF0:DC5E` | `DEF0:E08C` | File op via E08C helper. |
| 20 | `[0250]` | `DEF0:E048` | `DEF0:DFD5` | File op via core. |
| 21 | `[0254]` | `DEF0:E05A` | `DEF0:DFD5` | File op via core. |
| 22 | `[0258]` | `DEF0:E05A` | `DEF0:DFD5` | Same as #21 (duplicate entry). |
| 23 | `[025C]` | `DEF0:E070` | — | File service (standalone). |
| 24 | `[0260]` | `DEF0:E08C` | `DEF0:DFD5` | File helper (also called by #19, #27, #28). |
| 25 | `[0264]` | `DEF0:E0A4` | `DEF0:DFD5` | File op via core. |
| 26 | `[0268]` | `DEF0:DCA2` | — | File service (standalone). |
| 27 | `[026C]` | `DEF0:DD27` | `DEF0:E08C` | File op via E08C helper. |
| 28 | `[0270]` | `DEF0:DE34` | `DEF0:E0A4,E08C` | File op via both helpers. |
| 29 | `[0274]` | `DEF0:E0C0` | — | File service (standalone). |
| 30 | `[0278]` | `DEF0:DE90` | — | File service (standalone). |
| 31 | `[027C]` | `DEF0:DF1C` | — | File service (standalone). |
| 32 | `[0280]` | `DEF0:E1F0` | `DEF0:DFD5` | File op via core. |
| 33 | `[0284]` | `DEF0:E195` | `DEF0:DFD5` | File op via core. |
| 34 | `[0288]` | `DEF0:E1B4` | `DEF0:DFD5` | File op via core. |
| 35 | `[028C]` | `DEF0:E21A` | — | File service (standalone). |
| 36 | `[0290]` | `DEF0:E232` | — | File service (standalone). |
| 37 | `[0294]` | `DEF0:E254` | `DEF0:DFD5` | File op via core. |
| 38 | `[0298]` | `DEF0:E26C` | `DEF0:DFD5` | File op via core. |

## Entry #39 — Display + File Composite

| # | RAM addr | Target | Calls | Purpose |
| ---: | --- | --- | --- | --- |
| 39 | `[029C]` | `DEF0:57EF` | `C000:3F35,DEF0:0DF5,DEF0:51FD,DEF0:53C0` | Combined display render and file init. |

## DEF0:DFD5 — File Service Core

The shared core routine called by 13 of the 23 file service entries.
Checks AX against known operation codes (0x15 → set `[110F]=0x0D`,
0x50 → set `[110F]=0x11`, 0x20/0x21 → use `[F6E0:BX+0x0E]` lookup,
others → clamp to 0x13 and look up from segment `F6E0`). Stores
the resolved operation mode to `[110F]` and returns. Callers set up
AX=operation, BX=handle/path, CX=count, DX=buffer before the call.

Called by entries: #18, #20, #21, #22, #24, #25, #32, #33, #34, #37, #38,
and also indirectly through `DEF0:E08C` (#19, #27, #28) and
`DEF0:E0A4` (#25, #28).

## DEF0:E08C — File Helper

Secondary shared helper called by entries #19, #24, #27, #28. Calls
`DEF0:DFD5` internally, adding pre/post-processing around the core.

33 callers total in the trace — the second most-called DEF0 routine
after the display wrappers.

## DEF0:DCA2 — Standalone File Service (#26)

One of the standalone entries that doesn't use the `DFD5` core.
Calls `DEF0:E08C` with AX=0, BX=0, CX=0, DX=0, BX=1 — a single-file
query operation that reads the result into `[BP-4]`/`[BP-2]`.

## Address Range

The file services cluster at `DEF0:DA00..E2AA`:

- `DEF0:DAD6..DC5E` — entries #16-#19
- `DEF0:DCA2..DF1C` — entries #26-#31
- `DEF0:DFD5..E0C0` — shared core + helpers
- `DEF0:E0C0..E2AA` — entries #29, #32-#38

Plus `DEF0:57EF` (entry #39) which is in a separate cluster.

## Relationship to C000 INT 21h

The DEF0 file services are a higher-level API on top of the C000
INT 21h file operations:

```text
C772 app code
  -> far-call table [0240..029C]
    -> DEF0 file service wrappers
      -> DEF0:DFD5 core / DEF0:E08C helper
        -> INT 21h (AH=3C/3D/3E/3F/40/41/42/43/44/4E/4F/56/57)
          -> C000 file handler stubs
            -> C000 file implementation routines
```

The DEF0 layer adds:
- Handle management (mapping app-level handles to INT 21h handles)
- Error display (rendering error messages via display services)
- State tracking (updating `[A022..A342]` file handle table)
- DreamWriter-specific file format handling
