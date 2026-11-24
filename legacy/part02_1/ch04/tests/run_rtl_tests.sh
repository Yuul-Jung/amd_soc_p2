#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/out
if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
  echo "RTL_SIM NOT_RUN: iverilog/vvp not available. Vivado xsim is an alternative."
  exit 2
fi
iverilog -g2012 -s tb_pwm_core -o tests/out/tb_core \
  rtl/pwm_core.v tests/tb_pwm_core.v
vvp tests/out/tb_core
iverilog -g2012 -s tb_p2_04_axi_pwm -o tests/out/tb_axi \
  rtl/pwm_core.v rtl/p2_04_axi_pwm_v1_0_S00_AXI.v \
  rtl/p2_04_axi_pwm_v1_0.v tests/tb_p2_04_axi_pwm.v
vvp tests/out/tb_axi
