class router_packet_test extends router_base_test;
    `uvm_component_utils(router_packet_test)

    function new(string name = "router_packet_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drain_time = 200ns; // multi-flit packets need more time to leave the DUT
    endfunction

    virtual task run_stimulus();
        router_packet_seq pkt_seq = router_packet_seq::type_id::create("pkt_seq");

        if(!pkt_seq.randomize()with{
            pkt_len    == 4;
            pkt_vc     == ESCAPE;
            pkt_x_dest == 0;
            pkt_y_dest == 1;
        })
            `uvm_fatal(get_type_name(), "Randomization failed for packet sequence")

        pkt_seq.start(env.master_agents[0].sequencer); // LOCAL
    endtask

endclass