#ifndef XTMRCTR_H
#define XTMRCTR_H
#include "xil_types.h"
typedef struct {struct{unsigned IntrId;UINTPTR IntrParent;}Config;} XTmrCtr;
#define XTC_DOWN_COUNT_OPTION 1U
#define XTC_AUTO_RELOAD_OPTION 2U
#define XTC_INT_MODE_OPTION 4U
static inline int XTmrCtr_Initialize(XTmrCtr *t,unsigned base){(void)t;(void)base;return 0;}
static inline void XTmrCtr_SetHandler(XTmrCtr *t,void (*h)(void*,u8),void *ref){(void)t;(void)h;(void)ref;}
static inline void XTmrCtr_SetOptions(XTmrCtr *t,unsigned n,unsigned opts){(void)t;(void)n;(void)opts;}
static inline void XTmrCtr_SetResetValue(XTmrCtr *t,unsigned n,unsigned val){(void)t;(void)n;(void)val;}
static inline void XTmrCtr_Start(XTmrCtr *t,unsigned n){(void)t;(void)n;}
static inline void XTmrCtr_InterruptHandler(void *ref){(void)ref;}
#endif
