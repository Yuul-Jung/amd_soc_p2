`timescale 1ns/1ps
module tb_button_event_core;
    reg clk=0, resetn=0;
    reg [3:0] raw=0;
    wire [7:0] pulses;
    wire [3:0] pressed;
    integer counts[0:7];
    integer i;
    always #5 clk = ~clk;

    button_event_core #(.DEBOUNCE_CYCLES(3), .LONG_CYCLES(12)) dut (
        .clk(clk), .resetn(resetn), .btn_raw(raw),
        .event_pulse(pulses), .pressed(pressed)
    );
    always @(posedge clk) begin
        if (resetn) begin
            for (integer k=0; k<8; k=k+1)
                if (pulses[k]) counts[k] = counts[k] + 1;
        end
    end
    task tick(input integer n);
        integer j;
        begin for(j=0;j<n;j=j+1) begin @(posedge clk); #1; end end
    endtask
    task check(input integer bitno,input integer expected);
        begin
            if(counts[bitno] !== expected) begin
                $display("FAIL EVENT %0d: got %0d expected %0d", bitno,counts[bitno],expected);
                $fatal(1);
            end
        end
    endtask
    initial begin
        for(i=0;i<8;i=i+1) counts[i]=0;
        tick(3); resetn=1; tick(3);

        // < 3 sample periods of noise: should not latch as a press.
        raw[0]=1; tick(1); raw[0]=0; tick(4);
        check(0,0); check(4,0);
        if(pressed!==4'b0000) $fatal(1,"bouncing not rejected");

        // A valid short generates once only when button is released.
        raw[0]=1; tick(8); check(0,0); check(4,0);
        raw[0]=0; tick(8);
        check(0,1); check(4,0);
        if (pressed[0]) $fatal(1,"button remained pressed");

        // A >= threshold long generates once while held, no short on release.
        raw[1]=1; tick(24);
        check(5,1); check(1,0);
        tick(20); check(5,1);
        raw[1]=0; tick(8); check(1,0);

        // Two buttons can produce simultaneous independent events.
        raw[2]=1; raw[3]=1; tick(8);
        raw[2]=0; raw[3]=0; tick(8);
        check(2,1); check(3,1);

        // Reset while held must clear state and suppress stale events.
        raw[0]=1; tick(8);
        resetn=0; tick(3);
        raw=0; resetn=1; tick(8);
        check(0,1); check(4,0);
        $display("RTL_SIM_button_event_core PASS");
        $finish;
    end
endmodule
