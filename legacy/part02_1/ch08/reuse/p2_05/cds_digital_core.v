`timescale 1ns/1ps
// P2-05 reusable digital CdS core. DO is an asynchronous 3.3V-safe input.
// 2FF synchronization -> programmable interpretation -> stable-count filter.
// FILTER_CYCLES=2,000,000 at a VERIFIED 100MHz AXI clock means about 20ms.
module cds_digital_core #(
    parameter integer FILTER_CYCLES = 2000000
)(
    input  wire clk,
    input  wire resetn,
    input  wire cds_digital_i,
    input  wire dark_when_low,
    output wire raw_sync,
    output reg  stable_dark,
    output reg  stable_valid
);
    localparam integer CNT_W = (FILTER_CYCLES <= 2) ? 1 : $clog2(FILTER_CYCLES + 1);
    reg sync_meta, sync_data;
    reg polarity_q;
    reg candidate_q;
    reg [CNT_W-1:0] stable_count;
    wire candidate = dark_when_low ? ~sync_data : sync_data;

    // (추가) Two registers reduce metastability propagation probability.
    // Neither filter nor 2FF replaces board-level 3.3V electrical protection.
    always @(posedge clk) begin
        if (!resetn) begin
            sync_meta <= 1'b1;
            sync_data <= 1'b1;
        end else begin
            sync_meta <= cds_digital_i;
            sync_data <= sync_meta;
        end
    end
    assign raw_sync = sync_data;

    // (추가) On polarity changes, invalidate old interpretation and re-filter.
    // Until valid, the automatic light gate will remain OFF (fail-off).
    always @(posedge clk) begin
        if (!resetn) begin
            polarity_q   <= 1'b1;
            candidate_q  <= 1'b0;
            stable_count <= {CNT_W{1'b0}};
            stable_dark  <= 1'b0;
            stable_valid <= 1'b0;
        end else begin
            polarity_q <= dark_when_low;
            if (polarity_q != dark_when_low) begin
                candidate_q  <= candidate;
                stable_count <= {CNT_W{1'b0}};
                stable_dark  <= 1'b0;
                stable_valid <= 1'b0;
            end else if (candidate != candidate_q) begin
                candidate_q  <= candidate;
                stable_count <= {CNT_W{1'b0}};
            end else if (!stable_valid || candidate != stable_dark) begin
                if (stable_count >= FILTER_CYCLES - 1) begin
                    stable_dark  <= candidate;
                    stable_valid <= 1'b1;
                    stable_count <= {CNT_W{1'b0}};
                end else begin
                    stable_count <= stable_count + 1'b1;
                end
            end else begin
                stable_count <= {CNT_W{1'b0}};
            end
        end
    end
endmodule
