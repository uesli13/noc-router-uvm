class router_agent_config extends uvm_object;
    `uvm_object_utils(router_agent_config)
    
    virtual router_if vif;

    // Declares agent as MASTER or SLAVE 
    agent_mode_e mode = MASTER_AGENT;
    
    // Declares agent as ACTIVE or PASSIVE
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // The DUTs' port the agent is connected to 
    port_t port_id;

    //// Slave Driver Control Knobs ////
    
    // How many cycles delay before sending a credit
    int min_credit_delay = 0;
    int max_credit_delay = 0;

    //// Master Driver Control Knobs ////

    bit ignore_allocatable = 0; // if true, master driver sends head flit without minding allocatability (for illegal stimulus)

    function new(string name = "router_agent_config");
        super.new(name);
    endfunction

endclass