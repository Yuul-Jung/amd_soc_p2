#include "p2_06_sonic_logic.h"
#include <string.h>

SonicCommand sonic_parse_command(const char *line, uint16_t *warn_cm)
{
    unsigned value=0U, n=0U;
    const char *p;
    if (!line || !warn_cm) return SONIC_INVALID;
    if (strcmp(line, "SONIC ON") == 0) return SONIC_ON;
    if (strcmp(line, "SONIC OFF") == 0) return SONIC_OFF;
    if (strcmp(line, "SONIC READ") == 0) return SONIC_READ;
    if (strcmp(line, "SONIC SHOT") == 0) return SONIC_SHOT;
    if (strcmp(line, "WARN OFF") == 0) return SONIC_WARN_OFF;
    if (strncmp(line, "SONIC", 5U) == 0 ||
        strncmp(line, "WARN", 4U) == 0) {
        if (strncmp(line, "WARN ", 5U) != 0) return SONIC_INVALID;
        p = line + 5;
        if (*p < '1' || *p > '9') return SONIC_INVALID;
        while (*p) {
            if (*p < '0' || *p > '9' || ++n > 3U) return SONIC_INVALID;
            value = value*10U+(unsigned)(*p-'0');
            ++p;
        }
        if (value > 400U) return SONIC_INVALID;
        *warn_cm=(uint16_t)value;
        return SONIC_WARN_CM;
    }
    return SONIC_NOT_COMMAND;
}

int sonic_sample_valid(uint32_t status, uint32_t distance)
{
    return ((status & (1U<<1)) != 0U && distance >= 2U && distance <= 400U);
}

uint16_t sonic_visible_cm(uint32_t status, uint32_t distance)
{
    return sonic_sample_valid(status,distance) ? (uint16_t)distance : 0U;
}
