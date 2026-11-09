`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class router_sb_packet;
    port_t          in_port;   // Port where the packet entered the DUT
    vc_class_t      in_vc;     // VC used at the DUT input
    router_seq_item flits[$];  // Flits as captured at the input, in order
    bit             matched;   // Set when the output HEAD has been matched to this packet
    int             next_out;  // Index in flits[] of the next flit expected at the output
endclass

class router_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(router_scoreboard)

    uvm_analysis_imp_in  #(router_seq_item, router_scoreboard) in_imp;  // Takes flits from master monitors' analysis ports
    uvm_analysis_imp_out #(router_seq_item, router_scoreboard) out_imp; // Takes flits from slave  monitors' analysis ports

    int dut_x, dut_y; // DUT position in the mesh

    router_sb_packet in_flight[$]; // Packets currently inside the DUT

    router_sb_packet in_open [PORT_NUM][VC_NUM]; // Packet being received at each input (port, VC)
    router_sb_packet out_open[PORT_NUM][VC_NUM]; // Packet being transmitted at each output (port, VC)

    // End-of-test mechanism
    // The Scoreboard holds ONE objection on the run phase while in_flight is not empty
    virtual router_if vif;                // Used for clk, rst_n
    uvm_phase         run_ph;             // Run phase handle (for raise/drop objections)
    bit               obj_raised;         // 1 while scoreboard holds its objection
    int unsigned      stall_limit = 1000; // Cycles with no output flit (while packets are inside) before SB_STALL
    int unsigned      idle_cycles;        // Cycles since the last output flit

    // Statistics for the report_phase summary
    int unsigned n_flits_in, n_flits_out;
    int unsigned n_pkts_in,  n_pkts_out;
    int unsigned n_demoted; // Changed vc_id from ADAPTIVE to ESCAPE


    function new(string name = "router_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        in_imp  = new("in_imp", this);
        out_imp = new("out_imp", this);
        if(!uvm_config_db#(int)::get(this,"", "DUT_X_CUR" ,dut_x) ||
           !uvm_config_db#(int)::get(this,"", "DUT_Y_CUR" ,dut_y))
           `uvm_fatal(get_type_name(), "Missing DUT coordinates in config_db")

        if(!uvm_config_db#(virtual router_if)::get(this, "", "vif_upstream_LOCAL", vif))
            `uvm_fatal(get_type_name(), "Missing VIF for the stall detector")

        // Optional override from the test (default above)
        void'(uvm_config_db#(int unsigned)::get(this, "", "stall_limit", stall_limit));
    endfunction

    virtual task run_phase(uvm_phase phase);
        run_ph = phase; // No flit can arrive before this point
        stall_detector();
    endtask

    // ------------------------------------------------------------------
    // Analysis imp callbacks
    // ------------------------------------------------------------------
    function void write_in(router_seq_item t);
        router_sb_packet pkt;

        n_flits_in++;

        if (t.flit_label inside {HEAD, HEADTAIL}) begin
            if (in_open[t.port][t.vc_id] != null)
                `uvm_error("SB_IN_NO_TAIL", $sformatf("HEAD before previous TAIL at input: %s", t.convert2string())) 
            pkt = new();
            pkt.in_port = t.port;
            pkt.in_vc   = t.vc_id;
            in_flight.push_back(pkt);
            in_open[t.port][t.vc_id] = pkt;
            n_pkts_in++;
            sb_obj_raise();
        end
        else begin
            pkt = in_open[t.port][t.vc_id];
            if (pkt == null) begin
                `uvm_error("SB_IN_NO_HEAD", $sformatf("BODY/TAIL with no open packet at input: %s", t.convert2string()))
                return; 
            end
        end

        pkt.flits.push_back(t);

        if (t.flit_label inside {TAIL, HEADTAIL})
            in_open[t.port][t.vc_id] = null;
    endfunction

    function void write_out(router_seq_item t);
        router_sb_packet pkt;

        n_flits_out++;
        idle_cycles = 0;

        if (t.flit_label inside {HEAD, HEADTAIL}) begin
            if (out_open[t.port][t.vc_id] != null)
                `uvm_error("SB_INTERLEAVE", $sformatf("HEAD on output VC before previous TAIL: %s", t.convert2string()))
            pkt = find_match(t);
            if (pkt == null) begin
                `uvm_error("SB_NOMATCH", $sformatf("Output HEAD matches no packet in flight: %s", t.convert2string()))
                return;
            end
            pkt.matched  = 1;
            pkt.next_out = 1; // HEAD already checked by find_match
            check_routing(pkt, t);
            
            // VC Demotion Check
            if(pkt.in_vc == ADAPTIVE && t.vc_id == ESCAPE) begin
                n_demoted++;
                `uvm_info(get_type_name(), $sformatf("DEMOTION ADAPTIVE->ESCAPE on %s: %s",
                        t.port.name(), t.convert2string()), UVM_LOW)
            end

            out_open[t.port][t.vc_id] = pkt;
            `uvm_info(get_type_name(), $sformatf("MATCH %s -> %s", pkt.flits[0].convert2string(), t.convert2string()), UVM_LOW)
        end
        else begin
            pkt = out_open[t.port][t.vc_id];
            if (pkt == null) begin
                `uvm_error("SB_OUT_NO_HEAD", $sformatf("Output BODY/TAIL with no open packet: %s", t.convert2string()))
                return;
            end
            if (pkt.next_out >= pkt.flits.size())
                `uvm_error("SB_EXTRA", $sformatf("Output flit with no corresponding input flit: %s", t.convert2string()))
            else if (!pkt.flits[pkt.next_out].compare(t))
                `uvm_error("SB_DATA", $sformatf("Flit %0d mismatch. Expected %s, got %s",
                        pkt.next_out, pkt.flits[pkt.next_out].convert2string(), t.convert2string()))
            pkt.next_out++;
        end

        if (t.flit_label inside {TAIL, HEADTAIL}) begin
            out_open[t.port][t.vc_id] = null;
            remove_in_flight(pkt);
            n_pkts_out++;
            sb_obj_drop(); // No-op unless in_flight just went 1 -> 0
        end
    endfunction

    // ------------------------------------------------------------------
    // Objection handling
    // ------------------------------------------------------------------
    function void sb_obj_raise();
        if (obj_raised) return;
        if (run_ph == null)
            `uvm_fatal(get_type_name(), "Flit received before the run phase started")
        run_ph.raise_objection(this, "SB: packets in flight");
        obj_raised  = 1;
    endfunction

    function void sb_obj_drop(bit force_drop = 0);
        if (!obj_raised) return;
        if (!force_drop && in_flight.size() != 0) return;
        run_ph.drop_objection(this, force_drop ? "SB: stall, objection released" : "SB: DUT empty");
        obj_raised = 0;
    endfunction

    // Progress stall_detector: if packets are inside the DUT but nothing comes out
    // for stall_limit cycles, report SB_STALL and release the objection so
    // that check_phase / report_phase still run (SB_LEFTOVER gives the details).
    task stall_detector();
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n !== 1'b1 || !obj_raised) begin
                idle_cycles = 0;
                continue;
            end
            if (++idle_cycles >= stall_limit) begin
                `uvm_error("SB_STALL", $sformatf("No output flit for %0d cycles with %0d packet(s) in flight, releasing objection",
                        idle_cycles, in_flight.size()))
                sb_obj_drop(.force_drop(1));
                idle_cycles = 0;
            end
        end
    endtask

    // ------------------------------------------------------------------
    // End of test checks and summary
    // ------------------------------------------------------------------
    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        // One error per leftover packet, classified by where it got stuck
        foreach (in_flight[i]) begin
            router_sb_packet p = in_flight[i];
            string state;

            if (in_open[p.in_port][p.in_vc] == p)
                state = "input incomplete, TAIL never entered the DUT";
            else if (p.matched)
                state = $sformatf("partially delivered, %0d/%0d flits out", p.next_out, p.flits.size());
            else
                state = "never left the DUT";

            `uvm_error("SB_LEFTOVER", $sformatf("Packet in %s/%s %s: %s",
                    p.in_port.name(), p.in_vc.name(), state, p.flits[0].convert2string()))
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Summary: packets in=%0d out=%0d left=%0d demoted=%0d | flits in=%0d out=%0d",
                n_pkts_in, n_pkts_out, in_flight.size(), n_demoted, n_flits_in, n_flits_out), UVM_NONE)
    endfunction

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function void remove_in_flight(router_sb_packet pkt);
        foreach (in_flight[i])
            if (in_flight[i] == pkt) begin
                in_flight.delete(i);
                return;
            end
    endfunction

    function port_t xy_port(int xd, int yd);
        if (xd < dut_x) return WEST;
        if (xd > dut_x) return EAST;
        if (yd > dut_y) return NORTH;
        if (yd < dut_y) return SOUTH;
        return LOCAL;
    endfunction

    function bit is_minimal_port(port_t p, int xd, int yd);
        case (p)
            WEST:  return xd < dut_x;
            EAST:  return xd > dut_x;
            NORTH: return yd > dut_y;
            SOUTH: return yd < dut_y;
            LOCAL: return (xd == dut_x) && (yd == dut_y);
        endcase
        return 0;
    endfunction

    function void check_routing(router_sb_packet pkt, router_seq_item out);
        router_seq_item head = pkt.flits[0];
        if (pkt.in_vc == ESCAPE && out.vc_id == ADAPTIVE)
            `uvm_error("SB_VC", $sformatf("Illegal VC change ESCAPE->ADAPTIVE: %s", out.convert2string()))
        else if (out.vc_id == ESCAPE && out.port != xy_port(head.x_dest, head.y_dest))
            `uvm_error("SB_ROUTE_XY", $sformatf("ESCAPE output not on XY port (%s): %s",
                    xy_port(head.x_dest, head.y_dest).name(), out.convert2string()))
        else if (out.vc_id == ADAPTIVE && !is_minimal_port(out.port, head.x_dest, head.y_dest))
            `uvm_error("SB_ROUTE_MIN", $sformatf("ADAPTIVE output not on a minimal port: %s", out.convert2string()))
    endfunction

    function router_sb_packet find_match(router_seq_item t);
        foreach (in_flight[i]) begin
            router_seq_item h = in_flight[i].flits[0];
            if (!in_flight[i].matched &&
                h.flit_label == t.flit_label &&
                h.x_dest == t.x_dest && h.y_dest == t.y_dest &&
                h.payload == t.payload)
                return in_flight[i];
        end
        return null;
    endfunction

endclass