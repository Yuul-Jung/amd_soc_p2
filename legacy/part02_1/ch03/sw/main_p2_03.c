/* P2-03: UART string commands + four directional buttons via AXI interrupt.
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
#define LINE_CAP     32U

static P2AppState app;
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
    uart_puts("\r\n");
}

static void handle_line(const char *line)
{
    uint16_t value = 0;
    P2Command cmd = p2_parse_command(line, &value);
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
        uart_puts("ERROR: LED ON | LED OFF | DISP dddd | DISP OFF | STATUS\r\n");
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
    fnd_commit();
    status = setup_button_interrupt();
    if (status != XST_SUCCESS) {
        uart_puts("ERROR: interrupt initialization failed\r\n");
        return XST_FAILURE;
    }
    Xil_Out32(P2_03_BTN_BASEADDR + BTN_ENABLE, 0xFFU);
    uart_puts("P2-03: BUTTON SHORT/LONG + IRQ\r\n");
    uart_puts("UART: LED ON | LED OFF | DISP 1234 | DISP OFF | STATUS\r\n");
    while (1) {
        poll_uart(); // Non-blocking: do not starve event processing.
        service_button_events();
    }
}
