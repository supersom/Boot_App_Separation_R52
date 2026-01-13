// app.c – second ELF, linked at 0x00800000

#include <stdint.h>
#include <stdio.h>
// #include "../shared/boot_args.h"

// This is the application's entry point.
// void app_entry(void);
extern void app_bootloader(void);

// Define the stack top. This should align with the scatter file.
// RW_APP starts at 0x30020000 and is 0x8000 bytes long.
#define STACK_TOP 0x20048000

// Application's vector table.
// The first entry is the initial stack pointer, the second is the reset handler.
__attribute__ ((section(".app_vector_table"), used))
const volatile uint32_t app_vector_table[] = {
    STACK_TOP,
    (uint32_t) app_bootloader
};

// __attribute__ ((section("BOOT_ARGS"), used))
// volatile boot_args_t* boot_args = (boot_args_t*)BOOT_ARGS_ADDR;

// Approximate sleep - highly dependent on CPU clock speed
void sleep_busy_wait(unsigned int iterations) {
    volatile unsigned int i;
    for (i = 0; i < iterations; i++) {
        // Do nothing, just burn cycles
        __asm volatile("nop");
    }
}

// Application entry point.
// __attribute__((used))
// void app_entry(void)
int main(void)
{
    // uint32_t my_core_id = boot_args->core_id;
    // // Print the ID received from the bootloader
    // printf("Application started on core %u\n", my_core_id);

    // Simple “I’m alive” loop
    volatile uint32_t counter = 0;
    while (1)
    {
        counter++;
        printf("App (core 11) is alive: %u\n", counter);
        sleep_busy_wait(10000000);
    }
}
