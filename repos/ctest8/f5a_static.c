#include "targets.h"
static int helper(void){ return t_add(5,5); }   /* a 檔的 helper */
int f5a_use(void){ return helper(); }            /* 應連到「本檔」helper */
