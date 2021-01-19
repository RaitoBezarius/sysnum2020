# Magic to save directories
sp := $(sp).x
dirstack_$(sp) := $(d)
d := $(dir)

SOURCES_SV_$(d) = $(shell find . -type f -name '*.sv')
SOURCES_SIM_$(d) = $(shell find . -type f -name '*.cpp')

ifndef BUILDDIR
$(error Build directory (BUILDDIR) is not set)
endif

TGT_SIM_RUNTIME = $(BUILDDIR)/$(TESTBED_EXECUTABLE)
CLEAN := $(CLEAN) $(TGT_SIM_RUNTIME)

$(BUILDDIR)/$(TESTBED_EXECUTABLE): $(TESTBED_SOURCE) $(SOURCES_SV_$(d)) $(SOURCES_SIM_$(d))
	@echo "[+] Building the simulation runtime"
	$(VERILOG-CC) $(VERILOG-FLAGS) $(TESTBED_SOURCE) $(TESTBED_SIM_SOURCE) -o $(TESTBED_EXECUTABLE)
	mv $(VERILOG_GENERATED)/$(TESTBED_EXECUTABLE) $(BUILDDIR)/$(TESTBED_EXECUTABLE)

d := $(dirstack_$(sp))
sp := $(basename $(sp))
