#include "targets.h"
#define LOG_AND_ADD(x) (t_mul((x),1))   /* 巨集體內呼叫 t_mul */
int f4_caller(int x){ return LOG_AND_ADD(x); }  /* 展開後 → t_mul */
