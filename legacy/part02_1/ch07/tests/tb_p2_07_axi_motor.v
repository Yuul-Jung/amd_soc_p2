`timescale 1ns/1ps
// AXI tests cover AW/W independent arrivals, held responses, invalid values.
module tb_p2_07_axi_motor;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0;
    reg [5:0] awaddr=0, araddr=0;
    reg [2:0] awprot=0, arprot=0;
    reg awvalid=0,wvalid=0,arvalid=0;
    reg [31:0] wdata=0;
    reg [3:0] wstrb=4'hf;
    reg bready=0,rready=0;
    wire awready,wready,arready,bvalid,rvalid;
    wire [1:0] bresp,rresp;
    wire [31:0] rdata;
    reg sonar_auto=0,sonar_done=0,sonar_valid=0,sonar_unsafe=1;
    wire in1,in2,ena;
    p2_07_axi_motor_v1_0_S00_AXI #(.DEADTIME_CYCLES(3),.FRESH_CYCLES(30)) dut (
      .S_AXI_ACLK(clk),.S_AXI_ARESETN(resetn),
      .S_AXI_AWADDR(awaddr),.S_AXI_AWPROT(awprot),.S_AXI_AWVALID(awvalid),.S_AXI_AWREADY(awready),
      .S_AXI_WDATA(wdata),.S_AXI_WSTRB(wstrb),.S_AXI_WVALID(wvalid),.S_AXI_WREADY(wready),
      .S_AXI_BRESP(bresp),.S_AXI_BVALID(bvalid),.S_AXI_BREADY(bready),
      .S_AXI_ARADDR(araddr),.S_AXI_ARPROT(arprot),.S_AXI_ARVALID(arvalid),.S_AXI_ARREADY(arready),
      .S_AXI_RDATA(rdata),.S_AXI_RRESP(rresp),.S_AXI_RVALID(rvalid),.S_AXI_RREADY(rready),
      .sonic_auto_i(sonar_auto),.sonic_done_i(sonar_done),.sonic_valid_i(sonar_valid),
      .sonic_unsafe_i(sonar_unsafe),.motor_in1_o(in1),.motor_in2_o(in2),.motor_ena_o(ena)
    );
    task tick; begin @(posedge clk);#1;end endtask
    task aw(input [5:0] addr);begin
      @(negedge clk);awaddr=addr;awvalid=1;
      while(!awready) @(negedge clk);
      tick();
      @(negedge clk);awvalid=0;
    end endtask
    task wd(input [31:0] data,input [3:0] strobe);begin
      @(negedge clk);wdata=data;wstrb=strobe;wvalid=1;
      while(!wready) @(negedge clk);
      tick();
      @(negedge clk);wvalid=0;
    end endtask
    task bcheck(input [1:0] expected);begin
      while(!bvalid)tick();
      if(bresp!=expected)$fatal(1,"BRESP mismatch");
      repeat(2) begin tick();if(!bvalid)$fatal(1,"BVALID not held");end
      @(negedge clk);bready=1;tick();@(negedge clk);bready=0;
    end endtask
    task read32(input [5:0] addr,input [1:0] expected);begin
      @(negedge clk);araddr=addr;arvalid=1;
      while(!arready) @(negedge clk);
      tick();
      @(negedge clk);arvalid=0;
      while(!rvalid)tick();
      if(rresp!=expected)$fatal(1,"RRESP mismatch");
      repeat(2)begin tick();if(!rvalid)$fatal(1,"RVALID not held");end
      @(negedge clk);rready=1;tick();@(negedge clk);rready=0;
    end endtask
    initial begin
      tick();tick();resetn=1;tick();
      read32(6'h08,2'b00);
      // AW before W and W before AW, both legal.
      aw(6'h00);repeat(2)tick();wd(32'd1,4'hf);bcheck(2'b00);
      if(ena)$fatal(1,"Unsafe motor enabled");
      wd(32'd2,4'hf);repeat(2)tick();aw(6'h00);bcheck(2'b00);
      aw(6'h00);wd(32'd3,4'hf);bcheck(2'b10);
      aw(6'h0C);wd(32'd0,4'hf);bcheck(2'b10);
      aw(6'h00);wd(32'd0,4'hf);bcheck(2'b00);
      read32(6'h00,2'b00);
      read32(6'h04,2'b00);
      read32(6'h3c,2'b10);
      $display("P2_07_AXI_BUS_PASS");$finish;
    end
endmodule
