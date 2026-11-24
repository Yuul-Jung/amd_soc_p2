#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v gcc >/dev/null || { echo "P2_12_HOST NOT_RUN (gcc unavailable)"; exit 2; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
gcc -std=c11 -Wall -Wextra -Werror -pedantic -O2 \
    -I sw sw/stepper_logic.c tests/test_stepper_logic.c \
    -o "$tmp/stepper_host"
"$tmp/stepper_host"
