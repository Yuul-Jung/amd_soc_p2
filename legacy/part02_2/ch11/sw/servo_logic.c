#include "servo_logic.h"
#include <limits.h>
// SG90 초기 교육 범위: 20ms 프레임, 1~2ms HIGH 펄스.
// 제조사·실물 차이로 실제 기계적 0/180도와 정확히 일치하지 않을 수 있다.
int servo_angle_to_config(uint32_t clock_hz, int angle_deg,
                          servo_config_t *out)
{
    uint64_t period, pulse_us, duty;
    if (!out || clock_hz < 1000000u || clock_hz > 200000000u ||
        angle_deg < 0 || angle_deg > 180)
        return -1;
    // round-to-nearest us: 0도 1000us, 90도 1500us, 180도 2000us.
    // 정수 연산만 사용. 32비트 곱셈 오버플로 방지를 위해 uint64_t 사용.
    pulse_us = 1000u + (uint64_t)(angle_deg * 1000 + 90) / 180u;
    period = ((uint64_t)clock_hz * 20000u + 500000u) / 1000000u;
    duty = ((uint64_t)clock_hz * pulse_us + 500000u) / 1000000u;
    if (period < 2u || period > UINT32_MAX || duty >= period)
        return -1;
    out->period_ticks = (uint32_t)period;
    out->duty_ticks = (uint32_t)duty;
    return 0;
}
