#include "spinlock.h"
#include "utils.h"

// Declare the lock variable, which will be defined in the assembly file
volatile uint32_t printf_lock;

// A thread-safe printf implementation using a spinlock.
void spinlock_printf(const char *format, ...)
{
    va_list args;

    // Acquire the lock, spinning if necessary
    lock(&printf_lock);

    // Call the underlying vprintf
    va_start(args, format);
    vprintf(format, args);
    va_end(args);

    // Release the lock
    unlock(&printf_lock);
}
