class router_multi_packet_seq extends uvm_sequence #(router_seq_item);
    `uvm_object_utils(router_multi_packet_seq)

    // Number of packets to send
    rand int unsigned num_packets;

    constraint c_num_packets {
        soft num_packets inside {[1:10]};
    }

    // Deterministic mode: when use_fixed = 1, every packet uses the fixed values below
    bit                          use_fixed = 0;
    int unsigned                 fixed_len;
    vc_class_t                   fixed_vc;
    bit [DEST_ADDR_SIZE_X-1:0]   fixed_x_dest;
    bit [DEST_ADDR_SIZE_Y-1:0]   fixed_y_dest;

    function new(string name = "router_multi_packet_seq");
        super.new(name);
    endfunction

    virtual task body();
        router_packet_seq pkt_seq;

        `uvm_info(get_type_name(), $sformatf("Starting %0d packets (fixed mode: %0d)", num_packets, use_fixed), UVM_LOW)

        for (int n = 0; n < num_packets; n++) begin
            pkt_seq = router_packet_seq::type_id::create($sformatf("pkt_%0d", n));

            if(!pkt_seq.randomize() with {
                // In fixed mode, force the packet properties; otherwise they are random
                use_fixed -> {
                    pkt_len    == fixed_len;
                    pkt_vc     == fixed_vc;
                    pkt_x_dest == fixed_x_dest;
                    pkt_y_dest == fixed_y_dest;
                }
            }) begin
                `uvm_fatal(get_type_name(), $sformatf("Randomization failed for packet %0d", n))
            end

            `uvm_info(get_type_name(), $sformatf("Packet %0d/%0d", n + 1, num_packets), UVM_LOW)
            pkt_seq.start(m_sequencer, this);
        end

        `uvm_info(get_type_name(), "All packets finished", UVM_LOW)
    endtask

endclass