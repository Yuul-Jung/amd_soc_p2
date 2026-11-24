#ifndef P2_11_SERVO_AXI_H
#define P2_11_SERVO_AXI_H
#include <stdint.h>
// 반드시 실제 xparameters.h/시스템 Device Tree에서 얻은 베이스 주소를 전달.
int servo_axi_set_angle(uintptr_t baseaddr, uint32_t clock_hz, int angle_deg);
int servo_axi_disable(uintptr_t baseaddr);
#endif
