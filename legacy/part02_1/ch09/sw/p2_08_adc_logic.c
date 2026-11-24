#include "p2_08_adc_logic.h"
#include <string.h>
/* (추가) UART는 문자열 전체가 일치해야만 명령으로 인정한다. */
AdcCommand adc_parse_command(const char *line)
{
    if (line == NULL) return ADC_INVALID;
    if (strcmp(line, "ADC READ") == 0) return ADC_READ;
    if (strcmp(line, "ADC PWM") == 0) return ADC_PWM;
    if (strncmp(line, "ADC", 3U) == 0) return ADC_INVALID;
    return ADC_NOT_COMMAND;
}
/* (추가) XADC 결과의 [15:4]에서 실제 12-bit 값을 추출. */
uint16_t adc_raw12_from_status(uint32_t reg32)
{
    return (uint16_t)((reg32 >> 4) & 0x0FFFU);
}
/* (추가) 0~1V 단극성 입력을 약 0~1000mV로 환산(반올림). */
uint32_t adc_millivolts_from_raw(uint16_t raw12)
{
    uint32_t r = (uint32_t)raw12 & 0x0FFFU;
    return (r * 1000U + 2047U) / 4095U;
}
/* (추가) 샘플을 LED1 PWM 요청 Duty 0~100%로 선형 변환. */
uint8_t adc_percent_from_raw(uint16_t raw12)
{
    uint32_t r = (uint32_t)raw12 & 0x0FFFU;
    return (uint8_t)((r * 100U + 2047U) / 4095U);
}
