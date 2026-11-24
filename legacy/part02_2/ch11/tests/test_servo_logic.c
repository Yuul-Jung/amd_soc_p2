#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include "../sw/servo_logic.h"
static void check(uint32_t hz, int angle, uint32_t period, uint32_t duty)
{
    servo_config_t c = {0, 0};
    assert(servo_angle_to_config(hz, angle, &c) == 0);
    assert(c.period_ticks == period && c.duty_ticks == duty);
}
int main(void)
{
    servo_config_t c;
    check(100000000u, 0,   2000000u, 100000u);
    check(100000000u, 90,  2000000u, 150000u);
    check(100000000u, 180, 2000000u, 200000u);
    check(50000000u,  90,  1000000u,  75000u);
    assert(servo_angle_to_config(100000000u, -1, &c) == -1);
    assert(servo_angle_to_config(100000000u, 181, &c) == -1);
    assert(servo_angle_to_config(0, 90, &c) == -1);
    assert(servo_angle_to_config(100000000u, 90, 0) == -1);
    puts("P2_11_HOST_SERVO_LOGIC PASS");
    return 0;
}
