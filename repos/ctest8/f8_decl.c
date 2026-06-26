#include "f8_decl.h"
#include "f8_decl.h"   /* 重複 include 同原型 */
int f8_target(void){ return 42; }     /* 唯一定義 */
int f8_caller(void){ return f8_target(); } /* 應連到「定義」, f8_target 應只一個節點 */
