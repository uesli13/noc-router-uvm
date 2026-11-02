class router_contention_test extends router_base_test;
    `uvm_component_utils(router_contention_test)

    port_t src_port_1 = LOCAL;
    port_t src_port_2 = SOUTH;

    function new(string name = "router_contention_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drain_time = 300ns;
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

        router_multi_packet_seq seq_1 = router_multi_packet_seq::type_id::create("seq_1");
        router_multi_packet_seq seq_2 = router_multi_packet_seq::type_id::create("seq_2");
        
        if(src_port_1 == src_port_2)
            `uvm_fatal(get_type_name(), "Two sources can't be at the same port")

        seq_1.len      = pkt_len;
        seq_1.vc       = pkt_vc;
        seq_1.xd       = x_dest;
        seq_1.yd       = y_dest;

        seq_2.len      = pkt_len;
        seq_2.vc       = pkt_vc;
        seq_2.xd       = x_dest;
        seq_2.yd       = y_dest;

        if (!seq_1.randomize() with { (local::num_pkts > 0) -> num_packets == local::num_pkts; })
            `uvm_fatal(get_type_name(), "Randomization of seq_1 failed for stimulus sequence")
        
        if (!seq_2.randomize() with { (local::num_pkts > 0) -> num_packets == local::num_pkts; })
            `uvm_fatal(get_type_name(), "Randomization of seq_2 failed for stimulus sequence")

        `uvm_info(get_type_name(), $sformatf("Stimulus: src=%s npkt=%0d len=%0d vc=%0d dest=(%0d,%0d)  [-1 = random]",
                  src_port_1.name(), seq_1.num_packets, pkt_len, pkt_vc, x_dest, y_dest), UVM_LOW)
        
        `uvm_info(get_type_name(), $sformatf("Stimulus: src=%s npkt=%0d len=%0d vc=%0d dest=(%0d,%0d)  [-1 = random]",
                  src_port_2.name(), seq_2.num_packets, pkt_len, pkt_vc, x_dest, y_dest), UVM_LOW)
        

        fork
            seq_1.start(env.master_agents[src_port_1].sequencer);
            seq_2.start(env.master_agents[src_port_2].sequencer);
        join

    endtask

endclass