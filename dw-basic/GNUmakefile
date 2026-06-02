NASM ?= nasm
PYTHON ?= python3

BUILD_DIR := build
CARD_IN ?= /tmp/dw-card-1m.bin
CARD_OUT ?= /tmp/dw-card-1m-dw-basic.bin
NVRAM_IN ?= ../../nvram-romcard
NVRAM_OUT ?= /tmp/dw-nvram-romcard-dw-basic
NVRAM_STORE_OFFSET ?= 0x18000
SPLIT_SPIKE_BUILD_DIR ?= build-spike
SPLIT_SPIKE_NVRAM_OUT ?= /tmp/dw-nvram-romcard-split-spike
SPLIT_SPIKE_NASM_FLAGS ?=
SPLIT_SPIKE_COD_SEG ?= 0x19C0
SPLIT_SPIKE_DAT_ORG ?= 0x1000
EROMCARD := $(BUILD_DIR)/EROMCARD.X
MEMCHECK_EROMCARD := $(BUILD_DIR)/EROMCARD-MEMCHECK.X
MEMCHECK31_EROMCARD := $(BUILD_DIR)/EROMCARD-MEMCHECK-3.1UK.X
MEMCHECK1M_EROMCARD := $(BUILD_DIR)/EROMCARD-MEMCHECK-1M.X
MEMCHECK_EXAMPLE_DIR ?= ../examples/eromcard
MEMCHECK_CARD_OUT ?= /tmp/dw-card-1m-memcheck.bin
MEMCHECK31_CARD_OUT ?= /tmp/dw-card-1m-memcheck-31uk.bin
GW_EROMCARD := $(BUILD_DIR)/EROMCARD-GW.X
DW_BASIC_FLT := $(BUILD_DIR)/DW-BASIC.FLT
DW_BASIC_COD := $(BUILD_DIR)/DW-BASIC.COD
DW_BASIC_DAT := $(BUILD_DIR)/DW-BASIC.DAT
SPLIT_SPIKE_COD := $(SPLIT_SPIKE_BUILD_DIR)/SPIKE.COD
SPLIT_SPIKE_DAT := $(SPLIT_SPIKE_BUILD_DIR)/SPIKE.DAT
SPLIT_SPIKE_EROMCARD := $(SPLIT_SPIKE_BUILD_DIR)/EROMCARD-SPLIT-SPIKE.X
FLATLINK_DIR ?= ../third_party/flatlink
FLATLINK ?= $(FLATLINK_DIR)/flatlink
GW_BASIC_SEPARATE_SEGMENT ?= 1
ifeq ($(GW_BASIC_SEPARATE_SEGMENT),1)
GW_BASIC_LOAD_OFFSET ?= 0
else
GW_BASIC_LOAD_OFFSET ?= 2048
endif
FLATLINK_FLAGS ?= -f bin -offset $(GW_BASIC_LOAD_OFFSET) -maxfixups 10000
SPLITLINK_FLAGS ?= -f bin -offset 0 -splitseg -dataorg $(GW_DAT_ORG) -maxfixups 10000 -ocode $(DW_BASIC_COD) -odata $(DW_BASIC_DAT)
GW_REF_DIR ?= ../gw-basic
GW_SRC_DIR ?= src/gw
GW_GENERATED_SRC_DIR ?= $(GW_SRC_DIR)
GW_MANUAL_SRC_DIR ?= src/gw
GW_BUILD_DIR := $(BUILD_DIR)/gw
GW_BASIC_BIN := $(BUILD_DIR)/gw-basic.bin
GW_BASIC_MAP := $(BUILD_DIR)/gw-basic.map
GW_BASIC_SYMBOLS := $(BUILD_DIR)/gw-basic-symbols.inc
GW_BASIC_MIN_FREE ?= 4096
GW_DAT_ORG ?= 4096
GW_MEMORY_MODEL ?= flat64
GW_ENABLE_GRAPHICS ?= 0
GW_KEEP_DOS_VECTOR_WRAPPERS ?= 0
GW_BASIC_SPLIT_LOAD ?= 0
GW_BASIC_SPLIT_PAYLOAD ?= 0
DW_DEFAULT_FILE_DRIVE ?= 0x49
TRUNCATE_SIZE ?= 8192

ifneq ($(filter $(GW_MEMORY_MODEL),flat64 split128),$(GW_MEMORY_MODEL))
$(error GW_MEMORY_MODEL=$(GW_MEMORY_MODEL) is unknown; see docs/memory-model.md)
endif
GW_GRAPHICS_MODULES := \
	advgrp \
	gengrp
GW_MODULES := \
	bimisc \
	biprtu \
	biptrg \
	bistrs \
	call86 \
	dskcom \
	fiveo \
	gio86 \
	giocon \
	giokyb \
	gioscn \
	giotbl \
	gwdata \
	gweval \
	gwinit \
	gwlist \
	gwmain \
	gwram \
	gwsts \
	ibmres \
	itsa86 \
	maclng \
	math1 \
	next86 \
	scndrv \
	scnedt \
	dwdisk \
	dwio \
	dwstubs
ifeq ($(GW_ENABLE_GRAPHICS),1)
GW_MODULES := $(GW_GRAPHICS_MODULES) $(GW_MODULES)
endif
GW_GENERATED_MODULES := $(filter-out dwstubs dwio dwdisk giotbl,$(GW_MODULES))
GW_MANUAL_MODULES := $(filter-out $(GW_GENERATED_MODULES),$(GW_MODULES))
GW_GENERATED_SOURCES := $(GW_GENERATED_MODULES:%=$(GW_GENERATED_SRC_DIR)/%.asm)
GW_SIMPLE_GENERATED_SOURCES := $(filter-out $(GW_GENERATED_SRC_DIR)/bimisc.asm $(GW_GENERATED_SRC_DIR)/giokyb.asm $(GW_GENERATED_SRC_DIR)/gwdata.asm $(GW_GENERATED_SRC_DIR)/gwram.asm $(GW_GENERATED_SRC_DIR)/gwinit.asm $(GW_GENERATED_SRC_DIR)/gio86.asm $(GW_GENERATED_SRC_DIR)/gwsts.asm $(GW_GENERATED_SRC_DIR)/ibmres.asm $(GW_GENERATED_SRC_DIR)/itsa86.asm $(GW_GENERATED_SRC_DIR)/math1.asm $(GW_GENERATED_SRC_DIR)/scndrv.asm,$(GW_GENERATED_SOURCES))
GW_OBJECTS := $(GW_MODULES:%=$(GW_BUILD_DIR)/%.obj)
GW_GENERATED_OBJECTS := $(GW_GENERATED_MODULES:%=$(GW_BUILD_DIR)/%.obj)
GW_MANUAL_OBJECTS := $(GW_MANUAL_MODULES:%=$(GW_BUILD_DIR)/%.obj)
GW_INCLUDES := \
	src/include/dwoem.inc \
	src/include/gio86u.inc \
	src/include/gwerrors.inc \
	src/include/gwtokens.inc \
	src/include/msdosu.inc
GW_NASM_FLAGS := -D GW_ENABLE_GRAPHICS=$(GW_ENABLE_GRAPHICS) -D GW_KEEP_DOS_VECTOR_WRAPPERS=$(GW_KEEP_DOS_VECTOR_WRAPPERS) -D GW_BASIC_SPLIT_LOAD=$(GW_BASIC_SPLIT_LOAD) -D DW_DEFAULT_FILE_DRIVE=$(DW_DEFAULT_FILE_DRIVE)
MASM2NASM_FLAGS ?=
ifeq ($(GW_BASIC_SPLIT_LOAD),1)
GW_BASIC_SYMBOL_DEPS := $(DW_BASIC_COD) $(DW_BASIC_DAT)
else
GW_BASIC_SYMBOL_DEPS := $(GW_BASIC_BIN)
endif
ifeq ($(GW_BASIC_SPLIT_PAYLOAD),1)
GW_EROMCARD_DEPS := $(DW_BASIC_COD) $(DW_BASIC_DAT) $(GW_BASIC_SYMBOLS)
GW_EROMCARD_IMAGE_FLAGS = -D GW_COD_SIZE=$$(stat -f %z $(DW_BASIC_COD)) -D GW_DAT_SIZE=$$(stat -f %z $(DW_BASIC_DAT)) -D GW_DAT_ORG=$(GW_DAT_ORG)
else
GW_EROMCARD_DEPS := $(DW_BASIC_FLT) $(GW_BASIC_SYMBOLS)
GW_EROMCARD_IMAGE_FLAGS = -D GW_OVR_SIZE=$$(stat -f %z $(DW_BASIC_FLT))
endif
GW_EROMCARD_DEBUG_FLAGS ?=

.PHONY: all basic-card basic-payload clean card flat-size-report flatlink gw-basic-bin gw-objects gw-sources gw-math2-source large-smoke-card large-smoke-payload memcheck-all-payloads memcheck-card memcheck-examples memcheck-payload memcheck1m-payload memcheck31-card memcheck31-payload omf-unresolved omf-unused-public split-basic-card split-basic-files split-basic-nvram split-basic-payload split-gw-basic-bin split-spike-files split-spike-nvram truncate-card truncate-payload

all: $(EROMCARD)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(EROMCARD): src/eromcard.asm src/gw/dwio.asm src/include/dwapi.asm src/include/dwconsole.asm src/include/dwoem.inc | $(BUILD_DIR)
	$(NASM) -f bin -I src/include/ -o $@ $<

$(MEMCHECK_EROMCARD): src/eromcard_memcheck.asm src/include/dwapi.asm | $(BUILD_DIR)
	$(NASM) -f bin -I src/include/ -o $@ $<

$(MEMCHECK31_EROMCARD): src/eromcard_memcheck.asm src/include/dwapi.asm | $(BUILD_DIR)
	$(NASM) -f bin -I src/include/ -D DW_ROMCARD_PROFILE=31 -o $@ $<

$(MEMCHECK1M_EROMCARD): src/eromcard_memcheck.asm src/include/dwapi.asm | $(BUILD_DIR)
	$(NASM) -f bin -I src/include/ -D DW_ROMCARD_PROFILE=100 -o $@ $<

$(GW_BUILD_DIR):
	mkdir -p $(GW_BUILD_DIR)

$(SPLIT_SPIKE_BUILD_DIR):
	mkdir -p $(SPLIT_SPIKE_BUILD_DIR)

$(GW_GENERATED_SRC_DIR):
	mkdir -p $(GW_GENERATED_SRC_DIR)

$(GW_GENERATED_SRC_DIR)/gwdata.asm: $(GW_REF_DIR)/gwdata.asm tools/masm2nasm.py tools/gwdata_tables.py tools/source_feature_ranges.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@
	$(PYTHON) tools/gwdata_tables.py $@ $<
	$(PYTHON) tools/source_feature_ranges.py $@ \
		--range dos_vector_save_slots:GW_KEEP_DOS_VECTOR_WRAPPERS:CTLCAD:LSTCHR:all

$(GW_GENERATED_SRC_DIR)/bimisc.asm: $(GW_REF_DIR)/bimisc.asm tools/masm2nasm.py tools/flat_runtime_patches.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@
	$(PYTHON) tools/flat_runtime_patches.py bimisc $@

$(GW_GENERATED_SRC_DIR)/gwram.asm: $(GW_REF_DIR)/gwram.asm tools/masm2nasm.py tools/gwram_tables.py tools/source_feature_ranges.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@
	$(PYTHON) tools/gwram_tables.py $@
	$(PYTHON) tools/source_feature_ranges.py $@ --range graphics_work_ram:GW_ENABLE_GRAPHICS:GRPACX:SAVLEN

$(GW_GENERATED_SRC_DIR)/ibmres.asm: $(GW_REF_DIR)/ibmres.asm tools/masm2nasm.py tools/ibmres_tables.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@
	$(PYTHON) tools/ibmres_tables.py $@

$(GW_GENERATED_SRC_DIR)/math1.asm: $(GW_REF_DIR)/math1.asm $(GW_REF_DIR)/math2.asm tools/masm2nasm.py tools/gwmath_module.py tools/gwmath_symbols.py tools/flat_runtime_patches.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/gwmath_module.py $(GW_REF_DIR)/math1.asm $(GW_REF_DIR)/math2.asm $@ $(MASM2NASM_FLAGS)
	$(PYTHON) tools/gwmath_symbols.py $@
	$(PYTHON) tools/flat_runtime_patches.py math1 $@

$(GW_GENERATED_SRC_DIR)/math2.asm: $(GW_REF_DIR)/math2.asm tools/masm2nasm.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) --initial-radix 8 $< $@

gw-math2-source: $(GW_SRC_DIR)/math2.asm

$(GW_GENERATED_SRC_DIR)/gwinit.asm: $(GW_REF_DIR)/gwinit.asm tools/masm2nasm.py tools/flat_runtime_patches.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@
	$(PYTHON) tools/flat_runtime_patches.py gwinit $@

$(GW_GENERATED_SRC_DIR)/itsa86.asm: $(GW_REF_DIR)/itsa86.asm tools/masm2nasm.py tools/flat_runtime_patches.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@
	$(PYTHON) tools/flat_runtime_patches.py itsa86 $@

$(GW_GENERATED_SRC_DIR)/gio86.asm: $(GW_REF_DIR)/gio86.asm tools/masm2nasm.py tools/source_feature_ranges.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@
	$(PYTHON) tools/source_feature_ranges.py $@ \
		--range dos_vector_wrappers:GW_KEEP_DOS_VECTOR_WRAPPERS:DINTAD:EOF \
		--else-ret-stubs dos_vector_wrappers:MSISET,MSIRST

$(GW_GENERATED_SRC_DIR)/giokyb.asm: $(GW_REF_DIR)/giokyb.asm tools/masm2nasm.py tools/flat_runtime_patches.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@
	$(PYTHON) tools/flat_runtime_patches.py giokyb $@

$(GW_GENERATED_SRC_DIR)/gwsts.asm: $(GW_REF_DIR)/gwsts.asm tools/masm2nasm.py tools/source_feature_ranges.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@
	$(PYTHON) tools/source_feature_ranges.py $@ \
		--range graphics_line_loop:GW_ENABLE_GRAPHICS:LINLP3:VARPT2 \
		--range com_event_traps:NMCOMT:COMS:KEYS \
		--range pointing_devices:GW_ENABLE_POINTING_DEVICES:PENS:DATES \
		--else-ret-stubs pointing_devices:POLPEN,POLSTR \
		--range disabled_advanced_error_stubs:GW_KEEP_DISABLED_STUBS:PALETE:EOF

$(GW_GENERATED_SRC_DIR)/scndrv.asm: $(GW_REF_DIR)/scndrv.asm tools/masm2nasm.py tools/flat_runtime_patches.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@
	$(PYTHON) tools/flat_runtime_patches.py scndrv $@

$(GW_SIMPLE_GENERATED_SOURCES): $(GW_GENERATED_SRC_DIR)/%.asm: $(GW_REF_DIR)/%.asm tools/masm2nasm.py | $(GW_GENERATED_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $(MASM2NASM_FLAGS) $< $@

$(GW_GENERATED_OBJECTS): $(GW_BUILD_DIR)/%.obj: $(GW_GENERATED_SRC_DIR)/%.asm $(GW_INCLUDES) | $(GW_BUILD_DIR)
	$(NASM) -f obj -I src/include/ $(GW_NASM_FLAGS) -o $@ $<

$(GW_MANUAL_OBJECTS): $(GW_BUILD_DIR)/%.obj: $(GW_MANUAL_SRC_DIR)/%.asm $(GW_INCLUDES) | $(GW_BUILD_DIR)
	$(NASM) -f obj -I src/include/ $(GW_NASM_FLAGS) -o $@ $<

$(GW_BUILD_DIR)/dwio.obj: src/include/dwapi.asm src/include/dwconsole.asm
$(GW_BUILD_DIR)/dwstubs.obj: src/include/dwapi.asm

$(FLATLINK): $(FLATLINK_DIR)/src/*.c $(FLATLINK_DIR)/src/*.h
	$(MAKE) -C $(FLATLINK_DIR)/src

flatlink: $(FLATLINK)

gw-sources: $(GW_GENERATED_SOURCES)

gw-objects: $(GW_OBJECTS)

$(GW_BASIC_BIN): $(GW_OBJECTS) $(FLATLINK) | $(BUILD_DIR)
	$(FLATLINK) $(FLATLINK_FLAGS) -o $@ -m $(GW_BASIC_MAP) $(GW_OBJECTS)

gw-basic-bin: $(GW_BASIC_BIN)

$(DW_BASIC_COD) $(DW_BASIC_DAT): $(GW_OBJECTS) $(FLATLINK) | $(BUILD_DIR)
	$(FLATLINK) $(SPLITLINK_FLAGS) -o $(BUILD_DIR)/dw-basic-split.bin -m $(GW_BASIC_MAP) $(GW_OBJECTS)

split-gw-basic-bin: $(DW_BASIC_COD) $(DW_BASIC_DAT)

$(GW_BASIC_SYMBOLS): $(GW_BASIC_SYMBOL_DEPS) tools/map_to_nasm.py
	$(PYTHON) tools/map_to_nasm.py $(GW_BASIC_MAP) $@ INIT LSTVAR

$(DW_BASIC_FLT): $(GW_BASIC_BIN) | $(BUILD_DIR)
	cp $< $@

$(GW_EROMCARD): src/eromcard_gw.asm $(GW_EROMCARD_DEPS) | $(BUILD_DIR)
	$(NASM) -f bin -I $(BUILD_DIR)/ -D GW_BASIC_SEPARATE_SEGMENT=$(GW_BASIC_SEPARATE_SEGMENT) -D GW_BASIC_SPLIT_PAYLOAD=$(GW_BASIC_SPLIT_PAYLOAD) -D GW_BASIC_MIN_FREE=$(GW_BASIC_MIN_FREE) -D GW_BASIC_LOAD_OFFSET=$(GW_BASIC_LOAD_OFFSET) $(GW_EROMCARD_IMAGE_FLAGS) $(GW_EROMCARD_DEBUG_FLAGS) -o $@ $<

basic-payload: $(GW_EROMCARD) $(DW_BASIC_FLT)

split-basic-files: $(GW_EROMCARD) $(DW_BASIC_COD) $(DW_BASIC_DAT)

split-basic-payload:
	$(MAKE) BUILD_DIR=build-split GW_GENERATED_SRC_DIR=build-split/src/gw GW_BUILD_DIR=build-split/gw GW_MEMORY_MODEL=split128 GW_BASIC_SPLIT_LOAD=1 GW_BASIC_SPLIT_PAYLOAD=1 MASM2NASM_FLAGS=--conditional-segments split-basic-files

split-basic-card:
	$(MAKE) BUILD_DIR=build-split GW_GENERATED_SRC_DIR=build-split/src/gw GW_BUILD_DIR=build-split/gw GW_MEMORY_MODEL=split128 GW_BASIC_SPLIT_LOAD=1 GW_BASIC_SPLIT_PAYLOAD=1 MASM2NASM_FLAGS=--conditional-segments split-basic-files
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload build-split/EROMCARD-GW.X --extra DW-BASIC.COD=build-split/DW-BASIC.COD --extra DW-BASIC.DAT=build-split/DW-BASIC.DAT

split-basic-nvram:
	$(MAKE) BUILD_DIR=build-split GW_GENERATED_SRC_DIR=build-split/src/gw GW_BUILD_DIR=build-split/gw GW_MEMORY_MODEL=split128 GW_BASIC_SPLIT_LOAD=1 GW_BASIC_SPLIT_PAYLOAD=1 MASM2NASM_FLAGS=--conditional-segments split-basic-files
	$(PYTHON) tools/install_eromcard.py --card-in $(NVRAM_IN) --card-out $(NVRAM_OUT) --store-offset $(NVRAM_STORE_OFFSET) --payload build-split/EROMCARD-GW.X --extra DW-BASIC.COD=build-split/DW-BASIC.COD --extra DW-BASIC.DAT=build-split/DW-BASIC.DAT

$(SPLIT_SPIKE_COD): src/split_spike_cod.asm src/include/dwapi.asm | $(SPLIT_SPIKE_BUILD_DIR)
	$(NASM) -f bin -I src/include/ -D SPLIT_SPIKE_DAT_ORG=$(SPLIT_SPIKE_DAT_ORG) $(SPLIT_SPIKE_NASM_FLAGS) -o $@ $<

$(SPLIT_SPIKE_DAT): src/split_spike_dat.asm | $(SPLIT_SPIKE_BUILD_DIR)
	$(NASM) -f bin -D SPLIT_SPIKE_DAT_ORG=$(SPLIT_SPIKE_DAT_ORG) $(SPLIT_SPIKE_NASM_FLAGS) -o $@ $<

$(SPLIT_SPIKE_EROMCARD): src/eromcard_split_spike.asm $(SPLIT_SPIKE_DAT) | $(SPLIT_SPIKE_BUILD_DIR)
	$(NASM) -f bin -I src/include/ -D SPLIT_SPIKE_COD_SEG=$(SPLIT_SPIKE_COD_SEG) -D SPLIT_SPIKE_DAT_ORG=$(SPLIT_SPIKE_DAT_ORG) -D SPLIT_SPIKE_DAT_SIZE=$$(stat -f %z $(SPLIT_SPIKE_DAT)) $(SPLIT_SPIKE_NASM_FLAGS) -o $@ $<

split-spike-files: $(SPLIT_SPIKE_EROMCARD) $(SPLIT_SPIKE_COD) $(SPLIT_SPIKE_DAT)

split-spike-nvram: split-spike-files
	$(PYTHON) tools/install_eromcard.py --card-in $(NVRAM_IN) --card-out $(SPLIT_SPIKE_NVRAM_OUT) --store-offset $(NVRAM_STORE_OFFSET) --payload $(SPLIT_SPIKE_EROMCARD) --extra SPIKE.COD=$(SPLIT_SPIKE_COD) --extra SPIKE.DAT=$(SPLIT_SPIKE_DAT)

truncate-payload: $(GW_EROMCARD)
	dd if=$(GW_EROMCARD) of=$(EROMCARD) bs=1 count=$(TRUNCATE_SIZE)

truncate-card: truncate-payload
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload $(EROMCARD)

omf-unresolved: gw-objects
	$(PYTHON) tools/omf_symbols.py --unresolved $(GW_OBJECTS)

omf-unused-public: gw-objects
	$(PYTHON) tools/omf_symbols.py --unused-public-by-file --keep INIT --keep LSTVAR $(GW_OBJECTS)

flat-size-report: basic-card
	$(MAKE) BUILD_DIR=build-graphics GW_ENABLE_GRAPHICS=1 gw-basic-bin
	$(PYTHON) tools/flat_build_report.py --base-map $(GW_BASIC_MAP) --optional-map graphics=build-graphics/gw-basic.map

card: $(EROMCARD)
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload $(EROMCARD)

memcheck-payload: $(MEMCHECK_EROMCARD)

memcheck-card: memcheck-payload
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(MEMCHECK_CARD_OUT) --payload $(MEMCHECK_EROMCARD)

memcheck31-payload: $(MEMCHECK31_EROMCARD)

memcheck31-card: memcheck31-payload
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(MEMCHECK31_CARD_OUT) --payload $(MEMCHECK31_EROMCARD)

memcheck1m-payload: $(MEMCHECK1M_EROMCARD)

memcheck-all-payloads: $(MEMCHECK_EROMCARD) $(MEMCHECK31_EROMCARD) $(MEMCHECK1M_EROMCARD)

memcheck-examples: memcheck-all-payloads
	mkdir -p $(MEMCHECK_EXAMPLE_DIR)
	rm -f $(MEMCHECK_EXAMPLE_DIR)/EROMCARD-MEMCHECK*.X
	cp $(MEMCHECK_EROMCARD) $(MEMCHECK_EXAMPLE_DIR)/EROMCARD-MEMCHECK-T400.X
	cp $(MEMCHECK1M_EROMCARD) $(MEMCHECK_EXAMPLE_DIR)/EROMCARD-MEMCHECK-200.X
	cp $(MEMCHECK31_EROMCARD) $(MEMCHECK_EXAMPLE_DIR)/EROMCARD-MEMCHECK-Original.X

large-smoke-payload: $(GW_EROMCARD) src/eromcard.asm src/gw/dwio.asm src/include/dwapi.asm src/include/dwconsole.asm src/include/dwoem.inc | $(BUILD_DIR)
	$(NASM) -f bin -I src/include/ -DEROMCARD_PAD_SIZE=$$(stat -f %z $(GW_EROMCARD)) -o $(EROMCARD) src/eromcard.asm

large-smoke-card: large-smoke-payload
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload $(EROMCARD)

basic-card: $(GW_EROMCARD) $(DW_BASIC_FLT)
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload $(GW_EROMCARD) --extra DW-BASIC.FLT=$(DW_BASIC_FLT)

clean:
	rm -rf $(BUILD_DIR)
