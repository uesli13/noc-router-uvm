class router_agent extends uvm_agent;
    `uvm_component_utils(router_agent)
    
    // Components Declaration
    uvm_sequencer #(router_seq_item) sequencer;
    router_master_driver             master_drv;
    router_slave_driver              slave_drv;
    router_monitor                   monitor;

    // Analysis Port for communication with other components
    uvm_analysis_port #(router_seq_item) ap;

    // Configuration object
    router_agent_config cfg;

    function new(string name = "router_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db #(router_agent_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal(get_type_name(), "[NOCFG] Failed to get agent configuration object from config_db")
        end

        // Pass configuration object lower in the hierarchy
        uvm_config_db #(router_agent_config)::set(this, "*", "cfg", cfg);

        // Create the analysis port
        ap = new("ap", this);

        // Always create the monitor
        monitor = router_monitor::type_id::create("monitor", this);

        if(cfg.is_active == UVM_ACTIVE) begin

            // Check agent mode and create the corresponding driver
            if(cfg.mode == MASTER_AGENT) begin
                // Create sequencer
                sequencer = uvm_sequencer #(router_seq_item)::type_id::create("sequencer", this);
                
                // Create master driver
                master_drv = router_master_driver::type_id::create("master_drv", this);
                
                `uvm_info(get_type_name(), "Building Agent in MASTER mode", UVM_LOW)
            end
            else if(cfg.mode == SLAVE_AGENT) begin
                // Create slave driver
                slave_drv = router_slave_driver::type_id::create("slave_drv", this);
                // *No sequencer is needed for the slave driver
                `uvm_info(get_type_name(), "Building Agent in SLAVE mode", UVM_LOW)
            end
            else begin
                `uvm_fatal(get_type_name(), "Unknown Agent Mode! Cannot build driver.")
            end
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect monitor's analysis port with the agent's
        monitor.ap.connect(this.ap);

        if (cfg.is_active == UVM_ACTIVE) begin
            
            // Check agent mode
            if (cfg.mode == MASTER_AGENT) begin
                // Sequencer is connected to the master driver to pass transactions
                master_drv.seq_item_port.connect(sequencer.seq_item_export);
            end
            else if (cfg.mode == SLAVE_AGENT) begin
                // Νο connection is needed for the slave driver
            end
            else begin
                `uvm_fatal(get_type_name(), "Unknown Agent Mode! Cannot connect.")
            end
        end
    endfunction

endclass