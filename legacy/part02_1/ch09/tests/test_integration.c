/* Include application source in this mock test TU to exercise static functions.
 * This is NOT a target-BSP or AXI protocol test. */
#define P2_09_TEST_IO
#define main target_entry_not_called
#include "../sw/main_p2_09.c"
#undef main
#include <assert.h>
#include <stdio.h>

static UINTPTR last_write_addr;
static u32 last_write_value;
static unsigned writes_to_motor;
static unsigned writes_to_cds;
static unsigned writes_to_sonic;
static unsigned assertions;
#define CK(c) do{assertions++; if(!(c)){fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#c);return 1;}}while(0)

u32 Xil_In32(UINTPTR a)
{
    if (a == P2_06_SONIC_BASEADDR + SONIC_SEQ) return 7U;
    if (a == P2_07_MOTOR_BASEADDR + MOTOR_STATUS_REG) return (1U<<5); /* safe */
    return 0U;
}
void Xil_Out32(UINTPTR a,u32 v)
{
    last_write_addr=a;last_write_value=v;
    if(a==P2_07_MOTOR_BASEADDR+MOTOR_CMD_REG) writes_to_motor++;
    if(a==P2_05_CDS_BASEADDR+CDS_CTRL) writes_to_cds++;
    if(a==P2_06_SONIC_BASEADDR+SONIC_CTRL) writes_to_sonic++;
}
int main(void)
{
    unsigned n;
    p2_init(&app);
    CK(control_mode==P2_09_MANUAL);
    CK(cds_auto_enabled==0U);
    handle_line("MODE AUTO");
    CK(control_mode==P2_09_AUTO);
    CK(cds_auto_enabled==1U);
    CK(sonic_auto_enabled==1U);
    CK(sonic_view==1U);
    CK(sonic_view_fresh==0U);
    CK(writes_to_motor==1U);
    CK(last_write_addr==P2_02_FND_BASEADDR+FND_CTRL_REG);
    CK(writes_to_cds==1U);
    CK(writes_to_sonic==1U);
    n=writes_to_motor;
    handle_line("MOTOR FWD");
    CK(writes_to_motor==n); /* software mode denies drive */
    handle_line("MOTOR REV");
    CK(writes_to_motor==n);
    handle_line("AUTO OFF");
    CK(cds_auto_enabled==1U);
    CK(writes_to_cds==1U);
    handle_line("SONIC OFF");
    CK(sonic_auto_enabled==1U);
    CK(writes_to_sonic==1U);
    handle_line("MODE AUTO");
    CK(writes_to_motor==n); /* idempotent */
    handle_line("MOTOR STOP");
    CK(writes_to_motor==n+1U); /* STOP always permitted */
    handle_line("MODE MANUAL");
    CK(control_mode==P2_09_MANUAL);
    CK(cds_auto_enabled==0U);
    CK(sonic_auto_enabled==1U); /* don't disable sonar safety monitoring */
    CK(sonic_view==0U);
    handle_line("MOTOR FWD");
    CK(writes_to_motor==n+2U); /* safe status mocked */
    handle_line("AUTO ON");
    CK(cds_auto_enabled==1U);
    handle_line("MODE MANUAL");
    CK(cds_auto_enabled==0U); /* idempotent MODE MANUAL still disables CdS */
    timer_irq_count=0U;uart_line_activity=1U;
    timer_callback(0,0U);
    service_legacy_gpio_leds();
    CK(timer_irq_count==1U);
    CK(led_gpio_shadow==(UART_ACTIVITY_LED14|TIMER_HEARTBEAT_LED15));
    timer_callback(0,0U);
    service_legacy_gpio_leds();
    CK(led_gpio_shadow==UART_ACTIVITY_LED14);
    uart_line_activity=0U;
    service_legacy_gpio_leds();
    CK(led_gpio_shadow==0U);
    puts("P2_09_INTEGRATION_MOCK_PASS");
    printf("ASSERTIONS=%u\n",assertions);
    return 0;
}
