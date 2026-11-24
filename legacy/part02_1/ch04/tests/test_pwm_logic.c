#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include "p2_04_pwm_logic.h"
#include "p2_03_logic.h"
static unsigned checks = 0;
#define CHECK(x) do { assert(x); ++checks; } while (0)
int main(void)
{
    uint8_t pct = 222U;
    uint16_t val = 0U;
    P2AppState s;
    P2Command cmd;
    const char *ok[] = {"PWM 0", "PWM 1", "PWM 9", "PWM 25", "PWM 50", "PWM 99", "PWM 100"};
    const uint8_t want[] = {0,1,9,25,50,99,100};
    const char *bad[] = {"PWM", "PWM ", "PWM 00", "PWM 050", "PWM 101", "PWM -1",
                         "PWM +1", "PWM 1.0", "PWM 50 ", "PWM 10x", "PWM 99999999999999999",
                         "PWM 0x32", "PWM  50", "PWM 1000", "PWM\t50"};
    const char *legacy[] = {"LED ON", "LED OFF", "DISP 0050", "DISP OFF", "STATUS"};
    unsigned i;
    for (i=0;i<sizeof(ok)/sizeof(ok[0]);++i) {
        CHECK(pwm_parse_command(ok[i],&pct)==PWM_VALID);
        CHECK(pct==want[i]);
    }
    for (i=0;i<sizeof(bad)/sizeof(bad[0]);++i)
        CHECK(pwm_parse_command(bad[i],&pct)==PWM_INVALID);
    for (i=0;i<sizeof(legacy)/sizeof(legacy[0]);++i)
        CHECK(pwm_parse_command(legacy[i],&pct)==PWM_NOT_COMMAND);
    CHECK(pwm_duty_for_percent(100000,0)==0);
    CHECK(pwm_duty_for_percent(100000,1)==1000);
    CHECK(pwm_duty_for_percent(100000,50)==50000);
    CHECK(pwm_duty_for_percent(100000,100)==100000);
    CHECK(pwm_duty_for_percent(4294967200U,100)==4294967200U);
    CHECK(pwm_duty_for_percent(100000,255)==100000);
    p2_init(&s);
    cmd = p2_parse_command("DISP 0050", &val);
    CHECK(cmd == P2_CMD_DISP_VALUE);
    p2_set_disp(&s,val);
    CHECK(p2_to_bcd4(p2_visible_decimal(&s))==0x0050U);
    p2_apply_button(&s,0);
    CHECK(s.value==51U);
    CHECK(p2_parse_command("LED ON",&val)==P2_CMD_LED_ON);
    CHECK(p2_parse_command("STATUS",&val)==P2_CMD_STATUS);
    printf("P2_04_HOST_LOGIC PASS (%u assertions)\n", checks);
    return 0;
}
