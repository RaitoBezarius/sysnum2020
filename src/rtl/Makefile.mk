# Magic to save directories
sp := $(sp).x
dirstack_$(sp) := $(d)
d := $(dir)

SOURCES_$(d) = $(shell find . -type f -name '*.sv')

ifndef BUILDDIR
$(error Build directory (BUILDDIR) is not set)
endif

TGT_SIM_RUNTIME = $(BUILDDIR)/$(TESTBED_EXECUTABLE)
CLEAN := $(CLEAN) $(TGT_SIM_RUNTIME)

$(BUILDDIR)/$(TESTBED_EXECUTABLE): $(TESTBED_SOURCE) $(SOURCES_$(d))
	@echo "[+] Building the simulation runtime"
	$(VERILOG-CC) $(VERILOG-FLAGS) $(TESTBED_SOURCE) -o $@

d := $(dirstack_$(sp))
sp := $(basename $(sp))
