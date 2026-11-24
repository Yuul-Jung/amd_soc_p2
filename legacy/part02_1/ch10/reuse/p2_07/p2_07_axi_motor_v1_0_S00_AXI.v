`timescale 1ns/1ps
// P2-07 AXI4-Lite 32-bit motor register block, separate AW/W handshakes.
// Register map: 0x00 CMD RW 0 STOP/1 FWD/2 REV;
// 0x04 STATUS RO; 0x08 ID 0x00070001;
// 0x0C DEADTIME_CYCLES RO; 0x10 FRESH_CYCLES RO; 0x14 CLK_HZ RO.
module p2_07_axi_motor_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH=32,
    parameter integer C_S_AXI_ADDR_WIDTH=6,
    parameter integer CLK_HZ=100000000,
    parameter integer DEADTIME_CYCLES=10000000,
    parameter integer FRESH_CYCLES=25000000
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
    input wire sonic_auto_i, input wire sonic_done_i,
    input wire sonic_valid_i, input wire sonic_unsafe_i,
    output wire motor_in1_o, output wire motor_in2_o, output wire motor_ena_o
);
    localparam [1:0] OKAY=2'b00, SLVERR=2'b10;
    reg [1:0] requested_dir;
    reg stop_clear;
    wire [1:0] active_dir;
    wire sensor_safe, fresh, trip, deadtime;
    motor_controller #(.DEADTIME_CYCLES(DEADTIME_CYCLES),
                       .FRESH_CYCLES(FRESH_CYCLES)) u_motor (
        .clk(S_AXI_ACLK),.resetn(S_AXI_ARESETN),
        .request_i(requested_dir),.stop_clear_i(stop_clear),
        .sonic_auto_i(sonic_auto_i),.sonic_done_i(sonic_done_i),
        .sonic_valid_i(sonic_valid_i),.sonic_unsafe_i(sonic_unsafe_i),
        .motor_in1_o(motor_in1_o),.motor_in2_o(motor_in2_o),
        .motor_ena_o(motor_ena_o),.active_dir_o(active_dir),
        .sensor_safe_o(sensor_safe),.fresh_o(fresh),
        .trip_latched_o(trip),.deadtime_o(deadtime)
    );
    wire blocked = (requested_dir != 2'd0) && (!sensor_safe || trip);
    wire [31:0] status_reg = {22'd0, blocked, (requested_dir != 2'd0),
                             sonic_auto_i, fresh, sensor_safe, deadtime,
                             trip, (active_dir == 2'd2),
                             (active_dir == 2'd1), motor_ena_o};
    reg aw_hold, w_hold;
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;
    reg [31:0] wdata_hold;
    reg [3:0] wstrb_hold;
    reg [31:0] merged;
    integer j;
    assign S_AXI_AWREADY = S_AXI_ARESETN && !aw_hold && !S_AXI_BVALID;
    assign S_AXI_WREADY  = S_AXI_ARESETN && !w_hold && !S_AXI_BVALID;
    assign S_AXI_ARREADY = S_AXI_ARESETN && !S_AXI_RVALID;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            requested_dir <= 2'd0;
            stop_clear <= 1'b0;
            aw_hold <= 1'b0; w_hold <= 1'b0;
            awaddr_hold <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wdata_hold <= 32'd0; wstrb_hold <= 4'd0;
            S_AXI_BRESP <= OKAY;
            S_AXI_BVALID <= 1'b0;
        end else begin
            stop_clear <= 1'b0;
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
                S_AXI_BRESP <= OKAY;
                if (awaddr_hold == 6'h00) begin
                    merged = {30'd0,requested_dir};
                    for (j=0;j<4;j=j+1)
                        if (wstrb_hold[j])
                            merged[j*8 +: 8] = wdata_hold[j*8 +: 8];
                    if (merged > 32'd2) begin
                        S_AXI_BRESP <= SLVERR;
                    end else if (wstrb_hold != 4'b0000) begin
                        requested_dir <= merged[1:0];
                        if (merged == 32'd0) stop_clear <= 1'b1;
                    end
                end else begin
                    S_AXI_BRESP <= SLVERR;
                end
            end
        end
    end
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RDATA <= 32'd0;
            S_AXI_RRESP <= OKAY;
        end else begin
            if (S_AXI_RVALID && S_AXI_RREADY) S_AXI_RVALID <= 1'b0;
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP <= OKAY;
                case (S_AXI_ARADDR)
                6'h00: S_AXI_RDATA <= {30'd0,requested_dir};
                6'h04: S_AXI_RDATA <= status_reg;
                6'h08: S_AXI_RDATA <= 32'h00070001;
                6'h0C: S_AXI_RDATA <= DEADTIME_CYCLES;
                6'h10: S_AXI_RDATA <= FRESH_CYCLES;
                6'h14: S_AXI_RDATA <= CLK_HZ;
                default: begin
                    S_AXI_RDATA <= 32'd0;
                    S_AXI_RRESP <= SLVERR;
                end
                endcase
            end
        end
    end
endmodule
