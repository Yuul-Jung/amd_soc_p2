#ifndef XUARTLITE_L_H
#define XUARTLITE_L_H
#include "xil_types.h"
static inline void XUartLite_SendByte(UINTPTR a,u8 v) {(void)a;(void)v;}
static inline u8 XUartLite_RecvByte(UINTPTR a){(void)a;return 0;}
static inline int XUartLite_IsReceiveEmpty(UINTPTR a){(void)a;return 1;}
#endif
