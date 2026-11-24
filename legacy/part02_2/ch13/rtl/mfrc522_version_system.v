`timescale 1ns/1ps
// P2-13: reusable SPI + VersionReg probe subsystem.
// Board-independent: no pin mapping, buttons, LED policy in this module.
// start_pulse synchronously starts VersionReg(0x37) read.
module mfrc522_version_system #(
    parameter integer CLK_DIV=10
)(
    input wire clk, input wire resetn, input wire start_pulse,
    output wire spi_sck, output wire spi_mosi,
    input wire spi_miso, output wire spi_nss,
    output wire [7:0] version,
    output wire done_pulse, output wire busy
);
    wire cmd_valid,cmd_ready,cmd_read,rsp_valid;
    wire [5:0] cmd_addr;
    wire [7:0] cmd_wdata,rsp_rdata;
    mfrc522_version_probe u_probe(
        .clk(clk),.resetn(resetn),.start_pulse(start_pulse),
        .version(version),.done_pulse(done_pulse),.busy(busy),
        .cmd_valid(cmd_valid),.cmd_ready(cmd_ready),
        .cmd_read(cmd_read),.cmd_addr(cmd_addr),.cmd_wdata(cmd_wdata),
        .rsp_rdata(rsp_rdata),.rsp_valid(rsp_valid)
    );
    mfrc522_spi_master #(.CLK_DIV(CLK_DIV)) u_spi(
        .clk(clk),.resetn(resetn),
        .cmd_valid(cmd_valid),.cmd_ready(cmd_ready),
        .cmd_read(cmd_read),.cmd_addr(cmd_addr),.cmd_wdata(cmd_wdata),
        .rsp_rdata(rsp_rdata),.rsp_valid(rsp_valid),
        .spi_sck(spi_sck),.spi_mosi(spi_mosi),
        .spi_miso(spi_miso),.spi_nss(spi_nss)
    );
endmodule
