#ifndef FEATURE_H
#define FEATURE_H
#define WRAP_CALL(x) real_handler(x)   /* 巨集藏住對內部函式的呼叫 */
int real_handler(int x);
static inline int inline_helper(int a) { return a + 1; }  /* inline 函式 */
enum color { RED, GREEN, BLUE };        /* enum + enumerator */
struct ops { int (*fn)(int); };         /* struct + 函式指標欄位 */
#endif
