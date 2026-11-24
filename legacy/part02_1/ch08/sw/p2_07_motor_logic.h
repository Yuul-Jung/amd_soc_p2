#ifndef P2_07_MOTOR_LOGIC_H
#define P2_07_MOTOR_LOGIC_H
#include <stdint.h>
/* Exact ASCII UART line grammar; not a single-character protocol. */
typedef enum {
    MOTOR_NOT_COMMAND=0, MOTOR_FWD, MOTOR_REV, MOTOR_STOP,
    MOTOR_STATUS, MOTOR_INVALID
} MotorCommand;
MotorCommand motor_parse_command(const char *line);
const char *motor_direction_name(uint32_t dir);
#endif
