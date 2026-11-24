`timescale 1ns/1ps
// P2-06 Vivado IP Packager external shell; 32-bit AXI4-Lite only.
module p2_06_axi_sonic_v1_0 #(
    parameter integer C_S00_AXI_DATA_WIDTH=32,
    parameter integer C_S00_AXI_ADDR_WIDTH=6,
    parameter integer CLK_HZ=100000000,
    parameter integer TIMEOUT_US=38000,
    parameter integer COOLDOWN_US=60000
)(
    input wire sonic_echo_i, output wire sonic_trig_o,
    output wire sonic_alert_o, output wire sonic_unsafe_o,
    output wire sonic_auto_o, output wire sonic_done_o, output wire sonic_valid_o,
    input wire s00_axi_aclk, input wire s00_axi_aresetn,
    input wire [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_awaddr,
    input wire [2:0] s00_axi_awprot, input wire s00_axi_awvalid,
    output wire s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb,
    input wire s00_axi_wvalid, output wire s00_axi_wready,
    output wire [1:0] s00_axi_bresp, output wire s00_axi_bvalid,
    input wire s00_axi_bready,
    input wire [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_araddr,
    input wire [2:0] s00_axi_arprot, input wire s00_axi_arvalid,
    output wire s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_rdata,
    output wire [1:0] s00_axi_rresp, output wire s00_axi_rvalid,
    input wire s00_axi_rready
);
    p2_06_axi_sonic_v1_0_S00_AXI #(
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH),
        .CLK_HZ(CLK_HZ),.TIMEOUT_US(TIMEOUT_US),
        .COOLDOWN_US(COOLDOWN_US)
    ) u_axi (
        .S_AXI_ACLK(s00_axi_aclk),.S_AXI_ARESETN(s00_axi_aresetn),
        .S_AXI_AWADDR(s00_axi_awaddr),.S_AXI_AWPROT(s00_axi_awprot),
        .S_AXI_AWVALID(s00_axi_awvalid),.S_AXI_AWREADY(s00_axi_awready),
        .S_AXI_WDATA(s00_axi_wdata),.S_AXI_WSTRB(s00_axi_wstrb),
        .S_AXI_WVALID(s00_axi_wvalid),.S_AXI_WREADY(s00_axi_wready),
        .S_AXI_BRESP(s00_axi_bresp),.S_AXI_BVALID(s00_axi_bvalid),
        .S_AXI_BREADY(s00_axi_bready),
        .S_AXI_ARADDR(s00_axi_araddr),.S_AXI_ARPROT(s00_axi_arprot),
        .S_AXI_ARVALID(s00_axi_arvalid),.S_AXI_ARREADY(s00_axi_arready),
        .S_AXI_RDATA(s00_axi_rdata),.S_AXI_RRESP(s00_axi_rresp),
        .S_AXI_RVALID(s00_axi_rvalid),.S_AXI_RREADY(s00_axi_rready),
        .sonic_echo_i(sonic_echo_i),.sonic_trig_o(sonic_trig_o),
        .sonic_alert_o(sonic_alert_o),.sonic_unsafe_o(sonic_unsafe_o),
        .sonic_auto_o(sonic_auto_o),.sonic_done_o(sonic_done_o),
        .sonic_valid_o(sonic_valid_o)
    );
endmodule
