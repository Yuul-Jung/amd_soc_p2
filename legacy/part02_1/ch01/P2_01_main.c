/* P2-01: UART 문자열 명령으로 사용자 AXI IP의 LED0를 제어한다. */
#include "xparameters.h"   /* Vitis BSP의 하드웨어 주소 정의 */
#include "xil_types.h"     /* u8(8비트), u32(32비트) 자료형 */
#include "xil_io.h"        /* Xil_In32(), Xil_Out32() */
#include "xuartlite_l.h"   /* XUartLite_RecvByte(), SendByte() */
#include <string.h>        /* strcmp(): 두 문자열 비교 */

/* (필수 수정) Vivado Address Editor의 사용자 IP 주소를 입력한다. */
#ifndef USER_IP_BASEADDR
#define USER_IP_BASEADDR   0xFFFFFFFFU
#endif
#if USER_IP_BASEADDR == 0xFFFFFFFFU
#error "USER_IP_BASEADDR를 실제 Vivado AXI IP Base Address로 수정하세요"
#endif

#define LED_REG_OFFSET    0x00U  /* slv_reg0: bit0가 LED0 출력 */
#define LINE_CAPACITY     32U    /* 최대 31문자 + 종료문자 */

/* 제1부에서 사용한 AXI UART Lite를 재사용한다. */
#if defined(XPAR_XUARTLITE_0_BASEADDR)
#define UART_BASEADDR XPAR_XUARTLITE_0_BASEADDR
#elif defined(XPAR_UARTLITE_0_BASEADDR)
#define UART_BASEADDR XPAR_UARTLITE_0_BASEADDR
#elif defined(XPAR_AXI_UARTLITE_0_BASEADDR)
#define UART_BASEADDR XPAR_AXI_UARTLITE_0_BASEADDR
#else
#error "xparameters.h에서 UART Lite BASEADDR 매크로를 확인하세요"
#endif

/* 문자열의 각 문자를 UART로 보낸다. */
static void uart_puts(const char *text)
{
    while (*text != '\0') {  /* '\0': 문자열의 끝 */
        XUartLite_SendByte(UART_BASEADDR, (u8)*text);
        text++;
    }
}

/* u32 값을 8자리 16진수 문자열로 출력한다. */
static void uart_hex32(u32 value)
{
    const char digits[] = "0123456789ABCDEF";
    int shift;
    for (shift = 28; shift >= 0; shift -= 4) {
        u8 nibble = (u8)((value >> shift) & 0x0FU);
        XUartLite_SendByte(UART_BASEADDR, (u8)digits[nibble]);
    }
}

/* REG0 읽기값에서 LED0 상태를 해석해 출력한다. */
static void report_status(const char *prefix)
{
    u32 value = Xil_In32(USER_IP_BASEADDR + LED_REG_OFFSET);
    uart_puts(prefix);
    uart_puts((value & 1U) ? "LED=ON REG0=0x" : "LED=OFF REG0=0x");
    uart_hex32(value);
    uart_puts("\r\n");
}

/* Enter까지 입력받는다. 반환: 1=명령, 0=빈 줄, -1=초과, -2=제어문자. */
static int read_command_line(char *line, u32 capacity)
{
    u32 used = 0U;
    int overflow = 0;
    int invalid = 0;  /* NUL 등 제어문자 포함 명령 거부 */
    while (1) {
        u8 ch = XUartLite_RecvByte(UART_BASEADDR); /* 1바이트 대기 수신 */
        if (ch == (u8)'\r' || ch == (u8)'\n') {
            line[used] = '\0';       /* 항상 문자열을 종료한다. */
            if (overflow) return -1; /* 버퍼 밖에 쓰지 않는다. */
            if (invalid) return -2;  /* 제어문자가 포함되면 거부 */
            return used ? 1 : 0;
        }
        if (ch < (u8)0x20U || ch > (u8)0x7EU) {
            invalid = 1;  /* 출력 가능한 ASCII만 허용 */
            continue;
        }
        if (used < capacity - 1U) {
            line[used++] = (char)ch;
        } else {
            overflow = 1; /* Enter 전까지 초과 문자를 버린다. */
        }
    }
}

/* 문자열을 비교한 후 AXI 레지스터에 기록하거나 읽는다. */
static void handle_command(const char *line)
{
    if (strcmp(line, "LED ON") == 0) {
        Xil_Out32(USER_IP_BASEADDR + LED_REG_OFFSET, 1U);
        report_status("OK ");
    } else if (strcmp(line, "LED OFF") == 0) {
        Xil_Out32(USER_IP_BASEADDR + LED_REG_OFFSET, 0U);
        report_status("OK ");
    } else if (strcmp(line, "STATUS") == 0) {
        report_status("STATUS ");
    } else {
        uart_puts("ERROR: use LED ON / LED OFF / STATUS\r\n");
    }
}

int main(void)
{
    char line[LINE_CAPACITY]; /* ASCII 명령을 저장할 문자 배열 */
    int result;
    uart_puts("\r\nP2-01 AXI LED CONTROL\r\n");
    uart_puts("Commands: LED ON | LED OFF | STATUS (Enter)\r\n");
    report_status("STATUS ");

    while (1) {
        result = read_command_line(line, LINE_CAPACITY);
        if (result > 0) {
            handle_command(line);
        } else if (result == -2) {
            uart_puts("ERROR: invalid character\r\n");
        } else if (result < 0) {
            uart_puts("ERROR: command too long (max 31)\r\n");
        }
        /* 빈 줄 및 CRLF의 두 번째 줄바꿈은 무시한다. */
    }
}
