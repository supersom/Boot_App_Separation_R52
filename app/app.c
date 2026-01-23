// app.c – second ELF, linked at 0x00800000

#include <stdint.h>
#include <stdio.h>
#include "common_defs.h"
#include "generictimer.h"
#include "spinlock.h"
// #include "../shared/boot_args.h"

// This is the application's entry point.
// void app_entry(void);
extern void app_bootloader(void);

// Define the stack top. This should align with the scatter file.
// RW_APP starts at 0x30010000 and is 0x8000 bytes long.
#define STACK_TOP 0x20018000

// Application's vector table.
// The first entry is the initial stack pointer, the second is the reset handler.
__attribute__ ((section(".app_vector_table"), used))
const volatile uint32_t app_vector_table[] = {
    STACK_TOP,
    (uint32_t) app_bootloader
};

// __attribute__ ((section("BOOT_ARGS"), used))
// volatile boot_args_t* boot_args = (boot_args_t*)BOOT_ARGS_ADDR;

static void enableSystemCounter(void);
static void waitForEnableSystemCounter(void);

// Approximate sleep - highly dependent on CPU clock speed
void sleep_busy_wait(unsigned int iterations) {
    volatile unsigned int i;
    for (i = 0; i < iterations; i++) {
        // Do nothing, just burn cycles
        __asm volatile("nop");
    }
}

// // Application entry point.
// // __attribute__((used))
int main(void)
{
    uint32_t mpidr;
    // volatile unsigned int *heap_probe = &__heap_base_com;
    // (void)heap_probe;

    __asm volatile("MRC p15, 0, %0, c0, c0, 5" : "=r"(mpidr));
    uint32_t core_id = mpidr & 0xFF;

    printf("[%s] core_id=%u\n", "app", (unsigned)core_id);

    // Simple “I’m alive” loop
    volatile uint32_t counter = 0;
    while (1)
    {
        counter++;
        uint32_t hppir, rpr;
        __asm volatile("MRC p15, 0, %0, c12, c8, 0" : "=r"(hppir)); // ICC_HPPIR0
        __asm volatile("MRC p15, 0, %0, c12, c11, 3" : "=r"(rpr));  // ICC_RPR
        spinlock_printf("\nC00: HPPIR0=0x%x RPR=0x%x\n", hppir, rpr);
        spinlock_printf("C00: CNTPCT @ %u: %llu\n", counter, getCNTPCT());
        sleep_busy_wait(10000000);
    }
}
