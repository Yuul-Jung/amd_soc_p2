#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/out
if ! command -v iverilog >/dev/null 2>&1; then
  echo 'NOT_RUN: iverilog is not installed'; exit 2
fi
iverilog -g2012 -s tb_motor_controller -o tests/out/tb_motor \
  tests/tb_motor_controller.v rtl/motor_controller.v
vvp tests/out/tb_motor
iverilog -g2012 -s tb_p2_07_axi_motor -o tests/out/tb_motor_axi \
  tests/tb_p2_07_axi_motor.v \
  rtl/motor_controller.v rtl/p2_07_axi_motor_v1_0_S00_AXI.v
vvp tests/out/tb_motor_axi
