`timescale 1ns/1ps
// P2-14: I2C single-byte write (START + 7-bit address/W + DATA + STOP).
// Both *_drive_low outputs are open-drain controls: 1=pull low, 0=release.
// External 3.3V pullups required; clock stretching/arbitration unsupported.
// FPGA clk is the only clock domain. SCL is an output, not an FPGA clock.
module i2c_write_byte_master #(
    parameter integer CLK_DIV = 400
)(
    input wire clk, input wire resetn,
    input wire cmd_valid, output wire cmd_ready,
    input wire [6:0] cmd_addr, input wire [7:0] cmd_data,
    input wire sda_in,
    output reg scl_drive_low, output reg sda_drive_low,
    output reg done_pulse, output reg nack_pulse
);
    localparam [3:0] IDLE=0, START=1, BIT_LOW=2, BIT_UP=3,
        BIT_END=4, ACK_LOW=5, ACK_UP=6, ACK_END=7,
        STOP_LOW=8, STOP_UP=9, STOP_END=10, COMPLETE=11;
    reg [3:0] state;
    reg [7:0] tx_byte, data_latched;
    reg [2:0] bit_index;
    reg byte_index;
    reg nack_seen;
    reg [31:0] ticks;
    wire tick = (ticks == CLK_DIV-1);
    assign cmd_ready = (state == IDLE);
    always @(posedge clk) begin
        if(!resetn) begin
            state<=IDLE;tx_byte<=0;data_latched<=0;
            bit_index<=0;byte_index<=0;nack_seen<=0;ticks<=0;
            scl_drive_low<=0;sda_drive_low<=0;
            done_pulse<=0;nack_pulse<=0;
        end else begin
            done_pulse<=0;nack_pulse<=0;
            if(state==IDLE || tick) ticks<=0;
            else ticks<=ticks+1;
            case(state)
            IDLE: begin
                scl_drive_low<=0;sda_drive_low<=0;
                if(cmd_valid) begin
                    tx_byte<={cmd_addr,1'b0};
                    data_latched<=cmd_data;
                    bit_index<=3'd7;byte_index<=0;nack_seen<=0;
                    state<=START;
                end
            end
            START: if(tick) begin
                // SDA falls while SCL is high: START.
                sda_drive_low<=1;
                state<=BIT_LOW;
            end
            BIT_LOW: if(tick) begin
                scl_drive_low<=1;
                sda_drive_low<=~tx_byte[bit_index];
                state<=BIT_UP;
            end
            BIT_UP: if(tick) begin
                scl_drive_low<=0;state<=BIT_END;
            end
            BIT_END: if(tick) begin
                scl_drive_low<=1;
                if(bit_index==0) state<=ACK_LOW;
                else begin bit_index<=bit_index-1;state<=BIT_LOW;end
            end
            ACK_LOW: if(tick) begin
                sda_drive_low<=0;state<=ACK_UP;
            end
            ACK_UP: if(tick) begin
                scl_drive_low<=0;state<=ACK_END;
            end
            ACK_END: if(tick) begin
                if(sda_in) nack_seen<=1;
                scl_drive_low<=1;
                // (변경) Address NACK 이후에는 data byte를 보내지 않고
                // 즉시 STOP을 생성한다. Data NACK도 STOP으로 종료.
                if(sda_in) state<=STOP_LOW;
                else if(!byte_index) begin
                    byte_index<=1;tx_byte<=data_latched;
                    bit_index<=3'd7;state<=BIT_LOW;
                end else state<=STOP_LOW;
            end
            STOP_LOW: if(tick) begin
                sda_drive_low<=1;state<=STOP_UP;
            end
            STOP_UP: if(tick) begin
                scl_drive_low<=0;state<=STOP_END;
            end
            STOP_END: if(tick) begin
                // SDA rising with SCL HIGH: STOP.
                sda_drive_low<=0;state<=COMPLETE;
            end
            COMPLETE: if(tick) begin
                done_pulse<=1;nack_pulse<=nack_seen;state<=IDLE;
            end
            default: state<=IDLE;
            endcase
        end
    end
endmodule
