# Magic to save directories
sp := $(sp).x
dirstack_$(sp) := $(d)
d := $(dir)

SOURCES_$(d) = $(shell find . -type f -name '*.s')

FIRMWARE_PROGRAM_ELF = firmware.elf
FIRMWARE_PROGRAM = firmware.hex

ifndef BUILDDIR
$(error Build directory (BUILDDIR) is not set)
endif

TGT_FIRMWARE = $(BUILDDIR)/$(FIRMWARE_PROGRAM)
CLEAN := $(CLEAN) $(TGT_FIRMWARE) $(BUILDDIR)/$(FIRMWARE_PROGRAM_ELF)

$(BUILDDIR)/$(FIRMWARE_PROGRAM_ELF): $(DUAL_MODE_FIRMWARE_SRC) $(SOURCES_$(d))
	@echo "[+] Building the dual mode firmware"
	$(RISCV-AS) $(RISCV-AS-FLAGS) $(DUAL_MODE_FIRMWARE_SRC) -o $@

$(TGT_FIRMWARE): $(BUILDDIR)/$(FIRMWARE_PROGRAM_ELF)
	@echo "[+] Transforming it into a Verilog hexfile"
	$(RISCV-ELF2HEX) $(ELF2HEX-FLAGS) --input $(BUILDDIR)/$(FIRMWARE_PROGRAM_ELF) --output $@

d := $(dirstack_$(sp))
sp := $(basename $(sp))
