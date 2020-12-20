#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <verilated_vcd_c.h>

#include "verilated.h"
#include "Vtestbed.h"

using namespace std;

#ifndef N_TICKS
#define N_TICKS 5000
#endif

vluint64_t main_time = 0;       // Current simulation time
double sc_time_stamp() {
    return main_time;
}

template<class Module> class Testbench {
    Module  *mCore;
    VerilatedVcdC *mTrace;
    vluint64_t maxTicks;

    public:
    Testbench(Module* core, vluint64_t cMaxTicks) {
        Verilated::traceEverOn(true);
        mCore = core;
        maxTicks = cMaxTicks;

        mCore->reset = 0;
    }

    ~Testbench() {
        if (mTrace) {
            this->close();
        }

        if (mCore) {
            delete mCore;
            mCore = nullptr;
        }
    }

    bool done() {
        return sc_time_stamp() >= maxTicks || Verilated::gotFinish();
    }


    void openTrace(const char* vcdName) {
        if (!mTrace) {
            mTrace = new VerilatedVcdC;
            mCore->trace(mTrace, 99);
            mTrace->open(vcdName);
        }
    }

    void close() {
        if (!mTrace) {
            mTrace->close();
            mTrace = nullptr;
        }
    }

    void tick() {
        main_time++;

        mCore->clk = 0;
        mCore->eval();

        mTrace->dump(10*sc_time_stamp() - 2);

        mCore->clk = 1;
        mCore->eval();

        mTrace->dump(10*sc_time_stamp());

        // Negative edge.
        mCore->clk = 0;
        mCore->eval();

        mTrace->dump(10*sc_time_stamp() + 5);
        mTrace->flush();
    }
};

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Testbench<Vtestbed> tb(new Vtestbed, N_TICKS);

    cout << "Verilating the testbench now." << endl;

    tb.openTrace("trace.vcd");

    while (!tb.done()) {
        tb.tick();
    }

    return 0;
}

