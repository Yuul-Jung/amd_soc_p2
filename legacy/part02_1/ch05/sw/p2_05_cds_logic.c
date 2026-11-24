#include "p2_05_cds_logic.h"
#include <string.h>

CdsCommand cds_parse_command(const char *line)
{
    if (strcmp(line, "AUTO ON") == 0) return CDS_AUTO_ON;
    if (strcmp(line, "AUTO OFF") == 0) return CDS_AUTO_OFF;
    if (strcmp(line, "CDS POL LOW") == 0) return CDS_POL_LOW;
    if (strcmp(line, "CDS POL HIGH") == 0) return CDS_POL_HIGH;
    if (strcmp(line, "CDS READ") == 0) return CDS_READ;
    // (추가) AUTO/CDS로 시작하지만 정해진 문자열과 다르면 명시적 오류.
    if (strncmp(line, "AUTO", 4) == 0 || strncmp(line, "CDS", 3) == 0)
        return CDS_INVALID;
    return CDS_NOT_COMMAND;
}

uint32_t cds_control_word(uint8_t auto_on, uint8_t dark_when_low)
{
    // bit1: low -> dark. bit0: allow CdS gating.
    return ((dark_when_low ? 1U : 0U) << 1) | (auto_on ? 1U : 0U);
}

uint8_t cds_light_on(uint8_t pwm_high, uint8_t auto_on,
                     uint8_t dark_valid, uint8_t dark_filtered)
{
    // Matches auto_light_controller.v; AUTO ON cannot override PWM=0%.
    return (uint8_t)((pwm_high != 0U) &&
        ((auto_on == 0U) || ((dark_valid != 0U) && (dark_filtered != 0U))));
}
