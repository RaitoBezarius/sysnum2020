
#include <stdio.h>
#include <stdlib.h>
#include <iostream>

#include "verilated.h"
#include "Vriscv.h"

void tick(Vriscv *tb) {
    tb->eval();
    tb->clk = 1;
    tb->eval();
    tb->clk = 0;
    tb->eval();
}

int main(int argc, char **argv) {
    std::cout << "Hello world !" << std::endl;

    Verilated::commandArgs(argc, argv);
    Vriscv *tb = new Vriscv();

    for(int i = 0; i < 20; i++) {
        tick(tb);
        //std::cout << tb->rom_addr << std::endl;
    }
}

