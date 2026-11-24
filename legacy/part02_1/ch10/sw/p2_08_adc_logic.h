#ifndef P2_08_ADC_LOGIC_H
#define P2_08_ADC_LOGIC_H
#include <stdint.h>
/* ADC source: XADC Wizard VAUX6, 12 useful bits in status[15:4]. */
typedef enum {
    ADC_NOT_COMMAND=0, ADC_READ, ADC_PWM, ADC_INVALID
} AdcCommand;
AdcCommand adc_parse_command(const char *line);
uint16_t adc_raw12_from_status(uint32_t reg32);
uint32_t adc_millivolts_from_raw(uint16_t raw12);
uint8_t adc_percent_from_raw(uint16_t raw12);
#endif
