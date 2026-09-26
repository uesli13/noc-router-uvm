class router_packet_seq extends uvm_sequence #(router_seq_item);
    `uvm_object_utils(router_packet_seq)

    // Packet-level properties
    rand int unsigned                pkt_len;     // number of flits in the packet
    rand vc_class_t                  pkt_vc;      // VC used by the whole packet
    rand bit [DEST_ADDR_SIZE_X-1:0]  pkt_x_dest;  // destination, carried only by the head flit
    rand bit [DEST_ADDR_SIZE_Y-1:0]  pkt_y_dest;

    // Packets consist of 1 to MAX_PACKET_LEN flits
    constraint c_len {
        pkt_len inside {[1:MAX_PACKET_LEN]};
    }

    // Destination should be inside the mesh
    constraint c_dest {
        soft pkt_x_dest inside {[0:MESH_SIZE_X-1]};
        soft pkt_y_dest inside {[0:MESH_SIZE_Y-1]};
    }

    function new(string name = "router_packet_seq");
        super.new(name);
    endfunction

    virtual task body();
        router_seq_item req;
        flit_label_t    label;

        `uvm_info(get_type_name(), $sformatf("Starting packet: len=%0d vc=%s dest=(%0d,%0d)",
                  pkt_len, pkt_vc.name(), pkt_x_dest, pkt_y_dest), UVM_LOW)

        for (int i = 0; i < pkt_len; i++) begin
            // Decide the flit's label from its position in the packet
            if      (pkt_len == 1)       label = HEADTAIL;
            else if (i == 0)             label = HEAD;
            else if (i == pkt_len - 1)   label = TAIL;
            else                         label = BODY;

            req = router_seq_item::type_id::create($sformatf("flit_%0d", i));

            start_item(req);
            if(!req.randomize() with {
                flit_label == label;
                vc_id      == pkt_vc;
                // Only head flits carry the destination (avoids conflict with c_bt_no_dest)
                (flit_label inside {HEAD, HEADTAIL}) -> { x_dest == pkt_x_dest; y_dest == pkt_y_dest; }
            }) begin
                `uvm_fatal(get_type_name(), $sformatf("Randomization failed for flit %0d", i))
            end
            finish_item(req);
        end

        `uvm_info(get_type_name(), "Packet finished", UVM_LOW)
    endtask

endclass