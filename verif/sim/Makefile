# ==============================================================================
# Makefile for UVM Verification using Cadence Xcelium (xrun)
# ==============================================================================

TESTNAME  ?= router_sanity_test
VERBOSITY ?= UVM_LOW
SEED      ?= random
GUI       ?= 0
WAVE_SCRIPT ?= ../waves/router_sim.tcl
GUI_FLAGS    = -gui -input $(WAVE_SCRIPT)
X_CUR ?= 1
Y_CUR ?= 1
MUT ?=
PLUSARGS ?=
LOG ?= xrun.log

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
            $(VERIF_DIR)/tb/router_error_sva.sv \
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
XRUN_FLAGS += -defparam tb_top.TB_X_CURRENT=$(X_CUR)
XRUN_FLAGS += -defparam tb_top.TB_Y_CURRENT=$(Y_CUR)
XRUN_FLAGS += -l $(LOG)

ifeq ($(GUI), 1)
    XRUN_FLAGS += $(GUI_FLAGS)
endif


KNOWN_MUTS = MUT_SB_DATA MUT_SB_LEFTOVER MUT_SB_VC MUT_SB_ROUTE_XY MUT_SB_ROUTE_MIN MUT_SB_OUT_NO_HEAD MUT_SB_NOMATCH MUT_SB_EXTRA MUT_SB_INTERLEAVE

ifneq ($(MUT),)
    ifeq ($(filter $(MUT),$(KNOWN_MUTS)),)
        $(error Unknown mutation '$(MUT)'. Known: $(KNOWN_MUTS))
    endif
    XRUN_FLAGS += +define+$(MUT)
endif


XRUN_FLAGS += $(PLUSARGS)

# ------------------------------------------------------------------------------
# Regression
# ------------------------------------------------------------------------------

# Tests that must pass
REGRESS_TESTS = router_sanity_test \
                router_packet_test \
                router_multi_packet_test \
                router_contention_test \
				router_vc_demotion_test

# Tests that fail on purpose for now (illegal stimulus, fail on purpose)
EXPECT_FAIL   = router_no_head_packet_test \
                router_no_tail_packet_test

LOG_DIR = logs

# ------------------------------------------------------------------------------
# Execution Targets
# ------------------------------------------------------------------------------

.PHONY: run gui clean regress

run:
	xrun $(XRUN_FLAGS) $(ALL_SRCS)

# Run every test with its own log in $(LOG_DIR), then print one line per test
regress:
	@mkdir -p $(LOG_DIR)
	@for t in $(REGRESS_TESTS) $(EXPECT_FAIL); do \
	    echo "Running $$t ..."; \
		$(MAKE) --no-print-directory run TESTNAME=$$t LOG=$(LOG_DIR)/$$t.log > /dev/null 2>&1 || true; \
	done
	@echo ""
	@echo "==================== Regression summary ===================="
	@for t in $(REGRESS_TESTS) $(EXPECT_FAIL); do \
	    f=$(LOG_DIR)/$$t.log; \
	    if   grep -q "TEST PASSED" $$f; then r="PASSED"; \
	    elif grep -q "TEST FAILED" $$f; then r="FAILED"; \
	    else r="NO RESULT (check the log)"; fi; \
	    case " $(EXPECT_FAIL) " in *" $$t "*) r="$$r   [expected: FAILED]";; esac; \
	    printf "  %-32s %s\n" $$t "$$r"; \
	done
	@echo "============================================================"
	@echo "Logs in $(LOG_DIR)/"

clean:
	rm -rf INCA_libs xcelium.d xrun.* waves.shm *.vcd *.log .simvision *.key $(LOG_DIR)

gui:
	xrun $(XRUN_FLAGS) $(GUI_FLAGS) $(ALL_SRCS) &