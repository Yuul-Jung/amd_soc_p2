#ifndef P2_12_STEPPER_RAMP_LOGIC_H
#define P2_12_STEPPER_RAMP_LOGIC_H
#include <stdint.h>
// P2-12.4 별도 확장 코어의 설정. 기존 stepper_logic.*는 변경하지 않는다.
typedef struct {
    uint32_t steps;
    uint32_t start_ticks;
    uint32_t cruise_ticks;
    uint32_t delta_ticks;
    uint32_t ramp_steps;
    uint32_t control; // bit0 reverse, bit1 half
} stepper_ramp_cfg_t;
// 0 정상, -1 범위/구간/정밀도 오류.
int stepper_ramp_make_config(uint32_t clock_hz, uint32_t steps,
    uint32_t start_ms, uint32_t cruise_ms, uint32_t ramp_steps,
    int reverse, int half_step, stepper_ramp_cfg_t *out);
#endif
