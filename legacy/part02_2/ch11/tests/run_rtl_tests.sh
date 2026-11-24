#!/usr/bin/env bash
set -euo pipefail
# 04장 원본 코어를 상대경로로 참조: 기존 소스 변경/복제 불필요.
cd "$(dirname "$0")/.."
if ! command -v iverilog >/dev/null || ! command -v vvp >/dev/null; then
    echo "P2_11_RTL_SIM NOT_RUN (iverilog/vvp 미설치)"
    exit 2
fi
core="../../chapters/P2_04_Lesson_20261106/rtl/pwm_core.v"
# 현재 디렉터리는 part02/chapters/P2_11_Lesson; 형제인 04장 경로 사용.
core="../P2_04_Lesson_20261106/rtl/pwm_core.v"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
iverilog -g2012 -s tb_servo_pwm_reuse -o "$tmp/servo_tb" "$core" tests/tb_servo_pwm_reuse.v
vvp "$tmp/servo_tb"
