/* P2-05: retain P2-01~04 and gate PWM LED1 with filtered CdS DO.
 * NOTE: Base addresses, Interrupt ID/Parent MUST be read from actual BSP.
 * This source intentionally rejects unknown constants before target build.
 */
#include "xparameters.h"
#include "xil_types.h"      /* u8, u32, UINTPTR */
#include "xil_io.h"         /* Xil_In32, Xil_Out32 */
#include "xuartlite_l.h"    /* UART Lite byte functions + FIFO empty check */
#include "xstatus.h"
#include "xil_exception.h"
#ifdef SDT
#include "xinterrupt_wrap.h" /* SDT interrupt API */
#else
#include "xintc.h"          /* Classic interrupt controller API */
#endif
#include "p2_03_logic.h"
#include "p2_04_pwm_logic.h" // Reused 04 PWM parser / duty calculation
#include "p2_05_cds_logic.h" // (추가) Reusable AUTO/CDS command parser

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
#if P2_05_CDS_BASEADDR == P2_01_LED_BASEADDR || \
    P2_05_CDS_BASEADDR == P2_02_FND_BASEADDR || \
    P2_05_CDS_BASEADDR == P2_03_BTN_BASEADDR || \
    P2_05_CDS_BASEADDR == P2_04_PWM_BASEADDR
#error "P2-05 CdS IP base address must differ from P2-01~04"
#endif
#define LINE_CAP     32U

static P2AppState app;
static u8 pwm_requested_percent = 0U;
// (추가) The C application owns control policy; RTL filters raw CdS signal.
static u8 cds_auto_enabled = 0U;
static u8 cds_dark_when_low = 1U; // Start assumption; verify DO via CDS READ.

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

static void fnd_commit(void)
{
    // P2-02: REG0 BCD digits, REG1 bit0 enable. No software scan loops.
    Xil_Out32(P2_02_FND_BASEADDR + FND_VAL_REG,
              p2_to_bcd4(p2_visible_decimal(&app)));
    Xil_Out32(P2_02_FND_BASEADDR + FND_CTRL_REG, (u32)app.display_on);
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

static int setup_button_interrupt(void)
{
    int status;
#ifdef SDT
    // The physical interrupt ID and parent are project-specific.
    status = XSetupInterruptSystem(0, (void *)btn_irq_handler,
        P2_03_BTN_INTR_ID, (UINTPTR)P2_03_BTN_INTR_PARENT,
        XINTERRUPT_DEFAULT_PRIORITY);
#else
    status = XIntc_Initialize(&intc, P2_03_INTC_DEVICE_ID);
    if (status != XST_SUCCESS) return status;
    status = XIntc_Connect(&intc, P2_03_BTN_INTR_ID,
        (XInterruptHandler)btn_irq_handler, 0);
    if (status != XST_SUCCESS) return status;
    status = XIntc_Start(&intc, XIN_REAL_MODE);
    if (status != XST_SUCCESS) return status;
    XIntc_Enable(&intc, P2_03_BTN_INTR_ID);
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler)XIntc_InterruptHandler, &intc);
    Xil_ExceptionEnable();
#endif
    return status;
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
    uart_puts("\r\n");
}

static void handle_line(const char *line)
{
    uint16_t value = 0;
    u8 pwm_percent = 0U;
    // (추가) AUTO/CDS commands are recognized before existing PWM/LED/DISP.
    CdsCommand cds_cmd = cds_parse_command(line);
    PwmParseResult pwm_cmd = pwm_parse_command(line, &pwm_percent);
    P2Command cmd;
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
        uart_puts("ERROR: LED ON/OFF | DISP dddd/OFF | PWM 0..100 | AUTO ON/OFF | CDS READ/POL LOW/POL HIGH | STATUS\r\n");
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
    status = setup_button_interrupt();
    if (status != XST_SUCCESS) {
        uart_puts("ERROR: interrupt initialization failed\r\n");
        return XST_FAILURE;
    }
    Xil_Out32(P2_03_BTN_BASEADDR + BTN_ENABLE, 0xFFU);
    uart_puts("P2-05: Digital CdS AUTO gate + PWM LED1 + BUTTON IRQ + FND + LED0\r\n");
    uart_puts("UART: LED ON/OFF | DISP 1234/OFF | PWM 0..100 | AUTO ON/OFF | CDS READ/POL LOW/POL HIGH | STATUS\r\n");
    while (1) {
        poll_uart(); // Non-blocking: do not starve event processing.
        service_button_events();
    }
}
