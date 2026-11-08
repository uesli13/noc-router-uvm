`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import noc_params::*;

module router_error_sva(
    input logic clk,
    input logic rst_n,
    input logic [VC_NUM-1:0] error_o [PORT_NUM-1:0]
);

    function automatic string port_name(int p);
        port_t t = port_t'(p);
        return t.name();
    endfunction
 
    function automatic string vc_name(int v);
        vc_class_t t = vc_class_t'(v);
        return t.name();
    endfunction
    
    for (genvar port = 0; port < PORT_NUM; port++) begin : g_port
        for (genvar vc = 0; vc < VC_NUM; vc++) begin : g_vc
            
            a_no_error: assert property (
                @(posedge clk) disable iff (!rst_n)
                !$rose(error_o[port][vc])
            )
            else `uvm_error("DUT_ERROR_O", $sformatf(
                "error_o raised at input %s / VC %s",
                port_name(port), vc_name(vc)))
        end
    end

endmodule