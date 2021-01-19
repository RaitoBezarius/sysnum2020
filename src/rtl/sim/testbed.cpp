#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <ctime>

#include "verilated.h"
#include "Vtestbed.h"
#include "testbench.hpp"

using namespace std;

#define EPOCH 0x7ffec
#define INCREMENT_NOW 0x5000

clock_t start;
vluint64_t main_time = 0;       // Current simulation time
double sc_time_stamp() {
    return static_cast<double>(main_time);
}

clock_t tic() {
    start = clock();
    return start;
}

double tac() {
    return (clock() - start) / (double)CLOCKS_PER_SEC;
}

vluint32_t read_ram_int(Vtestbed* mod, vluint32_t addr) {
    return mod->__DOT_bram_DOT__ram[addr];
}

/*
void write_ram_int(Vtestbed* mod, vluint32_t addr, vluint32_t value) {
    mod->RAM[addr] = value;
}*/


bool parseArg(std::string const& arg, std::string const& prefix,
        std::string& value) {
    size_t len = prefix.length();

    if (strncmp(prefix.c_str(), arg.c_str(), len) == 0) {
        value = arg.substr(len);
        return true;
    } else {
        return false;
    }
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    vluint64_t nTicks = 100;
    bool enableRealtimeMode = false; // Enable or not the RTC.
    for (int i = 0 ; i < argc ; i++) {
        string val;
        if (parseArg(argv[i], "+nticks+", val)) {
            nTicks = atoi(val.c_str());
        }

        if (parseArg(argv[i], "+realtime", val)) {
            enableRealtimeMode = true;
        }
    }

    Vtestbed* vlog = new Vtestbed;
    Testbench<Vtestbed> tb(
            &main_time,
            vlog,
            nTicks,
            true);

    cout << "Verilating the testbench now for " << nTicks << "." << endl;
    tb.openTrace("trace.vcd");

    double avg_tick_delay = 0;
    vluint32_t last_epoch = 0;
    vluint32_t cur_epoch = 0;

    clock_t seconds_counter = clock();
    while (!tb.done()) {
        tic();
        tb.tick();
        avg_tick_delay += tac()/(double)nTicks;
        cur_epoch = read_ram_int(vlog, EPOCH);
        if (last_epoch != cur_epoch) {
            cout << "Seconds: " << cur_epoch << endl;
            last_epoch = cur_epoch;
        }
        // If a second elapsed, just assert increment now.
        if (enableRealtimeMode && (clock() - seconds_counter) / (double)CLOCKS_PER_SEC >= 1) {
            //write_ram_int(vlog, INCREMENT_NOW, 1);
        }
    }

    cout << "Performance: " << 1/avg_tick_delay << " ticks per second." << endl;

    return 0;
}

