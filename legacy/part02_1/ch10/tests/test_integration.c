#define P2_09_TEST_IO
#define main target_entry_not_called
#include "../sw/main_p2_10.c"
#undef main
#include <stdio.h>
#include <assert.h>
static UINTPTR last_write_addr;
static u32 last_write_value;
static u32 mock_motor_cmd=0U;
static u32 mock_motor_status=(1U<<5)|(1U<<6)|(1U<<7);
static u32 mock_sonic_status=(1U<<1)|(1U<<6);
static u32 mock_cds_status=(1U<<2);
static u32 mock_warn_cm=20U;
static unsigned motor_stop_writes, motor_start_writes, checks;
#define CK(x) do{checks++;if(!(x)){fprintf(stderr,"FAIL test_integration:%d: %s\n",__LINE__,#x);return 1;}}while(0)
u32 Xil_In32(UINTPTR a)
{
    if(a==P2_07_MOTOR_BASEADDR+MOTOR_CMD_REG) return mock_motor_cmd;
    if(a==P2_07_MOTOR_BASEADDR+MOTOR_STATUS_REG) return mock_motor_status;
    if(a==P2_06_SONIC_BASEADDR+SONIC_STATUS) return mock_sonic_status;
    if(a==P2_05_CDS_BASEADDR+CDS_STATUS) return mock_cds_status;
    if(a==P2_06_SONIC_BASEADDR+SONIC_SEQ) return 1U;
    if(a==P2_06_SONIC_BASEADDR+SONIC_WARN_CFG) return mock_warn_cm;
    return 0U;
}
void Xil_Out32(UINTPTR a,u32 v)
{
    last_write_addr=a;last_write_value=v;
    if(a==P2_06_SONIC_BASEADDR+SONIC_WARN_CFG) mock_warn_cm=v;
    if(a==P2_07_MOTOR_BASEADDR+MOTOR_CMD_REG){
        mock_motor_cmd=v;
        if(v==0U) motor_stop_writes++;
        else motor_start_writes++;
    }
}
int main(void)
{
    unsigned n;
    p2_init(&app);p2_10_init(&cap_state);
    CK(cap_state.state==P2_10_IDLE);
    handle_line("RUN START");
    CK(motor_start_writes==0U); /* MODE MANUAL 차단 */
    handle_line("MODE AUTO");
    CK(control_mode==P2_09_AUTO && sonic_auto_enabled && cds_auto_enabled);
    n=motor_stop_writes;
    handle_line("WARN 1");CK(mock_warn_cm==1U);
    handle_line("RUN START");CK(motor_start_writes==0U); /* 하한 위반 */
    handle_line("WARN 20");CK(mock_warn_cm==20U);
    handle_line("RUN START");
    CK(motor_start_writes==1U && mock_motor_cmd==1U);
    CK(cap_state.state==P2_10_RUNNING);
    CK(!p2_10_tick(&cap_state,&(P2_10_Guard){1,1, (1U<<1)|(1U<<6),
        (1U<<5)|(1U<<6)|(1U<<7),(1U<<2),20U},1U));
    handle_line("MOTOR REV");CK(motor_start_writes==1U); /* AUTO block */
    handle_line("CDS POL HIGH");CK(cds_dark_when_low==1U); /* RUN block */
    handle_line("WARN OFF");CK(sonic_warn_enabled==1U);
    handle_line("WARN 1");CK(mock_warn_cm==20U);
    handle_line("RUN STATUS");CK(cap_state.state==P2_10_RUNNING);
    mock_sonic_status|=(1U<<5); /* near obstacle */
    service_capstone();
    CK(cap_state.state==P2_10_FAULT);
    CK((cap_state.fault_latch&P2_10_FAULT_SONIC)!=0U);
    CK(mock_motor_cmd==0U && motor_stop_writes==n+1U);
    handle_line("RUN START");CK(motor_start_writes==1U);
    handle_line("RUN STOP");CK(cap_state.state==P2_10_FAULT);
    mock_sonic_status&=~(1U<<5);
    mock_motor_status|=1U; /* 일부러 하드웨어 ENA가 아직 켜진 상태 */
    handle_line("RUN RESET");CK(cap_state.state==P2_10_FAULT);
    mock_motor_status&=~1U;
    handle_line("RUN RESET");CK(cap_state.state==P2_10_IDLE);
    handle_line("RUN START");CK(motor_start_writes==2U);
    irq_counts[7]++;service_button_events();
    CK(cap_state.state==P2_10_FAULT);
    CK((cap_state.fault_latch&P2_10_FAULT_BUTTON)!=0U);
    CK(mock_motor_cmd==0U);
    handle_line("MODE MANUAL");CK(control_mode==P2_09_MANUAL);
    handle_line("RUN RESET");CK(cap_state.state==P2_10_IDLE);
    handle_line("RUN START");CK(motor_start_writes==2U); /* MANUAL */
    handle_line("MODE AUTO");
    handle_line("RUN START");CK(motor_start_writes==3U);
    handle_line("MODE MANUAL");CK(mock_motor_cmd==0U);
    CK(control_mode==P2_09_MANUAL && cap_state.state==P2_10_IDLE);
    printf("P2_10_INTEGRATION_MOCK_PASS ASSERTIONS=%u\n",checks);
    return 0;
}
