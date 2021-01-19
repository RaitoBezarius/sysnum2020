#include <stdio.h>
#include <stdlib.h>
#include <iostream>

#include "verilated.h"
#include "Vcompliancebed.h"
#include "romtestbench.hpp"

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
    string firmwareFileName, signatureFileName;


    for (int i = 0 ; i < argc ; i++) {
        string val;
        if (parseArg(argv[i], "+maxcycles+", val)) {
            nTicks = atoi(val.c_str())*2;
        }

        parseArg(argv[i], "+firmware+", firmwareFileName);
        parseArg(argv[i], "+signature", signatureFileName);
    }

    if (!firmwareFileName) {
        cout << "[!] No ROM provided!" << endl;
        return 1;
    }

    if (!signatureFileName) {
        cout << "[!] No signature output provided!" << endl;
        return 1;
    }

    ROMTestbench<Vcompliancebed> tb(
            &main_time,
            new Vcompliancebed,
            nTicks,
            false);

    vluint32_t* romArray = readFirmware(firmwareFileName);

    tb.setupROM(0x0, firmware);
    while (!tb.done()) {
        tb.tick();
    }

    // TODO(Ryan): collect the results somewhere somehow and write them as signature.

    return 0;
}

