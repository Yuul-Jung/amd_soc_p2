`timescale 1ns/1ps
// P2-12 28BYJ-48/ULN2003 Core, FPGA/AXI/보드 독립 RTL.
// 출력 coil_o[0..3]은 ULN2003 IN1..IN4로 순서대로 연결.
// (추가) 고정 2상 Full Step / 1-2상 Half Step.
// (추가) 설정은 START에서 래치하며 동작 중 변경하지 않음.
// (추가) STOP은 조합 출력 게이트 + 클록 동기 상태 중단.
// (주의) 오픈 루프이므로 steps_done은 기계적 축 회전 성공을 보증하지 않음.
module stepper_core #(
    parameter [31:0] MIN_STEP_CYCLES = 32'd200000
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire        start_pulse,
    input  wire        stop_pulse,
    input  wire [31:0] cfg_steps,
    input  wire [31:0] cfg_step_period,
    input  wire        cfg_reverse,
    input  wire        cfg_half_step,
    output wire [3:0]  coil_o,
    output reg         busy,
    output reg         done_pulse,
    output reg         error_pulse,
    output reg [31:0]  steps_done
);
    reg [31:0] target_steps;
    reg [31:0] active_period;
    reg [31:0] ticks_left;
    reg [2:0]  phase;
    reg        active_reverse;
    reg        active_half_step;
    reg [3:0]  coils_q;

    // 코일 비트 순서: [3]=IN4, [2]=IN3, [1]=IN2, [0]=IN1.
    // Half: IN1 -> IN1+IN2 -> IN2 -> IN2+IN3 -> ... -> IN4+IN1.
    function [3:0] coil_pattern;
        input [2:0] idx;
        input       half_step;
        begin
            if (half_step) begin
                case (idx)
                3'd0: coil_pattern = 4'b0001;
                3'd1: coil_pattern = 4'b0011;
                3'd2: coil_pattern = 4'b0010;
                3'd3: coil_pattern = 4'b0110;
                3'd4: coil_pattern = 4'b0100;
                3'd5: coil_pattern = 4'b1100;
                3'd6: coil_pattern = 4'b1000;
                default: coil_pattern = 4'b1001;
                endcase
            end else begin
                case (idx[1:0])
                2'd0: coil_pattern = 4'b0011;
                2'd1: coil_pattern = 4'b0110;
                2'd2: coil_pattern = 4'b1100;
                default: coil_pattern = 4'b1001;
                endcase
            end
        end
    endfunction

    // STOP/RESET이 올라오면 클록을 기다리지 않고 ULN2003 입력을 모두 LOW.
    assign coil_o = (resetn && !stop_pulse) ? coils_q : 4'b0000;

    always @(posedge clk) begin
        if (!resetn) begin
            busy             <= 1'b0;
            done_pulse       <= 1'b0;
            error_pulse      <= 1'b0;
            steps_done       <= 32'd0;
            target_steps     <= 32'd0;
            active_period    <= MIN_STEP_CYCLES;
            ticks_left       <= 32'd0;
            phase            <= 3'd0;
            active_reverse   <= 1'b0;
            active_half_step <= 1'b1;
            coils_q          <= 4'b0000;
        end else begin
            done_pulse  <= 1'b0;
            error_pulse <= 1'b0;
            if (stop_pulse) begin
                busy       <= 1'b0;
                coils_q    <= 4'b0000;
                ticks_left <= 32'd0;
            end else if (start_pulse) begin
                if (busy || cfg_steps == 32'd0 ||
                    cfg_step_period < MIN_STEP_CYCLES) begin
                    error_pulse <= 1'b1;
                end else begin
                    busy             <= 1'b1;
                    steps_done       <= 32'd0;
                    target_steps     <= cfg_steps;
                    active_period    <= cfg_step_period;
                    ticks_left       <= cfg_step_period - 32'd1;
                    active_reverse   <= cfg_reverse;
                    active_half_step <= cfg_half_step;
                    phase            <= 3'd0;
                    coils_q          <= 4'b0000;
                end
            end else if (busy) begin
                if (ticks_left != 32'd0) begin
                    ticks_left <= ticks_left - 32'd1;
                end else begin
                    // 실제 한 스텝 여자하고 카운트 1 증가.
                    coils_q    <= coil_pattern(phase, active_half_step);
                    steps_done <= steps_done + 32'd1;
                    ticks_left <= active_period - 32'd1;
                    if (steps_done + 32'd1 == target_steps) begin
                        busy       <= 1'b0;
                        done_pulse <= 1'b1;
                        // 마지막 여자 패턴은 DONE 한 클록 동안 유지.
                    end else if (active_reverse) begin
                        phase <= active_half_step ?
                                 (phase - 3'd1) :
                                 {1'b0, (phase[1:0] - 2'd1)};
                    end else begin
                        phase <= active_half_step ?
                                 (phase + 3'd1) :
                                 {1'b0, (phase[1:0] + 2'd1)};
                    end
                end
            end else begin
                // 유휴 때 발열 방지를 위해 코일 해제.
                coils_q <= 4'b0000;
            end
        end
    end
endmodule
