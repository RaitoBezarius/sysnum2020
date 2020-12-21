# Magic to save directories
sp := $(sp).x
dirstack_$(sp) := $(d)
d := $(dir)

FREERTOS_KERNEL_INCLUDE_FILES = vendor/FreeRTOS/FreeRTOS/Source/include
FREERTOS_BASE_DEMO = vendor/FreeRTOS/FreeRTOS/Demo/RISC-V-32-Verilator-sim_GCC
SOURCES_$(d) = $(shell find $(FREERTOS_BASE_DEMO) -type f -name '*.c')

FREERTOS_BUILDDIR = $(FREERTOS_BASE_DEMO)/build

TGT_FREERTOS_DEMO_ELF = $(BUILDDIR)/FreeRTOS.elf
TGT_FREERTOS_DEMO_IMAGE = $(BUILDDIR)/FreeRTOS.hex

CLEAN := $(CLEAN) $(TGT_FREERTOS_DEMO_IMAGE) $(TGT_FREERTOS_DEMO_ELF)
CLEAN_DIRS := $(CLEAN_DIRS) $(FREERTOS_BUILDDIR)

$(TGT_FREERTOS_DEMO_IMAGE): $(TGT_FREERTOS_DEMO_ELF)
	@echo "[+] Transforming the ELF image into a Verilog hex file"
	$(RISCV-ELF2HEX) $(ELF2HEX-FLAGS) --input $(TGT_FREERTOS_DEMO_ELF) --output $@

$(TGT_FREERTOS_DEMO_ELF): $(SOURCES_$(d))
	@if ! [ -d "$(FREERTOS_KERNEL_INCLUDE_FILES)" ]; then @echo "[!] The kernel include files are missing, please check your git repository" ; @exit 1; fi
	@echo "[+] Building FreeRTOS demo image"
	make -C $(FREERTOS_BASE_DEMO) -f Makefile IMAGE_NAME=FreeRTOS.elf
	mv $(FREERTOS_BUILDDIR)/FreeRTOS.elf $(TGT_FREERTOS_DEMO_ELF)

d := $(dirstack_$(sp))
sp := $(basename $(sp))
