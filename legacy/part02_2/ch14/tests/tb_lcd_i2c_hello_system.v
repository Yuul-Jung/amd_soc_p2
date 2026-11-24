`timescale 1ns/1ps
module tb_lcd_i2c_hello_system;
    reg clk=0; always #5 clk=~clk;
    reg resetn=0;
    reg slave_ack_drive=0;
    wire scl_low,sda_low,ready_done,error_latched;
    wire scl = scl_low ? 1'b0 : 1'b1; // digital model of 3.3V pull-up
    wire sda = (sda_low || slave_ack_drive) ? 1'b0 : 1'b1;
    integer bit_pos=0, bytes_seen=0, writes_seen=0, transactions=0;
    integer nibble_index=0;
    reg [7:0] incoming=0;
    reg [7:0] address_byte=0;
    reg [7:0] pcf_byte=0;
    reg [7:0] expected [0:71];
    integer i;

    lcd_i2c_hello_system #(
        .CLK_DIV(3),.LCD_ADDR(7'h27),
        .POWERUP_WAIT_CYCLES(32'd4),
        .FIRST_INIT_WAIT_CYCLES(32'd4),
        .OTHER_INIT_WAIT_CYCLES(32'd4),.CLEAR_WAIT_CYCLES(32'd4)
    ) dut (
        .clk(clk),.resetn(resetn),.sda_in(sda),
        .scl_drive_low(scl_low),.sda_drive_low(sda_low),
        .ready_done(ready_done),.error_latched(error_latched)
    );

    // Fake PCF8574 ACK at each ninth clock, and capture both bytes.
    // This is not a real electrical level-shifter/pull-up test.
    always @(negedge sda) begin
        if(scl && resetn) begin
            bit_pos=0;
            incoming=0;
            bytes_seen=0;
        end
    end
    always @(negedge scl) begin
        if(bit_pos==8) slave_ack_drive=1;
        else slave_ack_drive=0;
    end
    always @(posedge scl) begin
        if(resetn && !ready_done) begin
            if(bit_pos<8) begin
                incoming={incoming[6:0],sda};
                bit_pos=bit_pos+1;
            end else begin
                if(sda!==0) $fatal(1,"ACK not low");
                if(bytes_seen==0) begin
                    address_byte=incoming;
                    if(incoming!==8'h4e)
                        $fatal(1,"PCF8574 address expected 4E got %02h",incoming);
                end else if(bytes_seen==1) begin
                    pcf_byte=incoming;
                    if(writes_seen>=72) $fatal(1,"extra PCF writes");
                    if(pcf_byte!==expected[writes_seen])
                        $fatal(1,"PCF[%0d] expected=%02h got=%02h",
                            writes_seen,expected[writes_seen],pcf_byte);
                    writes_seen=writes_seen+1;
                end else $fatal(1,"more than two data bytes in transaction");
                bytes_seen=bytes_seen+1;
                bit_pos=0; incoming=0;
            end
        end
    end
    always @(posedge sda) begin
        if(resetn && scl && bytes_seen==2) begin
            transactions=transactions+1;
        end
    end
    // Typical PCF8574 backpack value for LCD nibble:
    // {D7..D4, BL=1, E, RW=0, RS}.
    function [7:0] io_val;
        input [3:0] nib;
        input e;
        input rs;
        begin io_val={nib,1'b1,e,1'b0,rs}; end
    endfunction
    task add_nib;
        input [3:0] nib;
        input rs;
        begin
            expected[nibble_index]=io_val(nib,0,rs);nibble_index=nibble_index+1;
            expected[nibble_index]=io_val(nib,1,rs);nibble_index=nibble_index+1;
            expected[nibble_index]=io_val(nib,0,rs);nibble_index=nibble_index+1;
        end
    endtask
    task add_byte;
        input [7:0] b;
        input rs;
        begin add_nib(b[7:4],rs); add_nib(b[3:0],rs); end
    endtask
    initial begin
        add_nib(4'h3,0);add_nib(4'h3,0);add_nib(4'h3,0);
        add_nib(4'h2,0);
        add_byte(8'h28,0);add_byte(8'h0c,0);add_byte(8'h06,0);
        add_byte(8'h01,0);add_byte(8'h80,0);
        add_byte("H",1);add_byte("E",1);add_byte("L",1);
        add_byte("L",1);add_byte("O",1);
        if(nibble_index!=72) $fatal(1,"test reference length");
        repeat(3) @(negedge clk);resetn=1;
        wait(ready_done);#1;
        if(error_latched || writes_seen!=72 || transactions!=72)
            $fatal(1,"LCD done/error/writes=%0d tx=%0d",
                        writes_seen,transactions);
        if(!scl || !sda) $fatal(1,"I2C bus not idle");
        $display("P2_14_I2C_72_PCF8574_BYTES_PASS");
        $display("P2_14_LCD_HELLO_SEQUENCE_PASS");
        $finish;
    end
    initial begin #20000000; $fatal(1,"TIMEOUT");end
endmodule
