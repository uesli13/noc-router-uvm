# ==============================================================================
# Makefile for UVM Verification using Cadence Xcelium (xrun)
# ==============================================================================

TESTNAME  ?= router_sanity_test
VERBOSITY ?= UVM_LOW
SEED      ?= random
GUI       ?= 0
X_CUR ?= 1
Y_CUR ?= 1

# Relative Paths
RTL_DIR   = ../../DUT_Design/RTL
PKG_DIR   = ../../DUT_Design/Packages
IF_DIR    = ../../DUT_Design/Interfaces
VERIF_DIR = ..

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

SRC_PKG   = $(PKG_DIR)/noc_params.sv

SRC_IF    = $(wildcard $(IF_DIR)/*.sv) \
            $(VERIF_DIR)/tb/router_if.sv

SRC_RTL   = $(filter-out $(RTL_DIR)/noc_params.sv, $(wildcard $(RTL_DIR)/*.sv))

SRC_TB    = $(VERIF_DIR)/router_pkg.sv \
            $(VERIF_DIR)/tb/tb_top.sv

ALL_SRCS  = $(SRC_PKG) $(SRC_IF) $(SRC_RTL) $(SRC_TB)

# ------------------------------------------------------------------------------
# Xcelium (xrun) Compilation and Simulation Flags
# ------------------------------------------------------------------------------
XRUN_FLAGS = -64bit -uvm -sv 
XRUN_FLAGS += $(INCDIRS)
XRUN_FLAGS += -timescale 1ns/1ps
XRUN_FLAGS += -access +rwc      
XRUN_FLAGS += -linedebug        
XRUN_FLAGS += -svseed $(SEED)   
XRUN_FLAGS += +UVM_TESTNAME=$(TESTNAME)
XRUN_FLAGS += +UVM_VERBOSITY=$(VERBOSITY)
XRUN_FLAGS += -defparam router_tb_top.TB_X_CURRENT=$(X_CUR)
XRUN_FLAGS += -defparam router_tb_top.TB_Y_CURRENT=$(Y_CUR)
ifeq ($(GUI), 1)
    XRUN_FLAGS += -gui
endif

# ------------------------------------------------------------------------------
# Execution Targets
# ------------------------------------------------------------------------------
run:
	xrun $(XRUN_FLAGS) $(ALL_SRCS)

clean:
	rm -rf INCA_libs xcelium.d xrun.* waves.shm *.vcd *.log .simvision *.key

gui:
	xrun $(XRUN_FLAGS) -gui $(ALL_SRCS) &