class router_sanity_seq extends uvm_sequence #(router_seq_item);
    `uvm_object_utils(router_sanity_seq)

    function new(string name ="router_sanity_seq");
        super.new(name);
    endfunction

    virtual task body();
        router_seq_item req;

        `uvm_info(get_type_name(), "Starting Sanity Sequence...", UVM_LOW)

        req = router_seq_item::type_id::create("req");

        start_item(req);

        if(!req.randomize()with {
            flit_label == HEADTAIL;
            vc_id      == ESCAPE;
            x_dest     == 0;
            y_dest     == 1;
        }) begin
            `uvm_fatal(get_type_name(), "Randomization failed for Sanity Sequence")
        end

        finish_item(req);

        `uvm_info(get_type_name(), $sformatf("Sanity Sequence finished. Sent Flit: %s", req.convert2string()), UVM_LOW)
    endtask
endclass