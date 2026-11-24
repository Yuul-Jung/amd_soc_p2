`timescale 1ns/1ps
// P2-16 transaction-level RTC register read planner (NOT physical I2C).
// Valid/ready command interface to a FUTURE I2C write/read engine.
// Sequence: START, D0(write address), 00(pointer), RESTART,
//           D1(read address), 6 READ_ACK, READ_NACK, STOP.
// Each bus command produces one response pulse; READ responses carry data.
// I2C opcode: 0 START,1 WRITE_BYTE,2 RESTART,3 READ_ACK,
//             4 READ_NACK,5 STOP. No electrical SCL/SDA RTL in this module.
module ds3231_burst_sequencer (
    input wire clk,input wire resetn,input wire start_pulse,
    output reg busy,output reg done_pulse,output reg error_pulse,
    output wire bus_valid,input wire bus_ready,
    output reg [2:0] bus_op,output reg [7:0] bus_wdata,
    input wire bus_rsp_valid,input wire bus_rsp_error,
    input wire [7:0] bus_rdata,
    output reg [55:0] raw_bcd // byte0 seconds is raw_bcd[7:0]
);
    localparam [1:0] IDLE=0, SEND=1, WAIT_RSP=2, FINISH=3;
    reg [1:0] state;
    reg [3:0] step;
    reg [55:0] shifted;
    reg [7:0] tmp_data;
    assign bus_valid=(state==SEND);
    always @(*) begin
        bus_op=0;bus_wdata=0;
        case(step)
        0:bus_op=0;                       // START
        1:begin bus_op=1;bus_wdata=8'hd0;end
        2:begin bus_op=1;bus_wdata=8'h00;end
        3:bus_op=2;                       // REPEATED START
        4:begin bus_op=1;bus_wdata=8'hd1;end
        5,6,7,8,9,10:bus_op=3;           // read + ACK
        11:bus_op=4;                      // read + NACK final
        12:bus_op=5;                      // STOP
        default:bus_op=0;
        endcase
    end
    always @(posedge clk) begin
        if(!resetn) begin
            state<=IDLE;step<=0;busy<=0;done_pulse<=0;
            error_pulse<=0;raw_bcd<=0;shifted<=0;tmp_data<=0;
        end else begin
            done_pulse<=0;error_pulse<=0;
            case(state)
            IDLE:if(start_pulse)begin
                step<=0;busy<=1;shifted<=0;state<=SEND;
            end
            SEND:if(bus_ready)state<=WAIT_RSP;
            WAIT_RSP:if(bus_rsp_valid)begin
                if(bus_rsp_error)begin
                    // Report failure; do not publish partial data.
                    // Actual I2C engine shall release bus on error.
                    error_pulse<=1;busy<=0;state<=IDLE;
                end else begin
                    if(step>=5 && step<=11)
                        shifted[8*(step-5)+:8]<=bus_rdata;
                    if(step==12)begin
                        raw_bcd<=shifted;state<=FINISH;
                    end else begin step<=step+1'b1;state<=SEND;end
                end
            end
            FINISH:begin
                done_pulse<=1;busy<=0;state<=IDLE;
            end
            default:state<=IDLE;
            endcase
        end
    end
endmodule
