addi x8, x0, 60
addi x9, x0, 60
mul x9, x8, x9
addi x13, x0, 24
addi x14, x0, 31
addi x15, x0, 12

mul x10, x9, x13
mul x11, x10, x14
mul x12, x11, x15

nop

addi x1, x1, 1
rem x2, x1, x8

div x3, x1, x8
rem x3, x3, x8

div x4, x1, x9
rem x4, x4, x13

div x5, x1, x10
rem x5, x5, x14

div x6, x1, x11
rem x6, x6, x15

div x7, x1, x12
jal -12
