`timescale 1ns/1ps
// Vivado-only 1-Wire IOBUF boundary. Separate from portable RTL tests.
// dq_drive_low=1 drives logic LOW; 0 releases DQ to external 3.3V pullup.
// Do not use 5V pullup on Basys3 FPGA input.
module ds18b20_open_drain_io(
    input wire dq_drive_low,
    inout wire ds18b20_dq,
    output wire dq_in
);
    IOBUF u_ds18b20_dq (
        .I(1'b0),.T(~dq_drive_low),.O(dq_in),.IO(ds18b20_dq)
    );
endmodule
