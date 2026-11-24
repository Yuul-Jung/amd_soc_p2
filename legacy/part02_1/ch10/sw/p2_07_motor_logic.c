#include "p2_07_motor_logic.h"
#include <string.h>

MotorCommand motor_parse_command(const char *line)
{
    if (line == NULL) return MOTOR_INVALID;
    if (strcmp(line, "MOTOR FWD") == 0) return MOTOR_FWD;
    if (strcmp(line, "MOTOR REV") == 0) return MOTOR_REV;
    if (strcmp(line, "MOTOR STOP") == 0) return MOTOR_STOP;
    if (strcmp(line, "MOTOR STATUS") == 0) return MOTOR_STATUS;
    if (strncmp(line, "MOTOR", 5U) == 0) return MOTOR_INVALID;
    return MOTOR_NOT_COMMAND;
}
const char *motor_direction_name(uint32_t dir)
{
    if (dir == 1U) return "FWD";
    if (dir == 2U) return "REV";
    return "STOP";
}
