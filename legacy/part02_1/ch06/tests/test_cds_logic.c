#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "p2_05_cds_logic.h"
#include "p2_04_pwm_logic.h"
#include "p2_03_logic.h"
static unsigned assertions;
#define CHECK(v) do { ++assertions; if(!(v)) { \
  fprintf(stderr,"FAIL at line %d: %s\n",__LINE__,#v); return 1; } } while(0)

int main(void)
{
    uint8_t p=255;
    uint16_t n=0;
    // Exact ASCII command contract, do not silently accept other spellings.
    CHECK(cds_parse_command("AUTO ON")==CDS_AUTO_ON);
    CHECK(cds_parse_command("AUTO OFF")==CDS_AUTO_OFF);
    CHECK(cds_parse_command("CDS READ")==CDS_READ);
    CHECK(cds_parse_command("CDS POL LOW")==CDS_POL_LOW);
    CHECK(cds_parse_command("CDS POL HIGH")==CDS_POL_HIGH);
    CHECK(cds_parse_command("AUTO") == CDS_INVALID);
    CHECK(cds_parse_command("AUTO ON ") == CDS_INVALID);
    CHECK(cds_parse_command("AUTO ONX") == CDS_INVALID);
    CHECK(cds_parse_command("auto on") == CDS_NOT_COMMAND);
    CHECK(cds_parse_command("CDS READ NOW") == CDS_INVALID);
    CHECK(cds_parse_command("CDS POL") == CDS_INVALID);
    CHECK(cds_parse_command("CDS POL FLIP") == CDS_INVALID);
    CHECK(cds_parse_command("LED ON") == CDS_NOT_COMMAND);
    CHECK(cds_parse_command("PWM 50") == CDS_NOT_COMMAND);
    CHECK(cds_parse_command("STATUS") == CDS_NOT_COMMAND);
    CHECK(cds_control_word(0,0)==0U);
    CHECK(cds_control_word(0,1)==2U);
    CHECK(cds_control_word(1,0)==1U);
    CHECK(cds_control_word(1,1)==3U);
    // Complete truth table of PWM, AUTO, VALID and DARK.
    for (unsigned pwm=0;pwm<=1;++pwm)
      for (unsigned auto_on=0;auto_on<=1;++auto_on)
        for (unsigned valid=0;valid<=1;++valid)
          for (unsigned dark=0;dark<=1;++dark) {
            unsigned exp = pwm && (!auto_on || (valid && dark));
            CHECK(cds_light_on(pwm,auto_on,valid,dark)==exp);
          }
    // Regression: 04 PWM settings, 01/02/03 command recognition.
    CHECK(pwm_parse_command("PWM 0",&p)==PWM_VALID && p==0);
    CHECK(pwm_parse_command("PWM 50",&p)==PWM_VALID && p==50);
    CHECK(pwm_parse_command("PWM 100",&p)==PWM_VALID && p==100);
    CHECK(pwm_parse_command("PWM 101",&p)==PWM_INVALID);
    CHECK(pwm_duty_for_percent(100000U,50)==50000U);
    CHECK(p2_parse_command("LED ON",&n)==P2_CMD_LED_ON);
    CHECK(p2_parse_command("LED OFF",&n)==P2_CMD_LED_OFF);
    CHECK(p2_parse_command("DISP 0050",&n)==P2_CMD_DISP_VALUE && n==50);
    CHECK(p2_parse_command("DISP OFF",&n)==P2_CMD_DISP_OFF);
    CHECK(p2_parse_command("STATUS",&n)==P2_CMD_STATUS);
    printf("HOST_CDS_AND_P2_01_04_REGRESSION PASS (%u assertions)\n", assertions);
    return 0;
}
