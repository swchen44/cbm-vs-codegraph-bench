int g_int(int x){ return x; }
double g_dbl(double x){ return x; }
#define G(x) _Generic((x), int: g_int, double: g_dbl)(x)
int f7_caller(void){ int a=G(3); double b=G(2.0); return a+(int)b; } /* int→g_int, double→g_dbl */
