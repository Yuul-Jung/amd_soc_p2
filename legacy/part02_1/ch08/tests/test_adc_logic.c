#include "p2_08_adc_logic.h"
#include <assert.h>
#include <stdio.h>
int main(void)
{
    unsigned n = 0U;
#define CK(x) do { assert(x); ++n; } while(0)
    CK(adc_parse_command("ADC READ")==ADC_READ);
    CK(adc_parse_command("ADC PWM")==ADC_PWM);
    CK(adc_parse_command("ADC") == ADC_INVALID);
    CK(adc_parse_command("ADC PWM 50") == ADC_INVALID);
    CK(adc_parse_command("ADC READ ") == ADC_INVALID);
    CK(adc_parse_command("adc read") == ADC_NOT_COMMAND);
    CK(adc_parse_command("PWM 50") == ADC_NOT_COMMAND);
    CK(adc_parse_command("STATUS") == ADC_NOT_COMMAND);
    CK(adc_parse_command(NULL) == ADC_INVALID);
    CK(adc_raw12_from_status(0x00000000U)==0U);
    CK(adc_raw12_from_status(0x0000FFF0U)==4095U);
    CK(adc_raw12_from_status(0x00008000U)==2048U);
    CK(adc_raw12_from_status(0xF1234567U)==0x456U);
    CK(adc_millivolts_from_raw(0U)==0U);
    CK(adc_millivolts_from_raw(4095U)==1000U);
    CK(adc_percent_from_raw(0U)==0U);
    CK(adc_percent_from_raw(4095U)==100U);
    CK(adc_percent_from_raw(2048U)==50U);
    CK(adc_millivolts_from_raw(2048U)==500U);
    CK(adc_percent_from_raw(1024U)==25U);
    CK(adc_percent_from_raw(3072U)==75U);
    for(unsigned r=0;r<4096U;r++) {
        uint32_t mv = adc_millivolts_from_raw((uint16_t)r);
        uint8_t pct = adc_percent_from_raw((uint16_t)r);
        CK(mv<=1000U && pct<=100U);
        if(r) {
            CK(mv>=adc_millivolts_from_raw((uint16_t)(r-1)));
            CK(pct>=adc_percent_from_raw((uint16_t)(r-1)));
        }
    }
    puts("P2_08_ADC_HOST_ASSERTIONS_PASS");
    printf("ASSERTIONS=%u\n",n);
    return 0;
}
