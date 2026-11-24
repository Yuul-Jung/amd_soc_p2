`timescale 1ns/1ps
// DS18B20 one externally-powered device on bus (VDD, DQ, GND).
// Reset -> Skip ROM(CC) -> Convert T(44) -> 750ms wait
// -> Reset -> Skip ROM(CC) -> Read Scratchpad(BE) -> 9 bytes -> CRC8.
// No strong-pullup/parasite-power support, multi-drop addressing,
// variable resolution, interrupt, or AXI interface in this version.
module ds18b20_controller #(
    parameter integer CLK_HZ=100000000,
    parameter integer CONVERT_WAIT_US=750000
)(
    input wire clk,input wire resetn,input wire start_pulse,
    input wire dq_in,output wire dq_drive_low,
    output reg busy,output reg done_pulse,output reg error_pulse,
    output reg [2:0] error_code, // 1=missing presence, 2=CRC
    output reg signed [15:0] temperature_raw
);
    localparam [3:0] IDLE=0,ISSUE=1,WAIT_OP=2,
        CHECK_RESET=3,WRITE_ADV=4,WAIT_CONVERT=5,
        READ_ADV=6,COMPLETE=7,FAULT=8;
    reg [3:0] state;
    // phases: reset0, CC, 44, wait, reset1, CC, BE, read9
    reg [2:0] phase;
    reg [7:0] tx_data;
    reg [3:0] bit_index;
    reg [3:0] byte_index;
    reg [7:0] scratchpad_byte;
    reg [7:0] crc;
    reg [7:0] low_temp;
    reg [7:0] high_temp;
    reg [31:0] conv_div;
    reg [31:0] conv_remaining;
    reg cmd_valid;
    reg [1:0] cmd_op;
    reg cmd_bit;
    wire cmd_ready,slot_done,presence,read_bit;
    onewire_slot_master #(.CLK_HZ(CLK_HZ)) u_slot (
        .clk(clk),.resetn(resetn),.cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),.cmd_op(cmd_op),.cmd_bit(cmd_bit),
        .dq_in(dq_in),.dq_drive_low(dq_drive_low),
        .done_pulse(slot_done),.presence(presence),.read_bit(read_bit)
    );
    function [7:0] crc_next;
        input [7:0] old_crc;
        input bit_value;
        reg feedback;
        begin
            feedback=old_crc[0]^bit_value;
            crc_next={1'b0,old_crc[7:1]} ^ (feedback ? 8'h8c : 8'h00);
        end
    endfunction
    always @(posedge clk) begin
        if(!resetn) begin
            state<=IDLE;phase<=0;tx_data<=0;bit_index<=0;
            byte_index<=0;scratchpad_byte<=0;crc<=0;low_temp<=0;high_temp<=0;
            conv_div<=0;conv_remaining<=0;
            cmd_valid<=0;cmd_op<=0;cmd_bit<=0;
            busy<=0;done_pulse<=0;error_pulse<=0;
            error_code<=0;temperature_raw<=0;
        end else begin
            done_pulse<=0;error_pulse<=0;cmd_valid<=0;
            case(state)
            IDLE: if(start_pulse) begin
                busy<=1;error_code<=0;phase<=0;
                bit_index<=0;byte_index<=0;crc<=0;
                state<=ISSUE;
            end
            ISSUE: if(cmd_ready) begin
                cmd_valid<=1;
                if(phase==0 || phase==4) begin
                    cmd_op<=0;cmd_bit<=0;
                end else if(phase==7) begin
                    cmd_op<=2;cmd_bit<=0;
                end else begin
                    cmd_op<=1;cmd_bit<=tx_data[bit_index];
                end
                state<=WAIT_OP;
            end
            WAIT_OP: if(slot_done) begin
                if(phase==0 || phase==4) state<=CHECK_RESET;
                else if(phase==7) state<=READ_ADV;
                else state<=WRITE_ADV;
            end
            CHECK_RESET: begin
                if(!presence) begin
                    error_code<=1;state<=FAULT;
                end else begin
                    if(phase==0) begin phase<=1;tx_data<=8'hcc;end
                    else begin phase<=5;tx_data<=8'hcc;end
                    bit_index<=0;state<=ISSUE;
                end
            end
            WRITE_ADV: begin
                if(bit_index!=7) begin
                    bit_index<=bit_index+1;state<=ISSUE;
                end else begin
                    bit_index<=0;
                    case(phase)
                    1: begin phase<=2;tx_data<=8'h44;state<=ISSUE;end
                    2: begin
                        phase<=3;conv_div<=0;
                        conv_remaining<=CONVERT_WAIT_US;
                        state<=WAIT_CONVERT;
                    end
                    5: begin phase<=6;tx_data<=8'hbe;state<=ISSUE;end
                    6: begin
                        phase<=7;byte_index<=0;crc<=0;
                        scratchpad_byte<=0;state<=ISSUE;
                    end
                    default: state<=FAULT;
                    endcase
                end
            end
            WAIT_CONVERT: begin
                if(conv_remaining==0) begin
                    phase<=4;state<=ISSUE;
                end else if(conv_div==CLK_HZ/1000000-1) begin
                    conv_div<=0;
                    conv_remaining<=conv_remaining-1;
                end else conv_div<=conv_div+1;
            end
            READ_ADV: begin
                scratchpad_byte[bit_index]<=read_bit;
                if(byte_index<8) crc<=crc_next(crc,read_bit);
                if(bit_index!=7) begin
                    bit_index<=bit_index+1;state<=ISSUE;
                end else begin
                    bit_index<=0;
                    if(byte_index==0) low_temp<={read_bit,scratchpad_byte[6:0]};
                    if(byte_index==1)
                        high_temp<={read_bit,scratchpad_byte[6:0]};
                    if(byte_index==8) begin
                        if({read_bit,scratchpad_byte[6:0]}==crc) begin
                            // (변경) CRC 정상일 때에만 공개 온도 레지스터 갱신.
                            temperature_raw<={high_temp,low_temp};
                            state<=COMPLETE;
                        end
                        else begin
                            error_code<=2;state<=FAULT;
                        end
                    end else begin
                        byte_index<=byte_index+1;
                        scratchpad_byte<=0;state<=ISSUE;
                    end
                end
            end
            COMPLETE: begin busy<=0;done_pulse<=1;state<=IDLE;end
            FAULT: begin busy<=0;error_pulse<=1;state<=IDLE;end
            default: state<=FAULT;
            endcase
        end
    end
endmodule
