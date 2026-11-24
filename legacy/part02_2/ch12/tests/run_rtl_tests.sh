#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v iverilog >/dev/null || ! command -v vvp >/dev/null; then
    echo "P2_12_RTL_SIM NOT_RUN (iverilog/vvp unavailable)"
    exit 2
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -Wall -s tb_stepper_core -o "$tmp/tb_stepper" \
    rtl/stepper_core.v tests/tb_stepper_core.v
vvp "$tmp/tb_stepper"

# AXI4-Lite Stepper IP 전체 시뮬레이션
iverilog -g2012 -Wall -s tb_p2_12_axi_stepper -o "$tmp/tb_stepper_axi" \
    rtl/stepper_core.v rtl/p2_12_axi_stepper_v1_0.v \
    tests/tb_p2_12_axi_stepper.v
vvp "$tmp/tb_stepper_axi"
