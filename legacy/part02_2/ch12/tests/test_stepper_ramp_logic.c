#include <assert.h>
#include <stdio.h>
#include "../sw/stepper_ramp_logic.h"
int main(void)
{
    stepper_ramp_cfg_t c;
    assert(stepper_ramp_make_config(100000000u,16,10,4,3,0,1,&c)==0);
    assert(c.steps==16 && c.start_ticks==1000000 &&
           c.cruise_ticks==400000 && c.delta_ticks==200000 &&
           c.ramp_steps==3 && c.control==2);
    assert(stepper_ramp_make_config(50000000u,11,8,4,2,1,0,&c)==0);
    assert(c.start_ticks==400000 && c.cruise_ticks==200000 &&
           c.delta_ticks==100000 && c.control==1);
    assert(stepper_ramp_make_config(100000000u,4,10,4,2,0,1,&c)==-1);
    assert(stepper_ramp_make_config(100000000u,10,4,4,2,0,1,&c)==-1);
    assert(stepper_ramp_make_config(100000000u,10,4,2,0,0,1,&c)==-1);
    assert(stepper_ramp_make_config(100000000u,10,4,2,3,0,1,&c)==-1);
    assert(stepper_ramp_make_config(100000000u,10,6,3,3,0,1,&c)==0);
    assert(stepper_ramp_make_config(100000000u,10,4,2,3,0,1,0)==-1);
    puts("P2_12_4_HOST_RAMP_LOGIC PASS");
    return 0;
}
