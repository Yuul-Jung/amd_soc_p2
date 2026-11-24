`timescale 1ns/1ps
module tb_p2_05_axi_cds;
  reg clk=0; always #5 clk=~clk;
  reg resetn=0, cds=1;
  reg [5:0] awaddr=0, araddr=0;
  reg [2:0] awprot=0, arprot=0;
  reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;
  reg [31:0] wdata=0;
  reg [3:0] wstrb=4'hF;
  wire awready,wready,bvalid,arready,rvalid,dark,valid,auto_en;
  wire [1:0] bresp,rresp;
  wire [31:0] rdata;
  reg [31:0] rd;
  p2_05_axi_cds_v1_0 #(.FILTER_CYCLES(4)) dut (
    .cds_digital_i(cds),.cds_dark_o(dark),.cds_valid_o(valid),
    .auto_enable_o(auto_en),.s00_axi_aclk(clk),.s00_axi_aresetn(resetn),
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
      if (data_first!=0) begin
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
      if(!bvalid || bresp!==expected) $fatal(1,"BRESP or BVALID not held");
      bready=1;@(negedge clk);bready=0;
    end
  endtask
  task read_axi;
    input [5:0] a; input [1:0] expected;
    begin
      @(negedge clk);araddr=a;arvalid=1;
      do @(posedge clk); while(!arready);
      @(negedge clk);arvalid=0;
      wait(rvalid);
      rd=rdata;
      repeat(3) @(negedge clk);
      if(!rvalid || rresp!==expected || rdata!==rd) $fatal(1,"R backpressure");
      rready=1;@(negedge clk);rready=0;
    end
  endtask
  initial begin
    repeat(3) @(negedge clk); resetn=1;
    read_axi(6'h08,2'b00); if(rd!==32'h00050001) $fatal(1,"ID");
    read_axi(6'h0C,2'b00); if(rd!==32'd4) $fatal(1,"FILTER parameter");
    read_axi(6'h00,2'b00); if(rd!==32'd2) $fatal(1,"default CTRL");
    write_axi(6'h00,32'd3,4'hF,1,2'b00); // DATA first
    read_axi(6'h00,2'b00); if(rd!==32'd3 || auto_en!==1) $fatal(1,"AUTO enable");
    write_axi(6'h00,32'd0,4'h8,0,2'b00); // high byte-only => no effect
    read_axi(6'h00,2'b00); if(rd!==32'd3) $fatal(1,"WSTRB mask");
    cds=0; repeat(12) @(negedge clk);
    read_axi(6'h04,2'b00);
    if((rd & 32'h3F)!==32'h3E) $fatal(1,"STATUS expected raw=0 dark=1 valid=1 gate=1 auto=1 pol=1");
    write_axi(6'h04,32'd0,4'hF,0,2'b10); // status RO
    write_axi(6'h03,32'd0,4'hF,0,2'b10); // unaligned address
    read_axi(6'h18,2'b10); // unmapped address
    write_axi(6'h00,32'd0,4'h1,0,2'b00); // auto=0, polarity=high
    repeat(12) @(negedge clk);
    read_axi(6'h04,2'b00);
    if((rd>>4 & 3)!==0 || valid!==1 || dark!==0) $fatal(1,"polarity/auto transition");
    $display("RTL_SIM_p2_05_axi_cds PASS (AW/W, WSTRB, B/R, RO, status, polarity)");
    $finish;
  end
  initial begin #400000; $fatal(1,"TIMEOUT"); end
endmodule
