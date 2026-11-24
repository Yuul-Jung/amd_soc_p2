`timescale 1ns/1ps
// P2-15 self-checking simulated DS18B20, does NOT model analog bus.
// Checks 2 resets/presence, CC/44/CC/BE TX, nine scratchpad bytes,
// signed temperature_raw, CRC rejection, missing presence.
module tb_ds18b20_controller;
  reg clk=0;always #5 clk=~clk;
  reg resetn=0,start=0,presence_enabled=1,corrupt_crc=0;
  wire dq_drive_low,done,error,busy;
  wire [2:0] error_code;
  wire signed [15:0] temperature_raw;
  reg [7:0] scratch[0:8];
  reg [7:0] crc_local;
  integer i,j,case_number=0,command_bits=0,reset_count=0;
  reg [7:0] command_bytes[0:3];
  reg [7:0] current_byte;
  reg slave_low;
  wire dq_in = !(dq_drive_low || slave_low);
  ds18b20_controller #(
      .CLK_HZ(1000000),.CONVERT_WAIT_US(20)
  ) dut(
    .clk(clk),.resetn(resetn),.start_pulse(start),
    .dq_in(dq_in),.dq_drive_low(dq_drive_low),
    .busy(busy),.done_pulse(done),.error_pulse(error),
    .error_code(error_code),.temperature_raw(temperature_raw)
  );
  function [7:0] crc_byte;
    input [7:0] crc_in;
    input [7:0] b;
    reg [7:0] c;
    integer n;
    begin
      c=crc_in;
      for(n=0;n<8;n=n+1) begin
        if(c[0]^b[n]) c=(c>>1)^8'h8c;
        else c=c>>1;
      end
      crc_byte=c;
    end
  endfunction
  task set_scratchpad;
    input [15:0] raw;
    begin
      scratch[0]=raw[7:0];scratch[1]=raw[15:8];
      scratch[2]=8'h4b;scratch[3]=8'h46;
      scratch[4]=8'h7f;scratch[5]=8'hff;
      scratch[6]=8'h0c;scratch[7]=8'h10;
      crc_local=0;
      for(i=0;i<8;i=i+1)
        crc_local=crc_byte(crc_local,scratch[i]);
      scratch[8]=crc_local^(corrupt_crc ? 8'h01 : 8'h00);
    end
  endtask
  // Simplified digital slave drives ACK-like presence and read-zero bits
  // at the exact sampling state. This is a functional bus model, not a
  // nanosecond jitter/timing compliance test.
  always @(*) begin
    slave_low=0;
    if(presence_enabled && dut.u_slot.state==3'd2)
      slave_low=1;
    if(dut.u_slot.state==3'd5 && dut.phase==7 &&
       !scratch[dut.byte_index][dut.bit_index])
      slave_low=1;
  end

  // Collect commands only at slot transaction start, avoiding races
  // between testbench and core's registered data pins.
  always @(posedge clk) begin
    if(resetn && dut.u_slot.cmd_valid && dut.u_slot.cmd_ready) begin
      if(dut.u_slot.cmd_op==0) begin
        reset_count=reset_count+1;
      end else if(dut.u_slot.cmd_op==1) begin
        current_byte[command_bits%8]=dut.u_slot.cmd_bit;
        command_bits=command_bits+1;
        if(command_bits%8==0)
          command_bytes[command_bits/8-1]=current_byte;
      end
    end
  end
  task reset_test;
    begin
      resetn=0;start=0;
      repeat(4) @(negedge clk);
      resetn=1;command_bits=0;reset_count=0;
    end
  endtask
  task kick;
    begin
      @(negedge clk);start=1;
      @(negedge clk);start=0;
    end
  endtask
  initial begin
    corrupt_crc=0;set_scratchpad(16'h0191);
    reset_test; kick;
    wait(done); #1;
    if(error || error_code || busy || temperature_raw!==16'h0191)
      $fatal(1,"positive temp incorrect: %h",temperature_raw);
    if(reset_count!=2 || command_bits!=32 ||
       command_bytes[0]!==8'hcc || command_bytes[1]!==8'h44 ||
       command_bytes[2]!==8'hcc || command_bytes[3]!==8'hbe)
      $fatal(1,"command sequence wrong resets=%0d bits=%0d %h %h %h %h",
             reset_count,command_bits,
             command_bytes[0],command_bytes[1],
             command_bytes[2],command_bytes[3]);
    $display("P2_15_DS18B20_POSITIVE_CRC_COMMAND_PASS");

    corrupt_crc=0;set_scratchpad(16'hff5e);
    reset_test;kick;wait(done);#1;
    if(busy || temperature_raw!==16'hff5e)
      $fatal(1,"negative signed temperature wrong: %h",temperature_raw);
    $display("P2_15_DS18B20_NEGATIVE_TEMP_PASS");

    corrupt_crc=1;set_scratchpad(16'h0191);
    reset_test;kick;wait(error);#1;
    if(error_code!=2 || busy || temperature_raw!==16'h0000)
      $fatal(1,"CRC error not rejected or untrusted temperature published");
    $display("P2_15_DS18B20_CRC_REJECT_PASS");

    corrupt_crc=0;set_scratchpad(16'h0191);presence_enabled=0;
    reset_test;kick;wait(error);#1;
    if(error_code!=1 || reset_count!=1 || busy)
      $fatal(1,"missing presence not detected");
    $display("P2_15_DS18B20_NO_PRESENCE_PASS");

    $display("P2_15_DS18B20_CONTROLLER_RTL PASS");
    $finish;
  end
  initial begin #4000000;$fatal(1,"TIMEOUT");end
endmodule
