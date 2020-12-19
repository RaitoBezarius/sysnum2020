ecall
li x1, 99
sw x1, 0(x0)
lw x2, 0(x0)
nop
li x3, 5
nop
add x3, x0, x2
#ecall
