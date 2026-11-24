#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v gcc >/dev/null || { echo "P2_16 HOST NOT_RUN: gcc missing";exit 2; }
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
gcc -std=c11 -Wall -Wextra -Werror -pedantic -O2 \
    -I sw sw/ds3231_time.c tests/test_ds3231_time.c -o "$tmp/rtc_test"
"$tmp/rtc_test"
