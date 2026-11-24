#ifndef P2_13_MFRC522_PICC_H
#define P2_13_MFRC522_PICC_H
#include <stdint.h>
#include <stddef.h>

// 보드에 종속되지 않는 Register I/O 추상 인터페이스.
// 반환: 0 = 성공, 0이 아니면 SPI/버스 접근 오류.
typedef int (*rc522_read_fn)(void *ctx, uint8_t reg, uint8_t *value);
typedef int (*rc522_write_fn)(void *ctx, uint8_t reg, uint8_t value);
typedef struct {
    void *ctx;
    rc522_read_fn read;
    rc522_write_fn write;
} rc522_bus_t;

typedef enum {
    RC522_OK = 0,
    RC522_IO_ERROR = -1,
    RC522_TIMEOUT = -2,
    RC522_PROTOCOL_ERROR = -3,
    RC522_COLLISION = -4,
    RC522_UNSUPPORTED_UID = -5
} rc522_status_t;

// MFRC522 전원이 켜져 있고 Mode/Timer/TxControl 초기화가 끝난 상태에서만.
// REQA(7-bit) → ATQA(2B) → CL1 Anticollision(5B UID/BCC).
// 오직 충돌 없는 단일 4바이트 UID 카드 대상으로 실습.
rc522_status_t rc522_read_uid4(const rc522_bus_t *bus, uint8_t uid[4],
                                uint8_t atqa[2], uint32_t max_polls);
#endif
