# sysnum2020

Projet de sysnum 2020

# Documentation

Some draft "frozen" (for us) docs are in docs/, including RISC-V specs, RISC-V privileged specs and Interrupt Cookbook from SiFive, please use them as a reference.

# TODO

## Core: RV64IM

- [x] XLEN=32
- [ ] XLEN=64

- [x] JAL
- [x] IMM
- [x] OP: VANILA/SUBSRA/MULT — ADD/SLL/SRL/SLT/SLTU/XOR/OR/AND/ADD/etc.
- [x] BRANCH: ADD/SLL/XOR/SRL/OR/AND
- [ ] LUI: load upper immediate
- [ ] AUIPC: add upper immediate to pc
- [ ] JALR: jump and link register
- [ ] LOAD
- [ ] STORE
- [ ] MISCMEM
- [ ] SYSTEM

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

## IRQ

Resources: look in docs, <https://stackoverflow.com/questions/61913210/risc-v-interrupt-handling-flow>, <http://faculty.salina.k-state.edu/tim/ossg/Introduction/OSworking.html>, <

- [ ] Split up tasks
- [ ] Implement a CLINT

## FreeRTOS

- [ ] Port it to our board.
- [ ] Make it run.
- [ ] Champagne.
