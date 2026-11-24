#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/out
cc -std=c11 -Wall -Wextra -Werror -pedantic -fsanitize=undefined -fno-sanitize-recover=all -Isw \
  tests/test_pwm_logic.c sw/p2_04_pwm_logic.c sw/p2_03_logic.c -o tests/out/host_logic
./tests/out/host_logic
for MODE in SDT CLASSIC; do
    EXTRA=()
    if [[ "$MODE" == SDT ]]; then
        EXTRA+=( -DSDT -DP2_03_BTN_INTR_PARENT=0x41200000U )
    else
        EXTRA+=( -DP2_03_INTC_DEVICE_ID=0 )
    fi
    cc -std=c11 -Wall -Wextra -Werror -fsyntax-only \
      -Itests/stubs -Isw "${EXTRA[@]}" \
      -DP2_01_LED_BASEADDR=0x43C00000U \
      -DP2_02_FND_BASEADDR=0x43C10000U \
      -DP2_03_BTN_BASEADDR=0x43C20000U \
      -DP2_04_PWM_BASEADDR=0x43C30000U \
      -DP2_03_BTN_INTR_ID=2U sw/main_p2_04.c
    echo "HOST_${MODE}_MOCK_BSP_SYNTAX PASS (not real target BSP)"
done
if cc -std=c11 -fsyntax-only -Itests/stubs -Isw sw/main_p2_04.c >tests/out/missing_macros.log 2>&1; then
    echo "ERROR: missing addresses incorrectly permitted"; exit 1
fi
echo "MISSING_BSP_MACROS_EXPECTED_FAIL PASS"
if cc -std=c11 -fsyntax-only -Itests/stubs -Isw -DSDT \
  -DP2_01_LED_BASEADDR=0x43C00000U \
  -DP2_02_FND_BASEADDR=0x43C10000U \
  -DP2_03_BTN_BASEADDR=0x43C20000U \
  -DP2_04_PWM_BASEADDR=0x43C20000U \
  -DP2_03_BTN_INTR_ID=2U -DP2_03_BTN_INTR_PARENT=0x41200000U \
  sw/main_p2_04.c >tests/out/duplicate_address.log 2>&1; then
    echo "ERROR: duplicate AXI IP addresses incorrectly permitted";exit 1
fi
echo "DUPLICATE_AXI_ADDRESS_EXPECTED_FAIL PASS"
