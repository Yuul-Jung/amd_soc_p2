#ifndef P2_04_PWM_LOGIC_H
#define P2_04_PWM_LOGIC_H
#include <stdint.h>

typedef enum {PWM_NOT_COMMAND=0, PWM_VALID, PWM_INVALID} PwmParseResult;
// Accept exactly "PWM 0".."PWM 100" with no extra spaces/leading zeroes.
PwmParseResult pwm_parse_command(const char *line, uint8_t *percent);
uint32_t pwm_duty_for_percent(uint32_t period, uint8_t percent);
#endif
