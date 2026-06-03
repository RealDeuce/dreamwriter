; Generated from disasm: DC98:990D-9944
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x990D


; file 0x6628D
    push bp
    sub  sp,0x0660
    call DC98:0E70
    call DC98:2887
    mov  ax,0x000a
    mov  bx,0xf0e0
    mov  cx,0x0012
    call C000:67AD       ; "*** WAIT ***"
    lea  ax,[bp-0x320]
    mov  [0x82b0],ax     ; index table buffer
    lea  ax,[bp-0x640]
    mov  [0x82b2],ax     ; scheduler date/time cache
DC98:99C9  lea  ax,[bp-0x654]       ; path buffer
DC98:99CE  call DC98:E946           ; open
DC98:99D6  mov  [0x82a8],ax         ; file handle
...
DC98:99E0  lea  ax,[bp-0x654]
DC98:99E4  mov  cx,0x0000
DC98:99E7  mov  dx,0xf102           ; header pointer
DC98:99EA  mov  bx,0x00c8           ; 200 index slots
DC98:99ED  call DC98:BB4F           ; create ODB
...
DC98:9A07  mov  ax,0x0000
DC98:9A0A  mov  bx,0xf102
DC98:9A0D  mov  cx,0x00c8
DC98:9A10  call DC98:BA42           ; validate existing ODB
; file 0x683C2
DC98:BA42  call DC98:EC2A       ; get file size
DC98:BAA5  read 0x10 bytes      ; header
DC98:BACD  compare 16 bytes     ; against caller header pointer
DC98:BAEB  read count*4 bytes   ; index table into [82B0]
DC98:BB07  mov  [0x82ae],0
DC98:BB34  inc  word [0x82ae]   ; one valid nonzero record offset
; file 0x69892
DC98:CF30  mov  ax,0x000a
DC98:CF33  mov  bx,0xf17b
DC98:CF36  mov  cx,0x0012
DC98:CF39  call C000:67AD       ; same wait screen pattern
DC98:CF3E  lea  ax,[bp-0x320]
DC98:CF42  mov  [0x82b0],ax     ; same dword offset table
DC98:CF45  lea  ax,[bp-0x3e8]
DC98:CF49  mov  [0x82b2],ax     ; address-book one-byte cache
...
DC98:CFE9  mov  cx,0x0006
DC98:CFEC  mov  dx,0xf1c5       ; ADDRESS header pointer
DC98:CFEF  mov  bx,0x00c8
DC98:CFF2  call DC98:BB4F
DC98:D00C  mov  ax,0x0006
DC98:D00F  mov  bx,0xf1c5
DC98:D012  mov  cx,0x00c8
DC98:D015  call DC98:BA42
; file 0x63D5B
DC98:73E9  seek [82B0 + si*4]        ; record offset
DC98:740F  read 4 bytes -> [82B2+si*4]
DC98:741D  read 5 bytes -> stack
DC98:7425  cmp  byte [bp-0x2],0
DC98:744E  load record date dword
DC98:7457  sub  date,0x63df
DC98:7464  store date delta at 82C8 + si*4
DC98:7472  store time word at 82C8 + si*4 + 2
DC98:9A51  cmp  word [0x82ae],0
DC98:9A58  call DC98:EE2E       ; close if empty
DC98:9A64  call DC98:EE40       ; delete empty SCHEDULE.ODB
...
DC98:9A7E  call DC98:74C2       ; compact scheduler record payloads
DC98:9A84  seek 0x10
DC98:9A94  write 0x320 bytes from [82B0]
DC98:9AA3  call DC98:EE2E       ; close
