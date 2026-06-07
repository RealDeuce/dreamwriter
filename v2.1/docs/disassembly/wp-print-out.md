# WP PRINT OUT

This slice expands the word-processor `PRINTER -> PRINT OUT` handler reached
from [`wp-submenus.md`](wp-submenus.md). The submenu bitmap asset is already
rendered there as the
[`PRINT OUT` icon](images/wp-printer-0x6e662.png); this handler path reaches
screen-resource prompts and print-state code rather than a new fixed bitmap.

## Far Wrapper

The `PRINTER` submenu calls `C688:EB5E` for item `1`. The wrapper follows the
same C688 application-wrapper shape used by FILE and CLEAR TEXT handlers:
preserve caller registers, set `ES=0A4F`, call the local worker, then return
the last event byte `[794A]` in `AX`.

```asm
wp_print_out_wrapper_C688_EB5E:
; file 0x553DE
C688:EB5E  51                push cx
C688:EB5F  52                push dx
C688:EB60  56                push si
C688:EB61  57                push di
C688:EB62  55                push bp
C688:EB63  BD 4F 0A          mov  bp,0x0a4f
C688:EB66  8E C5             mov  es,bp
C688:EB68  E8 3B BF          call C688:AAA6
C688:EB6B  5D                pop  bp
C688:EB6C  5F                pop  di
C688:EB6D  5E                pop  si
C688:EB6E  5A                pop  dx
C688:EB6F  59                pop  cx
C688:EB70  A0 4A 79          mov  al,[0x794a]
C688:EB73  B4 00             mov  ah,0
C688:EB75  CB                retf
```

## Print-Range Front End

`C688:AAA6` is the actual `PRINT OUT` application entry. It seeds a broad page
range, enables print/editor mode bits, runs document readiness/setup helpers,
and either waits on a cancel-style prompt or enters the print range UI.

```asm
wp_print_out_flow_C688_AAA6:
; file 0x51326
C688:AAA6  C7 06 13 78 01 00 mov  word [0x7813],0x0001
C688:AAAC  C7 06 15 78 E7 03 mov  word [0x7815],0x03e7
C688:AAB2  C7 06 0F 79 01 00 mov  word [0x790f],0x0001
C688:AAB8  80 26 B3 8D 7D    and  byte [0x8db3],0x7d
C688:AABD  80 0E B3 8D 01    or   byte [0x8db3],0x01
C688:AAC2  E8 4B DB          call C688:8610
C688:AAC5  E8 9B A4          call C688:4F63
C688:AAC8  9F                lahf
C688:AAC9  50                push ax
C688:AACA  E8 F7 99          call C688:44C4
C688:AACD  58                pop  ax
C688:AACE  9E                sahf
C688:AACF  73 0F             jnc  print_range_screen_C688_AAE0
C688:AAD1  BE 35 00          mov  si,0x0035
C688:AAD4  E8 AD 43          call C688:EE84
C688:AAD7  3C 0B             cmp  al,0x0b
C688:AAD9  74 04             jz   print_out_return_C688_AADF
C688:AADB  3C 03             cmp  al,0x03
C688:AADD  75 F2             jnz  C688:AAD1
print_out_return_C688_AADF:
C688:AADF  C3                ret
```

On the normal path, resource `0x0A` draws the `PRINT TEXT` screen with `FROM
PAGE`, `TO PAGE`, `PAGE NUMBERING? (Y/N)`, and `MERGE? (Y/N)` fields. The flow
uses `[75EF]` as an inline descriptor/dispatch pointer, initially `0xAA96`,
then adjusts that pointer as the user advances through fields.

```asm
print_range_screen_C688_AAE0:
C688:AAE0  E8 5D 46          call C688:F140
C688:AAE3  BE 0A 00          mov  si,0x000a
C688:AAE6  B5 03             mov  ch,0x03
C688:AAE8  E8 B3 43          call C688:EE9E
C688:AAEB  C7 06 EF 75 96 AA mov  word [0x75ef],0xaa96
...
C688:AB0E  80 3E 4A 79 13    cmp  byte [0x794a],0x13
C688:AB13  75 08             jnz  C688:AB1D
C688:AB15  83 06 EF 75 02    add  word [0x75ef],byte +0x02
C688:AB1A  E9 70 E7          jmp  C688:928D
C688:AB1D  80 3E 4A 79 DA    cmp  byte [0x794a],0xda
C688:AB22  75 F6             jnz  C688:AB1A
C688:AB24  BE 0D 00          mov  si,0x000d
C688:AB27  E8 5F CB          call C688:7689
C688:AB2A  E8 0A 00          call C688:AB37
C688:AB2D  3C 59             cmp  al,'Y'
C688:AB2F  75 03             jnz  C688:AB34
C688:AB31  E9 65 01          jmp  C688:AC99
C688:AB34  E9 6F FF          jmp  C688:AAA6
```

`C688:AB37` is the yes/no selector used after the `PRINT START ?` prompt. It
draws resource `0x0E` with `Y` selected and resource `0x0F` with `N` selected;
left/right events `0x11` and `0x10` toggle the default byte in `[7555]`, select
`0xDA` returns the chosen `Y`/`N`, and cancel `0x03` returns `N`.

## Merge And Output Path

When the user confirms print start, `C688:AC99` begins the output path. It marks
`[7817]=1` through `C688:ACAF`, sets bit `0` at `[77F1]`, and then displays
resource `0x1A`, whose visible text is `PRINT TEXT`, `PRINTING`, and the pause
or cancel instructions.

```asm
print_confirmed_C688_AC99:
; file 0x51519
C688:AC99  E8 50 E4          call C688:90EC
C688:AC9C  E8 1D BD          call C688:69BC
C688:AC9F  E8 0D 00          call C688:ACAF
C688:ACA2  E8 FF 63          call C688:10A4
C688:ACA5  BE 1A 00          mov  si,0x001a
C688:ACA8  B5 02             mov  ch,0x02
C688:ACAA  E8 F1 41          call C688:EE9E
C688:ACAD  EB 56             jmp  C688:AD05

set_print_active_C688_ACAF:
C688:ACAF  C7 06 17 78 01 00 mov  word [0x7817],0x0001
C688:ACB5  BE F1 77          mov  si,0x77f1
C688:ACB8  80 0C 01          or   byte [si],0x01
C688:ACBB  C3                ret
```

The sibling entry at `C688:ACBC` is reached from the app-loop event `0xEA`
(`C688:ED15`). It shares the readiness/error handling but starts at the
printer/merge-side branch rather than the submenu wrapper.

```asm
print_merge_side_entry_C688_ACBC:
; file 0x5153C
C688:ACBC  E8 51 D9          call C688:8610
C688:ACBF  E8 A1 A2          call C688:4F63
C688:ACC2  9F                lahf
C688:ACC3  50                push ax
C688:ACC4  E8 FD 97          call C688:44C4
C688:ACC7  58                pop  ax
C688:ACC8  9E                sahf
C688:ACC9  73 0F             jnc  C688:ACDA
C688:ACCB  BE 35 00          mov  si,0x0035
C688:ACCE  E8 B3 41          call C688:EE84
C688:ACD1  3C 0B             cmp  al,0x0b
C688:ACD3  74 04             jz   C688:ACD9
C688:ACD5  3C 03             cmp  al,0x03
C688:ACD7  75 F2             jnz  C688:ACCB
C688:ACD9  C3                ret
```

After the shared preflight, the flow displays resource `0x1F` (`MERGE.FIL is
not found`) for the missing merge-file case, then resource `0x1C` while running
the output loop. The output-loop helper at `C688:AD39` chains the current
print-state helpers at `C688:9461`, `C688:930B`, `C688:779A`, and `C688:93B5`;
this slice leaves those formatter internals as existing print-output frontier.

```asm
print_output_loop_C688_AD05:
C688:AD05  BE 1C 00          mov  si,0x001c
C688:AD08  E8 7E C9          call C688:7689
C688:AD0B  E8 2B 00          call C688:AD39
C688:AD0E  BE F1 77          mov  si,0x77f1
C688:AD11  F6 04 80          test byte [si],0x80
C688:AD14  75 EF             jnz  C688:AD05
C688:AD16  EB 00             jmp  C688:AD18

print_output_helper_C688_AD39:
C688:AD39  B1 01             mov  cl,0x01
C688:AD3B  E8 23 E7          call C688:9461
C688:AD3E  E8 CA E5          call C688:930B
C688:AD41  E8 56 CA          call C688:779A
C688:AD44  E8 6E E6          call C688:93B5
C688:AD47  C3                ret
```

`C688:AD48` is the missing-address-book branch: it displays resource `0x14`
(`ADDRESS.ODB is not found`) until cancel, then returns to the shared app menu
event loop at `C688:EC9F`. The next instruction block, `C688:AD5C`, opens the
address database and is expanded in
[`print-merge-handlers.md`](print-merge-handlers.md).

## Resource Descriptors

Resource IDs are looked up through the C688 display-resource table at file
`0x559C0`; payload offsets below point at the two-byte length word.

| ID | Table word | Payload | Role |
| ---: | ---: | ---: | --- |
| `0x0A` | `0x0215` | `0x55BD5` | `PRINT TEXT` range/page-numbering/merge form. |
| `0x0D` | `0x0302` | `0x55CC2` | `PRINT START ?` prompt. |
| `0x0E` | `0x0318` | `0x55CDA` | Yes/No selector with `Yes` selected. |
| `0x0F` | `0x0329` | `0x55CEB` | Yes/No selector with `No` selected. |
| `0x14` | `0x03B8` | `0x55D78` | `ADDRESS.ODB is not found`; cancel prompt. |
| `0x1A` | `0x0664` | `0x56024` | Print-progress screen: `PRINT TEXT`, `PRINTING`, pause/cancel instructions. |
| `0x1C` | `0x072F` | `0x560EF` | Completion/cancel status; includes `Printing was canceled`. |
| `0x1F` | `0x06CD` | `0x5608D` | `MERGE.FIL is not found`; cancel prompt. |
| `0x35` | `0x1112` | `0x56AD2` | Readiness/error prompt used when the preflight carries. |

## State Fields

| Address | Role in this slice |
| ---: | --- |
| `[7555]` | One-byte `Y`/`N` selection scratch for the print-start prompt. |
| `[75EF]` | Inline descriptor/dispatch pointer for the print range form. |
| `[77F1]` | Print/output flags; bit `0` marks print active, bit `0x80` keeps the resource `0x1C` output loop running. |
| `[7813]`, `[7815]` | From/to page bounds. The front end initializes these to `1..999`; the merge-side branch may copy `[78FF]` into both. |
| `[7817]` | Print-active/current-output mode word set to `1` before output. |
| `[790F]` | Print/editor state word reset to `1` before the form and again before printer output shutdown. |
| `[792E]` | Output/display flags; the confirmed branch ORs in `0x48`. |
| `[794A]` | Last key/event byte, returned by the wrapper. |
| `[8DB3]` | Shared mode flags; this path toggles bits `0`, `1`, `0x02`, and `0x80` around readiness, merge, and output modes. |

## Bottom

`C688:EB5E` and the `C688:AAA6` front end are now mapped. The lower printer
output path is mapped in [`printer-output.md`](printer-output.md):

| Root | Split | Reason |
| --- | --- | --- |
| Application printer formatter roots | [`printer-output.md`](printer-output.md) | Low-level formatted printer stream before `INT 21h AH=05`. |
