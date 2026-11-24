#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v iverilog >/dev/null || ! command -v vvp >/dev/null; then
  echo "RTL_SIM_NOT_RUN: install iverilog/vvp or use Vivado Simulator"
  exit 2
fi
iverilog -g2012 -s tb_button_event_core -o /tmp/tb_p2_03_btn.vvp \
  rtl/button_event_core.v tests/tb_button_event_core.v
vvp /tmp/tb_p2_03_btn.vvp
iverilog -g2012 -s tb_p2_03_axi_buttons -o /tmp/tb_p2_03_axi.vvp \
  rtl/p2_03_axi_buttons_v1_0_S00_AXI.v tests/tb_p2_03_axi_buttons.v
vvp /tmp/tb_p2_03_axi.vvp
