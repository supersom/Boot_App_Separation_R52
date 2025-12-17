#ifndef BOOT_ARGS_H
#define BOOT_ARGS_H

#include <stdint.h>

// Define a structure for the boot arguments
typedef struct {
    uint32_t core_id;
    // You can add more fields here in the future, e.g.:
    // uint32_t boot_timestamp;
    // uint32_t security_status;
} boot_args_t;

#define BOOT_ARGS_SIZE (0x4) // Size of boot_args_t in bytes

// Define the fixed memory address for the boot arguments structure.
// This must be placed in a region of RAM accessible by all cores at startup.
#define BOOT_ARGS_ADDR (0x10000000)

#endif // BOOT_ARGS_H
