#ifndef R52_H
#define R52_H

#include <stdint.h>
#include "../shared/boot_args.h"

// --- MPU (PMSAv8-32) ---
#define MPU_BASE 0xE000ED90
#define MPU ((Mpu_t *)MPU_BASE)

#define MPU_TYPE (*(volatile uint32_t *)(MPU_BASE + 0x00))
#define MPU_CTRL (*(volatile uint32_t *)(MPU_BASE + 0x04))
#define MPU_RNR (*(volatile uint32_t *)(MPU_BASE + 0x08))
#define MPU_RBAR (*(volatile uint32_t *)(MPU_BASE + 0x0C))
#define MPU_RLAR (*(volatile uint32_t *)(MPU_BASE + 0x10))
#define MPU_MAIR0 (*(volatile uint32_t *)(MPU_BASE + 0x30))
#define MPU_MAIR1 (*(volatile uint32_t *)(MPU_BASE + 0x34))

// MPU Control Register
#define MPU_CTRL_ENABLE (1 << 0)
#define MPU_CTRL_HFNMIENA (1 << 1)
#define MPU_CTRL_PRIVDEFENA (1 << 2)

// MPU RBAR
#define MPU_RBAR_XN (1 << 0) // Execute Never

// MPU RLAR
#define MPU_RLAR_EN (1 << 0) // Region Enable

// MAIR Attributes (AttrIndx)
#define MAIR_ATTR0_IDX 0
#define MAIR_ATTR1_IDX 1
#define MAIR_ATTR2_IDX 2
#define MAIR_ATTR3_IDX 3

// MAIR Encodings
// Device-nGnRnE (Strongly Ordered equivalent)
#define MAIR_ATTR_DEVICE 0x00
// Normal, Outer & Inner Write-Back, Read-Allocate, Write-Allocate, Non-Transient
#define MAIR_ATTR_NORMAL_WB 0xFF
// Normal, Outer & Inner Non-cacheable
#define MAIR_ATTR_NORMAL_NC 0x44
// Normal, Outer & Inner Write-Through
#define MAIR_ATTR_NORMAL_WT 0xBB

// Helper for AP (Access Permissions) in RBAR (bits 2:1)
// PMSAv8 uses AP bits in RBAR:
// AP[2:1] are bits 2:1 of RBAR.
// 00: RW Privileged
// 01: RW Any (if enabled) -> Wait, table is different.
// Checking ARMv8-R TRM:
// AP[2:1]
// 00: RW Priv, No Access User
// 01: RW Priv, RW User
// 10: RO Priv, No Access User
// 11: RO Priv, RO User
#define AP_RW_PRIV (0x0 << 1)
#define AP_RW_ALL  (0x1 << 1)
#define AP_RO_PRIV (0x2 << 1)
#define AP_RO_ALL  (0x3 << 1)

// Shareability (SH) in RBAR (bits 4:3)
#define SH_NON_SHAREABLE   (0x0 << 3)
#define SH_OUTER_SHAREABLE (0x2 << 3)
#define SH_INNER_SHAREABLE (0x3 << 3)

// CPU IDs
#define CPU_ID_00 0x0
#define CPU_ID_01 0x1
#define CPU_ID_10 0x2
#define CPU_ID_11 0x3

// TCM base addresses per core
#define ATCM_C00_BASE 0x01000000
#define BTCM_C00_BASE 0x02000000
#define CTCM_C00_BASE 0x03000000
#define ATCM_C01_BASE 0x05000000
#define BTCM_C01_BASE 0x06000000
#define CTCM_C01_BASE 0x07000000
#define ATCM_C10_BASE 0x09000000
#define BTCM_C10_BASE 0x0A000000
#define CTCM_C10_BASE 0x0B000000
#define ATCM_C11_BASE 0x0D000000
#define BTCM_C11_BASE 0x0E000000
#define CTCM_C11_BASE 0x0F000000

// --- System Control Block ---
#define SCB_BASE 0xE000ED00
#define SCB ((Scb_t *)SCB_BASE)
#define SCB_VTOR (*(volatile uint32_t *)(SCB_BASE + 0x08))
#define SCB_SHCSR (*(volatile uint32_t *)(SCB_BASE + 0x24))

#define SCB_SHCSR_MEMFAULTENA (1 << 16)
#define SCB_SHCSR_BUSFAULTENA (1 << 17)
#define SCB_SHCSR_USGFAULTENA (1 << 18)


// --- Inline functions for MPU configuration ---

static inline void mpu_config_region(uint32_t rnr, uint32_t rbar, uint32_t rlar)
{
    MPU_RNR = rnr;
    MPU_RBAR = rbar;
    MPU_RLAR = rlar;
}

static inline void mpu_set_mair(uint32_t mair0, uint32_t mair1)
{
    MPU_MAIR0 = mair0;
    MPU_MAIR1 = mair1;
}

static inline void mpu_enable(void)
{
    // Enable MPU with default private memory map for privileged access
    // Also enable background region (PRIVDEFENA)
    MPU_CTRL = MPU_CTRL_ENABLE | MPU_CTRL_PRIVDEFENA;
    __asm volatile ("dsb"); // data synchronization barrier
    __asm volatile ("isb"); // instruction synchronization barrier
}

static inline void mpu_disable(void)
{
    MPU_CTRL = 0;
    __asm volatile ("dsb");
    __asm volatile ("isb");
}

void init_mpu(void);


#endif // R52_H
