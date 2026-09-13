import noc_params::*;

class router_seq_item extends uvm_sequence_item;
    
    // Randomized fields for the flit
    rand flit_label_t        flit_label; // HEAD, BODY, TAIL, HEADTAIL
    rand logic [VC_SIZE-1:0] vc_id;      // 0: ESCAPE, 1: ADAPTIVE

    rand logic [DEST_ADDR_SIZE_X-1:0]  x_dest;     // x destination address
    rand logic [DEST_ADDR_SIZE_Y-1:0]  y_dest;     // y destination address
    rand logic [BODY_PAYLOAD_SIZE-1:0] payload;    // body/tail payload

    // UVM Macros for field registration
    `uvm_object_utils_begin(router_seq_item)
        `uvm_field_enum(flit_label_t, flit_label, UVM_ALL_ON)
        `uvm_field_int(vc_id,                     UVM_ALL_ON)
        `uvm_field_int(x_dest,                    UVM_ALL_ON)
        `uvm_field_int(y_dest,                    UVM_ALL_ON)
        `uvm_field_int(payload,                   UVM_ALL_ON)
    `uvm_object_utils_end

    // Constructor
    function new(string name = "router_seq_item");
        super.new(name);
    endfunction

    // Constraints
    constraint c_dest{
        soft x_dest inside {[0:MESH_SIZE_X-1]};
        soft y_dest inside {[0:MESH_SIZE_Y-1]};
    }

    constraint c_valid_dest{
        !(flit_label inside {HEAD, HEADTAIL}) -> { x_dest == 0; y_dest == 0; }
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
        this.vc_id      = f.vc_id;
        
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


endclass