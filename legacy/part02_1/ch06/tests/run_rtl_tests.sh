#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/out
if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
  echo 'RTL_SIM NOT_RUN: iverilog/vvp not installed; no RTL PASS claim'
  exit 2
fi
iverilog -g2012 -Wall -s tb_hc_sr04_core -o tests/out/tb_core \
  rtl/hc_sr04_core.v tests/tb_hc_sr04_core.v
vvp tests/out/tb_core
iverilog -g2012 -Wall -s tb_p2_06_axi_sonic -o tests/out/tb_axi \
  rtl/hc_sr04_core.v rtl/p2_06_axi_sonic_v1_0_S00_AXI.v \
  rtl/p2_06_axi_sonic_v1_0.v tests/tb_p2_06_axi_sonic.v
vvp tests/out/tb_axi
