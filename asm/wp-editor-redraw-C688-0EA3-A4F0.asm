; Generated from disasm: C688:0EA3-A4F0
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0EA3


root_editor_span_emitter_C688_18AC:
; file 0x4812C
    test cl,0x04
    jnz  C688:18B4
    jmp  C688:19B2
    push si
    call C688:194F
    or   cl,0x20
    test cl,0x10
    jnz  C688:18C3
    jmp  C688:19A4
span_emitter_long_path_C688_18C3:
    or   cl,0x10
    mov  si,0x007e
    mov  [0x79d9],si
    mov  si,0x007b
    mov  [0x79d7],si
    mov  si,0xffff
    mov  [0x795c],si
    mov  [0x79d5],si
    mov  dx,[0x78eb]
    test dl,0x40
    jz   C688:1910
    call C688:18EE
    jmp  C688:1E0D
signed_delta_seed_C688_18EE:
    call C688:1A0A
    mov  [0x7967],dx
    mov  si,[0x78e9]
    mov  [0x7969],si
    mov  si,[0x78f1]
    test si,0x0080
    jz   C688:190B
    or   si,0xff00
    add  si,dx
    xchg si,dx
    ret

plain_delta_seed_C688_1910:
    mov  [0x7967],dx
    mov  si,[0x78e7]
    mov  [0x7969],si
    mov  si,[0x78ef]
    add  si,dx
    xchg si,dx
    dec  si
    mov  [0x7963],si
    jmp  C688:1D7D
redraw_state_primer_C688_194F:
    push si
    mov  word [0x79f6],0
    mov  si,[0x793e]
    mov  [0x795f],si
    mov  word [0x75ed],0x795c
    mov  si,[0x78e5]
    mov  dx,[0x79a1]
    test dl,0x01
    jz   C688:1974
    mov  si,0x0002
    mov  [0x7a15],si
    mov  [0x796b],si
    mov  si,[0x797b]
    mov  [0x796d],si
    mov  si,[0x7912]
    mov  [0x7961],si
    pop  si
    ret
default_span_fields_C688_192C:
    mov  word [0x79d9],0x007c
    mov  si,[0x7a15]
    mov  [0x796b],si
    mov  si,0
    mov  [0x79d7],si
    mov  word [0x79d5],0x007c
    mov  si,0x0001
    mov  [0x795c],si
    ret
restore_redraw_state_C688_19B2:
    xor  al,al
    push si
    mov  si,0x79ec
    and  byte [si],0xbf
    mov  [0x772b],al
    test cl,0x01
    jnz  C688:198E
    mov  dx,[0x7969]
    test dl,0x40
    jnz  C688:19CF
    call C688:39BE
    mov  al,[0x795e]
    mov  [0x7988],al
    mov  si,[0x796b]
    mov  [0x79f6],si
    mov  si,[0x7a15]
    mov  [0x796b],si
    mov  si,[0x796d]
    mov  [0x7a41],si
    mov  si,[0x7961]
    mov  [0x79db],si
    mov  [0x7979],si
    mov  al,[0x7967]
    test al,0x40
    jz   C688:1A03
    jmp  C688:1F53
    mov  dx,[0x796f]
    jmp  C688:1D7D
emit_clamped_redraw_range_C688_1A85:
; file 0x48305
    xor  al,al
    mov  [0x79ff],al
    mov  cx,[0x7958]
    sub  cx,dx
    js   C688:1AA0
    jz   C688:1AA0
    sub  si,cx
    jns  C688:1A99
    ret
    jnz  C688:1A9C
    ret
    mov  dx,[0x7958]
    mov  cx,[0x7954]
    mov  al,[0x7990]
    or   al,al
    jz   C688:1AD2
    push si
    push dx
    mov  si,[0x7916]
    add  si,cx
    call C688:4239
...
    push cx
    push si
    add  si,dx
    dec  si
    mov  cx,si
    mov  si,[0x78e1]
    inc  si
    sub  si,cx
    jnc  C688:1AF6
...
    mov  al,[0x79ff]
    call C688:3C2B
    mov  al,[0x799a]
    test al,0x02
    jz   C688:1B11
    mov  al,0x0a
    mov  [0x7745],al
    call C688:3C68
    ret
editor_mode_bit_predicate_C688_1B12:
    mov  al,[0x78d5]
    test al,0x01
    jz   C688:1B11
    mov  al,[0x7717]
    test al,0x01
    ret
snapshot_redraw_window_bounds_C688_1B41:
    mov  al,[0x793e]
    mov  word [0x75ed],0x795c
    call C688:61DB
    mov  si,[0x78ff]
    mov  [0x7975],si
    mov  si,[0x78fb]
    mov  [0x7971],si
    mov  si,[0x78f5]
    mov  [0x7973],si
    mov  al,[0x793d]
    mov  [0x795e],al
    mov  [0x799a],al
    ret
append_redraw_mode_markers_C688_1B6F:
    mov  al,[0x795e]
    mov  si,[0x79e2]
    mov  dx,0x7f28
    sub  si,dx
    mov  dx,si
    mov  si,[0x79e2]
    mov  dh,0xf0
    or   al,al
    jz   C688:1B9A
    test al,0x01
    jz   C688:1B93
    mov  [si],dh
    inc  dl
    jnz  C688:1B92
    ret
    inc  si
    shr  al,1
    add  dh,0x02
    jmp  C688:1B83
    mov  dx,[0x794e]
    mov  al,[0x795f]
    cmp  al,dl
    jz   C688:1BA8
    call C688:1A51
    ret
append_redraw_position_record_C688_1A51:
    push si
    mov  [0x794e],al
    call C688:61DB
    pop  si
    mov  word [si],0x04ff
    add  si,byte +0x02
    mov  [si],dx
    add  si,byte +0x02
    mov  [0x7713],dx
    ret
finish_redraw_kick_C688_1A7B:
    xor  al,al
    mov  dx,[0x78e7]
    call C688:39B5
    ret
normalize_redraw_flag_bits_C688_39B5:
; file 0x4A235
    test dl,0x40
    jnz  C688:39BD
    and  dl,0xc0
    ret

save_and_normalize_redraw_flags_C688_39BE:
    mov  si,0x79e0
    mov  [0x7969],dx
    jmp  C688:39BA
write_redraw_mode_table_byte_C688_61DB:
; file 0x4CA5B
    mov  bx,[0x75ed]
    mov  [bx+0x0003],al
    mov  dl,al
    mov  dh,0
    mov  si,dx
    add  si,0x7118
    mov  dx,[cs:si]
    inc  si
    mov  al,dh
    mov  [bx+0x0004],al
    ret
flush_redraw_scratch_to_renderer_C688_6B8C:
; file 0x4D40C
    mov  si,[0x79e2]
    mov  dx,0x7f28
    xor  al,al
    sub  si,dx
    jnz  C688:6B9A
    ret
    mov  [0x7727],si
    mov  al,0x0a
    mov  [0x771d],al
    mov  si,0x771f
    mov  [0x771b],si

renderer_service_tail_C688_6BAA:
    mov  si,0x7719
    mov  word [0x75ef],0x7779
    mov  bx,ds
    mov  ah,0x06
    call C688:9364
    ret
redraw_stream_boundary_compare_C688_1A17:
; file 0x48297
    mov  si,[0x78e9]
    sub  si,dx
    jnz  C688:1A23
    mov  dx,[0x78ed]
    ret

redraw_stream_range_save_C688_1A24:
    mov  [0x7967],dx
    mov  si,[0x79d5]
    add  si,dx
    mov  [0x7963],si
    mov  dx,[0x7969]
    mov  si,[0x78e7]
    sub  si,dx
    jnz  C688:1A50
    mov  si,[0x78ef]
    mov  dx,[0x7967]
    add  si,dx
    mov  [0x7963],si
    mov  dx,[0x7969]
    ret
append_final_mode_span_markers_C688_1BA9:
; file 0x48429
    mov  al,[0x7990]
    or   al,al
    jz   C688:1BD2
    mov  si,[0x7916]
    call C688:4239
    mov  si,[0x78db]
    add  si,dx
    mov  dx,[0x78dd]
    sub  si,dx
    mov  si,[0x7916]
    jc   C688:1BCF
    mov  dx,[0x78db]
    sub  si,dx
    call C688:1C39
    mov  dl,0
    or   dl,0x02
    mov  al,[0x7988]
    and  al,dl
    lahf
    push ax
    jz   C688:1BE7
    call C688:1B72
    mov  [0x79e2],si
    mov  si,[0x7952]
    mov  dx,[0x7979]
    sub  si,dx
    xchg si,dx
    jnc  C688:1BF7
    add  si,dx
    mov  dx,[0x7950]
    sub  si,dx
    mov  dh,0x0e
    call C688:1C3B
    pop  ax
    sahf
    mov  al,[0x795e]
    jz   C688:1C1C
    test al,0x02
    jnz  C688:1C1A
    mov  si,[0x79e2]
    mov  word [si],0x00f3
    inc  si
    mov  [0x79e2],si
    and  al,0xfd
    call C688:1B72
    ret
append_mode_dependent_span_record_C688_1C20:
    cmp  si,0
    jz   C688:1C38
    mov  al,[0x78d5]
    test al,0x01
    mov  al,0x0e
    jz   C688:1C35
    mov  al,[0x7717]
    and  al,0x02
    add  al,0x0e
    call C688:1C47
    ret

append_span_record_C688_1C39:
    mov  dh,0x0e
    mov  ax,si
    or   ah,ah
    js   C688:1C38
    or   ah,al
    jz   C688:1C38
    mov  al,dh

append_span_record_tail_C688_1C47:
    xchg si,dx
    mov  si,[0x79e2]
    mov  byte [si],0xff
    inc  si
    mov  [si],al
    inc  si
    mov  [si],dl
    inc  si
    mov  [si],dh
    inc  si
    mov  [0x79e2],si
    ret
redraw_cl10_distance_adjust_C688_1C5F:
; file 0x484DF
    mov  dx,[0x79f9]
    test cl,0x10
    jz   C688:1CA7
    mov  si,[0x7975]
    dec  si
    mov  [0x7975],si
    dec  si
    cmp  si,0
    jnz  C688:1C86
    mov  al,[0x792e]
    test al,0x80
    jnz  C688:1C86
    mov  si,[0x7903]
    mov  [0x7971],si
    mov  al,[0x79f8]
    mov  dh,al
    mov  si,[0x7901]
    call C688:1B12
    jnz  C688:1C9E
    mov  si,[0x78fd]
    add  si,0x04
    sub  si,dx
    ret
    sub  si,dx
    mov  dx,[0x7907]
    add  si,dx
    ret

normalize_redraw_bound_C688_1CA7:
    call C688:1B12
    jnz  C688:1CC5
    mov  si,[0x78fd]
    add  si,0x02
    sub  si,dx
    js   C688:1CB9
    jnz  C688:1CC4
    xchg si,dx
    mov  si,[0x78fd]
    add  si,0x02
    add  si,dx
    ret
    mov  si,[0x7901]
    sub  si,dx
    js   C688:1CCF
    jnz  C688:1CA0
    mov  dx,[0x7901]
    add  si,dx
    jmp  C688:1CA0
redraw_active_cursor_advance_C688_1CD7:
; file 0x48557
    mov  si,[0x7952]
    sub  si,dx
    xchg si,dx
    jnc  C688:1CE3
    add  si,dx
    push si
    mov  dx,[0x79db]
    sub  si,dx
    pop  dx
    jc   C688:1CC4
    jz   C688:1CC4
    push si
    push dx
    mov  si,[0x79db]
    mov  dx,[0x7a41]
    sub  si,dx
    pop  dx
    jnc  C688:1D14
    mov  si,[0x7a41]
    sub  si,dx
    jc   C688:1D14
    pop  si
    push si
    push dx
    mov  dx,[0x7979]
    add  si,dx
    mov  [0x7979],si
    pop  dx
    pop  si
    mov  [0x79db],dx
    mov  al,[0x79df]
    and  al,0x03
    jz   C688:1D25
    dec  al
    jz   C688:1D49
    ret
    xchg si,dx
    mov  dx,[0x7950]
    sub  si,dx
    jc   C688:1D4C
    mov  bx,[0x7979]
    sub  bx,dx
    mov  dx,bx
    jc   C688:1D3B
    sub  si,dx
    push si
    call C688:1BA9
    mov  [0x79e2],si
    pop  si
    mov  al,0x01
    mov  [0x79df],al
    call C688:1C20
    ret

redraw_final_marker_return_C688_1D4D:
    mov  dx,0
    mov  [0x793b],al
    mov  al,[0x79f8]
    cmp  al,0x04
    jnz  C688:1D68
    mov  si,[0x79f9]
    test al,0x80
    jnz  C688:1D68
    mov  al,0
    add  ax,si
    add  ax,si
    mov  [0x797f],al
    test cl,0x08
    jz   C688:1D4C
    pop  ax
    sahf
    jmp  C688:2310
redraw_stream_wrapper_C688_1D75:
; file 0x485F5
    push si
    mov  dx,[0x796f]
    jmp  C688:1D7D
    pop  dx
redraw_stream_next_byte_C688_1D7D:
    test cl,0x40
    jz   C688:1D99
    mov  bx,dx
    push ds
    push si
    test byte [0x824f],0x01
    jnz  C688:1D91
    mov  si,es
    mov  ds,si
    mov  al,[bx]
    pop  si
    pop  ds
    inc  dx
    jmp  C688:1E27
    mov  si,[0x795c]
    add  si,dx
    mov  al,[es:si]
    xchg si,dx
    mov  si,[0x7963]
    sub  si,dx
    jnz  C688:1DEB
    mov  si,[0x7967]
    mov  dx,[0x79d9]
    add  si,dx
    mov  dx,[es:si]
    inc  si
    test dl,0x40
    jnz  C688:1DED
    call C688:39BE
    mov  si,[0x79d7]
    add  si,dx
    push si
    call C688:1A24
    call C688:1A17
    pop  si
    jnz  C688:1D9F
    mov  si,[0x78f1]
    test si,0x0080
    jz   C688:1DE0
    or   si,0xff00
    add  si,dx
    xchg si,dx
    call C688:A355
    jz   C688:1D7D
    mov  al,0x40
    jmp  C688:1E27
redraw_stream_sentinel_C688_1DED:
    mov  al,0x1f
    mov  [0x793b],al
    mov  si,[0x7963]
    mov  dx,[0x795c]
    xor  al,al
    test cl,0x10
    jnz  C688:1E03
    sub  si,dx
    xchg si,dx
    test cl,0x04
    jnz  C688:1E0D
    jmp  C688:1F45
    test cl,0x10
    jnz  C688:1E15
    jmp  C688:1F45
    pop  si
    push si
    and  cl,0xfd
    test si,0x8000
    mov  [0x79f6],si
    jnz  C688:1E89
    jmp  C688:1F45
redraw_stream_byte_dispatch_C688_1E27:
    push dx
    mov  ch,al
    test cl,0x80
    jz   C688:1E32
    jmp  C688:1F7E
    and  cl,0xfd
    cmp  al,0xff
    jnz  C688:1E57
    mov  dx,[0x7a13]
    and  byte [0x824f],0xfe
    test cl,0x40
    jnz  C688:1E50
    mov  word [0x6d79],0x1e32
    jmp  C688:01B6
    and  cl,0xbf
    pop  si
    jmp  C688:1D7D
    call C688:2574
    or   al,al
    jz   C688:1E61
    jmp  C688:21F4
redraw_classifier_zero_C688_1E61:
    mov  al,[0x793b]
    test cl,0x04
    jnz  C688:1E6C
    jmp  C688:231C
    pop  dx
    test al,0x02
    jnz  C688:1E74
    jmp  C688:1D7D
    test cl,0x10
    jnz  C688:1E7C
    jmp  C688:1F0E
redraw_positive_range_rebase_C688_1E7C:
    pop  si
    push si
    cmp  si,0
    jz   C688:1E8D
    test si,0x8000
    jz   C688:1EAC
    mov  [0x79f6],si
    test cl,0x02
    jnz  C688:1E95
    jmp  C688:1F45
    mov  dx,[0x7a19]
    mov  [0x7967],dx
    mov  dx,[0x7a17]
    mov  [0x7969],dx
    mov  dx,[0x79fe]
    jmp  C688:1F45
redraw_visible_bound_rebase_C688_1EAC:
    push dx
    mov  si,[0x7973]
    mov  dx,[0x796b]
    call C688:1B12
    jnz  C688:1EE2
    sub  si,dx
    jns  C688:1ECB
    mov  si,[0x78fd]
    add  si,0x04
    sub  si,dx
    mov  dx,[0x796b]
    mov  dx,[0x7971]
    sub  si,dx
    jns  C688:1EDA
    mov  dx,[0x78fd]
    add  dx,0x04
    add  si,dx
    mov  dx,[0x796b]
    jmp  C688:1EF0
    sub  si,dx
    jns  C688:1EF0
    mov  dx,[0x7901]
    add  si,dx
    mov  dx,[0x796b]
    mov  [0x7973],si
    pop  si
    mov  bp,sp
    xchg [bp+0x00],si
    sub  si,dx
    mov  bp,sp
    xchg [bp+0x00],si
    xchg si,dx
    mov  si,[0x7a15]
    mov  [0x796b],si
    jmp  C688:1D7D
redraw_short_range_rebase_C688_1F0E:
    push dx
    mov  si,[0x7973]
    mov  dx,[0x796b]
    add  si,dx
    mov  [0x7973],si
    pop  si
    mov  bp,sp
    xchg [bp+0x00],si
    sub  si,dx
    jz   C688:1F33
    jc   C688:1F33
    mov  ax,si
    or   ah,ah
    jnz  C688:1EFC
    dec  al
    jnz  C688:1EFC
    mov  dx,0
    xchg si,dx
    sub  si,dx
    mov  [0x79f6],si
    mov  bp,sp
    xchg [bp+0x00],si
    xchg si,dx
redraw_state_save_tail_C688_1F45:
    mov  [0x796f],dx
    call C688:192C
    mov  dx,[0x7967]
    call C688:1A24
    xor  al,al
    test cl,0x20
    jz   C688:1F5D
    jmp  C688:24C9
    mov  al,[0x79df]
    cmp  al,0x02
    jz   C688:1F79
    or   al,al
    jnz  C688:1F70
    mov  si,[0x796f]
    push si
    jmp  C688:24CE
    dec  al
    jnz  C688:1F79
    xor  al,al
    jmp  C688:24F0
    xor  al,al
    jmp  C688:24C9
buffered_marker_dispatch_C688_1F7E:
    mov  bx,[0x75ef]
    mov  [bx],ch
    inc  word [0x75ef]
    mov  si,0x7956
    dec  byte [si]
    jz   C688:1F92
    jmp  C688:1D7C
    and  cl,0x7f
    call C688:A378
    cmp  al,0xee
    jnz  C688:1F9F
    jmp  C688:21D7
    cmp  al,0xe8
    jnz  C688:1FA6
    jmp  C688:209B
    cmp  al,0xef
    jz   C688:1FAD
    jmp  C688:207F
marker_ef_or_width_clamp_C688_1FAD:
    mov  al,[0x79f8]
    test cl,0x10
    jz   C688:1FB8
    mov  al,[0x79fc]
    cmp  al,0x06
    jnz  C688:1FE6
    mov  al,[0x79a1]
    test al,0x01
    jz   C688:1FC6
    jmp  C688:1D7C
    test cl,0x10
    jnz  C688:1FCE
    jmp  C688:1D7C
    mov  si,[0x79fa]
    mov  [0x79f8],si
    call C688:1C5F
    mov  dx,[0x796b]
    add  si,dx
    mov  [0x796b],si
    jmp  C688:1D7C
    test cl,0x10
    jnz  C688:204E
    cmp  al,0x04
    jnz  C688:2068
    mov  byte [0x793b],0xcb
    mov  al,0xff
    mov  [0x797f],al
    mov  dx,0
    test cl,0x08
    jz   C688:2004
    jmp  C688:2310
    mov  al,[0x79a1]
    test al,0x01
    jz   C688:200E
    jmp  C688:2043
    mov  dx,[0x7973]
    mov  si,[0x79f6]
    add  si,dx
    mov  dx,[0x78fd]
    sub  si,dx
    js   C688:2026
    mov  si,[0x7907]
    jmp  C688:2028
    add  si,dx
    xchg si,dx
    mov  si,[0x79f9]
    sub  si,dx
    mov  dx,0x0002
    sub  si,dx
    jns  C688:203A
    mov  si,0
    add  si,dx
    mov  [0x796b],si
    or   cl,0x02
    mov  al,0xcb
    mov  [0x793b],al
    mov  dx,0
    jmp  C688:1E61
marker_width_clamp_alt_C688_204E:
    cmp  al,0x04
    jnz  C688:2068
    mov  al,[0x79a1]
    test al,0x01
    jnz  C688:2043
    mov  ax,[0x79fa]
    mov  dx,[0x79f8]
    xchg al,ah
    mov  si,ax
    xchg dl,dh
    jmp  C688:202E

marker_saved_span_C688_2068:
    mov  si,[0x79f9]
    test cl,0x10
    jz   C688:2078
    mov  ax,[0x79f8]
    xchg al,ah
    mov  si,ax
    mov  [0x796d],si
    jmp  C688:1D7C
marker_misc_dispatch_C688_207F:
    cmp  al,0xed
    jnz  C688:20D6
    mov  al,[0x79f8]
    mov  si,[0x79a1]
    test si,0x0001
    jz   C688:2092
    mov  al,0x02
    mov  [0x796b],al
    mov  [0x7a15],al
    jmp  C688:1D7C

marker_e8_saved_start_C688_209B:
    mov  si,[0x79f8]
    test cl,0x10
    jz   C688:20AA
    mov  ax,si
    xchg al,ah
    mov  si,ax
    mov  [0x7961],si
    jmp  C688:1D7C

marker_e9_jump_table_C688_20D6:
    cmp  al,0xe9
    jz   C688:20DD
    jmp  C688:21AA
    mov  si,[0x79f8]
    test cl,0x10
    jz   C688:20EA
    mov  si,[0x79fa]
    and  si,0x00ff
    mov  dx,0x20f5
    add  si,dx
    jmp  si
    jmp  C688:2150
    jmp  C688:2158
    jmp  C688:211A
    jmp  C688:2113
...
    jmp  C688:20B1
    jmp  C688:2150
    mov  al,0xdf
    mov  ch,al
    jmp  C688:1E57
marker_e9_table_cases_C688_211A:
    mov  al,[0x78d5]
    test al,0x10
    jz   C688:2150
    mov  al,[0x799c]
    cmp  al,0x04
    jz   C688:2150
    test cl,0x10
    jnz  C688:2155
    mov  word [0x75ed],0x7a0f
    mov  si,[0x7977]
    mov  dx,[0x79f9]
    add  si,dx
    mov  dx,[0x790f]
    dec  dx
    add  si,dx
    call C688:0F49
    mov  word [0x75ed],0x795c
    jmp  C688:1D7D
    xor  al,al
    call C688:1D4D
    jmp  C688:1D7C

marker_e9_span_case_C688_2158:
    test cl,0x10
    jnz  C688:217A
    mov  dx,[0x7973]
    mov  si,[0x79f6]
    add  si,dx
    xchg si,dx
    mov  si,[0x78fd]
    sub  si,dx
    jns  C688:2175
    mov  dx,[0x7901]
    call C688:1CA7
    jmp  C688:217D
    call C688:1C5F
    or   cl,0x02
    mov  ch,0xd6
    mov  al,[0x79a1]
    test al,0x01
    jz   C688:218C
    jmp  C688:2195
    test cl,0x08
    jnz  C688:2195
    mov  [0x796b],si
    mov  al,ch
    call C688:2574
    mov  al,0xcb
    mov  [0x793b],al
    test cl,0x08
    jnz  C688:21A7
    jmp  C688:1E61
    jmp  C688:2310
marker_ec_e7_dispatch_C688_21AA:
    cmp  al,0xec
    jz   C688:21BB
    cmp  al,0xe7
    jz   C688:21B5
    jmp  C688:1D7C
    call C688:1286
    jmp  C688:1D7C
    mov  al,[0x79f8]
    test cl,0x20
    jz   C688:21C9
    call C688:61DB
    jmp  C688:1D7C
    mov  si,[0x79e2]
    call C688:1A51
    mov  [0x79e2],si
    jmp  C688:1D7C

marker_ee_boundary_C688_21D7:
    call C688:66FC
    test cl,0x08
    jz   C688:21E2
    jmp  C688:2310
    test cl,0x04
    jz   C688:21EA
    jmp  C688:1D7C
    mov  dx,[0x79f8]
    call C688:1CD7
    jmp  C688:1D7C
classifier_70_buffer_setup_C688_21F4:
; file 0x48A74
    cmp  al,0x70
    jnz  C688:2254
    mov  [0x7956],dx
    cmp  dx,0
    jz   C688:2204
    jmp  C688:2233
    mov  al,0x1f
    cmp  al,ch
    jz   C688:2210
    mov  al,0x1e
    cmp  al,ch
    jnz  C688:221B
    test cl,0x10
    jnz  C688:2218
    jmp  C688:A37F
    jmp  C688:1D7C
    mov  al,0xd1
    cmp  al,ch
    jz   C688:2224
    jmp  C688:1D7C
    call C688:A355
    jnz  C688:222C
    jmp  C688:1D7C
    mov  al,0xd7
    mov  ch,al
    jmp  C688:1E57
    mov  word [0x75ef],0x79f8
    or   cl,0x80
    mov  dx,[0x7967]
    mov  [0x7a19],dx
    mov  dx,[0x7969]
    mov  [0x7a17],dx
    pop  dx
    mov  [0x79fe],dx
    jmp  C688:1D7D
classifier_general_path_C688_2254:
    call C688:A494
    lahf
    push ax
    mov  al,ch
    and  al,0xfe
    cmp  al,0xea
    jnz  C688:2288
    mov  al,[0x790e]
    cmp  al,0x01
    mov  al,ch
    jnz  C688:2288
    mov  al,[0x7999]
    cmp  al,ch
    mov  al,ch
    jnz  C688:2288
    mov  dx,[0x78f3]
    mov  si,[0x79db]
    sub  si,dx
    jz   C688:2285
    mov  si,0x79ec
    or   byte [si],0x40
    call C688:1CD7
    pop  ax
    sahf
    mov  si,0x795e
    mov  dl,[si]
    push dx
    call C688:626D
    pop  dx
    mov  al,dl
    not  al
    and  al,[si]
    test al,0x04
    jz   C688:22A6
    xor  al,al
    mov  [0x7909],al
    mov  [0x790a],al
classifier_mode_gate_C688_22A6:
    mov  al,[0x79df]
    dec  al
    jz   C688:22B0
    jmp  C688:1D7C
    test cl,0x08
    jz   C688:22BF
    mov  al,[si]
    xor  al,dl
    and  al,dl
    test al,0x04
    jnz  C688:2314
    test cl,0x20
    jz   C688:22C7
    jmp  C688:1D7C
    mov  si,0x793b
    mov  al,[si]
    mov  byte [si],0
    or   al,al
    jnz  C688:22D6
    jmp  C688:1D7C
    mov  al,ch
    and  al,0xfe
    cmp  al,0xea
    mov  al,ch
    jz   C688:22E7
    jc   C688:22E5
    jmp  C688:23FF
    rcr  al,1
    and  al,0x01
    add  al,0xf2
    mov  ch,al
    jmp  C688:23FF
redraw_cl08_span_cache_C688_22F0:
; file 0x48B70
    mov  al,[0x795e]
    test al,0x04
    jnz  C688:22FA
    jmp  C688:2310
    nop
    mov  si,[0x7909]
    xchg si,dx
    sub  si,dx
    jnc  C688:2307
    jmp  C688:1D7C
    add  si,dx
    mov  [0x7909],si
    jmp  C688:1D7C

redraw_direct_span_return_C688_2310:
    mov  [0x7909],dx
    pop  si
    pop  si
    mov  al,ch
    mov  [0x7f25],al
    ret

redraw_final_span_gate_C688_231C:
    test cl,0x08
    jnz  C688:22F0
    mov  al,[0x795e]
    test al,0x04
    jz   C688:233F
    mov  si,[0x7909]
    xchg si,dx
    sub  si,dx
    jc   C688:233C
    xchg si,dx
    add  si,dx
    mov  [0x7909],si
    jmp  C688:233F
    mov  dx,0
    mov  si,[0x793b]
    test si,0x0002
    jz   C688:2356
    mov  al,[0x79df]
    or   al,al
    jz   C688:2392
    mov  al,[0x795e]
    mov  [0x7988],al
redraw_final_state_gate_C688_2356:
    mov  al,ch
    cmp  al,0xe0
    jc   C688:236A
    mov  al,[0x79a1]
    test al,0x10
    jz   C688:236A
    mov  ch,0xc0
    mov  al,ch
    jmp  C688:1E57
    mov  al,[0x79df]
    cmp  al,0x02
    jz   C688:2387
    or   al,al
    jz   C688:2392
    jns  C688:23F5
    test si,0x0002
    jnz  C688:237F
    jmp  C688:2384
    xor  al,al
    mov  [0x79df],al
    jmp  C688:1D7C
    test si,0x0002
    jz   C688:2384
    xor  al,al
    jmp  C688:24C4
redraw_active_output_builder_C688_2392:
    mov  ax,si
    mov  si,[0x79db]
    push si
    add  si,dx
    mov  [0x79db],si
    dec  si
    mov  dx,[0x7950]
    sub  si,dx
    pop  si
    jns  C688:23B0
    test al,0x02
    jz   C688:2384
    jmp  C688:24CE
    test al,0x02
    jz   C688:23C1
    mov  al,ch
    cmp  al,0xdb
    jz   C688:23C1
    cmp  al,0xd6
    jz   C688:23C1
    jmp  C688:24CE
    xchg si,dx
    xor  al,al
    sub  si,dx
    jc   C688:23CB
    mov  ax,si
    mov  [0x772b],al
    mov  si,[0x7952]
    sub  si,dx
    lahf
    push ax
    mov  al,0x01
    mov  [0x79df],al
    call C688:1BA9
    pop  ax
    sahf
    jnc  C688:2403
    mov  al,0x02
    mov  [0x79e2],si
    mov  si,[0x793b]
    test si,0x0002
    jz   C688:2381
    jmp  C688:24E9
    mov  si,[0x79db]
    add  si,dx
    mov  [0x79db],si
    mov  si,[0x79e2]
    mov  al,[0x793b]
    test al,0x08
    jz   C688:2415
    mov  al,[0x79ec]
    test al,0x40
    jz   C688:241C
    mov  ch,0x20
    jmp  C688:241C
    test al,0x02
    jz   C688:241C
    jmp  C688:24E5
    mov  [si],ch
    inc  si
    mov  [0x79e2],si
redraw_output_length_gate_C688_2423:
    mov  si,[0x79db]
    mov  dx,[0x7952]
    xor  al,al
    sub  si,dx
    jz   C688:2459
    jc   C688:245B
    mov  bx,si
    mov  dl,bl
    mov  si,[0x79e2]
    dec  si
    mov  al,[0x795e]
    test al,0x04
    jz   C688:244B
    dec  si
    mov  al,[si]
    cmp  al,0xf4
    jnz  C688:2459
    inc  si
    mov  byte [si],0xfe
    inc  si
    mov  [si],dl
    inc  si
    mov  [si],ch
    inc  si
    mov  [0x79e2],si
    mov  al,0x01
    mov  ch,al
    mov  al,[0x793b]
    test al,0x02
    jz   C688:2467
    jmp  C688:24E9
    mov  si,[0x79e2]
    mov  dx,0x7f28
    xor  al,al
    sub  si,dx
    mov  ax,si
    or   ah,ah
    jnz  C688:2495
    cmp  al,0xf0
    jnc  C688:247F
    jmp  C688:24A7
    cmp  al,0xf6
    jnc  C688:2495
    mov  al,[0x795e]
    test al,0x04
    jz   C688:248D
    jmp  C688:1D7C
    test cl,0x40
    jz   C688:2495
    jmp  C688:1D7C
    pop  si
    mov  [0x796f],si
    pop  si
    mov  si,0x790d
    or   byte [si],0x40
    mov  al,cl
    mov  [0x7a60],al
    ret
redraw_small_output_fallback_C688_24A7:
    mov  dx,[0x795e]
    test dl,0x04
    jz   C688:24B3
    jmp  C688:1D7C
    mov  al,ch
    or   al,al
    jnz  C688:24BC
    jmp  C688:1D7C
    mov  al,0x02
    mov  [0x79df],al
    jmp  C688:1D7C

redraw_return_tail_C688_24C4:
    pop  dx
    mov  [0x796f],dx
    pop  si
    mov  [0x79df],al
    ret
redraw_final_clamp_C688_24CE:
; file 0x48D4E
    mov  si,[0x79db]
    mov  dx,[0x7950]
    sub  si,dx
    jnc  C688:24E2
    mov  si,[0x7950]
    mov  [0x79db],si
    call C688:1BA9
    mov  [0x79e2],si
    xor  al,al
    pop  dx
    mov  [0x796f],dx

redraw_final_mode_span_C688_24F0:
    test cl,0x20
    jnz  C688:24C9
    lahf
    push ax
    mov  al,[0x795e]
    test al,0x01
    jz   C688:250A
    mov  si,[0x79e2]
    mov  byte [si],0xf1
    inc  si
    mov  [0x79e2],si
    mov  dx,[0x79db]
    mov  si,[0x7952]
    sub  si,dx
    call C688:1C39
    pop  ax
    sahf
    jmp  C688:24C9
classify_redraw_stream_byte_C688_2574:
; file 0x48DF4
    mov  bl,al
    xor  bh,bh
    mov  bp,bx
    xor  dx,dx
    add  bx,bx
    mov  ax,[cs:bx+0x6ec4]
    mov  [0x793b],al
    mov  al,ah
    and  al,0xf0
    js   C688:25CF
    mov  bx,[0x75ed]
    or   dl,[bx+0x0004]
    jz   C688:25A1
    test byte [bx+0x0002],0x08
    jnz  C688:259E
    ret
    rol  dl,1
    ret
    sub  bp,0x20
    push es
    push si
    mov  dx,0xd7ef
    mov  es,dx
    mov  dl,[0x6d59]
    xor  dh,dh
    add  dx,dx
    mov  si,0x0038
    add  si,dx
    mov  si,[es:si]
    mov  dl,[es:bp+si]
    pop  si
    pop  es
    mov  bx,[0x75ed]
    test byte [bx+0x0002],0x08
    jnz  C688:25CC
    ret
    add  dl,dl
    ret
    mov  dl,ah
    and  dl,0x0f
    mov  al,ah
    and  al,0x70
    ret
merge_redraw_marker_mask_C688_626D:
; file 0x4CAED
    xchg [0x75f1],ax
    mov  al,[0x793b]
    mov  dh,al
    not  al
    mov  dl,al
    mov  al,[si]
    and  al,dl
    mov  dl,al
    xchg [0x75f1],ax
    xor  al,cl
    test al,0x10
    mov  al,dl
    jz   C688:628E
    or   al,dh
    mov  [si],al
    ret
synthetic_stream_allowed_predicate_C688_A355:
; file 0x50BD5
    mov  si,[0x79a1]
    mov  bx,si
    test bl,0x10
    jnz  C688:A361
    ret
    test cl,0x40
    jnz  C688:A375
    test cl,0x04
    jnz  C688:A375
    mov  si,[0x78d5]
    mov  bx,si
    test bl,0x01
    ret
    cmp  al,al
    ret
predicated_synthetic_stream_builder_C688_A378:
; file 0x50BF8
    call C688:A355
    jnz  C688:A37E
    ret
    pop  dx

synthetic_stream_builder_C688_A37F:
    mov  si,0x8029
    mov  word [si],0x00f2
    cmp  al,0x1f
    jz   C688:A3BA
    cmp  al,0x1e
    jz   C688:A3B4
    cmp  al,0xee
    jnz  C688:A395
    jmp  C688:A490
    cmp  al,0xed
    jnz  C688:A3C1
    mov  al,0x0c
    call C688:A47F
    mov  al,[0x79f9]
    add  al,0x30
    mov  [si],al
    inc  si
    mov  byte [si],0xdc
    inc  si
    mov  al,[0x79f8]
    add  al,0x30
    mov  [si],al
    inc  si
    jmp  C688:A3F8
    inc  si
    mov  byte [si],0x52
    jmp  C688:A3BE
    inc  si
    mov  byte [si],0x72
    inc  si
    jmp  C688:A3F8
    cmp  al,0xe9
    jnz  C688:A3FB
    mov  al,[0x79f8]
    cmp  al,0x1c
    jnz  C688:A3DD
    mov  byte [si],0xbb
    inc  si
    mov  al,[0x79f9]
    mov  [si],al
    inc  si
    mov  byte [si],0xbb
    inc  si
    jmp  C688:A4DD
    cmp  al,0x1a
    lahf
    push ax
    add  al,0x10
    call C688:A47F
    pop  ax
    sahf
    jnz  C688:A3F8
    mov  al,[0x79fa]
    cmp  al,0
    mov  al,0xdd
    jns  C688:A3F5
    mov  al,0xde
    mov  [si],al
    inc  si
    jmp  C688:A4D2
synthetic_stream_extended_markers_C688_A3FB:
    cmp  al,0xef
    jnz  C688:A418
    mov  al,[0x79f8]
    cmp  al,0x06
    jnz  C688:A40A
    xor  al,al
    jmp  C688:A3DD
    inc  si
    mov  byte [si],0x56
    inc  si
    mov  byte [si],0x54
    inc  si
    mov  dx,0x79fc
    jmp  C688:A424
    cmp  al,0xe8
    jnz  C688:A469
    mov  al,0x0e
    call C688:A47F
    mov  dx,0x79fb
    push cx
    push word [0x75ed]
    push si
    pop  word [0x75ed]
    mov  bp,dx
    mov  bh,[bp+0x00]
    dec  bp
    mov  bl,[bp+0x00]
    dec  bp
    mov  dx,bp
    mov  si,bx
    push dx
    call C688:0EF2
    pop  dx
    mov  bx,[0x75ed]
    mov  byte [bx],0xdc
    inc  bx
    mov  [0x75ed],bx
    mov  bp,dx
    mov  bh,[bp+0x00]
    dec  bp
    mov  bl,[bp+0x00]
    mov  si,bx
    mov  dx,bp
    call C688:0EF2
    push word [0x75ed]
    pop  si
    pop  word [0x75ed]
    pop  cx
    jmp  C688:A4D2
    mov  al,0x0a
    call C688:A47F
    mov  al,[0x79f9]
    call C688:A480
    mov  byte [si],0xdc
    mov  al,[0x79f8]
    call C688:A47F
    jmp  C688:A4D2
    inc  si
    mov  bl,al
    mov  bh,0
    mov  dx,0x774d
    add  bx,dx
    mov  dx,[bx]
    mov  [si],dx
    inc  si
    inc  si
    ret
    mov  al,0x08
    jmp  C688:A41E
classifier_pair_synthetic_stream_C688_A494:
    call C688:A355
    jnz  C688:A49A
    ret
    pop  dx
    mov  al,ch
    and  al,0xfe
    cmp  al,0xea
    jnz  C688:A4AB
    mov  al,ch
    and  al,0x01
    add  al,0xf2
    mov  ch,al
    mov  bl,ch
    shr  bl,1
    mov  dx,0x7746
    sub  dx,0x78
    mov  bh,0
    mov  si,bx
    add  si,dx
    mov  al,[si]
    mov  si,0x8029
    mov  byte [si],0xf2
    inc  si
    mov  [si],al
    inc  si
    mov  al,ch
    and  al,0x01
    xor  al,0x01
    add  al,0x30
    mov  [si],al
    inc  si

synthetic_stream_handoff_tail_C688_A4D2:
    mov  al,[0x795e]
    test al,0x02
    jnz  C688:A4DD
    mov  byte [si],0xf3
    inc  si
    mov  byte [si],0xff
    pop  si
    mov  [0x7a13],si
    mov  dx,0x8029
    or   byte [0x824f],0x01
    or   cl,0x40
    jmp  C688:1D7D
decimal_emit_tail_C688_0EA3:
; file 0x47723
    mov  ch,0x03
    mov  bx,[0x75ef]
    push ds
    mov  ds,di
    mov  dx,[bx]
    pop  ds
    inc  word [0x75ef]
    inc  word [0x75ef]
    mov  cl,0x2f
    inc  cl
    sub  si,dx
    jnc  C688:0EB9
    add  si,dx
    mov  bx,[0x75ed]
    mov  [bx],cl
    inc  word [0x75ed]
    dec  ch
    jnz  C688:0EA5
    mov  bx,[0x75ed]
    mov  al,[bx-0x03]
    cmp  al,0x3a
    jns  C688:0EDB
    ret
    mov  byte [bx-0x03],0x78
    ret

decimal_emit_3_digit_C688_0EF2:
    mov  bx,0x0e7b
    mov  [0x75ef],bx
    mov  di,cs
    jmp  C688:0EA3

decimal_emit_4_digit_C688_0EFD:
    mov  bx,0x0e79
    mov  [0x75ef],bx
    mov  ch,0x04
    mov  di,cs
    jmp  C688:0EA5

decimal_emit_5_digit_C688_0F0A:
    mov  bx,0x0e77
    mov  [0x75ef],bx
    mov  ch,0x05
    mov  di,cs
    jmp  C688:0EA5

decimal_parse_3_digit_C688_0F17:
    mov  ch,0x03
    mov  dh,0
    mov  si,0
    mov  bx,[0x75ed]
    mov  al,[bx]
    or   al,al
    jnz  C688:0F29
    ret
    cmp  al,0x20
    jnz  C688:0F2E
    ret
    mov  dx,si
    add  si,si
    add  si,si
    add  si,dx
    add  si,si
    and  al,0x0f
    mov  dh,0
    mov  dl,al
    add  si,dx
    inc  word [0x75ed]
    dec  ch
    jnz  C688:0F1E
    ret
format_word_and_prepare_stream_C688_0F49:
    push cx
    push word [0x75ed]
    push word [0x75ef]
    call C688:0EF2
    pop  word [0x75ef]
    pop  word [0x75ed]
    pop  cx
    or   byte [0x824f],0x01
    or   cl,0x40
    pop  si
    mov  bp,sp
    xchg [bp+0x00],si
    mov  bx,[0x75ed]
    mov  [bx+0x04],si
    mov  byte [bx+0x03],0xff
    push word [0x75ed]
    pop  si
    mov  al,[si]
    cmp  al,0x30
    jnz  C688:0F8A
    inc  si
    mov  al,[si]
    cmp  al,0x30
    jnz  C688:0F8A
    inc  si
    xchg si,dx
    ret
marker_e7_noop_hook_C688_1286:
; file 0x47B06
    ret
quarter_width_helper_C688_4239:
; file 0x4AAB9
    shr  si,1
    shr  si,1
    ret
state_record_width_or_default_C688_66FC:
; file 0x4CF7C
    mov  bx,[0x75ed]
    mov  al,[bx+0x0004]
    or   al,al
    jnz  C688:670A
    mov  al,0x05
    mov  dl,al
    mov  dh,0
    ret
renderer_descriptor_type0a_C688_3C29:
; file 0x4A4A9
    mov  al,0x0a

renderer_descriptor_from_stack_C688_3C2B:
    pop  cx
    mov  si,0
    mov  [0x7741],si
    jmp  C688:3C3E

renderer_descriptor_type03_C688_3C35:
    mov  al,0x03
    pop  cx
    pop  si
    mov  [0x7741],si
    pop  si
    mov  [0x7743],si
    mov  [0x7745],al
    pop  si
    mov  [0x7739],si
    pop  si
    mov  [0x773b],si
    pop  si
    mov  [0x773d],si
    pop  si
    mov  [0x773f],si
    push cx
    mov  ax,si
    test ah,0x80
    jz   C688:3C62
    ret
    cmp  si,0
    jnz  C688:3C68
    ret

renderer_descriptor_flush_C688_3C68:
    mov  al,[0x7a56]
    test al,0x01
    jz   C688:3C70
    ret
    mov  al,0x05
    mov  [0x771d],al
    mov  si,0x7732
    mov  [0x771b],si
    call C688:6BAA
    ret
