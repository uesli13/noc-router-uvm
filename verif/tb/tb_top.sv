`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import noc_params::*;
import router_pkg::*;

module tb_top #(
    parameter TB_X_CURRENT = 1,
    parameter TB_Y_CURRENT = 1
);

    logic clk;
    logic rst_n;
    
    // Router module uses active high reset
    logic rst;
    assign rst = ~rst_n;

    // Clock Generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Reset Generation
    initial begin
        rst_n = 1'b0;
        #25;
        rst_n = 1'b1;
    end

    // Create interfaces for each port and direction
    router_if vif_downstream_LOCAL (clk, rst_n);
    router_if vif_downstream_NORTH (clk, rst_n);
    router_if vif_downstream_SOUTH (clk, rst_n);
    router_if vif_downstream_WEST  (clk, rst_n);
    router_if vif_downstream_EAST  (clk, rst_n);

    router_if vif_upstream_LOCAL   (clk, rst_n);
    router_if vif_upstream_NORTH   (clk, rst_n);
    router_if vif_upstream_SOUTH   (clk, rst_n);
    router_if vif_upstream_WEST    (clk, rst_n);
    router_if vif_upstream_EAST    (clk, rst_n);

    // RTL Interfaces
    router2router r2r_downstream_LOCAL ();
    router2router r2r_downstream_NORTH ();
    router2router r2r_downstream_SOUTH ();
    router2router r2r_downstream_WEST  ();
    router2router r2r_downstream_EAST  ();

    router2router r2r_upstream_LOCAL ();
    router2router r2r_upstream_NORTH ();
    router2router r2r_upstream_SOUTH ();
    router2router r2r_upstream_WEST  ();
    router2router r2r_upstream_EAST  ();
    
    // Define macros to bind the virtual interfaces to the RTL interfaces
    `define BIND_DOWNSTREAM(TB, RTL) \
        assign RTL.data = TB.data; \
        assign RTL.is_valid = TB.is_valid; \
        assign TB.credits = RTL.credits; \
        assign TB.is_allocatable = RTL.is_allocatable;

    `define BIND_UPSTREAM(TB, RTL) \
        assign TB.data = RTL.data; \
        assign TB.is_valid = RTL.is_valid; \
        assign RTL.credits = TB.credits; \
        assign RTL.is_allocatable = TB.is_allocatable;

    // Wiring the interfaces together
    `BIND_DOWNSTREAM(vif_downstream_LOCAL, r2r_downstream_LOCAL)
    `BIND_DOWNSTREAM(vif_downstream_NORTH, r2r_downstream_NORTH)
    `BIND_DOWNSTREAM(vif_downstream_SOUTH, r2r_downstream_SOUTH)
    `BIND_DOWNSTREAM(vif_downstream_WEST,  r2r_downstream_WEST)
    `BIND_DOWNSTREAM(vif_downstream_EAST,  r2r_downstream_EAST)

    `BIND_UPSTREAM(vif_upstream_LOCAL, r2r_upstream_LOCAL)
    `BIND_UPSTREAM(vif_upstream_NORTH, r2r_upstream_NORTH)
    `BIND_UPSTREAM(vif_upstream_SOUTH, r2r_upstream_SOUTH)
    `BIND_UPSTREAM(vif_upstream_WEST,  r2r_upstream_WEST)
    `BIND_UPSTREAM(vif_upstream_EAST,  r2r_upstream_EAST)

    // Error output from the DUT
    logic [VC_NUM-1:0] error_o [PORT_NUM-1:0];

    // DUT Instantiation
    router #(
        .BUFFER_SIZE(VC_DEPTH),
        .X_CURRENT(TB_X_CURRENT),
        .Y_CURRENT(TB_Y_CURRENT)
    ) dut (
        .clk(clk),
        .rst(rst),
        
        // Upstream
        .router_if_local_up (r2r_upstream_LOCAL),
        .router_if_north_up (r2r_upstream_NORTH),
        .router_if_south_up (r2r_upstream_SOUTH),
        .router_if_west_up  (r2r_upstream_WEST),
        .router_if_east_up  (r2r_upstream_EAST),

        // Downstream
        .router_if_local_down (r2r_downstream_LOCAL),
        .router_if_north_down (r2r_downstream_NORTH),
        .router_if_south_down (r2r_downstream_SOUTH),
        .router_if_west_down  (r2r_downstream_WEST),
        .router_if_east_down  (r2r_downstream_EAST),
        
        .error_o(error_o)
    );

    initial begin
        // Set the virtual interfaces in the UVM configuration database
        
        // Master Interfaces
        uvm_config_db#(virtual router_if)::set(null, "*", "vif_downstream_LOCAL", vif_downstream_LOCAL);
        uvm_config_db#(virtual router_if)::set(null, "*", "vif_downstream_NORTH", vif_downstream_NORTH);
        uvm_config_db#(virtual router_if)::set(null, "*", "vif_downstream_SOUTH", vif_downstream_SOUTH);
        uvm_config_db#(virtual router_if)::set(null, "*", "vif_downstream_WEST",  vif_downstream_WEST);
        uvm_config_db#(virtual router_if)::set(null, "*", "vif_downstream_EAST",  vif_downstream_EAST);

        // Slave Interfaces
        uvm_config_db#(virtual router_if)::set(null, "*", "vif_upstream_LOCAL", vif_upstream_LOCAL);
        uvm_config_db#(virtual router_if)::set(null, "*", "vif_upstream_NORTH", vif_upstream_NORTH);
        uvm_config_db#(virtual router_if)::set(null, "*", "vif_upstream_SOUTH", vif_upstream_SOUTH);
        uvm_config_db#(virtual router_if)::set(null, "*", "vif_upstream_WEST",  vif_upstream_WEST);
        uvm_config_db#(virtual router_if)::set(null, "*", "vif_upstream_EAST",  vif_upstream_EAST);
        
        // Set Router Current location variables in the UVM configuration database
        uvm_config_db#(int)::set(null, "*", "DUT_X_CUR", TB_X_CURRENT);
        uvm_config_db#(int)::set(null, "*", "DUT_Y_CUR", TB_Y_CURRENT);

        run_test("router_sanity_test");
    end

    // Create waveform
    initial begin
        $dumpfile("router_dump.vcd");
        $dumpvars(0, tb_top);
    end

endmodule