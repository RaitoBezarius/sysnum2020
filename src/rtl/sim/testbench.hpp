#include <verilated_vcd_c.h>

template<class Module> class Testbench {
    Module  *mCore;
    VerilatedVcdC *mTrace;
    vluint64_t maxTicks;
    vluint64_t* main_time;
    bool shouldTrace;

    public:
    Testbench(vluint64_t* globalTimer, Module* core, vluint64_t nTicks, bool trace) {
        Verilated::traceEverOn(true);

        main_time = globalTimer;

        mCore = core;
        mCore->reset = 0;

        maxTicks = nTicks;
        shouldTrace = trace;

        mTrace = nullptr;
    }

    virtual ~Testbench() {
        if (mTrace) {
            this->close();
        }

        if (mCore) {
            mCore->final();
            delete mCore;
            mCore = nullptr;
        }
    }

    virtual bool done() {
        return (*main_time) >= maxTicks || Verilated::gotFinish();
    }


    virtual void openTrace(const char* vcdName) {
        if (!mTrace) {
            mTrace = new VerilatedVcdC;
            mCore->trace(mTrace, 99);
            mTrace->open(vcdName);
        }
    }

    virtual void close() {
        if (!mTrace) {
            mTrace->close();
            mTrace = nullptr;
        }
    }

    virtual void postEval(vluint64_t cur_tick) {
    }

    virtual void tick() {
        (*main_time)++;
        vluint64_t cur_tick = *main_time;

        mCore->clk = 0;
        mCore->eval();
        this->postEval(cur_tick);

        if (shouldTrace) mTrace->dump(10*cur_tick - 2);

        mCore->clk = 1;
        mCore->eval();
        this->postEval(cur_tick);

        if (shouldTrace) mTrace->dump(10*cur_tick);

        // Negative edge.
        mCore->clk = 0;
        mCore->eval();
        this->postEval(cur_tick);

        if (shouldTrace) {
            mTrace->dump(10*cur_tick + 5);
            mTrace->flush();
        }
    }
};


