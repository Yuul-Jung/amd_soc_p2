`timescale 1ns/1ps
// This testbench is supplied for user execution; no simulator bundled.
module tb_motor_controller;
    reg clk=0; always #5 clk=~clk;
    reg resetn=0, stop_clear=0, sonar_auto=0, sonar_done=0;
    reg sonar_valid=0, sonar_unsafe=1;
    reg [1:0] req=0;
    wire in1,in2,ena,safe,fresh,trip,dead;
    wire [1:0] actual;
    integer n;
    motor_controller #(.DEADTIME_CYCLES(4),.FRESH_CYCLES(20)) dut (
      .clk(clk),.resetn(resetn),.request_i(req),.stop_clear_i(stop_clear),
      .sonic_auto_i(sonar_auto),.sonic_done_i(sonar_done),
      .sonic_valid_i(sonar_valid),.sonic_unsafe_i(sonar_unsafe),
      .motor_in1_o(in1),.motor_in2_o(in2),.motor_ena_o(ena),
      .active_dir_o(actual),.sensor_safe_o(safe),.fresh_o(fresh),
      .trip_latched_o(trip),.deadtime_o(dead)
    );
    task tick; begin @(posedge clk); #1; end endtask
    task must_stop; begin
      if(ena || in1 || in2 || actual!=0) $fatal(1,"FAIL non-stop output");
    end endtask
    initial begin
      tick(); tick(); resetn=1; tick(); must_stop();
      req=1; tick(); must_stop();
      if(!trip) $fatal(1,"Missing unsafe latch");
      // A STOP write clears fault; no implicit restart.
      req=0; stop_clear=1; tick(); stop_clear=0; tick();
      if(trip) $fatal(1,"Trip not cleared by STOP");
      sonar_auto=1; sonar_valid=1; sonar_unsafe=0; sonar_done=1;
      tick(); sonar_done=0; tick();
      if(!safe) $fatal(1,"Valid completed reading not accepted");
      req=1; tick(); tick();
      if(!ena || !in1 || in2) $fatal(1,"Forward failed");
      // Change direction -> dead-time with both outputs zero.
      req=2; tick(); must_stop();
      if(!dead) $fatal(1,"Dead-time missing");
      for(n=0;n<3;n=n+1)begin tick(); must_stop();end
      tick(); must_stop();tick();
      if(!ena || in1 || !in2) $fatal(1,"Reverse failed");
      // (추가) STOP must not bypass dead-time before another direction.
      sonar_done=1;tick();sonar_done=0; // Renew freshness for this boundary test.
      req=0;tick();must_stop();
      if(!dead)$fatal(1,"STOP did not load minimum off-time");
      req=1;tick();must_stop();
      repeat(2) begin tick();must_stop();end
      tick();must_stop();tick();
      if(!ena || !in1 || in2) $fatal(1,"STOP->FWD bypassed dead-time");
      // Proximity gate is combinational: don't wait for a clock to drop ENA.
      sonar_unsafe=1; #1; must_stop();
      tick(); if(!trip) $fatal(1,"Trip not latched");
      sonar_unsafe=0; sonar_done=1; tick(); sonar_done=0;
      tick(); must_stop();
      req=0; stop_clear=1;tick();stop_clear=0;tick();
      if(trip) $fatal(1,"STOP failed to rearm");
      req=1; tick();tick(); if(!ena) $fatal(1,"Restart failed");
      // Sensor stops reporting: age-out must stop and latch.
      repeat(24)tick(); must_stop();
      if(!trip) $fatal(1,"Freshness timeout not latched");
      // SONIC AUTO OFF -> gate, even with previously valid last distance.
      req=0;stop_clear=1;tick();stop_clear=0;tick();
      sonar_auto=0;req=1;#1;must_stop();tick();
      $display("P2_07_MOTOR_CORE_PASS");$finish;
    end
endmodule
