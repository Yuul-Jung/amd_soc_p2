#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo "P2_18 RTL NOT_RUN: iverilog missing"; exit 2; }
command -v vvp >/dev/null || { echo "P2_18 RTL NOT_RUN: vvp missing"; exit 2; }
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -Wall -s tb_pir_irq_controller -o "$tmp/pir_tb" \
    rtl/pir_irq_controller.v tests/tb_pir_irq_controller.v
vvp "$tmp/pir_tb"

iverilog -g2012 -Wall -s tb_p2_18_axi_pir_irq -o "$tmp/axi_tb" \
    rtl/pir_irq_controller.v rtl/p2_18_axi_pir_irq_v1_0.v \
    tests/tb_p2_18_axi_pir_irq.v
vvp "$tmp/axi_tb"
