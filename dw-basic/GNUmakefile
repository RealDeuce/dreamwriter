NASM ?= nasm
PYTHON ?= python3

BUILD_DIR := build
CARD_IN ?= /tmp/dw-card-1m.bin
CARD_OUT ?= /tmp/dw-card-1m-dw-basic.bin
EROMCARD := $(BUILD_DIR)/EROMCARD.X
GW_EROMCARD := $(BUILD_DIR)/EROMCARD-GW.X
GW_BASIC_OVR := $(BUILD_DIR)/GWBASIC.OVR
FLATLINK_DIR ?= ../third_party/flatlink
FLATLINK ?= $(FLATLINK_DIR)/flatlink
GW_BASIC_LOAD_OFFSET ?= 2048
FLATLINK_FLAGS ?= -f bin -offset $(GW_BASIC_LOAD_OFFSET) -maxfixups 10000
GW_REF_DIR ?= ../gw-basic
GW_SRC_DIR := src/gw
GW_BUILD_DIR := $(BUILD_DIR)/gw
GW_BASIC_BIN := $(BUILD_DIR)/gw-basic.bin
GW_BASIC_MAP := $(BUILD_DIR)/gw-basic.map
GW_BASIC_SYMBOLS := $(BUILD_DIR)/gw-basic-symbols.inc
GW_BASIC_MIN_FREE ?= 4096
GW_MEMORY_MODEL ?= flat64
TRUNCATE_SIZE ?= 8192

ifneq ($(GW_MEMORY_MODEL),flat64)
$(error GW_MEMORY_MODEL=$(GW_MEMORY_MODEL) is scaffolded but not implemented; see docs/memory-model.md)
endif
GW_MODULES := \
	bimisc \
	biprtu \
	biptrg \
	bistrs \
	call86 \
	fiveo \
	gengrp \
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
	dwio \
	dwstubs
GW_GENERATED_MODULES := $(filter-out dwstubs dwio giotbl,$(GW_MODULES))
GW_GENERATED_SOURCES := $(GW_GENERATED_MODULES:%=$(GW_SRC_DIR)/%.asm)
GW_SIMPLE_GENERATED_SOURCES := $(filter-out $(GW_SRC_DIR)/gwdata.asm $(GW_SRC_DIR)/gwram.asm $(GW_SRC_DIR)/gwinit.asm $(GW_SRC_DIR)/gio86.asm $(GW_SRC_DIR)/ibmres.asm $(GW_SRC_DIR)/itsa86.asm $(GW_SRC_DIR)/math1.asm $(GW_SRC_DIR)/scndrv.asm,$(GW_GENERATED_SOURCES))
GW_OBJECTS := $(GW_MODULES:%=$(GW_BUILD_DIR)/%.obj)
GW_INCLUDES := \
	src/include/dwoem.inc \
	src/include/gio86u.inc \
	src/include/gwerrors.inc \
	src/include/gwtokens.inc \
	src/include/msdosu.inc

.PHONY: all basic-card basic-payload clean card flatlink gw-basic-bin gw-objects gw-sources gw-math2-source large-smoke-card large-smoke-payload omf-unresolved truncate-card truncate-payload

all: $(EROMCARD)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(EROMCARD): src/eromcard.asm src/gw/dwio.asm src/include/dwapi.asm src/include/dwconsole.asm src/include/dwoem.inc | $(BUILD_DIR)
	$(NASM) -f bin -I src/include/ -o $@ $<

$(GW_BUILD_DIR):
	mkdir -p $(GW_BUILD_DIR)

$(GW_SRC_DIR):
	mkdir -p $(GW_SRC_DIR)

$(GW_SRC_DIR)/gwdata.asm: $(GW_REF_DIR)/gwdata.asm tools/masm2nasm.py tools/gwdata_tables.py | $(GW_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $< $@
	$(PYTHON) tools/gwdata_tables.py $@ $<

$(GW_SRC_DIR)/gwram.asm: $(GW_REF_DIR)/gwram.asm tools/masm2nasm.py tools/gwram_tables.py | $(GW_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $< $@
	$(PYTHON) tools/gwram_tables.py $@

$(GW_SRC_DIR)/ibmres.asm: $(GW_REF_DIR)/ibmres.asm tools/masm2nasm.py tools/ibmres_tables.py | $(GW_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $< $@
	$(PYTHON) tools/ibmres_tables.py $@

$(GW_SRC_DIR)/math1.asm: $(GW_REF_DIR)/math1.asm $(GW_REF_DIR)/math2.asm tools/masm2nasm.py tools/gwmath_module.py tools/gwmath_symbols.py | $(GW_SRC_DIR)
	$(PYTHON) tools/gwmath_module.py $(GW_REF_DIR)/math1.asm $(GW_REF_DIR)/math2.asm $@
	$(PYTHON) tools/gwmath_symbols.py $@

$(GW_SRC_DIR)/math2.asm: $(GW_REF_DIR)/math2.asm tools/masm2nasm.py | $(GW_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py --initial-radix 8 $< $@

gw-math2-source: $(GW_SRC_DIR)/math2.asm

$(GW_SRC_DIR)/gwinit.asm: $(GW_REF_DIR)/gwinit.asm tools/masm2nasm.py tools/flat_runtime_patches.py | $(GW_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $< $@
	$(PYTHON) tools/flat_runtime_patches.py gwinit $@

$(GW_SRC_DIR)/itsa86.asm: $(GW_REF_DIR)/itsa86.asm tools/masm2nasm.py tools/flat_runtime_patches.py | $(GW_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $< $@
	$(PYTHON) tools/flat_runtime_patches.py itsa86 $@

$(GW_SRC_DIR)/gio86.asm: $(GW_REF_DIR)/gio86.asm tools/masm2nasm.py tools/flat_runtime_patches.py | $(GW_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $< $@
	$(PYTHON) tools/flat_runtime_patches.py gio86 $@

$(GW_SRC_DIR)/scndrv.asm: $(GW_REF_DIR)/scndrv.asm tools/masm2nasm.py tools/flat_runtime_patches.py | $(GW_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $< $@
	$(PYTHON) tools/flat_runtime_patches.py scndrv $@

$(GW_SIMPLE_GENERATED_SOURCES): $(GW_SRC_DIR)/%.asm: $(GW_REF_DIR)/%.asm tools/masm2nasm.py | $(GW_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $< $@

$(GW_BUILD_DIR)/%.obj: $(GW_SRC_DIR)/%.asm $(GW_INCLUDES) | $(GW_BUILD_DIR)
	$(NASM) -f obj -I src/include/ -o $@ $<

$(GW_BUILD_DIR)/dwio.obj: src/include/dwapi.asm src/include/dwconsole.asm

$(FLATLINK): $(FLATLINK_DIR)/src/*.c $(FLATLINK_DIR)/src/*.h
	$(MAKE) -C $(FLATLINK_DIR)/src

flatlink: $(FLATLINK)

gw-sources: $(GW_GENERATED_SOURCES)

gw-objects: $(GW_OBJECTS)

$(GW_BASIC_BIN): $(GW_OBJECTS) $(FLATLINK) | $(BUILD_DIR)
	$(FLATLINK) $(FLATLINK_FLAGS) -o $@ -m $(GW_BASIC_MAP) $(GW_OBJECTS)

gw-basic-bin: $(GW_BASIC_BIN)

$(GW_BASIC_SYMBOLS): $(GW_BASIC_BIN) tools/map_to_nasm.py
	$(PYTHON) tools/map_to_nasm.py $(GW_BASIC_MAP) $@ INIT LSTVAR DW_LOADER_LIMIT DW_EXIT_DS DW_EXIT_ES DW_EXIT_SS DW_EXIT_SP DW_EXIT_IP DW_EXIT_CS

$(GW_BASIC_OVR): $(GW_BASIC_BIN) | $(BUILD_DIR)
	cp $< $@

$(GW_EROMCARD): src/eromcard_gw.asm $(GW_BASIC_OVR) $(GW_BASIC_SYMBOLS) | $(BUILD_DIR)
	$(NASM) -f bin -D GW_BASIC_MIN_FREE=$(GW_BASIC_MIN_FREE) -D GW_BASIC_LOAD_OFFSET=$(GW_BASIC_LOAD_OFFSET) -D GW_OVR_SIZE=$$(stat -f %z $(GW_BASIC_OVR)) -o $@ $<

basic-payload: $(GW_EROMCARD) $(GW_BASIC_OVR)

truncate-payload: $(GW_EROMCARD)
	dd if=$(GW_EROMCARD) of=$(EROMCARD) bs=1 count=$(TRUNCATE_SIZE)

truncate-card: truncate-payload
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload $(EROMCARD)

omf-unresolved: gw-objects
	$(PYTHON) tools/omf_symbols.py --unresolved $(GW_OBJECTS)

card: $(EROMCARD)
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload $(EROMCARD)

large-smoke-payload: $(GW_EROMCARD) src/eromcard.asm src/gw/dwio.asm src/include/dwapi.asm src/include/dwconsole.asm src/include/dwoem.inc | $(BUILD_DIR)
	$(NASM) -f bin -I src/include/ -DEROMCARD_PAD_SIZE=$$(stat -f %z $(GW_EROMCARD)) -o $(EROMCARD) src/eromcard.asm

large-smoke-card: large-smoke-payload
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload $(EROMCARD)

basic-card: $(GW_EROMCARD) $(GW_BASIC_OVR)
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload $(GW_EROMCARD) --extra GWBASIC.OVR=$(GW_BASIC_OVR)

clean:
	rm -rf $(BUILD_DIR)
