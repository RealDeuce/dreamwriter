# WP CLEAR TEXT

This slice expands the word-processor top-menu `CLEAR TEXT` handler reached
from [`top-icon-menus.md`](top-icon-menus.md). No new bitmap assets are reached;
the top-menu `CLEAR TEXT` icon is already rendered beside its descriptor in
[`top-icon-menus.md`](top-icon-menus.md#word-processor-icon-table).

## Far Wrapper

`DC98:2807` far-calls `C688:EB46` when the user selects top-menu item `3`.
The wrapper is the same C688 app-wrapper pattern used by the FILE, PRINTER, and
COMMUNICATE handlers: save caller registers, set `ES=0A4F`, call the local
worker, then return `[794A]` as a zero-extended `AX`.

```asm
wp_clear_text_wrapper_C688_EB46:
; file 0x553C6
C688:EB46  51                push cx
C688:EB47  52                push dx
C688:EB48  56                push si
C688:EB49  57                push di
C688:EB4A  55                push bp
C688:EB4B  BD 4F 0A          mov  bp,0x0a4f
C688:EB4E  8E C5             mov  es,bp
C688:EB50  E8 24 01          call C688:EC77
C688:EB53  5D                pop  bp
C688:EB54  5F                pop  di
C688:EB55  5E                pop  si
C688:EB56  5A                pop  dx
C688:EB57  59                pop  cx
C688:EB58  A0 4A 79          mov  al,[0x794a]
C688:EB5B  B4 00             mov  ah,0
C688:EB5D  CB                retf
```

## Prompt And Clear

`C688:EC77` displays resource ID `0x08`, waits for one response key, and accepts
only `Y`/`y` as confirmation. `0x03` and `N`/`n` return immediately. Other
non-`Y` keys redraw the prompt and ask again.

```asm
wp_clear_text_worker_C688_EC77:
; file 0x554F7
C688:EC77  BE 08 00          mov  si,0x0008
C688:EC7A  E8 07 02          call C688:EE84       ; display prompt/read key
C688:EC7D  3C 03             cmp  al,0x03
C688:EC7F  74 1D             jz   clear_text_return_C688_EC9E
C688:EC81  0C 20             or   al,0x20
C688:EC83  3C 6E             cmp  al,'n'
C688:EC85  74 17             jz   clear_text_return_C688_EC9E
C688:EC87  E8 F7 02          call C688:EF81       ; AL |= 20h; compare 'y'
C688:EC8A  75 EB             jnz  C688:EC77
C688:EC8C  E8 D7 8A          call C688:7766       ; rebuild empty editor state
C688:EC8F  32 C0             xor  al,al
C688:EC91  BE 09 00          mov  si,0x0009
C688:EC94  E8 53 AA          call C688:96EA       ; display confirmation + delay
C688:EC97  BE 00 8E          mov  si,0x8e00
C688:EC9A  32 C0             xor  al,al
C688:EC9C  88 04             mov  [si],al
clear_text_return_C688_EC9E:
C688:EC9E  C3                ret
```

Helper boundaries:

| Helper | Current read |
| --- | --- |
| `C688:EE84` | Displays the resource selected by `SI`, enters the one-byte selection/input helper, and returns `[794A]` unless `[794A] == 0xFF`, in which case it returns `[7812]`. |
| `C688:EF81` | Case-folds `AL` with `OR 0x20` and returns zero flag set only for `Y`/`y`. |
| `C688:7766` | Existing boot/update sequence used here to rebuild the editor/display state after clearing. |
| `C688:96EA` | Displays the selected resource through `C688:7689`, then runs a short delay loop. |

The final store to `[8E00]=0` marks the active editor buffer/state as empty
after the redraw and confirmation message.

## String Resources

`C688:EE84`/`C688:96EA` reach these through the `C688:7689` and `C688:9541`
screen-resource loader. The resource table is at segment `D59C`, file
`0x559C0`; table entry `n` is the word at `0x559C4 + n * 2`, and the resource
payload begins two bytes after that entry's target offset.

Resource `0x08`:

```text
D59C table[0x08] = 0x01A1
file 0x55B61:
u16 payload_length = 0x0047
display payload at file 0x55B63
40 00 00 DF 39
0C 1F 1A F8 "CLEAR TEXT" F9 " in work memory"
0C 0C 0C 1F 1C "Are you sure? (Y/N):"
E9 1C 30 00 E9 10 E9 1C 7A 00 E9
```

Final formatted text:

```text
CLEAR TEXT in work memory

Are you sure? (Y/N):
```

Resource `0x09`:

```text
D59C table[0x09] = 0x01EA
file 0x55BAA:
u16 payload_length = 0x0029
display payload at file 0x55BAC
40 00 00 DF 39
0C 0C 0C 1F 17 "Text in work memory was cleared"
62 00
```

Final formatted text:

```text
Text in work memory was cleared
```

`40 00 00 DF 39`, `0C`, `1F`, `F8/F9`, `E9 ...`, and trailing `62 00` are
screen/resource controls rather than literal text in the final display.

## Bottom

This handler bottoms out locally. The only live descendants are the shared C688
screen-resource loader/input helpers and the already-known editor redraw/update
sequence at `C688:7766`; it does not enter FILE, PRINTER, COMMUNICATE,
diagnostic, or spell-engine paths.
