import noc_params::*;

class router_master_driver extends uvm_driver #(router_seq_item);
    `uvm_component_utils(router_master_driver)

    router_agent_config cfg;
    virtual router_if vif;

    int vc_credits [VC_NUM];            // Internal counter of available space in DUT's VCs
    bit [VC_NUM-1:0] is_vc_allocatable; // Keeps track of "allocatability" in DUT's VCs
    vc_class_t       active_vc_id;      // Remembers the VC type of the active packet even if it changes in the midway
                                        // **active packet is the packet that has been received from the
                                        //   sequencer and is about to be sent to the DUT 

    bit    req_pending;   // Tells if there's an ongoing transaction at the moment
    bit    ready_to_send; // Tells if there are available VCs in the DUT to receive the current flit
    flit_t current_flit;  // Holds the transaction's flit

    function new(string name = "router_master_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(router_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal(get_type_name(), "[NOCFG] Failed to get agent configuration object from config_db")

        vif = cfg.vif;
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin

            // Wait until the reset signal unsets
            wait(vif.rst_n === 1'b1);

            // Reset virtual interface variables and internal counters
            reset_driver_state();

            fork
                drive_loop();
                wait(!vif.rst_n);
            join_any // Exit block when one thread ends

            // Kill all threads
            // (obviously only the drive_loop() is active, since the and of wait() got the program out of the fork block)
            disable fork;

            // If there was an active transaction that got interupted, notify the sequencer
            if(req_pending) begin
                seq_item_port.item_done();
                req_pending = 0;
            end
        end
    endtask

     // Reset virtual interface variables and internal counters
    task reset_driver_state();
        vif.master_cb.data     <= '0;
        vif.master_cb.is_valid <= 1'b0;

        for(int i = 0; i < VC_NUM; i++) begin
            vc_credits[i] = VC_DEPTH;
        end
    
        is_vc_allocatable = {VC_NUM{1'b1}};
        req_pending   = 0;
        ready_to_send = 0;
    endtask
    
    //
    task drive_loop();
        forever begin
            @(vif.master_cb);

            // Update internal signals according to intputs
            update_flow_control();

            // Get new flit only if there isn't already one 
            if(!req_pending) begin
                seq_item_port.try_next_item(req); // Non-blocking
                if(req != null) begin
                    req_pending = 1'b1;
                    current_flit = req.to_struct();
                end
            end

            if(req_pending) begin
                ready_to_send = check_and_assign_vc(current_flit);

                if(ready_to_send) begin
                    //Send the flit
                    vif.master_cb.is_valid <= 1'b1;
                    vif.master_cb.data     <= current_flit;
                    `uvm_info(get_type_name(), $sformatf("Driving Flit to DUT:\n%s", req.sprint()), UVM_LOW)

                    // Update counters
                    vc_credits[current_flit.vc_id]--;

                    if(current_flit.flit_label == HEAD || current_flit.flit_label == HEADTAIL) begin
                        is_vc_allocatable[current_flit.vc_id] = 1'b0;
                        active_vc_id = vc_class_t'(current_flit.vc_id);
                    end

                    //Check for underflow
                    if(vc_credits[current_flit.vc_id] <0) begin
                        `uvm_error(get_type_name(), $sformatf("[CRED_UNF] Credit underflow in VC %0d!", current_flit.vc_id))
                    end

                    seq_item_port.item_done();
                    req_pending = 0;
                end 
                else begin
                    // There is a flit to send but no VCs available
                    vif.master_cb.is_valid <= 1'b0;
                end
            end
            else begin
                // There's no flit to send
                vif.master_cb.is_valid <= 1'b0;
            end
        end // end forever
    endtask

    // Helper function that checks if there are available VCs to receive the given flit
    function bit check_and_assign_vc(ref flit_t f);
        if(f.flit_label == HEAD || f.flit_label == HEADTAIL) begin
            if((f.vc_id == ADAPTIVE && vc_credits[ADAPTIVE] > 0 && is_vc_allocatable[ADAPTIVE]) ||
               (f.vc_id == ESCAPE   && vc_credits[ESCAPE]   > 0 && is_vc_allocatable[ESCAPE])) begin
                return 1'b1;
            end
            else if(f.vc_id == ADAPTIVE && vc_credits[ESCAPE] > 0 && is_vc_allocatable[ESCAPE]) begin
                f.vc_id = ESCAPE;
                return 1'b1;
            end
        end
        else begin
            f.vc_id = active_vc_id;
            if(vc_credits[f.vc_id] > 0) begin
                return 1'b1;
            end
        end

        // If there are no credits or no available VC is allocatable, can't send flit
        return 1'b0;
    endfunction

    // Helper function that updates flow control variables based on DUT signals
    function void update_flow_control();
        for(int i = 0; i < VC_NUM; i++) begin
            // Update credit counters
            if(vif.master_cb.credits[i]) begin
                vc_credits[i]++;

                // Check for overflow
                if(vc_credits[i] > VC_DEPTH) begin
                    `uvm_error(get_type_name(), $sformatf("[CRED_OVF] Credit overflow in VC %0d!", i))
                end
            end

            // Update allocatability
            if(vif.master_cb.is_allocatable[i]) begin
                is_vc_allocatable[i] = 1'b1;
            end
        end
    endfunction
endclass