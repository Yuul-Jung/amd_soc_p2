`timescale 1ns/1ps
// P2-06 AXI4-Lite HC-SR04 user IP, 32-bit aligned addresses only.
// REG0 0x00 CONTROL: bit0 AUTO, bit1 START W1P, bit2 WARN_EN (reset 1)
// REG1 0x04 STATUS: bit0 BUSY,1 VALID,2 TIMEOUT,3 RANGE_ERROR,
//                   bit4 WARN_LED,5 UNSAFE,6 AUTO,7 WARN_EN,8 READY
// REG2 0x08 DIST_CM; REG3 0x0C ECHO_US; REG4 0x10 WARN_CM (1..400)
// REG5 0x14 SEQUENCE; REG6 0x18 ID 0x00060001; REG7 0x1C CLK_HZ
// AW/W sampled independently; B/R held while backpressured; byte strobe.
module p2_06_axi_sonic_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer CLK_HZ = 100000000,
    parameter integer TIMEOUT_US = 38000,
    parameter integer COOLDOWN_US = 60000
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
    input wire sonic_echo_i, output wire sonic_trig_o,
    output wire sonic_alert_o, output wire sonic_unsafe_o
);
    localparam [1:0] RESP_OKAY=2'b00, RESP_SLVERR=2'b10;
    reg auto_en, warn_en, kick;
    reg [15:0] warn_cm;
    wire core_ready, core_busy, core_done;
    wire [15:0] core_dist;
    wire [31:0] core_echo_us;
    wire core_valid, core_timeout, core_range_error;
    reg [31:0] seq_count;
    wire core_start = (auto_en || kick) && core_ready;
    assign sonic_unsafe_o = (!core_valid) || (core_dist <= warn_cm);
    assign sonic_alert_o = warn_en && sonic_unsafe_o;

    hc_sr04_core #(.CLK_HZ(CLK_HZ), .TIMEOUT_US(TIMEOUT_US),
                   .COOLDOWN_US(COOLDOWN_US)) u_sonic_core (
        .clk(S_AXI_ACLK), .resetn(S_AXI_ARESETN),
        .echo_i(sonic_echo_i), .start_i(core_start),
        .trig_o(sonic_trig_o), .ready_o(core_ready), .busy_o(core_busy),
        .done_pulse_o(core_done), .distance_cm_o(core_dist),
        .echo_us_o(core_echo_us), .valid_o(core_valid),
        .timeout_o(core_timeout), .out_range_o(core_range_error)
    );

    reg aw_hold, w_hold;
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;
    reg [31:0] wdata_hold;
    reg [3:0] wstrb_hold;
    reg [31:0] merged_data;
    integer j;
    wire [31:0] status_word = {23'd0, core_ready, warn_en, auto_en,
                                sonic_unsafe_o, sonic_alert_o,
                                core_range_error, core_timeout,
                                core_valid, core_busy};
    assign S_AXI_AWREADY = S_AXI_ARESETN && !aw_hold && !S_AXI_BVALID;
    assign S_AXI_WREADY  = S_AXI_ARESETN && !w_hold  && !S_AXI_BVALID;
    assign S_AXI_ARREADY = S_AXI_ARESETN && !S_AXI_RVALID;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            auto_en <= 1'b0;
            warn_en <= 1'b1; // Default fail-safe near/fault indicator ON.
            warn_cm <= 16'd20;
            kick <= 1'b0;
            seq_count <= 32'd0;
            aw_hold <= 1'b0; w_hold <= 1'b0;
            awaddr_hold <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wdata_hold <= 32'd0; wstrb_hold <= 4'd0;
            S_AXI_BRESP <= RESP_OKAY;
            S_AXI_BVALID <= 1'b0;
        end else begin
            kick <= 1'b0; // One-clock W1P pulse.
            if (core_done) seq_count <= seq_count + 32'd1;
            if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                aw_hold <= 1'b1;
                awaddr_hold <= S_AXI_AWADDR;
            end
            if (S_AXI_WVALID && S_AXI_WREADY) begin
                w_hold <= 1'b1;
                wdata_hold <= S_AXI_WDATA;
                wstrb_hold <= S_AXI_WSTRB;
            end
            if (S_AXI_BVALID && S_AXI_BREADY) S_AXI_BVALID <= 1'b0;
            if (aw_hold && w_hold && !S_AXI_BVALID) begin
                aw_hold <= 1'b0; w_hold <= 1'b0;
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP <= RESP_OKAY;
                case (awaddr_hold)
                6'h00: begin
                    merged_data = {29'd0,warn_en,1'b0,auto_en};
                    for (j=0;j<4;j=j+1)
                        if (wstrb_hold[j])
                            merged_data[j*8 +: 8] = wdata_hold[j*8 +: 8];
                    if ((merged_data & ~32'h7) != 0) begin
                        S_AXI_BRESP <= RESP_SLVERR;
                    end else if (merged_data[1] && !core_ready) begin
                        S_AXI_BRESP <= RESP_SLVERR; // Busy one-shot rejected.
                    end else begin
                        auto_en <= merged_data[0];
                        warn_en <= merged_data[2];
                        kick <= merged_data[1];
                    end
                end
                6'h10: begin
                    merged_data = {16'd0,warn_cm};
                    for (j=0;j<4;j=j+1)
                        if (wstrb_hold[j])
                            merged_data[j*8 +: 8] = wdata_hold[j*8 +: 8];
                    if (merged_data >= 32'd1 && merged_data <= 32'd400)
                        warn_cm <= merged_data[15:0];
                    else S_AXI_BRESP <= RESP_SLVERR;
                end
                default: S_AXI_BRESP <= RESP_SLVERR;
                endcase
            end
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RDATA <= 32'd0;
            S_AXI_RRESP <= RESP_OKAY;
        end else begin
            if (S_AXI_RVALID && S_AXI_RREADY) S_AXI_RVALID <= 1'b0;
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP <= RESP_OKAY;
                case (S_AXI_ARADDR)
                6'h00: S_AXI_RDATA <= {29'd0,warn_en,1'b0,auto_en};
                6'h04: S_AXI_RDATA <= status_word;
                6'h08: S_AXI_RDATA <= {16'd0,core_dist};
                6'h0C: S_AXI_RDATA <= core_echo_us;
                6'h10: S_AXI_RDATA <= {16'd0,warn_cm};
                6'h14: S_AXI_RDATA <= seq_count;
                6'h18: S_AXI_RDATA <= 32'h00060001;
                6'h1C: S_AXI_RDATA <= CLK_HZ;
                default: begin
                    S_AXI_RDATA <= 32'd0;
                    S_AXI_RRESP <= RESP_SLVERR;
                end
                endcase
            end
        end
    end
endmodule
