#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo "P2_20 RTL NOT_RUN: missing iverilog";exit 2; }
command -v vvp >/dev/null || { echo "P2_20 RTL NOT_RUN: missing vvp";exit 2; }
repo_root="$(cd ../../.. && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -Wall -s tb_soc20_integrated_core -o "$tmp/integrated_tb" \
    "$repo_root/part02/chapters/P2_18_Lesson/rtl/pir_irq_controller.v" \
    "$repo_root/part02/chapters/P2_19_Lesson/rtl/environment_policy.v" \
    "$repo_root/part02/chapters/P2_12_Lesson/rtl/stepper_ramp_core.v" \
    rtl/soc20_safety_supervisor.v rtl/soc20_integrated_core.v \
    tests/tb_soc20_integrated_core.v
vvp "$tmp/integrated_tb"
