class router_slave_driver extends uvm_driver;
    `uvm_component_utils(router_slave_driver)

    router_agent_config cfg;
    virtual router_if   vif;

    int pending_credits[2];     // Counts the number of credits that need to be sent to DUT
    bit pending_allocatable[2]; // Knows if TAIL or HEADTAIL flit is passed, to drive the is_allocatable signal
    bit pending_head[2];        // Tells if HEAD or HEADTAIL flit is received and its packet delay is not applied yet

    // End-of-test mechanism
    uvm_phase run_ph;     // Run phase handle (for raise/drop objections)
    bit       obj_raised; // 1 while the driver holds its objection

    function new(string name = "router_slave_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(router_agent_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal(get_type_name(), "[NOCFG] Failed to get agent configuration object from config_db")
        end

        vif = cfg.vif;
    endfunction

    virtual task run_phase(uvm_phase phase);
        run_ph = phase; // Extract the handle of the phase

        forever begin
            // Reset virtual interface variables and internal signals
            reset_driver_state();

            // Wait until the reset signal unsets
            wait(vif.rst_n === 1'b1);

            // Parallel run
            fork
                monitor_incoming_flits();        // Listens DUT's incoming signals
                drive_vc_flow_control(ESCAPE);   // Drives output signals for ESCAPE VC
                drive_vc_flow_control(ADAPTIVE); // Drives output signals for ADAPTIVE VC
                wait(vif.rst_n === 1'b0);        // Waits for reset signals, so it stops the other threads
            join_any

            disable fork;
        end
    endtask

     // Reset virtual interface variables and internal signals
    task reset_driver_state();
        vif.slave_cb.credits         <= 2'b00;
        vif.slave_cb.is_allocatable  <= 2'b00;
        pending_credits     = '{0, 0};
        pending_allocatable = '{0, 0};
        pending_head        = '{0, 0};
        slv_obj_drop();
    endtask

    // Listens to the incoming signals and updates the internal counters when new flit is received
    virtual task monitor_incoming_flits();
        forever begin
            @(posedge vif.clk);
            
            // Check if there's a new incoming flit
            if (vif.is_valid === 1'b1) begin
                flit_t f = vif.data;
                
                // Increase the credits counter
                pending_credits[int'(f.vc_id)]++;

                if (f.flit_label == HEAD || f.flit_label == HEADTAIL) begin
                    // New packet, so the packet delay has to be applied before its first credit
                    pending_head[f.vc_id] = 1'b1;
                end
                
                if (f.flit_label == TAIL || f.flit_label == HEADTAIL) begin
                    // If TAIL or HEADTAIL is received, is_allocatable needs to be rose
                    pending_allocatable[f.vc_id] = 1'b1;
                end

                slv_obj_raise(); // objection should raise when driver "owes" control signal
            end
        end
    endtask

    // Drive output flits signals related to a VC, according to the internal counters
    virtual task drive_vc_flow_control(vc_class_t vc_id);
        forever begin
            @(vif.slave_cb);
            
            // Default values for output signals
            vif.slave_cb.credits[vc_id]        <= 1'b0;
            vif.slave_cb.is_allocatable[vc_id] <= 1'b0;

            // Check if credits need to be sent
            if (pending_credits[int'(vc_id)] > 0) begin
                
                // Per-flit delay: applied before every credit
                int delay = $urandom_range(cfg.min_flit_delay[vc_id], cfg.max_flit_delay[vc_id]);

                // Per-packet delay: applied once, before the first credit of a packet
                if (pending_head[vc_id]) begin
                    delay += $urandom_range(cfg.min_credit_delay[vc_id], cfg.max_credit_delay[vc_id]);
                    pending_head[vc_id] = 1'b0;
                end

                // Simulate delay of consuming a flit
                repeat(delay) @(vif.slave_cb);

                // Send a credit
                vif.slave_cb.credits[vc_id] <= 1'b1;
                `uvm_info(get_type_name(), $sformatf("Returning 1 Credit to VC %s", vc_id.name()), UVM_LOW)

                // Decrease credit counter
                pending_credits[int'(vc_id)]--;

                // If last flit sent was end of a packet, then the VC is allocatable again
                if (pending_credits[int'(vc_id)] == 0 && pending_allocatable[vc_id] == 1'b1) begin
                    vif.slave_cb.is_allocatable[vc_id] <= 1'b1;
                    `uvm_info(get_type_name(), $sformatf("Asserting is_allocatable for VC %s", vc_id.name()), UVM_LOW)
                    pending_allocatable[vc_id] = 1'b0;
                end

                slv_obj_drop(); // if driver owes nothing drop objection
            end
        end
    endtask

    function bit nothing_pending();
        foreach (pending_credits[i])
            if (pending_credits[i] != 0 || pending_allocatable[i] == 1'b1)
                return 0;
        return 1;
    endfunction

    function void slv_obj_raise();
        if (obj_raised) return;
        run_ph.raise_objection(this, "SLV: credits owed to DUT");
        obj_raised = 1;
    endfunction

    function void slv_obj_drop();
        if (!obj_raised || !nothing_pending()) return;
        run_ph.drop_objection(this, "SLV: all credits returned");
        obj_raised = 0;
    endfunction
endclass