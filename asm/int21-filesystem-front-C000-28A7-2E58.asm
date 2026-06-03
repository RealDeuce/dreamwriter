; Generated from disasm: C000:28A7-2E58
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x28A7


service_0E_select_drive_C000_28A7:
; file 0x428A7
    inc  dl              ; external DL -> internal 1-based
    cmp  dl,0x0b
    jnc  C000:28B2
    mov  [0x6d35],dl
    mov  word [bp+0x00],0x0009
    clc
    ret

service_19_get_drive_C000_28B9:
    mov  al,[0x6d35]
    xor  ah,ah
    mov  [bp+0x00],ax
    clc
    ret

service_1A_set_dta_C000_28C3:
    mov  [0x6f6a],dx
    mov  dx,[bp+0x08]   ; caller DS
    mov  [0x6f6c],dx
    clc
    ret

service_2F_get_dta_C000_28D0:
    mov  bx,[0x6f6c]
    mov  [bp+0x0a],bx   ; ES
    mov  bx,[0x6f6a]
    mov  [bp+0x02],bx   ; BX
    clc
    ret
service_36_free_space_C000_28E0:
; file 0x428E0
    or   dl,dl
    jnz  C000:28E8
    mov  dl,[0x6d35]
    mov  [0x6d35],dl
    mov  [0x6fa5],dl
    mov  word [0x6fa3],0x1800
...
    call mount_current_endpoint_C000_3B69
    mov  word [0x6f60],1
    call C000:3982
    mov  [0x6f57],cx
    call C000:39CE       ; read FAT12 entry
    or   ax,ax
    jnz  C000:298A
    inc  word [0x6f5b]  ; free cluster count
...
    mov  bx,[0x6f5b]
    mov  dx,[0x6faa]
    dec  dx
    mov  cx,0x0080
    mov  ax,[0x6f60]
    mov  [bp+0x00],ax
    mov  [bp+0x02],bx
    mov  [bp+0x04],cx
    mov  [bp+0x06],dx
    ret
service_3C_create_truncate_C000_29AD:
; file 0x429AD
    mov  [0x6f70],cx    ; attributes
    mov  si,dx
    call parse_filename_C000_39F7
...
    mov  al,[0x6fa5]
    cmp  al,0x0a
    jnz  local_create_C000_29D2
    call dreamlink_create_C000_4384
    jmp  finish_int21_status_C000_3953
service_3D_open_C000_2B84:
; file 0x42B84
    mov  ax,[bp+0x00]
    mov  [0x6f86],al    ; open mode
    mov  si,dx
    call parse_filename_C000_39F7
...
    mov  al,[0x6fa5]
    cmp  al,0x0a
    jnz  local_open_C000_2BBD
    mov  ax,[bp+0x08]
    mov  [0x703d],ax
    call dreamlink_open_C000_4459
    jmp  finish_int21_status_C000_3953
pack_time_C000_2B44:
    push es
    push di
    call C000:5213       ; get decoded time
...

pack_date_C000_2B5C:
    push es
    push di
    call C000:517C       ; get decoded date
...
service_4E_find_first_C000_2DE2:
; file 0x42DE2
    mov  [0x6f70],cx
    mov  si,dx
    call parse_filename_C000_39F7
...
    mov  di,[0x6f6a]    ; DTA
    mov  al,[0x6fa5]
    mov  [di+0x10],al
...
    mov  byte [0x6ec1],0x12
    call scan_next_dir_entry_C000_388B
