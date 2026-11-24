// P2-12.4 Vitis Ramp AXI v1.1 사용 예시.
// 원본 P2-12 V1.0 AXI IP 주소를 사용하지 않는다.
// 실제 하드웨어에서 별도 P2-12.4 IP v1.1을 패키징한 경우에만 사용한다.
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "../sw/stepper_ramp_logic.h"

#ifndef P2_12_RAMP_BASEADDR
#error "Set P2_12_RAMP_BASEADDR using actual XSA Address Editor"
#endif
#ifndef P2_12_AXI_CLOCK_HZ
#error "Set P2_12_AXI_CLOCK_HZ using actual Block Design clock"
#endif

#define R_STEPS      0x00u
#define R_START      0x04u
#define R_CONTROL    0x08u
#define R_COMMAND    0x0Cu
#define R_STATUS     0x10u
#define R_DONE       0x14u
#define R_ID         0x18u
#define R_MIN_PERIOD 0x1Cu
#define R_CRUISE     0x20u
#define R_DELTA      0x24u
#define R_RAMP_STEPS 0x28u
#define R_ACTIVE     0x2Cu

int p2_12_4_start_ramp_example(void)
{
    const UINTPTR base = (UINTPTR)P2_12_RAMP_BASEADDR;
    stepper_ramp_cfg_t c;
    uint32_t status;
    // 예제: 128 step, 10 ms → 4 ms, 가속 12 step, 감속 12 step.
    if (stepper_ramp_make_config(
            P2_12_AXI_CLOCK_HZ, 128u, 10u, 4u, 12u, 0, 1, &c) != 0) {
        xil_printf("ERR ramp config\r\n");
        return -1;
    }
    if (Xil_In32(base + R_ID) != 0x000C0002u ||
        c.cruise_ticks < Xil_In32(base + R_MIN_PERIOD)) {
        xil_printf("ERR wrong IP or too-fast ramp\r\n");
        return -1;
    }
    status = Xil_In32(base + R_STATUS);
    if (status & 1u) {
        xil_printf("ERR busy\r\n");
        return -1;
    }
    Xil_Out32(base + R_STEPS, c.steps);
    Xil_Out32(base + R_START, c.start_ticks);
    Xil_Out32(base + R_CRUISE, c.cruise_ticks);
    Xil_Out32(base + R_DELTA, c.delta_ticks);
    Xil_Out32(base + R_RAMP_STEPS, c.ramp_steps);
    Xil_Out32(base + R_CONTROL, c.control);
    Xil_Out32(base + R_COMMAND, 1u); // START: Vitis register write, not a completion
    xil_printf("RAMP issued. Poll STATUS, ACTIVE_PERIOD, DONE.\r\n");
    return 0;
}

void p2_12_4_stop_ramp_example(void)
{
    const UINTPTR base = (UINTPTR)P2_12_RAMP_BASEADDR;
    Xil_Out32(base + R_COMMAND, 2u); // STOP
}
