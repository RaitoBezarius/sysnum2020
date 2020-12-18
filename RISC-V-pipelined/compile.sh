#!/bin/sh

echo "***** Firmware *****"
riscv32-none-elf-as firmware.s -o firmware.elf
riscv32-none-elf-objdump -d firmware.elf
riscv32-none-elf-objcopy -O verilog firmware.elf

echo
echo

echo "***** Program *****"
riscv32-none-elf-as test.s -o test.elf
riscv32-none-elf-objdump -d test.elf
riscv32-none-elf-objcopy -O verilog test.elf

