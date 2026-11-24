`timescale 1ns/1ps
// P2-03: reusable four-button synchronizer, debounce, short/long event generator.
// btn_raw[0]=UP, [1]=DOWN, [2]=LEFT, [3]=RIGHT; active high.
// event_pulse[0..3]=short on debounced release;
// event_pulse[4..7]=long once at threshold, while held.
module button_event_core #(
    parameter integer DEBOUNCE_CYCLES = 2000000, // 20 ms at 100 MHz
    parameter integer LONG_CYCLES = 500000000    // 5 s at 100 MHz
)(
    input  wire       clk,
    input  wire       resetn,
    input  wire [3:0] btn_raw,
    output reg  [7:0] event_pulse,
    output wire [3:0] pressed
);
    // $clog2 helps keep a small counter for accelerated TB parameters.
    localparam integer DB_W   = (DEBOUNCE_CYCLES < 2) ? 1 : $clog2(DEBOUNCE_CYCLES+1);
    localparam integer LONG_W = (LONG_CYCLES < 2) ? 1 : $clog2(LONG_CYCLES+1);
    genvar k;
    generate for (k=0; k<4; k=k+1) begin: g_button
        (* ASYNC_REG = "TRUE" *) reg meta;
        (* ASYNC_REG = "TRUE" *) reg synced;
        reg debounced;
        reg [DB_W-1:0] db_ticks;
        reg [LONG_W-1:0] hold_ticks;
        reg long_sent;

        assign pressed[k] = debounced;

        always @(posedge clk) begin
            if (!resetn) begin
                meta       <= 1'b0;
                synced     <= 1'b0;
                debounced  <= 1'b0;
                db_ticks   <= {DB_W{1'b0}};
                hold_ticks <= {LONG_W{1'b0}};
                long_sent  <= 1'b0;
                event_pulse[k]   <= 1'b0;
                event_pulse[k+4] <= 1'b0;
            end else begin
                // Two-register synchronizer for asynchronous button input.
                meta <= btn_raw[k];
                synced <= meta;
                event_pulse[k]   <= 1'b0;
                event_pulse[k+4] <= 1'b0;

                // Count only when the sampled value disagrees with stable state.
                if (synced == debounced) begin
                    db_ticks <= {DB_W{1'b0}};
                end else if (db_ticks == DEBOUNCE_CYCLES-1) begin
                    db_ticks  <= {DB_W{1'b0}};
                    debounced <= synced;
                    if (synced) begin
                        hold_ticks <= {LONG_W{1'b0}};
                        long_sent  <= 1'b0;
                    end else begin
                        // No short pulse after a long event on the same press.
                        if (!long_sent) event_pulse[k] <= 1'b1;
                        hold_ticks <= {LONG_W{1'b0}};
                        long_sent  <= 1'b0;
                    end
                end else begin
                    db_ticks <= db_ticks + 1'b1;
                end

                // Freeze time while synchronized input is low; avoids a
                // false 5-second event during release debounce.
                if (debounced && synced && !long_sent) begin
                    if (hold_ticks == LONG_CYCLES-1) begin
                        event_pulse[k+4] <= 1'b1;
                        long_sent <= 1'b1;
                    end else begin
                        hold_ticks <= hold_ticks + 1'b1;
                    end
                end
            end
        end
    end endgenerate
endmodule
