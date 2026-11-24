`timescale 1ns/1ps
// P2-03 AXI4-Lite slave. 32-bit data, one response outstanding.
// 0x00 PENDING [7:0] read; W1C each bit, event SET wins over clear.
// 0x04 ENABLE  [7:0] R/W; reset 0 (interrupts masked).
// 0x08 PRESSED [3:0] read-only stable button states.
// 0x0C ID = 0x00030001 read-only.
// 0x10 COALESCED [7:0]: W1C flag when event arrives while same bit pending.
// Event bit mapping: [0..3] U/D/L/R short, [4..7] U/D/L/R long.
module p2_03_axi_buttons_v1_0_S00_AXI #(
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
    input  wire [7:0]                        event_pulse,
    input  wire [3:0]                        pressed,
    output wire                              irq
);
    reg  [7:0] pending;
    reg  [7:0] coalesced;
    reg  [7:0] enable_mask;
    reg aw_held, w_held;
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_held;
    reg [C_S_AXI_DATA_WIDTH-1:0] wdata_held;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb_held;

    assign S_AXI_AWREADY = S_AXI_ARESETN && !aw_held && !S_AXI_BVALID;
    assign S_AXI_WREADY  = S_AXI_ARESETN && !w_held  && !S_AXI_BVALID;
    assign S_AXI_ARREADY = S_AXI_ARESETN && !S_AXI_RVALID;
    assign irq = |(pending & enable_mask);  // Level interrupt until W1C.

    // Dedicated combinational W1C mask; simultaneous pulse has SET priority.
    wire complete_write = aw_held && w_held && !S_AXI_BVALID;
    wire [7:0] clear_mask = (complete_write && awaddr_held == 0 && wstrb_held[0])
                           ? wdata_held[7:0] : 8'h00;
    wire [7:0] clear_coalesced = (complete_write && awaddr_held == 16 && wstrb_held[0])
                                ? wdata_held[7:0] : 8'h00;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            pending <= 8'h00;
            coalesced <= 8'h00;
            enable_mask <= 8'h00;
            aw_held <= 1'b0;
            w_held <= 1'b0;
            awaddr_held <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wdata_held <= {C_S_AXI_DATA_WIDTH{1'b0}};
            wstrb_held <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};
            S_AXI_BRESP <= 2'b00;
            S_AXI_BVALID <= 1'b0;
            S_AXI_RDATA <= {C_S_AXI_DATA_WIDTH{1'b0}};
            S_AXI_RRESP <= 2'b00;
            S_AXI_RVALID <= 1'b0;
        end else begin
            pending <= (pending & ~clear_mask) | event_pulse;
            // Report duplicate-type events that a bitmask cannot count.
            coalesced <= (coalesced & ~clear_coalesced) |
                         (event_pulse & pending & ~clear_mask);
            if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                aw_held <= 1'b1;
                awaddr_held <= S_AXI_AWADDR;
            end
            if (S_AXI_WVALID && S_AXI_WREADY) begin
                w_held <= 1'b1;
                wdata_held <= S_AXI_WDATA;
                wstrb_held <= S_AXI_WSTRB;
            end
            if (complete_write) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP <= 2'b00; // OKAY
                aw_held <= 1'b0;
                w_held <= 1'b0;
                case (awaddr_held)
                    0: begin end // clear_mask applied above
                    16: begin end // clear_coalesced applied above
                    4: if (wstrb_held[0]) enable_mask <= wdata_held[7:0];
                    default: S_AXI_BRESP <= 2'b10; // SLVERR
                endcase
            end
            if (S_AXI_BVALID && S_AXI_BREADY) S_AXI_BVALID <= 1'b0;

            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RDATA <= {C_S_AXI_DATA_WIDTH{1'b0}};
                S_AXI_RRESP <= 2'b00;
                case (S_AXI_ARADDR)
                    0:  S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-8){1'b0}}, pending};
                    4:  S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-8){1'b0}}, enable_mask};
                    8:  S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-4){1'b0}}, pressed};
                    12: S_AXI_RDATA <= 32'h00030001;
                    16: S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-8){1'b0}}, coalesced};
                    default: S_AXI_RRESP <= 2'b10; // SLVERR
                endcase
            end
            if (S_AXI_RVALID && S_AXI_RREADY) S_AXI_RVALID <= 1'b0;
        end
    end
    // Protection fields are unused (educational slave, not security isolation).
    wire unused_protection = &{1'b0, S_AXI_AWPROT, S_AXI_ARPROT};
endmodule
