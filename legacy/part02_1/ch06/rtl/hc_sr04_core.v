`timescale 1ns/1ps
// P2-06 HC-SR04 reusable timing core; no board pins or AXI dependency.
// (추가) 2FF Echo synchronizer, microsecond tick, bounded waits, cooldown.
// 100 MHz AXI clock -> 100 clocks / 1 us; 12 us TRIG, >=60 ms cooldown.
// Result is the last COMPLETED reading. valid_o and fault flags persist.
module hc_sr04_core #(
    parameter integer CLK_HZ = 100000000,
    parameter integer TRIG_US = 12,
    parameter integer TIMEOUT_US = 38000,
    parameter integer COOLDOWN_US = 60000
)(
    input wire clk, input wire resetn,
    input wire echo_i, input wire start_i,
    output reg trig_o, output wire ready_o, output wire busy_o,
    output reg done_pulse_o,
    output reg [15:0] distance_cm_o,
    output reg [31:0] echo_us_o,
    output reg valid_o, output reg timeout_o, output reg out_range_o
);
    localparam integer TICK_CYCLES = CLK_HZ / 1000000;
    localparam [2:0] S_IDLE=3'd0, S_TRIG=3'd1,
                     S_WAIT=3'd2, S_ECHO=3'd3, S_COOL=3'd4;
    reg [2:0] state;
    reg [31:0] div_count, us_count, high_us;
    reg echo_meta, echo_sync, echo_prev;
    wire tick_us = (div_count == TICK_CYCLES-1);
    wire echo_rise = echo_sync && !echo_prev;
    reg echo_rise_pending; // Catch sub-us rising edges until the next us tick.
    assign ready_o = (state == S_IDLE);
    assign busy_o = !ready_o;

    // (추가) FPGA input can be asynchronous. Metastability cannot be
    // eliminated absolutely; this 2FF path lowers the risk.
    always @(posedge clk) begin
        if (!resetn) begin
            echo_meta <= 1'b0;
            echo_sync <= 1'b0;
            echo_prev <= 1'b0;
        end else begin
            echo_meta <= echo_i;
            echo_sync <= echo_meta;
            echo_prev <= echo_sync;
        end
    end

    always @(posedge clk) begin
        if (!resetn || state != S_WAIT) echo_rise_pending <= 1'b0;
        else if (echo_rise) echo_rise_pending <= 1'b1;
        else if (tick_us) echo_rise_pending <= 1'b0;
    end

    always @(posedge clk) begin
        if (!resetn) begin
            div_count <= 32'd0;
            state <= S_IDLE;
            us_count <= 32'd0;
            high_us <= 32'd0;
            trig_o <= 1'b0;
            done_pulse_o <= 1'b0;
            distance_cm_o <= 16'd0;
            echo_us_o <= 32'd0;
            valid_o <= 1'b0;
            timeout_o <= 1'b0;
            out_range_o <= 1'b0;
        end else begin
            done_pulse_o <= 1'b0;
            if (tick_us) div_count <= 32'd0;
            else div_count <= div_count + 32'd1;

            case (state)
            S_IDLE: begin
                if (start_i) begin
                    trig_o <= 1'b1;
                    us_count <= 32'd0;
                    high_us <= 32'd0;
                    state <= S_TRIG;
                end
            end
            S_TRIG: if (tick_us) begin
                if (us_count + 32'd1 >= TRIG_US) begin
                    trig_o <= 1'b0;
                    us_count <= 32'd0;
                    state <= S_WAIT;
                end else us_count <= us_count + 32'd1;
            end
            S_WAIT: if (tick_us) begin
                if (echo_rise_pending || echo_rise) begin
                    // Edge latched at 100MHz to avoid missing it on us tick.
                    high_us <= 32'd1;
                    us_count <= 32'd0;
                    state <= S_ECHO;
                end else if (us_count + 32'd1 >= TIMEOUT_US) begin
                    valid_o <= 1'b0;
                    timeout_o <= 1'b1;
                    out_range_o <= 1'b0;
                    distance_cm_o <= 16'd0;
                    echo_us_o <= 32'd0;
                    done_pulse_o <= 1'b1;
                    us_count <= 32'd0;
                    state <= S_COOL;
                end else us_count <= us_count + 32'd1;
            end
            S_ECHO: if (tick_us) begin
                if (!echo_sync) begin
                    echo_us_o <= high_us;
                    // D(cm) ~= EchoHigh(us)/58 at nominal room temperature.
                    if (high_us >= 32'd116 && high_us <= 32'd23200) begin
                        distance_cm_o <= (high_us + 32'd29) / 32'd58;
                        valid_o <= 1'b1;
                        timeout_o <= 1'b0;
                        out_range_o <= 1'b0;
                    end else begin
                        distance_cm_o <= 16'd0;
                        valid_o <= 1'b0;
                        timeout_o <= 1'b0;
                        out_range_o <= 1'b1;
                    end
                    done_pulse_o <= 1'b1;
                    us_count <= 32'd0;
                    state <= S_COOL;
                end else if (high_us >= TIMEOUT_US) begin
                    echo_us_o <= high_us;
                    distance_cm_o <= 16'd0;
                    valid_o <= 1'b0;
                    timeout_o <= 1'b1;
                    out_range_o <= 1'b0;
                    done_pulse_o <= 1'b1;
                    us_count <= 32'd0;
                    state <= S_COOL;
                end else high_us <= high_us + 32'd1;
            end
            S_COOL: if (tick_us) begin
                if (us_count + 32'd1 >= COOLDOWN_US) begin
                    us_count <= 32'd0;
                    state <= S_IDLE;
                end else us_count <= us_count + 32'd1;
            end
            default: state <= S_IDLE;
            endcase
        end
    end
endmodule
