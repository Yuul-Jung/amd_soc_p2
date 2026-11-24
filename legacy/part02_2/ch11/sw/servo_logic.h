#ifndef P2_11_SERVO_LOGIC_H
#define P2_11_SERVO_LOGIC_H
#include <stdint.h>
// P2-11: 전기적 출력 없이 수행하는 순수 각도 -> PWM 환산 로직.
// 클록 주파수는 실제 Vivado AXI Clock Frequency를 사용한다.
typedef struct {
    uint32_t period_ticks;
    uint32_t duty_ticks;
} servo_config_t;
// 반환: 0=정상, -1=잘못된 입력/범위/클록
int servo_angle_to_config(uint32_t clock_hz, int angle_deg,
                          servo_config_t *out);
#endif
