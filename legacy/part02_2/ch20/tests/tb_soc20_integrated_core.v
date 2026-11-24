`timescale 1ns/1ps
// P2-20 REAL three-chapter RTL integration test: P2-18 PIR + P2-19
// environment_policy + P2-12.4 stepper, plus new fail-safe supervisor.
// Simulated sensor readings are already validated input events.
// No fake AXI bus, no physical I2C/SPI, no Vivado or board here.
module tb_soc20_integrated_core;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,pir=0,pir_arm=1,irq_enable=1,pir_ack=0,clear_pir=0;
    reg dht_valid=0,ds_valid=0,bme_valid=0,rtc_valid=0;
    reg signed [15:0] dht_t=0,ds_t=0;
    reg [15:0] dht_h=0;
    reg signed [31:0] bme_t=0;
    reg [31:0] bme_h=0,bme_p=0;
    reg [4:0] hour=0;reg [5:0] minute=0;
    reg page_next=0,arm=0,disarm=0,clear_fault=0;
    reg motor_start=0,motor_stop=0;
    wire pir_irq,pir_pending,display_valid,permit,fresh,fault;
    wire [31:0] pir_count,steps_done,updates;
    wire [2:0] page,source,alarm;
    wire signed [31:0] display_value;
    wire [3:0] coil;
    wire motor_busy,motor_done,motor_error;
    soc20_integrated_core #(
        .PIR_WARMUP_CYCLES(64'd5),.PIR_FILTER_CYCLES(2),
        .MAX_AGE_CYCLES(55),.MOTOR_MIN_STEP_CYCLES(3)
    ) dut(
        .clk(clk),.resetn(resetn),
        .pir_in_async(pir),.pir_arm(pir_arm),.pir_irq_enable(irq_enable),
        .pir_ack(pir_ack),.pir_count_clear(clear_pir),
        .dht_valid(dht_valid),.dht_temp_tenths(dht_t),
        .dht_hum_tenths(dht_h),.ds_valid(ds_valid),.ds_temp_raw(ds_t),
        .bme_valid(bme_valid),.bme_temp_centi(bme_t),
        .bme_hum_milli(bme_h),.bme_pressure_pa(bme_p),
        .rtc_valid(rtc_valid),.rtc_hour(hour),.rtc_minute(minute),
        .page_next_pulse(page_next),.actuator_arm(arm),
        .actuator_disarm(disarm),.fault_clear(clear_fault),
        .motor_start(motor_start),.motor_stop(motor_stop),
        .motor_steps(32'd30),.motor_start_period(32'd12),
        .motor_cruise_period(32'd6),.motor_delta_period(32'd3),
        .motor_ramp_steps(32'd2),.motor_reverse(1'b0),
        .motor_half_step(1'b1),
        .pir_irq(pir_irq),.pir_pending(pir_pending),
        .pir_count(pir_count),.display_page(page),
        .display_valid(display_valid),.display_value(display_value),
        .display_source(source),.alarm_reason(alarm),
        .actuator_permit(permit),.sensor_fresh(fresh),
        .fault_latched(fault),.motor_coil(coil),.motor_busy(motor_busy),
        .motor_done(motor_done),.motor_error(motor_error),
        .motor_steps_done(steps_done),.updates_accepted(updates)
    );
    task cycles;input integer n;integer i;
        begin for(i=0;i<n;i=i+1) @(negedge clk);end
    endtask
    task pulse_arm;
        begin @(negedge clk);arm=1;@(negedge clk);arm=0;end
    endtask
    task pulse_start;
        begin @(negedge clk);motor_start=1;
              @(negedge clk);motor_start=0;end
    endtask
    task good_sample;
        begin @(negedge clk);dht_t=16'sd240;dht_h=16'd500;
              dht_valid=1;
              @(negedge clk);dht_valid=0;end
    endtask
    initial begin
        cycles(4);resetn=1;cycles(8);
        if(permit || fresh || fault || motor_busy || coil)
            $fatal(1,"P2-20 reset interlock failed");
        pulse_start();cycles(2);
        if(motor_busy || coil) $fatal(1,"unarmed motor started");
        $display("P2_20_DEFAULT_SAFE_INTERLOCK_PASS");

        good_sample();cycles(2);
        if(!fresh || alarm) $fatal(1,"validated DHT not accepted");
        pulse_arm();cycles(2);
        if(!permit) $fatal(1,"valid sample could not arm");
        pulse_start();cycles(18);
        if(!motor_busy || steps_done==0 || coil==0)
            $fatal(1,"P2-12.4 stepper not actually progressing");
        $display("P2_20_EXISTING_STEPPER_INTEGRATION_PASS");

        @(negedge clk);pir=1;
        cycles(9);
        if(!pir_pending || !pir_irq || alarm!=1 || permit || coil!=0)
            $fatal(1,"PIR interrupt failed to shut off motor");
        cycles(2);
        if(motor_busy) $fatal(1,"motor busy after PIR interlock");
        $display("P2_20_PIR_IRQ_MOTOR_STOP_PASS");

        @(negedge clk);pir_ack=1;@(negedge clk);pir_ack=0;
        cycles(2);
        if(pir_pending || pir_irq || !fault || permit)
            $fatal(1,"IRQ ACK incorrectly rearmed actuator");
        $display("P2_20_LATCHED_FAULT_NO_AUTO_RESTART_PASS");

        good_sample();
        @(negedge clk);clear_fault=1;
        @(negedge clk);clear_fault=0;
        cycles(2);
        if(fault || permit) $fatal(1,"fault clear must disarm");
        pulse_arm();cycles(2);
        if(!permit) $fatal(1,"explicit rearm failed");
        $display("P2_20_MANUAL_REARM_PASS");

        pulse_start();cycles(16);
        if(!motor_busy || !coil) $fatal(1,"restarted stepper stopped early");
        cycles(65);
        if(fresh || !fault || permit || coil!=0 || motor_busy)
            $fatal(1,"stale sample failed to shut down motor");
        $display("P2_20_STALE_SENSOR_FAIL_SAFE_PASS");

        // Fresh sample alone must not clear a latched trip.
        good_sample();cycles(2);
        if(!fresh || !fault || permit)
            $fatal(1,"new sample implicitly cleared fault");
        $display("P2_20_FRESH_SAMPLE_DOES_NOT_AUTO_REARM_PASS");

        // Existing P2-19 policy also consumes normalized BME/RTC data.
        // BME values here are MOCK ALREADY-COMPENSATED, not raw ADC.
        @(negedge clk);bme_t=32'sd2250;bme_h=32'd45000;
        bme_p=32'd101000;bme_valid=1;
        @(negedge clk);bme_valid=0;
        cycles(2);
        if(page!=0 || !display_valid ||
           display_value!=225 || source!=3)
            $fatal(1,"BME source priority failed");
        @(negedge clk);rtc_valid=1;hour=5'd14;minute=6'd35;
        @(negedge clk);rtc_valid=0;
        // temp -> hum -> pressure -> clock
        repeat(3)begin
            @(negedge clk);page_next=1;
            @(negedge clk);page_next=0;
        end
        cycles(2);
        if(page!=3 || !display_valid || display_value!=1435 ||
           source!=4)
            $fatal(1,"P2-19 policy RTC page not integrated");
        if(permit || !fault)
            $fatal(1,"new BME/RTC events bypassed latched stop");
        $display("P2_20_EXISTING_POLICY_BME_RTC_PASS");
        $display("P2_20_INTEGRATED_SOC_RTL PASS");
        $finish;
    end
    initial begin #250000;$fatal(1,"TIMEOUT");end
endmodule
