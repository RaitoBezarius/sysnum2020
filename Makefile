# Embedded cross-compile toolchain
RISCV-CC = riscv32-none-elf-gcc
RISCV-AS = riscv32-none-elf-as
RISCV-OBJCOPY = riscv32-none-elf-objcopy
RISCV-OBJDUMP = riscv32-none-elf-objdump
# For Verilog hex files
RISCV-ELF2HEX = riscv32-none-elf-elf2hex

# Simulation
VERILOG-CC = verilator
VERILOG-FLAGS = -Wall --cc -MMD -Isrc/rtl -Wno-fatal --build --exe -DN_TICKS=$(SIMULATION_N_TICKS) -DXLEN=$(XLEN) --Mdir $(VERILOG_GENERATED) --trace --trace-structs
VERILOG_GENERATED = _vgenerated
VERILOG_MAKEFILE = Vtestbed.mk
VERILOG-TRACE-MAX-ARRAY-DEPTH = 65536
VERILOG-TRACE-MAX-WIDTH = 65536

SIMULATOR =
SIMULATOR-FLAGS = +nticks+$(SIMULATION_N_TICKS)

# Flags
ELF2HEX-FLAGS = --bit-width $(XLEN)
RISCV-AS-FLAGS = 
RISCV-CC-FLAGS = -march=$(RISCV-ARCH) -mabi=$(RISCV-ABI) -mcmodel=medany -fvisibility=hidden -nostartfiles -nostdlib -Wl,-T,$(RISCV-LINKER-SCRIPT) $(RISCV-CRT0)


# Softcore configuration
XLEN = 32
RISCV-ARCH = rv$(XLEN)im
RISCV-ABI = ilp32
RISCV-LINKER-SCRIPT = src/firmware/riscv32-simulator.ld # RAM position, etc.
RISCV-CRT0 = src/firmware/crt0.S # Stack initialization.
DUAL_MODE_FIRMWARE_SRC = src/firmware/firmware.s

# Simulation/FPGA configuration
TEST_PROGRAM_SRC = src/software/test.c
SIMULATION_N_TICKS = 5000

TESTBED_SOURCE = src/rtl/testbed.sv
TESTBED_SIM_SOURCE = src/rtl/sim/testbed.cpp
TESTBED_EXECUTABLE = simulation

# Build configuration
BUILDDIR = build

include Rules.mk
