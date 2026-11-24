#ifndef P2_11_SERVO_COMMAND_H
#define P2_11_SERVO_COMMAND_H
typedef enum { SERVO_CMD_ANGLE, SERVO_CMD_OFF } servo_cmd_kind_t;
typedef struct {
    servo_cmd_kind_t kind;
    int angle_deg;
} servo_command_t;
// 1=서보 명령 파싱 성공, 0=서보 명령 아님, -1=잘못된 서보 명령.
// UART 수신 라인의 '\0' 종료 문자열을 입력으로 받는다.
int servo_parse_command(const char *line, servo_command_t *cmd);
#endif
