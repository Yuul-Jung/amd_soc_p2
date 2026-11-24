`timescale 1ns/1ps
module tb_p2_06_axi_sonic;
  reg clk=0; always #5 clk=~clk;
  reg resetn=0, echo=0;
  reg [5:0] awaddr=0, araddr=0;
  reg [2:0] awprot=0, arprot=0;
  reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;
  reg [31:0] wdata=0;
  reg [3:0] wstrb=4'hF;
  wire awready,wready,bvalid,arready,rvalid,trig,alert,unsafe;
  wire [1:0] bresp,rresp;
  wire [31:0] rdata;
  reg [31:0] rd;
  p2_06_axi_sonic_v1_0 #(
    .CLK_HZ(1000000),.TIMEOUT_US(1000),.COOLDOWN_US(50)
  ) dut (
    .sonic_echo_i(echo),.sonic_trig_o(trig),
    .sonic_alert_o(alert),.sonic_unsafe_o(unsafe),
    .s00_axi_aclk(clk),.s00_axi_aresetn(resetn),
    .s00_axi_awaddr(awaddr),.s00_axi_awprot(awprot),
    .s00_axi_awvalid(awvalid),.s00_axi_awready(awready),
    .s00_axi_wdata(wdata),.s00_axi_wstrb(wstrb),
    .s00_axi_wvalid(wvalid),.s00_axi_wready(wready),
    .s00_axi_bresp(bresp),.s00_axi_bvalid(bvalid),.s00_axi_bready(bready),
    .s00_axi_araddr(araddr),.s00_axi_arprot(arprot),
    .s00_axi_arvalid(arvalid),.s00_axi_arready(arready),
    .s00_axi_rdata(rdata),.s00_axi_rresp(rresp),.s00_axi_rvalid(rvalid),
    .s00_axi_rready(rready)
  );
  task write_axi;
    input [5:0] a; input [31:0] d; input [3:0] st;
    input integer data_first; input [1:0] expected;
    begin
      @(negedge clk);
      if(data_first!=0) begin
        wdata=d;wstrb=st;wvalid=1;
        do @(posedge clk);while(!wready);
        @(negedge clk);wvalid=0;
        repeat(3) @(negedge clk);
        awaddr=a;awvalid=1;
        do @(posedge clk);while(!awready);
        @(negedge clk);awvalid=0;
      end else begin
        awaddr=a;awvalid=1;
        do @(posedge clk);while(!awready);
        @(negedge clk);awvalid=0;
        repeat(3) @(negedge clk);
        wdata=d;wstrb=st;wvalid=1;
        do @(posedge clk);while(!wready);
        @(negedge clk);wvalid=0;
      end
      wait(bvalid);
      repeat(3) @(negedge clk);
      if(!bvalid || bresp!==expected) $fatal(1,"BRESP/backpressure");
      bready=1;@(negedge clk);bready=0;
    end
  endtask
  task read_axi;
    input [5:0] a;input [1:0] expected;
    begin
      @(negedge clk);araddr=a;arvalid=1;
      do @(posedge clk);while(!arready);
      @(negedge clk);arvalid=0;
      wait(rvalid); rd=rdata;
      repeat(3) @(negedge clk);
      if(!rvalid || rresp!==expected || rdata!==rd) $fatal(1,"R channel hold");
      rready=1;@(negedge clk);rready=0;
    end
  endtask
  initial begin
    repeat(3) @(negedge clk);resetn=1;
    read_axi(6'h18,2'b00); if(rd!==32'h00060001) $fatal(1,"ID");
    read_axi(6'h10,2'b00); if(rd!==32'd20) $fatal(1,"default WARN_CM");
    read_axi(6'h00,2'b00); if(rd!==32'd4) $fatal(1,"default ctrl");
    if(!alert || !unsafe) $fatal(1,"invalid before sample must alert");
    write_axi(6'h10,32'd20,4'hF,1,2'b00); // W before AW
    write_axi(6'h10,32'd100,4'h8,0,2'b00); // strobe ignored
    read_axi(6'h10,2'b00); if(rd!==32'd20) $fatal(1,"WSTRB ignored");
    write_axi(6'h10,32'd0,4'hF,0,2'b10);
    write_axi(6'h10,32'd401,4'hF,0,2'b10);
    write_axi(6'h04,32'd0,4'hF,0,2'b10);
    write_axi(6'h03,32'd0,4'hF,0,2'b10);
    read_axi(6'h24,2'b10);
    write_axi(6'h00,32'd6,4'hF,0,2'b00); // WARN_EN + START
    wait(trig);wait(!trig);
    repeat(5) @(negedge clk);
    echo=1;repeat(580) @(negedge clk);echo=0;
    repeat(10) @(negedge clk);
    read_axi(6'h08,2'b00);if(rd!==32'd10) $fatal(1,"distance 10cm %d",rd);
    read_axi(6'h04,2'b00);if((rd & 2)!=2 || !alert || !unsafe)
        $fatal(1,"near alert");
    read_axi(6'h14,2'b00);if(rd!==32'd1) $fatal(1,"seq1");
    write_axi(6'h00,32'd0,4'hF,0,2'b00); // WARN OFF, auto OFF
    if(alert || !unsafe) $fatal(1,"WARN OFF must not disable UNSAFE");
    write_axi(6'h00,32'd4,4'hF,0,2'b00); // WARN ON
    read_axi(6'h00,2'b00);if(rd!==32'd4) $fatal(1,"ctrl readback");
    $display("RTL_SIM_p2_06_axi_sonic PASS (AW/W, WSTRB, RO, ID, near/fault)");
    $finish;
  end
  initial begin #300000; $fatal(1,"WATCHDOG");end
endmodule
