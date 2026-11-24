#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/out
cc -std=c11 -Wall -Wextra -Werror -pedantic -fsanitize=undefined \
  -fno-sanitize-recover=all -Isw tests/test_cds_logic.c \
  sw/p2_05_cds_logic.c sw/p2_04_pwm_logic.c sw/p2_03_logic.c \
  -o tests/out/test_cds_logic
./tests/out/test_cds_logic
for MODE in SDT CLASSIC; do
  EXTRAS=()
  if [ "$MODE" = SDT ]; then
    EXTRAS+=( -DSDT -DP2_03_BTN_INTR_PARENT=0x41200000U )
  else
    EXTRAS+=( -DP2_03_INTC_DEVICE_ID=0U )
  fi
  cc -std=c11 -Wall -Wextra -Werror -fsyntax-only -Itests/stubs -Isw \
    "${EXTRAS[@]}" \
    -DP2_01_LED_BASEADDR=0x43C00000U \
    -DP2_02_FND_BASEADDR=0x43C10000U \
    -DP2_03_BTN_BASEADDR=0x43C20000U \
    -DP2_04_PWM_BASEADDR=0x43C30000U \
    -DP2_05_CDS_BASEADDR=0x43C40000U \
    -DP2_03_BTN_INTR_ID=2U sw/main_p2_05.c
  echo "HOST_${MODE}_MOCK_BSP_SYNTAX PASS (not Vitis target)"
done
if cc -std=c11 -fsyntax-only -Itests/stubs -Isw \
  sw/main_p2_05.c >tests/out/unknown_bsp.log 2>&1; then
  echo 'FAIL: unknown BSP addresses were not blocked'; exit 1
fi
echo 'UNKNOWN_ADDRESS_EXPECTED_FAIL PASS'
if cc -std=c11 -fsyntax-only -Itests/stubs -Isw -DSDT \
  -DP2_03_BTN_INTR_PARENT=0x41200000U -DP2_03_BTN_INTR_ID=2U \
  -DP2_01_LED_BASEADDR=0x43C00000U \
  -DP2_02_FND_BASEADDR=0x43C10000U \
  -DP2_03_BTN_BASEADDR=0x43C20000U \
  -DP2_04_PWM_BASEADDR=0x43C30000U \
  -DP2_05_CDS_BASEADDR=0x43C30000U \
  sw/main_p2_05.c >tests/out/duplicate_axi.log 2>&1; then
  echo 'FAIL: duplicate AXI addresses were not blocked'; exit 1
fi
echo 'DUPLICATE_ADDRESS_EXPECTED_FAIL PASS'
