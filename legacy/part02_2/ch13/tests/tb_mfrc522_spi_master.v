`timescale 1ns/1ps
module tb_mfrc522_spi_master;
    reg clk=0; always #5 clk=~clk;
    reg resetn=0,cmd_valid=0,cmd_read=0;
    reg [5:0] addr=0;
    reg [7:0] wdata=0;
    wire cmd_ready,rsp_valid,sck,mosi,nss;
    wire [7:0] rdata;
    reg miso=0;
    reg [15:0] actual_tx;
    reg [15:0] response_pattern=16'h00A5;
    integer rise_count;
    integer done_count=0;
    mfrc522_spi_master #(.CLK_DIV(3)) dut(
        .clk(clk),.resetn(resetn),.cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),.cmd_read(cmd_read),.cmd_addr(addr),
        .cmd_wdata(wdata),.rsp_rdata(rdata),.rsp_valid(rsp_valid),
        .spi_sck(sck),.spi_mosi(mosi),.spi_miso(miso),.spi_nss(nss)
    );
    // Slave prepares MISO on falling edge; first response bit already
    // present before first rising edge (first byte discarded by master).
    always @(negedge sck) begin
        if (!nss && rise_count < 16)
            miso = response_pattern[15-rise_count];
    end
    always @(posedge sck) begin
        if(nss) $fatal(1,"NSS not low during SCK");
        actual_tx[15-rise_count]=mosi;
        rise_count=rise_count+1;
    end
    always @(posedge rsp_valid) begin
        done_count=done_count+1;
        if(!nss || sck) $fatal(1,"response while bus active");
    end
    task transmit;
        input rd;
        input [5:0] address;
        input [7:0] data;
        input [15:0] expect_tx;
        input [7:0] expect_rx;
        begin
            @(negedge clk);
            cmd_read=rd;addr=address;wdata=data;cmd_valid=1;
            rise_count=0;actual_tx=0;
            response_pattern={8'h00,expect_rx};
            miso=0;
            @(negedge clk);cmd_valid=0;
            wait(rsp_valid);
            #1;
            if(rise_count!=16) $fatal(1,"expected 16 SCK rising edges, got %0d",rise_count);
            if(actual_tx !== expect_tx)
                $fatal(1,"MOSI expected=%04h got=%04h",expect_tx,actual_tx);
            if(rdata !== expect_rx)
                $fatal(1,"MISO expected=%02h got=%02h",expect_rx,rdata);
            @(negedge clk);
            if(!cmd_ready || !nss) $fatal(1,"not idle after response");
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);resetn=1;
        if(nss!==1 || sck!==0) $fatal(1,"idle polarity");
        // Read VersionReg 0x37 → address byte EE, dummy 00.
        transmit(1,6'h37,8'hcc,16'hEE00,8'h92);
        $display("P2_13_SPI_VERSION_REGISTER_READ PASS");
        // Write arbitrary test register 0x14: addr=0x28, value=0x5A.
        transmit(0,6'h14,8'h5A,16'h285A,8'hA5);
        $display("P2_13_SPI_REGISTER_WRITE PASS");
        // Busy command request must be ignored.
        if(done_count!=2) $fatal(1,"unexpected extra response");
        $display("P2_13_SPI_MASTER_RTL PASS");
        $finish;
    end
    initial begin #200000; $fatal(1,"TIMEOUT");end
endmodule
