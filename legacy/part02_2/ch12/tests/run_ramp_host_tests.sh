#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v gcc >/dev/null || { echo "P2_12_4_HOST NOT_RUN"; exit 2; }
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
gcc -std=c11 -Wall -Wextra -Werror -pedantic -O2 \
    -I sw sw/stepper_ramp_logic.c tests/test_stepper_ramp_logic.c \
    -o "$tmp/ramp_host"
"$tmp/ramp_host"
