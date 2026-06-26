#include "targets.h"
/* 函式回傳函式指標: 名字 get_op 埋在 parenthesized_declarator */
int (*get_op(int which))(int,int) { return which ? t_add : t_sub; }
/* K&R 舊式定義 */
int knr_caller(x) int x; { return t_add(x, 1); }
static int static_fn(void){ return t_mul(2,3); }      /* static 定義內呼叫 */
static inline int inline_fn(void){ return t_sub(9,4); } /* inline 定義內呼叫 */
