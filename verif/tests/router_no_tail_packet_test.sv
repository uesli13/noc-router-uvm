class router_no_tail_packet_test extends router_base_test;
    `uvm_component_utils(router_no_tail_packet_test)

    function new(string name = "router_no_tail_packet_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        router_packet_seq::type_id::set_type_override(router_no_tail_packet_seq::get_type());

        master_cfg[src_port].ignore_allocatable = 1; 

    endfunction

    virtual function void set_default_knobs();
        src_port = LOCAL;
        num_pkts = 2;
        pkt_len  = 2;
        pkt_vc   = ESCAPE;
        x_dest   = 0;
        y_dest   = 1;
    endfunction

endclass