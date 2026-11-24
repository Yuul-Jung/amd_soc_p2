`timescale 1ns/1ps
module tb_p2_02_axi_fnd;
    reg clk=0;
    always #5 clk=~clk;
    reg resetn=0;
    reg [5:0] awaddr=0;
    reg [2:0] awprot=0;
    reg awvalid=0;
    wire awready;
    reg [31:0] wdata=0;
    reg [3:0] wstrb=0;
    reg wvalid=0;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg bready=0;
    reg [5:0] araddr=0;
    reg [2:0] arprot=0;
    reg arvalid=0;
    wire arready;
    wire [31:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    reg rready=0;
    wire [6:0] seg;
    wire [3:0] an;
    wire dp;

    p2_02_axi_fnd_v1_0 #(
        .C_S00_AXI_DATA_WIDTH(32),
        .C_S00_AXI_ADDR_WIDTH(6),
        .FND_SCAN_TICKS(3)
    ) dut (
        .s00_axi_aclk(clk), .s00_axi_aresetn(resetn),
        .s00_axi_awaddr(awaddr), .s00_axi_awprot(awprot),
        .s00_axi_awvalid(awvalid), .s00_axi_awready(awready),
        .s00_axi_wdata(wdata), .s00_axi_wstrb(wstrb),
        .s00_axi_wvalid(wvalid), .s00_axi_wready(wready),
        .s00_axi_bresp(bresp), .s00_axi_bvalid(bvalid),
        .s00_axi_bready(bready), .s00_axi_araddr(araddr),
        .s00_axi_arprot(arprot), .s00_axi_arvalid(arvalid),
        .s00_axi_arready(arready), .s00_axi_rdata(rdata),
        .s00_axi_rresp(rresp), .s00_axi_rvalid(rvalid),
        .s00_axi_rready(rready), .fnd_seg(seg), .fnd_an(an), .fnd_dp(dp)
    );

    task require;
        input condition;
        input [200*8-1:0] message;
        begin if (!condition) begin
            $display("FAIL: %0s time=%0t",message,$time); $fatal(1);
        end end
    endtask
    task send_aw;
        input [5:0] address;
        input integer delay_cycles;
        begin
            repeat(delay_cycles) @(negedge clk);
            @(negedge clk); awaddr=address; awvalid=1;
            @(posedge clk);
            while (!awready) @(posedge clk);
            @(negedge clk); awvalid=0;
        end
    endtask
    task send_w;
        input [31:0] value;
        input [3:0] strobe;
        input integer delay_cycles;
        begin
            repeat(delay_cycles) @(negedge clk);
            @(negedge clk); wdata=value; wstrb=strobe; wvalid=1;
            @(posedge clk);
            while (!wready) @(posedge clk);
            @(negedge clk); wvalid=0;
        end
    endtask
    task axi_write;
        input [5:0] address;
        input [31:0] value;
        input [3:0] strobe;
        input integer aw_delay, w_delay;
        input [1:0] response;
        integer count;
        begin
            fork
                send_aw(address,aw_delay);
                send_w(value,strobe,w_delay);
            join
            count=0;
            while (!bvalid && count<30) begin
                @(posedge clk); #1; count=count+1;
            end
            require(bvalid,"write must respond");
            require(bresp===response,"write response code");
            repeat(3) begin
                @(posedge clk); #1;
                require(bvalid,"BVALID must stay asserted under stall");
                require(bresp===response,"BRESP must remain stable");
            end
            @(negedge clk); bready=1;
            @(posedge clk);
            @(negedge clk); bready=0;
            require(!bvalid,"BVALID should clear after handshake");
        end
    endtask
    task axi_read;
        input [5:0] address;
        input [31:0] value;
        input [1:0] response;
        integer count;
        begin
            @(negedge clk); araddr=address; arvalid=1;
            @(posedge clk);
            while (!arready) @(posedge clk);
            @(negedge clk); arvalid=0;
            count=0;
            while(!rvalid && count<30) begin
                @(posedge clk); #1; count=count+1;
            end
            require(rvalid,"read must respond");
            require(rdata===value,"read data mismatch");
            require(rresp===response,"read response mismatch");
            repeat(3) begin
                @(posedge clk); #1;
                require(rvalid,"RVALID must persist during stall");
                require(rdata===value,"RDATA must remain stable during stall");
            end
            @(negedge clk); rready=1;
            @(posedge clk);
            @(negedge clk); rready=0;
            require(!rvalid,"RVALID should clear after handshake");
        end
    endtask
    initial begin
        repeat(3) @(posedge clk);
        @(negedge clk); resetn=1;
        axi_read(6'h00,32'h00000000,2'b00);
        axi_read(6'h04,32'h00000000,2'b00);
        axi_write(6'h00,32'h00001234,4'b0011,0,4,2'b00); // AW before W
        axi_read(6'h00,32'h00001234,2'b00);
        axi_write(6'h04,32'h00000001,4'b0001,4,0,2'b00); // W before AW
        axi_read(6'h04,32'h00000001,2'b00);
        axi_write(6'h00,32'h00000056,4'b0001,0,0,2'b00); // partial strobe
        axi_read(6'h00,32'h00001256,2'b00);
        axi_write(6'h04,32'h00000000,4'b0010,0,0,2'b00); // CTRL[0] must hold
        axi_read(6'h04,32'h00000001,2'b00);
        axi_write(6'h00,32'hFFFFFFFF,4'b0000,0,0,2'b00); // no bytes enabled
        axi_read(6'h00,32'h00001256,2'b00);
        axi_write(6'h10,32'hFFFFFFFF,4'b1111,0,0,2'b10); // invalid address
        axi_read(6'h10,32'h00000000,2'b10);
        axi_read(6'h08,32'h00000000,2'b00); // reserved register
        axi_write(6'h04,32'h00000000,4'b0001,0,0,2'b00);
        repeat(20) @(posedge clk);
        require(an===4'b1111,"FND OFF must deassert all anodes");
        @(negedge clk); resetn=0;
        repeat(2) @(posedge clk);
        @(negedge clk); resetn=1;
        axi_read(6'h00,32'h00000000,2'b00);
        axi_read(6'h04,32'h00000000,2'b00);
        $display("AXI_FND_TB PASS");
        $finish;
    end
    initial begin
        #100000; $display("FAIL: AXI TB timeout"); $fatal(1);
    end
endmodule
