#include "../sw/bme280_probe.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>
typedef struct {
    uint8_t regs[256];
    uint8_t captured_addr, captured_reg;
    size_t captured_len;
    int fail;
} bus_t;
static int mock_read(void *ctx,uint8_t a,uint8_t reg,uint8_t *d,size_t n)
{
    bus_t *bus=(bus_t*)ctx;
    bus->captured_addr=a;bus->captured_reg=reg;bus->captured_len=n;
    if(bus->fail || (size_t)reg+n>256u)return -1;
    memcpy(d,bus->regs+reg,n);
    return 0;
}
int main(void)
{
    bus_t b={0};
    bme280_raw_t raw={0};
    b.regs[0xd0]=0x60;
    assert(bme280_probe_id(mock_read,&b,0x76)==BME280_PROBE_OK);
    assert(b.captured_addr==0x76 && b.captured_reg==0xd0 &&
           b.captured_len==1);
    b.regs[0xd0]=0x58; // BMP280 is pressure/temp only; not BME280.
    assert(bme280_probe_id(mock_read,&b,0x77)==BME280_PROBE_NOT_BME280);
    assert(bme280_probe_id(mock_read,&b,0x75)==BME280_PROBE_BAD_ARG);
    puts("P2_19_BME280_ID_BMP280_REJECT_PASS");
    // Raw pressure 0xABCDE, raw temperature 0x54321, humidity 0xA55A.
    const uint8_t data[8]={0xab,0xcd,0xe0,0x54,0x32,0x10,0xa5,0x5a};
    memcpy(b.regs+0xf7,data,8);
    assert(bme280_read_raw8(mock_read,&b,0x77,&raw)==BME280_PROBE_OK);
    assert(raw.adc_pressure_20==0xabcde &&
           raw.adc_temperature_20==0x54321 &&
           raw.adc_humidity_16==0xa55a);
    assert(b.captured_addr==0x77 && b.captured_reg==0xf7 &&
           b.captured_len==8);
    puts("P2_19_BME280_RAW8_DECODER_PASS");
    b.fail=1;
    assert(bme280_probe_id(mock_read,&b,0x76)==BME280_PROBE_BUS);
    assert(bme280_read_raw8(mock_read,&b,0x76,&raw)==BME280_PROBE_BUS);
    puts("P2_19_BME280_BUS_ERROR_PASS");
    puts("P2_19_BME280_HOST_C_PASS");
    return 0;
}
