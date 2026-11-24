#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "p2_03_logic.h"

#define TEST(e) do { if (!(e)) {fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #e); return 1;} passed++; } while(0)

int main(void)
{
    P2AppState s;
    uint16_t value = 7777;
    unsigned passed = 0;
    p2_init(&s);
    TEST(s.value == 0 && s.event_count == 0 && !s.display_on);
    TEST(p2_parse_command("LED ON", &value) == P2_CMD_LED_ON);
    TEST(p2_parse_command("LED OFF", &value) == P2_CMD_LED_OFF);
    TEST(p2_parse_command("STATUS", &value) == P2_CMD_STATUS);
    TEST(p2_parse_command("DISP OFF", &value) == P2_CMD_DISP_OFF);
    TEST(p2_parse_command("DISP 0050", &value) == P2_CMD_DISP_VALUE && value == 50);
    TEST(p2_to_bcd4(value) == 0x0050);
    TEST(p2_parse_command("DISP 0000", &value) == P2_CMD_DISP_VALUE && value == 0);
    TEST(p2_parse_command("DISP 9999", &value) == P2_CMD_DISP_VALUE && value == 9999);
    TEST(p2_parse_command("DISP 123", &value) == P2_CMD_INVALID);
    TEST(p2_parse_command("DISP 12A4", &value) == P2_CMD_INVALID);
    TEST(p2_parse_command("disp 1234", &value) == P2_CMD_INVALID);
    TEST(p2_parse_command("DISP 1234 ", &value) == P2_CMD_INVALID);
    TEST(p2_parse_command("1", &value) == P2_CMD_INVALID);
    TEST(p2_parse_command("LED ON\t", &value) == P2_CMD_INVALID);
    TEST(p2_parse_command("DISP OFF ", &value) == P2_CMD_INVALID);
    p2_set_disp(&s, 9999);
    TEST(s.value == 9999 && s.display_on && s.mode == 0);
    p2_apply_button(&s, 0); // UP short +1
    TEST(s.value == 0 && s.event_count == 1);
    p2_apply_button(&s, 1); // DOWN short -1
    TEST(s.value == 9999 && s.event_count == 2);
    p2_apply_button(&s, 4); // UP long +100
    TEST(s.value == 99 && s.event_count == 3);
    p2_apply_button(&s, 5); // DOWN long -100
    TEST(s.value == 9999 && s.event_count == 4);
    p2_apply_button(&s, 2); // LEFT short -> EVENTS
    TEST(s.mode == 1 && p2_visible_decimal(&s) == 5);
    p2_apply_button(&s, 3); // RIGHT short -> OFF
    TEST(s.display_on == 0 && s.event_count == 6);
    p2_apply_button(&s, 3); // RIGHT short -> ON
    TEST(s.display_on == 1 && s.event_count == 7);
    p2_apply_button(&s, 6); // LEFT long -> reset numeric VALUE
    TEST(s.value == 0 && s.event_count == 8 && s.mode == 1);
    p2_apply_button(&s, 7); // RIGHT long -> reset all, show 0000
    TEST(s.value == 0 && s.event_count == 0 && s.mode == 0 && s.display_on == 1);
    p2_apply_button(&s, 99); // Unknown ignored
    TEST(s.value == 0 && s.event_count == 0);
    p2_set_disp(&s, 1234);
    TEST(p2_to_bcd4(p2_visible_decimal(&s)) == 0x1234);
    s.event_count = 9999;
    p2_apply_button(&s, 0);
    TEST(s.event_count == 0 && s.value == 1235);
    puts("HOST_LOGIC PASS");
    printf("ASSERTIONS %u\n", passed);
    return 0;
}
