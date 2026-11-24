`timescale 1ns/1ps
// P2-04 AXI4-Lite 슬레이브: AW/W 주소·데이터 핸드셰이크를 독립 처리.
// AW와 W 각각 1개 버퍼, B/R 각각 1개 미완료 응답만 처리.
// WRITE 0x00 PERIOD_CFG, 0x04 DUTY_CFG, 0x08 CONTROL_CFG, 0x0C APPLY
// READ  0x10 STATUS, 0x14 ACTIVE_PERIOD, 0x18 ACTIVE_DUTY, 0x1C ID
// STATUS bit0 pending, bit8 active_enable, bit9 active_polarity.
module p2_04_axi_pwm_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
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
    output wire pwm_out
);
    // (주의) 교육용 레지스터는 32비트, 4바이트 정렬.
    // IP Packager에서 Data Width=32, Address Width>=6 적용.
    localparam [1:0] OKAY = 2'b00, SLVERR = 2'b10;
    localparam [31:0] RESET_PERIOD = 32'd100000;
    localparam [31:0] IP_ID = 32'h00040001;
    reg [31:0] period_cfg, duty_cfg, control_cfg;
    reg apply_strobe;
    wire pending;
    wire [31:0] active_period, active_duty;
    wire active_enable, active_polarity;
    reg aw_hold, w_hold;
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;
    reg [31:0] wdata_hold;
    reg [3:0] wstrb_hold;
    integer byte_i;
    reg [31:0] data_merged;

    pwm_core #(.RESET_PERIOD(RESET_PERIOD)) u_pwm_core (
        .clk(S_AXI_ACLK), .resetn(S_AXI_ARESETN),
        .cfg_apply(apply_strobe),
        .cfg_period(period_cfg), .cfg_duty(duty_cfg),
        .cfg_enable(control_cfg[0]), .cfg_polarity(control_cfg[1]),
        .pwm_out(pwm_out), .pending(pending),
        .active_period(active_period), .active_duty(active_duty),
        .active_enable(active_enable), .active_polarity(active_polarity)
    );

    assign S_AXI_AWREADY = S_AXI_ARESETN && !aw_hold && !S_AXI_BVALID;
    assign S_AXI_WREADY  = S_AXI_ARESETN && !w_hold && !S_AXI_BVALID;
    assign S_AXI_ARREADY = S_AXI_ARESETN && !S_AXI_RVALID;

    // (추가) AXI 쓰기: AW/W 모두 수신 후 WSTRB 적용, BRESP 유지.
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            period_cfg   <= RESET_PERIOD;
            duty_cfg     <= 32'd0;
            control_cfg  <= 32'd0;
            apply_strobe <= 1'b0;
            aw_hold      <= 1'b0;
            w_hold       <= 1'b0;
            awaddr_hold  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wdata_hold   <= 32'd0;
            wstrb_hold   <= 4'b0;
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= OKAY;
        end else begin
            apply_strobe <= 1'b0;
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
                aw_hold      <= 1'b0;
                w_hold       <= 1'b0;
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= OKAY;
                // (주의) 미정의/비정렬 주소는 저장하지 않고 SLVERR 응답.
                case (awaddr_hold)
                6'h00: begin
                    data_merged = period_cfg;
                    for (byte_i=0;byte_i<4;byte_i=byte_i+1)
                        if (wstrb_hold[byte_i])
                            data_merged[8*byte_i +: 8] = wdata_hold[8*byte_i +: 8];
                    period_cfg <= data_merged;
                end
                6'h04: begin
                    data_merged = duty_cfg;
                    for (byte_i=0;byte_i<4;byte_i=byte_i+1)
                        if (wstrb_hold[byte_i])
                            data_merged[8*byte_i +: 8] = wdata_hold[8*byte_i +: 8];
                    duty_cfg <= data_merged;
                end
                6'h08: begin
                    data_merged = control_cfg;
                    for (byte_i=0;byte_i<4;byte_i=byte_i+1)
                        if (wstrb_hold[byte_i])
                            data_merged[8*byte_i +: 8] = wdata_hold[8*byte_i +: 8];
                    control_cfg <= data_merged & 32'h00000003;
                end
                6'h0C: begin
                    if (wstrb_hold[0] && wdata_hold[0]) begin
                        if (period_cfg < 32'd2 || duty_cfg > period_cfg)
                            S_AXI_BRESP <= SLVERR;
                        else
                            apply_strobe <= 1'b1;
                    end
                end
                default: S_AXI_BRESP <= SLVERR;
                endcase
            end
        end
    end

    // (추가) AXI 읽기: AR 별도 수신, RREADY 전까지 RDATA 유지.
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RRESP  <= OKAY;
            S_AXI_RDATA  <= 32'd0;
        end else begin
            if (S_AXI_RVALID && S_AXI_RREADY)
                S_AXI_RVALID <= 1'b0;
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP  <= OKAY;
                case (S_AXI_ARADDR)
                6'h00: S_AXI_RDATA <= period_cfg;
                6'h04: S_AXI_RDATA <= duty_cfg;
                6'h08: S_AXI_RDATA <= control_cfg;
                6'h0C: S_AXI_RDATA <= 32'd0; // APPLY는 쓰기 명령; 읽으면 0.
                6'h10: S_AXI_RDATA <= {22'd0,active_polarity,active_enable,7'd0,pending};
                6'h14: S_AXI_RDATA <= active_period;
                6'h18: S_AXI_RDATA <= active_duty;
                6'h1C: S_AXI_RDATA <= IP_ID;
                default: begin S_AXI_RDATA <= 32'd0; S_AXI_RRESP <= SLVERR; end
                endcase
            end
        end
    end
endmodule
