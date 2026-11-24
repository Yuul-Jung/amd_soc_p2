`timescale 1ns/1ps
// P2-12.4: 기존 stepper_core.v를 보존하는 가감속 확장 코어.
// (추가) 시작 저속 -> 가속 -> 정속 -> 감속 -> 정지.
// (주의) 가감속은 스텝 간 간격을 계단식으로 조절하는 선형 주기 프로파일.
// (주의) 속도/가속도가 실제 기계의 연속 선형 가속도가 되지는 않는다.
// Clock Domain: clk 단일 도메인, AXI와 같은 클록 사용을 전제로 함.
module stepper_ramp_core #(
    parameter [31:0] MIN_STEP_CYCLES = 32'd200000
)(
    input wire clk, input wire resetn,
    input wire start_pulse, input wire stop_pulse,
    input wire [31:0] cfg_steps,
    input wire [31:0] cfg_start_period,
    input wire [31:0] cfg_cruise_period,
    input wire [31:0] cfg_delta_period,
    input wire [31:0] cfg_ramp_steps,
    input wire cfg_reverse, input wire cfg_half_step,
    output wire [3:0] coil_o,
    output reg busy, output reg done_pulse, output reg error_pulse,
    output reg [31:0] steps_done,
    output reg [31:0] active_period
);
    reg [31:0] target_steps;
    reg [31:0] cruise_period;
    reg [31:0] start_period;
    reg [31:0] delta_period;
    reg [31:0] ramp_steps;
    reg [31:0] ticks_left;
    reg [2:0] phase;
    reg reverse_q, half_q;
    reg [3:0] coils_q;

    function [3:0] pattern;
        input [2:0] idx;
        input       half;
        begin
            if(half) begin
                case(idx)
                3'd0:pattern=4'b0001;
                3'd1:pattern=4'b0011;
                3'd2:pattern=4'b0010;
                3'd3:pattern=4'b0110;
                3'd4:pattern=4'b0100;
                3'd5:pattern=4'b1100;
                3'd6:pattern=4'b1000;
                default:pattern=4'b1001;
                endcase
            end else begin
                case(idx[1:0])
                2'd0:pattern=4'b0011;
                2'd1:pattern=4'b0110;
                2'd2:pattern=4'b1100;
                default:pattern=4'b1001;
                endcase
            end
        end
    endfunction

    // 실제 코일 출력은 STOP/RESET에서 즉시 차단.
    assign coil_o = (resetn && !stop_pulse) ? coils_q : 4'b0000;

    // cfg_start_period = cfg_cruise_period + cfg_delta_period * cfg_ramp_steps
    // 일치하도록 C Host 단계에서 사전 검증한다. RTL은 감산/가산 포화 적용.
    always @(posedge clk) begin
        if(!resetn) begin
            busy <= 1'b0;
            done_pulse <= 1'b0;
            error_pulse <= 1'b0;
            steps_done <= 32'd0;
            active_period <= MIN_STEP_CYCLES;
            target_steps <= 32'd0;
            cruise_period <= MIN_STEP_CYCLES;
            start_period <= MIN_STEP_CYCLES;
            delta_period <= 32'd0;
            ramp_steps <= 32'd0;
            ticks_left <= 32'd0;
            phase <= 3'd0;
            reverse_q <= 1'b0;
            half_q <= 1'b1;
            coils_q <= 4'b0000;
        end else begin
            done_pulse <= 1'b0;
            error_pulse <= 1'b0;
            if(stop_pulse) begin
                busy <= 1'b0;
                coils_q <= 4'b0000;
                ticks_left <= 32'd0;
            end else if(start_pulse) begin
                // 2*R < N 필수: 가속/감속 구간이 겹치지 않도록 제한.
                if(busy || cfg_steps < 3 ||
                   cfg_ramp_steps == 0 ||
                   cfg_ramp_steps > ((cfg_steps - 32'd1) >> 1) ||
                   cfg_start_period <= cfg_cruise_period ||
                   cfg_cruise_period < MIN_STEP_CYCLES ||
                   cfg_delta_period == 0 ||
                   cfg_start_period < cfg_delta_period) begin
                    error_pulse <= 1'b1;
                end else begin
                    busy <= 1'b1;
                    steps_done <= 32'd0;
                    target_steps <= cfg_steps;
                    start_period <= cfg_start_period;
                    cruise_period <= cfg_cruise_period;
                    delta_period <= cfg_delta_period;
                    ramp_steps <= cfg_ramp_steps;
                    active_period <= cfg_start_period;
                    ticks_left <= cfg_start_period - 32'd1;
                    reverse_q <= cfg_reverse;
                    half_q <= cfg_half_step;
                    phase <= 3'd0;
                    coils_q <= 4'b0000;
                end
            end else if(busy) begin
                if(ticks_left != 0) begin
                    ticks_left <= ticks_left - 32'd1;
                end else begin
                    coils_q <= pattern(phase,half_q);
                    steps_done <= steps_done + 32'd1;
                    // 다음 step 주기값이 갱신되어도 지금 수행한 step은 유지.
                    if(steps_done + 32'd1 == target_steps) begin
                        busy <= 1'b0;
                        done_pulse <= 1'b1;
                    end else begin
                        if(reverse_q)
                            phase <= half_q ? (phase - 3'd1)
                                            : {1'b0,(phase[1:0] - 2'd1)};
                        else
                            phase <= half_q ? (phase + 3'd1)
                                            : {1'b0,(phase[1:0] + 2'd1)};
                        // next_index = steps_done+1, 0부터 시작.
                        if(steps_done + 32'd1 < ramp_steps) begin
                            // 가속 구간: period를 작은 값으로.
                            if(active_period > cruise_period &&
                               active_period - cruise_period > delta_period)
                                active_period <= active_period - delta_period;
                            else
                                active_period <= cruise_period;
                        end else if(steps_done + 32'd1 >= target_steps-ramp_steps) begin
                            // 감속 구간: period를 큰 값으로.
                            if(active_period < start_period &&
                               start_period - active_period > delta_period)
                                active_period <= active_period + delta_period;
                            else
                                active_period <= start_period;
                        end else begin
                            active_period <= cruise_period;
                        end
                        // 아래 구간에서 update된 active_period는 NBA이므로
                        // 타이머에는 다음 주기 길이가 필요하다.
                        // 다음 주기 tick 로드는 분기별로 직접 계산한다.
                        if(steps_done + 32'd1 < ramp_steps) begin
                            ticks_left <= ((active_period > cruise_period &&
                               active_period - cruise_period > delta_period)
                                          ? active_period-delta_period
                                          : cruise_period) - 32'd1;
                        end else if(steps_done + 32'd1 >= target_steps-ramp_steps) begin
                            ticks_left <= ((active_period < start_period-delta_period)
                                          ? active_period+delta_period
                                          : start_period) - 32'd1;
                        end else begin
                            ticks_left <= cruise_period - 32'd1;
                        end
                    end
                end
            end else begin
                coils_q <= 4'b0000;
            end
        end
    end
endmodule
