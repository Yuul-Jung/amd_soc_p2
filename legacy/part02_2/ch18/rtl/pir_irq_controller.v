`timescale 1ns/1ps
// P2-18 HC-SR501 PIR event controller (board-independent).
// pir_in_async -> 2-FF synchronizer -> stable filter -> rising event.
// Warm-up masks initial module transients. Pending is sticky until ACK;
// if ACK and new event coincide, NEW EVENT WINS (no lost interrupt).
// IRQ is level-sensitive: irq_enable & event_pending.
// This RTL does NOT implement a physical AXI-Lite bus / CPU interrupt controller.
module pir_irq_controller #(
    parameter [63:0] WARMUP_CYCLES = 64'd6000000000, // 60 sec @100 MHz
    parameter integer FILTER_CYCLES = 3
)(
    input wire clk,
    input wire resetn,
    input wire pir_in_async,
    input wire arm,
    input wire irq_enable,
    input wire irq_ack_pulse,
    input wire count_clear_pulse,
    output wire irq,
    output reg warmup_ready,
    output reg pir_level,
    output reg motion_pulse,
    output reg event_pending,
    output reg [31:0] event_count
);
    // Wide enough for 60s * 100MHz, no 32-bit overflow.
    reg [63:0] warmup_count;
    reg [31:0] filter_count;
    reg pir_meta, pir_sync;
    wire change_pending = (pir_sync != pir_level);
    wire qualified_rise = warmup_ready && arm && !pir_level &&
        pir_sync && change_pending && (filter_count >= FILTER_CYCLES-1);
    assign irq = irq_enable && event_pending;

    always @(posedge clk) begin
        if(!resetn) begin
            pir_meta<=0; pir_sync<=0; pir_level<=0;
            filter_count<=0; warmup_count<=0; warmup_ready<=0;
            motion_pulse<=0; event_pending<=0; event_count<=0;
        end else begin
            // (추가) Async PIR input synchronizer.
            pir_meta<=pir_in_async;
            pir_sync<=pir_meta;
            if(!warmup_ready) begin
                if(warmup_count >= WARMUP_CYCLES-1)
                    warmup_ready<=1;
                else warmup_count<=warmup_count+1;
            end

            // (추가) Reject glitches shorter than FILTER_CYCLES.
            if(!change_pending) filter_count<=0;
            else if(filter_count >= FILTER_CYCLES-1) begin
                pir_level<=pir_sync;
                filter_count<=0;
            end else filter_count<=filter_count+1;

            // Sticky event; simultaneous ACK cannot erase a new edge.
            motion_pulse<=qualified_rise;
            if(qualified_rise)
                event_pending<=1;
            else if(irq_ack_pulse)
                event_pending<=0;

            // Saturating number of qualified rising edges. This is NOT
            // a direct count of humans or motion events behind one long
            // HC-SR501 HIGH interval.
            if(count_clear_pulse) event_count<=qualified_rise ? 1 : 0;
            else if(qualified_rise && event_count!=32'hffffffff)
                event_count<=event_count+1;
        end
    end
endmodule
