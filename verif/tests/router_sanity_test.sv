class router_sanity_test extends router_base_test;
    `uvm_component_utils(router_sanity_test)

    function new(string name = "router_sanity_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // One HEADTAIL flit, ADAPTIVE, LOCAL -> (0,0)
    virtual function void set_default_knobs();
        src_port = LOCAL;
        num_pkts = 1;
        pkt_len  = 1;
        pkt_vc   = ADAPTIVE;
        x_dest   = 0;
        y_dest   = 0;
    endfunction

endclass