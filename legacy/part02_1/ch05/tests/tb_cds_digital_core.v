`timescale 1ns/1ps
module tb_cds_digital_core;
  reg clk=0; always #5 clk=~clk;
  reg resetn=0, cds=1, dark_when_low=1;
  wire raw, dark, valid;
  cds_digital_core #(.FILTER_CYCLES(4)) dut (
    .clk(clk),.resetn(resetn),.cds_digital_i(cds),
    .dark_when_low(dark_when_low),.raw_sync(raw),
    .stable_dark(dark),.stable_valid(valid));
  initial begin
    repeat(3) @(negedge clk); resetn=1;
    repeat(12) @(negedge clk);
    if (valid !== 1 || dark !== 0) $fatal(1,"light input initially dark");
    cds=0; // LOW interpreted DARK under default polarity.
    @(negedge clk); cds=1; // Short glitch must be suppressed.
    repeat(12) @(negedge clk);
    if (dark !== 0) $fatal(1,"glitch changed filtered value");
    cds=0; repeat(12) @(negedge clk);
    if (raw !== 0 || valid !== 1 || dark !== 1) $fatal(1,"dark not confirmed");
    // Reverse polarity: sensor becomes invalid until the new candidate settles.
    dark_when_low=0;
    repeat(2) @(negedge clk);
    if (valid !== 0) $fatal(1,"polarity change did not invalidate");
    repeat(12) @(negedge clk);
    if (valid !== 1 || dark !== 0) $fatal(1,"high-active polarity failed");
    cds=1; repeat(12) @(negedge clk);
    if (dark !== 1) $fatal(1,"new active-high dark reading failed");
    resetn=0; repeat(3) @(negedge clk);
    if (dark !== 0 || valid !== 0) $fatal(1,"reset failed");
    $display("RTL_SIM_cds_digital_core PASS (2FF/glitch/polarity/reset)");
    $finish;
  end
  initial begin #200000; $fatal(1,"TIMEOUT"); end
endmodule
