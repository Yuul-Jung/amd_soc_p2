#ifndef XIL_EXCEPTION_H
#define XIL_EXCEPTION_H
typedef void (*Xil_ExceptionHandler)(void *);
#define XIL_EXCEPTION_ID_INT 0
static inline void Xil_ExceptionInit(void){}
static inline void Xil_ExceptionEnable(void){}
static inline void Xil_ExceptionRegisterHandler(int id,Xil_ExceptionHandler h,void *p){(void)id;(void)h;(void)p;}
#endif
