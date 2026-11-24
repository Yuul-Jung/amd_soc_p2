#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "xil_types.h"
#include "xuartlite_l.h"
#include "xil_io.h"

static u32 led_value = 0U;
static u32 fnd_value = 0U;
static u32 fnd_ctrl = 0U;

u8 XUartLite_RecvByte(uintptr_t address)
{
    int ch;
    if (address != 0x40600000U) abort();
    ch = getchar();
    if (ch == EOF) { fflush(stdout); exit(0); }
    return (u8)ch;
}
void XUartLite_SendByte(uintptr_t address, u8 data)
{
    if (address != 0x40600000U) abort();
    putchar((int)data);
}
u32 Xil_In32(uintptr_t address)
{
    if (address == 0x44A00000U) return led_value;
    if (address == 0x44A10000U) return fnd_value;
    if (address == 0x44A10004U) return fnd_ctrl;
    fprintf(stderr, "BAD READ ADDRESS 0x%lx\n", (unsigned long)address);
    abort();
}
void Xil_Out32(uintptr_t address, u32 data)
{
    if (address == 0x44A00000U) {
        if (data > 1U) abort();
        led_value = data;
        return;
    }
    if (address == 0x44A10000U) {
        if (data > 0xFFFFU) abort();
        fnd_value = data;
        return;
    }
    if (address == 0x44A10004U) {
        if (data > 1U) abort();
        fnd_ctrl = data;
        return;
    }
    fprintf(stderr, "BAD WRITE ADDRESS 0x%lx\n", (unsigned long)address);
    abort();
}
