; Generated from disasm: C688:D8AF-EF3B
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0xD8AF


spell_grammar_entry_C688_ED1F:
; file 0x5559F
    call 0x4f85
    jnc  loc_ED27
    jmp  loc_EDBE
loc_ED27:
    mov  si,0x8db4
    and  byte [si],0x7f
    mov  byte [0x8e3e],0x1
    mov  dl,0x23
    mov  ah,0x4
    call 0x936a
    cmp  dl,0x1
    jnz  loc_ED56
    cmp  byte [0x6d55],0x0
    jnz  loc_ED56
    mov  byte [0x8e3e],0x0
    call loc_EF24
    mov  si,0x8da8
    or   byte [si],0x1
    and  byte [si],0xfd
loc_ED56:
    mov  si,0x1d
    cmp  byte [0x8e3e],0x0
    jnz  loc_ED63
    mov  si,0x8c
loc_ED63:
    call 0x7689
    call loc_D9B0
    call 0xd283
    jnc  loc_ED7C
    call loc_EEA8
    call loc_D9B5
    call 0xefab
    call loc_EEC2
    jnc  loc_ED56
loc_ED7C:
    mov  byte [0x8da8],0x0
    jmp  loc_EC9F
grammar_setup_C688_EF24:
; file 0x557A4
loc_EF24:
    call loc_EF31
    ret
loc_EF31:
    mov  dl,0x28
    call 0xd83d
    mov  byte [0x8da8],0x0
    ret
dictionary_entry_C688_D8AF:
; file 0x5412F
    call 0x4f85
    jnc  loc_D8B7
    jmp  loc_EDBE
loc_D8B7:
    mov  si,0x8db4
    and  byte [si],0x7f
    call 0x9717
    call 0x44c4
    call 0x9740
    call 0x2cfa
    call 0x8610
    call 0xd62c
    call loc_DDE0
    call 0xd64d
    call 0x44c4
    call 0xd60f
    jz   loc_D8E0
    jmp  loc_D948
loc_D8E0:
    mov  si,0x7f28
    mov  al,[si]
    or   al,al
    jnz  loc_D8EC
    jmp  loc_D978
loc_D8EC:
    mov  dx,0x8dba
    call 0xf11b
    mov  si,0x8dba
    call 0xf0f9
loc_D8F8:
    call loc_D9B5
    mov  si,0x39
    call 0x7689
    mov  cl,0x1
    mov  dx,0x75a0
    call 0x71b5
    call 0xf132
    call 0x92df
dictionary_action_handlers_C688_D927:
; file 0x541A7
    call loc_E0CB
    cmp  al,0x1
    jz   loc_D8F8
    jmp  loc_D948
    mov  si,0x8dba
    mov  di,0x757f
    mov  cx,0x20
    push es
    mov  bp,0
    mov  es,bp
    cld
    rep  movsb
    pop  es
    mov  dx,di
    call 0xf09f
loc_D948:
    call 0x8610
    call loc_E016
    jz   loc_D96F
    call 0x972d
    jmp  loc_D972
loc_D96F:
    call loc_D955
loc_D972:
    call 0x44c4
    jmp  loc_EC9F
loc_D978:
    call 0x8610
    call 0x972d
    call 0x44c4
    jmp  loc_D9C3
dictionary_suggestion_browser_C688_D9C3:
; file 0x54243
loc_D9C3:
    mov  byte [0x8e34],0
    call 0x4f85
    jnc  loc_D9D0
    jmp  loc_EDBE
loc_D9D0:
    mov  si,0x8db4
    mov  si,0x3a
    call 0x7689
    mov  si,0x8e13
    mov  [0x8e11],si
    mov  dl,0x9
    mov  ah,0x4
    call 0x936a
    mov  al,dl
    mov  [0x8db5],al
    mov  [0x8db6],al
    or   al,al
    jz   loc_DA4B
    mov  byte [0x8da9],0
    mov  byte [0x8daa],0
    mov  byte [0x8dab],0
    mov  al,0x10
    mov  [0x8db7],al
    call loc_DD5C
    jc   loc_DA29
...
loc_DA4B:
    mov  si,0x3e
    call 0x7689
    mov  cl,0x1
    call 0x71a4
    mov  al,[0x794a]
    cmp  al,0x3
    jnz  loc_DA4B
    jmp  loc_EC9F
thesaurus_entry_C688_E274:
; file 0x54AF4
    call 0x4f85
    jnc  loc_E27C
    jmp  loc_EDBE
loc_E27C:
    call loc_E282
    jmp  loc_EC9F

thesaurus_screen_setup_C688_E282:
loc_E282:
    mov  si,0x8db4
    and  byte [si],0x7f
    call 0x9717
    call 0x44c4
    call 0x9740
    call 0x2cfa
    call 0x8610
    call 0xd62c
    call loc_DDE0
    call 0xd64d
    call 0x44c4
    call 0xd60f
    jnz  loc_E2CE
    mov  si,0x7f28
    mov  al,[si]
    or   al,al
    jz   loc_E2CE
    mov  dx,0x8dba
    call 0xf11b
    mov  si,0x8dba
    call 0xf0f9
    mov  si,0x76
    call 0x7689
    mov  cl,0x1
    mov  dx,0x75a0
    call 0x71b5
    call loc_E2EA
loc_E2CE:
    cmp  al,0x1
    jnz  loc_E2DB
    mov  si,0x7a
    call 0x7689
    call 0x96ed
loc_E2DB:
    call 0x8610
    call 0x972d
    jmp  loc_E2E6
    call loc_D955
loc_E2E6:
    call 0x44c4
    ret
