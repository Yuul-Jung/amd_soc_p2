#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v gcc >/dev/null || { echo "P2_13_HOST NOT_RUN: gcc missing";exit 2; }
tmp="$(mktemp -d)";trap 'rm -rf "$tmp"' EXIT
gcc -std=c11 -O2 -Wall -Wextra -Werror -pedantic -I sw \
    sw/mfrc522_picc.c tests/test_mfrc522_picc.c -o "$tmp/picc_test"
"$tmp/picc_test"
