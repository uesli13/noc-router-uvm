class router_vc_demotion_test extends router_base_test;
    `uvm_component_utils(router_vc_demotion_test)

    // Scenario for DUT at (1,1) and target (0,0):
    // minimal ports are WEST and SOUTH

    port_t blocked_ports[2] = '{WEST, SOUTH};
    int    hold_cycles; // ADAPTIVE credit delay on the blocked ports

    function new(string name = "router_vc_demotion_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void set_default_knobs();
        num_pkts = 3;
        pkt_len  = -1;       // Random length
        pkt_vc   = ADAPTIVE;
        x_dest   = 0;
        y_dest   = 0;
    endfunction

    // Slow ADAPTIVE credits on both minimal ports; ESCAPE keeps the default delay
    virtual function void configure_agents();
        super.configure_agents();

        // The ADAPTIVE VCs must stay held until the last target has left the DUT.
        hold_cycles = 100 + 50 * num_pkts;

        // Preloads are held for hold_cycles and then drained. The whole run must fit the global timeout
        if (2 * hold_cycles * CLK_PERIOD > global_timeout)
            `uvm_fatal(get_type_name(), $sformatf("%0d targets need ~%0t, more than the global timeout. Raise +TIMEOUT_NS",
                    num_pkts, 2 * hold_cycles * CLK_PERIOD))

        foreach (blocked_ports[i]) begin
            slave_cfg[blocked_ports[i]].min_credit_delay[ADAPTIVE] = hold_cycles;
            slave_cfg[blocked_ports[i]].max_credit_delay[ADAPTIVE] = hold_cycles;
        end
    endfunction

    virtual task run_stimulus();
        if (num_pkts < 1)
            `uvm_fatal(get_type_name(), "Demotion test needs at least one target packet")

        // Preload slave Agents
        fork
            send_packets("preload_WEST",  EAST,  1, 1, ADAPTIVE, 0, 1); // Send packet to WEST slave
            send_packets("preload_SOUTH", NORTH, 1, 1, ADAPTIVE, 1, 0); // Send packet to SOUTH slave

        join

        // // Wait for slave agents to receive the packets in their ADAPTIVE VCs
        // If the DUT demotes a preload instead (ADAPTIVE VC was free), stop with fatal
        fork begin
            fork
                foreach (blocked_ports[i])
                    wait (env.slave_agents[blocked_ports[i]].slave_drv.pending_allocatable[ADAPTIVE]);
                begin
                    wait (env.sb.n_demoted > 0);
                    `uvm_fatal("DEMOTION_PRELOAD",
                        "DUT demoted a preload packet although its ADAPTIVE VC was free")
                end
            join_any
            disable fork;
        end join        

        // Send target packets
        for(int i = 0; i < num_pkts; i++) begin
            send_packets($sformatf("target_%0d", i), LOCAL, 1, pkt_len, pkt_vc, x_dest, y_dest);

            // Wait until DUT's ADAPTIVE VC is allocatable again, so the VC won't be demoted by the master agent             
            wait (env.master_agents[LOCAL].master_drv.is_vc_allocatable[ADAPTIVE]);
        end
    endtask

    // Every target packet must have been demoted by the DUT.
    // Routing of the demoted packets is checked by the scoreboard (SB_ROUTE_XY).
    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        if (env.sb.n_demoted != num_pkts)
            `uvm_error("DEMOTION_COUNT", $sformatf("Expected %0d demoted packets, scoreboard counted %0d",
                    num_pkts, env.sb.n_demoted))
        else
            `uvm_info(get_type_name(), $sformatf("All %0d target packets were demoted ADAPTIVE->ESCAPE",
                    num_pkts), UVM_LOW)
    endfunction

endclass