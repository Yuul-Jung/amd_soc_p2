#include "stepper_logic.h"
#include <limits.h>
// 2~100ms: 저속에서 시작. 제조사/부하별 실제 허용 속도는 별도 보드 확인.
// full/half mode의 1스텝 각도와 감속비는 모터마다 달라질 수 있다.
int stepper_make_config(uint32_t clock_hz, uint32_t step_count,
                        uint32_t interval_ms, int reverse,
                        int half_step, stepper_cfg_t *out)
{
    uint64_t ticks;
    if (!out || clock_hz < 1000000u || clock_hz > 200000000u ||
        step_count == 0u || step_count > 100000u ||
        interval_ms < 2u || interval_ms > 100u ||
        (reverse != 0 && reverse != 1) ||
        (half_step != 0 && half_step != 1)) return -1;

    ticks = ((uint64_t)clock_hz * interval_ms) / 1000u;
    if (ticks < 2u || ticks > UINT32_MAX) return -1;
    out->steps = step_count;
    out->period_ticks = (uint32_t)ticks;
    out->control = (uint32_t)reverse | ((uint32_t)half_step << 1);
    return 0;
}
