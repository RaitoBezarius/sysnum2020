# 酒井戸: Sakaido, the brillant microprocessor

# Introduction

This is a RISC-V core implementation in Verilog, it tries as much as possible to provide a vaguely usable implementation.

At the time of writing, it is currently able to run a very simple subset of RV32I, including a clock.

It targets the Arty S7-50 as a FPGA and otherwise works well with `iverilog`.

# Instructions on how to run

This repository has a `shell.nix`, `Makefile` and `.envrc` (direnv).

## Enjoying caching

```shell
nix-env -iA cachix -f https://cachix.org/api/v1/install
cachix use sysnum-riscv
```

Thanks to ENS for providing build servers :).

## `nix-shell`

Just running `nix-shell shell.nix` will provide you with a RISC-V 32 bits toolchain and `Makefile` will work out of the box.

## `.envrc`

Just allow the file: `direnv allow` and your shell will be provided with all that is needed.

## Testing

`make test` will run a test program and test firmware in simulation with Icarus Verilog.

## FPGA test

TODO: package the Vivado toolchain nicely and provide the bitstream generation mechanism and upload.

# Makefile documentation

`_vgenerated` is what Verilator produces.
`build` is the default build directory for useful artefacts, e.g. firmware, simulation runtime, etc.

```console
make clean # remove build/ and _vgenerated/
make test # test the default testbed
make test-memory # test the memory system directly with the hart0 using a block RAM
make dis-soft # disassemble the current test.elf
# TODO
make test-dcache # test the D-cache directly with the hart0 using a memory system linked with a block RAM
make test-uart # test the UART mechanism using a linux FIFO socket
make test-compliance # run the compliance test suite
make test-mmu # test the MMU
make formal # perform formal verification on all components
make upload-fpga # use Vivado to upload the current design to the FPGA
make flash-spi # use a programmer to flash to a SPI an initial firmware for persistent design
make freertos # build an image of FreeRTOS for a demo
make linux # build an RV32IM image of linux for a demo
```

The `Makefile` is pretty much modular and has some variables configurable for quick'n'dirty / temporary tests, please read: `Makefile` or `Rules.mk`.

# Documentation

Some draft "frozen" (for us) docs are in docs/, including RISC-V specs, RISC-V privileged specs and Interrupt Cookbook from SiFive, please use them as a reference.

# Model

## Theory

Target is a 5-staged pipeline processor.

(1) Instruction fetching (IF)

(2) Decode, register fetching: `rs1, rs2` (ID)

(3) Execution (EX)a

(4) Arbitrary memory access (MA)

(5) Write-back (WB)

Due to RISC-V ISA, there can be no structural hazards by design, at any moment, two instructions cannot require the same hardware resource at same time.
So no stalling should be put for instructions.

## Data hazards

Data hazards are still possible:

```
x1 ← x0 + 1
x2 ← x1 + 2
```

It is then required to implement stalling for early pipeline stages.
A simple way to implement such interlock control logic is to proceed by implementing a stall condition inside the core in the early pipeline stage.

For this to work, stalling must happen whenever a `rs` field match some `rd` ONLY IF the instruction writes OR read a register, i.e. check `write_enable` or `read_enable`.

Jumps and branches must be handled with caution.

## Shit, here we RAM again

Load & store will cause hazards too.

```
M[x1 + 1] ← x2
x4 ← M[x3 + 3]
```

If `x1 + 1 = x3 + 3`, this is a data hazard.

As long as the memory system completes its writes in one cycle, it's avoided.

## It's not the End™

This model does not account for branches and jumps really, especially, for `jalr` to have its target known, it requires a register fetching.

A way to solve this is to use branch prediction, but it requires statistical strategies with an instruction caching. So, TODO.

# TODO

## Core: RV32I (Julien & Ryan)

- [x] XLEN=32

- [x] JAL
- [x] IMM
- [x] OP: VANILLA/SUBSRA/MULT — ADD/SLL/SRL/SLT/SLTU/XOR/OR/AND/ADD/etc.
- [x] BRANCH: ADD/SLL/XOR/SRL/OR/AND
- [x] LUI: load upper immediate
- [x] AUIPC: add upper immediate to pc
- [x] JALR: jump and link register

- [x] LOAD
- [x] STORE
- [ ] MISCMEM/FENCE
- [x] SYSTEM

- [ ] 5-staged pipeline

- [x] Wishbone interconnection with a (FPGA) block RAM
- [ ] HALT signal
- [x] STALL signal
- [ ] RESET signal

## ALU: M extension (???)

- [ ] Send M-related instructions to another unit.

## VGA Controller (Constantin)

- [x] Initial controller
- [ ] Wishbone interconnect
- [ ] Memory mapping
- [ ] Simple primitives to show stuff

**Bonus for Ryan** :

- [ ] Implement a framebuffer driver in linux for it.

## RISC-V compliance testsuite & Verilator (Ryan & Julien)

- [x] Submodule for RISC-V compliance testsuite
- [x] Write the test harness with our own Makefile
- [x] Move to Verilator
- [ ] Write a simulation model to test our CPU with Verilator
- [ ] Report the results of the compliance testsuite
- [ ] Put it in GitHub Actions CI

## Data cache / instruction cache (Ryan)

- [x] Lay out the bare minimum in the CPU
- [ ] 2-way associative simple read-write data cache
- [ ] Formal verification using SymbiYosys
- [ ] Connect it to the CPU

## MMU (Ryan)

- [ ] Lay out the bare minimum in the CPU
- [ ] Simple permissions model
- [x] IO memory mapping (through a memory subsystem, allow for up to 5 buses, thus 4 IOs or 3 IOs + 1 registers, excluding the RAM controller)
- [ ] Formal verification using Symbiyosys
- [ ] Connect it to the CPU

## IRQ / Privileged mode (Julien)

Resources: look in docs, <https://stackoverflow.com/questions/61913210/risc-v-interrupt-handling-flow>, <http://faculty.salina.k-state.edu/tim/ossg/Introduction/OSworking.html>, <

- [x] Split up tasks
- [x] Dual mode
- [ ] Implement a CLINT

## RISC-V debug extension (???)

Go go go : <https://riscv.org/wp-content/uploads/2019/03/riscv-debug-release.pdf>

## Arty S7-50 FPGA-specific (???)

- [ ] Generate the DDR3L Xilinx FIFO controller
- [ ] Write a native FIFO to Wishbone bridge
- [ ] Connect the 100MHz clock to the RAM controller
- [ ] Connect the DDR3L to the CPU or the cache

## FreeRTOS (???)

- [x] Port it to our board (instant if CLINT is implemented)
- [ ] Make it run.
- [ ] Put the clock on it.

## Linux (Ryan, if he can, that is.)

- [ ] Implement a micro-BIOS to load an operating system
- [ ] Write a DTS file for our board and implementation
- [ ] Compile a RISC-V Linux
- [ ] Port coreboot to this board (?!)
