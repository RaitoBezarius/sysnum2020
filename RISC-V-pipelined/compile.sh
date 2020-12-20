#!/bin/sh

mkdir build
cd build

success=true

echo "***** Firmware *****"
{
    riscv32-none-elf-as ../firmware.s -o firmware.elf &&
    riscv32-none-elf-objdump -d firmware.elf          &&
    riscv32-none-elf-objcopy -O verilog firmware.elf
} || {
    echo "Couldn't build"
    success=false
}

echo
echo

echo "***** Program *****"
{
    riscv32-none-elf-as ../test.s -o test.elf    &&
    riscv32-none-elf-objdump -d test.elf         &&
    riscv32-none-elf-objcopy -O verilog test.elf
} || {
    echo "Couldn't build"
    success=false
}

echo
echo

echo "***** SOC *****"
cd ../

{
    verilator -cc riscv.v &&
    cd obj_dir            &&
    make -f Vriscv.mk     &&
    cd ../                &&
    g++ -I /usr/share/verilator/include/ -I obj_dir/ /usr/share/verilator/include/verilated.cpp testbed.cpp obj_dir/Vriscv__ALL.a
} || {
    echo "Couldn't build"
    success=false
}

if $success
then
    echo
    echo
    echo "Successful."
fi

