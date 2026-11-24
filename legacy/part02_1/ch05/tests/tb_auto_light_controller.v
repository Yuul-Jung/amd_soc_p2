`timescale 1ns/1ps
// Pure combinatorial truth-table test, no board hardware involved.
module tb_auto_light_controller;
  reg pwm=0, auto_en=0, dark=0, valid=0;
  wire led;
  integer i;
  auto_light_controller dut (
    .pwm_led_i(pwm), .auto_enable_i(auto_en),
    .sensor_dark_i(dark), .sensor_valid_i(valid), .led1_o(led));
  initial begin
    for (i=0; i<16; i=i+1) begin
      {pwm,auto_en,dark,valid}=i[3:0];
      #2;
      if (led !== (pwm & (~auto_en | (dark & valid))))
        $fatal(1,"light gate combination %0d failed",i);
    end
    $display("RTL_SIM_auto_light_controller PASS (16 combinations)");
    $finish;
  end
endmodule
