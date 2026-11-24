`timescale 1ns/1ps
// P2-19 Reusable integrated environment policy controller.
// Inputs are ALREADY DECODED sample values: not a physical I2C driver.
// DHT22: 0.1%RH + signed 0.1C; DS18B20: signed 1/16C.
// BME280: OPTIONAL upstream compensated 0.01C, 0.001%RH and Pa.
// RTC: ALREADY DECODED 24h hour/minute. PIR input is sticky event pending.
// Priority: PIR > TEMP HIGH > HUM HIGH > OK. No hardware actuator output.
// Display round-robin pages: temperature, humidity, pressure, RTC, PIR.
// Page selection is a presentation policy, not an LCD byte-level protocol.
module environment_policy #(
    parameter signed [15:0] TEMP_ALARM_TENTHS = 16'sd300,
    parameter [15:0] HUM_ALARM_TENTHS = 16'd800
)(
    input wire clk, input wire resetn,
    input wire dht_valid, input wire signed [15:0] dht_temp_tenths,
    input wire [15:0] dht_hum_tenths,
    input wire ds_valid, input wire signed [15:0] ds_temp_raw,
    input wire bme_valid, input wire signed [31:0] bme_temp_centi,
    input wire [31:0] bme_hum_milli, input wire [31:0] bme_pressure_pa,
    input wire rtc_valid, input wire [4:0] rtc_hour, input wire [5:0] rtc_minute,
    input wire pir_event_pending,
    input wire page_next_pulse,
    output reg [2:0] display_page,
    output reg display_valid,
    output reg signed [31:0] display_value,
    output reg [2:0] display_source, // 1 DHT, 2 DS, 3 BME, 4 RTC, 5 PIR
    output reg [2:0] alarm_reason, // 0 none, 1 PIR, 2 high-temp, 3 high-humidity
    output wire alarm_active,
    output reg [31:0] accepted_updates
);
    reg dht_seen,ds_seen,bme_seen,rtc_seen;
    reg signed [15:0] dht_t;
    reg [15:0] dht_h;
    reg signed [15:0] ds_t;
    reg signed [31:0] bme_t;
    reg [31:0] bme_h,bme_p;
    reg [4:0] hour_reg;
    reg [5:0] min_reg;

    wire bme_temp_sane = (bme_t >= -32'sd4000 &&
                           bme_t <= 32'sd8500);
    wire bme_hum_sane = (bme_h <= 32'd100000);
    wire bme_pressure_sane = (bme_p >= 32'd30000 &&
                              bme_p <= 32'd110000);
    wire bme_usable = bme_seen && bme_temp_sane && bme_hum_sane &&
                      bme_pressure_sane;
    wire dht_usable = dht_seen && dht_h<=16'd1000 &&
                      dht_t>=-16'sd400 && dht_t<=16'sd800;
    wire ds_usable = ds_seen && ds_t>=-16'sd880 &&
                     ds_t<=16'sd2000;
    wire rtc_usable = rtc_seen && hour_reg<=5'd23 &&
                      min_reg<=6'd59;
    // Select one coherent temperature source; bme is preferred if valid.
    reg signed [31:0] temp_selected;
    reg [31:0] hum_selected;
    reg temp_available,hum_available;
    reg [2:0] temp_src,hum_src;
    always @(*) begin
        temp_selected=0;hum_selected=0;
        temp_available=0;hum_available=0;
        temp_src=0;hum_src=0;
        if(bme_usable) begin
            temp_selected=bme_t / 32'sd10; // centi-C to tenth-C
            hum_selected=bme_h / 32'd100;  // milli-% to tenth-%
            temp_available=1;hum_available=1;
            temp_src=3;hum_src=3;
        end else begin
            if(dht_usable) begin
                temp_selected=dht_t;hum_selected=dht_h;
                temp_available=1;hum_available=1;
                temp_src=1;hum_src=1;
            end else if(ds_usable) begin
                // signed signed raw, convert 1/16C into 1/10C;
                // integer truncates towards zero, acceptable display approx.
                temp_selected=($signed(ds_t)*32'sd10)/32'sd16;
                temp_available=1;temp_src=2;
            end
        end
    end
    assign alarm_active=(alarm_reason!=0);
    always @(*) begin
        alarm_reason=0;
        if(pir_event_pending) alarm_reason=1;
        else if(temp_available &&
                temp_selected >= TEMP_ALARM_TENTHS)
            alarm_reason=2;
        else if(hum_available &&
                hum_selected >= HUM_ALARM_TENTHS)
            alarm_reason=3;
    end
    always @(*) begin
        display_valid=0;display_value=0;display_source=0;
        case(display_page)
        0:if(temp_available)begin
            display_valid=1;display_value=temp_selected;
            display_source=temp_src;
        end
        1:if(hum_available)begin
            display_valid=1;display_value=$signed(hum_selected);
            display_source=hum_src;
        end
        2:if(bme_usable)begin
            display_valid=1;display_value=$signed(bme_p);
            display_source=3;
        end
        3:if(rtc_usable)begin
            display_valid=1;
            display_value=hour_reg*32'd100+min_reg;
            display_source=4;
        end
        4:begin
            display_valid=1;
            display_value=pir_event_pending ? 32'sd1 : 32'sd0;
            display_source=5;
        end
        default:begin display_valid=0;end
        endcase
    end
    always @(posedge clk) begin
        if(!resetn)begin
            dht_seen<=0;ds_seen<=0;bme_seen<=0;rtc_seen<=0;
            dht_t<=0;dht_h<=0;ds_t<=0;
            bme_t<=0;bme_h<=0;bme_p<=0;hour_reg<=0;min_reg<=0;
            display_page<=0;accepted_updates<=0;
        end else begin
            if(page_next_pulse)
                display_page <= (display_page==4) ? 0 : display_page+1'b1;
            if(dht_valid) begin
                dht_seen<=1;dht_t<=dht_temp_tenths;dht_h<=dht_hum_tenths;
            end
            if(ds_valid) begin ds_seen<=1;ds_t<=ds_temp_raw;end
            if(bme_valid) begin
                bme_seen<=1;bme_t<=bme_temp_centi;
                bme_h<=bme_hum_milli;bme_p<=bme_pressure_pa;
            end
            if(rtc_valid) begin
                rtc_seen<=1;hour_reg<=rtc_hour;min_reg<=rtc_minute;
            end
            // Count ACCEPTED DATA update cycles, not physical sensors.
            if(dht_valid || ds_valid || bme_valid || rtc_valid)
                if(accepted_updates!=32'hffffffff)
                    accepted_updates<=accepted_updates+1;
        end
    end
endmodule
