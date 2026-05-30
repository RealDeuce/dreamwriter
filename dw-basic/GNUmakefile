NASM ?= nasm
PYTHON ?= python3

BUILD_DIR := build
CARD_IN ?= /tmp/dw-card-1m.bin
CARD_OUT ?= /tmp/dw-card-1m-dw-basic.bin
EROMCARD := $(BUILD_DIR)/EROMCARD.X
GW_REF_DIR ?= ../gw-basic
GW_SRC_DIR := src/gw
GW_BUILD_DIR := $(BUILD_DIR)/gw
GW_MODULES := \
	bimisc \
	biprtu \
	biptrg \
	bistrs \
	call86 \
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
	math1 \
	next86 \
	scndrv \
	scnedt \
	dwio \
	dwstubs
GW_GENERATED_MODULES := $(filter-out dwstubs dwio giotbl,$(GW_MODULES))
GW_GENERATED_SOURCES := $(GW_GENERATED_MODULES:%=$(GW_SRC_DIR)/%.asm)
GW_SIMPLE_GENERATED_SOURCES := $(filter-out $(GW_SRC_DIR)/gwdata.asm $(GW_SRC_DIR)/gwram.asm $(GW_SRC_DIR)/ibmres.asm $(GW_SRC_DIR)/math1.asm,$(GW_GENERATED_SOURCES))
GW_OBJECTS := $(GW_MODULES:%=$(GW_BUILD_DIR)/%.obj)
GW_INCLUDES := \
	src/include/dwoem.inc \
	src/include/gio86u.inc \
	src/include/gwerrors.inc \
	src/include/gwtokens.inc \
	src/include/msdosu.inc

.PHONY: all clean card gw-objects gw-sources omf-unresolved

all: $(EROMCARD)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(EROMCARD): src/eromcard.asm src/include/dwapi.asm src/include/dwconsole.asm | $(BUILD_DIR)
	$(NASM) -f bin -o $@ $<

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

$(GW_SIMPLE_GENERATED_SOURCES): $(GW_SRC_DIR)/%.asm: $(GW_REF_DIR)/%.asm tools/masm2nasm.py | $(GW_SRC_DIR)
	$(PYTHON) tools/masm2nasm.py $< $@

$(GW_BUILD_DIR)/%.obj: $(GW_SRC_DIR)/%.asm $(GW_INCLUDES) | $(GW_BUILD_DIR)
	$(NASM) -f obj -I src/include/ -o $@ $<

$(GW_BUILD_DIR)/dwio.obj: src/include/dwapi.asm src/include/dwconsole.asm

gw-sources: $(GW_GENERATED_SOURCES)

gw-objects: $(GW_OBJECTS)

omf-unresolved: gw-objects
	$(PYTHON) tools/omf_symbols.py --unresolved $(GW_OBJECTS)

card: $(EROMCARD)
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload $(EROMCARD)

clean:
	rm -rf $(BUILD_DIR)
