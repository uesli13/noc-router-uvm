class router_seq_item extends uvm_sequence_item;
    
    // Randomized fields for the flit
    rand flit_label_t flit_label; // HEAD, BODY, TAIL, HEADTAIL
    rand vc_class_t   vc_id;      // ESCAPE, ADAPTIVE

    rand bit [DEST_ADDR_SIZE_X-1:0]  x_dest;     // x destination address
    rand bit [DEST_ADDR_SIZE_Y-1:0]  y_dest;     // y destination address
    rand bit [BODY_PAYLOAD_SIZE-1:0] payload;    // body/tail payload

    // UVM Macros for field registration
    `uvm_object_utils_begin(router_seq_item)
        `uvm_field_enum(flit_label_t, flit_label, UVM_ALL_ON)
        `uvm_field_enum(vc_class_t, vc_id, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(x_dest,                    UVM_ALL_ON)
        `uvm_field_int(y_dest,                    UVM_ALL_ON)
        `uvm_field_int(payload,                   UVM_ALL_ON)
        
    `uvm_object_utils_end

    // Constructor
    function new(string name = "router_seq_item");
        super.new(name);
    endfunction

    // Constraints

    // Destination coordinates should be inside mesh size
    constraint c_dest{
        soft x_dest inside {[0:MESH_SIZE_X-1]};
        soft y_dest inside {[0:MESH_SIZE_Y-1]};
    }

    // BODY and TAIL flits should have no destination coordinates
    constraint c_bt_no_dest {
        (flit_label inside {BODY, TAIL}) -> { x_dest == 0; y_dest == 0; }
    }

    // HEAD and HEADTAIL flits should drive to zero the extra bits of the payload
    constraint c_head_payload {
        (flit_label inside {HEAD, HEADTAIL}) -> payload[BODY_PAYLOAD_SIZE-1:HEAD_PAYLOAD_SIZE] == '0;
    }

    // Helper functions

    // Convert the sequence item to a flit_t struct
    function flit_t to_struct();
        flit_t f;
        
        f.flit_label = this.flit_label;
        f.vc_id      = this.vc_id;
        
        if (this.flit_label == HEAD || this.flit_label == HEADTAIL) begin
            f.data.head_data.x_dest  = this.x_dest;
            f.data.head_data.y_dest  = this.y_dest;
            f.data.head_data.head_pl = this.payload[HEAD_PAYLOAD_SIZE-1:0]; 
        end 
        else begin
            f.data.bt_pl = this.payload; 
        end
        
        return f;
    endfunction

    // Convert a flit_t struct to the sequence item
    function void from_struct(flit_t f);
        this.flit_label = f.flit_label;
        this.vc_id      = vc_class_t'(f.vc_id);
        this.payload = '0;

        if (f.flit_label == HEAD || f.flit_label == HEADTAIL) begin
            this.x_dest  = f.data.head_data.x_dest;
            this.y_dest  = f.data.head_data.y_dest;
            this.payload[HEAD_PAYLOAD_SIZE-1:0] = f.data.head_data.head_pl;
        end 
        else begin
            this.x_dest  = 0;
            this.y_dest  = 0;
            this.payload = f.data.bt_pl;
        end
    endfunction

    // One-line summary for logs
    function string convert2string();
        return $sformatf("%s vc=%s dest=(%0d,%0d) pl=%0h", flit_label.name(), vc_id.name(), x_dest, y_dest, payload);
    endfunction

endclass