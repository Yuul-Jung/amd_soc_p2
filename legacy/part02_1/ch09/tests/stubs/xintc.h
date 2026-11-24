#ifndef XINTC_H
#define XINTC_H
#include "xil_types.h"
typedef struct {int pad;} XIntc;
typedef void (*XInterruptHandler)(void *);
#define XIN_REAL_MODE 1
static inline int XIntc_Initialize(XIntc *x,unsigned id){(void)x;(void)id;return 0;}
static inline int XIntc_Connect(XIntc *x,unsigned id,XInterruptHandler fn,void *ref){(void)x;(void)id;(void)fn;(void)ref;return 0;}
static inline int XIntc_Start(XIntc *x,unsigned mode){(void)x;(void)mode;return 0;}
static inline void XIntc_Enable(XIntc *x,unsigned id){(void)x;(void)id;}
static inline void XIntc_InterruptHandler(void *ref){(void)ref;}
#endif
