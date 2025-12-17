#ifndef R52_H
#define R52_H

#include <stdint.h>
#include "../shared/boot_args.h"

// --- MPU ---
#define MPU_BASE 0xE000ED90
#define MPU ((Mpu_t *)MPU_BASE)

#define MPU_TYPE (*(volatile uint32_t *)(MPU_BASE + 0x00))
#define MPU_CTRL (*(volatile uint32_t *)(MPU_BASE + 0x04))
#define MPU_RNR (*(volatile uint32_t *)(MPU_BASE + 0x08))
#define MPU_RBAR (*(volatile uint32_t *)(MPU_BASE + 0x0C))
#define MPU_RASR (*(volatile uint32_t *)(MPU_BASE + 0x10))

// MPU Control Register
#define MPU_CTRL_ENABLE (1 << 0)
#define MPU_CTRL_HFNMIENA (1 << 1)
#define MPU_CTRL_PRIVDEFENA (1 << 2)

// MPU Region Attribute and Size Register
// Access Permissions (AP)
#define AP_NO_ACCESS (0 << 24)
#define AP_RW_PRIV (1 << 24)
#define AP_RO_PRIV (5 << 24)
#define AP_RW_ALL (3 << 24)
#define AP_RO_ALL (6 << 24)

// eXecute Never (XN)
#define XN_DISABLE (0 << 28)
#define XN_ENABLE (1 << 28)

// Shareable (S), Cacheable (C), Bufferable (B)
#define Attr_StronglyOrdered (0 << 16)
#define Attr_Device (1 << 16)
#define Attr_Normal_NC_NB (2 << 16) // Normal, Non-cacheable, Non-bufferable
#define Attr_Normal_C_B (7 << 16) // Normal, Cacheable, Bufferable (Write-back, write-allocate)


// --- System Control Block ---
#define SCB_BASE 0xE000ED00
#define SCB ((Scb_t *)SCB_BASE)
#define SCB_VTOR (*(volatile uint32_t *)(SCB_BASE + 0x08))
#define SCB_SHCSR (*(volatile uint32_t *)(SCB_BASE + 0x24))

#define SCB_SHCSR_MEMFAULTENA (1 << 16)
#define SCB_SHCSR_BUSFAULTENA (1 << 17)
#define SCB_SHCSR_USGFAULTENA (1 << 18)


// --- Inline functions for MPU configuration ---

static inline void mpu_config_region(uint32_t rnr, uint32_t rbar, uint32_t rasr)
{
    MPU_RNR = rnr;
    MPU_RBAR = rbar;
    MPU_RASR = rasr;
}

static inline void mpu_enable(void)
{
    // Enable MPU with default private memory map for privileged access
    MPU_CTRL = MPU_CTRL_ENABLE | MPU_CTRL_PRIVDEFENA;
    __asm volatile ("dsb"); // data synchronization barrier
    __asm volatile ("isb"); // instruction synchronization barrier
}

static inline void mpu_disable(void)
{
    MPU_CTRL = 0;
}

static inline void init_mpu(void)
{
    mpu_disable();

    // Region 0: 0x00000000 - 0x00010000 (64KB) - Bootloader Code
    // Access: RO, Executable, Normal, Write-Back/Write-Allocate Cacheable
    mpu_config_region(0, 0x00000000, AP_RW_ALL | XN_DISABLE | Attr_Normal_C_B | (15 << 1) | 1);

    // Region 1: 0x00020000 - 0x00030000 (64KB) - App Code
    // Access: RO, Executable, Normal, Write-Back/Write-Allocate Cacheable
    mpu_config_region(1, 0x00020000, AP_RW_ALL | XN_DISABLE | Attr_Normal_C_B | (15 << 1) | 1);

    // Region 2: 0x20000000 - 0x20008000 (32KB) - Heap
    // Access: RW, Not-Executable, Normal, Write-Back/Write-Allocate Cacheable
    mpu_config_region(2, 0x20000000, AP_RW_ALL | XN_ENABLE | Attr_Normal_C_B | (14 << 1) | 1);

    // Region 3: 0x20010000 - 0x20018000 (32KB) - Stack
    // Access: RW, Not-Executable, Normal, Write-Back/Write-Allocate Cacheable
    mpu_config_region(3, 0x20010000, AP_RW_ALL | XN_ENABLE | Attr_Normal_C_B | (14 << 1) | 1);

    // Region 4: 0x30000000 - 0x30008000 (32KB) - Bootloader RAM
    // Access: RW, Not-Executable, Normal, Write-Back/Write-Allocate Cacheable
    mpu_config_region(4, 0x30000000, AP_RW_ALL | XN_ENABLE | Attr_Normal_C_B | (14 << 1) | 1);

    // Region 5: 0x30010000 - 0x30018000 (32KB) - App RAM
    // Access: RW, Not-Executable, Normal, Write-Back/Write-Allocate Cacheable
    mpu_config_region(5, 0x30010000, AP_RW_ALL | XN_ENABLE | Attr_Normal_C_B | (14 << 1) | 1);

    // Region 6: 0x10000000 - 0x10001000 (4KB) - Shared Boot Args
    // Access: Privileged RW, Not-Executable
    mpu_config_region(6, BOOT_ARGS_ADDR, AP_RW_ALL | XN_ENABLE | Attr_Normal_C_B | (11 << 1) | 1); // Size 4KB

    mpu_enable();
}


#endif // R52_H
