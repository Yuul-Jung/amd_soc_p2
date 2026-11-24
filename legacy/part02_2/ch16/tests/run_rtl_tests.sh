#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo "P2_16 RTL NOT_RUN: iverilog missing";exit 2; }
command -v vvp >/dev/null || { echo "P2_16 RTL NOT_RUN: vvp missing";exit 2; }
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -Wall -s tb_ds3231_burst_sequencer -o "$tmp/rtc_tb" \
    rtl/ds3231_burst_sequencer.v tests/tb_ds3231_burst_sequencer.v
vvp "$tmp/rtc_tb"
