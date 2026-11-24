`timescale 1ns / 1ps
// P2-02: a single-outstanding AXI4-Lite slave with independent AW/W capture.
// REG0 0x00: DISP_VALUE (16-bit packed BCD), reset 0x0000.
// REG1 0x04: DISP_CTRL bit0 (enable), reset 0.
// REG2 0x08 and REG3 0x0C: reserved, reads return zero, writes SLVERR.
module p2_02_axi_fnd_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)(
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire [2:0]                        S_AXI_AWPROT,
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,
    output reg  [1:0]                        S_AXI_BRESP,
    output reg                               S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire [2:0]                        S_AXI_ARPROT,
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,
    output reg  [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output reg  [1:0]                        S_AXI_RRESP,
    output reg                               S_AXI_RVALID,
    input  wire                              S_AXI_RREADY,
    output reg  [15:0]                       reg_disp_bcd,
    output reg                               reg_disp_enable
);
    reg                                  aw_captured;
    reg                                  w_captured;
    reg [C_S_AXI_ADDR_WIDTH-1:0]         held_awaddr;
    reg [C_S_AXI_DATA_WIDTH-1:0]         held_wdata;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0]     held_wstrb;

    // Do not accept a second write until the response was consumed.
    // AW and W may arrive in either order (or in the same cycle).
    assign S_AXI_AWREADY = S_AXI_ARESETN && !aw_captured && !S_AXI_BVALID;
    assign S_AXI_WREADY  = S_AXI_ARESETN && !w_captured  && !S_AXI_BVALID;
    assign S_AXI_ARREADY = S_AXI_ARESETN && !S_AXI_RVALID;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            aw_captured     <= 1'b0;
            w_captured      <= 1'b0;
            held_awaddr     <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            held_wdata      <= {C_S_AXI_DATA_WIDTH{1'b0}};
            held_wstrb      <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};
            S_AXI_BRESP     <= 2'b00;
            S_AXI_BVALID    <= 1'b0;
            S_AXI_RDATA     <= {C_S_AXI_DATA_WIDTH{1'b0}};
            S_AXI_RRESP     <= 2'b00;
            S_AXI_RVALID    <= 1'b0;
            reg_disp_bcd    <= 16'h0000;
            reg_disp_enable <= 1'b0;
        end else begin
            if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                aw_captured <= 1'b1;
                held_awaddr <= S_AXI_AWADDR;
            end
            if (S_AXI_WVALID && S_AXI_WREADY) begin
                w_captured <= 1'b1;
                held_wdata <= S_AXI_WDATA;
                held_wstrb <= S_AXI_WSTRB;
            end
            if (aw_captured && w_captured && !S_AXI_BVALID) begin
                S_AXI_BRESP  <= 2'b00; // OKAY
                S_AXI_BVALID <= 1'b1;
                aw_captured  <= 1'b0;
                w_captured   <= 1'b0;
                case (held_awaddr)
                    0: begin
                        if (held_wstrb[0]) reg_disp_bcd[7:0]  <= held_wdata[7:0];
                        if (held_wstrb[1]) reg_disp_bcd[15:8] <= held_wdata[15:8];
                    end
                    4: begin
                        if (held_wstrb[0]) reg_disp_enable <= held_wdata[0];
                    end
                    default: S_AXI_BRESP <= 2'b10; // SLVERR
                endcase
            end
            if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end

            // RDATA and RRESP remain stable while RVALID && !RREADY.
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP  <= 2'b00;
                S_AXI_RDATA  <= {C_S_AXI_DATA_WIDTH{1'b0}};
                case (S_AXI_ARADDR)
                    0: S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-16){1'b0}}, reg_disp_bcd};
                    4: S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-1){1'b0}}, reg_disp_enable};
                    8: S_AXI_RDATA <= {C_S_AXI_DATA_WIDTH{1'b0}}; // reserved
                    12: S_AXI_RDATA <= {C_S_AXI_DATA_WIDTH{1'b0}}; // reserved
                    default: S_AXI_RRESP <= 2'b10; // SLVERR
                endcase
            end
            if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

    // AWPROT/ARPROT are intentionally ignored in this simple standalone IP.
    // Not a security boundary: do not expose to untrusted bus masters.
endmodule
