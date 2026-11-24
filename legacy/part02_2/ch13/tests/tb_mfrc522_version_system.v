`timescale 1ns/1ps
// Full register-level path: start → probe → SPI master → modeled MFRC522.
module tb_mfrc522_version_system;
    reg clk=0; always #5 clk=~clk;
    reg resetn=0,start=0,miso=0;
    wire sck,mosi,nss,done,busy;
    wire [7:0] version;
    reg [15:0] observed=16'd0;
    integer bit_count=0;
    integer transactions=0;
    mfrc522_version_system #(.CLK_DIV(4)) dut(
        .clk(clk),.resetn(resetn),.start_pulse(start),
        .spi_sck(sck),.spi_mosi(mosi),.spi_miso(miso),.spi_nss(nss),
        .version(version),.done_pulse(done),.busy(busy)
    );
    // Fake MFRC522 VersionReg responds 0x92; status byte ignored.
    always @(negedge sck)
        if(!nss && bit_count<16)
            miso = (16'h0092 >> (15-bit_count)) & 1'b1;
    always @(posedge sck) begin
        observed[15-bit_count]=mosi;
        bit_count=bit_count+1;
    end
    always @(posedge nss) begin
        if (bit_count==16) transactions=transactions+1;
    end
    initial begin
        repeat(4) @(negedge clk); resetn=1;
        @(negedge clk);start=1;
        @(negedge clk);start=0;
        wait(done); #1;
        if(version!==8'h92) $fatal(1,"expected VersionReg 92, got %02x",version);
        if(observed!==16'hee00) $fatal(1,"expected EE00 MOSI, got %04x",observed);
        if(busy!==0 || nss!==1) $fatal(1,"busy/nss not released");
        if(transactions!=1 || bit_count!=16) $fatal(1,"expected one transaction");
        $display("P2_13_VERSION_PROBE_SYSTEM PASS");
        $finish;
    end
    initial begin #300000;$fatal(1,"TIMEOUT");end
endmodule
