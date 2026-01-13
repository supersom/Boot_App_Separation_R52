/*
 * utils.S
 *
 *  Created on: Nov 17, 2025
 *
 *	Description: This file has utility functions
 *
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

//=================================================================================
// Variable Definitions
//=================================================================================

	.section VARS, "aw"
// Variables for calling getAffinity() - static but only used by core 1
// in IRQ routine so no problems.
.balign 8
affinity_variables:
    .word 0
    .word 1
    .word 2

// Variables to record the start and stop values of PMU cycle counters
.global pmccntr_start_val
.balign 8
pmccntr_start_val:
	.word 0
	.word 0
	.word 0
	.word 0

.global pmccntr_stop_val
.balign 8
pmccntr_stop_val:
	.word 0
	.word 0
	.word 0
	.word 0

.global pmccntr_diff_val
.balign 8
pmccntr_diff_val:
	.word 0
	.word 0
	.word 0
	.word 0

.global pmccntr_c01_start_val
.balign 8
pmccntr_c01_start_val:
	.word 0

.global pmccntr_c01_stop_val
.balign 8
pmccntr_c01_stop_val:
	.word 0

.global pmccntr_c01_diff_val
.balign 8
pmccntr_c01_diff_val:
	.word 0

.global pmccntr_c10_start_val
.balign 8
pmccntr_c10_start_val:
	.word 0

.global pmccntr_c10_stop_val
.balign 8
pmccntr_c10_stop_val:
	.word 0

.global pmccntr_c10_diff_val
.balign 8
pmccntr_c10_diff_val:
	.word 0

.global pmccntr_c11_start_val
.balign 8
pmccntr_c11_start_val:
	.word 0

.global pmccntr_c11_stop_val
.balign 8
pmccntr_c11_stop_val:
	.word 0

.global pmccntr_c11_diff_val
.balign 8
pmccntr_c11_diff_val:
	.word 0
//=================================================================================
// Flag variables - to be placed in RW memory shared across cores
//=================================================================================

	.section FLAGS, "aw"
// Flag tracking whether the standard C library has been initialized.
.balign 8
C_library_initialized:
    .word 0

// Flag tracking whether a core is waiting.
.balign 8
Core_waiting:
    .word 0
    .word 0
    .word 0
    .word 0

// Flag tracking whether a core has been initialized.
.balign 8
Core_initialized:
    .word 0
    .word 0
    .word 0
    .word 0

// Flag tracking whether Core 1 is waiting.
.balign 8
Core_1_waiting:
    .word 0

// Flag tracking whether Core 1 has been initialized.
.balign 8
Core_1_initialized:
    .word 0

// Flag tracking whether Core 10 is waiting.
.balign 8
Core_10_waiting:
    .word 0

// Flag tracking whether Core 10 has been initialized.
.balign 8
Core_10_initialized:
    .word 0

// Flag tracking whether Core 11 is waiting.
.balign 8
Core_11_waiting:
    .word 0

// Flag tracking whether Core 11 has been initialized.
.balign 8
Core_11_initialized:
    .word 0

// Flag tracking whether the flash i/f for the core has been initialized.
.balign 8
flash_initialized:
	.word 0
	.word 0
	.word 0
	.word 0

// Flag tracking whether the ATCM for the core has been initialized.
.global ATCM_initialized
.balign 8
ATCM_initialized:
	.word 0
	.word 0
	.word 0
	.word 0

// Flag tracking whether the BTCM for the core has been initialized.
.balign 8
BTCM_initialized:
	.word 0
	.word 0
	.word 0
	.word 0

// Flag tracking whether the CTCM for the core has been initialized.
.balign 8
CTCM_initialized:
	.word 0
	.word 0
	.word 0
	.word 0

// Flag tracking whether the GICD has been initialized.
.balign 8
GICD_initialized: .word 0

// lock variable controlling access to print resource
.balign 8
printf_lock:
    .word 0


//=================================================================================

		.section UTILS, "ax"
.global generateSGI
.type generateSGI, "function"
generateSGI:
    // Push registers that are going to be used in this
    // handler onto the stack. These will backed up in switch_guest_os.
    // This includes r0-r3, r12, and lr, which are mandated by the
    // Arm Architecture Procedure Call Standard (AAPCS).
    // This is required because external C functions are called in the handler.
    PUSH {r0-r3, r12, lr}

    // AAPCS mandates 8-byte alignment at all external boundaries
    // (i.e. separately compiled or assembled files).
    // Check if the sp is 8-byte aligned.
    AND r5, sp, #4              // r7 contains either 0 (if sp is already aligned)
                                // or 4 (if sp is misaligned) after this AND.
    SUB sp, sp, r5              // Subtract either 0 or 4 to align to 8 bytes.

    // ** Send SGI
    // Use the Interrupt Controller Software Generated Interrupt Group 1 Register
    // (ICC_SGI1R), which is a 64-bit.
    //
    // Get affinity for core.
    // This will be core 0 and it is expected that
    // values of 0 are returned for all affinity levels.
    // However, in a system with more than one processor this would be an essential
    // step and the values for Aff1 and Aff2 would have to be obtained.

    // Note: getAffinity() is designed to be called by C code. Therefore, variables
    // to receive the affinity levels must be assigned.
    // In other words things are set up as if it is being called from C.

    LDR    r3, =affinity_variables
    MOV    r0, r3            // Load address of affinity0.
    ADD    r3, r3, 4
    MOV    r1, r3            // Load address of affinity1.
    ADD    r3, r3, 4
    MOV    r2, r3            // Load address of affinity2.

    // Call getAffinity()
    BL getAffinity

    ADD sp, sp, r5           // Restore sp to its previous alignment.

    // affinity2, affinity1 and affinity0 should now contain the affinity for
    // this core. 0.0.0 is expected in this system.
    // affinity 0 can be discarded as the cores required (in this case only core 1)
    // are set using the target list.
    // affinity1 and affinity2 *must* be used in a multi-processor system
    // when routing SGIs.
    // Even though the Cortex-R52 cannot route SGIs outside of itself, these
    // two values will reflect its "position" in a multi-processor system.
    // They therefore must be respected or SGI routing will fail.

    // Set lower 31 bits for ICC_SGI1R in r0.
    MOV    r0, #0x0         // Initializes the Interrupt ID to use for this SGI
                            // (bits 24-27) because ID 0 has been chosen
                            // for this SGI.
    ORR    r0, r0, #0x2     // Set bit 1 of the target list (bits 0 to 4) to
                            // to direct this SGI to core 1 only.
    LDR    r2, =affinity_variables
    LDR    r3, [r2, #4]     // Load affinity1 into r3.
    ORR    r0, r0, r3, LSL #16  // Set bits 16-23 to affinity1.

    // Set upper 31 bits for ICC_SGI1R in r1.
    MOV    r1, #0x0         // Sets bit 40 to 0 - This turns off a flag
                            // that determines whether to send the SGI
                            // to every core (and override the target list).
                            // The Affinity 3 setting (bits 48-55) is also set to 0
                            // // but the setting is not relevant to the Cortex-R52.
    LDR    r3, [r2, #8]     // Load affinity2 into r3.
    ORR    r1, r1, r3       // Set bits 32-39 to affinity2.

    MCRR p15, 0, r0, r1, c12 // Write r0 and r1 to ICC_SGI1R.

    // Pop registers that have been used in this
    // handler off the stack. The values on the stack
    // were updated in switch_guest_os and are now from the
    // guest OS being restored.
    POP {r0-r3, r12, lr}

    BX lr

.global wait
.type wait, "function"
wait:
    WFI
    BX      lr

.global getCPUID
.type getCPUID, "function"
getCPUID:
    //Check which CPU I am
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
    BX lr

.global getAffinity
.type getAffinity, "function"
getAffinity:
    // This function assumes the following:
    // r0, r1, r2: pointers to 32-bit int

    // Read MPIDR into r3.
    MRC p15, 0, r3, c0, c0, 5

    // Conform to AAPCS standard and preserve r4, r5, and r6.
    PUSH {r4-r6}

    // Load affinity level 0 (bits 0 - 7) into r4.
    MOV r4, r3
    AND r4, r4, 0xFF

    // Load affinity level 1 (bits 8 - 15)  into r5.
    MOV r5, r3
    AND r5, r5, 0xFF00
    LSR r5, 8

    // Load affinity level 2 (bits 16 - 23) into r6.
    MOV r6, r3
    AND r6, r6, 0xFF0000
    LSR r6, 16

    STR      r4, [r0]   // r4 into (int*) r0
    STR      r5, [r1]   // r5 into (int*) r1
    STR      r6, [r2]   // r6 into (int*) r2

    POP {r4-r6}

    BX      lr

.global markCLibraryInitialized
.type markCLibraryInitialized, "function"
markCLibraryInitialized:
    LDR r0, =C_library_initialized
    MOV r1, 0x1
    STR r1, [r0]
    BX lr

.global isCLibraryInitialized
.type isCLibraryInitialized, "function"
isCLibraryInitialized:
    LDR r2, =C_library_initialized
    LDR r3, [r2]
    CMP r3, #0x1
    BEQ libInit
    // not ready
    mov r0, #0x0
    BX      lr
libInit:
    mov r0, #0x1
    BX      lr

.global awaitCLibraryInit
.type awaitCLibraryInit, "function"
awaitCLibraryInit:
    LDR r2, =C_library_initialized
    LDR r3, [r2]
    CMP r3, #0x1
    BNE awaitCLibraryInit
    BX      lr

.global markCoreWaiting
.type markCoreWaiting, "function"
markCoreWaiting:
@	BL getCPUID
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
    LDR r2, =Core_waiting
    ADD r2, r2, r0, LSL #2     // add r0 * 4 to r2 and store in r2
    MOV r3, 0x1
    STR r3, [r2]
    BX lr

.global isCoreWaiting
.type isCoreWaiting, "function"
isCoreWaiting:
@	BL getCPUID
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
    LDR r2, =Core_waiting
    ADD r2, r2, r0, LSL #2     // add r0 * 4 to r2 and store in r2
    LDR r3, [r2]
    CMP r3, #0x1
    BEQ coreWaiting
    // not ready
    mov r0, #0x0
    BX      lr
coreWaiting:
    mov r0, #0x1
    BX      lr

.global awaitCoreWaiting
.type awaitCoreWaiting, "function"
awaitCoreWaiting:
@	BL getCPUID
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
    LDR r2, =Core_waiting
    ADD r2, r2, r0, LSL #2     // add r0 * 4 to r2 and store in r2
    LDR r3, [r2]
    CMP r3, #0x1
    BNE awaitCoreWaiting
    BX      lr

.global markCoreInitialized
.type markCoreInitialized, "function"
markCoreInitialized:
@    BL getCPUID
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
    LDR r2, =Core_initialized
    ADD r2, r2, r0, LSL #2     // add r0 * 4 to r2 and store in r2
    MOV r3, 0x1
    STR r3, [r2]
    BX lr

.global isCoreInitialized
.type isCoreInitialized, "function"
isCoreInitialized:
@    BL getCPUID
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
    LDR r2, =Core_initialized
    ADD r2, r2, r0, LSL #2     // add r0 * 4 to r2 and store in r2
    LDR r3, [r2]
    CMP r3, #0x1
    BEQ coreReady
    // not ready
    mov r0, #0x0
    BX      lr
coreReady:
    mov r0, #0x1
    BX      lr

.global awaitSpecificCoreInit
.type awaitSpecificCoreInit, "function"
awaitSpecificCoreInit:
    LDR r2, =Core_initialized
    ADD r2, r2, r0, LSL #2
1:
    LDR r3, [r2]
    CMP r3, #0x1
    BNE 1b
    BX      lr

.global markCore1Waiting
.type markCore1Waiting, "function"
markCore1Waiting:
    LDR r0, =Core_1_waiting
    MOV r1, 0x1
    STR r1, [r0]
    BX lr

.global isCore1Waiting
.type isCore1Waiting, "function"
isCore1Waiting:
    LDR r2, =Core_1_waiting
    LDR r3, [r2]
    CMP r3, #0x1
    BEQ core1Waiting
    // not ready
    mov r0, #0x0
    BX      lr
core1Waiting:
    mov r0, #0x1
    BX      lr

.global awaitCore1Waiting
.type awaitCore1Waiting, "function"
awaitCore1Waiting:
    LDR r2, =Core_1_waiting
    LDR r3, [r2]
    CMP r3, #0x1
    BNE awaitCore1Waiting
    BX      lr

.global markCore1Initialized
.type markCore1Initialized, "function"
markCore1Initialized:
    LDR r0, =Core_1_initialized
    MOV r1, 0x1
    STR r1, [r0]
    BX lr

.global isCore1Initialized
.type isCore1Initialized, "function"
isCore1Initialized:
    LDR r2, =Core_1_initialized
    LDR r3, [r2]
    CMP r3, #0x1
    BEQ core1Ready
    // not ready
    mov r0, #0x0
    BX      lr
core1Ready:
    mov r0, #0x1
    BX      lr

.global awaitCore1Init
.type awaitCore1Init, "function"
awaitCore1Init:
    LDR r2, =Core_1_initialized
    LDR r3, [r2]
    CMP r3, #0x1
    BNE awaitCore1Init
    BX      lr

.global markFlashInitialized
.type markFlashInitialized, "function"
markFlashInitialized:
	BL getCPUID // CPU ID in r0
    LDR r2, =flash_initialized
    ADD r2, r2, r0, LSL #2
    MOV r3, #0x1
    STR r3, [r2]
    BX lr

.global isFlashInitialized
.type isFlashInitialized, "function"
isFlashInitialized:
	BL getCPUID // CPU ID in r0
    LDR r2, =flash_initialized
    ADD r2, r2, r0, LSL #2
    LDR r3, [r2]
    CMP r3, #0x1
    BEQ flash_ready
    // not ready
    mov r0, #0x0
    BX      lr
flash_ready:
    mov r0, #0x1
    BX      lr

.global awaitFlashInit
.type awaitFlashInit, "function"
awaitFlashInit:
	BL getCPUID // CPU ID in r0
    LDR r2, =flash_initialized
    ADD r2, r2, r0, LSL #2
    LDR r3, [r2]
    CMP r3, #0x1
    BNE awaitFlashInit
    BX      lr

//----------------------------------------------------------------
// Ensure that no functions are called from ATCM init routines
// - stack will be initialized on ATCM and LR is not saved as
// stack has not been initialized yet.
//----------------------------------------------------------------
.global markATCMInitialized
.type markATCMInitialized, "function"
//----------------------------------------------------------------
// int markATCMInitialized(void)
// Internally uses:
//		r0: read MPIDR
//		r2: location of per-core ATCM_initialized flag
//		r3: value (0x1) to be set to per-core ATCM initialized flag
//----------------------------------------------------------------
markATCMInitialized:
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
    LDR r2, =ATCM_initialized
    ADD r2, r2, r0, LSL #2
    MOV r3, #0x1
    STR r3, [r2]
    BX lr

//----------------------------------------------------------------
// Ensure that no functions are called from ATCM init routines
// - stack will be initialized on ATCM and LR is not saved as
// stack has not been initialized yet.
//----------------------------------------------------------------
.global isATCMInitialized
.type isATCMInitialized, "function"
//----------------------------------------------------------------
// int isATCMInitialized(void)
// return r0: initialized or not flag
// Internally uses:
//		r0: read MPIDR
//		r2: location of per-core ATCM_initialized flag
//		r3: read value of per-core ATCM initialized flag
//----------------------------------------------------------------
isATCMInitialized:
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
    LDR r2, =ATCM_initialized
    ADD r2, r2, r0, LSL #2
    LDR r3, [r2]
    CMP r3, #0x1
    BEQ ATCM_ready
    // not ready
    mov r0, #0x0
    BX      lr
ATCM_ready:
    mov r0, #0x1
    BX      lr

//----------------------------------------------------------------
// Ensure that no functions are called from ATCM init routines
// - stack will be initialized on ATCM and LR is not saved as
// stack has not been initialized yet.
//----------------------------------------------------------------
.global awaitATCMInit
.type awaitATCMInit, "function"
//----------------------------------------------------------------
// void awaitATCMInit(void)
// Internally uses:
//		r0: read MPIDR
//		r2: location of per-core ATCM_initialized flag
//		r3: read value of per-core ATCM initialized flag
//----------------------------------------------------------------
awaitATCMInit:
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
    LDR r2, =ATCM_initialized
    ADD r2, r2, r0, LSL #2
    LDR r3, [r2]
    CMP r3, #0x1
    BNE awaitATCMInit
    BX      lr

.global markBTCMInitialized
.type markBTCMInitialized, "function"
//----------------------------------------------------------------
// void markBTCMInitialized(void)
// Internally uses:
//		r0: read MPIDR
//		r2: location of per-core BTCM_initialized flag
//		r3: value (0x1) to be set to per-core ATCM initialized flag
//----------------------------------------------------------------
markBTCMInitialized:
	PUSH {lr}
	BL getCPUID // CPU ID in r0
    LDR r2, =BTCM_initialized
    ADD r2, r2, r0, LSL #2
    POP {lr}
    MOV r3, #0x1
    STR r3, [r2]
    BX lr

.global isBTCMInitialized
.type isBTCMInitialized, "function"
//----------------------------------------------------------------
// int isBTCMInitialized(void)
// return r0: initialized or not flag
// Internally uses:
//		r0: read MPIDR
//		r2: location of per-core BTCM_initialized flag
//		r3: read value of per-core BTCM initialized flag
//----------------------------------------------------------------
isBTCMInitialized:
	PUSH {lr}
	BL getCPUID // CPU ID in r0
    LDR r2, =BTCM_initialized
    ADD r2, r2, r0, LSL #2
    POP {lr}
    LDR r3, [r2]
    CMP r3, #0x1
    BEQ BTCM_ready
    // not ready
    mov r0, #0x0
    BX      lr
BTCM_ready:
    mov r0, #0x1
    BX      lr

.global awaitBTCMInit
.type awaitBTCMInit, "function"
//----------------------------------------------------------------
// void awaitBTCMInit(void)
// Internally uses:
//		r0: read MPIDR
//		r2: location of per-core BTCM_initialized flag
//		r3: read value of per-core BTCM initialized flag
//----------------------------------------------------------------
awaitBTCMInit:
	PUSH {lr}
	BL getCPUID // CPU ID in r0
    LDR r2, =BTCM_initialized
    ADD r2, r2, r0, LSL #2
    POP {lr}
    LDR r3, [r2]
    CMP r3, #0x1
    BNE awaitBTCMInit
    BX      lr

.global markCTCMInitialized
.type markCTCMInitialized, "function"
//----------------------------------------------------------------
// void markCTCMInitialized(void)
// Internally uses:
//		r0: read MPIDR
//		r2: location of per-core CTCM_initialized flag
//		r3: value (0x1) to be set to per-core CTCM initialized flag
//----------------------------------------------------------------
markCTCMInitialized:
	PUSH {lr}
	BL getCPUID // CPU ID in r0
    LDR r2, =CTCM_initialized
    ADD r2, r2, r0, LSL #2
	POP {lr}
    MOV r3, #0x1
    STR r3, [r2]
    BX lr

.global isCTCMInitialized
.type isCTCMInitialized, "function"
//----------------------------------------------------------------
// int isCTCMInitialized(void)
// return r0: initialized or not flag
// Internally uses:
//		r0: read MPIDR
//		r2: location of per-core ATCM_initialized flag
//		r3: read value of per-core ATCM initialized flag
//----------------------------------------------------------------
isCTCMInitialized:
	PUSH {lr}
	BL getCPUID // CPU ID in r0
    LDR r2, =CTCM_initialized
    ADD r2, r2, r0, LSL #2
	POP {lr}
    LDR r3, [r2]
    CMP r3, #0x1
    BEQ CTCM_ready
    // not ready
    mov r0, #0x0
    BX      lr
CTCM_ready:
    mov r0, #0x1
    BX      lr

.global awaitCTCMInit
.type awaitCTCMInit, "function"
//----------------------------------------------------------------
// void awaitCTCMInit(void)
// Internally uses:
//		r0: read MPIDR
//		r2: location of per-core ATCM_initialized flag
//		r3: read value of per-core ATCM initialized flag
//----------------------------------------------------------------
awaitCTCMInit:
	PUSH {lr}
	BL getCPUID // CPU ID in r0
    LDR r2, =CTCM_initialized
    ADD r2, r2, r0, LSL #2
	POP {lr}
    LDR r3, [r2]
    CMP r3, #0x1
    BNE awaitCTCMInit
    BX      lr

.global markGICDInitialized
.type markGICDInitialized, "function"
markGICDInitialized:
    LDR r0, =GICD_initialized
    MOV r1, #0x1
    STR r1, [r0]
    BX lr

.global isGICDInitialized
.type isGICDInitialized, "function"
isGICDInitialized:
    LDR r2, =GICD_initialized
    LDR r3, [r2]
    CMP r3, #0x1
    BEQ GICD_ready
    // not ready
    mov r0, #0x0
    BX      lr
GICD_ready:
    mov r0, #0x1
    BX      lr

.global awaitGICDInit
.type awaitGICDInit, "function"
awaitGICDInit:
    LDR r2, =GICD_initialized
    LDR r3, [r2]
    CMP r3, #0x1
    BNE awaitGICDInit
    BX      lr

.global Copy_Vectors_ROM_to_TCM
.type Copy_Vectors_ROM_to_TCM, "function"
@ ---------------------------------------------------------------
@ Copy_Vectors_ROM_to_TCM
@ Copies Image$$VECTOR_TABLE$$Length bytes from Load$$... to Image$$...
@ ---------------------------------------------------------------
Copy_Vectors_ROM_to_TCM:
        PUSH    {r4-r7, lr}

@        -----------------------------------------------
@         1. Define source/destination/length
@        -----------------------------------------------
        LDR     r0, =Load$$ATCM$$Base    // src (ROM)
        LDR     r1, =Image$$ATCM$$Base   // dst (TCM)
        LDR     r2, =Image$$ATCM$$Length // total bytes
CopyLoopVec:
        LDR     r3, [r0], #4
        STR     r3, [r1], #4
        SUBS    r2, r2, #4
        BNE     CopyLoopVec

@        -----------------------------------------------
@         2. Set VBAR_EL1 to new vector table in TCM
@        -----------------------------------------------
        LDR     r0, =Image$$ATCM$$Base // new vector base in TCM
        MCR     p15, 4, r0, c12, c0, 0 // write VBAR

        DSB
        ISB
        POP     {r4-r7, pc}

.global Copy_ROM_to_TCM
.type Copy_ROM_to_TCM, "function"
@ ---------------------------------------------------------------------------
@ Copy_ROM_to_TCM
@ Copies Image$$<ER_SECTION>$$Length bytes from Load$$... to Image$$...
@ ---------------------------------------------------------------------------
@		Caller is expected to define source/destination/length
@        --------------------------------------------------------------------
@         1. Define source/destination/length
@        --------------------------------------------------------------------
@        LDR     r0, =Load$$<ER_SECTION>$$Base  // src (ROM)
@        LDR     r1, =Image$$ER_SECTION$$Base   // dst (TCM)
@        LDR     r2, =Image$$ER_SECTION$$Length // total bytes
@ ---------------------------------------------------------------------------

Copy_ROM_to_TCM:
        PUSH    {r4-r7, lr}

CopyLoop:
        LDR     r3, [r0], #4
        STR     r3, [r1], #4
        SUBS    r2, r2, #4
        BNE     CopyLoop

        DSB
        ISB
        POP     {r4-r7, pc}

@		After this function returns, do this if you are copying VECTORS
@        -----------------------------------------------
@         2. Set VBAR_EL1 to new vector table in TCM
@        -----------------------------------------------
@        LDR     r0, =Image$$ATCM$$Base // new vector base in TCM
@        MCR     p15, 4, r0, c12, c0, 0 // write VBAR

    .global lock
    .type lock, %function
lock:
    // r0 contains the address of the lock variable
1:
    ldrex r1, [r0]      // Load the lock value exclusively
    cmp r1, #0          // Check if the lock is free (0)
    bne 1b              // If not free (1), spin and wait
    mov r1, #1          // If free, prepare to write 1
    strex r2, r1, [r0]  // Try to store 1 to acquire the lock
    cmp r2, #0          // Check if the store was successful (STREX returns 0)
    bne 1b              // If not successful, another core took the lock just before us, so retry
    dmb                 // Data Memory Barrier to ensure that memory accesses after this point
                        // happen after the lock is acquired.
    bx lr

    .global unlock
    .type unlock, %function
unlock:
    // r0 contains the address of the lock variable
    dmb                 // Data Memory Barrier to ensure that all memory accesses before this
                        // point are completed before the lock is released.
    mov r1, #0
    str r1, [r0]        // Store 0 to release the lock
    bx lr

	.global init_pmu_cctr
	.type init_pmu_cctr, %function
init_pmu_cctr:
@	push {r0, r1}
    // -------------------------------------------------------------
    // 1. Enable User-mode Access to PMU
    // Register: PMUSERENR (c9, c14, 0)
    // Value: 1 (Enable)
    // -------------------------------------------------------------
    MOV R0, #1
    MCR p15, 0, R0, c9, c14, 0

    // -------------------------------------------------------------
    // 2. Program Control Register
    // Register: PMCR (c9, c12, 0)
    // Logic: 1 (Enable) | 2 (Reset Cnt) | 4 (Reset CC) | 16 (Export)
    // Value: 1 + 2 + 4 + 16 = 23 (0x17)
    // -------------------------------------------------------------
    MOV R0, #0x17
    MCR p15, 0, R0, c9, c12, 0

    // -------------------------------------------------------------
    // 3. Enable All Counters
    // Register: PMCNTENSET (c9, c12, 1)
    // Value: 0x8000000f (Bit 31 = Cycle Count, Bits 0-3 = Counters)
    // -------------------------------------------------------------
    LDR R0, =0x8000000f
    MCR p15, 0, R0, c9, c12, 1

    // -------------------------------------------------------------
    // 4. Clear Overflow Flags
    // Register: PMOVSR (c9, c12, 3)
    // Value: 0x8000000f (Same mask as above)
    // Note: R0 still holds 0x8000000f, so we reuse it.
    // -------------------------------------------------------------
    MCR p15, 0, R0, c9, c12, 3

@	pop {r0, r1}
    // Return
    BX LR

	.global profile_start_asm
	.type profile_start_asm, %function
// void profile_start()
profile_start_asm:
@.macro PROFILE_START
@	push {r0, r1}
@    BL getCPUID
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
	mrc p15, 0, r1, c9, c13, 0
	ldr r2, =pmccntr_start_val
    ADD r2, r2, r0, LSL #2
	str r1, [r2]
@	pop {r0, r1}
	bx lr
@.endm

	.global profile_stop_asm
	.type profile_stop_asm, %function
// void profile_stop()
profile_stop_asm:
@.macro PROFILE_STOP
@	push {r0-r3, r12, lr}
@    BL getCPUID
    MRC p15, 0, r0, c0, c0, 5   // Read MPIDR into R0
    ANDS r0, r0, 0xFF
	mrc p15, 0, r3, c9, c13, 0
	ldr r2, =pmccntr_stop_val
    ADD r2, r2, r0, LSL #2
	str r3, [r2]
	ldr r2, =pmccntr_start_val
    ADD r1, r2, r0, LSL #2
	ldr r1, [r2]
	sub r1, r3, r1
	ldr r2, =pmccntr_diff_val
    ADD r2, r2, r0, LSL #2
	str r1, [r2]
    mov r0, r1
@	pop {r0-r3, r12, lr}
	bx lr
@.endm
