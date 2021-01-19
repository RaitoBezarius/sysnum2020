#include <stdio.h>
#include <stdlib.h>
#include <iostream>

#include "verilated.h"
#include "Vmemsys_test.h"
#include "testbench.hpp"

using namespace std;

vluint64_t main_time = 0;       // Current simulation time
double sc_time_stamp() {
    return static_cast<double>(main_time);
}

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
    for (int i = 0 ; i < argc ; i++) {
        string val;
        if (parseArg(argv[i], "+nticks+", val)) {
            nTicks = atoi(val.c_str());
        }
    }

    Testbench<Vmemsys_test> tb(
            &main_time,
            new Vmemsys_test,
            nTicks,
            true);

    cout << "Verilating the testbench now for " << nTicks << "." << endl;
    tb.openTrace("trace.vcd");

    while (!tb.done()) {
        tb.tick();
    }

    return 0;
}

