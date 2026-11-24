`timescale 1ns/1ps
module tb_hc_sr04_core;
    reg clk=0; always #5 clk=~clk;
    reg resetn=0, echo_i=0, start_i=0;
    wire trig, ready, busy, done;
    wire [15:0] cm;
    wire [31:0] pulse_us;
    wire valid, timeout, range_error;
    integer trig_ticks;
    hc_sr04_core #(.CLK_HZ(1000000),.TRIG_US(12),
                    .TIMEOUT_US(6500),.COOLDOWN_US(70)) dut (
        .clk(clk),.resetn(resetn),.echo_i(echo_i),.start_i(start_i),
        .trig_o(trig),.ready_o(ready),.busy_o(busy),.done_pulse_o(done),
        .distance_cm_o(cm),.echo_us_o(pulse_us),.valid_o(valid),
        .timeout_o(timeout),.out_range_o(range_error)
    );
    task kick;
    begin
        wait(ready);
        @(negedge clk); start_i=1;
        @(negedge clk); start_i=0;
        wait(trig);
        trig_ticks=0;
        while(trig) begin @(negedge clk);trig_ticks=trig_ticks+1; end
        if(trig_ticks != 12) $fatal(1,"TRIG width %d != 12us",trig_ticks);
    end
    endtask
    task send_echo;
    input integer width_us;
    begin
        repeat(4) @(negedge clk);
        echo_i=1;
        repeat(width_us) @(negedge clk);
        echo_i=0;
        wait(done); @(negedge clk);
    end
    endtask
    initial begin
        repeat(5) @(negedge clk); resetn=1;
        if(!ready || !(!valid) || !(!trig)) $fatal(1,"RESET values");
        kick(); send_echo(5800);
        if(cm!==16'd100 || !valid || timeout || range_error)
            $fatal(1,"100cm echo failed cm=%d us=%d",cm,pulse_us);
        kick(); send_echo(580);
        if(cm!==16'd10 || !valid) $fatal(1,"10cm echo failed cm=%d",cm);
        kick(); send_echo(58);
        if(valid || timeout || !range_error) $fatal(1,"range error");
        kick(); wait(done); @(negedge clk); // no rising edge => timeout
        if(valid || !timeout || range_error) $fatal(1,"no echo timeout");
        wait(ready);
        echo_i=1; repeat(8) @(negedge clk); // stuck HIGH before trigger
        kick(); wait(done); @(negedge clk);
        if(valid || !timeout) $fatal(1,"stuck HIGH should timeout");
        $display("RTL_SIM_hc_sr04_core PASS (TRIG, 100cm,10cm,range,timeout,stuck)");
        $finish;
    end
    initial begin #2000000; $fatal(1,"WATCHDOG"); end
endmodule
