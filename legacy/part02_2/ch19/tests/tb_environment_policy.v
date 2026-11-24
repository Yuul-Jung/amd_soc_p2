`timescale 1ns/1ps
module tb_environment_policy;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,dht_valid=0,ds_valid=0,bme_valid=0,rtc_valid=0;
    reg signed [15:0] dht_t=0,ds_t=0;
    reg [15:0] dht_h=0;
    reg signed [31:0] bme_t=0;
    reg [31:0] bme_h=0,bme_p=0;
    reg [4:0] hh=0;reg [5:0] mm=0;
    reg pir=0,next=0;
    wire [2:0] page,source,alarm;
    wire valid,active;
    wire signed [31:0] value;
    wire [31:0] updates;
    environment_policy dut(
        .clk(clk),.resetn(resetn),
        .dht_valid(dht_valid),.dht_temp_tenths(dht_t),
        .dht_hum_tenths(dht_h),.ds_valid(ds_valid),
        .ds_temp_raw(ds_t),.bme_valid(bme_valid),
        .bme_temp_centi(bme_t),.bme_hum_milli(bme_h),
        .bme_pressure_pa(bme_p),.rtc_valid(rtc_valid),
        .rtc_hour(hh),.rtc_minute(mm),
        .pir_event_pending(pir),.page_next_pulse(next),
        .display_page(page),.display_valid(valid),
        .display_value(value),.display_source(source),
        .alarm_reason(alarm),.alarm_active(active),
        .accepted_updates(updates)
    );
    task tick;
        begin @(negedge clk);end
    endtask
    task advance_page;
        begin
            tick();next=1;tick();next=0;#1;
        end
    endtask
    task check_display;
        input [2:0] p;
        input v;
        input signed [31:0] n;
        input [2:0] src;
        begin
            #1;
            if(page!==p || valid!==v || (v && (value!==n || source!==src)))
                $fatal(1,"display page=%0d valid=%0d value=%0d source=%0d expected %0d %0d %0d %0d",
                    page,valid,value,source,p,v,n,src);
        end
    endtask
    initial begin
        repeat(3)tick();resetn=1;tick();
        check_display(0,0,0,0);
        if(alarm!==0 || updates!==0) $fatal(1,"reset defaults");
        $display("P2_19_ENV_RESET_NO_STALE_DATA_PASS");

        tick();ds_t=16'sd400;ds_valid=1;tick();ds_valid=0;#1;
        check_display(0,1,250,2);
        if(alarm!==0) $fatal(1,"DS temperature unexpectedly alarming");
        $display("P2_19_ENV_DS18B20_FALLBACK_PASS");

        tick();dht_t=16'sd310;dht_h=16'd650;dht_valid=1;
        tick();dht_valid=0;#1;
        check_display(0,1,310,1);
        if(alarm!==2 || !active) $fatal(1,"DHT hot alarm");
        advance_page();check_display(1,1,650,1);
        advance_page();check_display(2,0,0,0);
        advance_page();check_display(3,0,0,0);
        advance_page();check_display(4,1,0,5);
        advance_page();check_display(0,1,310,1);
        $display("P2_19_ENV_DHT_THRESHOLD_AND_PAGE_ROTATION_PASS");

        // DHT humidity alarm after temperature below 30.0C
        tick();dht_t=16'sd250;dht_h=16'd850;dht_valid=1;
        tick();dht_valid=0;#1;
        if(alarm!==3) $fatal(1,"humidity alarm not selected");
        $display("P2_19_ENV_HUMIDITY_ALARM_PASS");

        // BME280 sample is ALREADY compensated upstream; pressure in Pa.
        tick();bme_t=32'sd2400;bme_h=32'd40000;
        bme_p=32'd101325;bme_valid=1;
        tick();bme_valid=0;#1;
        check_display(0,1,240,3);
        if(alarm!==0) $fatal(1,"valid BME should clear alarm");
        advance_page();check_display(1,1,400,3);
        advance_page();check_display(2,1,101325,3);
        $display("P2_19_ENV_BME280_OPTIONAL_PRIORITY_PASS");

        // Corrupt BME humidity >100%, policy falls back to DHT
        tick();bme_t=2500;bme_h=200000;bme_p=101325;bme_valid=1;
        tick();bme_valid=0;#1;
        advance_page();check_display(3,0,0,0);
        advance_page();check_display(4,1,0,5);
        advance_page();check_display(0,1,250,1);
        if(alarm!==3) $fatal(1,"bad BME should not suppress DHT alarm");
        $display("P2_19_ENV_INVALID_BME_FALLBACK_PASS");

        // Valid calendar time, 14:37 -> HHMM 1437
        tick();hh=5'd14;mm=6'd37;rtc_valid=1;
        tick();rtc_valid=0;#1;
        advance_page();advance_page();advance_page();
        check_display(3,1,1437,4);
        $display("P2_19_ENV_RTC_DISPLAY_PASS");

        // PIR alarm ALWAYS overrides high temp/high humidity.
        tick();pir=1;#1;
        if(alarm!==1 || !active) $fatal(1,"PIR alarm priority");
        advance_page();check_display(4,1,1,5);
        tick();pir=0;#1;
        if(alarm!==3) $fatal(1,"PIR clearing priority");
        $display("P2_19_ENV_PIR_ALARM_PRIORITY_PASS");

        if(updates!==6) $fatal(1,"updates expected 6 got %0d",updates);
        $display("P2_19_ENV_UPDATE_ACCOUNTING_PASS");
        $display("P2_19_ENVIRONMENT_POLICY_RTL PASS");
        $finish;
    end
    initial begin #300000;$fatal(1,"TIMEOUT");end
endmodule
