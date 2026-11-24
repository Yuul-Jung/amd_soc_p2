#include "bme280_probe.h"
// Bosch Sensortec BME280: 7bit addr 0x76/0x77; ID register D0 -> 0x60.
// Data 0xF7..0xFE: pressure MSB/LSB/XLSB, temp, then humidity.
// Compensation needs device-specific calibration registers and Bosch's
// compensation algorithms. This helper exposes ONLY raw ADC words.
static int address_ok(uint8_t addr7)
{
    return addr7==0x76u || addr7==0x77u;
}
bme280_probe_status_t bme280_probe_id(bme280_read_fn read_reg,
    void *ctx,uint8_t addr7)
{
    uint8_t id=0;
    if(!read_reg || !address_ok(addr7)) return BME280_PROBE_BAD_ARG;
    if(read_reg(ctx,addr7,0xd0u,&id,1)!=0) return BME280_PROBE_BUS;
    return id==0x60u ? BME280_PROBE_OK : BME280_PROBE_NOT_BME280;
}
bme280_probe_status_t bme280_read_raw8(bme280_read_fn read_reg,
    void *ctx,uint8_t addr7,bme280_raw_t *raw)
{
    uint8_t bytes[8];
    bme280_raw_t decoded;
    if(!read_reg || !raw || !address_ok(addr7))
        return BME280_PROBE_BAD_ARG;
    if(read_reg(ctx,addr7,0xf7u,bytes,sizeof(bytes))!=0)
        return BME280_PROBE_BUS;
    decoded.adc_pressure_20 = ((uint32_t)bytes[0]<<12) |
          ((uint32_t)bytes[1]<<4) | (uint32_t)(bytes[2]>>4);
    decoded.adc_temperature_20 = ((uint32_t)bytes[3]<<12) |
          ((uint32_t)bytes[4]<<4) | (uint32_t)(bytes[5]>>4);
    decoded.adc_humidity_16 = (uint16_t)(((uint16_t)bytes[6]<<8) |
                                            (uint16_t)bytes[7]);
    *raw=decoded;
    return BME280_PROBE_OK;
}
