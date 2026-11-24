`timescale 1ns/1ps
module tb_pwm_core;
  reg clk = 0;
  always #5 clk = ~clk;
  reg resetn = 0, cfg_apply = 0, cfg_enable = 0, cfg_polarity = 0;
  reg [31:0] cfg_period = 10, cfg_duty = 0;
  wire pwm_out, pending;
  wire [31:0] active_period, active_duty;
  wire active_enable, active_polarity;
  integer high, i;
  pwm_core #(.RESET_PERIOD(10)) dut (
    .clk(clk), .resetn(resetn), .cfg_apply(cfg_apply),
    .cfg_period(cfg_period), .cfg_duty(cfg_duty),
    .cfg_enable(cfg_enable), .cfg_polarity(cfg_polarity),
    .pwm_out(pwm_out), .pending(pending),
    .active_period(active_period), .active_duty(active_duty),
    .active_enable(active_enable), .active_polarity(active_polarity)
  );
  task apply_cfg;
    input [31:0] p,d;
    input en,pol;
    begin
      @(negedge clk);
      cfg_period=p; cfg_duty=d; cfg_enable=en; cfg_polarity=pol;
      cfg_apply=1;
      @(negedge clk); cfg_apply=0;
    end
  endtask
  task count_two_periods;
    input integer expected;
    begin
      // Wait for pending request to reach the active registers.
      wait (pending == 0);
      @(negedge clk);
      if (active_period !== 10) $fatal(1,"wrong period");
      high=0;
      for (i=0;i<20;i=i+1) begin
        if (pwm_out) high=high+1;
        @(negedge clk);
      end
      if (high !== expected) $fatal(1,"high count actual=%0d expected=%0d",high,expected);
    end
  endtask
  initial begin
    repeat(3) @(negedge clk);
    if (pwm_out !== 1'b0) $fatal(1,"reset output not low");
    resetn=1;
    apply_cfg(10,0,1,0); count_two_periods(0);
    apply_cfg(10,5,1,0);
    if (pending && active_duty !== 0) $fatal(1,"mid-cycle glitch / duty early update");
    count_two_periods(10);
    apply_cfg(10,10,1,0); count_two_periods(20);
    apply_cfg(10,0,0,0); count_two_periods(0);
    apply_cfg(10,5,1,1); count_two_periods(10);
    apply_cfg(10,0,0,1); count_two_periods(0); // disable dominates polarity
    resetn=0;
    repeat(2) @(negedge clk);
    if (pwm_out !== 0 || pending !== 0 || active_duty !== 0)
      $fatal(1,"reset failed");
    $display("RTL_SIM_pwm_core PASS (0/50/100%%, polarity, enable, reset, boundary)");
    $finish;
  end
  initial begin #100000; $fatal(1,"TIMEOUT"); end
endmodule
