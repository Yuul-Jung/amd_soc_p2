#ifndef P2_10_CAPSTONE_LOGIC_H
#define P2_10_CAPSTONE_LOGIC_H
#include <stdint.h>

/* (추가) MicroBlaze와 무관한 캡스톤 안전 정책 모델. */
typedef enum { P2_10_IDLE=0, P2_10_RUNNING, P2_10_FAULT } P2_10_RunState;
typedef enum { P2_10_CMD_NONE=0, P2_10_CMD_START, P2_10_CMD_STOP,
               P2_10_CMD_RESET, P2_10_CMD_STATUS, P2_10_CMD_INVALID } P2_10_Command;

enum {
    P2_10_FAULT_MODE   = 1U << 0, // MODE AUTO가 아님
    P2_10_FAULT_SONIC  = 1U << 1, // 초음파 유효·자동 측정 오류 또는 근접
    P2_10_FAULT_FRESH  = 1U << 2, // 07장 모터 RTL의 센서 신선도 만료
    P2_10_FAULT_TRIP   = 1U << 3, // 모터 RTL 안전 latch
    P2_10_FAULT_CDS    = 1U << 4, // 디지털 CdS 샘플 미확정
    P2_10_FAULT_CMD    = 1U << 5, // 다른 경로에서 모터 CMD 변경
    P2_10_FAULT_BUTTON = 1U << 6, // BTNR 5초 장누름(소프트웨어 정지 요청)
    P2_10_FAULT_WARN   = 1U << 7  // WARN threshold below minimum 20cm
};

typedef struct {
    uint8_t mode_auto;
    uint8_t sonic_auto;
    uint32_t sonic_status; // bit1 VALID, 2 TIMEOUT, 3 RANGE, 5 UNSAFE, 6 AUTO
    uint32_t motor_status; // bit3 TRIP, 5 SAFE, 6 FRESH, 7 AUTO
    uint32_t cds_status;   // bit2 VALID
    uint32_t warn_cm;      // P2-06 WARN_CFG, minimum 20cm for RUN
} P2_10_Guard;

typedef struct {
    P2_10_RunState state;
    uint32_t fault_latch;
    uint32_t stop_count;
} P2_10_State;

P2_10_Command p2_10_parse(const char *s);
const char *p2_10_state_name(P2_10_RunState state);
void p2_10_init(P2_10_State *s);
uint32_t p2_10_faults(const P2_10_Guard *g);
int p2_10_start(P2_10_State *s, const P2_10_Guard *g);
void p2_10_stop(P2_10_State *s);
void p2_10_reset(P2_10_State *s);  // SW latch만 해제, 모터 구동 안 함
int p2_10_tick(P2_10_State *s, const P2_10_Guard *g,
               uint32_t motor_cmd); // 1이면 MOTOR STOP 기록 필요
int p2_10_button_stop(P2_10_State *s); // BTNR 장누름 시 1=STOP 기록 필요
#endif
