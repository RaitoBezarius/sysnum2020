# Embedded cross-compile toolchain
RISCV-CC = riscv32-none-elf-gcc
RISCV-AS = riscv32-none-elf-as
RISCV-OBJCOPY = riscv32-none-elf-objcopy
# For Verilog hex files
RISCV-ELF2HEX = riscv32-none-elf-elf2hex

# Simulation
VERILOG-CC = iverilog
VERILOG-FLAGS = -g2012 -Isrc/rtl

SIMULATOR = vvp
SIMULATOR-FLAGS = -lxt2 # Compact VCD traces.

# Flags
ELF2HEX-FLAGS = --bit-width $(XLEN)
RISCV-AS-FLAGS = 
RISCV-CC-FLAGS = -march=$(RISCV-ARCH) -mabi=$(RISCV-ABI) -ffreestanding -nolibc -nostdlib -Wl,-T,$(RISCV-LINKER-SCRIPT) $(RISCV-CRT0)


# Softcore configuration
XLEN = 32
RISCV-ARCH = rv$(XLEN)im
RISCV-ABI = ilp32
RISCV-LINKER-SCRIPT = src/firmware/riscv32-simulator.ld # RAM position, etc.
RISCV-CRT0 = src/firmware/crt0.S # Stack initialization.
DUAL_MODE_FIRMWARE_SRC = src/firmware/firmware.s

# Simulation/FPGA configuration
TEST_PROGRAM_SRC = src/software/test.c

TESTBED_SOURCE = src/rtl/testbed.sv
TESTBED_EXECUTABLE = simulation.vvp

# Build configuration
BUILDDIR = build

include Rules.mk
