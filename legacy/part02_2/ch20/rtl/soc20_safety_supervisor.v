`timescale 1ns/1ps
// P2-20: Safety DEMO policy, NOT a certified safety function.
// Freshness applies to valid temperature sources, not to RTC/PIR.
// Fail-safe: no valid sample, stale sample, or active environment
// alarm disables actuator permit. Arm must be re-asserted after a
// loss of permit (latched trip) and a fresh sample must be present.
module soc20_safety_supervisor #(
    parameter integer MAX_AGE_CYCLES=100000000
)(
    input wire clk,input wire resetn,
    input wire sample_valid,
    input wire arm_request,
    input wire disarm_request,
    input wire fault_clear_pulse,
    input wire alarm_active,
    output wire actuator_permit,
    output reg fresh,
    output reg fault_latched,
    output reg [31:0] sample_age
);
    reg armed;
    assign actuator_permit = resetn && armed && fresh &&
                             !fault_latched && !alarm_active;
    always @(posedge clk) begin
        if(!resetn)begin
            armed<=0;fresh<=0;fault_latched<=0;sample_age<=0;
        end else begin
            if(sample_valid)begin
                fresh<=1;sample_age<=0;
            end else if(fresh)begin
                if(sample_age>=MAX_AGE_CYCLES-1)begin
                    fresh<=0;
                    fault_latched<=1;
                end else sample_age<=sample_age+1;
            end
            if(alarm_active) fault_latched<=1;
            // Clear a trip does not automatically restart actuators.
            // Need a separate arm_request after fault_clear.
            if(fault_clear_pulse && !alarm_active && fresh)begin
                fault_latched<=0;armed<=0;
            end
            if(disarm_request)armed<=0;
            else if(arm_request && fresh && !fault_latched &&
                    !alarm_active && !fault_clear_pulse)armed<=1;
            if(!fresh)armed<=0;
        end
    end
endmodule
