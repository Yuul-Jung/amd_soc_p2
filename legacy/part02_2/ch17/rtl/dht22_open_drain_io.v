`timescale 1ns/1ps
// Xilinx Vivado-only physical open-drain pin wrapper (NOT in portable TB).
// External pullup to SAFE 3.3V; never pull DQ high with FPGA output.
module dht22_open_drain_io(
    input wire dq_drive_low,
    inout wire dht22_dq,
    output wire dq_in
);
    IOBUF u_dht22_dq(.I(1'b0),.T(~dq_drive_low),.O(dq_in),.IO(dht22_dq));
endmodule
