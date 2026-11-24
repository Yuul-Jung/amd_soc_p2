#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo "P2_13_RTL NOT_RUN: iverilog missing"; exit 2; }
command -v vvp >/dev/null || { echo "P2_13_RTL NOT_RUN: vvp missing"; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -Wall -s tb_mfrc522_spi_master -o "$tmp/spi_tb" \
    rtl/mfrc522_spi_master.v tests/tb_mfrc522_spi_master.v
vvp "$tmp/spi_tb"

iverilog -g2012 -Wall -s tb_mfrc522_version_system -o "$tmp/probe_tb" \
    rtl/mfrc522_spi_master.v rtl/mfrc522_version_probe.v \
    rtl/mfrc522_version_system.v tests/tb_mfrc522_version_system.v
vvp "$tmp/probe_tb"
