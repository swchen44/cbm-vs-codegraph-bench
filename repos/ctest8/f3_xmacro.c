#include "targets.h"
#define DEFINE_WRAPPER(n) int n##_wrapper(void){ return t_add(1,1); }
DEFINE_WRAPPER(foo)   /* 生成 foo_wrapper, 內呼叫 t_add */
DEFINE_WRAPPER(bar)   /* 生成 bar_wrapper */
/* X-macro 表 */
#define CMD_LIST(X) X(alpha) X(beta)
#define GEN(n) int cmd_##n(void){ return t_sub(0,0); }
CMD_LIST(GEN)         /* 生成 cmd_alpha, cmd_beta */
