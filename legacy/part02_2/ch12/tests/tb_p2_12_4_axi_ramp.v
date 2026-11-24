`timescale 1ns/1ps
// P2-12 AXI IP 회귀: AW/W 독립 도착, WSTRB, 레지스터, 모터 출력,
// BUSY/완료/오류/STOP을 포함한 self-checking testbench.
module tb_p2_12_4_axi_ramp;
    reg clk=0; always #5 clk=~clk;
    reg resetn=0;
    reg [5:0] awaddr=0,araddr=0;
    reg [2:0] awprot=0,arprot=0;
    reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;
    reg [31:0] wdata=0;
    reg [3:0] wstrb=4'hf;
    wire awready,wready,bvalid,arready,rvalid;
    wire [1:0] bresp,rresp;
    wire [31:0] rdata;
    wire [3:0] coil;
    reg [31:0] read_value;
    p2_12_axi_stepper_v1_1 #(
        .MIN_STEP_CYCLES(32'd2),
        .RESET_STEP_PERIOD(32'd3)
    ) dut (
        .S_AXI_ACLK(clk),.S_AXI_ARESETN(resetn),
        .S_AXI_AWADDR(awaddr),.S_AXI_AWPROT(awprot),
        .S_AXI_AWVALID(awvalid),.S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata),.S_AXI_WSTRB(wstrb),
        .S_AXI_WVALID(wvalid),.S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp),.S_AXI_BVALID(bvalid),
        .S_AXI_BREADY(bready),
        .S_AXI_ARADDR(araddr),.S_AXI_ARPROT(arprot),
        .S_AXI_ARVALID(arvalid),.S_AXI_ARREADY(arready),
        .S_AXI_RDATA(rdata),.S_AXI_RRESP(rresp),
        .S_AXI_RVALID(rvalid),.S_AXI_RREADY(rready),
        .stepper_coil_o(coil)
    );
    task wr;
        input [5:0] addr;
        input [31:0] data;
        input [3:0] strobe;
        input integer w_first;
        input [1:0] expected;
        begin
            @(negedge clk);
            if(w_first) begin
                wdata=data; wstrb=strobe; wvalid=1;
                do @(posedge clk); while(!wready);
                @(negedge clk); wvalid=0;
                repeat(2) @(negedge clk);
                awaddr=addr; awvalid=1;
                do @(posedge clk); while(!awready);
                @(negedge clk); awvalid=0;
            end else begin
                awaddr=addr; awvalid=1;
                do @(posedge clk); while(!awready);
                @(negedge clk); awvalid=0;
                repeat(2) @(negedge clk);
                wdata=data; wstrb=strobe; wvalid=1;
                do @(posedge clk); while(!wready);
                @(negedge clk); wvalid=0;
            end
            wait(bvalid); @(negedge clk);
            if(bresp !== expected)
                $fatal(1,"write 0x%h bresp=%b expected=%b",addr,bresp,expected);
            bready=1;
            @(negedge clk); bready=0;
        end
    endtask
    task rd;
        input [5:0] addr;
        input [1:0] expected;
        begin
            @(negedge clk); araddr=addr; arvalid=1;
            do @(posedge clk); while(!arready);
            @(negedge clk); arvalid=0;
            wait(rvalid); @(negedge clk);
            if(rresp!==expected) $fatal(1,"read 0x%h rresp",addr);
            read_value=rdata;
            rready=1;
            @(negedge clk); rready=0;
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); resetn=1;
        rd(6'h18,2'b00); if(read_value!==32'h000c0002) $fatal(1,"ID");
        rd(6'h1c,2'b00); if(read_value!==32'd2) $fatal(1,"MIN");
        wr(6'h00,32'd4,4'hf,1,2'b00);
        wr(6'h04,32'd3,4'hf,0,2'b00);
        wr(6'h20,32'd2,4'hf,0,2'b00); // CRUISE=2
        wr(6'h24,32'd1,4'hf,0,2'b00); // DELTA=1
        wr(6'h28,32'd1,4'hf,0,2'b00); // RAMP_STEPS=1
        wr(6'h08,32'd2,4'hf,1,2'b00); // Half Step
        wr(6'h08,32'd0,4'h8,0,2'b00); // WSTRB upper byte only
        rd(6'h08,2'b00);
        if(read_value !== 2) $fatal(1,"WSTRB control");
        wr(6'h0c,32'd1,4'h1,0,2'b00);
        wait(dut.u_core.steps_done >= 1); #1;
        if(coil !== 4'b0001) $fatal(1,"step1 pattern %b",coil);
        wait(dut.done_sticky == 1); #1;
        rd(6'h14,2'b00);
        if(read_value!==4) $fatal(1,"completed 4 steps");
        rd(6'h10,2'b00);
        if(read_value[1]!==1 || read_value[0]!==0) $fatal(1,"status done/busy");
        if(coil!==4'b0000) $fatal(1,"coil not released");
        rd(6'h20,2'b00); if(read_value!==2) $fatal(1,"cruise reg");
        rd(6'h24,2'b00); if(read_value!==1) $fatal(1,"delta reg");
        rd(6'h28,2'b00); if(read_value!==1) $fatal(1,"ramp reg");
        rd(6'h2c,2'b00); if(read_value!==3) $fatal(1,"active at end");
        $display("P2_12_4_AXI_RAMP_BASIC PASS");

        wr(6'h00,32'd0,4'hf,0,2'b00);
        wr(6'h0c,32'd1,4'h1,1,2'b10);
        rd(6'h10,2'b00);
        if(read_value[2]!==1) $fatal(1,"error sticky");
        wr(6'h04,32'd1,4'hf,0,2'b00);
        wr(6'h00,32'd5,4'hf,0,2'b00);
        wr(6'h0c,32'd1,4'h1,0,2'b10);
        $display("P2_12_4_AXI_INVALID_CONFIG PASS");

        wr(6'h04,32'd3,4'hf,0,2'b00);
        wr(6'h0c,32'd1,4'h1,0,2'b00);
        wait(dut.u_core.busy); #1;
        // 코일 출력 중 STOP에서 모든 출력을 제어 레벨로 차단.
        wait(dut.u_core.steps_done >= 1); #1;
        wr(6'h0c,32'd2,4'h1,1,2'b00);
        repeat(3) @(negedge clk);
        if(coil!==0 || dut.u_core.busy) $fatal(1,"STOP coils");
        $display("P2_12_4_AXI_STOP PASS");
        rd(6'h3c,2'b10);
        wr(6'h3c,32'd1,4'hf,0,2'b10);
        wr(6'h18,32'd1,4'hf,0,2'b10); // ID is read-only
        wr(6'h0c,32'd3,4'h1,0,2'b10); // simultaneous start/stop invalid
        $display("P2_12_4_AXI_ERROR_RESP PASS");
        $display("P2_12_4_AXI_STEPPER PASS");
        $finish;
    end
    initial begin #1000000; $fatal(1,"TIMEOUT"); end
endmodule
