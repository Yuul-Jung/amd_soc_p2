`timescale 1ns/1ps
// P2-17 DHT22/AM2302 separate one-wire pulse-width receiver.
// Unlike DS18B20 Dallas 1-Wire, this is Aosong's 40-bit protocol.
// Output units: humidity_tenths = 0.1 %RH, temperature_tenths = 0.1 C.
// DHT22 temperature uses sign-magnitude (NOT two's complement).
// No clock generated: samples synchronized dq_in using system clk.
// Timing parameters are microseconds, CLK_HZ must divide by 1_000_000.
// Only pull LOW or release: dq_drive_low=1 => LOW, 0=>external 3.3V pullup.
// No AXI, XDC or FPGA board logic in this reusable controller.
module dht22_controller #(
    parameter integer CLK_HZ=100000000,
    parameter integer START_LOW_US=1200,
    parameter integer RESPONSE_TIMEOUT_US=200,
    parameter integer PULSE_TIMEOUT_US=120,
    parameter integer BIT_THRESHOLD_US=45,
    parameter integer MIN_INTERVAL_US=2000000
)(
    input wire clk,input wire resetn,
    input wire start_pulse,
    input wire dq_in,
    output wire dq_drive_low,
    output reg busy,output reg done_pulse,output reg error_pulse,
    output reg [2:0] error_code, // 1 timeout, 2 checksum, 3 pulse, 4 bad range
    output reg [15:0] humidity_tenths,
    output reg signed [15:0] temperature_tenths,
    output wire sample_ready
);
    localparam integer TICKS_PER_US=CLK_HZ/1000000;
    localparam [3:0] IDLE=0, START_LOW=1, WAIT_RESP_LOW=2,
        RESP_LOW=3, RESP_HIGH=4, BIT_LOW=5, BIT_HIGH=6,
        VALIDATE=7, SUCCESS=8, FAIL=9;
    reg [3:0] state;
    reg [31:0] us_div, elapsed, cooldown;
    reg [5:0] bit_count;
    reg [39:0] shift_data;
    reg [2:0] fail_reason;
    reg dq_meta,dq_sync,dq_prev;
    wire tick_us=(us_div==TICKS_PER_US-1);
    wire rise=dq_sync && !dq_prev;
    wire fall=!dq_sync && dq_prev;
    wire [7:0] chk_sum=shift_data[39:32]+shift_data[31:24]+
                        shift_data[23:16]+shift_data[15:8];
    wire [15:0] rh_raw=shift_data[39:24];
    wire [15:0] temp_mag={1'b0,shift_data[22:8]};
    assign sample_ready=(state==IDLE && cooldown==0);
    assign dq_drive_low=(state==START_LOW && resetn);
    always @(posedge clk) begin
        if(!resetn) begin
            state<=IDLE;us_div<=0;elapsed<=0;cooldown<=0;
            bit_count<=0;shift_data<=0;fail_reason<=0;
            dq_meta<=1;dq_sync<=1;dq_prev<=1;
            busy<=0;done_pulse<=0;error_pulse<=0;
            error_code<=0;humidity_tenths<=0;temperature_tenths<=0;
        end else begin
            // Input synchronization: metastability risk reduced to 2 FF.
            dq_meta<=dq_in;dq_sync<=dq_meta;dq_prev<=dq_sync;
            done_pulse<=0;error_pulse<=0;
            if(tick_us) us_div<=0;
            else us_div<=us_div+1;
            if(tick_us && cooldown!=0) cooldown<=cooldown-1;
            if(tick_us && state!=IDLE && state!=SUCCESS && state!=FAIL)
                elapsed<=elapsed+1;
            case(state)
            IDLE: if(start_pulse && cooldown==0) begin
                busy<=1;error_code<=0;shift_data<=0;bit_count<=0;
                elapsed<=0;state<=START_LOW;
            end
            START_LOW: if(tick_us && elapsed>=START_LOW_US-1)begin
                elapsed<=0;state<=WAIT_RESP_LOW;
            end
            WAIT_RESP_LOW: begin
                if(fall)begin elapsed<=0;state<=RESP_LOW;end
                else if(tick_us && elapsed>=RESPONSE_TIMEOUT_US)begin
                    fail_reason<=1;state<=FAIL;
                end
            end
            RESP_LOW: begin
                if(rise)begin
                    if(elapsed<60 || elapsed>100)begin
                        fail_reason<=3;state<=FAIL;
                    end else begin elapsed<=0;state<=RESP_HIGH;end
                end else if(tick_us && elapsed>=PULSE_TIMEOUT_US)begin
                    fail_reason<=1;state<=FAIL;
                end
            end
            RESP_HIGH: begin
                if(fall)begin
                    if(elapsed<60 || elapsed>100)begin
                        fail_reason<=3;state<=FAIL;
                    end else begin elapsed<=0;state<=BIT_LOW;end
                end else if(tick_us && elapsed>=PULSE_TIMEOUT_US)begin
                    fail_reason<=1;state<=FAIL;
                end
            end
            BIT_LOW: begin
                if(rise)begin
                    if(elapsed<35 || elapsed>75)begin
                        fail_reason<=3;state<=FAIL;
                    end else begin elapsed<=0;state<=BIT_HIGH;end
                end else if(tick_us && elapsed>=PULSE_TIMEOUT_US)begin
                    fail_reason<=1;state<=FAIL;
                end
            end
            BIT_HIGH: begin
                if(fall)begin
                    if(elapsed<15 || elapsed>95)begin
                        fail_reason<=3;state<=FAIL;
                    end else begin
                        // (변경) 40 bits arrive MSB first; last bit is LSB.
                        shift_data<={shift_data[38:0],
                                     elapsed>=BIT_THRESHOLD_US};
                        elapsed<=0;
                        if(bit_count==39)state<=VALIDATE;
                        else begin bit_count<=bit_count+1;state<=BIT_LOW;end
                    end
                end else if(tick_us && elapsed>=PULSE_TIMEOUT_US)begin
                    fail_reason<=1;state<=FAIL;
                end
            end
            VALIDATE: begin
                if(chk_sum!=shift_data[7:0])begin
                    fail_reason<=2;state<=FAIL;
                end else if(rh_raw>1000 || temp_mag>800)begin
                    fail_reason<=4;state<=FAIL;
                end else begin
                    // Publish only the validated measurement pair.
                    humidity_tenths<=rh_raw;
                    temperature_tenths<=shift_data[23] ?
                        -$signed(temp_mag) : $signed(temp_mag);
                    state<=SUCCESS;
                end
            end
            SUCCESS: begin
                busy<=0;done_pulse<=1;cooldown<=MIN_INTERVAL_US;
                state<=IDLE;
            end
            FAIL: begin
                busy<=0;error_pulse<=1;error_code<=fail_reason;
                cooldown<=MIN_INTERVAL_US;state<=IDLE;
            end
            default:begin fail_reason<=1;state<=FAIL;end
            endcase
        end
    end
endmodule
