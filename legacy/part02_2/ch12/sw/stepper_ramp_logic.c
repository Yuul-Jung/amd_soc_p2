#include "stepper_ramp_logic.h"
#include <stdint.h>
#include <limits.h>
int stepper_ramp_make_config(uint32_t clock_hz, uint32_t steps,
    uint32_t start_ms, uint32_t cruise_ms, uint32_t ramp_steps,
    int reverse, int half_step, stepper_ramp_cfg_t *out)
{
    uint64_t slow,fast,diff;
    if(!out || clock_hz < 1000000u || clock_hz > 200000000u ||
       steps < 3u || steps > 100000u ||
       ramp_steps == 0u || ramp_steps > (steps-1u)/2u ||
       start_ms < 2u || start_ms > 100u ||
       cruise_ms < 2u || cruise_ms >= start_ms ||
       (reverse != 0 && reverse != 1) ||
       (half_step != 0 && half_step != 1)) return -1;
    slow=((uint64_t)clock_hz * start_ms) / 1000u;
    fast=((uint64_t)clock_hz * cruise_ms) / 1000u;
    if(slow > UINT32_MAX || fast > UINT32_MAX || fast < 2u)
        return -1;
    diff=slow-fast;
    // 매 스텝 간격 차이가 정수 tick으로 정확하게 일치해야 한다.
    if(diff < ramp_steps || diff % ramp_steps != 0u)
        return -1;
    if(diff/ramp_steps > UINT32_MAX)
        return -1;
    out->steps=steps;
    out->start_ticks=(uint32_t)slow;
    out->cruise_ticks=(uint32_t)fast;
    out->delta_ticks=(uint32_t)(diff/ramp_steps);
    out->ramp_steps=ramp_steps;
    out->control=(uint32_t)reverse | ((uint32_t)half_step << 1);
    return 0;
}
