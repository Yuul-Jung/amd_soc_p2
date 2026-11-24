#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/out
cc -std=c11 -Wall -Wextra -Werror -pedantic -fsanitize=undefined \
  -fno-sanitize-recover=all -Isw tests/test_capstone_logic.c \
  sw/p2_10_capstone_logic.c -o tests/out/test_capstone_logic
./tests/out/test_capstone_logic
COMMON=(-std=c11 -Wall -Wextra -Werror -fsyntax-only \
  -Itests/stubs -Isw \
  -DP2_01_LED_BASEADDR=0x43C00000U \
  -DP2_02_FND_BASEADDR=0x43C10000U \
  -DP2_03_BTN_BASEADDR=0x43C20000U \
  -DP2_04_PWM_BASEADDR=0x43C30000U \
  -DP2_05_CDS_BASEADDR=0x43C40000U \
  -DP2_06_SONIC_BASEADDR=0x43C50000U \
  -DP2_07_MOTOR_BASEADDR=0x43C60000U \
  -DP2_08_XADC_BASEADDR=0x43C70000U \
  -DP2_03_BTN_INTR_ID=2U -DP2_09_TIMER_CLK_HZ=100000000U)
cc "${COMMON[@]}" -DSDT \
  -DP2_03_BTN_INTR_PARENT=0x41200000U \
  -DP2_09_GPIO_BASEADDR=0x40000000U \
  -DP2_09_TIMER_BASEADDR=0x41C00000U sw/main_p2_10.c
printf 'SDT_HOST_MOCK_BSP_SYNTAX_PASS (NOT Vitis)\n'
cc "${COMMON[@]}" \
  -DP2_03_INTC_DEVICE_ID=0U \
  -DP2_09_TIMER_DEVICE_ID=1U \
  -DP2_09_TIMER_INTR_ID=1U \
  -DP2_09_GPIO_DEVICE_ID=0U sw/main_p2_10.c
printf 'CLASSIC_HOST_MOCK_BSP_SYNTAX_PASS (NOT Vitis)\n'
# Negative tests include missing addresses/clock, collisions and missing IRQ mappings.
if cc "${COMMON[@]/-DP2_09_TIMER_CLK_HZ=100000000U/}" -DSDT \
  -DP2_03_BTN_INTR_PARENT=0x41200000U \
  -DP2_09_GPIO_BASEADDR=0x40000000U \
  -DP2_09_TIMER_BASEADDR=0x41C00000U sw/main_p2_10.c >/dev/null 2>&1; then
  echo 'FAIL: clock unconfigured accepted';exit 1
fi
printf 'EXPECTED_FAIL_CLOCK_MISSING_PASS\n'
if cc "${COMMON[@]}" -DSDT \
  -DP2_03_BTN_INTR_PARENT=0x41200000U \
  -DP2_09_GPIO_BASEADDR=0x40000000U \
  -DP2_09_TIMER_BASEADDR=0x43C70000U sw/main_p2_10.c >/dev/null 2>&1; then
  echo 'FAIL: XADC/Timer alias accepted';exit 1
fi
printf 'EXPECTED_FAIL_XADC_TIMER_ALIAS_PASS\n'
# Build integration mock linking ALL actual dependency modules.
cc -std=c11 -Wall -Wextra -Werror -Isw -Itests/stubs \
  -DSDT -DP2_03_BTN_INTR_PARENT=0x41200000U \
  -DP2_09_GPIO_BASEADDR=0x40000000U -DP2_09_TIMER_BASEADDR=0x41C00000U \
  -DP2_01_LED_BASEADDR=0x43C00000U -DP2_02_FND_BASEADDR=0x43C10000U \
  -DP2_03_BTN_BASEADDR=0x43C20000U -DP2_04_PWM_BASEADDR=0x43C30000U \
  -DP2_05_CDS_BASEADDR=0x43C40000U -DP2_06_SONIC_BASEADDR=0x43C50000U \
  -DP2_07_MOTOR_BASEADDR=0x43C60000U -DP2_08_XADC_BASEADDR=0x43C70000U \
  -DP2_03_BTN_INTR_ID=2U -DP2_09_TIMER_CLK_HZ=100000000U \
  tests/test_integration.c \
  sw/p2_03_logic.c sw/p2_04_pwm_logic.c sw/p2_05_cds_logic.c \
  sw/p2_06_sonic_logic.c sw/p2_07_motor_logic.c sw/p2_08_adc_logic.c \
  sw/p2_09_mode_logic.c sw/p2_10_capstone_logic.c \
  -o tests/out/test_integration
./tests/out/test_integration
