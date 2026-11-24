#include "p2_06_sonic_logic.h"
#include "p2_03_logic.h"
#include "p2_04_pwm_logic.h"
#include "p2_05_cds_logic.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
int main(void)
{
    static const char *bad[]={"SONIC", "SONIC START", "SONIC on",
        "SONIC READ X", "WARN", "WARN 0", "WARN 00", "WARN 020",
        "WARN 401", "WARN -1", "WARN 20 ", "WARN 999999", "WARN 2.5"};
    uint16_t cm=0U, val=0U;
    unsigned i, count=0;
    P2AppState state;
    assert(sonic_parse_command("SONIC ON",&cm)==SONIC_ON); ++count;
    assert(sonic_parse_command("SONIC OFF",&cm)==SONIC_OFF); ++count;
    assert(sonic_parse_command("SONIC READ",&cm)==SONIC_READ); ++count;
    assert(sonic_parse_command("SONIC SHOT",&cm)==SONIC_SHOT); ++count;
    assert(sonic_parse_command("WARN OFF",&cm)==SONIC_WARN_OFF); ++count;
    assert(sonic_parse_command("WARN 20",&cm)==SONIC_WARN_CM && cm==20U);++count;
    assert(sonic_parse_command("WARN 1",&cm)==SONIC_WARN_CM && cm==1U);++count;
    assert(sonic_parse_command("WARN 400",&cm)==SONIC_WARN_CM && cm==400U);++count;
    for(i=0;i<sizeof bad/sizeof bad[0];i++) {
        assert(sonic_parse_command(bad[i],&cm)==SONIC_INVALID);++count;
    }
    assert(sonic_parse_command("CDS READ",&cm)==SONIC_NOT_COMMAND);++count;
    assert(sonic_parse_command("PWM 50",&cm)==SONIC_NOT_COMMAND);++count;
    assert(sonic_parse_command("STATUS",&cm)==SONIC_NOT_COMMAND);++count;
    assert(sonic_sample_valid(2U,100U));++count;
    assert(!sonic_sample_valid(0U,100U));++count;
    assert(!sonic_sample_valid(2U,0U));++count;
    assert(!sonic_sample_valid(2U,401U));++count;
    assert(sonic_visible_cm(2U,50U)==50U);++count;
    assert(sonic_visible_cm(4U,50U)==0U);++count;
    p2_init(&state);p2_set_disp(&state,50U);
    assert(p2_to_bcd4(p2_visible_decimal(&state))==0x0050U);++count;
    assert(p2_parse_command("LED ON",&val)==P2_CMD_LED_ON);++count;
    assert(p2_parse_command("DISP 0050",&val)==P2_CMD_DISP_VALUE && val==50U);++count;
    assert(sonic_parse_command("AUTO ON",&cm)==SONIC_NOT_COMMAND);++count;
    assert(sonic_parse_command("CDS POL LOW",&cm)==SONIC_NOT_COMMAND);++count;
    puts("P2_06_HOST_LOGIC PASS");printf("ASSERTIONS=%u\n",count);
    return 0;
}
