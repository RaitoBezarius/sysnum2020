#include "testbench.hpp"

template<class Module> class ROMTestbench : public Testbench<Module> {
        vluint32_t mRomAddr;
        vluint32_t* mRomArray;

        public:
        ROMTestbench(vluint64_t* gTimer, Module* core, vluint64_t nTicks, bool trace) {
                Testbench<Module>::Testbench(gTimer, core, nTicks, trace);

                mRomAddr = 0x0;
                mRomArray = nullptr;
        }

        virtual void setupROM(vluint32_t startAddr, vluint32_t* romArray) {
                mRomArray = romArray;
                mRomAddr = startAddr;
        }

        virtual void postEval(vluint64_t cur_tick) {
                // Update ROM at the start of the tick.
                mCore->rom_out = mRomArray[mCore->rom_addr];
        }
}
