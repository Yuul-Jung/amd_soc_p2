#include "p2_10_capstone_logic.h"
#include <stdio.h>
#include <string.h>
static unsigned n;
#define CK(x) do {++n; if(!(x)){fprintf(stderr,"FAIL %s:%d %s\n",__FILE__,__LINE__,#x);return 1;}}while(0)
int main(void)
{
    P2_10_State s;
    P2_10_Guard g={1U,1U,(1U<<1)|(1U<<6),(1U<<5)|(1U<<6)|(1U<<7),(1U<<2),20U};
    unsigned i;
    p2_10_init(&s);
    CK(s.state==P2_10_IDLE && s.fault_latch==0U && s.stop_count==0U);
    CK(p2_10_parse("RUN START")==P2_10_CMD_START);
    CK(p2_10_parse("RUN STOP")==P2_10_CMD_STOP);
    CK(p2_10_parse("RUN RESET")==P2_10_CMD_RESET);
    CK(p2_10_parse("RUN STATUS")==P2_10_CMD_STATUS);
    CK(p2_10_parse("RUN START ")==P2_10_CMD_INVALID);
    CK(p2_10_parse("run start")==P2_10_CMD_NONE);
    CK(p2_10_parse("RUNNING")==P2_10_CMD_INVALID);
    CK(p2_10_parse(NULL)==P2_10_CMD_INVALID);
    CK(p2_10_parse("MOTOR STOP")==P2_10_CMD_NONE);
    CK(p2_10_faults(&g)==0U);
    CK(p2_10_start(&s,&g));
    CK(s.state==P2_10_RUNNING);
    CK(!p2_10_start(&s,&g));
    CK(!p2_10_tick(&s,&g,1U));
    CK(!p2_10_button_stop(NULL));
    CK(p2_10_tick(&s,&g,0U));
    CK(s.state==P2_10_FAULT && (s.fault_latch&P2_10_FAULT_CMD));
    CK(!p2_10_start(&s,&g));
    p2_10_stop(&s);CK(s.state==P2_10_FAULT);
    p2_10_reset(&s);CK(s.state==P2_10_IDLE && s.fault_latch==0U);
    CK(p2_10_start(&s,&g));
    CK(p2_10_button_stop(&s));
    CK(s.state==P2_10_FAULT && (s.fault_latch&P2_10_FAULT_BUTTON));
    p2_10_reset(&s);CK(s.state==P2_10_IDLE);
    /* 각 독립 센서/정책 위험 비트가 모터 구동을 차단해야 한다. */
    for(i=0;i<8U;i++){
        P2_10_Guard bad=g;
        switch(i){
        case 0:bad.mode_auto=0U;break;
        case 1:bad.sonic_auto=0U;break;
        case 2:bad.sonic_status&=~(1U<<1);break;
        case 3:bad.sonic_status|=(1U<<5);break;
        case 4:bad.motor_status&=~(1U<<6);break;
        case 5:bad.motor_status|=(1U<<3);break;
        case 6:bad.cds_status=0U;break;
        case 7:bad.warn_cm=1U;break;
        }
        CK(p2_10_faults(&bad)!=0U);
        CK(!p2_10_start(&s,&bad));
        CK(p2_10_start(&s,&g));
        CK(p2_10_tick(&s,&bad,1U));
        CK(s.state==P2_10_FAULT);
        p2_10_stop(&s);
        CK(s.state==P2_10_FAULT);
        p2_10_reset(&s);
    }
    CK(p2_10_faults(NULL)!=0U);
    CK(strcmp(p2_10_state_name(P2_10_RUNNING),"RUNNING")==0);
    CK(strcmp(p2_10_state_name(P2_10_FAULT),"FAULT")==0);
    printf("P2_10_POLICY_HOST_PASS ASSERTIONS=%u\n",n);
    return 0;
}
