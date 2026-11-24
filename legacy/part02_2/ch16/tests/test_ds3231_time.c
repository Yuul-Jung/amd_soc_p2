#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../sw/ds3231_time.h"
typedef struct {uint8_t regs[0x13];int calls,fail_at,osf_during_read;} fake_rtc_t;
static int fake_read(void *ctx,uint8_t addr,uint8_t reg,uint8_t *dest,size_t len)
{
    fake_rtc_t *f=(fake_rtc_t*)ctx;
    f->calls++;
    if(f->fail_at==f->calls || addr!=0x68 || (size_t)reg+len>sizeof(f->regs))
        return -1;
    if(f->osf_during_read && f->calls==3) f->regs[0x0f]|=0x80;
    memcpy(dest,f->regs+reg,len);
    return 0;
}
static void seed(fake_rtc_t *f)
{
    memset(f,0,sizeof(*f));
    // 2026-11-11 09:42:58, user-defined weekday 4.
    uint8_t v[7]={0x58,0x42,0x09,0x04,0x11,0x11,0x26};
    memcpy(f->regs,v,7);
}
int main(void)
{
    fake_rtc_t f;ds3231_datetime_t t;
    seed(&f);
    assert(ds3231_read_datetime(fake_read,&f,&t)==DS3231_OK);
    assert(f.calls==3 && t.year==2026 && t.month==11 && t.day==11 &&
           t.hour==9 && t.minute==42 && t.second==58 && t.weekday==4);
    puts("P2_16_RTC_BURST_BCD_24H_PASS");
    seed(&f);f.regs[2]=0x72; // 12-hour 12 PM -> 12:xx
    assert(ds3231_read_datetime(fake_read,&f,&t)==DS3231_OK && t.hour==12);
    f.calls=0;f.regs[2]=0x52; // 12 AM -> 00:xx
    assert(ds3231_read_datetime(fake_read,&f,&t)==DS3231_OK && t.hour==0);
    f.calls=0;f.regs[2]=0x61; // 1 PM -> 13:xx
    assert(ds3231_read_datetime(fake_read,&f,&t)==DS3231_OK && t.hour==13);
    puts("P2_16_RTC_12H_AM_PM_PASS");
    seed(&f);f.regs[4]=0x29;f.regs[5]=0x02;f.regs[6]=0x24;
    assert(ds3231_decode_datetime(f.regs,&t)==DS3231_OK && t.day==29);
    f.regs[6]=0x25;
    assert(ds3231_decode_datetime(f.regs,&t)==DS3231_ERR_RANGE);
    f.regs[4]=0x31;f.regs[5]=0x04;
    assert(ds3231_decode_datetime(f.regs,&t)==DS3231_ERR_RANGE);
    puts("P2_16_RTC_LEAP_CALENDAR_PASS");
    seed(&f);f.regs[5]=0x91;f.regs[6]=0x00;f.regs[4]=0x11;
    assert(ds3231_decode_datetime(f.regs,&t)==DS3231_OK && t.year==2100);
    f.regs[4]=0x29;f.regs[5]=0x82;
    assert(ds3231_decode_datetime(f.regs,&t)==DS3231_ERR_RANGE);
    puts("P2_16_RTC_CENTURY_2100_PASS");
    seed(&f);f.regs[1]=0x6a;
    assert(ds3231_decode_datetime(f.regs,&t)==DS3231_ERR_BCD);
    seed(&f);f.regs[0]=0x60;
    assert(ds3231_decode_datetime(f.regs,&t)==DS3231_ERR_RANGE);
    seed(&f);f.regs[3]=0;
    assert(ds3231_decode_datetime(f.regs,&t)==DS3231_ERR_RANGE);
    puts("P2_16_RTC_INVALID_DATA_REJECT_PASS");
    seed(&f);f.regs[0x0f]=0x80;
    assert(ds3231_read_datetime(fake_read,&f,&t)==DS3231_ERR_OSF);
    seed(&f);f.osf_during_read=1;
    assert(ds3231_read_datetime(fake_read,&f,&t)==DS3231_ERR_OSF);
    seed(&f);f.fail_at=2;
    assert(ds3231_read_datetime(fake_read,&f,&t)==DS3231_ERR_BUS);
    puts("P2_16_RTC_OSF_BUS_ERROR_PASS");
    puts("P2_16_HOST_RTC_TESTS_PASS");
    return 0;
}
