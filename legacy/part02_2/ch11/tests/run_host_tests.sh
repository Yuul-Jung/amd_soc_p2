#!/usr/bin/env bash
set -euo pipefail
# 생성 결과를 저장소에 남기지 않는 호스트 단위 검사.
cd "$(dirname "$0")/.."
command -v gcc >/dev/null || { echo "HOST_C NOT_RUN: gcc 없음"; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
gcc -std=c11 -Wall -Wextra -Werror -pedantic -O2 \
    -I sw sw/servo_logic.c tests/test_servo_logic.c -o "$tmp/test_servo"
"$tmp/test_servo"
gcc -std=c11 -Wall -Wextra -Werror -pedantic -O2 \
    -I sw sw/servo_command.c tests/test_servo_command.c -o "$tmp/test_command"
"$tmp/test_command"
