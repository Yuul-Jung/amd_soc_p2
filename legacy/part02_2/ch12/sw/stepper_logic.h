#ifndef P2_12_STEPPER_LOGIC_H
#define P2_12_STEPPER_LOGIC_H
#include <stdint.h>
typedef struct {
    uint32_t steps;
    uint32_t period_ticks;
    uint32_t control;
} stepper_cfg_t;
// 0=정상, -1=입력 오류 또는 32bit tick 초과.
// clock_hz는 실제 AXI IP Clock을 사용하며 가정값을 확정하지 않는다.
int stepper_make_config(uint32_t clock_hz, uint32_t step_count,
                        uint32_t interval_ms, int reverse,
                        int half_step, stepper_cfg_t *out);
#endif
