class router_multi_packet_seq extends uvm_sequence #(router_seq_item);
    `uvm_object_utils(router_multi_packet_seq)

    // Number of packets to send
    rand int unsigned num_packets;

    constraint c_num_packets {
        soft num_packets inside {[1:10]};
    }

    // Per-packet knobs: a negative value leaves the field random for every packet
    int len = -1;   // flits per packet
    int vc  = -1;   // 0 = ESCAPE, 1 = ADAPTIVE
    int xd  = -1;   // destination x
    int yd  = -1;   // destination y

    function new(string name = "router_multi_packet_seq");
        super.new(name);
    endfunction

    virtual task body();
        router_packet_seq pkt_seq;

        `uvm_info(get_type_name(), $sformatf("Starting %0d packets", num_packets), UVM_LOW)

        for (int n = 0; n < num_packets; n++) begin
            pkt_seq = router_packet_seq::type_id::create($sformatf("pkt_%0d", n));

            if(!pkt_seq.randomize() with {
                (local::len >= 0) -> pkt_len    == local::len;
                (local::vc  >= 0) -> pkt_vc     == vc_class_t'(local::vc);
                (local::xd  >= 0) -> pkt_x_dest == local::xd;
                (local::yd  >= 0) -> pkt_y_dest == local::yd;
            }) begin
                `uvm_fatal(get_type_name(), $sformatf("Randomization failed for packet %0d", n))
            end

            `uvm_info(get_type_name(), $sformatf("Packet %0d/%0d", n + 1, num_packets), UVM_LOW)
            pkt_seq.start(m_sequencer, this);
        end

        `uvm_info(get_type_name(), "All packets finished", UVM_LOW)
    endtask

endclass