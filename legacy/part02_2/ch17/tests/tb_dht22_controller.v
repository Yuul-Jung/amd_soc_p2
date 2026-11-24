`timescale 1ns/1ps
// P2-17 self-checking fake DHT22 pulse-width source.
// Testbench sim clock = 1MHz (one clk per 1us); DUT RTL default 100MHz.
// Positive humidity+temperature, sign magnitude negative temperature,
// checksum corruption, silent sensor, too-short data pulse, cooldown.
module tb_dht22_controller;
    reg clk=0;always #500 clk=~clk; // 1 MHz
    reg resetn=0,start=0,slave_low=0;
    reg respond=1, bad_pulse=0;
    reg [39:0] frame=40'h029200EA7E;
    wire drive_low,busy,done,error,ready;
    wire [2:0] error_code;
    wire [15:0] humidity;
    wire signed [15:0] temperature;
    wire dq_in=!(drive_low||slave_low);
    integer k,frame_count=0;
    dht22_controller #(
        .CLK_HZ(1000000),.START_LOW_US(1200),
        .RESPONSE_TIMEOUT_US(200),.MIN_INTERVAL_US(150)
    ) dut (
        .clk(clk),.resetn(resetn),.start_pulse(start),
        .dq_in(dq_in),.dq_drive_low(drive_low),
        .busy(busy),.done_pulse(done),.error_pulse(error),
        .error_code(error_code),.humidity_tenths(humidity),
        .temperature_tenths(temperature),.sample_ready(ready)
    );
    // Sensor responds only after FPGA releases its initial START LOW.
    always @(negedge drive_low) if(respond && resetn) begin
        frame_count=frame_count+1;
        #30000;            // host release high for ~30us
        slave_low=1;#80000; // sensor 80us response LOW
        slave_low=0;#80000;// sensor 80us response HIGH
        for(k=39;k>=0;k=k-1)begin
            slave_low=1;#50000; // bit start 50us LOW
            slave_low=0;
            if(bad_pulse && k==12) #9000;
            else if(frame[k]) #70000;
            else #28000;
        end
        slave_low=1;#50000; // sensor's final LOW then release
        slave_low=0;
    end
    task issue;
        begin
            wait(ready);
            @(negedge clk);start=1;
            @(negedge clk);start=0;
            if(!busy) $fatal(1,"busy not set");
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);resetn=1;
        issue();
        wait(done);#1;
        if(busy || error || humidity!=658 || temperature!=234)
            $fatal(1,"positive decode RH=%0d TEMP=%0d",humidity,temperature);
        if(!error_code && frame_count==1)
            $display("P2_17_DHT22_POSITIVE_40BIT_PASS");
        else $fatal(1,"unexpected error");
        // Cooldown rejects a command while sample_ready=0.
        @(negedge clk);start=1;
        @(negedge clk);start=0;
        if(busy || frame_count!=1) $fatal(1,"cooldown accepted command");
        $display("P2_17_DHT22_COOLDOWN_PASS");

        frame=40'h01F48065DA; // 50.0% RH, -10.1 deg C
        issue();
        wait(done);#1;
        if(humidity!=500 || temperature!=-101)
            $fatal(1,"negative sign-magnitude temp %0d RH %0d",
                   temperature,humidity);
        $display("P2_17_DHT22_NEGATIVE_TEMP_PASS");

        frame=40'h029200EA00; // intentionally invalid checksum
        issue();wait(error);#1;
        if(error_code!=2 || humidity!=500 || temperature!=-101)
            $fatal(1,"checksum not rejected/previous data destroyed");
        $display("P2_17_DHT22_CHECKSUM_REJECT_PASS");

        respond=0;issue();wait(error);#1;
        if(error_code!=1 || busy || humidity!=500)
            $fatal(1,"missing response not handled");
        $display("P2_17_DHT22_NO_RESPONSE_PASS");

        respond=1;bad_pulse=1;frame=40'h029200EA7E;
        issue();wait(error);#1;
        if(error_code!=3 || humidity!=500)
            $fatal(1,"invalid high pulse was accepted");
        $display("P2_17_DHT22_PULSE_WIDTH_REJECT_PASS");

        $display("P2_17_DHT22_CONTROLLER_RTL PASS");
        $finish;
    end
    initial begin #1000000000; $fatal(1,"TB TIMEOUT");end
endmodule
