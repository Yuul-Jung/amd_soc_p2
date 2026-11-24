`timescale 1ns/1ps
// P2-07 reusable motor controller; no AXI or board-specific pins.
// (추가) Valid, recent HC-SR04 data + AUTO must exist before any drive.
// (추가) Near/fault/timeout immediately disables ENA via combinational gating.
// (추가) Fault while commanded latches TRIP; MOTOR STOP clears, FWD/REV re-arms.
module motor_controller #(
    parameter integer DEADTIME_CYCLES = 10000000, // 100 ms at 100MHz
    parameter integer FRESH_CYCLES    = 25000000  // 250 ms at 100MHz
)(
    input wire clk, input wire resetn,
    input wire [1:0] request_i, // 0 STOP, 1 FWD, 2 REV
    input wire stop_clear_i,   // One-clock pulse on MOTOR STOP write
    input wire sonic_auto_i, input wire sonic_done_i,
    input wire sonic_valid_i, input wire sonic_unsafe_i,
    output wire motor_in1_o, output wire motor_in2_o, output wire motor_ena_o,
    output wire [1:0] active_dir_o,
    output wire sensor_safe_o, output wire fresh_o,
    output reg trip_latched_o, output wire deadtime_o
);
    reg [31:0] fresh_count, dead_count;
    reg [1:0] drive_dir;
    // Always gate the physical outputs, even before the next clock edge.
    assign fresh_o = (fresh_count != 32'd0);
    assign sensor_safe_o = sonic_auto_i && fresh_o &&
                           sonic_valid_i && !sonic_unsafe_i;
    wire output_allowed = sensor_safe_o && !trip_latched_o &&
                          !stop_clear_i && (request_i != 2'd0);
    assign motor_in1_o = output_allowed && (drive_dir == 2'd1);
    assign motor_in2_o = output_allowed && (drive_dir == 2'd2);
    assign motor_ena_o = motor_in1_o || motor_in2_o;
    assign active_dir_o = motor_ena_o ? drive_dir : 2'd0;
    assign deadtime_o = (dead_count != 32'd0);

    always @(posedge clk) begin
        if (!resetn) begin
            fresh_count <= 32'd0;
            dead_count <= 32'd0;
            drive_dir <= 2'd0;
            trip_latched_o <= 1'b0;
        end else begin
            // Stale/invalid/off -> stop. Periodic successful DONE re-arms freshness.
            if (!sonic_auto_i || !sonic_valid_i || sonic_unsafe_i)
                fresh_count <= 32'd0;
            else if (sonic_done_i)
                fresh_count <= FRESH_CYCLES;
            else if (fresh_count != 32'd0)
                fresh_count <= fresh_count - 32'd1;

            if (stop_clear_i)
                trip_latched_o <= 1'b0;
            else if (request_i != 2'd0 && !sensor_safe_o)
                trip_latched_o <= 1'b1;

            if (!sensor_safe_o || trip_latched_o || stop_clear_i ||
                request_i == 2'd0 || request_i == 2'd3) begin
                drive_dir <= 2'd0;
                // (변경) STOP after motion must not bypass reversal dead-time.
                if (drive_dir != 2'd0)
                    dead_count <= DEADTIME_CYCLES;
                else if (dead_count != 32'd0)
                    dead_count <= dead_count - 32'd1;
            end else if (drive_dir != 2'd0 && drive_dir != request_i) begin
                // Disable bridge, then enforce a direction-change dead time.
                drive_dir <= 2'd0;
                dead_count <= DEADTIME_CYCLES;
            end else if (drive_dir == 2'd0) begin
                if (dead_count != 32'd0)
                    dead_count <= dead_count - 32'd1;
                else
                    drive_dir <= request_i;
            end
        end
    end
endmodule
