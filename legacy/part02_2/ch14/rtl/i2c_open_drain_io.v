`timescale 1ns/1ps
// (추가) P2-14 Vivado 합성용 Xilinx IOBUF 경계 모듈.
// 상위 사용자 Top은 이 모듈과 RTL Core 인스턴스만 단순 연결한다.
// IOBUF T=1 is input/high-Z; T=0 drives I=0 (open-drain LOW).
// Open-drain HIGH is supplied by an external pull-up to SAFE 3.3V.
// Do NOT connect a 5V PCF8574 backpack pull-up directly to Basys3.
// Simulation of the IOBUF primitive is intentionally excluded from
// Icarus portable RTL tests; synthesis/hardware validation is deferred.
module i2c_open_drain_io(
    input wire scl_drive_low,
    input wire sda_drive_low,
    inout wire i2c_scl,
    inout wire i2c_sda,
    output wire sda_in
);
    wire unused_scl_in;
    IOBUF u_scl_buf (
        .I(1'b0), .T(~scl_drive_low),
        .O(unused_scl_in), .IO(i2c_scl)
    );
    IOBUF u_sda_buf (
        .I(1'b0), .T(~sda_drive_low),
        .O(sda_in), .IO(i2c_sda)
    );
endmodule
