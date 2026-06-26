#include "targets.h"
typedef int (*binop_t)(int,int);
typedef binop_t alias_t;          /* typedef 鏈 */
int via_typedef(void){
    alias_t h = t_add;            /* h 指向 t_add */
    return h(1,2);                /* 間接呼叫 → 應連到 t_add */
}
