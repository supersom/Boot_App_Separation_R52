#include "r52.h"

void init_mpu(void)
{
    mpu_disable();

    // Configure MAIR0 with memory attributes
    // Byte 0 (Attr0): Device-nGnRnE (0x00) - Equivalent to Strongly Ordered
    // Byte 1 (Attr1): Normal Inner/Outer WB, WA (0xFF)
    // Byte 2 (Attr2): Normal Inner/Outer NC (0x44)
    // Byte 3 (Attr3): Normal Inner/Outer WT (0xBB)
    uint32_t mair0_val = (MAIR_ATTR_DEVICE << (MAIR_ATTR0_IDX * 8)) |
                         (MAIR_ATTR_NORMAL_WB << (MAIR_ATTR1_IDX * 8)) |
                         (MAIR_ATTR_NORMAL_NC << (MAIR_ATTR2_IDX * 8)) |
                         (MAIR_ATTR_NORMAL_WT << (MAIR_ATTR3_IDX * 8));
    
    mpu_set_mair(mair0_val, 0);

    // Region 0: 0x00000000 - 0x00100000 (1MB) - Bootloader Code
    // Access: RW, Executable (XN=0), Normal WB WA, Non-Shareable
    uint32_t limit_0 = 0x00000000 + 0x00100000 - 1;
    mpu_config_region(0, 
        0x00000000 | AP_RW_ALL | SH_NON_SHAREABLE, // RBAR: XN=0 (default)
        (limit_0 & 0xFFFFFFE0) | (MAIR_ATTR1_IDX << 1) | MPU_RLAR_EN
    );

    // Region 2: 0x20000000 - 0x20050000 (320KB) - Heap/Stack
    // Access: RW, Not-Executable, Normal WB WA, Non-Shareable
    uint32_t limit_2 = 0x20000000 + 0x00050000 - 1;
    mpu_config_region(2, 
        0x20000000 | AP_RW_ALL | SH_NON_SHAREABLE | MPU_RBAR_XN,
        (limit_2 & 0xFFFFFFE0) | (MAIR_ATTR1_IDX << 1) | MPU_RLAR_EN
    );

    // Region 4: 0x30000000 - 0x30050000 (320KB) - Bootloader RAM
    // Access: RW, Not-Executable, Normal WB WA, Non-Shareable
    uint32_t limit_4 = 0x30000000 + 0x00050000 - 1;
    mpu_config_region(4, 
        0x30000000 | AP_RW_ALL | SH_NON_SHAREABLE | MPU_RBAR_XN,
        (limit_4 & 0xFFFFFFE0) | (MAIR_ATTR1_IDX << 1) | MPU_RLAR_EN
    );

    // Region 6: BOOT_ARGS_ADDR (0x00400000) - Size 4KB - Shared Flags
    // Access: RW, Not-Executable, Device-nGnRnE (Strongly Ordered), Shareable
    // Note: Device memory is always Outer Shareable.
    uint32_t limit_6 = BOOT_ARGS_ADDR + 0x1000 - 1;
    mpu_config_region(6, 
        BOOT_ARGS_ADDR | AP_RW_ALL | SH_OUTER_SHAREABLE | MPU_RBAR_XN,
        (limit_6 & 0xFFFFFFE0) | (MAIR_ATTR0_IDX << 1) | MPU_RLAR_EN
    );

    // Regions 7-9: Per-core TCMs (RW, executable, non-shareable, non-cacheable)
    {
        uint32_t core_id;
        uint32_t atcm_base;
        uint32_t btcm_base;
        uint32_t ctcm_base;

        __asm volatile ("mrc p15, 0, %0, c0, c0, 5" : "=r"(core_id));
        core_id &= 0x3;

        if (core_id == CPU_ID_01) {
            atcm_base = ATCM_C01_BASE;
            btcm_base = BTCM_C01_BASE;
            ctcm_base = CTCM_C01_BASE;
        } else if (core_id == CPU_ID_10) {
            atcm_base = ATCM_C10_BASE;
            btcm_base = BTCM_C10_BASE;
            ctcm_base = CTCM_C10_BASE;
        } else if (core_id == CPU_ID_11) {
            atcm_base = ATCM_C11_BASE;
            btcm_base = BTCM_C11_BASE;
            ctcm_base = CTCM_C11_BASE;
        } else {
            atcm_base = ATCM_C00_BASE;
            btcm_base = BTCM_C00_BASE;
            ctcm_base = CTCM_C00_BASE;
        }

        // TCM Size: 128KB (0x20000)
        uint32_t tcm_size = 0x20000;
        uint32_t limit_atcm = atcm_base + tcm_size - 1;
        uint32_t limit_btcm = btcm_base + tcm_size - 1;
        uint32_t limit_ctcm = ctcm_base + tcm_size - 1;

        // Using Attr2 (Normal NC) for TCMs
        mpu_config_region(7, 
            atcm_base | AP_RW_ALL | SH_NON_SHAREABLE, // Executable
            (limit_atcm & 0xFFFFFFE0) | (MAIR_ATTR2_IDX << 1) | MPU_RLAR_EN
        );
        mpu_config_region(8, 
            btcm_base | AP_RW_ALL | SH_NON_SHAREABLE, // Executable
            (limit_btcm & 0xFFFFFFE0) | (MAIR_ATTR2_IDX << 1) | MPU_RLAR_EN
        );
        mpu_config_region(9, 
            ctcm_base | AP_RW_ALL | SH_NON_SHAREABLE, // Executable
            (limit_ctcm & 0xFFFFFFE0) | (MAIR_ATTR2_IDX << 1) | MPU_RLAR_EN
        );
    }

    mpu_enable();
}