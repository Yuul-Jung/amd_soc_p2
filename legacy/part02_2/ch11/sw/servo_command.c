#include "servo_command.h"
#include <string.h>
// 기존 P2-10 UART Parser는 유지한다. SERVO 명령 전용 독립 Parser.
// 엄격한 명령 규격: "SERVO 0"~"SERVO 180", "SERVO OFF".
// 뒤쪽 CR/LF는 기존 Line Receiver에서 제거해야 한다.
int servo_parse_command(const char *line, servo_command_t *cmd)
{
    int deg = 0;
    const char *p;
    if (!line || !cmd) return -1;
    if (strncmp(line, "SERVO", 5) != 0 ||
        (line[5] != '\0' && line[5] != ' '))
        return 0;
    if (strcmp(line, "SERVO OFF") == 0) {
        cmd->kind = SERVO_CMD_OFF;
        cmd->angle_deg = 0;
        return 1;
    }
    if (strncmp(line, "SERVO ", 6) != 0) return -1;
    p = line + 6;
    if (*p == '\0') return -1;
    while (*p != '\0') {
        if (*p < '0' || *p > '9') return -1;
        deg = deg * 10 + (*p - '0');
        if (deg > 180) return -1; // 큰 정수 입력도 안전하게 중단
        ++p;
    }
    cmd->kind = SERVO_CMD_ANGLE;
    cmd->angle_deg = deg;
    return 1;
}
