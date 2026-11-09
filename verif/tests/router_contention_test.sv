class router_contention_test extends router_base_test;
    `uvm_component_utils(router_contention_test)

    port_t src_port_1 = LOCAL;
    port_t src_port_2 = SOUTH;

    function new(string name = "router_contention_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void set_default_knobs();
        // src_port not defined here, but by the test variables
        num_pkts = 1;
        pkt_len  = 4;
        pkt_vc   = ESCAPE;
        x_dest   = 0;
        y_dest   = 1;
    endfunction

    virtual task run_stimulus();
        if(src_port_1 == src_port_2)
            `uvm_fatal(get_type_name(), "Two sources can't be at the same port")

        fork
            send_packets("seq_1", src_port_1, num_pkts, pkt_len, pkt_vc, x_dest, y_dest);
            send_packets("seq_2", src_port_2, num_pkts, pkt_len, pkt_vc, x_dest, y_dest);
        join
    endtask

endclass