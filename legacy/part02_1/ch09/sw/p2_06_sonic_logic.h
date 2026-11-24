#ifndef P2_06_SONIC_LOGIC_H
#define P2_06_SONIC_LOGIC_H
#include <stdint.h>
// Strict ASCII command grammar; never guess a sensor value from text.
typedef enum {
    SONIC_NOT_COMMAND=0, SONIC_ON, SONIC_OFF, SONIC_READ, SONIC_SHOT,
    SONIC_WARN_CM, SONIC_WARN_OFF, SONIC_INVALID
} SonicCommand;
SonicCommand sonic_parse_command(const char *line, uint16_t *warn_cm);
// Only a completed, valid 2..400cm reading can be displayed.
uint16_t sonic_visible_cm(uint32_t status, uint32_t distance);
// bit1 valid. Invalid/timeout/out-of-range => 0 (blank FND externally).
int sonic_sample_valid(uint32_t status, uint32_t distance);
#endif
