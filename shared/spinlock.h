#ifndef SPINLOCK_H_
#define SPINLOCK_H_

#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>

// A thread-safe version of printf
void spinlock_printf(const char *format, ...);

#endif /* SPINLOCK_H_ */
