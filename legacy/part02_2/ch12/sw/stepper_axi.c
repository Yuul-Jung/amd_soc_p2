#include "stepper_axi.h"
#include "xil_io.h"
#define REG_STEPS   0x00u
#define REG_PERIOD  0x04u
#define REG_CONTROL 0x08u
#define REG_COMMAND 0x0Cu
#define REG_STATUS  0x10u
#define REG_DONE    0x14u
int stepper_axi_start(uintptr_t baseaddr, const stepper_cfg_t *cfg)
{
    if (!cfg || cfg->steps == 0u || cfg->period_ticks < 2u ||
        (cfg->control & ~3u) != 0u) return -1;
    // (주의) 실제 최소 주기(MIN_STEP_TICKS)를 함께 검증해야 한다.
    // Xil_Out32는 AXI BRESP/하드웨어 완료를 자동 반환하지 않음.
    Xil_Out32(baseaddr + REG_STEPS, cfg->steps);
    Xil_Out32(baseaddr + REG_PERIOD, cfg->period_ticks);
    Xil_Out32(baseaddr + REG_CONTROL, cfg->control);
    Xil_Out32(baseaddr + REG_COMMAND, 1u);
    return 0;
}
void stepper_axi_stop(uintptr_t baseaddr)
{
    Xil_Out32(baseaddr + REG_COMMAND, 2u);
}
uint32_t stepper_axi_status(uintptr_t baseaddr)
{
    return Xil_In32(baseaddr + REG_STATUS);
}
uint32_t stepper_axi_steps_done(uintptr_t baseaddr)
{
    return Xil_In32(baseaddr + REG_DONE);
}
