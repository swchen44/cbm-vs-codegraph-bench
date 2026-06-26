#include "targets.h"
struct vtable { int (*op_a)(int,int); int (*op_b)(int,int); };
static struct vtable VT = { .op_a = t_add, .op_b = t_mul };  /* 兩欄位各指一函式 */
int f6_dispatch(struct vtable *v){ return v->op_a(1,2) + v->op_b(3,4); } /* → t_add, t_mul */
