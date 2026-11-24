#ifndef XIL_IO_H
#define XIL_IO_H
#include "xil_types.h"
#ifdef P2_09_TEST_IO
u32 Xil_In32(UINTPTR a);
void Xil_Out32(UINTPTR a,u32 v);
#else
static inline u32 Xil_In32(UINTPTR a) { (void)a; return 0; }
static inline void Xil_Out32(UINTPTR a, u32 v) {(void)a;(void)v;}
#endif
#endif
