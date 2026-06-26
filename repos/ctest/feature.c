#include "feature.h"

int real_handler(int x) { return x * 2; }

#ifdef FEATURE_X
int feature_func(void) { return real_handler(1); }   /* 只在 FEATURE_X 定義時存在 */
#else
int fallback_func(void) { return 0; }                 /* 只在 FEATURE_X 未定義時存在 */
#endif

int caller(int x) {
    return WRAP_CALL(x);    /* 巨集藏呼叫 → real_handler */
}

int use_inline(void) { return inline_helper(5); }

static int dispatch(struct ops *o, int x) { return o->fn(x); }  /* 函式指標分派 */
