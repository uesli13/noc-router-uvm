class router_sanity_test extends router_base_test;
    `uvm_component_utils(router_sanity_test)

    function new(string name = "router_sanity_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_stimulus();
        router_sanity_seq sanity_seq = router_sanity_seq::type_id::create("sanity_seq");
        sanity_seq.start(env.master_agents[0].sequencer); // LOCAL
    endtask

endclass