#include <stdint.h>
#include <stdio.h>
#include "../shared/r52.h"

typedef void (*entry_fn_t)(void);

#define APP_BASE_ADDRESS 0x00020000

static void jump_to_app(void)
{
    // The application's vector table is at the start of the app image.
    // The first entry is the initial stack pointer, the second is the reset handler.
    uint32_t *app_vector_table = (uint32_t *)APP_BASE_ADDRESS;
    uint32_t app_entry_point = app_vector_table[1];

    entry_fn_t app = (entry_fn_t)app_entry_point;

    printf("Jumping to app at address 0x%08X...\n", (uint32_t)app);
    app();
}

int main(void)
{
    // Set up MPU - THIS IS ESSENTIAL
    init_mpu();

    // Minimal init complete.
    printf("Bootloader finished initialisation.\n");

    // Then jump to the second ELF
    jump_to_app();

    // Should never return
    while (1) { }
}
