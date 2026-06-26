#include "targets.h"
static int helper(void){ return t_sub(8,8); }   /* b 檔的 helper (不同符號) */
int f5b_use(void){ return helper(); }            /* 應連到「本檔」helper */
