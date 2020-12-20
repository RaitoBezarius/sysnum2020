#include <stdio.h>
#include <stdlib.h>
#include <iostream>

#include "verilated.h"
#include "Vtestbed.h"


vluint64_t main_time = 0;       // Current simulation time
double sc_time_stamp() {
    return main_time;
}

void tick(Vtestbed *tb) {
    tb->eval();
    tb->clk = 1;
    tb->eval();
    tb->clk = 0;
    tb->eval();
}

int main(int argc, char **argv) {
    std::cout << "Hello world !" << std::endl;

    Verilated::commandArgs(argc, argv);
    Vtestbed *tb = new Vtestbed();

    for(int i = 0; i < 20; i++) {
        tick(tb);
        //std::cout << tb->rom_addr << std::endl;
        main_time++;
    }

    tb->final();
    delete tb;

    return 0;
}

