class router_multi_packet_test extends router_base_test;
    `uvm_component_utils(router_multi_packet_test)

    function new(string name = "router_multi_packet_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drain_time = 300ns; // several packets wait for VC reallocation inside the DUT
    endfunction

    virtual task run_stimulus();
        router_multi_packet_seq multi_seq = router_multi_packet_seq::type_id::create("multi_seq");

        // Deterministic run: 3 packets of 4 flits, ESCAPE, from LOCAL to (0,1) -> WEST
        multi_seq.use_fixed    = 1;
        multi_seq.fixed_len    = 4;
        multi_seq.fixed_vc     = ESCAPE;
        multi_seq.fixed_x_dest = 0;
        multi_seq.fixed_y_dest = 1;

        if(!multi_seq.randomize() with { num_packets == 3; })
            `uvm_fatal(get_type_name(), "Randomization failed for multi-packet sequence")

        multi_seq.start(env.master_agents[0].sequencer); // LOCAL
    endtask

endclass