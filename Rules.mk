all:	targets

mk_build_directory:
	mkdir -p $(BUILDDIR)

dir := src/firmware
include $(dir)/Makefile.mk
dir := src/software
include $(dir)/Makefile.mk
dir := src/rtl
include $(dir)/Makefile.mk
dir := vendor/
include $(dir)/Makefile.mk

.PHONY:	targets
targets: mk_build_directory $(TGT_FIRMWARE) $(TGT_SOFTWARE) $(TGT_SIM_RUNTIME) $(TGT_FREERTOS_DEMO_IMAGE)

test: targets
	cd $(BUILDDIR) && ./$(TESTBED_EXECUTABLE) $(SIMULATOR-FLAGS)

.USE_MEMORY_TESTBED:
	$(eval TESTBED_SOURCE = src/rtl/memsys_test.sv)
	$(eval TESTBED_SIM_SOURCE = src/rtl/sim/mem_testbed.cpp)
	$(eval TESTBED_EXECUTABLE = mem_simulation)

test-memory: .USE_MEMORY_TESTBED targets
	cd $(BUILDDIR) && ./$(TESTBED_EXECUTABLE) $(SIMULATOR-FLAGS)

dis-soft:
	$(RISCV-OBJDUMP) -d $(TGT_SOFTWARE_ELF)

.PHONY:	clean
clean:
	rm -f $(CLEAN)
	rm -rf $(VERILOG_GENERATED) $(CLEAN_DIRS)

.SECONDARY:	$(CLEAN) $(CLEAN_DIRS)

