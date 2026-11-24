#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo "P2_17 RTL NOT_RUN: iverilog missing"; exit 2; }
command -v vvp >/dev/null || { echo "P2_17 RTL NOT_RUN: vvp missing"; exit 2; }
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -Wall -s tb_dht22_controller -o "$tmp/dht22_tb" \
    rtl/dht22_controller.v tests/tb_dht22_controller.v
vvp "$tmp/dht22_tb"
