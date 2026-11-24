#include "p2_03_logic.h"
#include <string.h>

void p2_init(P2AppState *s)
{
    s->value = 0; s->event_count = 0;
    s->mode = 0; s->display_on = 0; // Same FND reset-off policy as P2-02.
}

static uint16_t wrap_10000(int value)
{
    value %= 10000;
    if (value < 0) value += 10000;
    return (uint16_t)value;
}

void p2_apply_button(P2AppState *s, unsigned event_bit)
{
    // Bit 0..3 short U/D/L/R; 4..7 long U/D/L/R.
    if (event_bit > 7U) return;
    s->event_count = wrap_10000((int)s->event_count + 1);
    switch (event_bit) {
    case 0: s->value = wrap_10000((int)s->value + 1); break;
    case 1: s->value = wrap_10000((int)s->value - 1); break;
    case 2: s->mode ^= 1U; break;
    case 3: s->display_on ^= 1U; break;
    case 4: s->value = wrap_10000((int)s->value + 100); break;
    case 5: s->value = wrap_10000((int)s->value - 100); break;
    case 6: s->value = 0; break;
    case 7: p2_init(s); s->display_on = 1; break; // Reset all, show 0000.
    default: break;
    }
}

void p2_set_disp(P2AppState *s, uint16_t value)
{
    s->value = value; s->mode = 0; s->display_on = 1;
}

uint16_t p2_visible_decimal(const P2AppState *s)
{
    return (s->mode == 0U) ? s->value : s->event_count;
}

uint16_t p2_to_bcd4(uint16_t value)
{
    // 0050 -> 0x0050; do not use binary integer 50 as FND raw digits.
    uint16_t thousands = (uint16_t)(value / 1000U);
    uint16_t hundreds = (uint16_t)((value / 100U) % 10U);
    uint16_t tens = (uint16_t)((value / 10U) % 10U);
    uint16_t ones = (uint16_t)(value % 10U);
    return (uint16_t)((thousands << 12) | (hundreds << 8) |
                      (tens << 4) | ones);
}

P2Command p2_parse_command(const char *text, uint16_t *disp_value)
{
    unsigned i;
    unsigned v = 0;
    if (strcmp(text, "LED ON") == 0) return P2_CMD_LED_ON;
    if (strcmp(text, "LED OFF") == 0) return P2_CMD_LED_OFF;
    if (strcmp(text, "STATUS") == 0) return P2_CMD_STATUS;
    if (strcmp(text, "DISP OFF") == 0) return P2_CMD_DISP_OFF;
    if (strlen(text) != 9U || memcmp(text, "DISP ", 5U) != 0)
        return P2_CMD_INVALID;
    for (i = 5U; i < 9U; ++i) {
        if (text[i] < '0' || text[i] > '9') return P2_CMD_INVALID;
        v = v * 10U + (unsigned)(text[i] - '0');
    }
    *disp_value = (uint16_t)v;
    return P2_CMD_DISP_VALUE;
}
