`timescale 1ns/1ps
// (추가) P2-12.4 전용 가감속 AXI4-Lite v1_1: 기존 v1_0 변경 없음.
// 확장 레지스터 0x20 CRUISE, 0x24 DELTA, 0x28 RAMP_STEPS, 0x2C ACTIVE_PERIOD.
// Original P2-01~10 AXI IPs are not modified.
// Registers: 0x00 STEPS, 0x04 PERIOD_TICKS, 0x08 CONTROL,
//            0x0C CMD, 0x10 STATUS, 0x14 DONE_STEPS,
//            0x18 ID, 0x1C MIN_STEP_TICKS.
// CONTROL bit0=reverse, bit1=half_step. CMD bit0=START, bit1=STOP.
// STATUS bit0=BUSY, bit1=DONE_STICKY, bit2=ERROR_STICKY.
module p2_12_axi_stepper_v1_1 #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter [31:0] MIN_STEP_CYCLES = 32'd200000,
    parameter [31:0] RESET_STEP_PERIOD = 32'd500000
)(
    input wire S_AXI_ACLK, input wire S_AXI_ARESETN,
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input wire [2:0] S_AXI_AWPROT,
    input wire S_AXI_AWVALID, output wire S_AXI_AWREADY,
    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input wire S_AXI_WVALID, output wire S_AXI_WREADY,
    output reg [1:0] S_AXI_BRESP, output reg S_AXI_BVALID,
    input wire S_AXI_BREADY,
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input wire [2:0] S_AXI_ARPROT,
    input wire S_AXI_ARVALID, output wire S_AXI_ARREADY,
    output reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg [1:0] S_AXI_RRESP, output reg S_AXI_RVALID,
    input wire S_AXI_RREADY,
    output wire [3:0] stepper_coil_o
);
    localparam [1:0] OKAY = 2'b00, SLVERR = 2'b10;
    localparam [31:0] ID = 32'h000C0002;
    reg [31:0] cfg_steps;
    reg [31:0] cfg_period;
    // (추가) 가감속을 위한 확장 설정값.
    reg [31:0] cfg_cruise_period, cfg_delta_period, cfg_ramp_steps;
    reg [31:0] cfg_control;
    reg start_strobe, stop_strobe;
    wire busy, done_pulse, error_pulse;
    wire [31:0] steps_done;
    wire [31:0] active_period;
    reg done_sticky, error_sticky;
    reg aw_hold, w_hold;
    reg [C_S_AXI_ADDR_WIDTH-1:0] saved_awaddr;
    reg [31:0] saved_wdata;
    reg [3:0] saved_wstrb;
    reg [31:0] merged;
    integer b;

    stepper_ramp_core #(.MIN_STEP_CYCLES(MIN_STEP_CYCLES)) u_core (
        .clk(S_AXI_ACLK), .resetn(S_AXI_ARESETN),
        .start_pulse(start_strobe), .stop_pulse(stop_strobe),
        .cfg_steps(cfg_steps), .cfg_start_period(cfg_period),
        .cfg_cruise_period(cfg_cruise_period),
        .cfg_delta_period(cfg_delta_period),
        .cfg_ramp_steps(cfg_ramp_steps),
        .cfg_reverse(cfg_control[0]),.cfg_half_step(cfg_control[1]),
        .coil_o(stepper_coil_o), .busy(busy),
        .done_pulse(done_pulse),.error_pulse(error_pulse),
        .steps_done(steps_done),.active_period(active_period)
    );
    // 각 AW/W 채널 버퍼 한 건 + 응답 한 건만 보관.
    assign S_AXI_AWREADY = S_AXI_ARESETN && !aw_hold && !S_AXI_BVALID;
    assign S_AXI_WREADY  = S_AXI_ARESETN && !w_hold  && !S_AXI_BVALID;
    assign S_AXI_ARREADY = S_AXI_ARESETN && !S_AXI_RVALID;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            cfg_steps     <= 32'd128;
            cfg_period    <= RESET_STEP_PERIOD;
            cfg_cruise_period <= 32'd200000;
            cfg_delta_period <= 32'd100000;
            cfg_ramp_steps <= 32'd3;
            cfg_control   <= 32'd2; // default HALF, forward
            aw_hold       <= 1'b0;
            w_hold        <= 1'b0;
            saved_awaddr  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            saved_wdata   <= 32'd0;
            saved_wstrb   <= 4'd0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= OKAY;
            start_strobe  <= 1'b0;
            stop_strobe   <= 1'b0;
            done_sticky   <= 1'b0;
            error_sticky  <= 1'b0;
        end else begin
            start_strobe <= 1'b0;
            stop_strobe  <= 1'b0;
            if (done_pulse) done_sticky <= 1'b1;
            if (error_pulse) error_sticky <= 1'b1;
            if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                saved_awaddr <= S_AXI_AWADDR;
                aw_hold <= 1'b1;
            end
            if (S_AXI_WVALID && S_AXI_WREADY) begin
                saved_wdata <= S_AXI_WDATA;
                saved_wstrb <= S_AXI_WSTRB;
                w_hold <= 1'b1;
            end
            if (S_AXI_BVALID && S_AXI_BREADY)
                S_AXI_BVALID <= 1'b0;
            if (aw_hold && w_hold && !S_AXI_BVALID) begin
                aw_hold <= 1'b0;
                w_hold <= 1'b0;
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP <= OKAY;
                case (saved_awaddr)
                6'h00: begin
                    merged=cfg_steps;
                    for (b=0;b<4;b=b+1)
                        if(saved_wstrb[b])
                            merged[8*b +:8]=saved_wdata[8*b +:8];
                    cfg_steps <= merged;
                end
                6'h04: begin
                    merged=cfg_period;
                    for (b=0;b<4;b=b+1)
                        if(saved_wstrb[b])
                            merged[8*b +:8]=saved_wdata[8*b +:8];
                    cfg_period <= merged;
                end
                6'h08: begin
                    merged=cfg_control;
                    for (b=0;b<4;b=b+1)
                        if(saved_wstrb[b])
                            merged[8*b +:8]=saved_wdata[8*b +:8];
                    cfg_control <= (merged & 32'h3);
                end
                6'h0C: begin
                    // 반드시 낮은 바이트 스트로브와 명령 비트가 있어야 함.
                    if (!saved_wstrb[0]) begin
                        S_AXI_BRESP <= SLVERR;
                    end else if (saved_wdata[1] && !saved_wdata[0]) begin
                        stop_strobe <= 1'b1;
                    end else if (saved_wdata[0] && !saved_wdata[1]) begin
                        if (busy || start_strobe || cfg_steps < 3 ||
                            cfg_ramp_steps == 0 ||
                            cfg_ramp_steps > ((cfg_steps - 32'd1) >> 1) ||
                            cfg_period <= cfg_cruise_period ||
                            cfg_cruise_period < MIN_STEP_CYCLES ||
                            cfg_delta_period == 0) begin
                            S_AXI_BRESP <= SLVERR;
                            error_sticky <= 1'b1;
                        end else begin
                            start_strobe <= 1'b1;
                            done_sticky <= 1'b0;
                            error_sticky <= 1'b0;
                        end
                    end else S_AXI_BRESP <= SLVERR;
                end
                // (추가) 확장 Configuration: 저장용 Shadow, START 때 래치.
                6'h20: begin
                    merged=cfg_cruise_period;
                    for(b=0;b<4;b=b+1)
                        if(saved_wstrb[b])
                            merged[8*b +:8]=saved_wdata[8*b +:8];
                    cfg_cruise_period<=merged;
                end
                6'h24: begin
                    merged=cfg_delta_period;
                    for(b=0;b<4;b=b+1)
                        if(saved_wstrb[b])
                            merged[8*b +:8]=saved_wdata[8*b +:8];
                    cfg_delta_period<=merged;
                end
                6'h28: begin
                    merged=cfg_ramp_steps;
                    for(b=0;b<4;b=b+1)
                        if(saved_wstrb[b])
                            merged[8*b +:8]=saved_wdata[8*b +:8];
                    cfg_ramp_steps<=merged;
                end
                default: S_AXI_BRESP <= SLVERR;
                endcase
            end
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RDATA  <= 32'd0;
            S_AXI_RRESP  <= OKAY;
        end else begin
            if (S_AXI_RVALID && S_AXI_RREADY)
                S_AXI_RVALID <= 1'b0;
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP <= OKAY;
                case (S_AXI_ARADDR)
                6'h00: S_AXI_RDATA <= cfg_steps;
                6'h04: S_AXI_RDATA <= cfg_period;
                6'h08: S_AXI_RDATA <= cfg_control;
                6'h0C: S_AXI_RDATA <= 32'd0;
                6'h10: S_AXI_RDATA <= {29'd0,error_sticky,done_sticky,busy};
                6'h14: S_AXI_RDATA <= steps_done;
                6'h18: S_AXI_RDATA <= ID;
                6'h1C: S_AXI_RDATA <= MIN_STEP_CYCLES;
                6'h20: S_AXI_RDATA <= cfg_cruise_period;
                6'h24: S_AXI_RDATA <= cfg_delta_period;
                6'h28: S_AXI_RDATA <= cfg_ramp_steps;
                6'h2C: S_AXI_RDATA <= active_period;
                default: begin
                    S_AXI_RDATA <= 32'd0;
                    S_AXI_RRESP <= SLVERR;
                end
                endcase
            end
        end
    end
endmodule
