all:	targets

mk_build_directory:
	mkdir -p $(BUILDDIR)

dir := src/firmware
include $(dir)/Makefile.mk
dir := src/software
include $(dir)/Makefile.mk
dir := src/rtl
include $(dir)/Makefile.mk

.PHONY:	targets
targets: mk_build_directory $(TGT_FIRMWARE) $(TGT_SOFTWARE) $(TGT_SIM_RUNTIME)

test: targets
	cd $(BUILDDIR) && $(SIMULATOR) $(TESTBED_EXECUTABLE) $(SIMULATOR-FLAGS)

.PHONY:	clean
clean:
	rm -f $(CLEAN)

.SECONDARY:	$(CLEAN)

