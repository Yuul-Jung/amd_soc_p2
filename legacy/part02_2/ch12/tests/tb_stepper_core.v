`timescale 1ns/1ps
module tb_stepper_core;
    reg clk=0; always #5 clk=~clk;
    reg resetn=0,start=0,stop=0;
    reg [31:0] steps=0,period=0;
    reg reverse=0,half=1;
    wire [3:0] coil;
    wire busy,done,error;
    wire [31:0] completed;
    integer i;
    reg [3:0] seq_half [0:7];
    reg [3:0] seq_full [0:3];
    stepper_core #(.MIN_STEP_CYCLES(32'd2)) dut (
        .clk(clk),.resetn(resetn),.start_pulse(start),.stop_pulse(stop),
        .cfg_steps(steps),.cfg_step_period(period),
        .cfg_reverse(reverse),.cfg_half_step(half),
        .coil_o(coil),.busy(busy),.done_pulse(done),
        .error_pulse(error),.steps_done(completed)
    );
    task begin_run;
        input [31:0] n,p;
        input r,h;
        begin
            @(negedge clk);
            steps=n;period=p;reverse=r;half=h;start=1;
            @(negedge clk);start=0;
            if (!busy) $fatal(1,"busy not asserted");
        end
    endtask
    task expect_step;
        input [31:0] n;
        input [3:0] expected;
        begin
            wait(completed == n);
            #1;
            if(coil !== expected)
                $fatal(1,"step %0d expected %b got %b", n,expected,coil);
        end
    endtask
    initial begin
        seq_half[0]=4'b0001;seq_half[1]=4'b0011;
        seq_half[2]=4'b0010;seq_half[3]=4'b0110;
        seq_half[4]=4'b0100;seq_half[5]=4'b1100;
        seq_half[6]=4'b1000;seq_half[7]=4'b1001;
        seq_full[0]=4'b0011;seq_full[1]=4'b0110;
        seq_full[2]=4'b1100;seq_full[3]=4'b1001;
        repeat(3) @(negedge clk); resetn=1;
        if(coil!==0 || busy) $fatal(1,"reset outputs");
        begin_run(8,3,0,1);
        for(i=0;i<8;i=i+1) expect_step(i+1,seq_half[i]);
        // (변경) DONE 직후 한 클록 뒤에 코일을 해제하는 RTL 정책을 기다린다.
        repeat(2) @(negedge clk);
        if(busy || done || coil !== 4'b0000 || completed != 8)
            $fatal(1,"done/idle release");
        $display("HALF_FORWARD PASS");

        begin_run(8,3,1,1);
        expect_step(1,seq_half[0]);
        for(i=1;i<8;i=i+1)
            expect_step(i+1,seq_half[8-i]);
        repeat(2) @(negedge clk);
        if(busy || coil!==0) $fatal(1,"reverse idle");
        $display("HALF_REVERSE PASS");

        begin_run(4,2,0,0);
        for(i=0;i<4;i=i+1) expect_step(i+1,seq_full[i]);
        repeat(2) @(negedge clk);
        if(busy || coil!==0) $fatal(1,"full idle");
        $display("FULL_FORWARD PASS");

        begin_run(4,2,1,0);
        expect_step(1,seq_full[0]);
        for(i=1;i<4;i=i+1) expect_step(i+1,seq_full[4-i]);
        repeat(2) @(negedge clk);
        if(busy || coil!==0) $fatal(1,"full reverse idle");
        $display("FULL_REVERSE PASS");

        // 동작 중 START: 에러 1클록, 진행 상태 유지.
        begin_run(12,3,0,1);
        @(negedge clk);start=1;
        @(negedge clk); start=0;
        if(!error || !busy) $fatal(1,"busy start error");
        @(negedge clk);
        if(error) $fatal(1,"error pulse not cleared");
        // STOP은 클록 전 즉시 코일 OFF.
        #1;stop=1;#1;
        if(coil!==0) $fatal(1,"immediate stop gating");
        @(negedge clk);stop=0;
        if(busy || coil!==0 || done) $fatal(1,"stop failed");
        $display("BUSY_REJECT_STOP PASS");

        // 0 step, period under minimum -> error pulse.
        @(negedge clk);steps=0;period=3;start=1;
        @(negedge clk);start=0;
        if(!error || busy) $fatal(1,"zero steps accepted");
        @(negedge clk);steps=3;period=1;start=1;
        @(negedge clk);start=0;
        if(!error || busy) $fatal(1,"unsafe period accepted");
        $display("INVALID_CONFIG PASS");
        $display("P2_12_RTL_STEPPER_CORE PASS");
        $finish;
    end
    initial begin #200000; $fatal(1,"TIMEOUT"); end
endmodule
