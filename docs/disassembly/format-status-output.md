# Format And Transfer Status Output

This slice follows the shared status-output helper reached by local/card
formatting and DreamLink transfer paths. It stays at the service display
resource boundary and does not enter menus or application handlers.

No image assets are reached in this slice.

## Status Resource Constructors

`C000:23CD` selects the upper status row. `C000:23D9` selects the lower status
row. `C000:23DE` is the lower-row entry used when a caller has already set
`[6F23]`.

```asm
status_upper_C000_23CD:
; file 0x423CD
C000:23CD  C6 06 23 6F 0C    mov  byte [0x6f23],0x0c
C000:23D2  C6 06 24 6F 1C    mov  byte [0x6f24],0x1c
C000:23D7  EB 0A             jmp  status_common_C000_23E3

status_lower_default_x_C000_23D9:
C000:23D9  C6 06 23 6F 0C    mov  byte [0x6f23],0x0c

status_lower_C000_23DE:
C000:23DE  C6 06 24 6F 25    mov  byte [0x6f24],0x25
```

The common path builds an 11-byte `C000:5AD6` display resource at `6EC3`,
formats `[6F21]` as a five-character right-aligned decimal field, then renders
the resource.

```asm
status_common_C000_23E3:
C000:23E3  BF C3 6E          mov  di,0x6ec3
C000:23E6  E8 16 00          call build_status_descriptor_C000_23FF
C000:23E9  A1 21 6F          mov  ax,[0x6f21]
C000:23EC  33 D2             xor  dx,dx
C000:23EE  55                push bp
C000:23EF  E8 8B FA          call format_u16_field_C000_1E7D
C000:23F2  B9 0B 00          mov  cx,0x000b
C000:23F5  BE C3 6E          mov  si,0x6ec3
C000:23F8  8C DA             mov  dx,ds
C000:23FA  E8 D9 36          call display_resource_C000_5AD6
C000:23FD  5D                pop  bp
C000:23FE  C3                ret
```

`C000:1E7D` sets `BP` to the caller's `DI`, so after
`build_status_descriptor_C000_23FF` the text field starts at `6EC9`. It calls
the decimal formatter at `C000:21D2`, then blanks leading zeroes in the first
four positions. The ones digit is never blanked, so zero displays as four
spaces followed by `0`.

```asm
format_u16_field_C000_1E7D:
; file 0x41E7D
C000:1E7D  8B EF             mov  bp,di
C000:1E7F  57                push di
C000:1E80  E8 4F 03          call format_decimal_5_C000_21D2
C000:1E83  5F                pop  di
C000:1E84  B9 04 00          mov  cx,4
blank_leading_zero_C000_1E87:
C000:1E87  80 3D 30          cmp  byte [di],'0'
C000:1E8A  75 06             jnz  done_decimal_field_C000_1E92
C000:1E8C  C6 05 20          mov  byte [di],' '
C000:1E8F  47                inc  di
C000:1E90  E2 F5             loop blank_leading_zero_C000_1E87
C000:1E92  0A C0             or   al,al
C000:1E94  C3                ret
```

The decimal formatter emits five digits by dividing the `DX:AX` input by
`10000`, `1000`, `100`, and `10`, then writing the final remainder. Digits are
looked up through the table at `C000:2288`.

```asm
format_decimal_5_C000_21D2:
; file 0x421D2
C000:21D2  50                push ax
C000:21D3  52                push dx
C000:21D4  B9 10 27          mov  cx,10000
C000:21D7  F7 F1             div  cx
C000:21D9  E8 97 00          call emit_digit_C000_2273
...
C000:21F9  B9 E8 03          mov  cx,1000
...
C000:2203  B9 64 00          mov  cx,100
...
C000:220D  B9 0A 00          mov  cx,10
...
C000:221B  2E 8A 87 88 22    mov  al,[cs:bx+0x2288]
C000:2220  3E 88 46 00       mov  [ds:bp+0],al
C000:2224  0A C0             or   al,al
C000:2226  C3                ret

emit_digit_C000_2273:
C000:2273  8A D8             mov  bl,al
C000:2275  32 FF             xor  bh,bh
C000:2277  3C 0F             cmp  al,0x0f
C000:2279  B0 58             mov  al,'X'
C000:227B  73 05             jnc  emit_digit_store_C000_2282
C000:227D  2E 8A 87 88 22    mov  al,[cs:bx+0x2288]
C000:2282  3E 88 46 00       mov  [ds:bp+0],al
C000:2286  45                inc  bp
C000:2287  C3                ret

digit_table_C000_2288:
; 30 31 32 33 34 35 36 37 38 39 41 42 43 44 45 46
; "0123456789ABCDEF"
```

## Display Resource Format

`C000:23FF` writes only the descriptor prefix. The resource length passed to
`C000:5AD6` is always 11 bytes, so the payload is a five-byte mutable field
following the six-byte position descriptor.

```asm
build_status_descriptor_C000_23FF:
C000:23FF  B8 FF 02          mov  ax,0x02ff
C000:2402  89 05             mov  [di],ax
C000:2404  83 C7 02          add  di,2
C000:2407  A0 23 6F          mov  al,[0x6f23]
C000:240A  B4 00             mov  ah,0
C000:240C  89 05             mov  [di],ax
C000:240E  83 C7 02          add  di,2
C000:2411  A0 24 6F          mov  al,[0x6f24]
C000:2414  8B D0             mov  dx,ax
C000:2416  03 C0             add  ax,ax
C000:2418  03 C2             add  ax,dx
C000:241A  D1 E0             shl  ax,1
C000:241C  89 05             mov  [di],ax
C000:241E  83 C7 02          add  di,2
C000:2421  C3                ret
```

Descriptor formats:

```text
Upper row:
  bytes: FF 02 0C 00 A8 00 <u16_decimal_5 [6F21]>
  format: text_run(x=12, y=168, text="%5u")
  final formatted text:
  %5u

Lower row, default x:
  bytes: FF 02 0C 00 DE 00 <u16_decimal_5 [6F21]>
  format: text_run(x=12, y=222, text="%5u")
  final formatted text:
  %5u

Lower row, caller-provided x:
  bytes: FF 02 <6F23:u16le> DE 00 <u16_decimal_5 [6F21]>
  format: text_run(x=[6F23], y=222, text="%5u")
  final formatted text:
  %5u
```

For example, `[6F21]=0` renders `"    0"`, `[6F21]=32` renders `"   32"`, and
`[6F21]=65535` renders `"65535"`.

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6EC3..6ECD` | 11-byte transient display resource rendered by `C000:5AD6`. |
| `6F21` | Progress scalar formatted as unsigned five-digit decimal. |
| `6F23` | Text x position in pixels. |
| `6F24` | Row index; converted to pixel y by `y = index * 6`. |
