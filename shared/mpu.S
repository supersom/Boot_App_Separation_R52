/*
 * mpu.S
 *
 *  Created on: Jan 30, 2026
 *
 *  Description:
 *      Standalone EL1 MPU setup sequence (mirrors the USE_EL1_MPU
 *      block in bootloader.S). Invoking EL1_MPU_Setup configures
 *      regions, updates MAIR0, and enables the MPU.
 *
 *  Copyright (c) C2i Semiconductors.
 *  All rights reserved. This file is part of proprietary firmware and
 *  internal development at C2i Semiconductors. Unauthorized copying,
 *  redistribution, or use of this file in source or binary forms, with or
 *  without modification, is strictly prohibited unless explicit written
 *  permission is granted by C2i Semiconductors.
 *
 * ---------------------------------------------------------------------------*/

#include "common_defs.h"

    .section MPU, "ax"
    .align 3

.global EL1_MPU_Setup
.type EL1_MPU_Setup, "function"
EL1_MPU_Setup:
        PUSH    {r0-r3, r12, lr}         // Save caller-saved regs and LR; keeps 8-byte stack alignment
//----------------------------------------------------------------
// MPU Configuration
//----------------------------------------------------------------

// Notes:
// * Regions apply to both instruction and data accesses.
// * Each region base address must be a multiple of its size
// * Any address range not covered by an enabled region will abort
// * The region at 0x0 over the Vector table is needed to support semihosting

// Region 0: Code          Base = See scatter file  Limit = Based on usage   Normal  Non-shared  Read-only    Executable
// Region 1: Data          Base = See scatter file  Limit = Based on usage   Normal  Non-shared  Full access  Not Executable
// Region 2: Stack/Heap    Base = See scatter file  Limit = Based on usage   Normal  Non-shared  Full access  Not Executable
// Region 3: Peripherals   Base = 0x9A000000        Limit = 0xAFFFFFC0       Device              Full access  Not Executable
// Region 4: ATCM          Base = Configurable      Limit = Based on usage   Normal  Non-shared  Full access  Executable
// Region 5: BTCM          Base = Configurable      Limit = Based on usage   Normal  Non-shared  Full access  Executable
// Region 6: CTCM          Base = Configurable      Limit = Based on usage   Normal  Non-shared  Full access  Executable

        // Region 0 - Code
        LDR     r1, =Image$$CODE$$Base
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c8, 0                   // write PRBAR0

        LDR     r1, =0x100000 //Load$$LR$$LOAD$$Limit
        SUB     r1, r1, #1                              // convert limit from exclusive to inclusive
        BFC     r1, #0, #6                              // and clear the lower 6 bits
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c8, 1                   // write PRLAR0

        // Region 1 - Data
        LDR     r1, =Image$$DATA_UNINIT$$Base
        LDR     r2, =((Outer_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c8, 4                   // write PRBAR1

        LDR     r1, =Image$$DATA$$ZI$$Limit
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c8, 5                   // write PRLAR1

        // Region 2 - Stack-Heap
        LDR     r1, =__heap_base_com //=Image$$ARM_LIB_HEAP$$Base
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c9, 0                   // write PRBAR2

        LDR     r1, =__heap_limit_com //=Image$$ARM_LIB_STACK$$ZI$$Limit
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c9, 1                   // write PRLAR2

        // Region 3 - Peripherals
        LDR     r1, =EXT_IP_BASE //Image$$PERIPHERALS$$Base //0x9A000000
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c9, 4                   // write PRBAR3

        LDR     r1, =EXT_IP_LIMIT //Image$$PERIPHERALS$$ZI$$Limit //0xAFFFFFC0
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx1<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c9, 5                   // write PRLAR3

#ifdef TCM
        // --- ATCM ---
        LDR     r1, =APP_ATCM_BASE
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c12, 4                  // write PRBAR9

        LDR     r1, =APP_ATCM_LIMIT
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx1<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c12, 5                  // write PRLAR9

        // --- BTCM ---
        LDR     r1, =APP_BTCM_BASE
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c13, 0                  // write PRBAR10

        LDR     r1, =APP_BTCM_LIMIT
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c13, 1                  // write PRLAR10

        // --- CTCM ---
        LDR     r1, =APP_CTCM_BASE
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c13, 4                  // write PRBAR11

        LDR     r1, =APP_CTCM_LIMIT
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c13, 5                  // write PRLAR11

@        // --- Stacks ---
@        // Region 7 - Stack of core 0
@        LDR     r1, =__stack_base_c00
@        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c11, 4                   // write PRBAR7
@
@        LDR     r1, =__stack_top_c00
@        SUB     r1, r1, #1
@        BFC     r1, #0, #6
@        LDR     r2, =((AttrIndx0<<1) | (ENable))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c11, 5                   // write PRLAR7
@
@        // Region 8 - Stack of core 1
@        LDR     r1, =__stack_base_c01
@        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c12, 0                   // write PRBAR8
@
@        LDR     r1, =__stack_top_c01
@        SUB     r1, r1, #1
@        BFC     r1, #0, #6
@        LDR     r2, =((AttrIndx0<<1) | (ENable))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c12, 1                   // write PRLAR8
@
@        // Region 19 - Stack of core 10 (via PRSELR)
@        MOV     r3, #19
@        MCR     p15, 0, r3, c6, c2, 1                   // write PRSELR
@        LDR     r1, =__stack_base_c10
@        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c3, 0                   // write PRBAR
@        LDR     r1, =__stack_top_c10
@        SUB     r1, r1, #1
@        BFC     r1, #0, #6
@        LDR     r2, =((AttrIndx0<<1) | (ENable))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c3, 1                   // write PRLAR
@
@        // Region 20 - Stack of core 11 (via PRSELR)
@        MOV     r3, #20
@        MCR     p15, 0, r3, c6, c2, 1                   // write PRSELR
@        LDR     r1, =__stack_base_c11
@        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c3, 0                   // write PRBAR
@        LDR     r1, =__stack_top_c11
@        SUB     r1, r1, #1
@        BFC     r1, #0, #6
@        LDR     r2, =((AttrIndx0<<1) | (ENable))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c3, 1                   // write PRLAR

        // Region 12 - Sys control (access like peripheral devices)
        LDR     r1, =GIC_TIMERS_BASE
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c14, 0                   // write PRBAR12

        LDR     r1, =GIC_TIMERS_LIMIT
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx1<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c14, 1                   // write PRLAR12

#endif

    // MAIR0 configuration
        MRC p15, 0, r0, c10, c2, 0      // Read MAIR0 into r0
        LDR r1, =0xBB                   // Normal inner/outer RW cacheable, write-through
        BFI r0, r1, #0, #8              // Update Attr0
        LDR r1, =0x04                   // Device nGnRnE
        BFI r0, r1, #8, #8              // Update Attr1
        MCR p15,0,r0,c10,c2,0           // Write r0 to MAIR0

//----------------------------------------------------------------
// Enable MPU
//----------------------------------------------------------------
        MRC     p15, 0, r0, c1, c0, 0       // Read System Control Register
        ORR     r0, r0, #0x01               // Set M bit to enable MPU
        DSB                                 // Ensure all previous loads/stores have completed
        MCR     p15, 0, r0, c1, c0, 0       // Write System Control Register
        ISB                                 // Ensure subsequent insts execute wrt new MPU settings

        POP     {r0-r3, r12, lr}
        BX      lr

.global EL2_MPU_Setup
.type EL2_MPU_Setup, "function"
EL2_MPU_Setup:
        PUSH    {r0-r3, r12, lr}         // Save caller-saved regs and LR; keeps 8-byte stack alignment
//----------------------------------------------------------------
// EL2 MPU Configuration (mirrors USE_EL2_MPU block)
//----------------------------------------------------------------

        // Region 0 - Code
        LDR     r1, =Image$$CODE$$Base
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c8, 0                   // write HPRBAR0
        MCR     p15, 0, r1, c6, c8, 0                   // write PRBAR0

        LDR     r1, =Load$$LR$$LOAD$$Limit
        SUB     r1, r1, #1                              // convert limit from exclusive to inclusive
        BFC     r1, #0, #6                              // and clear the lower 6 bits
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c8, 1                   // write HPRLAR0
        MCR     p15, 0, r1, c6, c8, 1                   // write PRLAR0

        // Region 1 - Data
        LDR     r1, =Image$$DATA$$Base
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c8, 4                   // write HPRBAR1
        MCR     p15, 0, r1, c6, c8, 4                   // write PRBAR1

        LDR     r1, =Image$$DATA$$ZI$$Limit
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c8, 5                   // write HPRLAR1
        MCR     p15, 0, r1, c6, c8, 5                   // write PRLAR1

        // Region 2 - Heap
        LDR     r1, =__heap_base_com //=Image$$ARM_LIB_HEAP$$Base
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c9, 0                   // write HPRBAR2
        MCR     p15, 0, r1, c6, c9, 0                   // write PRBAR2

        LDR     r1, =__heap_limit_com //=Image$$ARM_LIB_STACK$$ZI$$Limit
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c9, 1                   // write HPRLAR2
        MCR     p15, 0, r1, c6, c9, 1                   // write PRLAR2

        // Region 3 - Peripherals
        LDR     r1, =0x9A000000
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c9, 4                   // write HPRBAR3
        MCR     p15, 0, r1, c6, c9, 4                   // write PRBAR3

        LDR     r1, =0xAFFFFFC0
        SUB     r1, r1, #1                              // convert limit from exclusive to inclusive
        BFC     r1, #0, #6                              // and clear the lower 6 bits
        LDR     r2, =((AttrIndx1<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c9, 5                   // write HPRLAR3
        MCR     p15, 0, r1, c6, c9, 5                   // write PRLAR3

#ifdef TCM
        // Region 4 - ATCM
        LDR     r1, =APP_ATCM_BASE
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c10, 0                  // write HPRBAR4
        MCR     p15, 0, r1, c6, c10, 0                  // write PRBAR4

        LDR     r1, =APP_ATCM_LIMIT
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c10, 1                  // write HPRLAR4
        MCR     p15, 0, r1, c6, c10, 1                  // write PRLAR4

        // Region 5 - BTCM
        LDR     r1, =APP_BTCM_BASE
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c10, 4                  // write HPRBAR5
        MCR     p15, 0, r1, c6, c10, 4                  // write PRBAR5

        LDR     r1, =APP_BTCM_LIMIT
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c10, 5                  // write HPRLAR5
        MCR     p15, 0, r1, c6, c10, 5                  // write PRLAR5

        // Region 6 - CTCM
        LDR     r1, =APP_CTCM_BASE
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c11, 0                  // write HPRBAR6
        MCR     p15, 0, r1, c6, c11, 0                  // write PRBAR6

        LDR     r1, =APP_CTCM_LIMIT
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 4, r1, c6, c11, 1                  // write HPRLAR6
        MCR     p15, 0, r1, c6, c11, 1                  // write PRLAR6

#endif //TCM

        // Region 7 - Stack of core 0
        LDR     r1, =APP_STACK_BASE
        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c11, 4                   // write PRBAR7

        LDR     r1, =APP_STACK_TOP
        SUB     r1, r1, #1
        BFC     r1, #0, #6
        LDR     r2, =((AttrIndx0<<1) | (ENable))
        ORR     r1, r1, r2
        MCR     p15, 0, r1, c6, c11, 5                   // write PRLAR7

@        // Region 7 - Stack of core 0
@        LDR     r1, =__stack_base_c00
@        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c11, 4                   // write PRBAR7
@
@        LDR     r1, =__stack_top_c00
@        SUB     r1, r1, #1
@        BFC     r1, #0, #6
@        LDR     r2, =((AttrIndx0<<1) | (ENable))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c11, 5                   // write PRLAR7
@
@        // Region 8 - Stack of core 1
@        LDR     r1, =__stack_base_c01 //=Image$$ARM_LIB_HEAP$$Base
@        LDR     r2, =((Non_Shareable<<3) | (RW_Access<<1))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c12, 0                   // write PRBAR8
@
@        LDR     r1, =__stack_top_c01 //=Image$$ARM_LIB_STACK$$ZI$$Limit
@        SUB     r1, r1, #1
@        BFC     r1, #0, #6
@        LDR     r2, =((AttrIndx0<<1) | (ENable))
@        ORR     r1, r1, r2
@        MCR     p15, 0, r1, c6, c12, 1                   // write PRLAR8

    // HMAIR0 configuration
        MRC p15, 4, r0, c10, c2, 0      // Read HMAIR0 into r0
        LDR r1, =0xBB                   // Normal inner/outer RW cacheable, write-through
        BFI r0, r1, #0, #8              // Update Attr0
        LDR r1, =0x04                   // Device nGnRnE
        BFI r0, r1, #8, #8              // Update Attr1
        MCR p15,4,r0,c10,c2,0           // Write r0 to HMAIR0

        MRC p15, 4, r0, c1, c0, 0   // HSCTLR
        ORR r0, r0, #1              // enable MPU
        MCR p15, 4, r0, c1, c0, 0

    // MAIR0 configuration
        MRC p15, 0, r0, c10, c2, 0      // Read MAIR0 into r0
        LDR r1, =0xBB                   // Normal inner/outer RW cacheable, write-through
        BFI r0, r1, #0, #8              // Update Attr0
        LDR r1, =0x04                   // Device nGnRnE
        BFI r0, r1, #8, #8              // Update Attr1
        MCR p15,0,r0,c10,c2,0           // Write r0 to HMAIR0

        MRC p15, 0, r0, c1, c0, 0   // SCTLR
        ORR r0, r0, #1              // enable EL1 MPU
        MCR p15, 0, r0, c1, c0, 0

        POP     {r0-r3, r12, lr}
        BX      lr
