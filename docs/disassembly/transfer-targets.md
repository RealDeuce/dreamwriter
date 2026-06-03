# Transfer Target Audit

Generated from direct call/jump operands in annotated snippets. Address-only targets are not automatically wrong; they are review candidates.

| Target | Symbol(s) | Transfers | Sample sources |
| ---: | --- | ---: | --- |
| `3000:0037` | (address-only) | 5 | call from `3000:4D4E` [diagnostic-spell-services.md:137](diagnostic-spell-services.md#L137)<br>call from `3000:4D51` [diagnostic-spell-services.md:138](diagnostic-spell-services.md#L138)<br>call from `3000:4D54` [diagnostic-spell-services.md:139](diagnostic-spell-services.md#L139)<br>call from `3000:4D57` [diagnostic-spell-services.md:140](diagnostic-spell-services.md#L140)<br>call from `3000:4D5A` [diagnostic-spell-services.md:141](diagnostic-spell-services.md#L141) |
| `3000:3646` | (address-only) | 1 | call from `3000:4D2E` [diagnostic-spell-services.md:120](diagnostic-spell-services.md#L120) |
| `3000:39E0` | (address-only) | 1 | call from `3000:4D75` [diagnostic-spell-services.md:158](diagnostic-spell-services.md#L158) |
| `3000:3A1E` | (address-only) | 1 | call from `3000:4D7B` [diagnostic-spell-services.md:160](diagnostic-spell-services.md#L160) |
| `3000:3AAC` | (address-only) | 1 | call from `3000:4D44` [diagnostic-spell-services.md:126](diagnostic-spell-services.md#L126) |
| `3000:4CF4` | (address-only) | 1 | call from `3000:4BF2` [diagnostic-spell-services.md:60](diagnostic-spell-services.md#L60) |
| `3000:4D02` | (address-only) | 1 | jc from `3000:4D14` [diagnostic-spell-services.md:91](diagnostic-spell-services.md#L91) |
| `3000:4D0D` | (address-only) | 1 | jmp from `3000:4D00` [diagnostic-spell-services.md:84](diagnostic-spell-services.md#L84) |
| `3000:4D1A` | (address-only) | 1 | call from `3000:4BFA` [diagnostic-spell-services.md:66](diagnostic-spell-services.md#L66) |
| `3000:4D21` | (address-only) | 1 | jmp from `3000:4D63` [diagnostic-spell-services.md:143](diagnostic-spell-services.md#L143) |
| `3000:4D26` | (address-only) | 1 | jz from `3000:4D1F` [diagnostic-spell-services.md:112](diagnostic-spell-services.md#L112) |
| `3000:4D66` | (address-only) | 1 | jz from `3000:4D49` [diagnostic-spell-services.md:128](diagnostic-spell-services.md#L128) |
| `3000:4D6A` | (address-only) | 1 | call from `3000:4D4B` [diagnostic-spell-services.md:136](diagnostic-spell-services.md#L136) |
| `3000:4F76` | (address-only) | 1 | call from `3000:4D6A` [diagnostic-spell-services.md:153](diagnostic-spell-services.md#L153) |
| `3000:5016` | (address-only) | 1 | call from `3000:4D1A` [diagnostic-spell-services.md:110](diagnostic-spell-services.md#L110) |
| `3000:527C` | (address-only) | 1 | call from `3000:4D3E` [diagnostic-spell-services.md:124](diagnostic-spell-services.md#L124) |
| `C000:0000` | `root_c000_entry` | 1 | jmp from `F8DC:0008` [boot.md:30](boot.md#L30) |
| `C000:0029` | `startup_C000_0029` | 1 | jmp from `C000:12E5` [diagnostic-monitor.md:171](diagnostic-monitor.md#L171) |
| `C000:011A` | (address-only) | 1 | jz from `C000:0157` [boot.md:225](boot.md#L225) |
| `C000:0192` | (address-only) | 1 | jc from `C000:019E` [boot.md:255](boot.md#L255) |
| `C000:02A3` | (address-only) | 1 | call from `C000:0102` [boot.md:189](boot.md#L189) |
| `C000:02B3` | (address-only) | 2 | call from `C000:013D` [boot.md:218](boot.md#L218)<br>call from `C000:0168` [boot.md:233](boot.md#L233) |
| `C000:036A` | (address-only) | 1 | jz from `C000:0365` [power-irq.md:102](power-irq.md#L102) |
| `C000:0370` | `terminal_power_handoff_C000_0370` | 1 | jmp from `C000:07E6` [rtc-alarm-power.md:30](rtc-alarm-power.md#L30) |
| `C000:038B` | (address-only) | 1 | jc from `C000:0386` [power-irq.md:133](power-irq.md#L133) |
| `C000:039D` | `enable_alarm_output_C000_039D` | 2 | jmp from `C000:03AC` [power-irq.md:151](power-irq.md#L151)<br>call from `C000:07E3` [rtc-alarm-power.md:29](rtc-alarm-power.md#L29) |
| `C000:0428` | (address-only) | 1 | jmp from `C000:0436` [power-irq.md:219](power-irq.md#L219) |
| `C000:0441` | (address-only) | 1 | loop from `C000:0444` [power-irq.md:233](power-irq.md#L233) |
| `C000:044B` | `checksum_builtin_store_C000_044B` | 1 | call from `C000:12DD` [diagnostic-monitor.md:169](diagnostic-monitor.md#L169) |
| `C000:0477` | (address-only) | 1 | loop from `C000:047A` [power-irq.md:254](power-irq.md#L254) |
| `C000:04EE` | (address-only) | 1 | jz from `C000:04E7` [keyboard-irq.md:117](keyboard-irq.md#L117) |
| `C000:057F` | (address-only) | 2 | jmp from `C000:059F` [device-irq.md:79](device-irq.md#L79)<br>jmp from `C000:05B3` [device-irq.md:88](device-irq.md#L88) |
| `C000:05D9` | (address-only) | 1 | jz from `C000:05D2` [device-irq.md:112](device-irq.md#L112) |
| `C000:05E2` | (address-only) | 1 | jz from `C000:05DB` [device-irq.md:115](device-irq.md#L115) |
| `C000:05EB` | (address-only) | 1 | jz from `C000:05E4` [device-irq.md:118](device-irq.md#L118) |
| `C000:0764` | (address-only) | 1 | jmp from `C000:077A` [device-irq.md:213](device-irq.md#L213) |
| `C000:077C` | (address-only) | 1 | call from `DC98:2974` [setup-screens.md:208](setup-screens.md#L208) |
| `C000:086C` | (address-only) | 1 | call from `C000:52C5` [int21-dispatch.md:299](int21-dispatch.md#L299) |
| `C000:087F` | `tone_duration_far_C000_087F` | 1 | call from `DC98:0DB8` [sound-lowlevel.md:24](sound-lowlevel.md#L24) |
| `C000:08A3` | (address-only) | 2 | call from `C000:169B` [diagnostic-keyboard-check.md:78](diagnostic-keyboard-check.md#L78)<br>call from `C000:129F` [diagnostic-monitor.md:125](diagnostic-monitor.md#L125) |
| `C000:0920` | `centronics_write_dl_C000_0920` | 1 | call from `C000:5146` [int21-dispatch.md:161](int21-dispatch.md#L161) |
| `C000:096A` | `tone_duration_C000_096A` | 1 | call from `C000:087F` [sound-lowlevel.md:38](sound-lowlevel.md#L38) |
| `C000:0979` | (address-only) | 1 | jmp from `C000:0974` [sound-lowlevel.md:57](sound-lowlevel.md#L57) |
| `C000:0995` | (address-only) | 1 | jnz from `C000:098D` [sound-lowlevel.md:62](sound-lowlevel.md#L62) |
| `C000:099C` | `tone_on_C000_099C` | 2 | call from `C000:15B7` [diagnostic-int1.md:58](diagnostic-int1.md#L58)<br>call from `C000:15D5` [diagnostic-int1.md:84](diagnostic-int1.md#L84) |
| `C000:09A9` | `tone_off_C000_09A9` | 1 | call from `C000:15DE` [diagnostic-int1.md:88](diagnostic-int1.md#L88) |
| `C000:09AE` | (address-only) | 1 | call from `C000:526C` [int21-dispatch.md:267](int21-dispatch.md#L267) |
| `C000:09C9` | (address-only) | 1 | call from `C000:5205` [int21-dispatch.md:249](int21-dispatch.md#L249) |
| `C000:0A11` | `program_selected_alarm_C000_0A11` | 1 | call from `C000:0395` [power-irq.md:141](power-irq.md#L141) |
| `C000:0A3F` | `program_minute_plus_one_C000_0A3F` | 2 | call from `C000:03A4` [power-irq.md:149](power-irq.md#L149)<br>call from `C000:07DB` [rtc-alarm-power.md:27](rtc-alarm-power.md#L27) |
| `C000:0A9F` | (address-only) | 2 | jmp from `C000:0AB0` [battery-status.md:69](battery-status.md#L69)<br>jmp from `C000:0AC2` [battery-status.md:85](battery-status.md#L85) |
| `C000:0B50` | `disarm_timer_C000_0B50` | 2 | call from `C000:0358` [power-irq.md:86](power-irq.md#L86)<br>call from `C000:047D` [power-irq.md:266](power-irq.md#L266) |
| `C000:0B60` | `rtc_snapshot_C000_0B60` | 2 | call from `C000:517C` [int21-dispatch.md:235](int21-dispatch.md#L235)<br>call from `C000:5213` [int21-dispatch.md:257](int21-dispatch.md#L257) |
| `C000:0B7C` | `short_alarm_compare_C000_0B7C` | 1 | call from `C000:0388` [power-irq.md:134](power-irq.md#L134) |
| `C000:0B90` | `full_alarm_compare_C000_0B90` | 1 | call from `C000:0383` [power-irq.md:132](power-irq.md#L132) |
| `C000:0CBC` | `serial_reinit_C000_0CBC` | 1 | call from `C000:52D0` [int21-dispatch.md:304](int21-dispatch.md#L304) |
| `C000:0D25` | (address-only) | 1 | call from `C000:52D4` [int21-dispatch.md:306](int21-dispatch.md#L306) |
| `C000:0F27` | `default_vector_fill_11_F7_C000_0F27` | 1 | loop from `C000:0F2D` [installed-vectors.md:30](installed-vectors.md#L30) |
| `C000:0F3B` | `seed_irq_vector_loop_C000_0F3B` | 1 | loop from `C000:0F44` [installed-vectors.md:74](installed-vectors.md#L74) |
| `C000:0F5B` | `seed_irq_vector_tail_C000_0F5B` | 1 | loop from `C000:0F64` [installed-vectors.md:91](installed-vectors.md#L91) |
| `C000:123C` | `forced_diagnostic_entry_C000_123C` | 1 | call from `C688:01B0` [early-app-helper.md:28](early-app-helper.md#L28) |
| `C000:1247` | `diagnostic_banner_and_loop_C000_1247` | 5 | jz from `C000:1243` [diagnostic-monitor.md:27](diagnostic-monitor.md#L27)<br>jmp from `C000:124F` [diagnostic-monitor.md:33](diagnostic-monitor.md#L33)<br>call from `C000:123C` [early-app-helper.md:41](early-app-helper.md#L41)<br>jmp from `C000:124F` [early-app-helper.md:57](early-app-helper.md#L57)<br>jz from `C000:1243` [early-app-helper.md:67](early-app-helper.md#L67) |
| `C000:1251` | (address-only) | 2 | jc from `C000:124D` [diagnostic-monitor.md:32](diagnostic-monitor.md#L32)<br>jc from `C000:124D` [early-app-helper.md:56](early-app-helper.md#L56) |
| `C000:1252` | `diagnostic_chord_compare_C000_1252` | 3 | call from `C000:1240` [diagnostic-monitor.md:26](diagnostic-monitor.md#L26)<br>call from `C000:1240` [early-app-helper.md:66](early-app-helper.md#L66)<br>call from `C000:0316` [power-irq.md:48](power-irq.md#L48) |
| `C000:1272` | `diagnostic_draw_short_banner_C000_1272` | 3 | call from `C000:1247` [diagnostic-monitor.md:30](diagnostic-monitor.md#L30)<br>call from `C000:12D8` [diagnostic-monitor.md:165](diagnostic-monitor.md#L165)<br>call from `C000:1247` [early-app-helper.md:54](early-app-helper.md#L54) |
| `C000:128F` | `diagnostic_command_loop_C000_128F` | 3 | call from `C000:124A` [diagnostic-monitor.md:31](diagnostic-monitor.md#L31)<br>jmp from `C000:12DB` [diagnostic-monitor.md:166](diagnostic-monitor.md#L166)<br>call from `C000:124A` [early-app-helper.md:55](early-app-helper.md#L55) |
| `C000:1297` | (address-only) | 3 | jz from `C000:12AB` [diagnostic-monitor.md:130](diagnostic-monitor.md#L130)<br>jmp from `C000:12CC` [diagnostic-monitor.md:146](diagnostic-monitor.md#L146)<br>jmp from `C000:12D3` [diagnostic-monitor.md:161](diagnostic-monitor.md#L161) |
| `C000:12E8` | (address-only) | 1 | jz from `C000:1341` [diagnostic-monitor.md:207](diagnostic-monitor.md#L207) |
| `C000:1306` | (address-only) | 1 | jmp from `C000:12FF` [diagnostic-spell-services.md:18](diagnostic-spell-services.md#L18) |
| `C000:1382` | (address-only) | 1 | jc from `C000:137C` [diagnostic-monitor.md:215](diagnostic-monitor.md#L215) |
| `C000:13A1` | (address-only) | 1 | jmp from `C000:1319` [diagnostic-spell-services.md:34](diagnostic-spell-services.md#L34) |
| `C000:140C` | (address-only) | 2 | jnz from `C000:146E` [diagnostic-monitor.md:261](diagnostic-monitor.md#L261)<br>jmp from `C000:13FC` [diagnostic-monitor.md:320](diagnostic-monitor.md#L320) |
| `C000:1427` | (address-only) | 2 | jz from `C000:1412` [diagnostic-monitor.md:242](diagnostic-monitor.md#L242)<br>jz from `C000:1419` [diagnostic-monitor.md:244](diagnostic-monitor.md#L244) |
| `C000:147B` | (address-only) | 1 | jnz from `C000:1475` [diagnostic-monitor.md:290](diagnostic-monitor.md#L290) |
| `C000:14B4` | `diagnostic_read_dump_byte_C000_14B4` | 1 | call from `C000:143E` [diagnostic-monitor.md:253](diagnostic-monitor.md#L253) |
| `C000:14D4` | (address-only) | 2 | jz from `C000:14BF` [diagnostic-monitor.md:272](diagnostic-monitor.md#L272)<br>jz from `C000:14C6` [diagnostic-monitor.md:274](diagnostic-monitor.md#L274) |
| `C000:14D9` | (address-only) | 1 | jmp from `C000:14D2` [diagnostic-monitor.md:279](diagnostic-monitor.md#L279) |
| `C000:14DA` | (address-only) | 1 | call from `C000:1467` [diagnostic-monitor.md:258](diagnostic-monitor.md#L258) |
| `C000:15DB` | (address-only) | 1 | jnz from `C000:15DC` [diagnostic-int1.md:87](diagnostic-int1.md#L87) |
| `C000:15E4` | (address-only) | 1 | jnz from `C000:15EB` [diagnostic-int1.md:94](diagnostic-int1.md#L94) |
| `C000:15E7` | (address-only) | 1 | jnz from `C000:15E8` [diagnostic-int1.md:92](diagnostic-int1.md#L92) |
| `C000:15F0` | (address-only) | 1 | call from `C000:1303` [diagnostic-spell-services.md:22](diagnostic-spell-services.md#L22) |
| `C000:15FE` | `diagnostic_reset_command_state_C000_15FE` | 2 | call from `C000:1294` [diagnostic-monitor.md:122](diagnostic-monitor.md#L122)<br>call from `C000:16FF` [diagnostic-monitor.md:396](diagnostic-monitor.md#L396) |
| `C000:1617` | (address-only) | 1 | call from `C000:12A2` [diagnostic-monitor.md:126](diagnostic-monitor.md#L126) |
| `C000:1645` | (address-only) | 2 | call from `C000:141F` [diagnostic-monitor.md:246](diagnostic-monitor.md#L246)<br>call from `C000:142B` [diagnostic-monitor.md:250](diagnostic-monitor.md#L250) |
| `C000:1650` | (address-only) | 1 | call from `C000:1447` [diagnostic-monitor.md:256](diagnostic-monitor.md#L256) |
| `C000:1674` | `diagnostic_putc_C000_1674` | 2 | call from `C000:12C9` [diagnostic-monitor.md:145](diagnostic-monitor.md#L145)<br>call from `C000:1424` [diagnostic-monitor.md:248](diagnostic-monitor.md#L248) |
| `C000:1687` | (address-only) | 2 | jc from `C000:167A` [diagnostic-monitor.md:413](diagnostic-monitor.md#L413)<br>jnc from `C000:167E` [diagnostic-monitor.md:415](diagnostic-monitor.md#L415) |
| `C000:1696` | `diagnostic_key_input_C000_1696` | 1 | call from `DC98:0CCC` [diagnostic-keyboard-check.md:44](diagnostic-keyboard-check.md#L44) |
| `C000:16A6` | `diagnostic_keyboard_check_C000_16A6` | 1 | call from `C000:12D5` [diagnostic-monitor.md:164](diagnostic-monitor.md#L164) |
| `C000:16B8` | (address-only) | 2 | call from `C000:132F` [diagnostic-monitor.md:201](diagnostic-monitor.md#L201)<br>call from `C000:146A` [diagnostic-monitor.md:259](diagnostic-monitor.md#L259) |
| `C000:16EB` | `diagnostic_help_page_C000_16EB` | 1 | call from `C000:12D0` [diagnostic-monitor.md:160](diagnostic-monitor.md#L160) |
| `C000:1716` | (address-only) | 1 | call from `C000:0021` [boot.md:68](boot.md#L68) |
| `C000:1873` | (address-only) | 1 | call from `C000:0025` [boot.md:70](boot.md#L70) |
| `C000:18A1` | (address-only) | 2 | call from `C000:12FB` [diagnostic-spell-services.md:16](diagnostic-spell-services.md#L16)<br>call from `C000:15F1` [diagnostic-spell-services.md:43](diagnostic-spell-services.md#L43) |
| `C000:23D9` | `status_lower_default_x_C000_23D9` | 1 | call from `C000:3C83` [storage-geometry.md:74](storage-geometry.md#L74) |
| `C000:23DE` | `status_lower_C000_23DE` | 1 | call from `C000:3CA2` [storage-geometry.md:97](storage-geometry.md#L97) |
| `C000:28A7` | `service_0E_select_drive_C000_28A7` | 1 | call from `C000:5163` [int21-dispatch.md:182](int21-dispatch.md#L182) |
| `C000:28B2` | (address-only) | 1 | jnc from `C000:28AC` [int21-filesystem-front.md:17](int21-filesystem-front.md#L17) |
| `C000:28B9` | `service_19_get_drive_C000_28B9` | 1 | call from `C000:5167` [int21-dispatch.md:184](int21-dispatch.md#L184) |
| `C000:28C3` | `service_1A_set_dta_C000_28C3` | 1 | call from `C000:516B` [int21-dispatch.md:186](int21-dispatch.md#L186) |
| `C000:28D0` | `service_2F_get_dta_C000_28D0` | 1 | call from `C000:5270` [int21-dispatch.md:189](int21-dispatch.md#L189) |
| `C000:28E0` | `service_36_free_space_C000_28E0` | 1 | call from `C000:5274` [int21-dispatch.md:191](int21-dispatch.md#L191) |
| `C000:28E8` | (address-only) | 1 | jnz from `C000:28E2` [int21-filesystem-front.md:57](int21-filesystem-front.md#L57) |
| `C000:298A` | (address-only) | 1 | jnz from `C000:2984` [int21-filesystem-front.md:69](int21-filesystem-front.md#L69) |
| `C000:29AD` | `service_3C_create_truncate_C000_29AD` | 1 | call from `C000:5278` [int21-dispatch.md:193](int21-dispatch.md#L193) |
| `C000:2A1B` | (address-only) | 1 | call from `C000:5304` [int21-dispatch.md:217](int21-dispatch.md#L217) |
| `C000:2B84` | `service_3D_open_C000_2B84` | 1 | call from `C000:527C` [int21-dispatch.md:195](int21-dispatch.md#L195) |
| `C000:2C41` | (address-only) | 1 | call from `C000:5280` [int21-dispatch.md:197](int21-dispatch.md#L197) |
| `C000:2C4A` | `private_format_C000_2C4A` | 1 | call from `C000:5112` [int21-dispatch.md:94](int21-dispatch.md#L94) |
| `C000:2D7F` | (address-only) | 1 | jz from `C000:2D74` [int21-format.md:126](int21-format.md#L126) |
| `C000:2DE2` | `service_4E_find_first_C000_2DE2` | 1 | call from `C000:52F4` [int21-dispatch.md:209](int21-dispatch.md#L209) |
| `C000:2E27` | (address-only) | 1 | call from `C000:52F8` [int21-dispatch.md:211](int21-dispatch.md#L211) |
| `C000:2FE5` | (address-only) | 1 | call from `C000:52FC` [int21-dispatch.md:213](int21-dispatch.md#L213) |
| `C000:3064` | `endpoint_probe_C000_3064` | 1 | call from `C000:52EC` [int21-dispatch.md:316](int21-dispatch.md#L316) |
| `C000:3083` | (address-only) | 1 | jc from `C000:307F` [int21-endpoints.md:27](int21-endpoints.md#L27) |
| `C000:3097` | (address-only) | 1 | jc from `C000:3093` [int21-endpoints.md:36](int21-endpoints.md#L36) |
| `C000:30A0` | (address-only) | 1 | jc from `C000:309C` [int21-endpoints.md:43](int21-endpoints.md#L43) |
| `C000:30B0` | `ioctl_4400_C000_30B0` | 1 | call from `C000:52C1` [int21-dispatch.md:297](int21-dispatch.md#L297) |
| `C000:30BC` | (address-only) | 1 | jnz from `C000:30B8` [int21-endpoints.md:72](int21-endpoints.md#L72) |
| `C000:30DA` | `service_57_file_datetime_C000_30DA` | 1 | call from `C000:5300` [int21-dispatch.md:215](int21-dispatch.md#L215) |
| `C000:311E` | `dreamlink_finish_wrapper_C000_311E` | 1 | call from `C000:52F0` [int21-dispatch.md:318](int21-dispatch.md#L318) |
| `C000:3134` | (address-only) | 1 | jz from `C000:312D` [int21-endpoints.md:124](int21-endpoints.md#L124) |
| `C000:3194` | `service_3F_read_C000_3194` | 1 | call from `C000:5284` [int21-dispatch.md:199](int21-dispatch.md#L199) |
| `C000:32B1` | `service_40_write_C000_32B1` | 1 | call from `C000:5288` [int21-dispatch.md:201](int21-dispatch.md#L201) |
| `C000:34BB` | (address-only) | 1 | jc from `C000:34E7` [int21-file-io.md:119](int21-file-io.md#L119) |
| `C000:356F` | `service_42_seek_C000_356F` | 1 | call from `C000:5290` [int21-dispatch.md:205](int21-dispatch.md#L205) |
| `C000:3730` | (address-only) | 1 | call from `C000:528C` [int21-dispatch.md:203](int21-dispatch.md#L203) |
| `C000:37A7` | (address-only) | 1 | call from `C000:5294` [int21-dispatch.md:207](int21-dispatch.md#L207) |
| `C000:3886` | (address-only) | 1 | jmp from `C000:391F` [int21-directory-core.md:48](int21-directory-core.md#L48) |
| `C000:3982` | (address-only) | 1 | call from `C000:296E` [int21-filesystem-front.md:65](int21-filesystem-front.md#L65) |
| `C000:39CE` | (address-only) | 1 | call from `C000:297F` [int21-filesystem-front.md:67](int21-filesystem-front.md#L67) |
| `C000:3B54` | (address-only) | 1 | jnz from `C000:3B4C` [int21-format.md:104](int21-format.md#L104) |
| `C000:3C90` | `local_sector_geometry_C000_3C90` | 1 | call from `C000:2CB8` [int21-format.md:81](int21-format.md#L81) |
| `C000:3DB3` | `resolve_open_file_C000_3DB3` | 1 | call from `C000:30F5` [int21-endpoints.md:96](int21-endpoints.md#L96) |
| `C000:3F7B` | (address-only) | 1 | loop from `C000:3F7B` [dreamlink-file-core.md:23](dreamlink-file-core.md#L23) |
| `C000:3FF3` | (address-only) | 1 | call from `C000:3169` [int21-endpoints.md:136](int21-endpoints.md#L136) |
| `C000:47D3` | (address-only) | 1 | call from `C000:0097` [boot.md:136](boot.md#L136) |
| `C000:4811` | (address-only) | 1 | call from `C000:00FA` [boot.md:187](boot.md#L187) |
| `C000:48D5` | `validate_rs232_setup_C000_48D5` | 1 | call from `C000:0CBD` [serial-services.md:37](serial-services.md#L37) |
| `C000:4977` | `keyboard_status_C000_4977` | 1 | call from `C000:515C` [int21-dispatch.md:174](int21-dispatch.md#L174) |
| `C000:49F8` | `idle_until_event_C000_49F8` | 1 | call from `C000:5121` [int21-dispatch.md:145](int21-dispatch.md#L145) |
| `C000:4A8D` | `keyboard_read_C000_4A8D` | 1 | call from `C000:5155` [int21-dispatch.md:169](int21-dispatch.md#L169) |
| `C000:4B8D` | `serial_rx_dequeue_C000_4B8D` | 1 | call from `C000:5117` [int21-dispatch.md:142](int21-dispatch.md#L142) |
| `C000:4BED` | `serial_rx_enqueue_C000_4BED` | 1 | call from `C000:057F` [device-irq.md:51](device-irq.md#L51) |
| `C000:50E7` | (address-only) | 1 | jmp from `C000:5115` [int21-dispatch.md:95](int21-dispatch.md#L95) |
| `C000:512A` | (address-only) | 1 | jmp from `C000:5144` [int21-dispatch.md:158](int21-dispatch.md#L158) |
| `C000:5142` | (address-only) | 1 | jz from `C000:511F` [int21-dispatch.md:144](int21-dispatch.md#L144) |
| `C000:517C` | (address-only) | 2 | call from `C000:516F` [int21-dispatch.md:229](int21-dispatch.md#L229)<br>call from `C000:2B5E` [int21-filesystem-front.md:160](int21-filesystem-front.md#L160) |
| `C000:51CE` | (address-only) | 1 | call from `C000:51C7` [int21-dispatch.md:244](int21-dispatch.md#L244) |
| `C000:5213` | (address-only) | 2 | call from `C000:5209` [int21-dispatch.md:253](int21-dispatch.md#L253)<br>call from `C000:2B46` [int21-filesystem-front.md:154](int21-filesystem-front.md#L154) |
| `C000:5244` | (address-only) | 1 | call from `C000:523D` [int21-dispatch.md:262](int21-dispatch.md#L262) |
| `C000:5308` | (address-only) | 1 | call from `C000:51C1` [int21-dispatch.md:240](int21-dispatch.md#L240) |
| `C000:5948` | (address-only) | 1 | call from `C000:52DC` [int21-dispatch.md:310](int21-dispatch.md#L310) |
| `C000:5A2F` | (address-only) | 1 | call from `C000:52D8` [int21-dispatch.md:308](int21-dispatch.md#L308) |
| `C000:5AD6` | `display_resource_C000_5AD6` | 2 | call from `C000:1280` [diagnostic-monitor.md:75](diagnostic-monitor.md#L75)<br>call from `C000:16FC` [diagnostic-monitor.md:395](diagnostic-monitor.md#L395) |
| `C000:67AD` | `display_stream_far_C000_67AD` | 13 | call from `DC98:0E7A` [diagnostic-keyboard-check.md:138](diagnostic-keyboard-check.md#L138)<br>call from `DC98:0E7A` [display-wrappers.md:23](display-wrappers.md#L23)<br>call from `DC98:0EDB` [display-wrappers.md:75](display-wrappers.md#L75)<br>call from `DC98:106B` [display-wrappers.md:124](display-wrappers.md#L124)<br>call from `DC98:118C` [horizontal-icon-renderer.md:57](horizontal-icon-renderer.md#L57)<br>call from `DC98:126B` [horizontal-icon-renderer.md:167](horizontal-icon-renderer.md#L167) |
| `C688:000B` | (address-only) | 1 | jmp from `C000:011A` [boot.md:197](boot.md#L197) |
| `C688:000F` | (address-only) | 1 | jmp from `C000:015C` [boot.md:227](boot.md#L227) |
| `C688:0053` | (address-only) | 1 | call from `C000:0090` [boot.md:134](boot.md#L134) |
| `C688:005C` | (address-only) | 1 | loop from `C688:0065` [menu-entry.md:41](menu-entry.md#L41) |
| `C688:0073` | (address-only) | 2 | jnz from `C688:0061` [menu-entry.md:38](menu-entry.md#L38)<br>loop from `C688:007A` [menu-entry.md:54](menu-entry.md#L54) |
| `C688:007C` | (address-only) | 1 | jnz from `C688:006F` [menu-entry.md:45](menu-entry.md#L45) |
| `C688:01B0` | `forced_diagnostic_wrapper_C688_01B0` | 1 | call from `C688:ED1A` [early-app-helper.md:19](early-app-helper.md#L19) |
| `C688:01E6` | (address-only) | 1 | call from `DC98:2C1B` [wp-others-handlers.md:202](wp-others-handlers.md#L202) |
| `C688:020C` | (address-only) | 3 | call from `DC98:2C2E` [wp-others-handlers.md:209](wp-others-handlers.md#L209)<br>call from `DC98:2CF4` [wp-others-handlers.md:264](wp-others-handlers.md#L264)<br>call from `DC98:2D1C` [wp-others-handlers.md:293](wp-others-handlers.md#L293) |
| `C688:022B` | (address-only) | 1 | call from `DC98:2D15` [wp-others-handlers.md:291](wp-others-handlers.md#L291) |
| `C688:0240` | (address-only) | 3 | call from `C688:8E39` [document-picker-ui.md:297](document-picker-ui.md#L297)<br>call from `C688:8E4F` [document-picker-ui.md:304](document-picker-ui.md#L304)<br>call from `C688:2A12` [menu-entry.md:92](menu-entry.md#L92) |
| `C688:0B11` | (address-only) | 1 | call from `C688:ED07` [app-menu-event-loop.md:186](app-menu-event-loop.md#L186) |
| `C688:0D05` | (address-only) | 1 | call from `C688:77A6` [wp-edit-text.md:122](wp-edit-text.md#L122) |
| `C688:12D6` | (address-only) | 3 | call from `C688:ECB0` [app-menu-event-loop.md:77](app-menu-event-loop.md#L77)<br>call from `C688:ECB0` [menu-entry.md:370](menu-entry.md#L370)<br>call from `C688:ECB0` [wp-edit-text.md:63](wp-edit-text.md#L63) |
| `C688:18AC` | `root_editor_span_emitter_C688_18AC` | 3 | call from `C688:452F` [wp-editor-viewport.md:81](wp-editor-viewport.md#L81)<br>call from `C688:453F` [wp-editor-viewport.md:88](wp-editor-viewport.md#L88)<br>call from `C688:4594` [wp-editor-viewport.md:118](wp-editor-viewport.md#L118) |
| `C688:18B4` | (address-only) | 1 | jnz from `C688:18AF` [wp-editor-redraw.md:24](wp-editor-redraw.md#L24) |
| `C688:18C3` | `span_emitter_long_path_C688_18C3` | 1 | jnz from `C688:18BE` [wp-editor-redraw.md:30](wp-editor-redraw.md#L30) |
| `C688:18EE` | `signed_delta_seed_C688_18EE` | 1 | call from `C688:18E8` [wp-editor-redraw.md:50](wp-editor-redraw.md#L50) |
| `C688:190B` | (address-only) | 1 | jz from `C688:1905` [wp-editor-redraw.md:66](wp-editor-redraw.md#L66) |
| `C688:1910` | `plain_delta_seed_C688_1910` | 1 | jz from `C688:18E6` [wp-editor-redraw.md:49](wp-editor-redraw.md#L49) |
| `C688:194F` | `redraw_state_primer_C688_194F` | 1 | call from `C688:18B5` [wp-editor-redraw.md:27](wp-editor-redraw.md#L27) |
| `C688:1974` | (address-only) | 1 | jz from `C688:196F` [wp-editor-redraw.md:100](wp-editor-redraw.md#L100) |
| `C688:198E` | (address-only) | 1 | jnz from `C688:19C1` [wp-editor-redraw.md:142](wp-editor-redraw.md#L142) |
| `C688:19A4` | (address-only) | 1 | jmp from `C688:18C0` [wp-editor-redraw.md:31](wp-editor-redraw.md#L31) |
| `C688:19B2` | `restore_redraw_state_C688_19B2` | 1 | jmp from `C688:18B1` [wp-editor-redraw.md:25](wp-editor-redraw.md#L25) |
| `C688:19CF` | (address-only) | 1 | jnz from `C688:19CA` [wp-editor-redraw.md:145](wp-editor-redraw.md#L145) |
| `C688:1A03` | (address-only) | 1 | jz from `C688:19FE` [wp-editor-redraw.md:160](wp-editor-redraw.md#L160) |
| `C688:1A0A` | (address-only) | 1 | call from `C688:18EE` [wp-editor-redraw.md:60](wp-editor-redraw.md#L60) |
| `C688:1A51` | `append_redraw_position_record_C688_1A51` | 1 | call from `C688:461F` [wp-editor-viewport.md:171](wp-editor-viewport.md#L171) |
| `C688:1A7B` | `finish_redraw_kick_C688_1A7B` | 1 | jmp from `C688:4778` [wp-editor-viewport.md:258](wp-editor-viewport.md#L258) |
| `C688:1A85` | (address-only) | 2 | call from `C688:4556` [wp-editor-viewport.md:91](wp-editor-viewport.md#L91)<br>call from `C688:4775` [wp-editor-viewport.md:257](wp-editor-viewport.md#L257) |
| `C688:1B12` | (address-only) | 1 | call from `C688:4626` [wp-editor-viewport.md:173](wp-editor-viewport.md#L173) |
| `C688:1B41` | (address-only) | 1 | call from `C688:4503` [wp-editor-viewport.md:51](wp-editor-viewport.md#L51) |
| `C688:1B6F` | (address-only) | 1 | call from `C688:4704` [wp-editor-viewport.md:224](wp-editor-viewport.md#L224) |
| `C688:1D75` | (address-only) | 1 | call from `C688:470F` [wp-editor-viewport.md:227](wp-editor-viewport.md#L227) |
| `C688:1DFD` | (address-only) | 2 | jmp from `C688:1929` [wp-editor-redraw.md:81](wp-editor-redraw.md#L81)<br>jmp from `C688:1A07` [wp-editor-redraw.md:163](wp-editor-redraw.md#L163) |
| `C688:1FD3` | (address-only) | 1 | jmp from `C688:1A00` [wp-editor-redraw.md:161](wp-editor-redraw.md#L161) |
| `C688:208D` | (address-only) | 1 | jmp from `C688:18EB` [wp-editor-redraw.md:51](wp-editor-redraw.md#L51) |
| `C688:294B` | (address-only) | 1 | call from `C688:2A01` [menu-entry.md:87](menu-entry.md#L87) |
| `C688:29D9` | (address-only) | 1 | call from `C688:000B` [menu-entry.md:20](menu-entry.md#L20) |
| `C688:2A90` | (address-only) | 1 | call from `C688:8DF8` [document-picker-ui.md:260](document-picker-ui.md#L260) |
| `C688:2CFA` | (address-only) | 1 | call from `C688:8DFB` [document-picker-ui.md:261](document-picker-ui.md#L261) |
| `C688:2D26` | (address-only) | 1 | call from `C688:8312` [menu-entry.md:280](menu-entry.md#L280) |
| `C688:2D75` | (address-only) | 1 | call from `C688:2A04` [menu-entry.md:88](menu-entry.md#L88) |
| `C688:39B5` | (address-only) | 1 | call from `C688:1A81` [wp-editor-redraw.md:194](wp-editor-redraw.md#L194) |
| `C688:39BE` | (address-only) | 1 | call from `C688:19CC` [wp-editor-redraw.md:146](wp-editor-redraw.md#L146) |
| `C688:441A` | (address-only) | 1 | call from `C688:2A5D` [menu-entry.md:118](menu-entry.md#L118) |
| `C688:4473` | (address-only) | 1 | call from `C688:77A3` [wp-edit-text.md:121](wp-edit-text.md#L121) |
| `C688:44C4` | `snapshot_active_editor_state_C688_44C4` | 13 | call from `C688:ECB6` [app-menu-event-loop.md:79](app-menu-event-loop.md#L79)<br>call from `C688:ED0A` [app-menu-event-loop.md:187](app-menu-event-loop.md#L187)<br>call from `C688:EE20` [app-menu-event-loop.md:259](app-menu-event-loop.md#L259)<br>call from `C688:8D80` [document-picker-ui.md:114](document-picker-ui.md#L114)<br>call from `C688:8DE9` [document-picker-ui.md:244](document-picker-ui.md#L244)<br>call from `C688:8DFE` [document-picker-ui.md:262](document-picker-ui.md#L262) |
| `C688:44F4` | `shared_editor_viewport_body_C688_44F4` | 1 | jmp from `C688:44E0` [wp-editor-viewport.md:25](wp-editor-viewport.md#L25) |
| `C688:4503` | (address-only) | 1 | jz from `C688:44FE` [wp-editor-viewport.md:47](wp-editor-viewport.md#L47) |
| `C688:452F` | (address-only) | 1 | jnz from `C688:4527` [wp-editor-viewport.md:77](wp-editor-viewport.md#L77) |
| `C688:4534` | (address-only) | 3 | jz from `C688:451D` [wp-editor-viewport.md:72](wp-editor-viewport.md#L72)<br>js from `C688:451F` [wp-editor-viewport.md:73](wp-editor-viewport.md#L73)<br>jz from `C688:452D` [wp-editor-viewport.md:80](wp-editor-viewport.md#L80) |
| `C688:4559` | `viewport_state_seed_C688_4559` | 1 | jmp from `C688:4532` [wp-editor-viewport.md:82](wp-editor-viewport.md#L82) |
| `C688:45B8` | (address-only) | 1 | jc from `C688:45A8` [wp-editor-viewport.md:136](wp-editor-viewport.md#L136) |
| `C688:45DB` | (address-only) | 1 | jns from `C688:45B6` [wp-editor-viewport.md:141](wp-editor-viewport.md#L141) |
| `C688:45E9` | (address-only) | 1 | jz from `C688:45E4` [wp-editor-viewport.md:149](wp-editor-viewport.md#L149) |
| `C688:4602` | `negative_delta_emit_seed_C688_4602` | 1 | jz from `C688:459C` [wp-editor-viewport.md:132](wp-editor-viewport.md#L132) |
| `C688:4626` | (address-only) | 2 | jz from `C688:460A` [wp-editor-viewport.md:163](wp-editor-viewport.md#L163)<br>jz from `C688:4617` [wp-editor-viewport.md:168](wp-editor-viewport.md#L168) |
| `C688:469E` | (address-only) | 1 | jmp from `C688:466C` [wp-editor-viewport.md:192](wp-editor-viewport.md#L192) |
| `C688:46CD` | (address-only) | 1 | jz from `C688:46C0` [wp-editor-viewport.md:205](wp-editor-viewport.md#L205) |
| `C688:46EC` | (address-only) | 1 | jmp from `C688:4747` [wp-editor-viewport.md:249](wp-editor-viewport.md#L249) |
| `C688:4707` | (address-only) | 1 | jnz from `C688:4702` [wp-editor-viewport.md:223](wp-editor-viewport.md#L223) |
| `C688:473F` | (address-only) | 1 | jnz from `C688:46C6` [wp-editor-viewport.md:208](wp-editor-viewport.md#L208) |
| `C688:4749` | (address-only) | 1 | jz from `C688:46F2` [wp-editor-viewport.md:216](wp-editor-viewport.md#L216) |
| `C688:4778` | (address-only) | 1 | jz from `C688:4773` [wp-editor-viewport.md:256](wp-editor-viewport.md#L256) |
| `C688:4848` | (address-only) | 1 | call from `C688:8315` [menu-entry.md:281](menu-entry.md#L281) |
| `C688:50FC` | (address-only) | 1 | call from `C688:8DDD` [document-picker-ui.md:237](document-picker-ui.md#L237) |
| `C688:5102` | (address-only) | 1 | call from `C688:8EB7` [document-picker-ui.md:328](document-picker-ui.md#L328) |
| `C688:5108` | (address-only) | 2 | call from `C688:8D7D` [document-picker-ui.md:113](document-picker-ui.md#L113)<br>call from `C688:8DE5` [document-picker-ui.md:242](document-picker-ui.md#L242) |
| `C688:599C` | (address-only) | 2 | call from `C688:7771` [menu-entry.md:163](menu-entry.md#L163)<br>call from `C688:7771` [wp-edit-text.md:93](wp-edit-text.md#L93) |
| `C688:5B7D` | (address-only) | 1 | call from `C688:83FA` [menu-entry.md:341](menu-entry.md#L341) |
| `C688:5B90` | (address-only) | 1 | call from `C688:EDEB` [app-menu-event-loop.md:257](app-menu-event-loop.md#L257) |
| `C688:61DB` | (address-only) | 2 | call from `C688:2A0F` [menu-entry.md:91](menu-entry.md#L91)<br>call from `C688:1A55` [wp-editor-redraw.md:176](wp-editor-redraw.md#L176) |
| `C688:622B` | (address-only) | 1 | call from `C688:ED04` [app-menu-event-loop.md:185](app-menu-event-loop.md#L185) |
| `C688:6B8C` | (address-only) | 2 | call from `C688:77D9` [menu-entry.md:236](menu-entry.md#L236)<br>call from `C688:46E7` [wp-editor-viewport.md:212](wp-editor-viewport.md#L212) |
| `C688:71C6` | (address-only) | 2 | call from `C688:8D41` [document-picker-ui.md:154](document-picker-ui.md#L154)<br>call from `C688:8D9D` [document-picker-ui.md:199](document-picker-ui.md#L199) |
| `C688:7689` | (address-only) | 6 | call from `C688:8D18` [document-picker-ui.md:129](document-picker-ui.md#L129)<br>call from `C688:8D1E` [document-picker-ui.md:131](document-picker-ui.md#L131)<br>call from `C688:8D2C` [document-picker-ui.md:138](document-picker-ui.md#L138)<br>call from `C688:8D32` [document-picker-ui.md:140](document-picker-ui.md#L140)<br>call from `C688:8D91` [document-picker-ui.md:194](document-picker-ui.md#L194)<br>call from `C688:83EF` [menu-entry.md:337](menu-entry.md#L337) |
| `C688:76BF` | (address-only) | 1 | call from `C688:772F` [menu-entry.md:131](menu-entry.md#L131) |
| `C688:7729` | (address-only) | 1 | jmp from `C688:2A60` [menu-entry.md:119](menu-entry.md#L119) |
| `C688:7752` | (address-only) | 1 | call from `C688:000F` [menu-entry.md:24](menu-entry.md#L24) |
| `C688:775C` | (address-only) | 1 | jz from `C688:7757` [menu-entry.md:148](menu-entry.md#L148) |
| `C688:7766` | `editor_boot_update_sequence_C688_7766` | 2 | call from `C688:7729` [menu-entry.md:129](menu-entry.md#L129)<br>call from `C688:EC8C` [wp-clear-text.md:54](wp-clear-text.md#L54) |
| `C688:7795` | (address-only) | 3 | call from `C688:ECA7` [app-menu-event-loop.md:74](app-menu-event-loop.md#L74)<br>call from `C688:ECA7` [menu-entry.md:367](menu-entry.md#L367)<br>call from `C688:ECA7` [wp-edit-text.md:60](wp-edit-text.md#L60) |
| `C688:77A3` | `editor_update_id_helper_C688_77A3` | 17 | call from `C688:ED0F` [app-menu-event-loop.md:189](app-menu-event-loop.md#L189)<br>call from `C688:7779` [menu-entry.md:166](menu-entry.md#L166)<br>call from `C688:777E` [menu-entry.md:168](menu-entry.md#L168)<br>call from `C688:7783` [menu-entry.md:170](menu-entry.md#L170)<br>call from `C688:7788` [menu-entry.md:172](menu-entry.md#L172)<br>call from `C688:778D` [menu-entry.md:174](menu-entry.md#L174) |
| `C688:77AA` | (address-only) | 3 | call from `C688:EB15` [app-menu-event-loop.md:121](app-menu-event-loop.md#L121)<br>call from `C688:774F` [menu-entry.md:143](menu-entry.md#L143)<br>call from `C688:EB15` [wp-edit-text.md:35](wp-edit-text.md#L35) |
| `C688:77B4` | (address-only) | 1 | call from `C688:7752` [menu-entry.md:146](menu-entry.md#L146) |
| `C688:77C1` | (address-only) | 1 | call from `C688:77BA` [menu-entry.md:220](menu-entry.md#L220) |
| `C688:77DD` | (address-only) | 4 | call from `C688:EC9F` [app-menu-event-loop.md:69](app-menu-event-loop.md#L69)<br>call from `C688:EE29` [app-menu-event-loop.md:262](app-menu-event-loop.md#L262)<br>call from `C688:EC9F` [menu-entry.md:364](menu-entry.md#L364)<br>call from `C688:EC9F` [wp-edit-text.md:57](wp-edit-text.md#L57) |
| `C688:8312` | (address-only) | 1 | call from `C688:77BD` [menu-entry.md:221](menu-entry.md#L221) |
| `C688:834F` | (address-only) | 2 | jmp from `C688:8335` [document-picker-ui.md:54](document-picker-ui.md#L54)<br>jmp from `C688:8335` [menu-entry.md:293](menu-entry.md#L293) |
| `C688:8399` | (address-only) | 2 | jz from `C688:8390` [menu-entry.md:314](menu-entry.md#L314)<br>jz from `C688:8394` [menu-entry.md:316](menu-entry.md#L316) |
| `C688:83AB` | (address-only) | 1 | jmp from `C688:83EA` [menu-entry.md:334](menu-entry.md#L334) |
| `C688:83D8` | (address-only) | 1 | jz from `C688:8388` [menu-entry.md:310](menu-entry.md#L310) |
| `C688:83DD` | (address-only) | 1 | jz from `C688:838C` [menu-entry.md:312](menu-entry.md#L312) |
| `C688:83EC` | (address-only) | 1 | jz from `C688:83E2` [menu-entry.md:332](menu-entry.md#L332) |
| `C688:8402` | (address-only) | 1 | jz from `C688:83F8` [menu-entry.md:340](menu-entry.md#L340) |
| `C688:8413` | (address-only) | 1 | jmp from `C688:8400` [menu-entry.md:343](menu-entry.md#L343) |
| `C688:8419` | (address-only) | 1 | jmp from `C688:83DB` [menu-entry.md:328](menu-entry.md#L328) |
| `C688:85B4` | (address-only) | 2 | call from `C688:832C` [document-picker-ui.md:51](document-picker-ui.md#L51)<br>call from `C688:832C` [menu-entry.md:290](menu-entry.md#L290) |
| `C688:8610` | (address-only) | 2 | call from `C688:EDE8` [app-menu-event-loop.md:256](app-menu-event-loop.md#L256)<br>call from `C688:83F2` [menu-entry.md:338](menu-entry.md#L338) |
| `C688:8617` | (address-only) | 2 | call from `C688:832F` [document-picker-ui.md:52](document-picker-ui.md#L52)<br>call from `C688:832F` [menu-entry.md:291](menu-entry.md#L291) |
| `C688:86C9` | (address-only) | 1 | call from `C688:83FD` [menu-entry.md:342](menu-entry.md#L342) |
| `C688:88FC` | (address-only) | 1 | call from `C688:8416` [menu-entry.md:352](menu-entry.md#L352) |
| `C688:8926` | (address-only) | 2 | call from `C688:8319` [document-picker-ui.md:45](document-picker-ui.md#L45)<br>call from `C688:8319` [menu-entry.md:284](menu-entry.md#L284) |
| `C688:898A` | (address-only) | 1 | call from `C688:83D8` [menu-entry.md:327](menu-entry.md#L327) |
| `C688:89F6` | (address-only) | 1 | call from `C688:83F5` [menu-entry.md:339](menu-entry.md#L339) |
| `C688:8D09` | (address-only) | 1 | jnz from `C688:8D04` [document-picker-ui.md:96](document-picker-ui.md#L96) |
| `C688:8D0C` | (address-only) | 1 | jz from `C688:8D00` [document-picker-ui.md:94](document-picker-ui.md#L94) |
| `C688:8D35` | `prompt_common_input_C688_8D35` | 1 | jmp from `C688:8D21` [document-picker-ui.md:132](document-picker-ui.md#L132) |
| `C688:8D60` | (address-only) | 1 | jnc from `C688:8D59` [document-picker-ui.md:162](document-picker-ui.md#L162) |
| `C688:8D72` | `document_list_refresh_C688_8D72` | 1 | jz from `C688:8D8C` [document-picker-ui.md:192](document-picker-ui.md#L192) |
| `C688:8D7A` | `document_list_refresh_C688_8D7A` | 1 | jmp from `C688:8D06` [document-picker-ui.md:97](document-picker-ui.md#L97) |
| `C688:8D83` | (address-only) | 1 | jnz from `C688:8DEF` [document-picker-ui.md:247](document-picker-ui.md#L247) |
| `C688:8DBF` | `replace_commit_selected_C688_8DBF` | 1 | jmp from `C688:8D09` [document-picker-ui.md:98](document-picker-ui.md#L98) |
| `C688:8DC7` | `replace_commit_common_C688_8DC7` | 1 | jmp from `C688:8DC2` [document-picker-ui.md:224](document-picker-ui.md#L224) |
| `C688:8DDD` | (address-only) | 1 | jmp from `C688:8ED7` [document-picker-ui.md:349](document-picker-ui.md#L349) |
| `C688:8DE2` | `replace_reselect_C688_8DE2` | 1 | jmp from `C688:8E13` [document-picker-ui.md:270](document-picker-ui.md#L270) |
| `C688:8DE8` | (address-only) | 1 | jmp from `C688:8DE0` [document-picker-ui.md:238](document-picker-ui.md#L238) |
| `C688:8E15` | (address-only) | 1 | jnz from `C688:8E11` [document-picker-ui.md:269](document-picker-ui.md#L269) |
| `C688:8E1C` | `replace_final_stage_C688_8E1C` | 2 | jz from `C688:8DF6` [document-picker-ui.md:259](document-picker-ui.md#L259)<br>jz from `C688:8E17` [document-picker-ui.md:272](document-picker-ui.md#L272) |
| `C688:8EB7` | (address-only) | 1 | jnc from `C688:8E5A` [document-picker-ui.md:315](document-picker-ui.md#L315) |
| `C688:8EDA` | `work_memory_full_exit_C688_8EDA` | 1 | jz from `C688:8EBF` [document-picker-ui.md:338](document-picker-ui.md#L338) |
| `C688:8EE9` | `scan_space_or_letter_C688_8EE9` | 4 | call from `C688:8E61` [document-picker-ui.md:318](document-picker-ui.md#L318)<br>jc from `C688:8EF9` [document-picker-ui.md:376](document-picker-ui.md#L376)<br>jc from `C688:8F01` [document-picker-ui.md:380](document-picker-ui.md#L380)<br>jnc from `C688:8F05` [document-picker-ui.md:382](document-picker-ui.md#L382) |
| `C688:8EF3` | (address-only) | 1 | jnz from `C688:8EF0` [document-picker-ui.md:371](document-picker-ui.md#L371) |
| `C688:8F08` | (address-only) | 2 | jz from `C688:8EF5` [document-picker-ui.md:374](document-picker-ui.md#L374)<br>jc from `C688:8EFD` [document-picker-ui.md:378](document-picker-ui.md#L378) |
| `C688:8F0D` | `build_search_mask_C688_8F0D` | 1 | call from `C688:8E47` [document-picker-ui.md:301](document-picker-ui.md#L301) |
| `C688:8F15` | (address-only) | 1 | jnz from `C688:8F3D` [document-picker-ui.md:422](document-picker-ui.md#L422) |
| `C688:8F23` | (address-only) | 1 | jnz from `C688:8F20` [document-picker-ui.md:404](document-picker-ui.md#L404) |
| `C688:8F2F` | (address-only) | 1 | jz from `C688:8F2C` [document-picker-ui.md:413](document-picker-ui.md#L413) |
| `C688:8F3B` | (address-only) | 1 | jz from `C688:8F33` [document-picker-ui.md:417](document-picker-ui.md#L417) |
| `C688:8F40` | `snapshot_display_state_C688_8F40` | 7 | call from `C688:ECAD` [app-menu-event-loop.md:76](app-menu-event-loop.md#L76)<br>call from `C688:8D7A` [document-picker-ui.md:112](document-picker-ui.md#L112)<br>call from `C688:8DDA` [document-picker-ui.md:236](document-picker-ui.md#L236)<br>call from `C688:8DE2` [document-picker-ui.md:241](document-picker-ui.md#L241)<br>call from `C688:8E23` [document-picker-ui.md:287](document-picker-ui.md#L287)<br>call from `C688:ECAD` [menu-entry.md:369](menu-entry.md#L369) |
| `C688:8F43` | (address-only) | 2 | call from `C688:7768` [menu-entry.md:160](menu-entry.md#L160)<br>call from `C688:7768` [wp-edit-text.md:90](wp-edit-text.md#L90) |
| `C688:90EC` | (address-only) | 2 | call from `C688:8332` [document-picker-ui.md:53](document-picker-ui.md#L53)<br>call from `C688:8332` [menu-entry.md:292](menu-entry.md#L292) |
| `C688:928D` | (address-only) | 1 | jmp from `C688:8399` [menu-entry.md:318](menu-entry.md#L318) |
| `C688:92A0` | (address-only) | 1 | jmp from `C688:8396` [menu-entry.md:317](menu-entry.md#L317) |
| `C688:92DF` | `inline_key_dispatch_C688_92DF` | 5 | call from `C688:ECC3` [app-menu-event-loop.md:84](app-menu-event-loop.md#L84)<br>call from `C688:8D60` [document-picker-ui.md:164](document-picker-ui.md#L164)<br>call from `C688:8DB0` [document-picker-ui.md:206](document-picker-ui.md#L206)<br>call from `C688:ECC3` [menu-entry.md:377](menu-entry.md#L377)<br>call from `C688:ECC3` [wp-edit-text.md:70](wp-edit-text.md#L70) |
| `C688:92E2` | `inline_key_dispatch_body_C688_92E2` | 1 | call from `C688:ED87` [app-menu-event-loop.md:220](app-menu-event-loop.md#L220) |
| `C688:92EA` | (address-only) | 1 | jmp from `C688:92FC` [app-menu-event-loop.md:51](app-menu-event-loop.md#L51) |
| `C688:92FE` | (address-only) | 2 | jz from `C688:92F4` [app-menu-event-loop.md:46](app-menu-event-loop.md#L46)<br>jz from `C688:92F8` [app-menu-event-loop.md:48](app-menu-event-loop.md#L48) |
| `C688:9301` | (address-only) | 1 | jz from `C688:92F0` [app-menu-event-loop.md:44](app-menu-event-loop.md#L44) |
| `C688:9347` | (address-only) | 1 | call from `C688:8E06` [document-picker-ui.md:265](document-picker-ui.md#L265) |
| `C688:93B5` | (address-only) | 1 | call from `C688:8E09` [document-picker-ui.md:266](document-picker-ui.md#L266) |
| `C688:93CE` | `trim_trailing_spaces_C688_93CE` | 2 | call from `C688:8D49` [document-picker-ui.md:157](document-picker-ui.md#L157)<br>call from `C688:8DA5` [document-picker-ui.md:202](document-picker-ui.md#L202) |
| `C688:93DE` | (address-only) | 1 | jnz from `C688:93F1` [document-picker-ui.md:461](document-picker-ui.md#L461) |
| `C688:93EB` | (address-only) | 1 | jz from `C688:93E3` [document-picker-ui.md:454](document-picker-ui.md#L454) |
| `C688:944E` | (address-only) | 1 | jnz from `C688:93E9` [document-picker-ui.md:457](document-picker-ui.md#L457) |
| `C688:9541` | (address-only) | 3 | call from `C688:2A57` [menu-entry.md:116](menu-entry.md#L116)<br>call from `C688:776E` [menu-entry.md:162](menu-entry.md#L162)<br>call from `C688:776E` [wp-edit-text.md:92](wp-edit-text.md#L92) |
| `C688:96E1` | (address-only) | 2 | call from `C688:779F` [menu-entry.md:181](menu-entry.md#L181)<br>call from `C688:779F` [wp-edit-text.md:111](wp-edit-text.md#L111) |
| `C688:96EA` | (address-only) | 3 | call from `C688:EDC1` [app-menu-event-loop.md:253](app-menu-event-loop.md#L253)<br>call from `C688:8EE3` [document-picker-ui.md:355](document-picker-ui.md#L355)<br>call from `C688:EC94` [wp-clear-text.md:57](wp-clear-text.md#L57) |
| `C688:97E7` | (address-only) | 1 | call from `C688:8F26` [document-picker-ui.md:409](document-picker-ui.md#L409) |
| `C688:9DFB` | (address-only) | 1 | call from `C688:2A5A` [menu-entry.md:117](menu-entry.md#L117) |
| `C688:EB15` | `wp_top_menu_default_C688_EB15`, `wp_top_menu_default_return_C688_EB15` | 4 | jmp from `C688:EF4C` [app-menu-event-loop.md:142](app-menu-event-loop.md#L142)<br>jmp from `C688:ED12` [app-menu-event-loop.md:190](app-menu-event-loop.md#L190)<br>jmp from `C688:7759` [menu-entry.md:149](menu-entry.md#L149)<br>jmp from `C688:7763` [menu-entry.md:153](menu-entry.md#L153) |
| `C688:EB2B` | (address-only) | 2 | jz from `C688:EB26` [app-menu-event-loop.md:128](app-menu-event-loop.md#L128)<br>jz from `C688:EB26` [wp-edit-text.md:42](wp-edit-text.md#L42) |
| `C688:EB2E` | (address-only) | 1 | call from `DC98:276D` [wp-submenus.md:32](wp-submenus.md#L32) |
| `C688:EB46` | `wp_clear_text_wrapper_C688_EB46` | 1 | call from `DC98:2848` [top-icon-menus.md:52](top-icon-menus.md#L52) |
| `C688:EB5E` | (address-only) | 1 | call from `DC98:2670` [wp-submenus.md:105](wp-submenus.md#L105) |
| `C688:EB91` | (address-only) | 1 | call from `DC98:27E4` [wp-submenus.md:42](wp-submenus.md#L42) |
| `C688:EBA9` | (address-only) | 1 | call from `DC98:27A3` [wp-submenus.md:36](wp-submenus.md#L36) |
| `C688:EBC1` | (address-only) | 1 | call from `DC98:27B9` [wp-submenus.md:38](wp-submenus.md#L38) |
| `C688:EBD9` | (address-only) | 1 | call from `DC98:278D` [wp-submenus.md:34](wp-submenus.md#L34) |
| `C688:EBF1` | (address-only) | 1 | call from `DC98:26F7` [wp-submenus.md:165](wp-submenus.md#L165) |
| `C688:EC09` | (address-only) | 1 | call from `DC98:270D` [wp-submenus.md:166](wp-submenus.md#L166) |
| `C688:EC24` | (address-only) | 1 | call from `DC98:26CB` [wp-submenus.md:163](wp-submenus.md#L163) |
| `C688:EC3F` | (address-only) | 1 | call from `DC98:26E1` [wp-submenus.md:164](wp-submenus.md#L164) |
| `C688:EC5A` | (address-only) | 1 | call from `DC98:2723` [wp-submenus.md:167](wp-submenus.md#L167) |
| `C688:EC77` | `wp_clear_text_worker_C688_EC77` | 2 | call from `C688:EB50` [wp-clear-text.md:25](wp-clear-text.md#L25)<br>jnz from `C688:EC8A` [wp-clear-text.md:53](wp-clear-text.md#L53) |
| `C688:EC9F` | `root_app_menu_event_loop_C688_EC9F`, `root_edit_text_shared_loop_C688_EC9F` | 10 | jmp from `C688:EB2B` [app-menu-event-loop.md:130](app-menu-event-loop.md#L130)<br>jmp from `C688:EF56` [app-menu-event-loop.md:154](app-menu-event-loop.md#L154)<br>jmp from `C688:EF68` [app-menu-event-loop.md:169](app-menu-event-loop.md#L169)<br>jmp from `C688:8D0C` [document-picker-ui.md:99](document-picker-ui.md#L99)<br>jmp from `C688:8D83` [document-picker-ui.md:115](document-picker-ui.md#L115)<br>jmp from `C688:8E19` [document-picker-ui.md:273](document-picker-ui.md#L273) |
| `C688:ECA7` | `loop_refresh_and_poll_C688_ECA7` | 2 | jmp from `C688:ED02` [app-menu-event-loop.md:184](app-menu-event-loop.md#L184)<br>jmp from `C688:EE2C` [app-menu-event-loop.md:263](app-menu-event-loop.md#L263) |
| `C688:ECC3` | (address-only) | 3 | jnz from `C688:ECBE` [app-menu-event-loop.md:82](app-menu-event-loop.md#L82)<br>jnz from `C688:ECBE` [menu-entry.md:375](menu-entry.md#L375)<br>jnz from `C688:ECBE` [wp-edit-text.md:68](wp-edit-text.md#L68) |
| `C688:ED04` | (address-only) | 1 | jz from `C688:ECFB` [app-menu-event-loop.md:182](app-menu-event-loop.md#L182) |
| `C688:ED84` | `no_event_dispatch_C688_ED84` | 3 | jmp from `C688:ECC0` [app-menu-event-loop.md:83](app-menu-event-loop.md#L83)<br>jmp from `C688:ECC0` [menu-entry.md:376](menu-entry.md#L376)<br>jmp from `C688:ECC0` [wp-edit-text.md:69](wp-edit-text.md#L69) |
| `C688:EDB9` | (address-only) | 1 | jmp from `C688:EDC4` [app-menu-event-loop.md:254](app-menu-event-loop.md#L254) |
| `C688:EDC1` | (address-only) | 1 | jmp from `C688:EE32` [app-menu-event-loop.md:265](app-menu-event-loop.md#L265) |
| `C688:EDCB` | (address-only) | 1 | jc from `C688:EDA1` [app-menu-event-loop.md:250](app-menu-event-loop.md#L250) |
| `C688:EE84` | (address-only) | 2 | call from `C688:EE3A` [app-menu-event-loop.md:268](app-menu-event-loop.md#L268)<br>call from `C688:EC7A` [wp-clear-text.md:46](wp-clear-text.md#L46) |
| `C688:EE8C` | (address-only) | 1 | call from `C688:92DF` [app-menu-event-loop.md:34](app-menu-event-loop.md#L34) |
| `C688:EE98` | (address-only) | 2 | call from `C688:EE34` [app-menu-event-loop.md:266](app-menu-event-loop.md#L266)<br>call from `C688:8EDD` [document-picker-ui.md:353](document-picker-ui.md#L353) |
| `C688:EE9E` | (address-only) | 2 | call from `C688:8329` [document-picker-ui.md:50](document-picker-ui.md#L50)<br>call from `C688:8329` [menu-entry.md:289](menu-entry.md#L289) |
| `C688:EEFE` | (address-only) | 1 | call from `C688:ED9E` [app-menu-event-loop.md:249](app-menu-event-loop.md#L249) |
| `C688:EF45` | `organizer_then_wp_menu_C688_EF45` | 2 | jmp from `C688:EB28` [app-menu-event-loop.md:129](app-menu-event-loop.md#L129)<br>jmp from `C688:EB28` [wp-edit-text.md:43](wp-edit-text.md#L43) |
| `C688:EF67` | (address-only) | 1 | jz from `C688:EF62` [app-menu-event-loop.md:166](app-menu-event-loop.md#L166) |
| `C688:EF81` | (address-only) | 1 | call from `C688:EC87` [wp-clear-text.md:52](wp-clear-text.md#L52) |
| `C688:EF86` | `classify_prompt_field_C688_EF86` | 3 | call from `C688:8D56` [document-picker-ui.md:161](document-picker-ui.md#L161)<br>call from `C688:8DAD` [document-picker-ui.md:205](document-picker-ui.md#L205)<br>jnz from `C688:EFA3` [document-picker-ui.md:493](document-picker-ui.md#L493) |
| `C688:EF8D` | (address-only) | 1 | jnz from `C688:EF8A` [document-picker-ui.md:479](document-picker-ui.md#L479) |
| `C688:EF99` | (address-only) | 1 | jz from `C688:EF8F` [document-picker-ui.md:482](document-picker-ui.md#L482) |
| `C688:EFA0` | (address-only) | 2 | jc from `C688:EF93` [document-picker-ui.md:484](document-picker-ui.md#L484)<br>jnc from `C688:EF97` [document-picker-ui.md:486](document-picker-ui.md#L486) |
| `C688:F13A` | (address-only) | 3 | call from `C688:ECAA` [app-menu-event-loop.md:75](app-menu-event-loop.md#L75)<br>call from `C688:ECAA` [menu-entry.md:368](menu-entry.md#L368)<br>call from `C688:ECAA` [wp-edit-text.md:61](wp-edit-text.md#L61) |
| `C688:F140` | (address-only) | 2 | call from `C688:831C` [document-picker-ui.md:46](document-picker-ui.md#L46)<br>call from `C688:831C` [menu-entry.md:285](menu-entry.md#L285) |
| `DC98:000E` | (address-only) | 1 | call from `C000:1272` [diagnostic-monitor.md:71](diagnostic-monitor.md#L71) |
| `DC98:001C` | (address-only) | 4 | call from `C000:129A` [diagnostic-monitor.md:124](diagnostic-monitor.md#L124)<br>call from `C000:1335` [diagnostic-monitor.md:203](diagnostic-monitor.md#L203)<br>call from `C000:1511` [diagnostic-monitor.md:337](diagnostic-monitor.md#L337)<br>call from `C000:16EE` [diagnostic-monitor.md:391](diagnostic-monitor.md#L391) |
| `DC98:002A` | (address-only) | 2 | call from `C000:1289` [diagnostic-monitor.md:78](diagnostic-monitor.md#L78)<br>call from `C000:1708` [diagnostic-monitor.md:399](diagnostic-monitor.md#L399) |
| `DC98:0038` | (address-only) | 1 | call from `C000:1682` [diagnostic-monitor.md:417](diagnostic-monitor.md#L417) |
| `DC98:0137` | (address-only) | 1 | call from `DC98:0CB5` [diagnostic-keyboard-check.md:33](diagnostic-keyboard-check.md#L33) |
| `DC98:02AE` | (address-only) | 1 | call from `DC98:0CEA` [diagnostic-keyboard-check.md:55](diagnostic-keyboard-check.md#L55) |
| `DC98:055E` | (address-only) | 1 | call from `DC98:0CC2` [diagnostic-keyboard-check.md:39](diagnostic-keyboard-check.md#L39) |
| `DC98:099F` | (address-only) | 1 | call from `DC98:0CC5` [diagnostic-keyboard-check.md:40](diagnostic-keyboard-check.md#L40) |
| `DC98:0CA2` | `diagnostic_keyboard_check_DC98_0CA2` | 1 | call from `C000:16AC` [diagnostic-monitor.md:378](diagnostic-monitor.md#L378) |
| `DC98:0CF9` | (address-only) | 3 | call from `DC98:11B2` [horizontal-icon-renderer.md:100](horizontal-icon-renderer.md#L100)<br>call from `DC98:21E3` [low-ram-abi-unknowns.md:164](low-ram-abi-unknowns.md#L164)<br>call from `DC98:2C07` [wp-others-handlers.md:182](wp-others-handlers.md#L182) |
| `DC98:0D19` | (address-only) | 1 | call from `DC98:B970` [organizer-world-clock.md:164](organizer-world-clock.md#L164) |
| `DC98:0D2A` | (address-only) | 1 | call from `DC98:A06E` [organizer-world-clock.md:124](organizer-world-clock.md#L124) |
| `DC98:0D4E` | (address-only) | 1 | call from `DC98:A071` [organizer-world-clock.md:125](organizer-world-clock.md#L125) |
| `DC98:0E70` | `diagnostic_keyboard_setup_DC98_0E70`, `display_fixed_resource_DC98_0E70` | 11 | call from `DC98:0CAA` [diagnostic-keyboard-check.md:28](diagnostic-keyboard-check.md#L28)<br>call from `DC98:125D` [horizontal-icon-renderer.md:163](horizontal-icon-renderer.md#L163)<br>call from `DC98:CF1C` [organizer-address-book.md:22](organizer-address-book.md#L22)<br>call from `DC98:6A3A` [organizer-calculator.md:16](organizer-calculator.md#L16)<br>call from `DC98:9917` [organizer-scheduler.md:21](organizer-scheduler.md#L21)<br>call from `DC98:B686` [organizer-world-clock.md:17](organizer-world-clock.md#L17) |
| `DC98:0E81` | `display_text_DC98_0E81` | 5 | call from `DC98:145B` [horizontal-icon-renderer.md:238](horizontal-icon-renderer.md#L238)<br>call from `DC98:22BB` [setup-screens.md:70](setup-screens.md#L70)<br>call from `DC98:2BF1` [wp-others-handlers.md:176](wp-others-handlers.md#L176)<br>call from `DC98:2C02` [wp-others-handlers.md:181](wp-others-handlers.md#L181)<br>call from `DC98:2D05` [wp-others-handlers.md:269](wp-others-handlers.md#L269) |
| `DC98:0EE5` | `display_rects_DC98_0EE5` | 1 | call from `DC98:6A4F` [organizer-calculator.md:23](organizer-calculator.md#L23) |
| `DC98:10EC` | (address-only) | 1 | call from `DC98:1448` [horizontal-icon-renderer.md:234](horizontal-icon-renderer.md#L234) |
| `DC98:110E` | `selection_marker_DC98_110E` | 1 | call from `DC98:11A9` [horizontal-icon-renderer.md:98](horizontal-icon-renderer.md#L98) |
| `DC98:1198` | `horizontal_icon_key_loop_DC98_1198` | 1 | call from `DC98:1489` [horizontal-icon-renderer.md:255](horizontal-icon-renderer.md#L255) |
| `DC98:124C` | `horizontal_icon_renderer_DC98_124C` | 6 | call from `DC98:2816` [top-icon-menus.md:26](top-icon-menus.md#L26)<br>call from `DC98:53EE` [top-icon-menus.md:116](top-icon-menus.md#L116)<br>call from `DC98:2763` [wp-submenus.md:30](wp-submenus.md#L30)<br>call from `DC98:2666` [wp-submenus.md:103](wp-submenus.md#L103)<br>call from `DC98:26C1` [wp-submenus.md:161](wp-submenus.md#L161)<br>call from `DC98:2D34` [wp-submenus.md:232](wp-submenus.md#L232) |
| `DC98:1859` | `set_input_idle_callback_DC98_1859` | 1 | call from `DC98:2593` [setup-screens.md:144](setup-screens.md#L144) |
| `DC98:20AA` | (address-only) | 1 | call from `DC98:2199` [low-ram-abi-unknowns.md:162](low-ram-abi-unknowns.md#L162) |
| `DC98:22A1` | `rs232_setup_DC98_22A1` | 2 | call from `DC98:2699` [wp-submenus.md:109](wp-submenus.md#L109)<br>call from `DC98:2739` [wp-submenus.md:168](wp-submenus.md#L168) |
| `DC98:24DB` | `printer_setup_DC98_24DB` | 1 | call from `DC98:2685` [wp-submenus.md:107](wp-submenus.md#L107) |
| `DC98:265D` | `wp_printer_submenu_DC98_265D` | 1 | call from `DC98:2857` [top-icon-menus.md:54](top-icon-menus.md#L54) |
| `DC98:26B8` | `wp_communicate_submenu_DC98_26B8` | 1 | call from `DC98:2864` [top-icon-menus.md:56](top-icon-menus.md#L56) |
| `DC98:275A` | `wp_file_submenu_DC98_275A` | 1 | call from `DC98:282F` [top-icon-menus.md:50](top-icon-menus.md#L50) |
| `DC98:2807` | `wp_top_menu_DC98_2807` | 2 | call from `C688:EB1E` [app-menu-event-loop.md:125](app-menu-event-loop.md#L125)<br>call from `C688:EB1E` [wp-edit-text.md:39](wp-edit-text.md#L39) |
| `DC98:282A` | (address-only) | 2 | jnz from `DC98:2824` [top-icon-menus.md:45](top-icon-menus.md#L45)<br>jnz from `DC98:2824` [wp-edit-text.md:24](wp-edit-text.md#L24) |
| `DC98:2843` | (address-only) | 1 | jnz from `DC98:282D` [top-icon-menus.md:49](top-icon-menus.md#L49) |
| `DC98:2885` | (address-only) | 2 | jmp from `DC98:2828` [top-icon-menus.md:47](top-icon-menus.md#L47)<br>jmp from `DC98:2828` [wp-edit-text.md:26](wp-edit-text.md#L26) |
| `DC98:2887` | (address-only) | 2 | call from `DC98:CF21` [organizer-address-book.md:23](organizer-address-book.md#L23)<br>call from `DC98:991C` [organizer-scheduler.md:22](organizer-scheduler.md#L22) |
| `DC98:288A` | `system_settings_DC98_288A` | 1 | call from `DC98:2D3E` [wp-submenus.md:234](wp-submenus.md#L234) |
| `DC98:2A83` | `preferences_DC98_2A83` | 1 | call from `DC98:2D51` [wp-submenus.md:235](wp-submenus.md#L235) |
| `DC98:2B75` | `rom_card_loader_DC98_2B75` | 1 | call from `DC98:2D7D` [wp-submenus.md:237](wp-submenus.md#L237) |
| `DC98:2C1B` | (address-only) | 2 | jz from `DC98:2BC5` [wp-others-handlers.md:152](wp-others-handlers.md#L152)<br>jz from `DC98:2BE3` [wp-others-handlers.md:160](wp-others-handlers.md#L160) |
| `DC98:2C69` | (address-only) | 1 | jnl from `DC98:2C2C` [wp-others-handlers.md:208](wp-others-handlers.md#L208) |
| `DC98:2C9F` | (address-only) | 1 | jnl from `DC98:2C7D` [wp-others-handlers.md:234](wp-others-handlers.md#L234) |
| `DC98:2CF2` | (address-only) | 1 | jnz from `DC98:2CEC` [wp-others-handlers.md:261](wp-others-handlers.md#L261) |
| `DC98:2D13` | (address-only) | 1 | jz from `DC98:2CF2` [wp-others-handlers.md:263](wp-others-handlers.md#L263) |
| `DC98:2D2B` | `wp_others_submenu_DC98_2D2B` | 1 | call from `DC98:2871` [top-icon-menus.md:58](top-icon-menus.md#L58) |
| `DC98:455F` | (address-only) | 1 | call from `DC98:27CF` [wp-submenus.md:40](wp-submenus.md#L40) |
| `DC98:4D08` | (address-only) | 1 | call from `C688:EF5A` [app-menu-event-loop.md:164](app-menu-event-loop.md#L164) |
| `DC98:539E` | (address-only) | 2 | call from `C000:00FD` [boot.md:188](boot.md#L188)<br>call from `DC98:53D9` [top-icon-menus.md:111](top-icon-menus.md#L111) |
| `DC98:53C3` | `organizer_top_menu_DC98_53C3` | 3 | call from `C688:EF46` [app-menu-event-loop.md:140](app-menu-event-loop.md#L140)<br>call from `C688:EF50` [app-menu-event-loop.md:152](app-menu-event-loop.md#L152)<br>call from `C688:775D` [menu-entry.md:151](menu-entry.md#L151) |
| `DC98:53D9` | (address-only) | 2 | jnz from `DC98:53C9` [top-icon-menus.md:106](top-icon-menus.md#L106)<br>jnz from `DC98:53D0` [top-icon-menus.md:108](top-icon-menus.md#L108) |
| `DC98:53DE` | (address-only) | 1 | jz from `DC98:53D7` [top-icon-menus.md:110](top-icon-menus.md#L110) |
| `DC98:54A9` | (address-only) | 2 | call from `DC98:6A7C` [organizer-calculator.md:28](organizer-calculator.md#L28)<br>call from `DC98:6A82` [organizer-calculator.md:30](organizer-calculator.md#L30) |
| `DC98:583E` | (address-only) | 1 | call from `DC98:6A8D` [organizer-calculator.md:33](organizer-calculator.md#L33) |
| `DC98:5C5C` | (address-only) | 1 | call from `DC98:6A90` [organizer-calculator.md:34](organizer-calculator.md#L34) |
| `DC98:5D9F` | (address-only) | 1 | call from `DC98:624E` [organizer-calculator.md:161](organizer-calculator.md#L161) |
| `DC98:5E2D` | (address-only) | 1 | call from `DC98:623D` [organizer-calculator.md:157](organizer-calculator.md#L157) |
| `DC98:5ED4` | (address-only) | 1 | call from `DC98:6CD5` [organizer-calculator.md:207](organizer-calculator.md#L207) |
| `DC98:5F42` | (address-only) | 1 | call from `DC98:6CD0` [organizer-calculator.md:206](organizer-calculator.md#L206) |
| `DC98:5FE0` | (address-only) | 1 | call from `DC98:62CB` [organizer-calculator.md:175](organizer-calculator.md#L175) |
| `DC98:60AB` | (address-only) | 1 | call from `DC98:62E6` [organizer-calculator.md:177](organizer-calculator.md#L177) |
| `DC98:60D1` | (address-only) | 1 | call from `DC98:6301` [organizer-calculator.md:178](organizer-calculator.md#L178) |
| `DC98:61B8` | (address-only) | 1 | call from `DC98:631C` [organizer-calculator.md:179](organizer-calculator.md#L179) |
| `DC98:6239` | (address-only) | 1 | jnl from `DC98:6254` [organizer-calculator.md:163](organizer-calculator.md#L163) |
| `DC98:640F` | (address-only) | 1 | call from `DC98:6A98` [organizer-calculator.md:36](organizer-calculator.md#L36) |
| `DC98:6B4C` | (address-only) | 1 | call from `DC98:6C38` [organizer-calculator.md:203](organizer-calculator.md#L203) |
| `DC98:9AC8` | (address-only) | 2 | call from `DC98:A092` [organizer-world-clock.md:130](organizer-world-clock.md#L130)<br>call from `DC98:A0C6` [organizer-world-clock.md:137](organizer-world-clock.md#L137) |
| `DC98:9FD4` | (address-only) | 1 | call from `DC98:A0A5` [organizer-world-clock.md:136](organizer-world-clock.md#L136) |
| `DC98:A06C` | (address-only) | 1 | call from `DC98:B96B` [organizer-world-clock.md:163](organizer-world-clock.md#L163) |
| `DC98:A0CC` | (address-only) | 1 | call from `DC98:B877` [organizer-world-clock.md:26](organizer-world-clock.md#L26) |
| `DC98:B9F2` | (address-only) | 1 | call from `DC98:D049` [organizer-address-book.md:60](organizer-address-book.md#L60) |
| `DC98:BA42` | (address-only) | 1 | call from `DC98:D015` [organizer-address-book.md:59](organizer-address-book.md#L59) |
| `DC98:BB4F` | (address-only) | 1 | call from `DC98:CFF2` [organizer-address-book.md:54](organizer-address-book.md#L54) |
| `DC98:CB04` | (address-only) | 1 | call from `DC98:D04C` [organizer-address-book.md:61](organizer-address-book.md#L61) |
| `DC98:D3BB` | (address-only) | 3 | call from `C000:037D` [power-irq.md:130](power-irq.md#L130)<br>call from `C000:07B0` [rtc-alarm-power.md:24](rtc-alarm-power.md#L24)<br>call from `C000:037D` [rtc-programming.md:24](rtc-programming.md#L24) |
| `DC98:DB5E` | (address-only) | 1 | call from `C000:0796` [rtc-alarm-power.md:22](rtc-alarm-power.md#L22) |
| `DC98:E946` | (address-only) | 2 | call from `DC98:E8DB` [dc98-file-wrappers.md:22](dc98-file-wrappers.md#L22)<br>call from `DC98:2C70` [wp-others-handlers.md:231](wp-others-handlers.md#L231) |
| `DC98:EE08` | `file_read_DC98_EE08` | 1 | call from `DC98:2CA7` [wp-others-handlers.md:239](wp-others-handlers.md#L239) |
| `DC98:EE2E` | (address-only) | 1 | call from `DC98:2CDD` [wp-others-handlers.md:242](wp-others-handlers.md#L242) |
| `DC98:EF7B` | (address-only) | 2 | call from `DC98:2BBE` [wp-others-handlers.md:150](wp-others-handlers.md#L150)<br>call from `DC98:2BDC` [wp-others-handlers.md:158](wp-others-handlers.md#L158) |
| `DC98:F198` | (address-only) | 1 | call from `EBBB:0182` [wp-others-handlers.md:79](wp-others-handlers.md#L79) |
| `DC98:F200` | (address-only) | 1 | call from `EBBB:0175` [wp-others-handlers.md:78](wp-others-handlers.md#L78) |
| `EBBB:0000` | `typin_time_entry_EBBB_0000` | 1 | call from `DC98:2D65` [wp-submenus.md:236](wp-submenus.md#L236) |
| `EBBB:00CC` | `typin_time_init_EBBB_00CC` | 1 | call from `EBBB:000F` [wp-others-handlers.md:25](wp-others-handlers.md#L25) |
| `EBBB:0116` | (address-only) | 1 | call from `EBBB:0162` [wp-others-handlers.md:75](wp-others-handlers.md#L75) |
| `EBBB:012E` | `typin_time_dispatcher_EBBB_012E` | 1 | call from `EBBB:010A` [wp-others-handlers.md:58](wp-others-handlers.md#L58) |
