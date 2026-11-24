/* P2-02: UART string commands -> P2-01 LED IP + P2-02 FND IP. */
#include "xparameters.h"  /* Actual address constants from Vitis BSP */
#include "xil_types.h"    /* u8 and u32 fixed-width Xilinx types */
#include "xil_io.h"       /* Xil_In32 / Xil_Out32: memory-mapped I/O */
#include "xuartlite_l.h"  /* XUartLite_RecvByte / SendByte */
#include <string.h>       /* strcmp, memcmp, strlen */

/* Fill from CURRENT Address Editor/BSP; never guess physical addresses. */
#ifndef USER_IP_BASEADDR
#define USER_IP_BASEADDR 0xFFFFFFFFU
#endif
#ifndef FND_IP_BASEADDR
#define FND_IP_BASEADDR 0xFFFFFFFFU
#endif
#if USER_IP_BASEADDR == 0xFFFFFFFFU
#error "Set USER_IP_BASEADDR to the P2-01 AXI LED Base Address"
#endif
#if FND_IP_BASEADDR == 0xFFFFFFFFU
#error "Set FND_IP_BASEADDR to the P2-02 AXI FND Base Address"
#endif
#if USER_IP_BASEADDR == FND_IP_BASEADDR
#error "AXI LED and AXI FND Base Addresses must be different"
#endif

#define LED_REG0       0x00U  /* P2-01 LED bit0 */
#define FND_VALUE_REG  0x00U  /* P2-02 four packed BCD digits */
#define FND_CTRL_REG   0x04U  /* P2-02 bit0: display enable */
#define LINE_CAPACITY  32U    /* at most 31 ASCII characters + NUL */

#if defined(XPAR_XUARTLITE_0_BASEADDR)
#define UART_BASEADDR XPAR_XUARTLITE_0_BASEADDR
#elif defined(XPAR_UARTLITE_0_BASEADDR)
#define UART_BASEADDR XPAR_UARTLITE_0_BASEADDR
#elif defined(XPAR_AXI_UARTLITE_0_BASEADDR)
#define UART_BASEADDR XPAR_AXI_UARTLITE_0_BASEADDR
#else
#error "Find the UART Lite BASEADDR macro in generated xparameters.h"
#endif

/* Send a NUL-terminated string through the existing UART Lite. */
static void uart_puts(const char *text)
{
    while (*text != '\0') {
        XUartLite_SendByte(UART_BASEADDR, (u8)*text);
        text++;
    }
}

/* Print a 32-bit unsigned value as exactly eight hex digits. */
static void uart_hex32(u32 value)
{
    const char digits[] = "0123456789ABCDEF";
    int shift;
    for (shift = 28; shift >= 0; shift -= 4) {
        u8 nibble = (u8)((value >> shift) & 0x0FU);
        XUartLite_SendByte(UART_BASEADDR, (u8)digits[nibble]);
    }
}

/* Low four BCD nibbles map to digits from left to right. */
static void uart_bcd4(u32 packed)
{
    int shift;
    for (shift = 12; shift >= 0; shift -= 4) {
        u8 digit = (u8)((packed >> shift) & 0x0FU);
        XUartLite_SendByte(UART_BASEADDR,
            (u8)((digit <= 9U) ? ('0' + digit) : '?'));
    }
}

static void report_led(const char *prefix)
{
    u32 value = Xil_In32(USER_IP_BASEADDR + LED_REG0);
    uart_puts(prefix);
    uart_puts((value & 1U) ? "LED=ON REG0=0x" : "LED=OFF REG0=0x");
    uart_hex32(value);
    uart_puts("\r\n");
}

static void report_fnd(const char *prefix)
{
    u32 digits = Xil_In32(FND_IP_BASEADDR + FND_VALUE_REG);
    u32 ctrl = Xil_In32(FND_IP_BASEADDR + FND_CTRL_REG);
    uart_puts(prefix);
    uart_puts((ctrl & 1U) ? "DISP=" : "DISP=OFF VALUE=");
    uart_bcd4(digits);
    uart_puts(" REG0=0x");
    uart_hex32(digits);
    uart_puts(" REG1=0x");
    uart_hex32(ctrl);
    uart_puts("\r\n");
}

/* 1=valid line; 0=empty; -1=overflow; -2=nonprintable ASCII. */
static int read_command_line(char *line, u32 capacity)
{
    u32 used = 0U;
    int overflow = 0;
    int invalid = 0;
    while (1) {
        u8 ch = XUartLite_RecvByte(UART_BASEADDR);
        if (ch == (u8)'\r' || ch == (u8)'\n') {
            line[used] = '\0';
            if (overflow) return -1;
            if (invalid) return -2;
            return used ? 1 : 0;
        }
        if (ch < (u8)0x20U || ch > (u8)0x7EU) {
            invalid = 1;
            continue;
        }
        if (used < capacity - 1U) {
            line[used++] = (char)ch;
        } else {
            overflow = 1;
        }
    }
}

/* Require exactly 4 decimal digits: "DISP 0050" -> 0x0050. */
static int parse_disp_digits(const char *line, u32 *packed)
{
    u32 bcd = 0U;
    int i;
    if (strlen(line) != 9U || memcmp(line, "DISP ", 5U) != 0)
        return 0;
    for (i = 5; i < 9; ++i) {
        if (line[i] < '0' || line[i] > '9') return 0;
        bcd = (bcd << 4) | (u32)(line[i] - '0');
    }
    *packed = bcd;
    return 1;
}

static void handle_command(const char *line)
{
    u32 packed = 0U;
    if (strcmp(line, "LED ON") == 0) {
        Xil_Out32(USER_IP_BASEADDR + LED_REG0, 1U);
        report_led("OK ");
    } else if (strcmp(line, "LED OFF") == 0) {
        Xil_Out32(USER_IP_BASEADDR + LED_REG0, 0U);
        report_led("OK ");
    } else if (strcmp(line, "STATUS") == 0) {
        report_led("STATUS ");
        report_fnd("STATUS ");
    } else if (strcmp(line, "DISP OFF") == 0) {
        Xil_Out32(FND_IP_BASEADDR + FND_CTRL_REG, 0U);
        report_fnd("OK ");
    } else if (parse_disp_digits(line, &packed)) {
        Xil_Out32(FND_IP_BASEADDR + FND_VALUE_REG, packed);
        Xil_Out32(FND_IP_BASEADDR + FND_CTRL_REG, 1U);
        report_fnd("OK ");
    } else {
        uart_puts("ERROR: LED ON / LED OFF / DISP dddd / DISP OFF / STATUS\r\n");
    }
}

int main(void)
{
    char line[LINE_CAPACITY];
    int result;
    uart_puts("\r\nP2-02 AXI FND CONTROL\r\n");
    uart_puts("Commands: LED ON | LED OFF | DISP 1234 | DISP 0050 | DISP OFF | STATUS\r\n");
    report_led("STATUS ");
    report_fnd("STATUS ");

    while (1) {
        result = read_command_line(line, LINE_CAPACITY);
        if (result > 0) {
            handle_command(line);
        } else if (result == -2) {
            uart_puts("ERROR: invalid character\r\n");
        } else if (result < 0) {
            uart_puts("ERROR: command too long (max 31)\r\n");
        }
        /* Empty CR/LF lines are ignored (also handles CRLF terminals). */
    }
}
