`timescale 1ns/1ps
// P2-20 REAL RTL integration of existing P2-18 + P2-19 + P2-12.4 cores.
// No invented AXI bridge. External decoded/validated sensor samples only.
// UART/RFID/LCD/RTC hardware drivers and AXI addresses remain OUT OF SCOPE.
// Top shell has no functional logic: put policy and interlock HERE.
module soc20_integrated_core #(
    parameter [63:0] PIR_WARMUP_CYCLES=64'd6000000000,
    parameter integer PIR_FILTER_CYCLES=3,
    parameter integer MAX_AGE_CYCLES=100000000,
    parameter [31:0] MOTOR_MIN_STEP_CYCLES=32'd200000
)(
    input wire clk,input wire resetn,
    input wire pir_in_async,input wire pir_arm,input wire pir_irq_enable,
    input wire pir_ack,input wire pir_count_clear,
    input wire dht_valid,input wire signed [15:0] dht_temp_tenths,
    input wire [15:0] dht_hum_tenths,
    input wire ds_valid,input wire signed [15:0] ds_temp_raw,
    input wire bme_valid,input wire signed [31:0] bme_temp_centi,
    input wire [31:0] bme_hum_milli,input wire [31:0] bme_pressure_pa,
    input wire rtc_valid,input wire [4:0] rtc_hour,
    input wire [5:0] rtc_minute,input wire page_next_pulse,
    input wire actuator_arm,input wire actuator_disarm,
    input wire fault_clear,
    input wire motor_start,input wire motor_stop,
    input wire [31:0] motor_steps,input wire [31:0] motor_start_period,
    input wire [31:0] motor_cruise_period,
    input wire [31:0] motor_delta_period,input wire [31:0] motor_ramp_steps,
    input wire motor_reverse,input wire motor_half_step,
    output wire pir_irq,output wire pir_pending,
    output wire [31:0] pir_count,
    output wire [2:0] display_page,output wire display_valid,
    output wire signed [31:0] display_value,
    output wire [2:0] display_source,
    output wire [2:0] alarm_reason,
    output wire actuator_permit,output wire sensor_fresh,
    output wire fault_latched,
    output wire [3:0] motor_coil,
    output wire motor_busy,output wire motor_done,output wire motor_error,
    output wire [31:0] motor_steps_done,
    output wire [31:0] updates_accepted
);
    wire pir_warmup_ready,pir_level,pir_motion_pulse;
    wire policy_alarm_active;
    wire [31:0] motor_active_period;
    // (추가) Reference existing chapter 18 exactly; no duplicate RTL.
    pir_irq_controller #(
        .WARMUP_CYCLES(PIR_WARMUP_CYCLES),
        .FILTER_CYCLES(PIR_FILTER_CYCLES)
    ) u_pir (
        .clk(clk),.resetn(resetn),.pir_in_async(pir_in_async),
        .arm(pir_arm),.irq_enable(pir_irq_enable),
        .irq_ack_pulse(pir_ack),.count_clear_pulse(pir_count_clear),
        .irq(pir_irq),.warmup_ready(pir_warmup_ready),
        .pir_level(pir_level),.motion_pulse(pir_motion_pulse),
        .event_pending(pir_pending),.event_count(pir_count)
    );
    // (추가) Reference existing chapter 19, unchanged.
    environment_policy u_env (
        .clk(clk),.resetn(resetn),
        .dht_valid(dht_valid),.dht_temp_tenths(dht_temp_tenths),
        .dht_hum_tenths(dht_hum_tenths),.ds_valid(ds_valid),
        .ds_temp_raw(ds_temp_raw),
        .bme_valid(bme_valid),.bme_temp_centi(bme_temp_centi),
        .bme_hum_milli(bme_hum_milli),.bme_pressure_pa(bme_pressure_pa),
        .rtc_valid(rtc_valid),.rtc_hour(rtc_hour),
        .rtc_minute(rtc_minute),.pir_event_pending(pir_pending),
        .page_next_pulse(page_next_pulse),
        .display_page(display_page),.display_valid(display_valid),
        .display_value(display_value),.display_source(display_source),
        .alarm_reason(alarm_reason),.alarm_active(policy_alarm_active),
        .accepted_updates(updates_accepted)
    );
    // (추가) Freshness timeout disables actuator even if old policy
    // retains a formerly normal reading.
    soc20_safety_supervisor #(
        .MAX_AGE_CYCLES(MAX_AGE_CYCLES)
    ) u_safety (
        .clk(clk),.resetn(resetn),
        .sample_valid(dht_valid||ds_valid||bme_valid),
        .arm_request(actuator_arm),.disarm_request(actuator_disarm),
        .fault_clear_pulse(fault_clear),
        .alarm_active(policy_alarm_active),
        .actuator_permit(actuator_permit),.fresh(sensor_fresh),
        .fault_latched(fault_latched),.sample_age()
    );
    // (추가) P2-12.4 actual stepper ramp instantiated. Permit revocation
    // forces the stop input and coil LOW, no automatic restart after ACK.
    stepper_ramp_core #(
        .MIN_STEP_CYCLES(MOTOR_MIN_STEP_CYCLES)
    ) u_motor (
        .clk(clk),.resetn(resetn),
        .start_pulse(motor_start && actuator_permit),
        .stop_pulse(motor_stop || !actuator_permit),
        .cfg_steps(motor_steps),
        .cfg_start_period(motor_start_period),
        .cfg_cruise_period(motor_cruise_period),
        .cfg_delta_period(motor_delta_period),
        .cfg_ramp_steps(motor_ramp_steps),
        .cfg_reverse(motor_reverse),.cfg_half_step(motor_half_step),
        .coil_o(motor_coil),.busy(motor_busy),
        .done_pulse(motor_done),.error_pulse(motor_error),
        .steps_done(motor_steps_done),.active_period(motor_active_period)
    );
endmodule
