#ifndef XINTERRUPT_WRAP_H
#define XINTERRUPT_WRAP_H
#include "xil_types.h"
#define XINTERRUPT_DEFAULT_PRIORITY 0xA0U
static inline int XSetupInterruptSystem(void *ref,void *handler,u32 id,UINTPTR parent,unsigned short priority)
{(void)ref;(void)handler;(void)id;(void)parent;(void)priority;return 0;}
#endif
