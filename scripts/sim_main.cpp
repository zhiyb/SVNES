// Verilated -*- C++ -*-
// DESCRIPTION: main() calling loop, created with Verilator --main

#include <unistd.h>
#include "verilated.h"
#include "verilated_fst_c.h"
#include "sim.h"

int main(int argc, char** argv, char**)
{
    // Setup context, defaults, and parse command line
    Verilated::debug(0);
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->traceEverOn(true);
    contextp->commandArgs(argc, argv);

    // Construct the Verilated model, from Vtop.h generated from Verilating
    const std::unique_ptr<sim> topp{new sim{contextp.get()}};

    Verilated::traceEverOn(true);
    VerilatedFstC* tfp = new VerilatedFstC;
    topp->trace(tfp, 100);

    int c;
    while ((c = getopt(argc, argv, "o:")) != -1) {
        switch (c) {
            case 'o':
                tfp->open(optarg);
                break;
        }
    }

    // Simulate until $finish
    while (!contextp->gotFinish()) {
        // Evaluate model
        topp->eval();
        tfp->dump(contextp->time());
        // Advance time
        if (!topp->eventsPending()) break;
        contextp->time(topp->nextTimeSlot());
    }

    if (!contextp->gotFinish()) {
        VL_DEBUG_IF(VL_PRINTF("+ Exiting without $finish; no events left\n"););
    }

    tfp->close();

    // Final model cleanup
    topp->final();
    return 0;
}
