class router_monitor extends uvm_monitor;
    `uvm_component_utils(router_monitor)

    uvm_analysis_port #(router_seq_item) ap; // The port from where monitor sends transactions to other components
    router_agent_config cfg;
    virtual router_if   vif;

    function new(string name = "router_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db #(router_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal(get_type_name(), "[NOCFG] Failed to get agent configuration object from config_db")
        
        vif = cfg.vif;
        
        ap  = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        router_seq_item req; // Hold the captured flit
        forever begin
            // Operates on every clock edge
            @(vif.mon_cb);

            if(!vif.rst_n) begin
                continue; // If there's an active reset, monitor does nothing 
            end

            // Check if flit is sent using control signal "is_valid"
            if(vif.mon_cb.is_valid === 1'b1) begin
                req = router_seq_item::type_id::create("req"); // Create sequence item for the taken flit
                req.from_struct(vif.mon_cb.data);              // Convert flit from struct to transaction type
                ap.write(req);                                 // Send the transaction to the analysis port
                `uvm_info(get_type_name(), $sformatf("Captured Flit:\n%s", req.sprint()), UVM_LOW)
            end
        end
    endtask
endclass