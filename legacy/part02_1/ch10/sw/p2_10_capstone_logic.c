#include "p2_10_capstone_logic.h"
#include <string.h>

/* (추가) 대소문자와 공백까지 정확하게 일치하는 ASCII 명령. */
P2_10_Command p2_10_parse(const char *s)
{
    if (s == 0) return P2_10_CMD_INVALID;
    if (strcmp(s,"RUN START") == 0) return P2_10_CMD_START;
    if (strcmp(s,"RUN STOP") == 0) return P2_10_CMD_STOP;
    if (strcmp(s,"RUN RESET") == 0) return P2_10_CMD_RESET;
    if (strcmp(s,"RUN STATUS") == 0) return P2_10_CMD_STATUS;
    if (strncmp(s,"RUN",3U) == 0) return P2_10_CMD_INVALID;
    return P2_10_CMD_NONE;
}
const char *p2_10_state_name(P2_10_RunState state)
{
    return state==P2_10_RUNNING ? "RUNNING" :
           (state==P2_10_FAULT ? "FAULT" : "IDLE");
}
void p2_10_init(P2_10_State *s)
{
    if (!s) return;
    s->state=P2_10_IDLE; s->fault_latch=0U; s->stop_count=0U;
}
/* (추가) 안전 판단은 실제 상태비트에 근거. XADC 저장 샘플은 안전 인터록에 사용하지 않음. */
uint32_t p2_10_faults(const P2_10_Guard *g)
{
    uint32_t f=0U;
    if (!g) return P2_10_FAULT_MODE|P2_10_FAULT_SONIC|
                   P2_10_FAULT_FRESH|P2_10_FAULT_CDS;
    if (!g->mode_auto) f|=P2_10_FAULT_MODE;
    if (!g->sonic_auto || !(g->sonic_status&(1U<<6)) ||
        !(g->sonic_status&(1U<<1)) ||
        (g->sonic_status&((1U<<2)|(1U<<3)|(1U<<5))))
        f|=P2_10_FAULT_SONIC;
    if (!(g->motor_status&(1U<<5)) ||
        !(g->motor_status&(1U<<6)) ||
        !(g->motor_status&(1U<<7))) f|=P2_10_FAULT_FRESH;
    if (g->motor_status&(1U<<3)) f|=P2_10_FAULT_TRIP;
    if (!(g->cds_status&(1U<<2))) f|=P2_10_FAULT_CDS;
    if (g->warn_cm < 20U || g->warn_cm > 400U) f|=P2_10_FAULT_WARN;
    return f;
}
int p2_10_start(P2_10_State *s, const P2_10_Guard *g)
{
    if (!s || s->state!=P2_10_IDLE || s->fault_latch!=0U ||
        p2_10_faults(g)!=0U) return 0;
    s->state=P2_10_RUNNING;
    return 1;
}
void p2_10_stop(P2_10_State *s)
{
    if (!s) return;
    /* (변경) FAULT는 RUN STOP 한 번으로 해제되지 않는다. */
    if (s->state==P2_10_RUNNING) s->state=P2_10_IDLE;
    s->stop_count++;
}
void p2_10_reset(P2_10_State *s)
{
    if (!s || s->state==P2_10_RUNNING) return;
    s->state=P2_10_IDLE; s->fault_latch=0U;
}
int p2_10_tick(P2_10_State *s,const P2_10_Guard *g,uint32_t motor_cmd)
{
    uint32_t f;
    if (!s || s->state!=P2_10_RUNNING) return 0;
    f=p2_10_faults(g);
    if (motor_cmd!=1U) f|=P2_10_FAULT_CMD;
    if (f==0U) return 0;
    s->fault_latch|=f;
    s->state=P2_10_FAULT;
    s->stop_count++;
    return 1;
}
int p2_10_button_stop(P2_10_State *s)
{
    if (!s || s->state!=P2_10_RUNNING) return 0;
    s->fault_latch|=P2_10_FAULT_BUTTON;
    s->state=P2_10_FAULT;
    s->stop_count++;
    return 1;
}
