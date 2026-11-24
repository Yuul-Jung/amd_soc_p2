// P2-12.3: 독립 Vitis 보드 스모크 테스트.
// 이 파일은 기존 P2-10 main.c와 함께 컴파일/링크하지 않는다.
// 아래 세 매크로는 실제 XSA/BSP/Block Design을 확인해 사용자가 지정한다.
#include <stdint.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xuartlite_l.h"
#include "../sw/stepper_logic.h"
#include "../sw/stepper_axi.h"

#ifndef P2_12_STEPPER_BASEADDR
#error "Define P2_12_STEPPER_BASEADDR from the actual Address Editor/XSA BSP"
#endif
#ifndef P2_12_UART_BASEADDR
#error "Define P2_12_UART_BASEADDR from the actual BSP"
#endif
#ifndef P2_12_AXI_CLOCK_HZ
#error "Define P2_12_AXI_CLOCK_HZ from actual Block Design Clock"
#endif

#define STP_STATUS 0x10u
#define STP_DONE   0x14u
#define STP_ID     0x18u
#define STP_MIN    0x1Cu

static int perform_step(uint32_t steps, uint32_t interval_ms,
                        int reverse, int half_step)
{
    stepper_cfg_t config;
    uint32_t base = (uint32_t)P2_12_STEPPER_BASEADDR;
    uint32_t min_ticks = Xil_In32(base + STP_MIN);
    uint32_t status = Xil_In32(base + STP_STATUS);
    if (status & 1u) { xil_printf("ERR busy\r\n"); return -1; }
    if (stepper_make_config(P2_12_AXI_CLOCK_HZ, steps, interval_ms,
                            reverse, half_step, &config) != 0 ||
        config.period_ticks < min_ticks) {
        xil_printf("ERR invalid config\r\n"); return -1;
    }
    // AXI Xil_Out32는 BRESP 오류를 직접 돌려주지 않는다.
    // 명령 전 STATUS/하드웨어 최소 주기 확인은 필수다.
    if (stepper_axi_start(base, &config) != 0) {
        xil_printf("ERR start\r\n"); return -1;
    }
    xil_printf("START steps=%lu ms=%lu direction=%s mode=%s\r\n",
               (unsigned long)steps, (unsigned long)interval_ms,
               reverse ? "REV" : "FWD", half_step ? "HALF" : "FULL");
    return 0;
}

int main(void)
{
    const uint32_t base = (uint32_t)P2_12_STEPPER_BASEADDR;
    uint8_t cmd;
    if (Xil_In32(base + STP_ID) != 0x000C0001u) {
        xil_printf("ERR IP ID does not match P2-12\r\n");
        return 1;
    }
    stepper_axi_stop(base);
    xil_printf("\r\nP2-12 28BYJ-48 BOARD TEST\r\n");
    xil_printf("1 HALF FWD 8 steps, 2 HALF REV 8 steps\r\n");
    xil_printf("3 FULL FWD 8 steps, 4 FULL REV 8 steps\r\n");
    xil_printf("5 HALF FWD 128 steps, 6 HALF REV 128 steps\r\n");
    xil_printf("s STOP, p STATUS, q STOP/quit\r\n");
    while (1) {
        cmd = XUartLite_RecvByte(P2_12_UART_BASEADDR);
        switch (cmd) {
        case '1': perform_step(8u, 10u, 0, 1); break;
        case '2': perform_step(8u, 10u, 1, 1); break;
        case '3': perform_step(8u, 10u, 0, 0); break;
        case '4': perform_step(8u, 10u, 1, 0); break;
        case '5': perform_step(128u, 5u, 0, 1); break;
        case '6': perform_step(128u, 5u, 1, 1); break;
        case 's': stepper_axi_stop(base); xil_printf("STOP\r\n"); break;
        case 'p':
            xil_printf("STATUS=0x%08lx STEPS=%lu\r\n",
                       (unsigned long)Xil_In32(base + STP_STATUS),
                       (unsigned long)Xil_In32(base + STP_DONE));
            break;
        case 'q':
            stepper_axi_stop(base);
            xil_printf("QUIT\r\n");
            return 0;
        default:
            // 개행 문자 등은 무시한다.
            break;
        }
    }
}
