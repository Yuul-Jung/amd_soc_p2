#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/out
cc -std=c11 -Wall -Wextra -Werror -pedantic -fsanitize=undefined \
  -fno-sanitize-recover=all -Isw tests/test_adc_logic.c sw/p2_08_adc_logic.c \
  -o tests/out/test_adc_logic
./tests/out/test_adc_logic
for MODE in SDT CLASSIC; do
  EXTRA=()
  if [ "$MODE" = SDT ]; then
    EXTRA=(-DSDT -DP2_03_BTN_INTR_PARENT=0x41200000U)
  else
    EXTRA=(-DP2_03_INTC_DEVICE_ID=0U)
  fi
  cc -std=c11 -Wall -Wextra -Werror -fsyntax-only \
    -Itests/stubs -Isw "${EXTRA[@]}" \
    -DP2_01_LED_BASEADDR=0x43C00000U \
    -DP2_02_FND_BASEADDR=0x43C10000U \
    -DP2_03_BTN_BASEADDR=0x43C20000U \
    -DP2_04_PWM_BASEADDR=0x43C30000U \
    -DP2_05_CDS_BASEADDR=0x43C40000U \
    -DP2_06_SONIC_BASEADDR=0x43C50000U \
    -DP2_07_MOTOR_BASEADDR=0x43C60000U \
    -DP2_08_XADC_BASEADDR=0x43C70000U \
    -DP2_03_BTN_INTR_ID=2U sw/main_p2_08.c
  echo "P2_08_${MODE}_HOST_MOCK_BSP_SYNTAX_PASS (NOT Vitis build)"
done
COMMON=( -std=c11 -fsyntax-only -Itests/stubs -Isw -DSDT \
  -DP2_03_BTN_INTR_PARENT=0x41200000U -DP2_03_BTN_INTR_ID=2U \
  -DP2_01_LED_BASEADDR=0x43C00000U \
  -DP2_02_FND_BASEADDR=0x43C10000U \
  -DP2_03_BTN_BASEADDR=0x43C20000U \
  -DP2_04_PWM_BASEADDR=0x43C30000U \
  -DP2_05_CDS_BASEADDR=0x43C40000U \
  -DP2_06_SONIC_BASEADDR=0x43C50000U \
  -DP2_07_MOTOR_BASEADDR=0x43C60000U )
if cc "${COMMON[@]}" sw/main_p2_08.c >/dev/null 2>&1; then
  echo 'ERROR missing XADC address was accepted';exit 1
fi
echo 'EXPECTED_FAIL_MISSING_XADC_ADDRESS_PASS'
if cc "${COMMON[@]}" -DP2_08_XADC_BASEADDR=0x43C60000U sw/main_p2_08.c >/dev/null 2>&1; then
  echo 'ERROR duplicate XADC base was accepted';exit 1
fi
echo 'EXPECTED_FAIL_DUPLICATE_XADC_ADDRESS_PASS'
