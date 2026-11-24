`timescale 1ns/1ps
// Separate NACK regression: without a responding I2C slave,
// both address and data ACK slots remain HIGH from the pull-up.
module tb_i2c_write_nack;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,cmd_valid=0;
    wire cmd_ready,scl_drive_low,sda_drive_low,done_pulse,nack_pulse;
    wire sda = sda_drive_low ? 1'b0 : 1'b1;
    integer seen_done=0,seen_nack=0,clock_rises=0;
    wire bus_scl = scl_drive_low ? 1'b0 : 1'b1;
    // (변경) STOP은 SCL을 1회 추가 상승시키므로
    // 데이터 및 ACK 구간의 SCL 상승만 카운트한다.
    always @(posedge bus_scl) if(resetn &&
        (dut.state==4'd4 || dut.state==4'd7))
        clock_rises=clock_rises+1;
    i2c_write_byte_master #(.CLK_DIV(3)) dut(
        .clk(clk),.resetn(resetn),.cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),.cmd_addr(7'h27),.cmd_data(8'h08),
        .sda_in(sda),.scl_drive_low(scl_drive_low),
        .sda_drive_low(sda_drive_low),.done_pulse(done_pulse),
        .nack_pulse(nack_pulse)
    );
    always @(posedge clk) if(done_pulse) begin
        seen_done=seen_done+1;
        if(!nack_pulse) $fatal(1,"NACK not reported");
        seen_nack=seen_nack+1;
    end
    initial begin
        repeat(3) @(negedge clk);resetn=1;
        @(negedge clk);cmd_valid=1;
        @(negedge clk);cmd_valid=0;
        wait(done_pulse);repeat(3) @(negedge clk);
        if(seen_done!=1 || seen_nack!=1 || clock_rises!=9 ||
           !cmd_ready || scl_drive_low || sda_drive_low)
            $fatal(1,"NACK completion/STOP/idle failure clocks=%0d done=%0d nack=%0d",
                   clock_rises,seen_done,seen_nack);
        $display("P2_14_I2C_NACK_HANDLING_PASS");
        $finish;
    end
    initial begin #200000; $fatal(1,"TIMEOUT");end
endmodule
