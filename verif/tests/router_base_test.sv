class router_base_test extends uvm_test;
    `uvm_component_utils(router_base_test)

    router_env          env;
    router_agent_config master_cfg[5];
    router_agent_config slave_cfg[5];

    //DUT's position in the mesh
    int dut_x;
    int dut_y;

    // End-of-test settings
    time         drain_time     = 3 * CLK_PERIOD;
    int unsigned stall_limit    = 1000;   // cycles without output          (+STALL_LIMIT=)
    time         global_timeout = 1ms;    // Safety net for testbench hangs (+TIMEOUT_NS=)

    // Stimulus parameters (-1 means random)
    // Each test sets its own values in set_default_knobs(), plusargs can overwrite them
    int num_pkts = 1;     // Number of packets       (+NPKT=)
    int pkt_len  = -1;    // Flits per packet        (+LEN=)
    int pkt_vc   = -1;    // VC of the packets       (+VC=ESCAPE/ADAPTIVE/RANDOM)
    int x_dest   = -1;    // Destination x           (+XD=)
    int y_dest   = -1;    // Destination y           (+YD=)
    int src_port = LOCAL; // Master agent that sends (+SRC=LOCAL/NORTH/SOUTH/WEST/EAST)


    function new(string name = "router_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = router_env::type_id::create("env", this);

        if(!uvm_config_db#(int)::get(this, "", "DUT_X_CUR", dut_x) ||
           !uvm_config_db#(int)::get(this, "", "DUT_Y_CUR", dut_y))
            `uvm_fatal(get_type_name(), "Missing DUT coordinates in config_db")
        
        `uvm_info(get_type_name(), $sformatf("DUT position: (%0d,%0d) in a %0dx%0d mesh", 
                   dut_x, dut_y, MESH_SIZE_X, MESH_SIZE_Y), UVM_LOW)

        set_default_knobs(); // Each test's own defaults
        read_plusargs();     // Command line overrides
        configure_agents();  // Agent configuration (may depend on the knobs)

        uvm_config_db#(int unsigned)::set(this, "env.sb", "stall_limit", stall_limit);
        uvm_top.set_timeout(global_timeout, 1);
    endfunction

    // Overridden by derived tests to set their own default stimulus
    virtual function void set_default_knobs();
    endfunction

    // Read stimulus knobs from the command line
    function void read_plusargs();
        string s;
        int    tmo_ns;

        void'($value$plusargs("NPKT=%d", num_pkts));
        void'($value$plusargs("LEN=%d",  pkt_len));
        void'($value$plusargs("XD=%d",   x_dest));
        void'($value$plusargs("YD=%d",   y_dest));
        void'($value$plusargs("STALL_LIMIT=%d", stall_limit));

        if ($value$plusargs("TIMEOUT_NS=%d", tmo_ns))
            global_timeout = tmo_ns * 1ns;

        if ($value$plusargs("VC=%s", s)) begin
            if      (s == "ESCAPE")   pkt_vc = ESCAPE;
            else if (s == "ADAPTIVE") pkt_vc = ADAPTIVE;
            else if (s == "RANDOM")   pkt_vc = -1;
            else `uvm_fatal(get_type_name(), {"Unknown +VC value: ", s})
        end

        if ($value$plusargs("SRC=%s", s)) begin
            src_port = -1;
            foreach (PORT_NAMES[i])
                if (PORT_NAMES[i] == s) src_port = i;
            if (src_port < 0)
                `uvm_fatal(get_type_name(), {"Unknown +SRC value: ", s})
        end
    endfunction

    virtual function void configure_agents();
        for(int i = 0; i < 5; i++) begin
            string down_vif_path    = $sformatf("vif_downstream_%s", PORT_NAMES[i]);
            string up_vif_path      = $sformatf("vif_upstream_%s", PORT_NAMES[i]);
            string master_env_path  = $sformatf("env.master_%s", PORT_NAMES[i]);
            string slave_env_path   = $sformatf("env.slave_%s", PORT_NAMES[i]);

            master_cfg[i] = router_agent_config::type_id::create($sformatf("master_cfg_%s", PORT_NAMES[i]));
            slave_cfg[i]  = router_agent_config::type_id::create($sformatf("slave_cfg_%s", PORT_NAMES[i]));

            master_cfg[i].mode      = MASTER_AGENT;
            master_cfg[i].is_active = UVM_ACTIVE;
            slave_cfg[i].mode       = SLAVE_AGENT;
            slave_cfg[i].is_active  = UVM_ACTIVE;

            master_cfg[i].port_id = port_t'(i);
            slave_cfg[i].port_id  = port_t'(i);

            // Default packet and flit consumption delay in the slave driver
            slave_cfg[i].min_credit_delay = '{default: 4};
            slave_cfg[i].max_credit_delay = '{default: 4};
            slave_cfg[i].min_flit_delay = '{default: 0};
            slave_cfg[i].max_flit_delay = '{default: 0};

            if(!uvm_config_db#(virtual router_if)::get(this, "", down_vif_path, master_cfg[i].vif))
                `uvm_fatal(get_type_name(), $sformatf("Missing Downstream VIF for %s", PORT_NAMES[i]))

            if(!uvm_config_db#(virtual router_if)::get(this, "", up_vif_path, slave_cfg[i].vif))
                `uvm_fatal(get_type_name(), $sformatf("Missing Upstream VIF for %s", PORT_NAMES[i]))

            uvm_config_db#(router_agent_config)::set(this, master_env_path, "cfg", master_cfg[i]);
            uvm_config_db#(router_agent_config)::set(this, slave_env_path, "cfg", slave_cfg[i]);
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.phase_done.set_drain_time(this, drain_time);

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "Test is running...", UVM_LOW)

        run_stimulus();

        `uvm_info(get_type_name(), "Stimulus finished, waiting for scoreboard and slave agents to drain", UVM_LOW)
        phase.drop_objection(this);
    endtask

    // Default stimulus: a sequence of packets shaped by the knobs.
    // Tests with different stimulus override it.
    virtual task run_stimulus();
        send_packets("seq", port_t'(src_port), num_pkts, pkt_len, pkt_vc, x_dest, y_dest);
    endtask

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int err_count;

        super.report_phase(phase);

        svr       = uvm_report_server::get_server();
        err_count = svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL);

        if(err_count == 0)
            `uvm_info(get_type_name(), "** TEST PASSED **", UVM_NONE)
        else
            `uvm_info(get_type_name(), $sformatf("** TEST FAILED ** (%0d errors)", err_count), UVM_NONE)
    endfunction


    // Create, randomize and send a router_multi_packet_seq from a master agent.
    task send_packets(string name, port_t src, int npkt, int len, int vc, int xd, int yd);
        router_multi_packet_seq seq = router_multi_packet_seq::type_id::create(name);

        seq.len = len;
        seq.vc  = vc;
        seq.xd  = xd;
        seq.yd  = yd;

        if(!seq.randomize() with {(local::npkt > 0) ->  num_packets == local::npkt;})
            `uvm_fatal(get_type_name(), $sformatf("Randomization failed for %s", name))

        `uvm_info(get_type_name(), $sformatf("Stimulus %s: src=%s npkt=%0d len=%0d vc=%0d dest=(%0d,%0d)  [-1 = random]",
                  name, src.name(), seq.num_packets, len, vc, xd, yd), UVM_LOW)

        seq.start(env.master_agents[src].sequencer);
    endtask

        // Does the DUT have a neighbour on this port at its current position?
    function bit port_exists(port_t p);
        case (p)
            WEST:    return dut_x > 0;
            EAST:    return dut_x < MESH_SIZE_X - 1;
            SOUTH:   return dut_y > 0;
            NORTH:   return dut_y < MESH_SIZE_Y - 1;
            default: return 1; // LOCAL
        endcase
    endfunction

    // Can a packet with this VC and destination arrive at this input port
    function bit is_legal(port_t in, int vc, int xd, int yd);
        if (!port_exists(in)) return 0;
        case (in)
            WEST:    return xd >= dut_x;
            EAST:    return xd <= dut_x;
            // ESCAPE packets move in Y only after X is done (XY routing)
            SOUTH:   return yd >= dut_y && (vc == ADAPTIVE || xd == dut_x);
            NORTH:   return yd <= dut_y && (vc == ADAPTIVE || xd == dut_x);
            default: return !(xd == dut_x && yd == dut_y); // LOCAL (no LOCAL -> LOCAL)
        endcase
    endfunction

endclass