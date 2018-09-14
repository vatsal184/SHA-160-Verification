        
//-----------interface--------------------------------------------------------------------------------------------------

interface sha1_if( input clk_i, input rst_i);  
  
  reg [31:0]text_i; // text input 32bit
  reg [31:0]text_o; // text output 32bit
  reg [2:0]cmd_i; // command input
  reg   cmd_w_i;// command input write enable
  reg  [3:0]cmd_o; // command output(status)
  
  
  clocking driver_cb @(posedge clk_i);
    input text_o;
    input cmd_o;
    output text_i;
    output cmd_w_i;
    output cmd_i;
    endclocking
  
  clocking monitor_cb @(posedge clk_i);
    input text_o;
    input cmd_o;
    input text_i;
    input cmd_w_i;
    input cmd_i;
    endclocking
  
  
  modport DRIVER  (clocking driver_cb,input clk_i,rst_i);
  modport MONITOR  (clocking monitor_cb,input clk_i,rst_i);

   
endinterface: sha1_if
    
    
//---------------------------------------------------------------------------------------------------------------------------------
//            seq_item
//----------------------------------------------------------------------------------------------------------------------------------
class sha1_seq_item extends uvm_sequence_item;
  
    `uvm_object_utils(sha1_seq_item)
  
    rand logic [31:0]text_i; // text input 32bit
    rand logic [2:0]cmd_i; // command input
    bit cmd_w_i;// command input write enable
    logic [3:0]cmd_o;
    logic [31:0]text_o; // text output 32bit
    
  
    function new (string name = "sha1_seq_item");
      super.new(name);
    endfunction
  
    function string convert2string;
        return $psprintf("text_i = %h, text_o = %h, cmd_o = %h", text_i, text_o, cmd_o);
    endfunction: convert2string
     
endclass: sha1_seq_item

    
//------------------------------------------------------------------------------------------------------------------------
//          Sequence
//------------------------------------------------------------------------------------------------------------------------

class sha1_sequence extends uvm_sequence#(sha1_seq_item);
    `uvm_object_utils(sha1_sequence)
    sha1_seq_item req;
    function new (string name = "sha1_sequence");
      super.new(name);
    endfunction

    task body();
      repeat (40) begin
        req = sha1_seq_item::type_id::create("req");
        start_item(req);
        if( !req.randomize() )
          `uvm_error("", "Randomize failed")
        finish_item(req);
        end
    endtask
   
endclass: sha1_sequence
      
//------------------------------------------------------------------------------------------------------------------------
//          Sequencer
//------------------------------------------------------------------------------------------------------------------------
      
class sha1_sequencer extends uvm_sequencer #(sha1_seq_item);
    
    `uvm_component_utils(sha1_sequencer)
        
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  
endclass: sha1_sequencer
    
//------------------------------------------------------------------------------------------------------------------
//            Driver
//------------------------------------------------------------------------------------------------------------------

class sha1_driver extends uvm_driver #(sha1_seq_item);
  
    `uvm_component_utils(sha1_driver)

    virtual sha1_if sha1_vi;
    sha1_seq_item req;
    reg cmd_w_i = 1;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      if( !uvm_config_db #(virtual sha1_if)::get(this, "", "m_if", sha1_vi) )
        `uvm_error("", "uvm_config_db::get failed")
        req = sha1_seq_item::type_id::create("req");
    endfunction 
   
        
    task run_phase(uvm_phase phase);
      forever begin
        seq_item_port.get_next_item(req);
    drive(req);
        seq_item_port.item_done();
      end
    endtask
      
      
      task drive(input sha1_seq_item req);
        @(posedge sha1_vi.DRIVER.clk_i);
        sha1_vi.cmd_i = req.cmd_i;
        sha1_vi.cmd_w_i = cmd_w_i;
        sha1_vi.text_i = req.text_i;
         #1 cmd_w_i = 0;
        sha1_vi.cmd_w_i = cmd_w_i;
        #840  
        cmd_w_i = 1;
        req.text_o = sha1_vi.text_o;
       // $display("text output %h",req.text_o);
      endtask
      
  
  endclass: sha1_driver
  
//------------------------------------------------------------------------------------------------------------------------
//            Monitor
//-----------------------------------------------------------------------------------------------------------------------

class sha1_monitor extends uvm_monitor;
  
  `uvm_component_utils(sha1_monitor)
  
  uvm_analysis_port #(sha1_seq_item) m_port;
  
  
  virtual sha1_if inf;
  
  function new (string name, uvm_component parent);
    super.new(name, parent);
    m_port = new("m_port",this);
  endfunction : new
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(virtual sha1_if)::get(this,"","m_if",inf))
      `uvm_error("", "uvm_config_db::get failed")
      
  endfunction: build_phase
  
  virtual task run_phase(uvm_phase phase);
    forever begin
      sha1_seq_item trans;
      
      @(posedge inf.MONITOR.monitor_cb.cmd_i)
      
        trans = sha1_seq_item::type_id::create("trans",this);
      
        trans.cmd_i = inf.cmd_i;
        trans.cmd_w_i = inf.cmd_w_i;
        trans.text_i = inf.text_i;
        trans.cmd_o = inf.cmd_o;
        trans.text_o = inf.text_o;
      
      /*$display("monitor cmd_o %h",trans.cmd_o);
        $display("monitor text_i %h",trans.text_i);  
        $display("monitor cmd_w_i %h",trans.cmd_i);
        $display("monitor cmd_i %h",trans.cmd_i);
        $display("monitor text_o %h",trans.text_o);*/
        m_port.write(trans);
    end
  endtask : run_phase
endclass : sha1_monitor
      
    

//------------------------------------------------------------------------------------------------------------------------
//            Agent
//-----------------------------------------------------------------------------------------------------------------------

      
class sha1_agent extends uvm_agent;

    `uvm_component_utils(sha1_agent)
    
    sha1_sequencer sha1_seqr;
    sha1_driver    sha1_driv;
    sha1_monitor  monitor;
        
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
 
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
        monitor = sha1_monitor::type_id::create("monitor", this);
      if (is_active == UVM_ACTIVE) begin
        sha1_seqr = sha1_sequencer::type_id::create("sha1_seqr", this); 
        sha1_driv = sha1_driver::type_id::create("sha1_driv", this);
      end
    endfunction
    
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      sha1_driv.seq_item_port.connect( sha1_seqr.seq_item_export );
      
      //sha1_driv.rsp_port.connect( sha1_seqr.rsp_export );
    endfunction: connect_phase
    
  endclass: sha1_agent
    
    
//------------------------------------------------------------------------------------------------------------------------
//            Subscriber
//------------------------------------------------------------------------------------------------------------------------

class sha1_subscriber extends uvm_subscriber#(sha1_seq_item);
  `uvm_component_utils(sha1_subscriber)
  virtual sha1_if _if;
    
    sha1_seq_item trans;
  
    covergroup cov;
      covi : coverpoint trans.text_i;// { option.auto_bin_max = 32;  } 
      covo : coverpoint trans.text_o;// { option.auto_bin_max = 32;  }
    endgroup
  

 
    extern function new(string name, uvm_component parent);
    extern function void write(input sha1_seq_item t);
  

endclass: sha1_subscriber
      
   function sha1_subscriber::new (string name, uvm_component parent);
    super.new(name, parent);
        cov = new;
    endfunction : new
      
  function void sha1_subscriber::write(input sha1_seq_item t);
      `uvm_info("mg", $psprintf("Subscriber received t %s", t.convert2string()), UVM_NONE);
      
        trans = t;
      cov.sample();
     // $display("SCB:: Pkt recived");
      //t.print();
   
  endfunction      
      
      
//--------------------------------------------------------------------------------------------------------------------------
//            Env
//--------------------------------------------------------------------------------------------------------------------------


      
class sha1_env extends uvm_env;

  `uvm_component_utils(sha1_env)
    
    sha1_agent      sha1_agnt;
    sha1_subscriber scoreb;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
 
    function void build_phase(uvm_phase phase);
      sha1_agnt = sha1_agent::type_id::create("sha1_agnt", this);
      scoreb = sha1_subscriber::type_id::create("scoreb", this);
    endfunction: build_phase
    
  function void connect_phase(uvm_phase phase);
    sha1_agnt.monitor.m_port.connect(scoreb.analysis_export);
  endfunction: connect_phase
    
endclass: sha1_env

//--------------------------------------------------------------------------------------------------------------------------------
//            Test
//-----------------------------------------------------------------------------------------------------------------------
      
class sha1_test extends uvm_test;
  `uvm_component_utils(sha1_test)
    
    sha1_env env;
    sha1_sequence seq;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      env = sha1_env::type_id::create("env", this);
      seq = sha1_sequence::type_id::create("seq");
    endfunction
    
    task run_phase(uvm_phase phase);
      //seq.no_iterations = 20;
    if( !seq.randomize() ) 
        `uvm_error("", "Randomize failed")
      phase.raise_objection(this);
      env.scoreb.cov.start();
      seq.start(env.sha1_agnt.sha1_seqr);
      env.scoreb.cov.stop();
      $display("coverage : %d",env.scoreb.cov.covi.get_coverage());
      $display("coverage : %d",env.scoreb.cov.covo.get_coverage());
      phase.drop_objection(this);
    
    //set a drain-time for the environment if desired
    phase.phase_done.set_drain_time(this, 50);
    endtask
      
  endclass: sha1_test
  
  
//------------------------------------------------------------------------------------------------------------------------
//            Top module
//------------------------------------------------------------------------------------------------------------------------
      
   

module top();
   
  bit clk_i;
  bit rst_i;

  initial begin
            $dumpfile("dump.vcd"); 
      $dumpvars;
    clk_i = 0;
    rst_i = 1;
    #5 rst_i = 0;
  end

  always #5 clk_i = ~clk_i;
   
 
  sha1_if sha1_if0 (clk_i, rst_i);


  sha1 dut(
        .clk_i(sha1_if0.clk_i),
      .rst_i(sha1_if0.rst_i),
      .text_i(sha1_if0.text_i),
      .text_o(sha1_if0.text_o),
      .cmd_i(sha1_if0.cmd_i),
      .cmd_w_i(sha1_if0.cmd_w_i),
      .cmd_o(sha1_if0.cmd_o));

  initial begin
     uvm_config_db #(virtual sha1_if)::set(uvm_root::get(),"*","m_if", sha1_if0);

     end
  
initial begin

  run_test();
end
  
endmodule
