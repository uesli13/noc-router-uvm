class router_slave_driver extends uvm_driver;
    `uvm_component_utils(router_slave_driver)

    router_agent_config cfg;
    virtual router_if   vif;

    int pending_credits[2];     // Counts the number of credits that need to be sent to DUT
    bit pending_allocatable[2]; // Knows if TAIL or HEADTAIL flit is passed, to drive the is_allocatable signal

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
        vif.credits         = 2'b00;
        vif.is_allocatable  = 2'b00;
        pending_credits     = '{0, 0};
        pending_allocatable = '{0, 0};
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
                
                if (f.flit_label == TAIL || f.flit_label == HEADTAIL) begin
                    // If TAIL or HEADTAIL is received, is_allocatable needs to be rose
                    pending_allocatable[f.vc_id] = 1'b1;
                end
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
                
                // Choose random cycles delay using config
                int delay = $urandom_range(cfg.min_credit_delay, cfg.max_credit_delay);
                
                // Simulate delay of sending a flit
                repeat(delay) @(vif.slave_cb);

                // Send a credit
                vif.slave_cb.credits[vc_id] <= 1'b1;

                // Decrease credit counter
                pending_credits[int'(vc_id)]--;

                // If last flit sent was end of a packet, then the VC is allocatable again
                if (pending_credits[int'(vc_id)] == 0 && pending_allocatable[vc_id] == 1'b1) begin
                    vif.slave_cb.is_allocatable[vc_id] <= 1'b1;
                    pending_allocatable[vc_id] = 1'b0;
                end
            end
        end
    endtask
endclass