#include <stdint.h>

void __aeabi_assert(const char *expr, const char *file, int line)
{
    (void)expr;
    (void)file;
    (void)line;
    while (1) {
        __asm volatile("wfi");
    }
}

