#include <assert.h>
#include <stdio.h>
#include "../sw/stepper_logic.h"
int main(void)
{
    stepper_cfg_t c;
    assert(stepper_make_config(100000000u,128,5,0,1,&c)==0);
    assert(c.steps==128 && c.period_ticks==500000 && c.control==2);
    assert(stepper_make_config(100000000u,2048,2,1,0,&c)==0);
    assert(c.period_ticks==200000 && c.control==1);
    assert(stepper_make_config(50000000u,100,10,1,1,&c)==0);
    assert(c.period_ticks==500000 && c.control==3);
    assert(stepper_make_config(100000000u,0,2,0,1,&c)==-1);
    assert(stepper_make_config(100000000u,1,1,0,1,&c)==-1);
    assert(stepper_make_config(100000000u,1,101,0,1,&c)==-1);
    assert(stepper_make_config(0,1,5,0,1,&c)==-1);
    assert(stepper_make_config(100000000u,1,5,3,1,&c)==-1);
    assert(stepper_make_config(100000000u,1,5,0,-1,&c)==-1);
    assert(stepper_make_config(100000000u,1,5,0,1,0)==-1);
    puts("P2_12_HOST_STEPPER_LOGIC PASS");
    return 0;
}
