#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "xil_types.h"
#include "xuartlite_l.h"
#include "xil_io.h"
static u32 reg0 = 0;
static unsigned reads = 0, writes = 0;
u8 XUartLite_RecvByte(uintptr_t address) { (void)address; int c = getchar(); if (c == EOF) { fflush(stdout); exit(0); } return (u8)c; }
void XUartLite_SendByte(uintptr_t address, u8 data) { (void)address; putchar((int)data); }
u32 Xil_In32(uintptr_t address) { if (address != 0x44A00000u) abort(); reads++; return reg0; }
void Xil_Out32(uintptr_t address, u32 data) { if (address != 0x44A00000u) abort(); writes++; if (data > 1) abort(); reg0 = data; }
