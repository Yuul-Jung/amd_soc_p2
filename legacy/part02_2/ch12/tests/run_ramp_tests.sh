#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v iverilog >/dev/null || ! command -v vvp >/dev/null; then
    echo "P2_12_4_RTL_SIM NOT_RUN: iverilog/vvp missing"
    exit 2
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -Wall -s tb_stepper_ramp_core -o "$tmp/ramp_tb" \
    rtl/stepper_ramp_core.v tests/tb_stepper_ramp_core.v
vvp "$tmp/ramp_tb"

# P2-12.4 신규 v1_1 AXI4-Lite 래퍼 별도 검증
iverilog -g2012 -Wall -s tb_p2_12_4_axi_ramp -o "$tmp/ramp_axi_tb" \
    rtl/stepper_ramp_core.v rtl/p2_12_axi_stepper_v1_1.v \
    tests/tb_p2_12_4_axi_ramp.v
vvp "$tmp/ramp_axi_tb"
