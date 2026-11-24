#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cc -std=c11 -Wall -Wextra -Werror -pedantic -Isw \
    tests/test_logic.c sw/p2_03_logic.c -o /tmp/p2_03_logic_test
/tmp/p2_03_logic_test
# Strict syntax check, both SDT and Classic paths; dummy values are test-only.
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
    -DP2_03_BTN_INTR_ID=2U sw/main_p2_03.c
  echo "HOST_${MODE}_STUB_SYNTAX PASS (not actual BSP)"
done
# Absence of actual base/IRQ constants must fail the compilation.
if cc -std=c11 -fsyntax-only -Itests/stubs -Isw sw/main_p2_03.c >/tmp/p2_03_guard.log 2>&1; then
  echo "FAIL: unconfigured addresses/IRQ unexpectedly compiled"; exit 1
fi
echo "UNCONFIGURED_TARGET_BUILD_FAIL_EXPECTED PASS"
