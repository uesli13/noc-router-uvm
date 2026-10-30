class router_illegal_packet_seq extends router_packet_seq;
    `uvm_object_utils(router_illegal_packet_seq)

    function new(string name = "router_illegal_packet_seq");
        super.new(name);
    endfunction

    virtual function flit_label_t calc_label(int i);
        if(i == pkt_len -1) return TAIL;
        else                return BODY;
    endfunction
endclass