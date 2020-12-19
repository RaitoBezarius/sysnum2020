
# Unprivileged

## Combinatorial circuits

Forwarded data must be instantly available, which requires
the ALU data to also be instantly available. These two components
must therefore be implemented as combinatorial circuits.

## Pipeline

|IF  | Instruction Fetch  |
|ID  | Instruction Decode |
|EX  | Execute            |
|MEM | Memory             |
|WB  | Write Back         |

In a nominal cycle :
  * Fetch the instruction
  * Find what to perform
  * Access the operands
  * Compute the result (for register operations)
  * Read and write memory
    Both happen at the same time from the processor's perspective
  * Write back to registers.
    Implemented in the last stage, as we only want one input to
    the register file and both EX and MEM may produce values that
    will be written to registers.

### ID
Not only Decode
  * Also responsible for fetching operands, therefore outputs
    the two operands (or the number of operands that the
    instruction has).
  * Must handle data hazards -> Linked to Forwarding Unit.
It might be possible to further optimize the ID stage, by referring
to the table 24.1 in the RISC-V manual, using the array presentation
it provides.

Register read is during ID.

ID should detect NOP instructions.

### EXE

What are the possibilities ?
ID gives all the operands, the destination and the operation type.

May also not require the ALU at all ! When it comes to memory
operations.

Also output :
  * The output register id;
  * Wether the MEM stage instruction (possibly NOP);
  * The input registers ids, to be used by the forwarding
    unit.

RISC-V operations:
  * ADDI, SLTI, SLTIU, ANDI, ORI, XORI, SLLI, SRLI, SRAI
  * ADD, SLT, SLTU, AND, OR, XOR, SLL, SRL, SUB, SRA

What may be performed (EX operations) :
  * ADD, SUB
  * SLT, SLTU
  * AND, OR, XOR
  * SLL, SRL, SRA
  * NOP
11 possible operations.

For shifting operations : only the 5 first bits of the operand
are considered (see the spec).

Memory operations only require ADD.
 
Control transfer instructions may require an addition *and*
a comparison. One possibility is to add a special addition
circuit that will be used by both memory and control transfer
instructions.
This may be an incentive to hardwire an adder.

Control transfer requires at most : 2 inputs that will
be compared, a base and an offset.

STORE also requires 3 inputs : the value to store, and a base-offset
couple.

The base will always be added to the offset, which may suggest that
it would be better to add the two before the EXE stage (during ID).
However, computation naturally belongs to the EXE stage, and additions
may be longer to perform, so they belong to the EXE stage which
performs all the operation that may take more time.

| instruction | input 1   | input 2   | base   | offset    |
------------------------------------------------------------
| JAL         | pc        | immediate | unused | unused    |
| JALR        | op1       | immediate | unused | unused    |
| BRANCH      | op1       | op2       | pc     | immediate |
| LOAD        | op1       | op2       | unused | immediata |
| STORE       | op1       | op2       | unused | immeduata |

Based on this table, we pass the following to the EXE stage :
  * op1, op2 (required anyway by arithmetic operations);
  * pc
  * offset

The EXE control transfer instructions are :
JUMP, BEQ, BNE, BLT, BLTU, BGE, BGEU.

The actual jump will be handled during the WB stage.

### MEM

Some memory operations require performing arithemetics on
adresses. Do we want to do this during the EXE state or
in MEM itself ?
  * It seems like such operations are fast enough to be
    performed during MEM.
  * It seems like the actual time cost of EXE lies in MUL
    and DIV.

MEM operations may lead to two behaviors :
  * If the memory span is already cached, or if there is no
    complicated memory protection (e.g. MMU), then they aren't
    more costly than register operations (or slightly more)
  * If the span isn't cached... this may lead to MMU calls.
    -> Compute-intensive, stalls the pipeline, ...

### WB

This stage may :
  * Write a register;
  * Jump;
  * Do nothing.

When jumping, the previous pipeline stages must be invalidated
(in absence of branch prediction).

## Forwading ?

The forwarding unit makes sure the EXE stage sees the right information.
It must therefore handle :
  * The result of the MEM stage;
  * The results of the WB stage.

That means the CPU state that the EXE stage sees is that of the CPU
after the previous instructions have been processed (except for jumps
that are only guessed).
Therefore, it solves all data hazards.

This requires adding wires between ID and Forward to tell which register
is read.
This can be done by using only a 5-wide bus, and declaring that the value
00000 is equivalent to no forwarding (this exploits the fact that r0 is
hardwired to 0).

### Forwarding to ID

The registers should not be directly accessed.
Instead, the ID block should ask the forwarding unit for the
relevant value.

The EX, MEM and WB stages should inform the forwarding unit on wether they will
trigger a write and, if applicable, what is being written.

The forwading unit provies an interface between registers and the
ID stage.

## What signals do we need ?

STALL; KILL

In each pipeline stage : a wire that stalls it : bubbling behavior.

Forwarding units

**Each stage must have a no-op state** (used in case of invalidation
and at the first execution).

The NOP state may be used for stalling. In this case, the NOP state
musn't modify the outputs of the stage.

The pipeline contents may be invalidated (in case of a jump)
Invalidation occurs when a jumping instruction arrives in WB.
This is triggered by a KILL signal.

## Incremental design

Incremental design ?

 * IF/ID/EX/WB; no branch
 * Forwarding
 * Branching            -- At this stage, we have a functional processor
 * Memory operations

### IF/ID/EX/WB, no branch

#### Integer computational instructions

| register-immediate | I-type, U-type |
| regiser-register   | R-type         |

To build immediate value : use figure 2.4 from the RISC-V manual.

First : build the immediates. Nothing to do for R-type instructions.

| OP-IMM | I-type |
| LUI    | U-type |
| AUIPC  | U-type |
| OP     | R-type |

### What's next

#### Memory operations

LOAD/STORE

Require an addition : handle this in the EXE stage.

Might cause data hazards : should be handled by
forwarding unit

Data hazards can be resolved by branching the forwarging unit on
the EX stage. This also requires to prepare data that may be
forwarded during the ID stage, in case the address register of a
memory operation is written to by another memory operation.

# Privileged

## Interruptions

Some hints may lie in the Privileged Architecture Manual, paragraph 5.6.2, "Trap Entry" and
5.6.4, "Trap return" -- beware thought, these paragraphs belong to the Hypervisor
extension !

According to the SiFive Interrupt Cookbook, upon interruption, we
want to :
  * Save `pc` to `mepc`;
  * Save the privilege level to `mstatus.mpp`;
  * Save `mie` to `mstatus.mpie`;
  * Set `pc` to the interrupt handler address;
  * Disable interrupts : `mstatus.mie <- 0`.

When returning from an interruption, we want to :
  * Set `pc` to `mepc`
  * Set the current privilege level to `mstatus.mpp`
  * Set `mie` to `mstatus.mpie`

### Dual mode

When trapping, the processor switches to "dual mode".
This switches to another register set and another program memory.
We may want to switch to another, smaller main memory.

Three possibilities for dual mode trap :
  * SYSTEM call;
  * Exception;
  * Memory access (if we want virtual addresses and a MMU).
Idea : use one entry point for each instruction.

We will use an additional argument for traps :
  * For SYSTEM calls and exceptions, the instruction that caused the trap;
  * For memory accesses, the (virtual) address we want to access.

When entering dual mode :
  * We write `pc` to some register;
  * We write the argument to another register.

Dual mode is exitted by executing any SYSTEM instruction.

Dual mode can't access the RAM.
Instead, LOAD and STORE instruction operate on a memory-mapped
space that maps the normal mode registers, plus some extra registers
that store the CSR states.

