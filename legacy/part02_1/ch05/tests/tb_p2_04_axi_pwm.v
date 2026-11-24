`timescale 1ns/1ps
module tb_p2_04_axi_pwm;
  reg clk = 0;
  always #5 clk = ~clk;
  reg resetn=0;
  reg [5:0] awaddr=0, araddr=0;
  reg [2:0] awprot=0, arprot=0;
  reg awvalid=0, wvalid=0, bready=0, arvalid=0, rready=0;
  reg [31:0] wdata=0;
  reg [3:0] wstrb=4'hF;
  wire awready,wready,bvalid,arready,rvalid,pwm_led_o;
  wire [1:0] bresp,rresp;
  wire [31:0] rdata;
  reg [31:0] read_value;
  integer high, i;
  p2_04_axi_pwm_v1_0 #(.C_S00_AXI_ADDR_WIDTH(6)) dut (
    .pwm_led_o(pwm_led_o), .s00_axi_aclk(clk), .s00_axi_aresetn(resetn),
    .s00_axi_awaddr(awaddr), .s00_axi_awprot(awprot),
    .s00_axi_awvalid(awvalid), .s00_axi_awready(awready),
    .s00_axi_wdata(wdata), .s00_axi_wstrb(wstrb),
    .s00_axi_wvalid(wvalid), .s00_axi_wready(wready),
    .s00_axi_bresp(bresp), .s00_axi_bvalid(bvalid), .s00_axi_bready(bready),
    .s00_axi_araddr(araddr), .s00_axi_arprot(arprot),
    .s00_axi_arvalid(arvalid), .s00_axi_arready(arready),
    .s00_axi_rdata(rdata), .s00_axi_rresp(rresp),
    .s00_axi_rvalid(rvalid), .s00_axi_rready(rready)
  );
  task axi_write;
    input [5:0] a;
    input [31:0] d;
    input [3:0] strb;
    input integer w_first;
    input [1:0] expected_resp;
    begin
      // Separate AW/W by several cycles, test each arrival order.
      @(negedge clk);
      if (w_first) begin
        wdata=d; wstrb=strb; wvalid=1;
        do @(posedge clk); while (!wready);
        @(negedge clk); wvalid=0;
        repeat(3) @(negedge clk);
        awaddr=a; awvalid=1;
        do @(posedge clk); while (!awready);
        @(negedge clk); awvalid=0;
      end else begin
        awaddr=a; awvalid=1;
        do @(posedge clk); while (!awready);
        @(negedge clk); awvalid=0;
        repeat(3) @(negedge clk);
        wdata=d; wstrb=strb; wvalid=1;
        do @(posedge clk); while (!wready);
        @(negedge clk); wvalid=0;
      end
      wait(bvalid);
      repeat(2) @(negedge clk);
      if (bvalid !== 1 || bresp !== expected_resp) $fatal(1,"write response");
      bready=1;
      @(negedge clk); bready=0;
    end
  endtask
  task axi_read;
    input [5:0] a;
    input [1:0] expected_resp;
    begin
      @(negedge clk); araddr=a; arvalid=1;
      do @(posedge clk); while (!arready);
      @(negedge clk); arvalid=0;
      wait(rvalid);
      repeat(2) @(negedge clk);
      if (rvalid !== 1 || rresp !== expected_resp) $fatal(1,"read response");
      read_value=rdata;
      rready=1;
      @(negedge clk); rready=0;
    end
  endtask
  initial begin
    repeat(3) @(negedge clk); resetn=1;
    axi_read(6'h1C,2'b00);
    if(read_value!==32'h00040001) $fatal(1,"IP ID mismatch");
    axi_write(6'h00,32'd10,4'hF,1,2'b00); // W first
    axi_write(6'h04,32'd5,4'hF,0,2'b00);  // AW first
    axi_write(6'h08,32'd1,4'hF,1,2'b00);
    // WSTRB[3] must not overwrite lowest control byte.
    axi_write(6'h08,32'h00000000,4'h8,0,2'b00);
    axi_read(6'h08,2'b00);
    if(read_value!==32'd1) $fatal(1,"WSTRB failed");
    axi_write(6'h0C,32'd1,4'h1,0,2'b00);
    // 최초 활성 주기는 RESET_PERIOD=100000이다. APPLY는 현재 주기 경계에서
    // 반영되므로 그 경계를 지난 뒤 ACTIVE 값을 읽는다.
    repeat(100010) @(negedge clk);
    axi_read(6'h14,2'b00); if(read_value!==10) $fatal(1,"active period");
    axi_read(6'h18,2'b00); if(read_value!==5) $fatal(1,"active duty");
    high=0;
    for (i=0;i<20;i=i+1) begin
      @(negedge clk); if(pwm_led_o) high=high+1;
    end
    if(high!==10) $fatal(1,"PWM duty 50%%: high=%0d",high);
    // Duty must not exceed period: APPLY yields SLVERR.
    axi_write(6'h04,32'd11,4'hF,0,2'b00);
    axi_write(6'h0C,32'd1,4'h1,0,2'b10);
    axi_read(6'h18,2'b00); if(read_value!==5) $fatal(1,"invalid apply altered duty");
    axi_read(6'h3C,2'b10);
    axi_write(6'h3C,32'd0,4'hF,0,2'b10);
    // Restore duty=100% and then duty=0%; output should be DC high/low.
    axi_write(6'h04,32'd10,4'hF,0,2'b00);
    axi_write(6'h0C,32'd1,4'hF,0,2'b00);
    repeat(20) @(negedge clk);
    for(i=0;i<20;i=i+1) begin
      @(negedge clk); if(pwm_led_o!==1) $fatal(1,"100 percent DC");
    end
    axi_write(6'h04,32'd0,4'hF,0,2'b00);
    axi_write(6'h0C,32'd1,4'hF,0,2'b00);
    repeat(20) @(negedge clk);
    for(i=0;i<20;i=i+1) begin
      @(negedge clk); if(pwm_led_o!==0) $fatal(1,"0 percent DC");
    end
    $display("RTL_SIM_p2_04_axi_pwm PASS (AW/W order, WSTRB, B/R backpressure, errors, PWM)");
    $finish;
  end
  initial begin #2000000; $fatal(1,"TIMEOUT"); end
endmodule
