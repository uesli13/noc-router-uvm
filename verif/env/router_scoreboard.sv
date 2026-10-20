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
    endfunction

    function void write_in(router_seq_item t);
        router_sb_packet pkt;

        if (t.flit_label inside {HEAD, HEADTAIL}) begin
            if (in_open[t.port][t.vc_id] != null)
                `uvm_error("SB_IN_PROTO", $sformatf("HEAD before previous TAIL at input: %s", t.convert2string())) 
            pkt = new();
            pkt.in_port = t.port;
            pkt.in_vc   = t.vc_id;
            in_flight.push_back(pkt);
            in_open[t.port][t.vc_id] = pkt;
        end
        else begin
            pkt = in_open[t.port][t.vc_id];
            if (pkt == null) begin
                `uvm_error("SB_IN_PROTO", $sformatf("BODY/TAIL with no open packet at input: %s", t.convert2string()))
                return; 
            end
        end

        pkt.flits.push_back(t);

        if (t.flit_label inside {TAIL, HEADTAIL})
            in_open[t.port][t.vc_id] = null;
    endfunction

    function void write_out(router_seq_item t);
        router_sb_packet pkt;

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
            out_open[t.port][t.vc_id] = pkt;
            `uvm_info(get_type_name(), $sformatf("MATCH %s -> %s", pkt.flits[0].convert2string(), t.convert2string()), UVM_LOW)
        end
        else begin
            pkt = out_open[t.port][t.vc_id];
            if (pkt == null) begin
                `uvm_error("SB_NOMATCH", $sformatf("Output BODY/TAIL with no open packet: %s", t.convert2string())) 
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
        end
    endfunction

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        foreach (in_flight[i])
            `uvm_error("SB_LEFTOVER", $sformatf("Packet not fully delivered (in %s, %0d/%0d flits out): %s",
                    in_flight[i].in_port.name(), in_flight[i].next_out, in_flight[i].flits.size(),
                    in_flight[i].flits[0].convert2string()))

        `uvm_info(get_type_name(), $sformatf("Scoreboard: %0d packets still in flight at end of test",
                in_flight.size()), UVM_LOW)
    endfunction
    
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
            `uvm_error("SB_ROUTE", $sformatf("ESCAPE output not on XY port (%s): %s",
                    xy_port(head.x_dest, head.y_dest).name(), out.convert2string()))
        else if (out.vc_id == ADAPTIVE && !is_minimal_port(out.port, head.x_dest, head.y_dest))
            `uvm_error("SB_ROUTE", $sformatf("ADAPTIVE output not on a minimal port: %s", out.convert2string()))
    endfunction


    // If routing was based on the input flit's vc_id this would be the check_routing
    // function void check_routing(router_sb_packet pkt, router_seq_item out);
    //     router_seq_item head = pkt.flits[0];
    //     if (pkt.in_vc == ESCAPE && out.vc_id == ADAPTIVE)
    //         `uvm_error("SB_VC", $sformatf("Illegal VC change ESCAPE->ADAPTIVE: %s", out.convert2string()))
    //     else if (pkt.in_vc == ESCAPE && out.port != xy_port(head.x_dest, head.y_dest))
    //         `uvm_error("SB_ROUTE", $sformatf("ESCAPE packet not routed to XY port (expected %s): %s",
    //                 xy_port(head.x_dest, head.y_dest).name(), out.convert2string()))
    //     else if (pkt.in_vc == ADAPTIVE && !is_minimal_port(out.port, head.x_dest, head.y_dest))
    //         `uvm_error("SB_ROUTE", $sformatf("ADAPTIVE packet not routed to a minimal port: %s", out.convert2string()))
    // endfunction

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