`timescale 1ns/1ps
module tb_p2_03_axi_buttons;
    reg clk=0, resetn=0;
    always #5 clk=~clk;
    reg [5:0] awaddr=0, araddr=0;
    reg [2:0] awprot=0, arprot=0;
    reg awvalid=0, wvalid=0, arvalid=0;
    wire awready,wready,arready;
    reg [31:0] wdata=0;
    reg [3:0] wstrb=4'hf;
    reg bready=0, rready=0;
    wire [1:0] bresp,rresp;
    wire bvalid,rvalid;
    wire [31:0] rdata;
    reg [7:0] event_pulse=0;
    reg [3:0] pressed=0;
    wire irq;
    p2_03_axi_buttons_v1_0_S00_AXI dut(
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(resetn),
        .S_AXI_AWADDR(awaddr), .S_AXI_AWPROT(awprot),
        .S_AXI_AWVALID(awvalid), .S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata), .S_AXI_WSTRB(wstrb),
        .S_AXI_WVALID(wvalid), .S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp), .S_AXI_BVALID(bvalid), .S_AXI_BREADY(bready),
        .S_AXI_ARADDR(araddr), .S_AXI_ARPROT(arprot),
        .S_AXI_ARVALID(arvalid), .S_AXI_ARREADY(arready),
        .S_AXI_RDATA(rdata), .S_AXI_RRESP(rresp), .S_AXI_RVALID(rvalid),
        .S_AXI_RREADY(rready), .event_pulse(event_pulse),
        .pressed(pressed), .irq(irq)
    );
    task tick(input integer n);
        integer i;
        begin for(i=0;i<n;i=i+1) begin @(posedge clk); #1; end end
    endtask
    task write_reg(input [5:0] addr,input [31:0] value,input [3:0] strb,input integer aw_first);
        begin
            @(negedge clk); awaddr=addr;wdata=value;wstrb=strb;
            if(aw_first) begin
                awvalid=1; @(negedge clk);awvalid=0; tick(2);
                @(negedge clk);wvalid=1;@(negedge clk);wvalid=0;
            end else begin
                wvalid=1; @(negedge clk); wvalid=0;tick(2);
                @(negedge clk);awvalid=1;@(negedge clk);awvalid=0;
            end
            wait(bvalid===1); #1;
            if (bresp !== 2'b00) $fatal(1,"unexpected write resp %b",bresp);
            @(negedge clk); bready=1;
            @(negedge clk); bready=0;
        end
    endtask
    task read_check(input [5:0] addr,input [31:0] expected);
        begin
            @(negedge clk);araddr=addr;arvalid=1;
            @(negedge clk);arvalid=0;
            wait(rvalid===1);#1;
            if(rresp!==2'b00 || rdata!==expected)
                $fatal(1,"read[%h] got %h expected %h resp=%b",addr,rdata,expected,rresp);
            @(negedge clk);rready=1;
            @(negedge clk);rready=0;
        end
    endtask
    initial begin
        tick(4); resetn=1; tick(2);
        read_check(0,0);
        read_check(4,0);
        read_check(12,32'h00030001);
        // Event retained with mask 0; IRQ not asserted.
        @(negedge clk); event_pulse=8'h11;
        @(negedge clk); event_pulse=0;
        read_check(0,32'h11);
        if(irq) $fatal(1,"IRQ high while disabled");
        write_reg(4,32'h11,4'b0001,1); // AW first
        read_check(4,32'h11);
        if(!irq) $fatal(1,"IRQ failed to assert after enable");
        write_reg(0,32'h01,4'b0001,0); // W first, clear short-UP
        read_check(0,32'h10);
        if(!irq) $fatal(1,"IRQ should remain for long-UP");
        write_reg(0,32'h10,4'b0001,1);
        read_check(0,0);
        if(irq) $fatal(1,"IRQ not deasserted after W1C");
        // WSTRB=0 must not clear pending bits.
        @(negedge clk);event_pulse=8'h02;
        @(negedge clk);event_pulse=0;
        write_reg(0,32'h02,4'b0000,1);
        read_check(0,32'h02);
        write_reg(0,32'h02,4'b0001,1);
        read_check(0,0);
        // Duplicate event of the same type while pending sets COALESCED flag.
        @(negedge clk); event_pulse=8'h04;
        @(negedge clk); event_pulse=0;
        read_check(0,32'h04);
        @(negedge clk); event_pulse=8'h04;
        @(negedge clk); event_pulse=0;
        read_check(16,32'h04);
        write_reg(0,32'h04,4'b0001,1);
        write_reg(16,32'h04,4'b0001,1);
        read_check(0,0);
        read_check(16,0);
        // Event SET must win if it coincides with W1C of the same bit.
        @(negedge clk); event_pulse=8'h01;
        @(negedge clk); event_pulse=0;
        fork
            write_reg(0,32'h01,4'b0001,1);
            begin
                wait(dut.complete_write===1'b1);
                @(negedge clk); event_pulse=8'h01;
                @(negedge clk); event_pulse=0;
            end
        join
        read_check(0,32'h01);
        write_reg(0,32'h01,4'b0001,1);
        read_check(0,0);
        // Stable pressed state can be read, no interrupt generated.
        @(negedge clk);pressed=4'h5;
        read_check(8,32'h5);
        $display("RTL_SIM_axi_buttons PASS");
        $finish;
    end
endmodule
