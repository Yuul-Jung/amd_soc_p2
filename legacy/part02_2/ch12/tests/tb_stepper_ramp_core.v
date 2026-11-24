`timescale 1ns/1ps
// P2-12.4 self-checking 가감속 코어 TB.
// N=10, R=3, START=8 tick, CRUISE=2, DELTA=2
// 기대 각 스텝 간격: 8,6,4,2,2,2,2,4,6,8
module tb_stepper_ramp_core;
    reg clk=0; always #5 clk=~clk;
    reg resetn=0,start=0,stop=0;
    reg [31:0] steps=10,start_period=8,cruise_period=2;
    reg [31:0] delta=2,ramp_steps=3;
    reg reverse=0,half=1;
    wire [3:0] coil;
    wire busy,done,error;
    wire [31:0] completed,period_active;
    reg [31:0] expected [0:9];
    reg [3:0] phases [0:7];
    integer i;
    stepper_ramp_core #(.MIN_STEP_CYCLES(32'd2)) dut(
        .clk(clk),.resetn(resetn),.start_pulse(start),.stop_pulse(stop),
        .cfg_steps(steps),.cfg_start_period(start_period),
        .cfg_cruise_period(cruise_period),
        .cfg_delta_period(delta),.cfg_ramp_steps(ramp_steps),
        .cfg_reverse(reverse),.cfg_half_step(half),
        .coil_o(coil),.busy(busy),.done_pulse(done),
        .error_pulse(error),.steps_done(completed),
        .active_period(period_active)
    );
    task begin_run;
        input rev;
        begin
            @(negedge clk); reverse=rev;start=1;
            @(negedge clk);start=0;
            if(!busy || completed!=0) $fatal(1,"start failed");
        end
    endtask
    initial begin
        phases[0]=4'b0001;phases[1]=4'b0011;
        phases[2]=4'b0010;phases[3]=4'b0110;
        phases[4]=4'b0100;phases[5]=4'b1100;
        phases[6]=4'b1000;phases[7]=4'b1001;
        expected[0]=8;expected[1]=6;expected[2]=4;
        expected[3]=2;expected[4]=2;expected[5]=2;
        expected[6]=2;expected[7]=4;expected[8]=6;
        expected[9]=8;
        repeat(3) @(negedge clk);resetn=1;
        begin_run(0);
        for(i=0;i<10;i=i+1) begin
            if(period_active!==expected[i])
                $fatal(1,"FWD index %0d period expected %0d got %0d",
                       i,expected[i],period_active);
            wait(completed == i+1);#1;
            if(coil !== phases[i%8])
                $fatal(1,"FWD index %0d coil expected %b got %b",
                       i, phases[i%8],coil);
        end
        if(!done || busy) $fatal(1,"done/busy");
        repeat(2) @(negedge clk);
        if(coil !== 0 || done) $fatal(1,"idle coil release");
        $display("P2_12_4_RAMP_FWD PASS");

        begin_run(1);
        for(i=0;i<10;i=i+1) begin
            if(period_active!==expected[i])
                $fatal(1,"REV period index=%0d",i);
            wait(completed == i+1);#1;
            if(coil !== phases[(8-(i%8))%8])
                $fatal(1,"REV index %0d actual=%b",i,coil);
        end
        repeat(2) @(negedge clk);
        if(coil !== 0 || busy) $fatal(1,"REV idle");
        $display("P2_12_4_RAMP_REV PASS");

        // STOP 즉시 출력 차단, Busy 동기 정지
        begin_run(0);
        wait(completed>=1); #1;stop=1;#1;
        if(coil!==0) $fatal(1,"stop output still on");
        // STOP을 적어도 한 번의 clk 상승 에지까지 유지해야 상태가 동기 갱신됨.
        @(posedge clk);
        @(negedge clk);stop=0;
        if(busy || coil!==0) $fatal(1,"stop state");
        $display("P2_12_4_STOP PASS");

        // 잘못된 설정을 거부
        @(negedge clk);steps=4;ramp_steps=3;start=1;
        @(negedge clk);start=0;
        if(!error || busy) $fatal(1,"invalid overlap accepted");
        @(negedge clk);steps=10;ramp_steps=3;cruise_period=1;start=1;
        @(negedge clk);start=0;
        if(!error || busy) $fatal(1,"invalid min accepted");
        $display("P2_12_4_INVALID_CONFIG PASS");
        $display("P2_12_4_RAMP_CORE PASS");
        $finish;
    end
    initial begin #200000; $fatal(1,"TIMEOUT"); end
endmodule
