# ==============================================================================
# Makefile for UVM Verification using Cadence Xcelium (xrun)
#  
# Open terminal inside the 'sim' directory.
# Type 'make run' to execute the simulation in batch mode.
# ==============================================================================

# Default parameters (can be overridden from terminal, e.g., make run GUI=1)
TESTNAME  ?= router_sanity_test
VERBOSITY ?= UVM_LOW
SEED      ?= random
GUI       ?= 0

# Relative paths (Assuming Makefile is inside project_root/verif/sim/)
RTL_DIR   = ../../RTL
PKG_DIR   = ../../Packages
IF_DIR    = ../../Interfaces
VERIF_DIR = ..

# Include directories (+incdir+) for the UVM environment and RTL
# This tells the compiler where to look when it sees an `include statement.
INCDIRS   = +incdir+$(RTL_DIR) \
            +incdir+$(PKG_DIR) \
            +incdir+$(IF_DIR) \
            +incdir+$(VERIF_DIR)/env \
            +incdir+$(VERIF_DIR)/seq \
            +incdir+$(VERIF_DIR)/tb \
            +incdir+$(VERIF_DIR)/tests \
            +incdir+$(VERIF_DIR)

# ------------------------------------------------------------------------------
# Source Files with Strict Compilation Order
# ------------------------------------------------------------------------------

# 1. RTL Parameters Package (Must be compiled first)
SRC_PKG   = $(PKG_DIR)/noc_params.sv

# 2. SystemVerilog Interfaces (Design and Testbench interfaces)
SRC_IF    = $(wildcard $(IF_DIR)/*.sv) \
            $(VERIF_DIR)/tb/router_if.sv

# 3. RTL Modules (Design Under Test)
SRC_RTL   = $(wildcard $(RTL_DIR)/*.sv)

# 4. UVM Package and Top-Level Module (Testbench top)
SRC_TB    = $(VERIF_DIR)/router_pkg.sv \
            $(VERIF_DIR)/tb/tb_top.sv

# Concatenate all files into a single variable
ALL_SRCS  = $(SRC_PKG) $(SRC_IF) $(SRC_RTL) $(SRC_TB)

# ------------------------------------------------------------------------------
# Xcelium (xrun) Compilation and Simulation Flags
# ------------------------------------------------------------------------------
XRUN_FLAGS = -64bit -uvm -sv 
XRUN_FLAGS += $(INCDIRS)
XRUN_FLAGS += -timescale 1ns/1ps
XRUN_FLAGS += -access +rwc      # Enables read/write/connectivity access for waveforms
XRUN_FLAGS += -linedebug        # Enables line debugging capabilities
XRUN_FLAGS += -svseed $(SEED)   # Sets the randomization seed for UVM
XRUN_FLAGS += +UVM_TESTNAME=$(TESTNAME)
XRUN_FLAGS += +UVM_VERBOSITY=$(VERBOSITY)

# Dynamically append GUI flag if GUI=1 is passed from terminal
ifeq ($(GUI), 1)
    XRUN_FLAGS += -gui
endif

# ------------------------------------------------------------------------------
# Execution Targets
# ------------------------------------------------------------------------------

# Default target: Batch mode execution (Terminal output only)
run:
	xrun $(XRUN_FLAGS) $(ALL_SRCS)

# Clean target: Removes simulator generated files, waveforms, and logs
clean:
	rm -rf INCA_libs xcelium.d xrun.* waves.shm *.vcd *.log .simvision *.key