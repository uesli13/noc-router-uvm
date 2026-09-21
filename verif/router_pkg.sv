package router_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import noc_params::*;
    import noc_params::BODY;   // BODY also exists in uvm_pkg; use the flit label

    typedef enum {MASTER_AGENT, SLAVE_AGENT} agent_mode_e;
    string PORT_NAMES[5] = '{"LOCAL", "NORTH", "SOUTH", "WEST", "EAST"};

    `include "router_agent_config.sv"
    `include "router_seq_item.sv"
    `include "router_sanity_seq.sv"
    `include "router_monitor.sv"
    `include "router_master_driver.sv"
    `include "router_slave_driver.sv"
    `include "router_agent.sv"
    `include "router_env.sv"
    `include "router_sanity_test.sv"
endpackage