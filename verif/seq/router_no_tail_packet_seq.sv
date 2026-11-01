class router_no_tail_packet_seq extends router_packet_seq;
    `uvm_object_utils(router_no_tail_packet_seq)

    function new(string name = "router_no_tail_packet_seq");
        super.new(name);
    endfunction

    virtual function flit_label_t calc_label(int i);
        if(i == 0) return HEAD;
        else       return BODY;
    endfunction
endclass