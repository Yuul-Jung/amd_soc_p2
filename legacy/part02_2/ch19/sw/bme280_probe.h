#ifndef P2_19_BME280_PROBE_H
#define P2_19_BME280_PROBE_H
#include <stdint.h>
#include <stddef.h>
// Raw ADC codes are not physical temperature/pressure/humidity values.
// Never feed these into environment_policy's compensated input ports.
typedef struct {
    uint32_t adc_pressure_20;
    uint32_t adc_temperature_20;
    uint16_t adc_humidity_16;
} bme280_raw_t;
typedef int (*bme280_read_fn)(void *ctx, uint8_t addr7,
                              uint8_t reg, uint8_t *dst, size_t len);
typedef enum {
    BME280_PROBE_OK=0, BME280_PROBE_BAD_ARG=-1,
    BME280_PROBE_BUS=-2, BME280_PROBE_NOT_BME280=-3
} bme280_probe_status_t;
bme280_probe_status_t bme280_probe_id(bme280_read_fn read_reg,
    void *ctx,uint8_t addr7);
bme280_probe_status_t bme280_read_raw8(bme280_read_fn read_reg,
    void *ctx,uint8_t addr7,bme280_raw_t *raw);
#endif
