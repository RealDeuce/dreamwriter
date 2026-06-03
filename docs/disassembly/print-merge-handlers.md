# Print/Merge Handlers

This slice expands the word-processor printer/merge application roots exposed
by [`app-menu-event-loop.md`](app-menu-event-loop.md) and
[`wp-print-out.md`](wp-print-out.md). No new bitmap asset is reached here. The
code is a data reader: it opens `ADDRESS.ODB`, builds a selectable name list,
and emits selected address fields into the same print/output stream used by
`PRINT OUT`.

## App-Loop Printer Entry

Event `0xEA` dispatches to `C688:ED15`. This is a small trampoline: run the
printer/merge-side preflight body already shown in
[`wp-print-out.md`](wp-print-out.md#merge-and-output-path), then return to the
shared application menu loop.

```asm
print_merge_event_entry_C688_ED15:
; file 0x55595
C688:ED15  E8 A4 BF          call C688:ACBC
C688:ED18  EB 85             jmp  C688:EC9F
```

## Address Database Name List

Event `0xD2` dispatches to `C688:AD5C`. It opens the inline path at
`C688:AE3A`, currently `H:ADDRESS.ODB`, stores the file handle in `[8253]`,
and initializes `[8255]=0x0010` so the first index-table entry is read from the
Organizer ODB offset table. The `ADDRESS.ODB` container and tab-separated record
format are documented in
[`organizer-address-book.md`](organizer-address-book.md#addressodb-format).

This reader uses only the low word of each four-byte record-offset entry. It
increments `[8255]` by four per record, seeks to the referenced record offset,
reads 24 bytes into `[8259]`, and emits the leading field until TAB, LF, or the
24-byte buffer end. Each displayed name is followed by output byte `0x0C`, and
`[8258]` counts the displayed rows.

```asm
address_merge_reader_C688_AD5C:
; file 0x515DC
C688:AD5C  1E                push ds
C688:AD5D  8C CE             mov  si,cs
C688:AD5F  8E DE             mov  ds,si
C688:AD61  BA 3A AE          mov  dx,0xae3a
C688:AD64  32 C0             xor  al,al
C688:AD66  B4 3D             mov  ah,0x3d
C688:AD68  E8 52 54          call C688:01BD       ; INT 21h wrapper
C688:AD6B  1F                pop  ds
C688:AD6C  72 DA             jc   C688:AD48       ; ADDRESS.ODB missing prompt
C688:AD6E  A3 53 82          mov  [0x8253],ax
C688:AD71  32 C0             xor  al,al
C688:AD73  A2 58 82          mov  [0x8258],al
C688:AD76  A2 57 82          mov  [0x8257],al
C688:AD79  C7 06 55 82 10 00 mov  word [0x8255],0x0010
C688:AD7F  BE 11 00          mov  si,0x0011
C688:AD82  B5 03             mov  ch,0x03
C688:AD84  E8 17 41          call C688:EE9E       ; NAME LIST screen
C688:AD87  B0 00             mov  al,0x00
C688:AD89  E8 B5 E7          call C688:9541
```

The index/read/display loop:

```asm
address_list_next_index_C688_AD8C:
C688:AD8C  8B 16 55 82       mov  dx,[0x8255]
C688:AD90  8B F2             mov  si,dx
C688:AD92  83 C6 04          add  si,byte +0x04
C688:AD95  89 36 55 82       mov  [0x8255],si
C688:AD99  33 C9             xor  cx,cx
C688:AD9B  8A C1             mov  al,cl
C688:AD9D  8B 1E 53 82       mov  bx,[0x8253]
C688:ADA1  B4 42             mov  ah,0x42
C688:ADA3  E8 17 54          call C688:01BD       ; seek to dword index entry
C688:ADA6  BA 59 82          mov  dx,0x8259
C688:ADA9  B9 02 00          mov  cx,0x0002
C688:ADAC  8B 1E 53 82       mov  bx,[0x8253]
C688:ADB0  B4 3F             mov  ah,0x3f
C688:ADB2  E8 08 54          call C688:01BD       ; read low word of offset
C688:ADB5  8B 36 59 82       mov  si,[0x8259]
C688:ADB9  0B F6             or   si,si
C688:ADBB  74 4B             jz   C688:AE08
C688:ADBD  8B D6             mov  dx,si
C688:ADBF  33 C9             xor  cx,cx
C688:ADC1  8A C1             mov  al,cl
C688:ADC3  8B 1E 53 82       mov  bx,[0x8253]
C688:ADC7  B4 42             mov  ah,0x42
C688:ADC9  E8 F1 53          call C688:01BD       ; seek to record
C688:ADCC  BA 59 82          mov  dx,0x8259
C688:ADCF  B9 18 00          mov  cx,0x0018
C688:ADD2  8B 1E 53 82       mov  bx,[0x8253]
C688:ADD6  B4 3F             mov  ah,0x3f
C688:ADD8  E8 E2 53          call C688:01BD       ; read leading name bytes
C688:ADDB  BE 59 82          mov  si,0x8259
C688:ADDE  8A 14             mov  dl,[si]
C688:ADE0  80 FA 09          cmp  dl,0x09
C688:ADE3  74 11             jz   C688:ADF6
C688:ADE5  80 FA 0A          cmp  dl,0x0a
C688:ADE8  74 0C             jz   C688:ADF6
C688:ADEA  56                push si
C688:ADEB  E8 95 AD          call C688:5B83
C688:ADEE  5E                pop  si
C688:ADEF  46                inc  si
C688:ADF0  81 FE 71 82       cmp  si,0x8271
C688:ADF4  75 E8             jnz  C688:ADDE
C688:ADF6  B2 0C             mov  dl,0x0c
C688:ADF8  E8 88 AD          call C688:5B83
C688:ADFB  FE 06 58 82       inc  byte [0x8258]
C688:ADFF  83 3E 54 7A 09    cmp  word [0x7a54],byte +0x09
C688:AE04  72 43             jc   C688:AE49
C688:AE06  EB 84             jmp  C688:AD8C
```

When the index word is zero, the name-list pass ends. The path flushes display
state, closes `ADDRESS.ODB`, and returns to `C688:EC9F`; if the user did not
cancel with event `0x03`, it restores `[8DB3] bit 0x40`.

```asm
address_list_done_C688_AE08:
C688:AE08  E8 85 AD          call C688:5C90
C688:AE0B  E8 6F AD          call C688:5B7D
C688:AE0E  E8 B3 96          call C688:44C4
C688:AE11  E8 C0 E3          call C688:91D4
C688:AE14  E8 66 C4          call C688:727D
C688:AE17  E8 EB 5E          call C688:0D05
C688:AE1A  E8 A7 96          call C688:44C4
C688:AE1D  80 26 B3 8D BF    and  byte [0x8db3],0xbf
C688:AE22  80 3E 4A 79 03    cmp  byte [0x794a],0x03
C688:AE27  74 05             jz   C688:AE2E
C688:AE29  80 0E B3 8D 40    or   byte [0x8db3],0x40
C688:AE2E  8B 1E 53 82       mov  bx,[0x8253]
C688:AE32  B4 3E             mov  ah,0x3e
C688:AE34  E8 86 53          call C688:01BD
C688:AE37  E9 65 3E          jmp  C688:EC9F
```

## Address Record Substitution

`C688:AE5F` is the selected-record substitution helper. It reopens
`ADDRESS.ODB`, seeks to index entry `0x10 + [8257] * 4`, reads the selected
record offset, then streams selected tab-separated fields. The inline template
at `C688:EAED` names the emitted fields:

```text
D5 "NAME(" TAB
D5 "SALUTATION(" TAB
D5 "TEL(" TAB
D5 "FAX(" TAB
D5 "ADRS(" TAB
LF
```

For each template field, `C688:AEBE` emits the literal prefix through
`C688:5B83` until TAB, then `C688:AECF` emits the next address-book field until
TAB or LF, adds `')'`, and terminates the field with `0x0C`. `C688:AF10` is the
shared chunk loader that seeks to `[8255]`, reads `0x1E` bytes into `[8259]`,
stores the byte count in `[8258]`, and resets `[8257]`.

```asm
selected_address_stream_C688_AE5F:
; file 0x516DF
C688:AE5F  80 26 B3 8D BF    and  byte [0x8db3],0xbf
C688:AE64  1E                push ds
C688:AE65  8C CE             mov  si,cs
C688:AE67  8E DE             mov  ds,si
C688:AE69  BA 3A AE          mov  dx,0xae3a
C688:AE6C  B0 00             mov  al,0x00
C688:AE6E  B4 3D             mov  ah,0x3d
C688:AE70  E8 4A 53          call C688:01BD
C688:AE73  1F                pop  ds
C688:AE74  73 04             jnc  C688:AE7A
C688:AE76  E8 D5 FE          call C688:AD4E
C688:AE79  C3                ret
C688:AE7A  A3 53 82          mov  [0x8253],ax
C688:AE7D  B6 00             mov  dh,0x00
C688:AE7F  8A 16 57 82       mov  dl,[0x8257]
C688:AE83  03 D2             add  dx,dx
C688:AE85  03 D2             add  dx,dx
C688:AE87  83 C2 10          add  dx,byte +0x10
C688:AE8A  E8 83 00          call C688:AF10
C688:AE8D  8B 16 59 82       mov  dx,[0x8259]
C688:AE91  89 16 55 82       mov  [0x8255],dx
C688:AE95  E8 78 00          call C688:AF10
C688:AE98  C7 06 51 82 ED EA mov  word [0x8251],0xeaed
```

The template/field loop:

```asm
address_template_loop_C688_AE9E:
C688:AE9E  8B 36 51 82       mov  si,[0x8251]
C688:AEA2  2E 80 3C 0A       cmp  byte [cs:si],0x0a
C688:AEA6  74 0C             jz   C688:AEB4
C688:AEA8  E8 13 00          call C688:AEBE
C688:AEAB  89 36 51 82       mov  [0x8251],si
C688:AEAF  E8 1D 00          call C688:AECF
C688:AEB2  EB EA             jmp  C688:AE9E
C688:AEB4  8B 1E 53 82       mov  bx,[0x8253]
C688:AEB8  B4 3E             mov  ah,0x3e
C688:AEBA  E8 00 53          call C688:01BD
C688:AEBD  C3                ret
```

The literal-template and record-field emitters are the small local helpers below.

```asm
emit_address_template_literal_C688_AEBE:
C688:AEBE  2E 8A 14          mov  dl,[cs:si]
C688:AEC1  46                inc  si
C688:AEC2  80 FA 09          cmp  dl,0x09
C688:AEC5  74 07             jz   C688:AECE
C688:AEC7  56                push si
C688:AEC8  E8 B8 AC          call C688:5B83
C688:AECB  5E                pop  si
C688:AECC  EB F0             jmp  C688:AEBE
C688:AECE  C3                ret

emit_selected_address_field_C688_AECF:
C688:AECF  A0 57 82          mov  al,[0x8257]
C688:AED2  3A 06 58 82       cmp  al,[0x8258]
C688:AED6  75 10             jnz  C688:AEE8
C688:AED8  8B 16 55 82       mov  dx,[0x8255]
C688:AEDC  83 C2 1E          add  dx,byte +0x1e
C688:AEDF  89 16 55 82       mov  [0x8255],dx
C688:AEE3  E8 2A 00          call C688:AF10
C688:AEE6  EB E7             jmp  C688:AECF
C688:AEE8  8A D8             mov  bl,al
C688:AEEA  B7 00             mov  bh,0x00
C688:AEEC  81 C3 59 82       add  bx,0x8259
C688:AEF0  8A 17             mov  dl,[bx]
C688:AEF2  80 FA 0A          cmp  dl,0x0a
C688:AEF5  74 0E             jz   C688:AF05
C688:AEF7  FE 06 57 82       inc  byte [0x8257]
C688:AEFB  80 FA 09          cmp  dl,0x09
C688:AEFE  74 05             jz   C688:AF05
C688:AF00  E8 80 AC          call C688:5B83
C688:AF03  EB CA             jmp  C688:AECF
C688:AF05  B2 29             mov  dl,')'
C688:AF07  E8 79 AC          call C688:5B83
C688:AF0A  B2 0C             mov  dl,0x0c
C688:AF0C  E8 74 AC          call C688:5B83
C688:AF0F  C3                ret

load_address_chunk_C688_AF10:
C688:AF10  B9 00 00          mov  cx,0x0000
C688:AF13  B0 00             mov  al,0x00
C688:AF15  8B 1E 53 82       mov  bx,[0x8253]
C688:AF19  B4 42             mov  ah,0x42
C688:AF1B  E8 9F 52          call C688:01BD
C688:AF1E  BA 59 82          mov  dx,0x8259
C688:AF21  B9 1E 00          mov  cx,0x001e
C688:AF24  8B 1E 53 82       mov  bx,[0x8253]
C688:AF28  B4 3F             mov  ah,0x3f
C688:AF2A  E8 90 52          call C688:01BD
C688:AF2D  A2 58 82          mov  [0x8258],al
C688:AF30  C6 06 57 82 00    mov  byte [0x8257],0x00
C688:AF35  C3                ret
```

## Resources And State

| Resource | Table word | Payload | Role |
| ---: | ---: | ---: | --- |
| `0x11` | `0x0355` | `0x55D15` | `NAME LIST`; instructions to position cursor, press select, or press CAN. |
| `0x14` | `0x03B8` | `0x55D78` | `ADDRESS.ODB is not found`; cancel prompt. |
| `0x2D` | `0x0ACC` | `0x5648C` | `Remaining work memory is inadequate`; CAN-to-exit prompt. |

| Address | Role |
| ---: | --- |
| `[7A54]` | Display/list row count used to stop the name-list pass when the screen is full. |
| `[8251]` | Pointer into the inline field-label template at `C688:EAED`. |
| `[8253]` | Open `ADDRESS.ODB` file handle. |
| `[8255]` | Current file offset: index-table dword slot during list building, then selected-record chunk offset during substitution. |
| `[8257]` | During list display, cleared before the pass; during substitution, selected record index and then chunk byte cursor. |
| `[8258]` | Name-list row counter; reused as the bytes-read count for a selected-record chunk. |
| `[8259..8276]` | Scratch read buffer for index words, record-leading bytes, and 30-byte selected-record chunks. |
| `[8DB3] bit 0x40` | Print/merge mode bit cleared around address-list and selected-record work, restored unless the user cancels. |

## Bottom

`C688:AD5C`, `C688:ED15`, and the selected-address substitution helper are now
mapped. The lower formatted output stream, including `C688:5B83` and the
application byte sink before `INT 21h AH=05`, is mapped in
[`printer-output.md`](printer-output.md).
