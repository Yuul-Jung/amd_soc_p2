`timescale 1ns/1ps
// P2-15 1-Wire slot engine: reset/presence, write bit, read bit.
// Single system clk, open-drain dq_drive_low (1=LOW; 0=Hi-Z).
// CLK_HZ must be an integer multiple of 1 MHz.
module onewire_slot_master #(
    parameter integer CLK_HZ=100000000
)(
    input wire clk,input wire resetn,
    input wire cmd_valid,output wire cmd_ready,
    input wire [1:0] cmd_op, // 0=RESET, 1=WRITE, 2=READ
    input wire cmd_bit,
    input wire dq_in,output reg dq_drive_low,
    output reg done_pulse,output reg presence,
    output reg read_bit
);
    localparam integer CYCLES_PER_US=CLK_HZ/1000000;
    localparam [2:0] IDLE=0, RESET_LOW=1, PRES_WAIT=2,
        PRES_RECOVER=3, SLOT_LOW=4, READ_WAIT=5,
        SLOT_RELEASE=6, FINISH=7;
    reg [2:0] state;
    reg [31:0] us_div;
    reg [15:0] remain;
    reg [1:0] op_q;
    reg bit_q;
    wire tick_us = (us_div == CYCLES_PER_US-1);
    assign cmd_ready=(state==IDLE);
    always @(posedge clk) begin
        if(!resetn) begin
            state<=IDLE;us_div<=0;remain<=0;
            op_q<=0;bit_q<=0;dq_drive_low<=0;
            done_pulse<=0;presence<=0;read_bit<=1;
        end else begin
            done_pulse<=0;
            if(state==IDLE) us_div<=0;
            else if(tick_us) us_div<=0;
            else us_div<=us_div+1;
            if(state==IDLE) begin
                dq_drive_low<=0;
                if(cmd_valid) begin
                    op_q<=cmd_op;bit_q<=cmd_bit;
                    if(cmd_op==0) begin
                        presence<=0;dq_drive_low<=1;
                        remain<=16'd480;state<=RESET_LOW;
                    end else if(cmd_op==1 || cmd_op==2) begin
                        dq_drive_low<=1;
                        remain<= (cmd_op==2 || cmd_bit) ? 16'd6 : 16'd60;
                        state<=SLOT_LOW;
                    end else begin
                        state<=FINISH;
                    end
                end
            end else if(tick_us) begin
                if(remain>1) remain<=remain-1;
                else begin
                    case(state)
                    RESET_LOW: begin
                        dq_drive_low<=0;remain<=16'd70;
                        state<=PRES_WAIT;
                    end
                    PRES_WAIT: begin
                        presence<=~dq_in;remain<=16'd410;
                        state<=PRES_RECOVER;
                    end
                    PRES_RECOVER: state<=FINISH;
                    SLOT_LOW: begin
                        dq_drive_low<=0;
                        if(op_q==2) begin
                            remain<=16'd9;state<=READ_WAIT;
                        end else begin
                            remain<=bit_q ? 16'd64 : 16'd10;
                            state<=SLOT_RELEASE;
                        end
                    end
                    READ_WAIT: begin
                        read_bit<=dq_in;
                        remain<=16'd55;state<=SLOT_RELEASE;
                    end
                    SLOT_RELEASE: state<=FINISH;
                    FINISH: state<=IDLE;
                    default: state<=IDLE;
                    endcase
                end
            end
            if(state==FINISH && tick_us) begin
                done_pulse<=1;
                dq_drive_low<=0;
            end
        end
    end
endmodule
