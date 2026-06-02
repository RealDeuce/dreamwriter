bits 16

%ifndef SPLIT_SPIKE_DAT_ORG
SPLIT_SPIKE_DAT_ORG equ 0x1000
%endif
org SPLIT_SPIKE_DAT_ORG

%ifndef SPLIT_SPIKE_DAT_PAD_SIZE
SPLIT_SPIKE_DAT_PAD_SIZE equ 128
%endif

spike_dat_magic:
    db "SPKDAT01"

times 0x0010 - ($ - $$) db 0
spike_dat_title:
    db "SPLIT SPIKE DAT OK", 0

times 0x0040 - ($ - $$) db 0
spike_dat_prompt:
    db "PRESS SPACE TO RETURN", 0

%if ($ - $$) > SPLIT_SPIKE_DAT_PAD_SIZE
%error "split spike DAT exceeds SPLIT_SPIKE_DAT_PAD_SIZE"
%endif
    times SPLIT_SPIKE_DAT_PAD_SIZE - ($ - $$) db 0
