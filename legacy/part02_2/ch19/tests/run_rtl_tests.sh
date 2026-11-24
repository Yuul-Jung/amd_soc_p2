#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo "P2_19 RTL NOT_RUN: missing iverilog";exit 2; }
command -v vvp >/dev/null || { echo "P2_19 RTL NOT_RUN: missing vvp";exit 2; }
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -Wall -s tb_environment_policy -o "$tmp/tb" \
    rtl/environment_policy.v tests/tb_environment_policy.v
vvp "$tmp/tb"
