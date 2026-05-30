NASM ?= nasm
PYTHON ?= python3

BUILD_DIR := build
CARD_IN ?= /tmp/dw-card-1m.bin
CARD_OUT ?= /tmp/dw-card-1m-dw-basic.bin
EROMCARD := $(BUILD_DIR)/EROMCARD.X

.PHONY: all clean card

all: $(EROMCARD)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(EROMCARD): src/eromcard.asm src/include/dwapi.asm src/include/dwconsole.asm | $(BUILD_DIR)
	$(NASM) -f bin -o $@ $<

card: $(EROMCARD)
	$(PYTHON) tools/install_eromcard.py --card-in $(CARD_IN) --card-out $(CARD_OUT) --payload $(EROMCARD)

clean:
	rm -rf $(BUILD_DIR)
