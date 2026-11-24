`timescale 1ns/1ps
// P2-05 AXI4-Lite CdS digital monitor/configuration slave.
// Offset 0x00 CONTROL: RW bit0 AUTO_ENABLE, bit1 DARK_WHEN_LOW (default 1).
// Offset 0x04 STATUS: RO bit0 RAW_SYNC, 1 DARK, 2 VALID, 3 AUTO_GATE,
//                    bit4 AUTO_ENABLE, bit5 DARK_WHEN_LOW.
// Offset 0x08 ID: RO 0x00050001. Offset 0x0C FILTER_CYCLES: RO.
// AXI AW/W handshakes are independently captured; R/B held under backpressure.
module p2_05_axi_cds_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer FILTER_CYCLES = 2000000
)(
    input wire S_AXI_ACLK, input wire S_AXI_ARESETN,
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input wire [2:0] S_AXI_AWPROT, input wire S_AXI_AWVALID,
    output wire S_AXI_AWREADY,
    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input wire S_AXI_WVALID, output wire S_AXI_WREADY,
    output reg [1:0] S_AXI_BRESP, output reg S_AXI_BVALID,
    input wire S_AXI_BREADY,
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input wire [2:0] S_AXI_ARPROT, input wire S_AXI_ARVALID,
    output wire S_AXI_ARREADY,
    output reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg [1:0] S_AXI_RRESP, output reg S_AXI_RVALID,
    input wire S_AXI_RREADY,
    input wire cds_digital_i,
    output wire cds_dark_o,
    output wire cds_valid_o,
    output wire auto_enable_o
);
    localparam [1:0] RESP_OKAY = 2'b00, RESP_SLVERR = 2'b10;
    reg [1:0] control_reg;
    wire raw_sync;
    wire dark_filtered;
    wire dark_valid;
    wire gate = dark_filtered & dark_valid;
    reg aw_hold, w_hold;
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;
    reg [31:0] wdata_hold;
    reg [3:0] wstrb_hold;
    reg [31:0] merged_data;
    integer i;

    assign auto_enable_o = control_reg[0];
    assign cds_dark_o = dark_filtered;
    assign cds_valid_o = dark_valid;

    cds_digital_core #(.FILTER_CYCLES(FILTER_CYCLES)) u_cds_core (
        .clk(S_AXI_ACLK), .resetn(S_AXI_ARESETN),
        .cds_digital_i(cds_digital_i), .dark_when_low(control_reg[1]),
        .raw_sync(raw_sync), .stable_dark(dark_filtered),
        .stable_valid(dark_valid)
    );

    assign S_AXI_AWREADY = S_AXI_ARESETN && !aw_hold && !S_AXI_BVALID;
    assign S_AXI_WREADY  = S_AXI_ARESETN && !w_hold  && !S_AXI_BVALID;
    assign S_AXI_ARREADY = S_AXI_ARESETN && !S_AXI_RVALID;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            control_reg <= 2'b10; // Safe manual mode; polarity is adjustable.
            aw_hold <= 1'b0; w_hold <= 1'b0;
            awaddr_hold <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wdata_hold <= 32'd0; wstrb_hold <= 4'd0;
            S_AXI_BRESP <= RESP_OKAY;
            S_AXI_BVALID <= 1'b0;
        end else begin
            if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                awaddr_hold <= S_AXI_AWADDR;
                aw_hold <= 1'b1;
            end
            if (S_AXI_WVALID && S_AXI_WREADY) begin
                wdata_hold <= S_AXI_WDATA;
                wstrb_hold <= S_AXI_WSTRB;
                w_hold <= 1'b1;
            end
            if (S_AXI_BVALID && S_AXI_BREADY)
                S_AXI_BVALID <= 1'b0;
            if (aw_hold && w_hold && !S_AXI_BVALID) begin
                aw_hold <= 1'b0;
                w_hold <= 1'b0;
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP <= RESP_OKAY;
                // Only CONTROL is writable; byte masking is honored.
                if (awaddr_hold == 6'h00) begin
                    merged_data = {30'd0,control_reg};
                    for (i=0;i<4;i=i+1)
                        if (wstrb_hold[i])
                            merged_data[i*8 +: 8] = wdata_hold[i*8 +: 8];
                    control_reg <= merged_data[1:0];
                end else
                    S_AXI_BRESP <= RESP_SLVERR;
            end
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RRESP <= RESP_OKAY;
            S_AXI_RVALID <= 1'b0;
            S_AXI_RDATA <= 32'd0;
        end else begin
            if (S_AXI_RVALID && S_AXI_RREADY)
                S_AXI_RVALID <= 1'b0;
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP <= RESP_OKAY;
                case (S_AXI_ARADDR)
                    6'h00: S_AXI_RDATA <= {30'd0,control_reg};
                    6'h04: S_AXI_RDATA <= {26'd0,control_reg[1],control_reg[0],
                                           gate, dark_valid,dark_filtered,raw_sync};
                    6'h08: S_AXI_RDATA <= 32'h00050001;
                    6'h0C: S_AXI_RDATA <= FILTER_CYCLES;
                    default: begin
                        S_AXI_RDATA <= 32'd0;
                        S_AXI_RRESP <= RESP_SLVERR;
                    end
                endcase
            end
        end
    end
endmodule
