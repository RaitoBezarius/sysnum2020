# 酒井戸: Sakaido, the brillant microprocessor

# Introduction

This is a RISC-V core implementation in Verilog, it tries as much as possible to provide a vaguely usable implementation.

At the time of writing, it is currently able to run a very simple subset of RV32I, including a clock.

It targets the Arty S7-50 as a FPGA and otherwise works well with `iverilog`.

# Documentation

Some draft "frozen" (for us) docs are in docs/, including RISC-V specs, RISC-V privileged specs and Interrupt Cookbook from SiFive, please use them as a reference.

# Model

## Theory

Target is a 5-staged pipeline processor.

(1) Instruction fetching (IF)
(2) Decode, register fetching: `rs1, rs2` (ID)
(3) Execution (EX)
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

## Core: RV64IM

- [x] XLEN=32
- [ ] XLEN=64

- [x] JAL
- [x] IMM
- [x] OP: VANILA/SUBSRA/MULT — ADD/SLL/SRL/SLT/SLTU/XOR/OR/AND/ADD/etc.
- [x] BRANCH: ADD/SLL/XOR/SRL/OR/AND
- [x] LUI: load upper immediate
- [x] AUIPC: add upper immediate to pc
- [x] JALR: jump and link register

- [ ] LOAD
- [ ] STORE
- [ ] MISCMEM/FENCE
- [ ] SYSTEM

### Core refactor (Ryan + Constantin)

- [ ] Get out the ALU (Constantin).
- [ ] Introduce HALT, RESET, STALL signals (Ryan).
- [ ] Rewrite the memory interface system to support async signalling of memory ack'd a read (Ryan).
- [ ] Rewrite the ROM interface (Ryan).

## 64-bits (Julien?)

- [ ] W instructions variants: `add(i)w, subw, sxxw`, etc.
- [ ] 64-bits LUI
- [ ] 64-bits AUIPC
- [ ] 64-bits LOAD
- [ ] 64-bits STORE
- [ ] LD
- [ ] LW
- [ ] LWU
- [ ] 64-bits CSR: RDCYCLE, RDTIME, RDISTRET. Make illegal the H variants in RV64I.

- [ ] 64-bits version of M-extension: mult/div.

## IRQ (Ryan)

Resources: look in docs, <https://stackoverflow.com/questions/61913210/risc-v-interrupt-handling-flow>, <http://faculty.salina.k-state.edu/tim/ossg/Introduction/OSworking.html>, <

- [ ] Split up tasks
- [ ] Implement a CLINT

## FreeRTOS (???)

- [ ] Port it to our board.
- [ ] Make it run.
- [ ] Champagne.

## Linux (!?)

- [ ] Implement privileged extension, at least, M/S.
- [ ] Write an MMU.
- [ ] Make it run.
