#include "servo_axi.h"
#include "servo_logic.h"
#include "xil_io.h"
// P2-04 원본 AXI PWM IP의 변경 없는 오프셋 사용.
// 0x00 PERIOD_CFG / 0x04 DUTY_CFG / 0x08 CONTROL / 0x0C APPLY
// 0x10 STATUS / 0x14 ACTIVE_PERIOD / 0x18 ACTIVE_DUTY / 0x1C ID
#define PWM_PERIOD  0x00u
#define PWM_DUTY    0x04u
#define PWM_CONTROL 0x08u
#define PWM_APPLY   0x0Cu
int servo_axi_set_angle(uintptr_t baseaddr, uint32_t clock_hz, int angle_deg)
{
    servo_config_t c;
    if (servo_angle_to_config(clock_hz, angle_deg, &c) != 0)
        return -1;
    // 별도 P2-11 인스턴스에만 접근. 기존 LED1 PWM IP 주소 사용 금지.
    Xil_Out32(baseaddr + PWM_PERIOD, c.period_ticks);
    Xil_Out32(baseaddr + PWM_DUTY, c.duty_ticks);
    Xil_Out32(baseaddr + PWM_CONTROL, 1u); // enable=1, normal polarity
    Xil_Out32(baseaddr + PWM_APPLY, 1u);   // 다음 PWM 주기 경계 적용
    return 0;
}
int servo_axi_disable(uintptr_t baseaddr)
{
    // 모터 신호를 바로 LOW로 만들지 않고 다음 프레임 경계에 적용.
    Xil_Out32(baseaddr + PWM_CONTROL, 0u);
    Xil_Out32(baseaddr + PWM_APPLY, 1u);
    return 0;
}
