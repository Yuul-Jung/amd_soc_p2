#ifndef P2_12_STEPPER_AXI_H
#define P2_12_STEPPER_AXI_H
#include <stdint.h>
#include "stepper_logic.h"
// 실제 Address Editor/XSA/BSP에서 확인한 전용 IP baseaddr만 사용.
int stepper_axi_start(uintptr_t baseaddr, const stepper_cfg_t *cfg);
void stepper_axi_stop(uintptr_t baseaddr);
uint32_t stepper_axi_status(uintptr_t baseaddr);
uint32_t stepper_axi_steps_done(uintptr_t baseaddr);
#endif
