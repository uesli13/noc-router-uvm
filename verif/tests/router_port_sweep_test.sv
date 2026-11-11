class router_port_sweep_test extends router_base_test;
    `uvm_component_utils(router_port_sweep_test)

    int unsigned n_sent; // Packets sent so far

    function new(string name = "router_port_sweep_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // src_port, pkt_vc, x_dest, y_dest are not used: the test sweeps them
    virtual function void set_default_knobs();
        num_pkts = 1;   // Packets per combination
        pkt_len  = -1;  // Random length
    endfunction

    // One combination at a time: every legal (input port, VC, destination)
    virtual task run_stimulus();
        if (num_pkts < 1)
            `uvm_fatal(get_type_name(), "Sweep test needs a fixed number of packets per combination (+NPKT >= 1)")

        for (int p = 0; p < PORT_NUM; p++)
            for (int vc = 0; vc < VC_NUM; vc++)
                for (int xd = 0; xd < MESH_SIZE_X; xd++)
                    for (int yd = 0; yd < MESH_SIZE_Y; yd++) begin
                        port_t in = port_t'(p);

                        if (!is_legal(in, vc, xd, yd)) continue;

                        send_packets($sformatf("sweep_%s_vc%0d_%0d_%0d", in.name(), vc, xd, yd),
                                     in, num_pkts, pkt_len, vc, xd, yd);
                        n_sent += num_pkts;

                        // Wait until the packets have left the DUT, so combinations don't overlap
                        wait (env.sb.n_pkts_out == n_sent);
                        
                        // Wait until every slave has returned all its credits and is_allocatable
                        foreach (env.slave_agents[i])
                            while (!env.slave_agents[i].slave_drv.nothing_pending())
                                #(CLK_PERIOD);

                    end
    endtask

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        if (env.sb.n_demoted != 0)
            `uvm_error("SWEEP_DEMOTION", $sformatf("%0d packets were demoted, but every downstream VC was free",
                    env.sb.n_demoted))

        if (n_sent == 0)
            `uvm_error("SWEEP_EMPTY", "No legal combination was found for this DUT position")
        else
            `uvm_info(get_type_name(), $sformatf("Sweep at (%0d,%0d): %0d packets sent",
                      dut_x, dut_y, n_sent), UVM_LOW)
    endfunction

endclass