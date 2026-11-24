#!/usr/bin/env bash
set -euo pipefail
# Install iverilog and vvp on the Ubuntu machine that runs RTL simulations.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$ROOT/rtl"
OUT="${TMPDIR:-/tmp}/p2_02_iverilog_$$"
mkdir -p "$OUT"
trap 'rm -rf "$OUT"' EXIT
iverilog -g2012 -Wall -s tb_fnd_scan_controller -o "$OUT/fnd.vvp" \
  "$RTL/fnd_scan_controller.v" "$ROOT/tests/tb_fnd_scan_controller.v"
vvp "$OUT/fnd.vvp"
iverilog -g2012 -Wall -s tb_p2_02_axi_fnd -o "$OUT/axi.vvp" \
  "$RTL/fnd_scan_controller.v" \
  "$RTL/p2_02_axi_fnd_v1_0_S00_AXI.v" \
  "$RTL/p2_02_axi_fnd_v1_0.v" \
  "$ROOT/tests/tb_p2_02_axi_fnd.v"
vvp "$OUT/axi.vvp"
