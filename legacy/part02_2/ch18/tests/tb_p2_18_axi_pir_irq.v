`timescale 1ns/1ps
module tb_p2_18_axi_pir_irq;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,pir=0;
    reg [5:0] awaddr=0,araddr=0;
    reg awvalid=0,wvalid=0,arvalid=0;
    reg [31:0] wdata=0;
    reg [3:0] wstrb=4'hf;
    reg bready=0,rready=0;
    wire awready,wready,bvalid,arready,rvalid,irq;
    wire [31:0] rdata;
    wire [1:0] bresp,rresp;
    reg [31:0] result;
    p2_18_axi_pir_irq_v1_0 #(
        .WARMUP_CYCLES(64'd12),.FILTER_CYCLES(3)
    ) dut (
        .S_AXI_ACLK(clk),.S_AXI_ARESETN(resetn),
        .S_AXI_AWADDR(awaddr),.S_AXI_AWPROT(3'b0),
        .S_AXI_AWVALID(awvalid),.S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata),.S_AXI_WSTRB(wstrb),
        .S_AXI_WVALID(wvalid),.S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp),.S_AXI_BVALID(bvalid),
        .S_AXI_BREADY(bready),.S_AXI_ARADDR(araddr),
        .S_AXI_ARPROT(3'b0),.S_AXI_ARVALID(arvalid),
        .S_AXI_ARREADY(arready),.S_AXI_RDATA(rdata),
        .S_AXI_RRESP(rresp),.S_AXI_RVALID(rvalid),
        .S_AXI_RREADY(rready),.pir_in_async(pir),.irq(irq)
    );
    task write_reg;
        input [5:0] address;
        input [31:0] data;
        input [3:0] strb;
        input [1:0] expect_resp;
        begin
            // AW then W deliberately arrive on separate cycles.
            @(negedge clk);awaddr=address;awvalid=1;
            @(posedge clk);if(!awready)$fatal(1,"AW not ready");
            @(negedge clk);awvalid=0;wdata=data;wstrb=strb;wvalid=1;
            @(posedge clk);if(!wready)$fatal(1,"W not ready");
            @(negedge clk);wvalid=0;
            wait(bvalid);#1;
            if(bresp!==expect_resp)
                $fatal(1,"BRESP address=%h expected=%h got=%h",
                    address,expect_resp,bresp);
            @(negedge clk);bready=1;
            @(negedge clk);bready=0;
        end
    endtask
    task read_reg;
        input [5:0] address;
        input [1:0] expect_resp;
        begin
            @(negedge clk);araddr=address;arvalid=1;
            @(posedge clk);if(!arready)$fatal(1,"AR not ready");
            @(negedge clk);arvalid=0;
            wait(rvalid);#1;
            result=rdata;
            if(rresp!==expect_resp)
                $fatal(1,"RRESP address=%h expected=%h got=%h",
                     address,expect_resp,rresp);
            @(negedge clk);rready=1;
            @(negedge clk);rready=0;
        end
    endtask
    task advance;
        input integer cycles;
        integer i;
        begin for(i=0;i<cycles;i=i+1)@(negedge clk);end
    endtask
    initial begin
        advance(4);resetn=1;advance(17);
        read_reg(6'h10,2'b00);
        if(result!==32'h00180001) $fatal(1,"IP ID");
        read_reg(6'h00,2'b00);
        if(result!==0 || irq) $fatal(1,"default CTRL not safe");
        $display("P2_18_AXI_ID_RESET_PASS");

        // A zero write-strobe must not change CTRL.
        write_reg(6'h00,32'h3,4'h0,2'b00);
        read_reg(6'h00,2'b00);
        if(result!==0) $fatal(1,"WSTRB ignored");
        write_reg(6'h00,32'h3,4'h1,2'b00);
        read_reg(6'h00,2'b00);
        if(result!==3) $fatal(1,"CTRL write failed");
        $display("P2_18_AXI_WSTRB_CTRL_PASS");

        @(negedge clk);pir=1;advance(12);
        if(!irq)$fatal(1,"IRQ not asserted");
        read_reg(6'h08,2'b00);
        if(result[3:0]!==4'b1111)$fatal(1,"STATUS incorrect %h",result);
        read_reg(6'h0c,2'b00);
        if(result!==1) $fatal(1,"count missing");
        $display("P2_18_AXI_IRQ_STATUS_COUNT_PASS");

        write_reg(6'h00,32'h1,4'h1,2'b00);
        advance(3);if(irq!==0) $fatal(1,"mask ineffective");
        read_reg(6'h08,2'b00);
        if(result[2]!==1) $fatal(1,"mask erased pending");
        write_reg(6'h00,32'h3,4'h1,2'b00);
        advance(2);if(!irq) $fatal(1,"unmask lost pending");
        write_reg(6'h04,32'h1,4'h1,2'b00);advance(3);
        if(irq!==0) $fatal(1,"ACK failed");
        read_reg(6'h0c,2'b00);
        if(result!==1) $fatal(1,"ACK cleared counter");
        $display("P2_18_AXI_IRQ_MASK_ACK_PASS");

        write_reg(6'h04,32'h2,4'h1,2'b00);advance(3);
        read_reg(6'h0c,2'b00);
        if(result!==0) $fatal(1,"COUNT_CLEAR failed");
        write_reg(6'h0c,32'hffff,4'hf,2'b10);
        read_reg(6'h04,2'b10);
        read_reg(6'h15,2'b10);
        $display("P2_18_AXI_ERROR_RESP_PASS");
        $display("P2_18_AXI_PIR_IRQ_PASS");
        $finish;
    end
    initial begin #250000;$fatal(1,"TIMEOUT");end
endmodule
