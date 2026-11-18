class router_contention_sweep_test extends router_base_test;
    `uvm_component_utils(router_contention_sweep_test)

    int unsigned n_sent;       // Packets sent
    int unsigned n_scenarios;  // Pairs sent
    int unsigned n_contended;  // Pairs that really met inside the DUT

    function new(string name = "router_contention_sweep_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void set_default_knobs();
        num_pkts = 1;  // One packet per input in every scenario
        pkt_len  = 4;
    endfunction

    virtual task run_stimulus();
        if (num_pkts != 1)
            `uvm_fatal(get_type_name(), "Output contention test needs exactly one packet per input")

        // Sweep every output port
        for (int o = 0; o < PORT_NUM; o++) begin
            port_t out = port_t'(o);
            int    xd, yd;

            // Skip outputs without a neighbour at this DUT position
            if (!port_exists(out)) continue;
            out_dest(out, xd, yd);

            // Create packet combinations that can send to this output
            for (int a = 0; a < PORT_NUM; a++)
                for (int b = a + 1; b < PORT_NUM; b++)
                    for (int vc_a = 0; vc_a < VC_NUM; vc_a++)
                        for (int vc_b = 0; vc_b < VC_NUM; vc_b++) begin
                            port_t in_a = port_t'(a);
                            port_t in_b = port_t'(b);

                            // Filter out non legal scenarios
                            if (!is_legal(in_a, vc_a, xd, yd)) continue;
                            if (!is_legal(in_b, vc_b, xd, yd)) continue;

                            // Send the packets at the same time
                            run_pair(out, in_a, vc_a, in_b, vc_b, xd, yd);
                        end
        end
    endtask

    task run_pair(port_t out, port_t in_a, int vc_a, port_t in_b, int vc_b, int xd, int yd);
        vc_class_t       va = vc_class_t'(vc_a);
        vc_class_t       vb = vc_class_t'(vc_b);
        string           tag;
        router_sb_packet pkt_1, pkt_2;

        tag = $sformatf("%s_from_%s_%s_and_%s_%s", out.name(), in_a.name(), va.name(), in_b.name(), vb.name());

        // Send both packets at the same time
        fork
            send_packets({tag, "_a"}, in_a, num_pkts, pkt_len, vc_a, xd, yd);
            send_packets({tag, "_b"}, in_b, num_pkts, pkt_len, vc_b, xd, yd);
        join

        n_sent += 2;
        n_scenarios++;

        // Wait until both packets have left and every agent is idle
        wait_dut_idle(n_sent);

        // The two packets of this scenario are the last two that left the DUT
        pkt_1 = env.sb.done_pkts[$-1];
        pkt_2 = env.sb.done_pkts[$];

        // Check if contention happened (both left from the same output and their time inside the DUT overlaps)
        if (pkt_1.out_port == out && pkt_2.out_port == out &&
            pkt_1.t_in < pkt_2.t_out && pkt_2.t_in < pkt_1.t_out) begin
            n_contended++;
            `uvm_info(get_type_name(), $sformatf("%s: contention OK (in %0t/%0t, out %0t/%0t)",
                      tag, pkt_1.t_in, pkt_2.t_in, pkt_1.t_out, pkt_2.t_out), UVM_LOW)
        end
        else
            `uvm_error("NO_CONTENTION", $sformatf("%s: packets did not meet inside the DUT (ports %s/%s, in %0t/%0t, out %0t/%0t)",
                       tag, pkt_1.out_port.name(), pkt_2.out_port.name(),
                       pkt_1.t_in, pkt_2.t_in, pkt_1.t_out, pkt_2.t_out))
    endtask
    
    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        if (n_scenarios == 0)
            `uvm_error("CONTENTION_EMPTY", "No legal pair of inputs was found for this DUT position")
        else
            `uvm_info(get_type_name(), $sformatf("Contention sweep at (%0d,%0d): %0d/%0d scenarios with contention, %0d demoted",
                      dut_x, dut_y, n_contended, n_scenarios, env.sb.n_demoted), UVM_LOW)
    endfunction
endclass