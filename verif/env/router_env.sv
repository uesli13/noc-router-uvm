class router_env extends uvm_env;
    `uvm_component_utils(router_env)

    // Index mapping: 0=LOCAL, 1=NORTH, 2=SOUTH, 3=WEST, 4=EAST
    router_agent master_agents[5];
    router_agent slave_agents[5];

    function new(string name = "router_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        `uvm_info(get_type_name(), "Building 5 Master and 5 Slave agents", UVM_LOW)

        for(int i = 0; i<5; i++) begin
            string master_name = $sformatf("master_agent_%0d", i);
            string slave_name  = $sformatf("slave_agent_%0d", i);

            master_agents[i] =  router_agent::type_id::create(master_name, this);
            slave_agents[i]  =  router_agent::type_id::create(slave_name, this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction
endclass