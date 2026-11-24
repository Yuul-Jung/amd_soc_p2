#ifndef P2_03_LOGIC_H
#define P2_03_LOGIC_H
#include <stdint.h>

// Board-independent application state and event semantics (testable on PC).
typedef struct {
    uint16_t value;       // 0000..9999, used in VALUE mode
    uint16_t event_count; // 0000..9999, used in EVENTS mode
    uint8_t mode;         // 0: VALUE, 1: EVENTS
    uint8_t display_on;   // 0/1, independent of mode
} P2AppState;

typedef enum {
    P2_CMD_INVALID = 0, P2_CMD_LED_ON, P2_CMD_LED_OFF,
    P2_CMD_STATUS, P2_CMD_DISP_OFF, P2_CMD_DISP_VALUE
} P2Command;

void p2_init(P2AppState *s);
void p2_apply_button(P2AppState *s, unsigned event_bit);
void p2_set_disp(P2AppState *s, uint16_t value);
uint16_t p2_visible_decimal(const P2AppState *s);
uint16_t p2_to_bcd4(uint16_t value);
P2Command p2_parse_command(const char *text, uint16_t *disp_value);
#endif
