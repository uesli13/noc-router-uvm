class router_multi_packet_test extends router_base_test;
    `uvm_component_utils(router_multi_packet_test)

    function new(string name = "router_multi_packet_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drain_time = 300ns; // several packets wait for VC reallocation inside the DUT
    endfunction

    // 3 packets of 4 flits, ESCAPE, LOCAL -> (0,1)
    virtual function void set_default_knobs();
        src_port = LOCAL;
        num_pkts = 3;
        pkt_len  = 4;
        pkt_vc   = ESCAPE;
        x_dest   = 0;
        y_dest   = 1;
    endfunction

endclass
