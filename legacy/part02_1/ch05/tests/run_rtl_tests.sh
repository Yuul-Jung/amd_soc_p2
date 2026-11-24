#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v iverilog >/dev/null || ! command -v vvp >/dev/null; then
  echo 'RTL_SIM NOT_RUN: Icarus Verilog (iverilog + vvp) unavailable'
  exit 0
fi
mkdir -p tests/out
iverilog -g2012 -s tb_auto_light_controller -o tests/out/tb_gate \
  rtl/auto_light_controller.v tests/tb_auto_light_controller.v
vvp tests/out/tb_gate
iverilog -g2012 -s tb_cds_digital_core -o tests/out/tb_filter \
  rtl/cds_digital_core.v tests/tb_cds_digital_core.v
vvp tests/out/tb_filter
iverilog -g2012 -s tb_p2_05_axi_cds -o tests/out/tb_axi \
  rtl/cds_digital_core.v rtl/p2_05_axi_cds_v1_0_S00_AXI.v \
  rtl/p2_05_axi_cds_v1_0.v tests/tb_p2_05_axi_cds.v
vvp tests/out/tb_axi
