#include "p2_07_motor_logic.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>
static int passes=0;
#define CK(c) do { assert(c); passes++; } while (0)
int main(void)
{
    CK(motor_parse_command("MOTOR FWD")==MOTOR_FWD);
    CK(motor_parse_command("MOTOR REV")==MOTOR_REV);
    CK(motor_parse_command("MOTOR STOP")==MOTOR_STOP);
    CK(motor_parse_command("MOTOR STATUS")==MOTOR_STATUS);
    CK(motor_parse_command("MOTOR") == MOTOR_INVALID);
    CK(motor_parse_command("MOTOR ") == MOTOR_INVALID);
    CK(motor_parse_command("MOTOR FWD ") == MOTOR_INVALID);
    CK(motor_parse_command("MOTOR FORWARD") == MOTOR_INVALID);
    CK(motor_parse_command("MOTOR REVERE") == MOTOR_INVALID);
    CK(motor_parse_command("MOTOR  FWD") == MOTOR_INVALID);
    CK(motor_parse_command("motor fwd") == MOTOR_NOT_COMMAND);
    CK(motor_parse_command("MOTOR STOP\n") == MOTOR_INVALID);
    CK(motor_parse_command("MOTOR FWD\r") == MOTOR_INVALID);
    CK(motor_parse_command("LED ON") == MOTOR_NOT_COMMAND);
    CK(motor_parse_command("SONIC ON") == MOTOR_NOT_COMMAND);
    CK(motor_parse_command("WARN 20") == MOTOR_NOT_COMMAND);
    CK(motor_parse_command("PWM 50") == MOTOR_NOT_COMMAND);
    CK(motor_parse_command("") == MOTOR_NOT_COMMAND);
    CK(motor_parse_command(NULL) == MOTOR_INVALID);
    CK(strcmp(motor_direction_name(0),"STOP")==0);
    CK(strcmp(motor_direction_name(1),"FWD")==0);
    CK(strcmp(motor_direction_name(2),"REV")==0);
    CK(strcmp(motor_direction_name(3),"STOP")==0);
    puts("P2_07_MOTOR_PARSER_PASS 23 assertions");
    return 0;
}
