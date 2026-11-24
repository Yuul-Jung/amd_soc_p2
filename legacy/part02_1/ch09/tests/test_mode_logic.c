#include "p2_09_mode_logic.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static unsigned checks;
#define CK(cond) do{checks++; if(!(cond)){fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#cond);return 1;}}while(0)
int main(void){
    struct {const char *in; P2_09_Command want;} cases[]={
        {"MODE AUTO",P2_09_MODE_AUTO},{"MODE MANUAL",P2_09_MODE_MANUAL},
        {"MODE STATUS",P2_09_MODE_STATUS},{"IRQ STATUS",P2_09_IRQ_STATUS},
        {"MODE",P2_09_MODE_INVALID},{"MODE ",P2_09_MODE_INVALID},
        {"MODE AUT",P2_09_MODE_INVALID},{"MODE AUTO ",P2_09_MODE_INVALID},
        {"MODE  AUTO",P2_09_MODE_INVALID},{"mode auto",P2_09_NOT_COMMAND},
        {"MODE AUTO\n",P2_09_MODE_INVALID},{"MODE AUTO 123",P2_09_MODE_INVALID},
        {"MODE MANUAL ",P2_09_MODE_INVALID},{"MODE STATUS!",P2_09_MODE_INVALID},
        {"MODEX",P2_09_MODE_INVALID},{"IRQ",P2_09_IRQ_INVALID},
        {"IRQ ",P2_09_IRQ_INVALID},{"IRQ CLEAR",P2_09_IRQ_INVALID},
        {"IRQ STATUS ",P2_09_IRQ_INVALID},{"IRQS",P2_09_IRQ_INVALID},
        {"LED ON",P2_09_NOT_COMMAND},{"LED OFF",P2_09_NOT_COMMAND},
        {"DISP 0050",P2_09_NOT_COMMAND},{"DISP OFF",P2_09_NOT_COMMAND},
        {"PWM 50",P2_09_NOT_COMMAND},{"PWM 100",P2_09_NOT_COMMAND},
        {"ADC READ",P2_09_NOT_COMMAND},{"ADC PWM",P2_09_NOT_COMMAND},
        {"AUTO ON",P2_09_NOT_COMMAND},{"AUTO OFF",P2_09_NOT_COMMAND},
        {"SONIC ON",P2_09_NOT_COMMAND},{"SONIC OFF",P2_09_NOT_COMMAND},
        {"SONIC READ",P2_09_NOT_COMMAND},{"WARN 20",P2_09_NOT_COMMAND},
        {"WARN OFF",P2_09_NOT_COMMAND},{"MOTOR FWD",P2_09_NOT_COMMAND},
        {"MOTOR REV",P2_09_NOT_COMMAND},{"MOTOR STOP",P2_09_NOT_COMMAND},
        {"MOTOR STATUS",P2_09_NOT_COMMAND},{"STATUS",P2_09_NOT_COMMAND},
        {"CDS READ",P2_09_NOT_COMMAND},
    };
    unsigned i;
    for(i=0;i<sizeof(cases)/sizeof(cases[0]);i++)CK(p2_09_parse_command(cases[i].in)==cases[i].want);
    CK(p2_09_parse_command(NULL)==P2_09_MODE_INVALID);
    CK(strcmp(p2_09_mode_name(P2_09_MANUAL),"MANUAL")==0);
    CK(strcmp(p2_09_mode_name(P2_09_AUTO),"AUTO")==0);
    const char *forbidden[]={"AUTO OFF","SONIC OFF","MOTOR FWD","MOTOR REV"};
    const char *allowed[]={"MOTOR STOP","MOTOR STATUS","SONIC ON","SONIC READ","WARN OFF","STATUS","MODE MANUAL","IRQ STATUS","ADC READ","PWM 50","AUTO ON","DISP 0050","LED ON"};
    for(i=0;i<sizeof(forbidden)/sizeof(forbidden[0]);i++)CK(p2_09_allowed_in_auto(forbidden[i])==0);
    for(i=0;i<sizeof(allowed)/sizeof(allowed[0]);i++)CK(p2_09_allowed_in_auto(allowed[i])==1);
    CK(p2_09_allowed_in_auto(NULL)==0);
    puts("P2_09_MODE_PARSER_AND_POLICY_PASS");
    printf("ASSERTIONS=%u\n",checks);
    return 0;
}
