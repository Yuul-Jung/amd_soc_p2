#include "p2_09_mode_logic.h"
#include <string.h>
/* 문자열 전체 일치, 대소문자/공백을 임의 정규화하지 않는다. */
P2_09_Command p2_09_parse_command(const char *line)
{
    if (line == 0) return P2_09_MODE_INVALID;
    if (strcmp(line, "MODE AUTO") == 0) return P2_09_MODE_AUTO;
    if (strcmp(line, "MODE MANUAL") == 0) return P2_09_MODE_MANUAL;
    if (strcmp(line, "MODE STATUS") == 0) return P2_09_MODE_STATUS;
    if (strcmp(line, "IRQ STATUS") == 0) return P2_09_IRQ_STATUS;
    if (strncmp(line, "MODE", 4U) == 0) return P2_09_MODE_INVALID;
    if (strncmp(line, "IRQ", 3U) == 0) return P2_09_IRQ_INVALID;
    return P2_09_NOT_COMMAND;
}
const char *p2_09_mode_name(P2_09_Mode mode)
{
    return mode == P2_09_AUTO ? "AUTO" : "MANUAL";
}
int p2_09_allowed_in_auto(const char *line)
{
    if (line == 0) return 0;
    /* (필수) AUTO 모드 중 안전 감시/조도 게이트를 해제하지 않는다. */
    if (strcmp(line, "AUTO OFF") == 0) return 0;
    if (strcmp(line, "SONIC OFF") == 0) return 0;
    /* (필수) AUTO 모드는 모터 자체를 기동하지 않는다. */
    if (strcmp(line, "MOTOR FWD") == 0) return 0;
    if (strcmp(line, "MOTOR REV") == 0) return 0;
    return 1;
}
