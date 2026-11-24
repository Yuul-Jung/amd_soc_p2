#include "ds3231_time.h"
static int bcd_to_uint(uint8_t v,int *out)
{
    if ((v & 0x0fu)>9u || ((v>>4)&0x0fu)>9u) return -1;
    *out=(int)((v>>4)*10u+(v&0x0fu));
    return 0;
}
static int leap(unsigned y)
{
    return (y%4u==0u && (y%100u!=0u || y%400u==0u));
}
ds3231_result_t ds3231_decode_datetime(const uint8_t raw[7],
                                        ds3231_datetime_t *out)
{
    ds3231_datetime_t t;
    int seconds,minutes,hours,date,month,year,weekday,dim;
    const int days[12]={31,28,31,30,31,30,31,31,30,31,30,31};
    if(!raw||!out) return DS3231_ERR_ARG;
    if((raw[0]&0x80u) || (raw[1]&0x80u) || (raw[2]&0x80u) ||
       (raw[3]&0xf8u) || (raw[4]&0xc0u) || (raw[5]&0x60u))
        return DS3231_ERR_RANGE;
    if(bcd_to_uint(raw[0]&0x7fu,&seconds) ||
       bcd_to_uint(raw[1]&0x7fu,&minutes) ||
       bcd_to_uint(raw[3]&0x07u,&weekday) ||
       bcd_to_uint(raw[4]&0x3fu,&date) ||
       bcd_to_uint(raw[5]&0x1fu,&month) ||
       bcd_to_uint(raw[6],&year)) return DS3231_ERR_BCD;
    if(raw[2]&0x40u) {
        // DS3231 hours register bit6=1: 12-hour, bit5=PM.
        int h12;
        if((raw[2]&0x80u) || bcd_to_uint(raw[2]&0x1fu,&h12))
            return DS3231_ERR_BCD;
        if(h12<1 || h12>12) return DS3231_ERR_RANGE;
        hours=h12%12 + ((raw[2]&0x20u)?12:0);
    } else {
        if(bcd_to_uint(raw[2]&0x3fu,&hours)) return DS3231_ERR_BCD;
    }
    t.year=(uint16_t)(2000+year+((raw[5]&0x80u)?100:0));
    if(seconds>59 || minutes>59 || hours>23 || weekday<1 ||
       weekday>7 || month<1 || month>12 || date<1)
        return DS3231_ERR_RANGE;
    dim=days[month-1];
    if(month==2 && leap(t.year)) dim++;
    if(date>dim) return DS3231_ERR_RANGE;
    t.second=(uint8_t)seconds;t.minute=(uint8_t)minutes;
    t.hour=(uint8_t)hours;t.day=(uint8_t)date;
    t.month=(uint8_t)month;t.weekday=(uint8_t)weekday;
    *out=t; return DS3231_OK;
}
ds3231_result_t ds3231_read_datetime(ds3231_read_regs_fn reader, void *ctx,
                                      ds3231_datetime_t *out)
{
    uint8_t raw[7],status;
    if(!reader||!out) return DS3231_ERR_ARG;
    // Check OSF before and after snapshot to reject oscillator-stop
    // conditions arising during the read.
    if(reader(ctx,DS3231_I2C_ADDR,0x0f,&status,1)!=0)
        return DS3231_ERR_BUS;
    if(status&0x80u) return DS3231_ERR_OSF;
    if(reader(ctx,DS3231_I2C_ADDR,0x00,raw,7)!=0)
        return DS3231_ERR_BUS;
    if(reader(ctx,DS3231_I2C_ADDR,0x0f,&status,1)!=0)
        return DS3231_ERR_BUS;
    if(status&0x80u) return DS3231_ERR_OSF;
    return ds3231_decode_datetime(raw,out);
}
