`timescale 1ns/1ps
// P2-14: Pin-independent composition of LCD controller and I2C master.
// IMPORTANT: SDA/SCL are open-drain controls, NOT push-pull outputs.
// Top Shell must implement true IOBUF/open-drain 0-or-Z connection,
// and SDA input feedback. Actual XDC/pin/pull-up requires separate check.
module lcd_i2c_hello_system #(
    parameter integer CLK_DIV=400,
    parameter [6:0] LCD_ADDR=7'h27,
    parameter [31:0] POWERUP_WAIT_CYCLES=32'd5000000,
    parameter [31:0] FIRST_INIT_WAIT_CYCLES=32'd500000,
    parameter [31:0] OTHER_INIT_WAIT_CYCLES=32'd20000,
    parameter [31:0] CLEAR_WAIT_CYCLES=32'd200000
)(
    input wire clk, input wire resetn,
    input wire sda_in,
    output wire scl_drive_low, output wire sda_drive_low,
    output wire ready_done, output wire error_latched
);
    wire cmd_valid,cmd_ready,cmd_done,cmd_nack;
    wire [6:0] cmd_addr;
    wire [7:0] cmd_data;
    lcd_pcf8574_hello #(
        .I2C_ADDR(LCD_ADDR),.POWERUP_WAIT_CYCLES(POWERUP_WAIT_CYCLES),
        .FIRST_INIT_WAIT_CYCLES(FIRST_INIT_WAIT_CYCLES),
        .OTHER_INIT_WAIT_CYCLES(OTHER_INIT_WAIT_CYCLES),
        .CLEAR_WAIT_CYCLES(CLEAR_WAIT_CYCLES)
    ) u_lcd (
        .clk(clk),.resetn(resetn),
        .cmd_valid(cmd_valid),.cmd_ready(cmd_ready),
        .cmd_addr(cmd_addr),.cmd_data(cmd_data),
        .cmd_done(cmd_done),.cmd_nack(cmd_nack),
        .ready_done(ready_done),.error_latched(error_latched)
    );
    i2c_write_byte_master #(.CLK_DIV(CLK_DIV)) u_i2c (
        .clk(clk),.resetn(resetn),
        .cmd_valid(cmd_valid),.cmd_ready(cmd_ready),
        .cmd_addr(cmd_addr),.cmd_data(cmd_data),
        .sda_in(sda_in),
        .scl_drive_low(scl_drive_low),.sda_drive_low(sda_drive_low),
        .done_pulse(cmd_done),.nack_pulse(cmd_nack)
    );
endmodule
