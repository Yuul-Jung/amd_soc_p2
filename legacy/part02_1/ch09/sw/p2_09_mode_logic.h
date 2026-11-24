#ifndef P2_09_MODE_LOGIC_H
#define P2_09_MODE_LOGIC_H
#include <stdint.h>
/* P2-09: 보드에 종속되지 않는 운전 모드/문자열 명령 계약. */
typedef enum {
    P2_09_NOT_COMMAND = 0,
    P2_09_MODE_AUTO,
    P2_09_MODE_MANUAL,
    P2_09_MODE_STATUS,
    P2_09_MODE_INVALID,
    P2_09_IRQ_STATUS,
    P2_09_IRQ_INVALID
} P2_09_Command;
typedef enum { P2_09_MANUAL=0, P2_09_AUTO=1 } P2_09_Mode;
P2_09_Command p2_09_parse_command(const char *line);
const char *p2_09_mode_name(P2_09_Mode mode);
/* AUTO에서는 안전정책 해제 및 모터 기동 명령을 금지한다. */
int p2_09_allowed_in_auto(const char *line);
#endif
