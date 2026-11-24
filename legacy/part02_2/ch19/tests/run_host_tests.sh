#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v gcc >/dev/null || { echo "P2_19 HOST_C NOT_RUN: missing gcc";exit 2; }
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
gcc -std=c11 -Wall -Wextra -Werror -pedantic -O2 -I sw \
  sw/bme280_probe.c tests/test_bme280_probe.c -o "$tmp/bme_test"
"$tmp/bme_test"
