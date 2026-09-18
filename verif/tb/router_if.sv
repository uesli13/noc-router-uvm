import noc_params::*;

interface router_if(
    input logic clk,
    input logic rst_n
);

    wire flit_t    data;
    wire logic     is_valid;
    wire credits_t credits;
    wire logic [VC_NUM-1:0] is_allocatable;

    // Clocking BLock for Master Driver
    clocking master_cb @(posedge clk);
        default input #1ns output #1ns;
        input  credits;
        input  is_allocatable;
        output data;
        output is_valid;
    endclocking

    // Clocking BLock for Slave Driver
    clocking slave_cb @(posedge clk);
        default input #1ns output #1ns;
        input  data;
        input  is_valid;
        output credits;
        output is_allocatable;
    endclocking

    // Clocking Block for monitor
    clocking mon_cb @(posedge clk);
        default input #1ns output #1ns;
        input data;
        input is_valid;
        input credits;
        input is_allocatable;
    endclocking

    // Master Modport
    modport master_mp (
        clocking master_cb,
        input    clk,
        input    rst_n
    );

    // Slave Modport
    modport slave_mp (
        clocking slave_cb,
        input    clk,
        input    rst_n
    );

    modport monitor_mp(
        clocking mon_cb,
        input    clk,
        input    rst_n
    );

endinterface
