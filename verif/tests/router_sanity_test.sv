class router_sanity_test extends uvm_test;
    `uvm_component_utils(router_sanity_test)

    router_env          env;
    // router_agent_config agent_cfg;
    
    function new(string name = "router_sanity_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        env = router_env::type_id::create("env", this);
        configure_agents();
    endfunction
    
    virtual function void configure_agents();
        router_agent_config master_cfg[5];
        router_agent_config slave_cfg[5];

        string port_names[5] = '{"LOCAL", "NORTH", "SOUTH", "WEST", "EAST"};

        for(int i = 0; i < 5; i++) begin
            string master_name = $sformatf("master_cfg_%0d", i);
            string slave_name  = $sformatf("slave_cfg_%0d", i);

            string down_vif_path    = $sformatf("vif_downstream_%s", port_names[i]);
            string up_vif_path      = $sformatf("vif_upstream_%s", port_names[i]);

            string master_env_path  = $sformatf("env.master_agents[%0d]*", i);
            string slave_env_path   = $sformatf("env.slave_agents[%0d]*", i);

            master_cfg[i] = router_agent_config::type_id::create(master_name, this);
            slave_cfg[i] = router_agent_config::type_id::create(slave_name, this);

            master_cfg[i].mode      = MASTER_AGENT;
            master_cfg[i].is_active = UVM_ACTIVE;
            slave_cfg[i].mode       = SLAVE_AGENT;
            slave_cfg[i].is_active  =UVM_ACTIVE;

            if (!uvm_config_db#(virtual router_if)::get(this, "", down_vif_path, master_cfg[i].vif))
                `uvm_fatal(get_type_name(), $sformatf("Missing Downstream VIF for %s", port_names[i]))

            if (!uvm_config_db#(virtual router_if)::get(this, "", up_vif_path, slave_cfg[i].vif))
                `uvm_fatal(get_type_name(), $sformatf("Missing Upstream VIF for %s", port_names[i]))

            uvm_config_db#(router_agent_config)::set(this, master_env_path, "cfg", master_cfg[i]);
            uvm_config_db#(router_agent_config)::set(this, slave_env_path, "cfg", slave_cfg[i]);
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        router_sanity_seq sanity_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "Sanity Test is running...", UVM_LOW)

        sanity_seq = router_sanity_seq::type_id::create("sanity_seq");
        sanity_seq.start(env.master_agents[0].sequencer);
        #100ns

        `uvm_info(get_type_name(), "Sanity Test finished", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass