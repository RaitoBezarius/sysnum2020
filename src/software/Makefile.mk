# Magic to save directories
sp := $(sp).x
dirstack_$(sp) := $(d)
d := $(dir)

SOURCES_$(d) = $(shell find $(d) -type f -name '*.c')

TEST_PROGRAM_ELF = test.elf
TEST_PROGRAM = test.hex

ifndef BUILDDIR
$(error Build directory (BUILDDIR) is not set)
endif

ifndef RISCV-CRT0
$(error No crt0.s is provided through RISCV-CRT0)
endif

ifndef RISCV-LINKER-SCRIPT
$(error No linker script was provided through RISCV-LINKER-SCRIPT)
endif

TGT_SOFTWARE_ELF = $(BUILDDIR)/$(TEST_PROGRAM_ELF)
TGT_SOFTWARE = $(BUILDDIR)/$(TEST_PROGRAM)
CLEAN := $(CLEAN) $(TGT_SOFTWARE) $(BUILDDIR)/$(TEST_PROGRAM_ELF)

$(TGT_SOFTWARE_ELF): $(TEST_PROGRAM_SRC) $(RISCV_CRT0) $(SOURCES_$(d))
	@echo "[+] Building the test program"
	$(RISCV-CC) $(RISCV-CC-FLAGS) $(TEST_PROGRAM_SRC) -o $@

$(TGT_SOFTWARE): $(TGT_SOFTWARE_ELF)
	@echo "[+] Transforming it into Verilog hexfile"
	$(RISCV-ELF2HEX) $(ELF2HEX-FLAGS) --input $(BUILDDIR)/$(TEST_PROGRAM_ELF) --output $@

d := $(dirstack_$(sp))
sp := $(basename $(sp))
