#include <assert.h>
#include <stdio.h>
#include "../sw/servo_command.h"
int main(void)
{
    servo_command_t c;
    assert(servo_parse_command("SERVO 0", &c) == 1);
    assert(c.kind == SERVO_CMD_ANGLE && c.angle_deg == 0);
    assert(servo_parse_command("SERVO 90", &c) == 1);
    assert(c.angle_deg == 90);
    assert(servo_parse_command("SERVO 180", &c) == 1);
    assert(c.angle_deg == 180);
    assert(servo_parse_command("SERVO OFF", &c) == 1);
    assert(c.kind == SERVO_CMD_OFF);
    assert(servo_parse_command("STATUS", &c) == 0);
    assert(servo_parse_command("SERVO 181", &c) == -1);
    assert(servo_parse_command("SERVO -1", &c) == -1);
    assert(servo_parse_command("SERVO ", &c) == -1);
    assert(servo_parse_command("SERVO 90\n", &c) == -1);
    assert(servo_parse_command("SERVO 99999999999999", &c) == -1);
    puts("P2_11_HOST_SERVO_COMMAND PASS");
    return 0;
}
