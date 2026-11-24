#ifndef XGPIO_H
#define XGPIO_H
#include "xil_types.h"
typedef struct {unsigned pad;} XGpio;
static inline int XGpio_Initialize(XGpio *g,unsigned base){(void)g;(void)base;return 0;}
static inline void XGpio_SetDataDirection(XGpio *g,unsigned ch,unsigned mask){(void)g;(void)ch;(void)mask;}
static inline void XGpio_DiscreteWrite(XGpio *g,unsigned ch,unsigned val){(void)g;(void)ch;(void)val;}
#endif
