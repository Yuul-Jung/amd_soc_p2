#include "p2_04_pwm_logic.h"
#include <string.h>

PwmParseResult pwm_parse_command(const char *line, uint8_t *percent)
{
    unsigned value = 0U;
    const char *p;
    // (유지) 기존 LED/DISP 명령은 p2_parse_command()에서 처리.
    if (strncmp(line, "PWM", 3) != 0) return PWM_NOT_COMMAND;
    if (line[3] != ' ') return PWM_INVALID;
    p = line + 4;
    if (*p < '0' || *p > '9') return PWM_INVALID;
    if (*p == '0' && p[1] != '\0') return PWM_INVALID;
    while (*p >= '0' && *p <= '9') {
        value = 10U * value + (unsigned)(*p - '0');
        if (value > 100U) return PWM_INVALID; // 100 초과는 곧바로 차단해 오버플로 방지.
        ++p;
    }
    if (*p != '\0') return PWM_INVALID;
    *percent = (uint8_t)value;
    return PWM_VALID;
}

uint32_t pwm_duty_for_percent(uint32_t period, uint8_t percent)
{
    // (추가) 주기값 × 퍼센트의 곱셈을 64비트로 수행.
    if (percent > 100U) return period; // 방어적 상한 처리. UART parser에서는 오류로 차단.
    return (uint32_t)(((uint64_t)period * percent) / 100U);
}
