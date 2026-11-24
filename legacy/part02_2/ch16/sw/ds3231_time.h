#ifndef P2_16_DS3231_TIME_H
#define P2_16_DS3231_TIME_H
#include <stdint.h>
#include <stddef.h>
#define DS3231_I2C_ADDR 0x68u
// 7-byte register burst is obtained with pointer 0x00 and repeated START.
// Return 0 on success, nonzero for bus errors.
typedef int (*ds3231_read_regs_fn)(void *ctx, uint8_t addr7,
                                  uint8_t reg, uint8_t *dest, size_t len);
typedef struct {
    uint16_t year;       // 2000..2199 if century flag is used.
    uint8_t month, day, weekday, hour, minute, second;
} ds3231_datetime_t;
typedef enum {
    DS3231_OK=0,
    DS3231_ERR_ARG=-1,
    DS3231_ERR_BUS=-2,
    DS3231_ERR_BCD=-3,
    DS3231_ERR_RANGE=-4,
    DS3231_ERR_OSF=-5
} ds3231_result_t;
// Hour 12/24 handling; weekday 1..7 is DS3231 user-defined sequence.
ds3231_result_t ds3231_decode_datetime(const uint8_t raw[7],
                                        ds3231_datetime_t *out);
// Reads status reg 0x0F OSF bit and time regs 0x00..0x06.
// OSF=1 rejects timestamp as untrusted; does not clear status by itself.
ds3231_result_t ds3231_read_datetime(ds3231_read_regs_fn reader, void *ctx,
                                      ds3231_datetime_t *out);
#endif
