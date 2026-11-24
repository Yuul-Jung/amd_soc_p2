#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo "P2_14 RTL NOT_RUN: iverilog missing";exit 2; }
command -v vvp >/dev/null || { echo "P2_14 RTL NOT_RUN: vvp missing";exit 2; }
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -Wall -s tb_lcd_i2c_hello_system -o "$tmp/lcd_tb" \
    rtl/i2c_write_byte_master.v rtl/lcd_pcf8574_hello.v \
    rtl/lcd_i2c_hello_system.v tests/tb_lcd_i2c_hello_system.v
vvp "$tmp/lcd_tb"

iverilog -g2012 -Wall -s tb_i2c_write_nack -o "$tmp/nack_tb" \
    rtl/i2c_write_byte_master.v tests/tb_i2c_write_nack.v
vvp "$tmp/nack_tb"
