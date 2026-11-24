`timescale 1ns/1ps
// P2-14 · PCF8574 backpack 4-bit LCD initialization + "HELLO".
// Typical backpack pin mapping: P7..P4=D7..D4, P3=BL, P2=E, P1=RW, P0=RS.
// Does not assume all PCF8574 backpacks use the same mapping.
// Sends 3 I2C writes per LCD nibble: E=0 -> E=1 -> E=0.
// First 4 boot nibbles: 3,3,3,2; then 0x28,0x0C,0x06,0x01,0x80,
// then ASCII 'H','E','L','L','O'. Single-line subset of 1602/2004.
// Each I2C write is START/address/data/STOP (slow but easy to verify).
module lcd_pcf8574_hello #(
    parameter [6:0] I2C_ADDR=7'h27,
    parameter [31:0] POWERUP_WAIT_CYCLES=32'd5000000,
    // HD44780-compatible power-on initialization spacing:
    // first 0x3 nibble -> >=4.1ms, further 0x3/0x2 -> >=100us.
    parameter [31:0] FIRST_INIT_WAIT_CYCLES=32'd500000,
    parameter [31:0] OTHER_INIT_WAIT_CYCLES=32'd20000,
    parameter [31:0] CLEAR_WAIT_CYCLES=32'd200000
)(
    input wire clk, input wire resetn,
    output wire cmd_valid, input wire cmd_ready,
    output wire [6:0] cmd_addr, output wire [7:0] cmd_data,
    input wire cmd_done, input wire cmd_nack,
    output reg ready_done, output reg error_latched
);
    localparam [2:0] POWERUP=0,SEND=1,WAIT_RSP=2,GUARD=3,
                     FINISH=4,FAULT=5;
    reg [2:0] state;
    reg [31:0] guard_counter;
    reg [3:0] step_index;   // 0..13
    reg nibble_select;     // 0 high nibble, 1 low nibble
    reg [1:0] enable_phase;// 0=LOW, 1=HIGH, 2=LOW
    reg [7:0] lcd_byte;
    reg [3:0] nibble;
    reg rs;
    always @(*) begin
        lcd_byte=8'h00;
        case (step_index)
        4: lcd_byte=8'h28;  // 4-bit mode, 2 rows, 5x8 glyph
        5: lcd_byte=8'h0C;  // display ON, cursor OFF
        6: lcd_byte=8'h06;  // entry increment
        7: lcd_byte=8'h01;  // clear display
        8: lcd_byte=8'h80;  // DDRAM line-1 address 0
        9: lcd_byte=8'h48;  // H
        10: lcd_byte=8'h45; // E
        11: lcd_byte=8'h4C; // L
        12: lcd_byte=8'h4C; // L
        13: lcd_byte=8'h4F; // O
        default: lcd_byte=8'h00;
        endcase
        rs=(step_index>=9);
        if(step_index<4) begin
            case(step_index)
            0,1,2: nibble=4'h3;
            default: nibble=4'h2;
            endcase
        end else
            nibble=nibble_select ? lcd_byte[3:0] : lcd_byte[7:4];
    end
    assign cmd_addr=I2C_ADDR;
    assign cmd_valid=(state==SEND);
    assign cmd_data={nibble,1'b1,(enable_phase==1),1'b0,rs};
    always @(posedge clk) begin
        if(!resetn) begin
            state<=POWERUP;guard_counter<=POWERUP_WAIT_CYCLES;
            step_index<=0;nibble_select<=0;enable_phase<=0;
            ready_done<=0;error_latched<=0;
        end else begin
            case(state)
            POWERUP: if(guard_counter==0) state<=SEND;
                     else guard_counter<=guard_counter-1;
            SEND: if(cmd_ready) state<=WAIT_RSP;
            WAIT_RSP: if(cmd_done) begin
                if(cmd_nack) begin
                    error_latched<=1; state<=FAULT;
                end else if(enable_phase!=2) begin
                    enable_phase<=enable_phase+1;
                    state<=SEND;
                end else begin
                    enable_phase<=0;
                    if(step_index>=4 && !nibble_select) begin
                        nibble_select<=1;state<=SEND;
                    end else begin
                        nibble_select<=0;
                        if(step_index==13) state<=FINISH;
                        else begin
                            step_index<=step_index+1;
                            // 0x01 clear display requires >=1.52ms settle time.
                            if(step_index==7) begin
                                guard_counter<=CLEAR_WAIT_CYCLES;
                                state<=GUARD;
                            end else if(step_index==0) begin
                                guard_counter<=FIRST_INIT_WAIT_CYCLES;
                                state<=GUARD;
                            end else if(step_index==1 || step_index==2 ||
                                        step_index==3) begin
                                guard_counter<=OTHER_INIT_WAIT_CYCLES;
                                state<=GUARD;
                            end else state<=SEND;
                        end
                    end
                end
            end
            GUARD: if(guard_counter==0) state<=SEND;
                   else guard_counter<=guard_counter-1;
            FINISH: ready_done<=1;
            FAULT: state<=FAULT;
            default: state<=FAULT;
            endcase
        end
    end
endmodule
