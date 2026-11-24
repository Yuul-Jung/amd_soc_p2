#ifndef P2_05_CDS_LOGIC_H
#define P2_05_CDS_LOGIC_H
#include <stdint.h>

// Reusable exact-match ASCII command parser, independent of AMD BSP.
typedef enum {
    CDS_NOT_COMMAND=0, CDS_AUTO_ON, CDS_AUTO_OFF,
    CDS_POL_LOW, CDS_POL_HIGH, CDS_READ, CDS_INVALID
} CdsCommand;
CdsCommand cds_parse_command(const char *line);
uint32_t cds_control_word(uint8_t auto_on, uint8_t dark_when_low);
uint8_t cds_light_on(uint8_t pwm_high, uint8_t auto_on,
                     uint8_t dark_valid, uint8_t dark_filtered);
#endif
