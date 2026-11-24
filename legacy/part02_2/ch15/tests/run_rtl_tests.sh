#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo "P2_15 RTL NOT_RUN: iverilog missing";exit 2; }
command -v vvp >/dev/null || { echo "P2_15 RTL NOT_RUN: vvp missing";exit 2; }
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -Wall -s tb_ds18b20_controller -o "$tmp/ds18b20_tb" \
  rtl/onewire_slot_master.v rtl/ds18b20_controller.v \
  tests/tb_ds18b20_controller.v
vvp "$tmp/ds18b20_tb"
