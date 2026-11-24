/* P2-09: integrate P2-01..08 commands, button IRQ and Timer heartbeat.
 * NOTE: Base addresses, Interrupt ID/Parent MUST be read from actual BSP.
 * This source intentionally rejects unknown constants before target build.
 */
#include "xparameters.h"
#include "xil_types.h"      /* u8, u32, UINTPTR */
#include "xil_io.h"         /* Xil_In32, Xil_Out32 */
#include "xuartlite_l.h"    /* UART Lite byte functions + FIFO empty check */
#include "xstatus.h"
#include "xgpio.h"        /* AXI GPIO LED14/15: legacy output path */
#include "xtmrctr.h"      /* AXI Timer + heartbeat IRQ */
#include "p2_09_mode_logic.h" /* MODE / IRQ string grammar */
#include "xil_exception.h"
#ifdef SDT
#include "xinterrupt_wrap.h" /* SDT interrupt API */
#else
#include "xintc.h"          /* Classic interrupt controller API */
#endif
#include "p2_03_logic.h"
#include "p2_04_pwm_logic.h" // Reused 04 PWM parser / duty calculation
#include "p2_05_cds_logic.h" // Existing AUTO/CDS command parser
#include "p2_06_sonic_logic.h" // (유지) SONIC/WARN command parser
#include "p2_07_motor_logic.h" // (추가) MOTOR FWD/REV/STOP/STATUS parser
#include "p2_08_adc_logic.h" // (추가) XADC 12비트·mV·PWM 변환 및 명령 처리

#ifndef P2_04_PWM_BASEADDR
#define P2_04_PWM_BASEADDR 0xFFFFFFFFU
#endif
#if P2_04_PWM_BASEADDR == 0xFFFFFFFFU
#error "Set P2_04_PWM_BASEADDR from CURRENT Vivado Address Editor/xparameters.h"
#endif
// (추가) Never guess the fifth AXI IP base: use CURRENT generated BSP.
#ifndef P2_05_CDS_BASEADDR
#define P2_05_CDS_BASEADDR 0xFFFFFFFFU
#endif
#if P2_05_CDS_BASEADDR == 0xFFFFFFFFU
#error "Set P2_05_CDS_BASEADDR from CURRENT Address Editor/xparameters.h"
#endif
#ifndef P2_01_LED_BASEADDR
#define P2_01_LED_BASEADDR 0xFFFFFFFFU
#endif
#ifndef P2_02_FND_BASEADDR
#define P2_02_FND_BASEADDR 0xFFFFFFFFU
#endif
#ifndef P2_03_BTN_BASEADDR
#define P2_03_BTN_BASEADDR 0xFFFFFFFFU
#endif
#if P2_01_LED_BASEADDR == 0xFFFFFFFFU || P2_02_FND_BASEADDR == 0xFFFFFFFFU || P2_03_BTN_BASEADDR == 0xFFFFFFFFU
#error "Set all three AXI IP addresses from CURRENT Address Editor/xparameters.h"
#endif
#if P2_01_LED_BASEADDR == P2_02_FND_BASEADDR || P2_01_LED_BASEADDR == P2_03_BTN_BASEADDR || P2_02_FND_BASEADDR == P2_03_BTN_BASEADDR
#error "Three user AXI IP base addresses must be unique"
#endif
#ifndef P2_03_BTN_INTR_ID
#error "Fill P2_03_BTN_INTR_ID from CURRENT generated BSP interrupt map"
#endif
#ifdef SDT
#ifndef P2_03_BTN_INTR_PARENT
#error "Fill P2_03_BTN_INTR_PARENT (SDT encoded interrupt parent) from actual BSP"
#endif
#else
#ifndef P2_03_INTC_DEVICE_ID
#error "Fill P2_03_INTC_DEVICE_ID from Classic BSP"
#endif
#endif

#if defined(XPAR_XUARTLITE_0_BASEADDR)
#define UART_BASEADDR XPAR_XUARTLITE_0_BASEADDR
#elif defined(XPAR_UARTLITE_0_BASEADDR)
#define UART_BASEADDR XPAR_UARTLITE_0_BASEADDR
#elif defined(XPAR_AXI_UARTLITE_0_BASEADDR)
#define UART_BASEADDR XPAR_AXI_UARTLITE_0_BASEADDR
#else
#error "Check UART Lite base macro in the generated xparameters.h"
#endif

#define FND_VAL_REG  0x00U
#define FND_CTRL_REG 0x04U
#define BTN_PENDING  0x00U
#define BTN_ENABLE   0x04U
#define BTN_PRESSED  0x08U
#define BTN_ID       0x0CU
#define BTN_COALESCED 0x10U
// P2-04 register offsets: 32-bit, byte-addressed.
#define PWM_PERIOD_CFG 0x00U
#define PWM_DUTY_CFG   0x04U
#define PWM_CTRL_CFG   0x08U
#define PWM_APPLY      0x0CU
#define PWM_STATUS     0x10U
#define PWM_PERIOD_ACT 0x14U
#define PWM_DUTY_ACT   0x18U
#define PWM_ID         0x1CU
#define PWM_IP_ID      0x00040001U
#define PWM_PERIOD_TICKS 100000U // AXI Clock이 실제 100MHz일 때 1kHz.
#if P2_04_PWM_BASEADDR == P2_01_LED_BASEADDR || \
    P2_04_PWM_BASEADDR == P2_02_FND_BASEADDR || \
    P2_04_PWM_BASEADDR == P2_03_BTN_BASEADDR
#error "New PWM IP base must differ from all prior IP addresses"
#endif
// (추가) P2-05 digital CdS AXI register map (32-bit byte offsets).
#define CDS_CTRL    0x00U
#define CDS_STATUS  0x04U
#define CDS_IP_ID   0x08U
#define CDS_FILTER  0x0CU
#define CDS_EXPECTED_ID 0x00050001U
#ifndef P2_06_SONIC_BASEADDR
#define P2_06_SONIC_BASEADDR 0xFFFFFFFFU
#endif
#if P2_06_SONIC_BASEADDR == 0xFFFFFFFFU
#error "Set P2_06_SONIC_BASEADDR from CURRENT Address Editor and BSP"
#endif
#if P2_05_CDS_BASEADDR == P2_01_LED_BASEADDR || \
    P2_05_CDS_BASEADDR == P2_02_FND_BASEADDR || \
    P2_05_CDS_BASEADDR == P2_03_BTN_BASEADDR || \
    P2_05_CDS_BASEADDR == P2_04_PWM_BASEADDR
#error "P2-05 CdS IP base address must differ from P2-01~04"
#endif
// (추가) P2-06 AXI4-Lite offsets; all byte offsets.
#define SONIC_CTRL       0x00U
#define SONIC_STATUS     0x04U
#define SONIC_DIST_CM    0x08U
#define SONIC_ECHO_US    0x0CU
#define SONIC_WARN_CFG   0x10U
#define SONIC_SEQ        0x14U
#define SONIC_ID         0x18U
#define SONIC_CLK_HZ     0x1CU
#define SONIC_EXPECTED_ID 0x00060001U
#if P2_06_SONIC_BASEADDR == P2_01_LED_BASEADDR || \
    P2_06_SONIC_BASEADDR == P2_02_FND_BASEADDR || \
    P2_06_SONIC_BASEADDR == P2_03_BTN_BASEADDR || \
    P2_06_SONIC_BASEADDR == P2_04_PWM_BASEADDR || \
    P2_06_SONIC_BASEADDR == P2_05_CDS_BASEADDR
#error "P2-06 SONIC AXI base must be distinct from all previous IPs"
#endif
// (추가) All AXI motor addresses are BSP-derived; never invent a base.
#ifndef P2_07_MOTOR_BASEADDR
#define P2_07_MOTOR_BASEADDR 0xFFFFFFFFU
#endif
#if P2_07_MOTOR_BASEADDR == 0xFFFFFFFFU
#error "Set P2_07_MOTOR_BASEADDR from CURRENT Vivado Address Editor/xparameters.h"
#endif
#if P2_07_MOTOR_BASEADDR == P2_01_LED_BASEADDR || \
    P2_07_MOTOR_BASEADDR == P2_02_FND_BASEADDR || \
    P2_07_MOTOR_BASEADDR == P2_03_BTN_BASEADDR || \
    P2_07_MOTOR_BASEADDR == P2_04_PWM_BASEADDR || \
    P2_07_MOTOR_BASEADDR == P2_05_CDS_BASEADDR || \
    P2_07_MOTOR_BASEADDR == P2_06_SONIC_BASEADDR
#error "P2-07 motor AXI base must be distinct from all other IPs"
#endif
// (추가) 새 XADC Wizard AXI 주소는 실제 Address Editor에서만 가져온다.
#ifndef P2_08_XADC_BASEADDR
#define P2_08_XADC_BASEADDR 0xFFFFFFFFU
#endif
#if P2_08_XADC_BASEADDR == 0xFFFFFFFFU
#error "Set P2_08_XADC_BASEADDR from CURRENT Vivado Address Editor/xparameters.h"
#endif
#if P2_08_XADC_BASEADDR == P2_01_LED_BASEADDR || \
    P2_08_XADC_BASEADDR == P2_02_FND_BASEADDR || \
    P2_08_XADC_BASEADDR == P2_03_BTN_BASEADDR || \
    P2_08_XADC_BASEADDR == P2_04_PWM_BASEADDR || \
    P2_08_XADC_BASEADDR == P2_05_CDS_BASEADDR || \
    P2_08_XADC_BASEADDR == P2_06_SONIC_BASEADDR || \
    P2_08_XADC_BASEADDR == P2_07_MOTOR_BASEADDR
#error "P2-08 XADC AXI base must differ from every previously used AXI IP base"
#endif
/* AMD sysmon xsysmon_hw.h: XSM_AUX06_OFFSET, Artix-7 offset 0x258.
 * XADC의 전용 Status Register이며 사용자 IP가 아니다. */
#define XADC_AUX06_OFFSET 0x258U
#define MOTOR_CMD_REG     0x00U
#define MOTOR_STATUS_REG  0x04U
#define MOTOR_ID_REG      0x08U
#define MOTOR_DEADTIME    0x0CU
#define MOTOR_FRESHNESS   0x10U
#define MOTOR_CLK_HZ      0x14U
#define MOTOR_EXPECTED_ID 0x00070001U
#define LINE_CAP     32U
/* 실제 BD의 0.5초 타이머 클록 확인 없이 주기를 단정하지 않는다. */
#ifndef P2_09_TIMER_CLK_HZ
#error "Define P2_09_TIMER_CLK_HZ from the CURRENT Timer clock connection"
#endif
#if P2_09_TIMER_CLK_HZ < 4U
#error "Timer clock must be at least 4Hz for this lesson"
#endif
#define TIMER0 0U
#define TIMER_RESET_VALUE ((P2_09_TIMER_CLK_HZ/2U)-2U)
#define UART_ACTIVITY_LED14 0x00004000U
#define TIMER_HEARTBEAT_LED15 0x00008000U
#ifndef SDT
#ifndef P2_09_TIMER_DEVICE_ID
#error "Define P2_09_TIMER_DEVICE_ID from Classic BSP"
#endif
#ifndef P2_09_TIMER_INTR_ID
#error "Define P2_09_TIMER_INTR_ID from Classic BSP AXI INTC map"
#endif
#if P2_09_TIMER_INTR_ID == P2_03_BTN_INTR_ID
#error "Button IRQ ID and Timer IRQ ID must be different"
#endif
#ifndef P2_09_GPIO_DEVICE_ID
#error "Define P2_09_GPIO_DEVICE_ID from Classic BSP"
#endif
#else
#ifndef P2_09_TIMER_BASEADDR
#error "Define P2_09_TIMER_BASEADDR from SDT BSP"
#endif
#ifndef P2_09_GPIO_BASEADDR
#error "Define P2_09_GPIO_BASEADDR from SDT BSP"
#endif
/* (추가) 09장의 기존 GPIO/Timer 주소는 앞선 사용자 IP와 분리. */
#if P2_09_TIMER_BASEADDR == P2_09_GPIO_BASEADDR || \
    P2_09_TIMER_BASEADDR == P2_01_LED_BASEADDR || \
    P2_09_TIMER_BASEADDR == P2_02_FND_BASEADDR || \
    P2_09_TIMER_BASEADDR == P2_03_BTN_BASEADDR || \
    P2_09_TIMER_BASEADDR == P2_04_PWM_BASEADDR || \
    P2_09_TIMER_BASEADDR == P2_05_CDS_BASEADDR || \
    P2_09_TIMER_BASEADDR == P2_06_SONIC_BASEADDR || \
    P2_09_TIMER_BASEADDR == P2_07_MOTOR_BASEADDR || \
    P2_09_TIMER_BASEADDR == P2_08_XADC_BASEADDR
#error "Timer base address aliases GPIO or another AXI IP"
#endif
#if P2_09_GPIO_BASEADDR == P2_01_LED_BASEADDR || \
    P2_09_GPIO_BASEADDR == P2_02_FND_BASEADDR || \
    P2_09_GPIO_BASEADDR == P2_03_BTN_BASEADDR || \
    P2_09_GPIO_BASEADDR == P2_04_PWM_BASEADDR || \
    P2_09_GPIO_BASEADDR == P2_05_CDS_BASEADDR || \
    P2_09_GPIO_BASEADDR == P2_06_SONIC_BASEADDR || \
    P2_09_GPIO_BASEADDR == P2_07_MOTOR_BASEADDR || \
    P2_09_GPIO_BASEADDR == P2_08_XADC_BASEADDR
#error "AXI GPIO base address aliases a custom IP"
#endif
#endif

static P2AppState app;
static u8 pwm_requested_percent = 0U;
// (추가) The C application owns control policy; RTL filters raw CdS signal.
static u8 cds_auto_enabled = 0U;
static u8 sonic_auto_enabled = 0U;
static u8 sonic_warn_enabled = 1U;
static u8 sonic_view = 0U; // 1: DIST(cm) FND view overrides VALUE/EVENTS.
static u8 sonic_view_fresh = 0U; // Blank stale result until next completion after ON.
static u32 sonic_seq_seen = 0U;
static u8 cds_dark_when_low = 1U; // Start assumption; verify DO via CDS READ.
static u8 adc_last_applied = 0U; // (추가) ADC PWM 명령의 마지막 요청 Duty
static u8 adc_apply_seen = 0U; // (추가) 아직 적용한 적 없음을 구분

static P2_09_Mode control_mode = P2_09_MANUAL;
static volatile u32 timer_irq_count = 0U; /* ISR 단순 카운트 */
static u32 led_gpio_shadow = 0U;  /* GPIO LED14/15만 씀; LED0~2는 별도 IP */
static u8 uart_line_activity = 0U; /* 완료된 문자열 명령마다 LED14 토글 */
static XTmrCtr timer;
static XGpio gpio;
static volatile u32 irq_counts[8]; // ISR writes monotonically; main reads.
static u32 handled_counts[8];      // Main-only processed counts.
#ifndef SDT
static XIntc intc;
#endif

static void uart_puts(const char *s)
{
    while (*s) XUartLite_SendByte(UART_BASEADDR, (u8)*s++);
}
static void uart_hex32(u32 v)
{
    const char hex[] = "0123456789ABCDEF";
    int shift;
    for (shift = 28; shift >= 0; shift -= 4)
        XUartLite_SendByte(UART_BASEADDR, (u8)hex[(v >> shift) & 15U]);
}
static void uart_dec4(u32 value)
{
    int d;
    u32 divisors[4] = {1000U, 100U, 10U, 1U};
    for (d = 0; d < 4; ++d) {
        u32 n = (value / divisors[d]) % 10U;
        XUartLite_SendByte(UART_BASEADDR, (u8)('0' + n));
    }
}

// (추가) 0~4294967295를 선행 0 없이 UART에 출력.
static void uart_dec_u32(u32 value)
{
    char tmp[10]; // u32 십진수 최대 10자리.
    unsigned used = 0U;
    do {
        tmp[used++] = (char)('0' + (value % 10U));
        value /= 10U;
    } while (value != 0U);
    while (used != 0U)
        XUartLite_SendByte(UART_BASEADDR, (u8)tmp[--used]);
}

// (추가) 이전 설정이 반영 중이면 BUSY, 아니면 다음 주기 적용을 예약.
static int pwm_queue_percent(u8 percent)
{
    u32 duty;
    if ((Xil_In32(P2_04_PWM_BASEADDR + PWM_STATUS) & 1U) != 0U)
        return 0; // 기존 Pending 설정을 덮지 않는다.
    duty = pwm_duty_for_percent(PWM_PERIOD_TICKS, percent);
    Xil_Out32(P2_04_PWM_BASEADDR + PWM_PERIOD_CFG, PWM_PERIOD_TICKS);
    Xil_Out32(P2_04_PWM_BASEADDR + PWM_DUTY_CFG, duty);
    Xil_Out32(P2_04_PWM_BASEADDR + PWM_CTRL_CFG, percent ? 1U : 0U);
    Xil_Out32(P2_04_PWM_BASEADDR + PWM_APPLY, 1U);
    pwm_requested_percent = percent;
    return 1;
}

// (추가) 7-series XADC AXI 데이터 Status는 상위 12비트가 유효하다.
static uint16_t adc_sample_raw12(void)
{
    u32 reg32 = Xil_In32(P2_08_XADC_BASEADDR + XADC_AUX06_OFFSET);
    return (uint16_t)adc_raw12_from_status(reg32);
}

// (추가) 샘플 레지스터의 현재 저장값을 출력한다; 신규 변환 완료 증거는 아니다.
static void adc_print_reading(void)
{
    uint16_t raw = adc_sample_raw12();
    uart_puts("ADC AUX6 RAW="); uart_dec_u32(raw);
    uart_puts(" MV="); uart_dec_u32(adc_millivolts_from_raw(raw));
    uart_puts(" PWM_REF="); uart_dec_u32(adc_percent_from_raw(raw));
    uart_puts("% (stored sample; freshness not guaranteed)\r\n");
}

// (추가) Write configuration as one atomic 32-bit AXI register update.
static void cds_commit_control(void)
{
    Xil_Out32(P2_05_CDS_BASEADDR + CDS_CTRL,
              cds_control_word(cds_auto_enabled, cds_dark_when_low));
}

// (추가) Read sensor pins via AXI status, not by polling a physical GPIO.
static void cds_print_reading(void)
{
    u32 bits = Xil_In32(P2_05_CDS_BASEADDR + CDS_STATUS);
    uart_puts("CDS RAW="); uart_dec_u32(bits & 1U);
    uart_puts(" DARK="); uart_dec_u32((bits >> 1) & 1U);
    uart_puts(" VALID="); uart_dec_u32((bits >> 2) & 1U);
    uart_puts(" GATE="); uart_dec_u32((bits >> 3) & 1U);
    uart_puts(" AUTO="); uart_dec_u32((bits >> 4) & 1U);
    uart_puts(" POL="); uart_puts((bits & (1U << 5)) ? "LOW" : "HIGH");
    uart_puts("\r\n");
}

// (추가) 06장 STATUS는 최근 완료된 샘플(VALID/TIMEOUT/RANGE)을 보존.
// SEQ is a lightweight change marker; the HW has no atomic multiword latch.
static void sonic_read_state(u32 *status, u32 *cm, u32 *seq)
{
    u32 a, b;
    unsigned tries;
    for (tries = 0; tries < 3U; ++tries) {
        a = Xil_In32(P2_06_SONIC_BASEADDR + SONIC_SEQ);
        *status = Xil_In32(P2_06_SONIC_BASEADDR + SONIC_STATUS);
        *cm = Xil_In32(P2_06_SONIC_BASEADDR + SONIC_DIST_CM);
        b = Xil_In32(P2_06_SONIC_BASEADDR + SONIC_SEQ);
        if (a == b) { *seq = b; return; }
    }
    *seq = b; // Contended snapshot: STATUS logs must not claim atomicity.
}

static void sonic_commit_ctrl(void)
{
    Xil_Out32(P2_06_SONIC_BASEADDR + SONIC_CTRL,
              (u32)sonic_auto_enabled | ((u32)sonic_warn_enabled << 2));
}

static void sonic_print_reading(void)
{
    u32 st, cm, seq, echo_us;
    sonic_read_state(&st,&cm,&seq);
    echo_us = Xil_In32(P2_06_SONIC_BASEADDR + SONIC_ECHO_US);
    uart_puts("SONIC CM="); uart_dec_u32(cm);
    uart_puts(" ECHO_US="); uart_dec_u32(echo_us);
    uart_puts(" VALID="); uart_dec_u32((st >> 1) & 1U);
    uart_puts(" TIMEOUT="); uart_dec_u32((st >> 2) & 1U);
    uart_puts(" RANGE_ERROR="); uart_dec_u32((st >> 3) & 1U);
    uart_puts(" BUSY="); uart_dec_u32(st & 1U);
    uart_puts(" ALERT="); uart_dec_u32((st >> 4) & 1U);
    uart_puts(" UNSAFE="); uart_dec_u32((st >> 5) & 1U);
    uart_puts(" SEQ="); uart_dec_u32(seq);
    uart_puts(" WARN_CM="); uart_dec_u32(
        Xil_In32(P2_06_SONIC_BASEADDR + SONIC_WARN_CFG));
    uart_puts("\r\n");
}

static void fnd_commit(void)
{
    if (sonic_view) {
        u32 st, cm, seq;
        uint16_t visible;
        sonic_read_state(&st,&cm,&seq);
        visible = sonic_visible_cm(st,cm);
        // (추가) D3..D0: decimal 0002..0400 cm; no unit/dot hardware.
        // Invalid/timeout => FND blank, not a misleading '0000'.
        Xil_Out32(P2_02_FND_BASEADDR + FND_VAL_REG, p2_to_bcd4(visible));
        Xil_Out32(P2_02_FND_BASEADDR + FND_CTRL_REG,
                  (sonic_view_fresh && sonic_sample_valid(st,cm)) ? 1U : 0U);
        return;
    }
    // (유지) P2-03 VALUE/EVENTS shown when SONIC OFF.
    Xil_Out32(P2_02_FND_BASEADDR + FND_VAL_REG,
              p2_to_bcd4(p2_visible_decimal(&app)));
    Xil_Out32(P2_02_FND_BASEADDR + FND_CTRL_REG, (u32)app.display_on);
}

static void service_sonic_display(void)
{
    u32 seq = Xil_In32(P2_06_SONIC_BASEADDR + SONIC_SEQ);
    if (seq != sonic_seq_seen) {
        sonic_seq_seen = seq;
        if (sonic_view) { sonic_view_fresh = 1U; fnd_commit(); }
    }
}

// Level interrupt: read PENDING, acknowledge W1C, count each asserted type.
static void btn_irq_handler(void *unused)
{
    u32 pending;
    unsigned i;
    (void)unused;
    pending = Xil_In32(P2_03_BTN_BASEADDR + BTN_PENDING) & 0xFFU;
    if (!pending) return;
    Xil_Out32(P2_03_BTN_BASEADDR + BTN_PENDING, pending); // W1C
    for (i = 0; i < 8U; ++i)
        if (pending & (1U << i)) irq_counts[i]++;
}

/* (추가) 제1부 Timer callback: ISR에서는 출력하지 않고 카운터만 갱신. */
static void timer_callback(void *ref, u8 timer_index)
{
    (void)ref;
    (void)timer_index;
    timer_irq_count++;
}

/* (추가) Classic은 하나의 AXI INTC 인스턴스에 버튼과 Timer를 모두 등록한다.
 * SDT는 실제 BSP의 XSetupInterruptSystem 다중 소스 동작을 확인해야 한다. */
static int setup_integrated_interrupts(void)
{
    int status;
#ifndef SDT
    status = XIntc_Initialize(&intc, P2_03_INTC_DEVICE_ID);
    if (status != XST_SUCCESS) return status;
    status = XIntc_Connect(&intc, P2_03_BTN_INTR_ID,
        (XInterruptHandler)btn_irq_handler, 0);
    if (status != XST_SUCCESS) return status;
    status = XIntc_Connect(&intc, P2_09_TIMER_INTR_ID,
        (XInterruptHandler)XTmrCtr_InterruptHandler, &timer);
    if (status != XST_SUCCESS) return status;
    status = XIntc_Start(&intc, XIN_REAL_MODE);
    if (status != XST_SUCCESS) return status;
    XIntc_Enable(&intc, P2_03_BTN_INTR_ID);
    XIntc_Enable(&intc, P2_09_TIMER_INTR_ID);
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler)XIntc_InterruptHandler, &intc);
    Xil_ExceptionEnable();
#else
    status = XSetupInterruptSystem(0, (void *)btn_irq_handler,
        P2_03_BTN_INTR_ID, (UINTPTR)P2_03_BTN_INTR_PARENT,
        XINTERRUPT_DEFAULT_PRIORITY);
    if (status != XST_SUCCESS) return status;
    status = XSetupInterruptSystem(&timer,
        (void *)XTmrCtr_InterruptHandler,
        timer.Config.IntrId, timer.Config.IntrParent,
        XINTERRUPT_DEFAULT_PRIORITY);
    if (status != XST_SUCCESS) return status;
#endif
    return XST_SUCCESS;
}

/* (추가) Timer의 실제 클록은 BD에서 확인한 값으로 주입한다. */
static int setup_legacy_timer_and_gpio(void)
{
    int status;
#ifndef SDT
    status = XGpio_Initialize(&gpio, P2_09_GPIO_DEVICE_ID);
#else
    status = XGpio_Initialize(&gpio, P2_09_GPIO_BASEADDR);
#endif
    if (status != XST_SUCCESS) return status;
    XGpio_SetDataDirection(&gpio, 1U, 0x00000000U); /* LED 채널 출력 */
    XGpio_DiscreteWrite(&gpio, 1U, 0U); /* 기존 GPIO 상위 출력 초기화 */
#ifndef SDT
    status = XTmrCtr_Initialize(&timer, P2_09_TIMER_DEVICE_ID);
#else
    status = XTmrCtr_Initialize(&timer, P2_09_TIMER_BASEADDR);
#endif
    if (status != XST_SUCCESS) return status;
    XTmrCtr_SetHandler(&timer, timer_callback, &timer);
    XTmrCtr_SetOptions(&timer, TIMER0,
        XTC_DOWN_COUNT_OPTION | XTC_AUTO_RELOAD_OPTION | XTC_INT_MODE_OPTION);
    XTmrCtr_SetResetValue(&timer, TIMER0, TIMER_RESET_VALUE);
    return XST_SUCCESS;
}

/* (추가) LED0~2는 별도 사용자 IP, GPIO는 LED14/15만 구동한다. */
static void service_legacy_gpio_leds(void)
{
    u32 target = (uart_line_activity ? UART_ACTIVITY_LED14 : 0U)
        | ((timer_irq_count & 1U) ? TIMER_HEARTBEAT_LED15 : 0U);
    if (target != led_gpio_shadow) {
        led_gpio_shadow = target;
        XGpio_DiscreteWrite(&gpio, 1U, led_gpio_shadow);
    }
}

static void print_irq_status(void)
{
    unsigned i;
    uart_puts("IRQ TIMER="); uart_dec_u32(timer_irq_count);
    uart_puts(" BTN=");
    for (i=0; i<8U; ++i) {
        if (i) uart_puts(",");
        uart_dec_u32(irq_counts[i]);
    }
    uart_puts(" COALESCED=0x");
    uart_hex32(Xil_In32(P2_03_BTN_BASEADDR + BTN_COALESCED));
    uart_puts(" (non-atomic snapshot)\r\n");
}

/* (추가) MODE AUTO는 모터 재기동 없이 센서 관찰·CdS 게이트만 구성. */
static void enter_auto_mode(void)
{
    if (control_mode == P2_09_AUTO) {
        uart_puts("OK MODE AUTO (already active)\r\n"); return;
    }
    Xil_Out32(P2_07_MOTOR_BASEADDR + MOTOR_CMD_REG, 0U); /* STOP 요청 */
    sonic_seq_seen = Xil_In32(P2_06_SONIC_BASEADDR + SONIC_SEQ);
    sonic_view_fresh = 0U; sonic_auto_enabled=1U; sonic_view=1U;
    sonic_commit_ctrl(); /* 근접 안전 감시는 유지 */
    cds_auto_enabled=1U; cds_commit_control();
    control_mode=P2_09_AUTO;
    fnd_commit();
    uart_puts("OK MODE AUTO: MOTOR STOP REQUESTED; CDS+SONIC ON; FND DIST\r\n");
}

static void enter_manual_mode(void)
{
    /* MANUAL 중 AUTO ON을 직접 켠 경우에도 명시적 MODE MANUAL은 해제. */
    cds_auto_enabled=0U; cds_commit_control();
    sonic_view=0U; sonic_view_fresh=0U; fnd_commit();
    /* 근접 감시를 OFF하지 않는다. MOTOR STOP 요청도 유지된다. */
    control_mode=P2_09_MANUAL;
    uart_puts("OK MODE MANUAL: CDS AUTO OFF; SONIC SAFETY RETAINED\r\n");
}

// (추가) Report command vs physical output separately. Command != rotation.
static void motor_print_status(void)
{
    u32 cmd = Xil_In32(P2_07_MOTOR_BASEADDR + MOTOR_CMD_REG);
    u32 st = Xil_In32(P2_07_MOTOR_BASEADDR + MOTOR_STATUS_REG);
    uart_puts(" MOTOR_REQ="); uart_puts(motor_direction_name(cmd));
    uart_puts(" MOTOR_ACT=");
    uart_puts((st & (1U << 1)) ? "FWD" : ((st & (1U << 2)) ? "REV" : "STOP"));
    uart_puts(" MOTOR_EN="); uart_dec_u32(st & 1U);
    uart_puts(" MOTOR_TRIP="); uart_dec_u32((st >> 3) & 1U);
    uart_puts(" MOTOR_DEADTIME="); uart_dec_u32((st >> 4) & 1U);
    uart_puts(" MOTOR_SAFE="); uart_dec_u32((st >> 5) & 1U);
    uart_puts(" MOTOR_FRESH="); uart_dec_u32((st >> 6) & 1U);
    uart_puts(" MOTOR_AUTO="); uart_dec_u32((st >> 7) & 1U);
    uart_puts(" MOTOR_BLOCKED="); uart_dec_u32((st >> 9) & 1U);
}

static void print_status(void)
{
    u32 led = Xil_In32(P2_01_LED_BASEADDR);
    u32 fnd_bcd = Xil_In32(P2_02_FND_BASEADDR + FND_VAL_REG);
    u32 fnd_ctrl = Xil_In32(P2_02_FND_BASEADDR + FND_CTRL_REG);
    u32 pressed = Xil_In32(P2_03_BTN_BASEADDR + BTN_PRESSED);
    u32 pending = Xil_In32(P2_03_BTN_BASEADDR + BTN_PENDING);
    u32 lost = Xil_In32(P2_03_BTN_BASEADDR + BTN_COALESCED);
    uart_puts("STATUS LED="); uart_puts((led & 1U) ? "ON" : "OFF");
    uart_puts(" REG0=0x"); uart_hex32(led);
    uart_puts(" DISP="); uart_dec4(p2_visible_decimal(&app));
    uart_puts((fnd_ctrl & 1U) ? " ON" : " OFF");
    uart_puts(" MODE="); uart_puts(app.mode ? "EVENTS" : "VALUE");
    uart_puts(" VALUE="); uart_dec4(app.value);
    uart_puts(" EVENTS="); uart_dec4(app.event_count);
    uart_puts(" FND_REG0=0x"); uart_hex32(fnd_bcd);
    uart_puts(" BTN_PRESSED=0x"); uart_hex32(pressed);
    uart_puts(" BTN_PENDING=0x"); uart_hex32(pending);
    uart_puts(" COALESCED=0x"); uart_hex32(lost);
    // (추가) 03장 STATUS 전체를 유지하고 PWM 상태를 뒤에 추가.
    {
        u32 flags = Xil_In32(P2_04_PWM_BASEADDR + PWM_STATUS);
        u32 p = Xil_In32(P2_04_PWM_BASEADDR + PWM_PERIOD_ACT);
        u32 d = Xil_In32(P2_04_PWM_BASEADDR + PWM_DUTY_ACT);
        u32 pct = p ? (u32)(((uint64_t)d * 100U) / p) : 0U;
        uart_puts(" PWM_SET="); uart_dec_u32(pwm_requested_percent);
        uart_puts("% PWM_ACTIVE="); uart_dec_u32(pct);
        uart_puts("% PWM_PENDING="); uart_puts((flags & 1U) ? "1" : "0");
        uart_puts(" PWM_ENABLE="); uart_puts((flags & (1U << 8)) ? "1" : "0");
        uart_puts(" PWM_LED=1");
    }
    // (추가) Append CdS state without removing 04 status fields.
    {
        u32 bits = Xil_In32(P2_05_CDS_BASEADDR + CDS_STATUS);
        uart_puts(" CDS_RAW="); uart_dec_u32(bits & 1U);
        uart_puts(" CDS_DARK="); uart_dec_u32((bits >> 1) & 1U);
        uart_puts(" CDS_VALID="); uart_dec_u32((bits >> 2) & 1U);
        uart_puts(" CDS_GATE="); uart_dec_u32((bits >> 3) & 1U);
        uart_puts(" CDS_AUTO="); uart_dec_u32((bits >> 4) & 1U);
        uart_puts(" CDS_POL="); uart_puts((bits & (1U << 5)) ? "LOW" : "HIGH");
    }
    // (추가) Append 06 status fields; do not remove 01~05 fields.
    {
        u32 st, cm, seq;
        sonic_read_state(&st,&cm,&seq);
        uart_puts(" SONIC_VIEW="); uart_puts(sonic_view ? "DIST" : "VALUE/EVENTS");
        uart_puts(" SONIC_CM="); uart_dec_u32(cm);
        uart_puts(" SONIC_VALID="); uart_dec_u32((st >> 1) & 1U);
        uart_puts(" SONIC_TIMEOUT="); uart_dec_u32((st >> 2) & 1U);
        uart_puts(" SONIC_RANGE="); uart_dec_u32((st >> 3) & 1U);
        uart_puts(" SONIC_ALERT="); uart_dec_u32((st >> 4) & 1U);
        uart_puts(" SONIC_UNSAFE="); uart_dec_u32((st >> 5) & 1U);
        uart_puts(" SONIC_SEQ="); uart_dec_u32(seq);
    }
    // (추가) 07장 상태 필드; 01~06장 내용 삭제 금지.
    motor_print_status();
    // (추가) 제1부~07장의 모든 STATUS 필드를 보존하고 XADC를 덧붙인다.
    {
        uint16_t raw = adc_sample_raw12();
        uart_puts(" ADC_RAW="); uart_dec_u32(raw);
        uart_puts(" ADC_MV="); uart_dec_u32(adc_millivolts_from_raw(raw));
        uart_puts(" ADC_PWM_LAST=");
        if (adc_apply_seen) uart_dec_u32(adc_last_applied);
        else uart_puts("NONE");
        uart_puts(" ADC_FRESH=UNVERIFIED");
    }
    /* (추가) 기존 출력 필드 삭제 없이 09장 통합 상태를 덧붙인다. */
    uart_puts(" CTRL_MODE="); uart_puts(p2_09_mode_name(control_mode));
    uart_puts(" IRQ_TIMER="); uart_dec_u32(timer_irq_count);
    uart_puts(" LED14_ACTIVITY="); uart_dec_u32(uart_line_activity);
    uart_puts(" LED15_HEARTBEAT="); uart_dec_u32(timer_irq_count & 1U);
    uart_puts("\r\n");
}

static void handle_line(const char *line)
{
    uint16_t value = 0;
    u8 pwm_percent = 0U;
    /* (추가) MODE/IRQ 문자열을 기존 파서보다 먼저 처리한다. */
    P2_09_Command integrated_cmd = p2_09_parse_command(line);
    switch (integrated_cmd) {
    case P2_09_MODE_AUTO: enter_auto_mode(); return;
    case P2_09_MODE_MANUAL: enter_manual_mode(); return;
    case P2_09_MODE_STATUS:
        uart_puts("MODE="); uart_puts(p2_09_mode_name(control_mode));
        uart_puts(" CDS_AUTO="); uart_dec_u32(cds_auto_enabled);
        uart_puts(" SONIC_AUTO="); uart_dec_u32(sonic_auto_enabled);
        uart_puts(" MOTOR_REQ=");
        uart_puts(motor_direction_name(Xil_In32(P2_07_MOTOR_BASEADDR+MOTOR_CMD_REG)));
        uart_puts(" (actual motor state: MOTOR STATUS)\r\n"); return;
    case P2_09_IRQ_STATUS: print_irq_status(); return;
    case P2_09_MODE_INVALID: uart_puts("ERROR: MODE AUTO | MODE MANUAL | MODE STATUS\r\n"); return;
    case P2_09_IRQ_INVALID: uart_puts("ERROR: IRQ STATUS\r\n"); return;
    default: break;
    }
    if (control_mode == P2_09_AUTO && !p2_09_allowed_in_auto(line)) {
        uart_puts("BLOCKED: MODE AUTO safety; use MODE MANUAL first\r\n");
        return;
    }
    // (추가) 08장 ADC READ / ADC PWM 명령은 기존 명령과 독립적으로 파싱.
    AdcCommand adc_cmd = adc_parse_command(line);
    if (adc_cmd != ADC_NOT_COMMAND) {
        if (adc_cmd == ADC_READ) {
            adc_print_reading();
        } else if (adc_cmd == ADC_PWM) {
            uint16_t raw = adc_sample_raw12();
            u8 percent = adc_percent_from_raw(raw);
            // (추가) 실제 모터 PWM이나 보호 RTL은 변경하지 않는다.
            if (!pwm_queue_percent(percent)) {
                uart_puts("BUSY: previous PWM update pending; retry ADC PWM\r\n");
            } else {
                adc_last_applied = percent;
                adc_apply_seen = 1U;
                uart_puts("OK ADC PWM "); uart_dec_u32(percent);
                uart_puts("% QUEUED (LED1; next PWM period)\r\n");
            }
        } else {
            uart_puts("ERROR: ADC READ | ADC PWM\r\n");
        }
        return;
    }
    MotorCommand motor_cmd = motor_parse_command(line);
    if (motor_cmd != MOTOR_NOT_COMMAND) {
        switch (motor_cmd) {
        case MOTOR_STOP:
            // (추가) STOP always accepted, even when sensor is unsafe.
            // Also clears a latched trip; restart requires new FWD/REV.
            Xil_Out32(P2_07_MOTOR_BASEADDR + MOTOR_CMD_REG, 0U);
            uart_puts("OK MOTOR STOP REQUESTED\r\n");
            break;
        case MOTOR_FWD:
        case MOTOR_REV: {
            u32 st = Xil_In32(P2_07_MOTOR_BASEADDR + MOTOR_STATUS_REG);
            if ((st & (1U << 5)) == 0U || (st & (1U << 3)) != 0U) {
                uart_puts("BLOCKED: SONIC AUTO + fresh safe distance required; "
                          "after TRIP use MOTOR STOP\r\n");
            } else {
                Xil_Out32(P2_07_MOTOR_BASEADDR + MOTOR_CMD_REG,
                          motor_cmd == MOTOR_FWD ? 1U : 2U);
                uart_puts("OK MOTOR REQUESTED ");
                uart_puts(motor_cmd == MOTOR_FWD ? "FWD" : "REV");
                uart_puts(" (check MOTOR STATUS for physical output)\r\n");
            }
            break;
        }
        case MOTOR_STATUS:
            uart_puts("MOTOR STATUS"); motor_print_status(); uart_puts("\r\n");
            break;
        default:
            uart_puts("ERROR: MOTOR FWD | MOTOR REV | MOTOR STOP | MOTOR STATUS\r\n");
            break;
        }
        return;
    }
    // (추가) SONIC / WARN commands are parsed before legacy commands.
    uint16_t warn_cm=0U;
    SonicCommand sonic_cmd = sonic_parse_command(line,&warn_cm);
    CdsCommand cds_cmd = cds_parse_command(line);
    PwmParseResult pwm_cmd = pwm_parse_command(line, &pwm_percent);
    P2Command cmd;
    if (sonic_cmd != SONIC_NOT_COMMAND) {
        switch (sonic_cmd) {
        case SONIC_ON:
            sonic_seq_seen = Xil_In32(P2_06_SONIC_BASEADDR + SONIC_SEQ);
            sonic_view_fresh=0U; sonic_auto_enabled=1U; sonic_view=1U;
            sonic_commit_ctrl(); fnd_commit();
            uart_puts("OK SONIC ON (FND DIST cm)\r\n"); break;
        case SONIC_OFF:
            sonic_auto_enabled=0U; sonic_view=0U; sonic_view_fresh=0U;
            sonic_commit_ctrl(); fnd_commit();
            uart_puts("OK SONIC OFF (FND VALUE/EVENTS restored)\r\n"); break;
        case SONIC_READ: sonic_print_reading(); break;
        case SONIC_SHOT:
            if (sonic_auto_enabled ||
                ((Xil_In32(P2_06_SONIC_BASEADDR + SONIC_STATUS) >> 8) & 1U)==0U) {
                uart_puts("BUSY: SONIC SHOT unavailable; retry or SONIC OFF\r\n");
            } else {
                // W1P START bit1; preserve WARN_EN bit2, AUTO remains off.
                Xil_Out32(P2_06_SONIC_BASEADDR + SONIC_CTRL,
                          ((u32)sonic_warn_enabled << 2) | 2U);
                uart_puts("OK SONIC SHOT QUEUED; use SONIC READ\r\n");
            }
            break;
        case SONIC_WARN_CM:
            Xil_Out32(P2_06_SONIC_BASEADDR + SONIC_WARN_CFG, warn_cm);
            sonic_warn_enabled=1U; sonic_commit_ctrl();
            uart_puts("OK WARN ");uart_dec_u32(warn_cm);uart_puts(" CM\r\n"); break;
        case SONIC_WARN_OFF:
            sonic_warn_enabled=0U; sonic_commit_ctrl();
            uart_puts("OK WARN OFF (UNSAFE status remains active)\r\n"); break;
        default: uart_puts("ERROR: SONIC ON/OFF/READ/SHOT | WARN 1..400/OFF\r\n");
        }
        return;
    }
    if (cds_cmd != CDS_NOT_COMMAND) {
        switch (cds_cmd) {
        case CDS_AUTO_ON:
            cds_auto_enabled=1U; cds_commit_control();
            uart_puts("OK AUTO ON (PWM duty retained)\r\n"); break;
        case CDS_AUTO_OFF:
            cds_auto_enabled=0U; cds_commit_control();
            uart_puts("OK AUTO OFF (PWM manual)\r\n"); break;
        case CDS_POL_LOW:
            cds_dark_when_low=1U; cds_commit_control();
            uart_puts("OK CDS POL LOW\r\n"); break;
        case CDS_POL_HIGH:
            cds_dark_when_low=0U; cds_commit_control();
            uart_puts("OK CDS POL HIGH\r\n"); break;
        case CDS_READ:
            cds_print_reading(); break;
        default:
            uart_puts("ERROR: AUTO ON | AUTO OFF | CDS READ | CDS POL LOW | CDS POL HIGH\r\n");
            break;
        }
        return;
    }
    if (pwm_cmd != PWM_NOT_COMMAND) {
        if (pwm_cmd == PWM_INVALID) {
            uart_puts("ERROR: PWM 0..100 (decimal, no leading zeroes)\r\n");
        } else if (!pwm_queue_percent(pwm_percent)) {
            uart_puts("BUSY: previous PWM update pending; retry\r\n");
        } else {
            uart_puts("OK PWM "); uart_dec_u32(pwm_percent);
            uart_puts(" QUEUED\r\n"); // 실제 출력은 다음 주기 경계에서 반영됨.
        }
        return;
    }
    cmd = p2_parse_command(line, &value);
    switch (cmd) {
    case P2_CMD_LED_ON:
        Xil_Out32(P2_01_LED_BASEADDR, 1U);
        uart_puts("OK LED ON\r\n"); break;
    case P2_CMD_LED_OFF:
        Xil_Out32(P2_01_LED_BASEADDR, 0U);
        uart_puts("OK LED OFF\r\n"); break;
    case P2_CMD_DISP_VALUE:
        p2_set_disp(&app, value); fnd_commit();
        uart_puts("OK DISP "); uart_dec4(value); uart_puts("\r\n"); break;
    case P2_CMD_DISP_OFF:
        app.display_on = 0; fnd_commit(); uart_puts("OK DISP OFF\r\n"); break;
    case P2_CMD_STATUS:
        print_status(); break;
    default:
        uart_puts("ERROR: ADC READ/PWM | MOTOR FWD/REV/STOP/STATUS | LED ON/OFF | DISP dddd/OFF | PWM 0..100 | AUTO ON/OFF | CDS READ/POL | SONIC ON/OFF/READ/SHOT | WARN 1..400/OFF | STATUS\r\n");
    }
}

static void poll_uart(void)
{
    static char line[LINE_CAP];
    static u32 used = 0;
    static int invalid = 0;
    static int overflow = 0;
    u8 ch;
    if (XUartLite_IsReceiveEmpty(UART_BASEADDR)) return;
    ch = XUartLite_RecvByte(UART_BASEADDR);
    if (ch == '\r' || ch == '\n') {
        line[used] = '\0';
        if (overflow) uart_puts("ERROR: line too long\r\n");
        else if (invalid) uart_puts("ERROR: invalid ASCII\r\n");
        else if (used) handle_line(line);
        /* (추가) Enter로 완성된 명령 행이 있을 때 LED14 활동 비트 반전. */
        if (used || overflow || invalid) uart_line_activity ^= 1U;
        used = 0; overflow = 0; invalid = 0;
        return; // CRLF second terminator is ignored.
    }
    if (ch < 0x20U || ch > 0x7EU) { invalid = 1; return; }
    if (used < LINE_CAP-1U) line[used++] = (char)ch;
    else overflow = 1;
}

static void service_button_events(void)
{
    unsigned i;
    for (i = 0; i < 8U; ++i) {
        // Each 32-bit read is atomic on the target 32-bit CPU. ISR only increments.
        u32 seen = irq_counts[i];
        while (handled_counts[i] != seen) {
            handled_counts[i]++;
            p2_apply_button(&app, i);
            fnd_commit();
        }
    }
}

int main(void)
{
    int status;
    unsigned i;
    p2_init(&app);
    for (i=0; i<8U; ++i) { irq_counts[i]=0U; handled_counts[i]=0U; }
    Xil_Out32(P2_03_BTN_BASEADDR + BTN_ENABLE, 0U); // Mask IRQ while setting up.
    Xil_Out32(P2_03_BTN_BASEADDR + BTN_PENDING, 0xFFU); // Clear stale events.
    Xil_Out32(P2_03_BTN_BASEADDR + BTN_COALESCED, 0xFFU); // Clear stale loss flags.
    if (Xil_In32(P2_03_BTN_BASEADDR + BTN_ID) != 0x00030001U) {
        uart_puts("ERROR: button IP identity mismatch\r\n"); return XST_FAILURE;
    }
    // (추가) P2-05 identity check BEFORE enabling automatic operation.
    if (Xil_In32(P2_05_CDS_BASEADDR + CDS_IP_ID) != CDS_EXPECTED_ID) {
        uart_puts("ERROR: CdS IP identity mismatch\r\n");
        return XST_FAILURE;
    }
    cds_auto_enabled = 0U; cds_dark_when_low = 1U;
    cds_commit_control(); // Power-on always begins in manual bypass mode.
    // (추가) Motor hardware boot state: STOP before configuring other devices.
    if (Xil_In32(P2_07_MOTOR_BASEADDR + MOTOR_ID_REG) != MOTOR_EXPECTED_ID) {
        uart_puts("ERROR: motor IP identity mismatch\r\n");
        return XST_FAILURE;
    }
    Xil_Out32(P2_07_MOTOR_BASEADDR + MOTOR_CMD_REG, 0U);
    // (추가) Validate 06 IP before enabling a continuous trigger.
    if (Xil_In32(P2_06_SONIC_BASEADDR + SONIC_ID) != SONIC_EXPECTED_ID) {
        uart_puts("ERROR: HC-SR04 IP identity mismatch\r\n");
        return XST_FAILURE;
    }
    sonic_auto_enabled=0U; sonic_warn_enabled=1U; sonic_view=0U; sonic_view_fresh=0U;
    Xil_Out32(P2_06_SONIC_BASEADDR + SONIC_WARN_CFG, 20U);
    sonic_commit_ctrl();
    sonic_seq_seen=Xil_In32(P2_06_SONIC_BASEADDR + SONIC_SEQ);
    // (추가) IP ID를 확인하고 시작할 때 PWM OFF를 예약.
    if (Xil_In32(P2_04_PWM_BASEADDR + PWM_ID) != PWM_IP_ID) {
        uart_puts("ERROR: PWM IP identity mismatch\r\n");
        return XST_FAILURE;
    }
    Xil_Out32(P2_04_PWM_BASEADDR + PWM_PERIOD_CFG, PWM_PERIOD_TICKS);
    Xil_Out32(P2_04_PWM_BASEADDR + PWM_DUTY_CFG, 0U);
    Xil_Out32(P2_04_PWM_BASEADDR + PWM_CTRL_CFG, 0U);
    Xil_Out32(P2_04_PWM_BASEADDR + PWM_APPLY, 1U);
    fnd_commit();
    /* (추가) 기존 GPIO LED14/15와 Timer 준비 후 IRQ 공유 연결. */
    status = setup_legacy_timer_and_gpio();
    if (status != XST_SUCCESS) {
        uart_puts("ERROR: legacy GPIO/Timer init failed\r\n");
        return XST_FAILURE;
    }
    status = setup_integrated_interrupts();
    if (status != XST_SUCCESS) {
        uart_puts("ERROR: interrupt initialization failed\r\n");
        return XST_FAILURE;
    }
    Xil_Out32(P2_03_BTN_BASEADDR + BTN_ENABLE, 0xFFU);
    XTmrCtr_Start(&timer, TIMER0); /* (추가) IRQ 연결 후 0.5초 Tick 시작. */
    uart_puts("P2-09: UART/IRQ + MODE AUTO/MANUAL integrated\r\n");
    uart_puts("UART: MODE AUTO/MANUAL/STATUS | IRQ STATUS | ADC READ/PWM | MOTOR FWD/REV/STOP/STATUS | SONIC ON/OFF/READ/SHOT | WARN 1..400/OFF | LED ON/OFF | DISP 1234/OFF | PWM 0..100 | AUTO ON/OFF | CDS READ/POL LOW/HIGH | STATUS\r\n");
    while (1) {
        poll_uart(); // Non-blocking: do not starve event processing.
        service_button_events();
        service_sonic_display(); // (유지) FND 거리의 최신 완료 샘플 반영.
        service_legacy_gpio_leds(); // (추가) LED14 활동·LED15 타이머 표시.
    }
}
