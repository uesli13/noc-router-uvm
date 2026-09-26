class router_base_test extends uvm_test;
    `uvm_component_utils(router_base_test)

    router_env          env;
    router_agent_config master_cfg[5];
    router_agent_config slave_cfg[5];

    time drain_time = 100ns;

    function new(string name = "router_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        env = router_env::type_id::create("env", this);
        configure_agents();
    endfunction

    virtual function void configure_agents();
        for(int i = 0; i < 5; i++) begin
            string down_vif_path    = $sformatf("vif_downstream_%s", PORT_NAMES[i]);
            string up_vif_path      = $sformatf("vif_upstream_%s", PORT_NAMES[i]);
            string master_env_path  = $sformatf("env.master_%s", PORT_NAMES[i]);
            string slave_env_path   = $sformatf("env.slave_%s", PORT_NAMES[i]);

            master_cfg[i] = router_agent_config::type_id::create($sformatf("master_cfg_%s", PORT_NAMES[i]));
            slave_cfg[i]  = router_agent_config::type_id::create($sformatf("slave_cfg_%s", PORT_NAMES[i]));

            master_cfg[i].mode      = MASTER_AGENT;
            master_cfg[i].is_active = UVM_ACTIVE;
            slave_cfg[i].mode       = SLAVE_AGENT;
            slave_cfg[i].is_active  = UVM_ACTIVE;

            // Default flit consumption delay in the slave driver
            slave_cfg[i].min_credit_delay = 1;
            slave_cfg[i].max_credit_delay = 1;

            if(!uvm_config_db#(virtual router_if)::get(this, "", down_vif_path, master_cfg[i].vif))
                `uvm_fatal(get_type_name(), $sformatf("Missing Downstream VIF for %s", PORT_NAMES[i]))

            if(!uvm_config_db#(virtual router_if)::get(this, "", up_vif_path, slave_cfg[i].vif))
                `uvm_fatal(get_type_name(), $sformatf("Missing Upstream VIF for %s", PORT_NAMES[i]))

            uvm_config_db#(router_agent_config)::set(this, master_env_path, "cfg", master_cfg[i]);
            uvm_config_db#(router_agent_config)::set(this, slave_env_path, "cfg", slave_cfg[i]);
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.phase_done.set_drain_time(this, drain_time);

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "Test is running...", UVM_LOW)

        run_stimulus();

        `uvm_info(get_type_name(), "Stimulus finished, draining...", UVM_LOW)
        phase.drop_objection(this);
    endtask

    virtual task run_stimulus();
        `uvm_warning(get_type_name(), "run_stimulus() not overridden: no stimulus was sent")
    endtask

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int err_count;

        super.report_phase(phase);

        svr       = uvm_report_server::get_server();
        err_count = svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL);

        if(err_count == 0)
            `uvm_info(get_type_name(), "** TEST PASSED **", UVM_NONE)
        else
            `uvm_info(get_type_name(), $sformatf("** TEST FAILED ** (%0d errors)", err_count), UVM_NONE)
    endfunction

endclass